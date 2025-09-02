#!/usr/bin/env bash

# Analysis Functions Module for FFmpeg Encoder
# Contains video analysis, complexity detection, and HDR analysis functions

# Determine video duration
get_video_duration() {
    local input=$1
    local duration=$(ffprobe -v error -analyzeduration 100M -probesize 50M -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | \
        cut -d. -f1 || echo "0")
    echo "$duration"
}

# Automatic crop detection with progress
detect_crop_values() {
    local input=$1
    local detection_duration=${2:-300}
    local min_threshold=${3:-20}
    
    log CROP "Starting automatic crop detection..."
    
    # HDR detection for adaptive crop limits  
    local is_hdr=$(extract_hdr_metadata "$input")
    local crop_limit=24  # Increased from 16 to catch more vertical bars
    if [[ "$is_hdr" == "true" ]]; then
        crop_limit=64  # Higher threshold for HDR content as black bars are not pure black
        log CROP "HDR content detected - using adjusted crop limit: $crop_limit"
    else
        log CROP "SDR content - using standard crop limit: $crop_limit"
    fi
    
    # Determine video duration
    local video_duration=$(get_video_duration "$input")
    [[ $video_duration -lt $detection_duration ]] && detection_duration=$video_duration
    
    # Sample points
    local start_time=60
    local mid_time=$((video_duration / 2))
    local end_time=$((video_duration - 60))
    [[ $end_time -lt $start_time ]] && end_time=$start_time
    
    local temp_crop_log="${TEMP_DIR}/crop_analysis_$$.log"
    
    # Sample 1 with progress - adaptive detection for black bars
    local cmd1="ffmpeg -loglevel info -ss $start_time -i '$input' -t 30 -vsync vfr -vf 'fps=1/4,cropdetect=limit=$crop_limit:round=2:reset=1' -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> '$temp_crop_log' || true"
    run_with_progress "Crop Analysis (Start)" 0 \
        bash -c "$cmd1" >&2
    
    # Sample 2 with progress
    local cmd2="ffmpeg -loglevel info -ss $mid_time -i '$input' -t 30 -vsync vfr -vf 'fps=1/4,cropdetect=limit=$crop_limit:round=2:reset=1' -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> '$temp_crop_log' || true"
    run_with_progress "Crop Analysis (Middle)" 0 \
        bash -c "$cmd2" >&2
    
    # Sample 3 with progress
    local cmd3="ffmpeg -loglevel info -ss $end_time -i '$input' -t 30 -vsync vfr -vf 'fps=1/4,cropdetect=limit=$crop_limit:round=2:reset=1' -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> '$temp_crop_log' || true"
    run_with_progress "Crop Analysis (End)" 0 \
        bash -c "$cmd3" >&2
    
    # Determine most common crop value
    local most_common_crop=""
    if [[ -f "$temp_crop_log" && -s "$temp_crop_log" ]]; then
        most_common_crop=$(sort "$temp_crop_log" | uniq -c | sort -nr | head -1 | awk '{print $2}' 2>/dev/null || echo "")
    fi
    
    rm -f "$temp_crop_log" 2>/dev/null || true
    
    # Validation
    if [[ -n "$most_common_crop" ]]; then
        local crop_w=$(echo "$most_common_crop" | cut -d: -f1 | cut -d= -f2)
        local crop_h=$(echo "$most_common_crop" | cut -d: -f2)
        
        local orig_resolution=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams v:0 -show_entries stream=width,height \
            -of csv=s=x:p=0 "$input" 2>/dev/null || echo "1920x1080")
        local orig_w=$(echo "$orig_resolution" | cut -dx -f1)
        local orig_h=$(echo "$orig_resolution" | cut -dx -f2)
        
        local w_diff=$((orig_w - crop_w))
        local h_diff=$((orig_h - crop_h))
        local total_diff=$((w_diff + h_diff))
        
        # Check both absolute difference and percentage difference
        local percentage_diff=$(echo "scale=2; ($total_diff * 100) / ($orig_w + $orig_h)" | bc -l 2>/dev/null || echo "0")
        local significant_crop=$(echo "$percentage_diff > 1.0" | bc -l 2>/dev/null || echo "0")
        
        if [[ $total_diff -ge $min_threshold ]] || [[ $significant_crop -eq 1 ]]; then
            log CROP "Crop detected: ${orig_w}x${orig_h} → ${crop_w}x${crop_h} (${total_diff} pixels, ${percentage_diff}%)"
            echo "$most_common_crop"
        else
            log CROP "No significant crop required (${total_diff} pixels, ${percentage_diff}%)"
            echo ""
        fi
    else
        log CROP "No black bars detected"
        echo ""
    fi
}

# Calculate Spatial Information
calculate_spatial_information() {
    local input=$1
    local duration=$(get_video_duration "$input")
    local analysis_time=$((duration > 300 ? 30 : duration / 10))
    
    local si_temp_file="${TEMP_DIR}/si_output_$$.tmp"
    
    # Run analysis with progress bar displayed to stderr
    bash -c "ffmpeg -i '$input' -vf 'sobel,crop=iw-4:ih-4:2:2' -t 30 -f null - 2>&1 | grep -o 'frame=.*fps' | tail -1 | grep -o '[0-9]*fps' | sed 's/fps//' || echo '50'" > "$si_temp_file" &
    local pid=$!
    
    # Show progress while analysis runs
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $analysis_time ]]; do
        show_progress "$elapsed" "$analysis_time" "Spatial Information"
        sleep 1
        ((elapsed++))
    done
    
    wait "$pid"
    show_progress "$analysis_time" "$analysis_time" "Spatial Information"
    printf "\n"
    
    local si
    si=$(cat "$si_temp_file" 2>/dev/null || echo "50")
    rm -f "$si_temp_file" 2>/dev/null || true
    
    # Validate si is numeric
    if ! [[ "$si" =~ ^[0-9]+$ ]]; then
        si="50"
    fi
    
    echo "${si:-50}"
}

# Calculate Temporal Information
calculate_temporal_information() {
    local input=$1
    
    local ti_temp_file="${TEMP_DIR}/ti_output_$$.tmp"
    
    # Run analysis with progress bar displayed to stderr
    bash -c "ffprobe -v error -select_streams v:0 -read_intervals '%+#900' -show_frames -show_entries frame=pict_type '$input' 2>/dev/null | awk 'BEGIN{p=0;t=0} /pict_type=P|pict_type=B/{p++} /pict_type=/{t++} END{print (t>0 ? p*100/t : 50)}' || echo '50'" > "$ti_temp_file" &
    local pid=$!
    
    # Show progress while analysis runs
    local elapsed=0
    local analysis_time=10
    while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $analysis_time ]]; do
        show_progress "$elapsed" "$analysis_time" "Temporal Information"
        sleep 1
        ((elapsed++))
    done
    
    wait "$pid"
    show_progress "$analysis_time" "$analysis_time" "Temporal Information"
    printf "\n"
    
    local ti
    ti=$(cat "$ti_temp_file" 2>/dev/null || echo "50")
    rm -f "$ti_temp_file" 2>/dev/null || true
    
    # Validate ti is numeric
    if ! [[ "$ti" =~ ^[0-9.]+$ ]]; then
        ti="50"
    fi
    
    echo "${ti:-50}"
}

# Scene Change Detection
analyze_scene_changes() {
    local input=$1
    
    local sc_temp_file="${TEMP_DIR}/sc_output_$$.tmp"
    
    # Run analysis with progress bar displayed to stderr
    bash -c "ffmpeg -i '$input' -vf \"select='gt(scene,0.3)',showinfo\" -t 60 -f null - 2>&1 | grep -c 'Parsed_showinfo' || echo '10'" > "$sc_temp_file" &
    local pid=$!
    
    # Show progress while analysis runs
    local elapsed=0
    local analysis_time=60
    while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $analysis_time ]]; do
        show_progress "$elapsed" "$analysis_time" "Scene Change Analyse"
        sleep 1
        ((elapsed++))
    done
    
    wait "$pid"
    show_progress "$analysis_time" "$analysis_time" "Scene Change Analyse"
    printf "\n"
    
    local scene_changes
    scene_changes=$(cat "$sc_temp_file" 2>/dev/null || echo "10")
    rm -f "$sc_temp_file" 2>/dev/null || true
    
    # Validate scene_changes is numeric
    if ! [[ "$scene_changes" =~ ^[0-9]+$ ]]; then
        scene_changes="10"
    fi
    
    echo "${scene_changes:-10}"
}

# Frame Type Distribution
analyze_frame_distribution() {
    local input=$1
    
    local fd_temp_file="${TEMP_DIR}/fd_output_$$.tmp"
    
    # Run analysis with progress bar displayed to stderr
    bash -c "ffprobe -v error -select_streams v:0 -read_intervals '%+#1800' -show_frames -show_entries frame=pict_type '$input' 2>/dev/null | awk 'BEGIN{i=0;total=0} /pict_type=I/{i++} /pict_type=/{total++} END{print (total>0 ? i*200/total : 4)}' || echo '4'" > "$fd_temp_file" &
    local pid=$!
    
    # Show progress while analysis runs
    local elapsed=0
    local analysis_time=15
    while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $analysis_time ]]; do
        show_progress "$elapsed" "$analysis_time" "Frame Distribution"
        sleep 1
        ((elapsed++))
    done
    
    wait "$pid"
    show_progress "$analysis_time" "$analysis_time" "Frame Distribution"
    printf "\n"
    
    local frame_complexity
    frame_complexity=$(cat "$fd_temp_file" 2>/dev/null || echo "4")
    rm -f "$fd_temp_file" 2>/dev/null || true
    
    # Validate frame_complexity is numeric
    if ! [[ "$frame_complexity" =~ ^[0-9.]+$ ]]; then
        frame_complexity="4"
    fi
    
    echo "${frame_complexity:-4}"
}

# Fallback profile selection based on basic video properties
select_fallback_profile() {
    local input_video="$1"
    
    # Get basic video properties
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input_video" 2>/dev/null || echo "1920")
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input_video" 2>/dev/null || echo "1080")
    local color_space=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_space -of csv=p=0 "$input_video" 2>/dev/null)
    local color_primaries=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_primaries -of csv=p=0 "$input_video" 2>/dev/null)
    
    # Determine resolution category
    local resolution_prefix="1080p"
    if [[ $width -ge 3840 ]] && [[ $height -ge 2160 ]]; then
        resolution_prefix="4k"
    fi
    
    # Check for HDR
    local is_hdr=false
    if [[ "$color_space" == "bt2020nc" ]] || [[ "$color_primaries" == "bt2020" ]]; then
        is_hdr=true
    fi
    
    # Simple content detection based on filename patterns
    local filename=$(basename "$input_video" | tr '[:upper:]' '[:lower:]')
    local fallback_profile="${resolution_prefix}_film"
    
    case "$filename" in
        *anime*|*animation*|*cartoon*)
            fallback_profile="${resolution_prefix}_anime"
            ;;
        *cgi*|*3d*)
            fallback_profile="${resolution_prefix}_3d_animation"
            ;;
        *action*|*sports*)
            fallback_profile="${resolution_prefix}_action"
            ;;
        *classic*|*vintage*|*old*)
            fallback_profile="${resolution_prefix}_light_grain"
            ;;
        *)
            fallback_profile="${resolution_prefix}_film"
            ;;
    esac
    
    log DEBUG "Fallback selection: ${width}x${height}, HDR: $is_hdr, Profile: $fallback_profile"
    echo "$fallback_profile"
}

# Extract HDR metadata
extract_hdr_metadata() {
    local f=$1
    
    local hdr_info=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams v:0 \
        -show_entries stream=color_primaries,color_transfer,color_space \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null || echo "")
    
    local is_hdr=false
    if [[ "$hdr_info" == *"bt2020"* && "$hdr_info" == *"smpte2084"* ]]; then
        is_hdr=true
    fi
    
    echo "$is_hdr"
}

# Complete complexity analysis with progress
perform_complexity_analysis() {
    local input=$1
    log ANALYSIS "Starting comprehensive complexity analysis for: $(basename "$input")"
    
    # Get video duration for sampling strategy
    local duration=$(get_video_duration "$input")
    
    # Collect base metrics
    local si=$(calculate_spatial_information "$input")
    local ti=$(calculate_temporal_information "$input")
    local scene_changes=$(analyze_scene_changes "$input")
    local frame_complexity=$(analyze_frame_distribution "$input")
    local is_hdr=$(extract_hdr_metadata "$input")
    
    # Validate all metrics are numeric and provide defaults
    [[ "$si" =~ ^[0-9.]+$ ]] || si="50"
    [[ "$ti" =~ ^[0-9.]+$ ]] || ti="50"
    [[ "$scene_changes" =~ ^[0-9.]+$ ]] || scene_changes="10"
    [[ "$frame_complexity" =~ ^[0-9.]+$ ]] || frame_complexity="4"
    
    # Enhanced complexity scoring with grain awareness - initialize variables first
    local grain_level="0"
    local texture_score="0"
    
    # Enhanced grain detection using multiple methods and sample points
    local temp_frames_dir="/tmp/grain_analysis_$$"
    mkdir -p "$temp_frames_dir"
    
    # Sample multiple points distributed throughout the video duration
    # Use percentage-based sampling for better coverage
    local sample_times=()
    local sample_percentages=("10" "25" "50" "75" "90")  # Sample at 10%, 25%, 50%, 75%, 90% of video
    
    for percentage in "${sample_percentages[@]}"; do
        local sample_time=$(echo "scale=0; $duration * $percentage / 100" | bc -l)
        # Ensure minimum sample time of 2 seconds and doesn't exceed duration-5
        if (( $(echo "$sample_time < 2" | bc -l) )); then
            sample_time="2"
        elif (( $(echo "$sample_time > ($duration - 5)" | bc -l) )); then
            sample_time=$(echo "scale=0; $duration - 5" | bc -l)
        fi
        # Only add if it's a valid time and not duplicate
        if (( $(echo "$sample_time >= 2" | bc -l) && $(echo "$sample_time <= $duration" | bc -l) )); then
            # Check for duplicates
            local is_duplicate=false
            for existing_time in "${sample_times[@]}"; do
                if [[ "$existing_time" == "$sample_time" ]]; then
                    is_duplicate=true
                    break
                fi
            done
            if [[ "$is_duplicate" == "false" ]]; then
                sample_times+=("$sample_time")
            fi
        fi
    done
    
    # Fallback for very short videos (less than 10 seconds)
    if [[ ${#sample_times[@]} -eq 0 ]]; then
        if (( $(echo "$duration > 8" | bc -l) )); then
            sample_times=("2" "5" "8")
        elif (( $(echo "$duration > 4" | bc -l) )); then
            sample_times=("2" "$((duration/2))")
        else
            sample_times=("1")
        fi
    fi
    local total_grain=0
    local total_texture=0
    local valid_samples=0
    
    log ANALYSIS "Performing enhanced grain detection at multiple time points..."
    
    for sample_time in "${sample_times[@]}"; do
        local temp_frame="$temp_frames_dir/frame_${sample_time}.png"
        
        # Extract frame at sample time
        if ffmpeg -ss "$sample_time" -i "$input" -vframes 1 -y "$temp_frame" -loglevel error 2>/dev/null && [[ -f "$temp_frame" ]]; then
            
            # Method 1: High-frequency noise analysis (improved)
            local hf_noise=$(ffmpeg -i "$temp_frame" -vf "format=gray,crop=400:400:iw/2-200:ih/2-200,highpass=f=20:width_type=h" -f rawvideo -pix_fmt gray - 2>/dev/null | xxd -ps -l 8000 | wc -c 2>/dev/null || echo "0")
            local grain_sample=$(echo "scale=2; $hf_noise / 100" | bc -l 2>/dev/null || echo "0")
            
            # Method 2: Local variance analysis for grain texture
            local local_var=$(ffmpeg -i "$temp_frame" -vf "format=gray,crop=300:300:iw/2-150:ih/2-150" -f rawvideo -pix_fmt gray - 2>/dev/null | \
                python3 -c "
import sys
import numpy as np
try:
    data = sys.stdin.buffer.read()
    if len(data) > 1000:
        arr = np.frombuffer(data, dtype=np.uint8)
        arr = arr.reshape(-1, 300) if len(arr) >= 90000 else arr.reshape(-1, int(np.sqrt(len(arr))))
        # Calculate local variance using sliding window
        kernel_size = 5
        local_vars = []
        for i in range(kernel_size, arr.shape[0]-kernel_size):
            for j in range(kernel_size, arr.shape[1]-kernel_size):
                patch = arr[i-kernel_size:i+kernel_size, j-kernel_size:j+kernel_size]
                local_vars.append(np.var(patch))
        mean_local_var = np.mean(local_vars) if local_vars else 0
        print(f'{mean_local_var:.2f}')
    else:
        print('0')
except:
    print('0')
" 2>/dev/null || echo "0")
            
            # Method 3: Edge detection for film grain patterns
            local edge_variance=$(ffmpeg -i "$temp_frame" -vf "format=gray,crop=200:200:iw/2-100:ih/2-100,edgedetect=low=0.05:high=0.15,signalstats" -f null - 2>&1 | grep -o "YAVG:[0-9.]*" | cut -d: -f2 2>/dev/null || echo "0")
            
            # Normalize and validate values
            [[ "$grain_sample" =~ ^[0-9.]+$ ]] || grain_sample="0"
            [[ "$local_var" =~ ^[0-9.]+$ ]] || local_var="0"
            [[ "$edge_variance" =~ ^[0-9.]+$ ]] || edge_variance="0"
            
            # Combined grain metric for this sample
            local combined_grain=$(echo "scale=2; ($grain_sample * 0.4) + ($local_var * 0.1) + ($edge_variance * 0.5)" | bc -l 2>/dev/null || echo "0")
            
            # Texture analysis (optimized edge content detection)  
            local texture_sample=$(ffmpeg -i "$temp_frame" -vf "scale=320:240,format=gray,sobel" -f rawvideo -pix_fmt gray - 2>/dev/null | od -tu1 | awk 'NR>1{for(i=2;i<=NF;i++) if($i>50) count++} END{print count+0}')
            texture_sample=$(echo "scale=1; $texture_sample / 100" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "0")
            [[ "$texture_sample" =~ ^[0-9.]+$ ]] || texture_sample="0"
            
            # Accumulate values
            total_grain=$(echo "$total_grain + $combined_grain" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "$total_grain")
            total_texture=$(echo "$total_texture + $texture_sample" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "$total_texture")
            valid_samples=$((valid_samples + 1))
            
            log ANALYSIS "Sample at ${sample_time}s: grain=$combined_grain, texture=$texture_sample"
            
            rm -f "$temp_frame"
        fi
    done
    
    # Calculate average values
    if [[ $valid_samples -gt 0 ]]; then
        grain_level=$(echo "scale=1; $total_grain / $valid_samples" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "0")
        texture_score=$(echo "scale=1; $total_texture / $valid_samples" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "0")
        
        # Round grain_level to nearest integer for final use
        grain_level=$(echo "scale=0; $grain_level + 0.5" | bc -l 2>/dev/null | head -1 | tr -d '\n' | cut -d. -f1 || echo "0")
        
        # If grain level is still low, try darker scene analysis for Arcane/animated content
        if (( $(echo "$grain_level < 5" | bc -l 2>/dev/null || echo 1) )); then
            log ANALYSIS "Low grain detected, analyzing darker scenes for potential grain..."
            
            # Look for darker scenes with potential grain
            local dark_frame="$temp_frames_dir/dark_scene.png"
            if ffmpeg -ss 180 -i "$input" -vf "select=lt(scene\,0.1),format=gray" -vframes 1 -y "$dark_frame" -loglevel error 2>/dev/null && [[ -f "$dark_frame" ]]; then
                
                # Enhanced analysis for dark scenes
                local dark_grain=$(ffmpeg -i "$dark_frame" -vf "crop=400:400:iw/2-200:ih/2-200,unsharp=5:5:2.0,highpass=f=25:width_type=h,histogram=display_mode=0" -f rawvideo -pix_fmt gray - 2>/dev/null | xxd -ps -l 16000 | wc -c 2>/dev/null || echo "0")
                dark_grain=$(echo "scale=1; $dark_grain / 80" | bc -l 2>/dev/null || echo "0")
                
                # Boost grain level if dark scene analysis finds grain
                # Ensure dark_grain is a valid number
                [[ "$dark_grain" =~ ^[0-9.]+$ ]] || dark_grain="0"
                
                if (( $(echo "$dark_grain > $grain_level" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "0") )); then
                    grain_level=$(echo "scale=0; $dark_grain" | bc -l 2>/dev/null | head -1 | tr -d '\n' || echo "$grain_level")
                    log ANALYSIS "Dark scene analysis boosted grain level to: $grain_level"
                fi
                
                rm -f "$dark_frame"
            fi
        fi
        
    else
        grain_level="0"
        texture_score="0"
    fi
    
    # Cleanup
    rm -rf "$temp_frames_dir"
    
    # Normalize grain and texture values
    [[ "$grain_level" =~ ^[0-9]+$ ]] || grain_level="0"
    [[ "$texture_score" =~ ^[0-9.]+$ ]] || texture_score="0"
    
    log ANALYSIS "SI: $si, TI: $ti, Scenes/min: $scene_changes, Frame-Complexity: $frame_complexity"
    log ANALYSIS "Grain Level: $grain_level, Texture Score: $texture_score"
    log ANALYSIS "HDR Content: $is_hdr"
    
    # Enhanced complexity calculation with grain and texture weighting
    local complexity_score
    complexity_score=$(echo "scale=2; ($si * 0.25) + ($ti * 0.35) + ($scene_changes * 1.5) + ($grain_level * 8) + ($texture_score * 0.3) + ($frame_complexity * 0.25)" | bc -l 2>/dev/null || echo "50")
    
    # Validate complexity_score is numeric
    if ! [[ "$complexity_score" =~ ^[0-9.]+$ ]]; then
        complexity_score="50"
    fi
    
    # Limit score
    if (( $(echo "$complexity_score > 100" | bc -l 2>/dev/null || echo 0) )); then
        complexity_score="100"
    elif (( $(echo "$complexity_score < 10" | bc -l 2>/dev/null || echo 0) )); then
        complexity_score="10"
    fi
    
    log ANALYSIS "Total complexity score: $complexity_score"
    echo "$complexity_score"
}

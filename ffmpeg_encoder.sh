#!/usr/bin/env bash

# Advanced FFmpeg Two-Pass Encoding Script
# Version: 2.2 - Content-Adaptive Encoding
# Automatic Bitrate Optimization and Crop Detection

set -euo pipefail

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Temporary file settings
TEMP_DIR="/tmp"
STATS_PREFIX="ffmpeg_stats_$$"

# Base profile definitions
declare -A BASE_PROFILES

# 1080p Profiles
BASE_PROFILES["1080p_anime"]="preset=slow:crf=20:tune=animation:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=60:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=6:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:base_bitrate=4000:hdr_bitrate=5000:content_type=anime"
BASE_PROFILES["1080p_3d_animation"]="preset=slow:crf=18:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=60:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=5:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:base_bitrate=6000:hdr_bitrate=7000:content_type=3d_animation"
BASE_PROFILES["1080p_film"]="preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=60:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=5:psy-rd=1.0:psy-rdoq=1.0:base_bitrate=5000:hdr_bitrate=6000:content_type=film"

# 4K Profiles
BASE_PROFILES["4k_anime"]="preset=slow:crf=22:tune=animation:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=80:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:base_bitrate=10000:hdr_bitrate=12000:content_type=anime"
BASE_PROFILES["4k_3d_animation"]="preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=80:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=4:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:base_bitrate=14000:hdr_bitrate=16000:content_type=3d_animation"
BASE_PROFILES["4k_film"]="preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:rc-lookahead=80:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=1.0:base_bitrate=16000:hdr_bitrate=18000:content_type=film"

# Progress bar functions
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local bar_length=50
    
    local progress=$((current * bar_length / total))
    local percentage=$((current * 100 / total))
    
    local bar=""
    for ((i=0; i<bar_length; i++)); do
        if [[ $i -lt $progress ]]; then
            bar+="█"
        else
            bar+="░"
        fi
    done
    
    printf "\r${CYAN}[PROGRESS]${NC} %s [%s] %d%% (%d/%d)" \
        "$description" "$bar" "$percentage" "$current" "$total"
}

show_spinner() {
    local pid=$1
    local description=$2
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    printf "\r${CYAN}[PROGRESS]${NC} %s " "$description"
    
    while kill -0 "$pid" 2>/dev/null; do
        local char="${spinner_chars:$((i % ${#spinner_chars})):1}"
        printf "\r${CYAN}[PROGRESS]${NC} %s %s" "$description" "$char"
        sleep 0.1
        ((i++))
    done
    
    printf "\r${CYAN}[PROGRESS]${NC} %s ✓\n" "$description"
}

# Progress wrapper for commands with estimated duration
run_with_progress() {
    local description=$1
    local estimated_duration=$2
    shift 2
    local cmd=("$@")
    
    if [[ $estimated_duration -gt 0 ]]; then
        # Time-based progress bar
        "${cmd[@]}" &
        local pid=$!
        local elapsed=0
        
        while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $estimated_duration ]]; do
            show_progress "$elapsed" "$estimated_duration" "$description"
            sleep 1
            ((elapsed++))
        done
        
        wait "$pid"
        local exit_code=$?
        
        show_progress "$estimated_duration" "$estimated_duration" "$description"
        printf "\n"
        
        return $exit_code
    else
        # Spinner for unknown duration
        "${cmd[@]}" &
        local pid=$!
        show_spinner "$pid" "$description"
        wait "$pid"
        return $?
    fi
}

# FFmpeg with real-time progress
run_ffmpeg_with_progress() {
    local description=$1
    local input_duration=$2
    shift 2
    local cmd=("$@")
    
    log INFO "$description"
    
    # Temporary file for FFmpeg progress
    local progress_file="${TEMP_DIR}/ffmpeg_progress_$$.txt"
    
    # Extend FFmpeg command with progress output
    local ffmpeg_cmd=("${cmd[@]}")
    ffmpeg_cmd+=(-progress "$progress_file")
    
    # Start FFmpeg in background
    "${ffmpeg_cmd[@]}" &
    local pid=$!
    
    # Monitor progress
    local current_time=0
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -f "$progress_file" ]]; then
            # Read current progress from progress file
            local out_time=$(tail -n 20 "$progress_file" 2>/dev/null | \
                grep "out_time_ms=" | tail -1 | cut -d= -f2 || echo "0")
            
            if [[ "$out_time" =~ ^[0-9]+$ ]] && [[ $out_time -gt 0 ]]; then
                current_time=$((out_time / 1000000)) # Microseconds to seconds
                
                if [[ $input_duration -gt 0 && $current_time -le $input_duration ]]; then
                    show_progress "$current_time" "$input_duration" "$description"
                fi
            fi
        fi
        sleep 0.5
    done
    
    wait "$pid"
    local exit_code=$?
    
    # Cleanup
    rm -f "$progress_file" 2>/dev/null || true
    
    # Show 100% on success
    if [[ $exit_code -eq 0 && $input_duration -gt 0 ]]; then
        show_progress "$input_duration" "$input_duration" "$description"
    fi
    printf "\n"
    
    return $exit_code
}

# Determine video duration
get_video_duration() {
    local input=$1
    local duration=$(ffprobe -v error -analyzeduration 100M -probesize 50M -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | \
        cut -d. -f1 || echo "0")
    echo "$duration"
}

# Logging function
log() {
    local level=$1; shift
    local msg=$*
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC} ${ts} - ${msg}" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN ]${NC} ${ts} - ${msg}" >&2 ;;
        ERROR) echo -e "${RED}[ERROR]${NC} ${ts} - ${msg}" >&2 ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} ${ts} - ${msg}" >&2 ;;
        ANALYSIS) echo -e "${PURPLE}[ANALYSIS]${NC} ${ts} - ${msg}" >&2 ;;
        CROP) echo -e "${CYAN}[CROP]${NC} ${ts} - ${msg}" >&2 ;;
    esac
}

# Input file validation
validate_input() {
    local f=$1
    [[ -f $f && -r $f ]] || { log ERROR "Invalid input file: $f"; exit 1; }
    ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams v:0 -show_entries stream=index "$f" >/dev/null \
        || { log ERROR "No video stream: $f"; exit 1; }
    log INFO "Input validated: $f"
}

# Automatic crop detection with progress
detect_crop_values() {
    local input=$1
    local detection_duration=${2:-300}
    local min_threshold=${3:-20}
    
    log CROP "Starting automatic crop detection..."
    
    # HDR detection for adaptive crop limits  
    local is_hdr=$(extract_hdr_metadata "$input")
    local crop_limit=16
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
    run_with_progress "Crop Analysis (Start)" 30 \
        bash -c "$cmd1" >&2
    
    # Sample 2 with progress
    local cmd2="ffmpeg -loglevel info -ss $mid_time -i '$input' -t 30 -vsync vfr -vf 'fps=1/4,cropdetect=limit=$crop_limit:round=2:reset=1' -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> '$temp_crop_log' || true"
    run_with_progress "Crop Analysis (Middle)" 30 \
        bash -c "$cmd2" >&2
    
    # Sample 3 with progress
    local cmd3="ffmpeg -loglevel info -ss $end_time -i '$input' -t 30 -vsync vfr -vf 'fps=1/4,cropdetect=limit=$crop_limit:round=2:reset=1' -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> '$temp_crop_log' || true"
    run_with_progress "Crop Analysis (End)" 30 \
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
    
    log ANALYSIS "SI: $si, TI: $ti, Scenes/min: $scene_changes, Frame-Complexity: $frame_complexity"
    log ANALYSIS "HDR Content: $is_hdr"
    
    # Calculate complexity score
    local complexity_score
    complexity_score=$(echo "scale=2; ($si * 0.3) + ($ti * 0.4) + ($scene_changes * 2) + ($frame_complexity * 0.3)" | bc -l 2>/dev/null || echo "50")
    
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

# Adjust bitrate based on complexity
calculate_adaptive_bitrate() {
    local base_bitrate=$1
    local complexity_score=$2
    local content_type=$3
    
    # Validate inputs
    [[ "$base_bitrate" =~ ^[0-9]+$ ]] || base_bitrate="16000"
    [[ "$complexity_score" =~ ^[0-9.]+$ ]] || complexity_score="50"
    
    local base_value=$(echo "$base_bitrate" | sed 's/k$//')
    
    local type_modifier=1.0
    case $content_type in
        "anime")         type_modifier=0.85 ;;
        "3d_animation")  type_modifier=1.1 ;;
        "film")          type_modifier=1.0 ;;
    esac
    
    local complexity_factor
    complexity_factor=$(echo "scale=3; 0.7 + ($complexity_score / 100 * 0.6)" | bc -l 2>/dev/null || echo "1.0")
    [[ "$complexity_factor" =~ ^[0-9.]+$ ]] || complexity_factor="1.0"
    
    local adaptive_bitrate
    adaptive_bitrate=$(echo "scale=0; $base_value * $complexity_factor * $type_modifier / 1" | bc -l 2>/dev/null || echo "$base_value")
    [[ "$adaptive_bitrate" =~ ^[0-9]+$ ]] || adaptive_bitrate="$base_value"
    
    echo "${adaptive_bitrate}k"
}

# Adjust CRF based on complexity
calculate_adaptive_crf() {
    local base_crf=$1
    local complexity_score=$2
    
    # Validate inputs
    [[ "$base_crf" =~ ^[0-9.]+$ ]] || base_crf="22"
    [[ "$complexity_score" =~ ^[0-9.]+$ ]] || complexity_score="50"
    
    local crf_adjustment
    crf_adjustment=$(echo "scale=1; ($complexity_score - 50) * (-0.05)" | bc -l 2>/dev/null || echo "0")
    [[ "$crf_adjustment" =~ ^-?[0-9.]+$ ]] || crf_adjustment="0"
    
    local adaptive_crf
    adaptive_crf=$(echo "scale=1; $base_crf + $crf_adjustment" | bc -l 2>/dev/null || echo "$base_crf")
    [[ "$adaptive_crf" =~ ^[0-9.]+$ ]] || adaptive_crf="$base_crf"
    
    if (( $(echo "$adaptive_crf < 15" | bc -l 2>/dev/null || echo 0) )); then
        adaptive_crf="15"
    elif (( $(echo "$adaptive_crf > 28" | bc -l 2>/dev/null || echo 0) )); then
        adaptive_crf="28"
    fi
    echo "$adaptive_crf"
}

# Build filter chain with automatic crop
build_filter_chain() {
    local manual_crop=$1
    local scale=$2
    local auto_crop=$3
    local fc=""
    
    local final_crop=""
    if [[ -n "$manual_crop" ]]; then
        final_crop="crop=$manual_crop"
        log DEBUG "Using manual crop: $manual_crop"
    elif [[ -n "$auto_crop" ]]; then
        final_crop="$auto_crop"
        log DEBUG "Using automatic crop: $auto_crop"
    fi
    
    if [[ -n "$final_crop" ]]; then
        fc="[0:v]${final_crop}[v]"
    else
        fc="[0:v]null[v]"
    fi
    
    if [[ -n "$scale" ]]; then
        fc="${fc};[v]scale=$scale[v]"
    fi
    
    echo "$fc"
}

# Audio/Subs/Chapters Mapping
build_stream_mapping() {
    local f=$1 map=""
    
    local audio_streams=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams a -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    if [[ $audio_streams -gt 0 ]]; then
        for i in $(seq 0 $((audio_streams-1))); do 
            map+=" -map 0:a:$i -c:a:$i copy"
        done
    fi
    
    local sub_streams=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams s -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    if [[ $sub_streams -gt 0 ]]; then
        for i in $(seq 0 $((sub_streams-1))); do 
            map+=" -map 0:s:$i -c:s:$i copy"
        done
    fi
    
    map+=" -map_chapters 0 -map_metadata 0"
    echo "$map"
}

# Parse profile and adapt through complexity analysis
parse_and_adapt_profile() {
    local profile_name=$1
    local input_file=$2
    local str=${BASE_PROFILES[$profile_name]:-}
    [[ -n $str ]] || { log ERROR "Unknown profile: $profile_name"; exit 1; }
    
    # HDR Detection
    local is_hdr=$(extract_hdr_metadata "$input_file")
    
    # Extract base values
    local base_bitrate=$(echo "$str" | grep -o 'base_bitrate=[^:]*' | cut -d= -f2)
    local hdr_bitrate=$(echo "$str" | grep -o 'hdr_bitrate=[^:]*' | cut -d= -f2)
    local base_crf=$(echo "$str" | grep -o 'crf=[^:]*' | cut -d= -f2)
    local content_type=$(echo "$str" | grep -o 'content_type=[^:]*' | cut -d= -f2)
    
    # Use HDR bitrate if HDR content is detected
    local selected_bitrate="$base_bitrate"
    local selected_crf="$base_crf"
    if [[ "$is_hdr" == "true" ]]; then
        selected_bitrate="$hdr_bitrate"
        selected_crf=$(echo "scale=1; $base_crf + 2" | bc -l 2>/dev/null || echo "$base_crf")  # Slightly higher CRF for HDR
        log ANALYSIS "HDR content detected - using HDR optimized parameters"
    fi
    
    # Perform complexity analysis
    log ANALYSIS "Starting content analysis for adaptive parameter optimization..."
    local complexity_score=$(perform_complexity_analysis "$input_file")
    
    # Calculate adaptive parameters
    local adaptive_bitrate=$(calculate_adaptive_bitrate "$selected_bitrate" "$complexity_score" "$content_type")
    local adaptive_crf=$(calculate_adaptive_crf "$selected_crf" "$complexity_score")
    
    log ANALYSIS "Adaptive parameters - Bitrate: $selected_bitrate → $adaptive_bitrate, CRF: $selected_crf → $adaptive_crf (Complexity: $complexity_score)"
    
    # Update profile with adaptive values and remove helper fields
    local adapted_profile=$(echo "$str" | sed "s|base_bitrate=[^:]*|bitrate=$adaptive_bitrate|" | sed "s|hdr_bitrate=[^:]*||" | sed "s|crf=[^:]*|crf=$adaptive_crf|" | sed 's|content_type=[^:]*||' | sed 's|::|:|g' | sed 's|^:||' | sed 's|:$||')
    
    # Add HDR-specific parameters if HDR content is detected
    if [[ "$is_hdr" == "true" ]]; then
        adapted_profile="${adapted_profile}:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1"
        log ANALYSIS "HDR encoding parameters added"
    fi
    
    echo "$adapted_profile"
}

# Two-pass encoding with adaptive parameters and progress
run_encoding() {
    local in=$1 out=$2 prof=$3 title=$4 manual_crop=$5 scale=$6

    log INFO "Profile: $prof"
    
    # Video duration for progress
    local input_duration=$(get_video_duration "$in")
    
    # Automatic crop detection
    local auto_crop=""
    if [[ -z "$manual_crop" ]]; then
        auto_crop=$(detect_crop_values "$in")
        log INFO "Crop detection completed."
    fi
    
    local ps=$(parse_and_adapt_profile "$prof" "$in")
    local bitrate=$(echo "$ps" | grep -o 'bitrate=[^:]*' | cut -d= -f2)
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's|preset=[^:]*:||;s|bitrate=[^:]*:||;s|pix_fmt=[^:]*:||;s|profile=[^:]*:||;s|crf=[^:]*:||;s|^:||;s|:$||')
    local fc=$(build_filter_chain "$manual_crop" "$scale" "$auto_crop" 2>/dev/null)
    local streams=$(build_stream_mapping "$in")
    local stats="$TEMP_DIR/${STATS_PREFIX}_$(basename "$in" .${in##*.}).log"

    log INFO "Adaptive parameters - Bitrate: $bitrate, CRF: $crf"

    # First pass with progress
    local cmd1=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd1+=(-metadata title="$title")
    [[ -n $fc ]] && cmd1+=(-filter_complex "$fc" -map "[v]") || cmd1+=(-map 0:v:0)
    cmd1+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd1+=(-x265-params "$x265p:pass=1:no-slow-firstpass=1:stats=$stats")
    cmd1+=(-b:v "$bitrate" -preset:v slow -an -sn -dn -f mp4 -loglevel warning /dev/null)
    
    run_ffmpeg_with_progress "First Pass (Analyse)" "$input_duration" "${cmd1[@]}" || { 
        log ERROR "First pass failed"; exit 1; 
    }

    # Second pass with progress
    local cmd2=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd2+=(-metadata title="$title")
    [[ -n $fc ]] && cmd2+=(-filter_complex "$fc" -map "[v]") || cmd2+=(-map 0:v:0)
    cmd2+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd2+=(-x265-params "$x265p:pass=2:stats=$stats")
    cmd2+=(-b:v "$bitrate" -preset:v "$preset")
    cmd2+=($streams -default_mode infer_no_subs -loglevel warning "$out")
    
    run_ffmpeg_with_progress "Second Pass (Final Encoding)" "$input_duration" "${cmd2[@]}" || { 
        log ERROR "Second pass failed"; exit 1; 
    }

    # Cleanup
    rm -f "${stats}"* 2>/dev/null || true
    
    # Final statistics
    local input_size=$(du -h "$in" | cut -f1)
    local output_size=$(du -h "$out" | cut -f1)
    local compression_ratio=$(echo "scale=1; $(du -k "$in" | cut -f1) / $(du -k "$out" | cut -f1)" | bc -l 2>/dev/null || echo "N/A")
    log INFO "Compression: $input_size → $output_size (Ratio: ${compression_ratio}:1)"
    log INFO "Encoding completed successfully!"
}

# Main function
main() {
    local input="" output="" profile="" title="" crop="" scale=""

    # Check dependencies
    for tool in ffmpeg ffprobe bc; do
        command -v $tool >/dev/null || { log ERROR "$tool missing (install: apt install $tool)"; exit 1; }
    done

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)    input="$2"; shift 2 ;;
            -o|--output)   output="$2"; shift 2 ;;
            -p|--profile)  profile="$2"; shift 2 ;;
            -t|--title)    title="$2"; shift 2 ;;
            -c|--crop)     crop="$2"; shift 2 ;;
            -s|--scale)    scale="$2"; shift 2 ;;
            -h|--help)     
                echo "Advanced FFmpeg Two-Pass Encoder with Auto-Crop and HDR Detection for x265 encoding"
                echo "Usage: $0 -i INPUT -o OUTPUT -p PROFILE [OPTIONS]"
                echo ""
                echo "Available Profiles: ${!BASE_PROFILES[*]}"
                echo ""
                echo "Options:"
                echo "  -i, --input   Input video file"
                echo "  -o, --output  Output video file"  
                echo "  -p, --profile Encoding profile (content-type based)"
                echo "  -t, --title   Video title metadata"
                echo "  -c, --crop    Manual crop (format: w:h:x:y)"
                echo "  -s, --scale   Scale resolution (format: w:h)"
                echo "  -h, --help    Show this help"
                echo ""
                exit 0 ;;
            *) log ERROR "Unknown option: $1"; exit 1 ;;
        esac
    done

    [[ -n $input && -n $output && -n $profile ]] || { 
        log ERROR "Missing arguments: -i INPUT -o OUTPUT -p PROFILE"; exit 1; 
    }
    validate_input "$input"

    log INFO "Starting content-adaptive encoding with auto-crop and HDR detection..."
    run_encoding "$input" "$output" "$profile" "$title" "$crop" "$scale"
}

# Execute script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

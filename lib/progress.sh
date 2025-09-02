#!/usr/bin/env bash

# Progress Functions Module for FFmpeg Encoder
# Contains all progress tracking, monitoring, and display functions

# Progress bar functions
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local bar_length=50
    
    # Avoid division by zero
    if [[ $total -eq 0 ]]; then
        local progress=0
        local percentage=0
    else
        local progress=$((current * bar_length / total))
        local percentage=$((current * 100 / total))
    fi
    
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

# Get total frame count for more accurate progress tracking
get_total_frame_count() {
    local input="$1"
    local frame_count
    
    # Try multiple methods for frame count detection
    frame_count=$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$input" 2>/dev/null)
    
    # Fallback method if first fails
    if [[ ! "$frame_count" =~ ^[0-9]+$ ]] || [[ $frame_count -eq 0 ]]; then
        frame_count=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_frames -of csv=p=0 "$input" 2>/dev/null)
    fi
    
    # Final fallback: estimate from duration and fps
    if [[ ! "$frame_count" =~ ^[0-9]+$ ]] || [[ $frame_count -eq 0 ]]; then
        local duration fps
        duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$input" 2>/dev/null)
        fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$input" 2>/dev/null)
        
        if [[ -n "$duration" && -n "$fps" ]]; then
            # Convert fps fraction to decimal
            fps=$(bc -l <<< "scale=3; $fps" 2>/dev/null || echo "25")
            frame_count=$(bc -l <<< "scale=0; $duration * $fps / 1" 2>/dev/null || echo "0")
        fi
    fi
    
    # Return 0 if we still couldn't determine frame count
    echo "${frame_count:-0}"
}

# Calculate adaptive update interval based on resolution and complexity
calculate_update_interval() {
    local resolution="$1"
    local complexity_score="${2:-50}"  # Default to medium complexity
    local encoding_mode="${3:-abr}"
    
    local base_interval=1
    
    # Adjust based on resolution - higher res = longer intervals to reduce overhead
    if [[ "$resolution" =~ (4k|2160p) ]]; then
        base_interval=3
    elif [[ "$resolution" =~ (1440p) ]]; then
        base_interval=2
    else
        base_interval=1
    fi
    
    # Adjust for complexity (higher complexity = longer intervals)
    if (( ${complexity_score%.*} > 70 )); then
        base_interval=$((base_interval + 2))
    elif (( ${complexity_score%.*} > 50 )); then
        base_interval=$((base_interval + 1))
    fi
    
    # Adjust for encoding mode
    case "$encoding_mode" in
        "cbr") base_interval=$((base_interval + 1)) ;;  # CBR is more intensive
        "crf") ;;  # CRF uses base interval
        "abr") ;;  # ABR uses base interval
    esac
    
    # Minimum interval is 1 second, maximum is 5 seconds
    if (( base_interval < 1 )); then base_interval=1; fi
    if (( base_interval > 5 )); then base_interval=5; fi
    
    echo "$base_interval"
}

# Parse FFmpeg progress with multiple fallback methods
parse_ffmpeg_progress() {
    local progress_file="$1"
    local total_duration="$2"
    local total_frames="$3"
    
    local progress_data out_time_us frame fps speed
    
    # Read last few lines to avoid race conditions and incomplete data
    if [[ ! -f "$progress_file" ]]; then
        echo "unknown:0:0:0:0"
        return
    fi
    
    # Use tail with multiple lines to be more robust against partial writes
    progress_data=$(tail -n 10 "$progress_file" 2>/dev/null | grep -E "(out_time_us|frame|fps|speed)=" | tail -n 6)
    
    if [[ -z "$progress_data" ]]; then
        echo "unknown:0:0:0:0"
        return
    fi
    
    # Extract metrics with fallbacks and improved FPS parsing
    out_time_us=$(echo "$progress_data" | grep "out_time_us=" | tail -n 1 | cut -d'=' -f2 | tr -d ' ' || echo "0")
    frame=$(echo "$progress_data" | grep "frame=" | tail -n 1 | cut -d'=' -f2 | tr -d ' ' || echo "0")
    fps=$(echo "$progress_data" | grep "fps=" | tail -n 1 | cut -d'=' -f2 | tr -d ' ' | sed 's/\..*$//' || echo "0")  # Remove decimals for display
    speed=$(echo "$progress_data" | grep "speed=" | tail -n 1 | cut -d'=' -f2 | tr -d ' x' || echo "1")
    
    # Calculate progress using both time and frame methods
    local time_progress=0
    local frame_progress=0
    local current_progress=0
    local method="unknown"
    
    # Time-based progress calculation
    if [[ "$out_time_us" =~ ^[0-9]+$ ]] && [[ $out_time_us -gt 0 ]] && [[ $total_duration -gt 0 ]]; then
        local total_duration_us=$((total_duration * 1000000))
        time_progress=$(bc -l <<< "scale=4; $out_time_us / $total_duration_us" 2>/dev/null || echo "0")
        method="time"
        current_progress="$time_progress"
    fi
    
    # Frame-based progress calculation (more reliable for some content)
    if [[ "$frame" =~ ^[0-9]+$ ]] && [[ $frame -gt 0 ]] && [[ $total_frames -gt 0 ]]; then
        frame_progress=$(bc -l <<< "scale=4; $frame / $total_frames" 2>/dev/null || echo "0")
        
        # Prefer frame-based if it's available and reasonable
        if (( $(echo "$frame_progress > 0 && $frame_progress <= 1" | bc -l) )); then
            method="frame"
            current_progress="$frame_progress"
        fi
    fi
    
    # Ensure progress doesn't exceed 1.0
    if (( $(echo "$current_progress > 1" | bc -l) )); then
        current_progress="1"
    fi
    
    # Return format: method:progress:fps:frame:speed
    echo "$method:$current_progress:$fps:$frame:$speed"
}

# Calculate ETA with exponential smoothing for stability
calculate_eta() {
    local current_progress="$1"
    local elapsed_time="$2"
    local fps="$3"
    local total_frames="$4"
    local speed="$5"
    
    local eta_estimate=0
    
    # Multiple ETA calculation methods for robustness
    
    # Method 1: Progress-based ETA
    if (( $(echo "$current_progress > 0.01" | bc -l) )); then
        local eta_progress
        eta_progress=$(bc -l <<< "scale=0; ($elapsed_time / $current_progress) - $elapsed_time" 2>/dev/null || echo "0")
        if [[ $eta_progress -gt 0 ]]; then
            eta_estimate="$eta_progress"
        fi
    fi
    
    # Method 2: Frame and FPS-based ETA (often more accurate)
    if [[ "$fps" =~ ^[0-9.]+$ ]] && (( $(echo "$fps > 0" | bc -l) )) && [[ $total_frames -gt 0 ]] && (( $(echo "$current_progress > 0" | bc -l) )); then
        local remaining_frames
        remaining_frames=$(bc -l <<< "scale=0; $total_frames * (1 - $current_progress)" 2>/dev/null || echo "0")
        if [[ $remaining_frames -gt 0 ]]; then
            local eta_frame
            eta_frame=$(bc -l <<< "scale=0; $remaining_frames / $fps" 2>/dev/null || echo "0")
            
            # Use frame-based ETA if it seems reasonable and differs significantly from progress-based
            if [[ $eta_frame -gt 0 ]] && [[ $eta_frame -lt $((eta_estimate * 2)) || $eta_estimate -eq 0 ]]; then
                eta_estimate="$eta_frame"
            fi
        fi
    fi
    
    # Method 3: Speed-adjusted ETA (if speed info available)
    if [[ "$speed" =~ ^[0-9.]+$ ]] && (( $(echo "$speed > 0" | bc -l) )) && [[ $eta_estimate -gt 0 ]]; then
        local eta_speed_adjusted
        eta_speed_adjusted=$(bc -l <<< "scale=0; $eta_estimate / $speed" 2>/dev/null || echo "$eta_estimate")
        if [[ $eta_speed_adjusted -gt 0 ]]; then
            eta_estimate="$eta_speed_adjusted"
        fi
    fi
    
    # Sanity check: don't return unreasonably long ETAs
    if [[ $eta_estimate -gt $((24 * 3600)) ]]; then  # More than 24 hours
        eta_estimate=0
    fi
    
    echo "${eta_estimate%.*}"  # Return integer seconds
}

# Format file size in human-readable format
format_file_size() {
    local bytes="$1"
    
    if [[ -z "$bytes" ]] || [[ "$bytes" -eq 0 ]]; then
        echo "0B"
        return
    fi
    
    local units=("B" "KB" "MB" "GB" "TB")
    local size="$bytes"
    local unit_index=0
    
    while (( $(echo "$size >= 1024" | bc -l 2>/dev/null || echo 0) )) && [[ $unit_index -lt 4 ]]; do
        size=$(bc -l <<< "scale=1; $size / 1024" 2>/dev/null || echo "$size")
        ((unit_index++))
    done
    
    # Remove trailing .0
    size=$(echo "$size" | sed 's/\.0$//')
    echo "${size}${units[$unit_index]}"
}

# Format duration in human-readable format
format_duration() {
    local total_seconds="$1"
    
    if [[ $total_seconds -le 0 ]]; then
        echo "calculating..."
        return
    fi
    
    local hours minutes seconds
    hours=$((total_seconds / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    seconds=$((total_seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
    else
        printf "%02d:%02d" "$minutes" "$seconds"
    fi
}

# Enhanced progress display with better formatting
show_enhanced_progress() {
    local description="$1"
    local current_progress="$2"
    local eta="$3"
    local current_size="$4"
    local estimated_size="$5"
    
    local percent
    percent=$(bc -l <<< "scale=1; $current_progress * 100" 2>/dev/null || echo "0.0")
    
    # Ensure percent is not empty and is a valid number
    if [[ -z "$percent" ]] || ! [[ "$percent" =~ ^[0-9]*\.?[0-9]*$ ]]; then
        percent="0.0"
    fi
    
    local eta_formatted
    if [[ $eta -gt 0 ]]; then
        eta_formatted=$(format_duration "$eta")
    else
        eta_formatted="calculating..."
    fi
    
    # Create progress bar (50 characters wide)
    local bar_length=50
    local filled_length
    filled_length=$(bc -l <<< "scale=0; $bar_length * $current_progress / 1" 2>/dev/null || echo "0")
    
    # Ensure filled_length is not empty and is a valid number
    if [[ -z "$filled_length" ]] || ! [[ "$filled_length" =~ ^[0-9]+$ ]]; then
        filled_length=0
    fi
    
    local progress_bar=""
    for ((i=1; i<=filled_length; i++)); do
        progress_bar+="#"
    done
    for ((i=filled_length+1; i<=bar_length; i++)); do
        progress_bar+=" "
    done
    
    
    # Print progress line with proper formatting
    # Convert percent to integer for printf compatibility
    local percent_int=${percent%.*}
    local percent_dec=${percent#*.}
    if [[ "$percent_dec" == "$percent" ]] || [[ -z "$percent_dec" ]]; then percent_dec="0"; fi
    
    # Ensure both values are valid numbers for printf
    if [[ -z "$percent_int" ]] || ! [[ "$percent_int" =~ ^[0-9]+$ ]]; then
        percent_int=0
    fi
    if [[ -z "$percent_dec" ]] || ! [[ "$percent_dec" =~ ^[0-9]+$ ]]; then
        percent_dec=0
    fi
    
    # Format size display: show estimated size with label
    local size_display
    if [[ -n "$estimated_size" ]]; then
        size_display="${estimated_size}"
    else
        size_display="calculating..."
    fi
    
    printf "\r\033[K%s: [%s] %3d.%01d%% | ETA: %11s | Estimated size: %12s" \
           "$description" \
           "$progress_bar" \
           "$percent_int" \
           "${percent_dec:0:1}" \
           "$eta_formatted" \
           "$size_display"
}

# Enhanced FFmpeg with robust real-time progress tracking
# Parameters: description, input_duration, profile_name, encoding_mode, then ffmpeg_command...
run_ffmpeg_with_progress() {
    local description="$1"
    local input_duration="$2"
    local profile_name="$3"
    local encoding_mode="$4"
    shift 4
    local cmd=("$@")
    
    log INFO "$description"
    
    # Get input and output files for tracking
    local input_file output_file
    for arg in "${cmd[@]}"; do
        if [[ -f "$arg" ]]; then
            input_file="$arg"
            break
        fi
    done
    
    # Extract output file (last argument that's not an option)
    for ((i=${#cmd[@]}-1; i>=0; i--)); do
        local arg="${cmd[i]}"
        if [[ "$arg" != -* ]] && [[ "$arg" != "$input_file" ]] && [[ "$arg" != *"="* ]]; then
            output_file="$arg"
            break
        fi
    done
    
    local total_frames=0
    if [[ -n "$input_file" ]]; then
        total_frames=$(get_total_frame_count "$input_file")
        log DEBUG "Total frames detected: $total_frames"
    fi
    
    # Calculate adaptive update interval using passed parameters
    local update_interval
    update_interval=$(calculate_update_interval "$profile_name" "${complexity_score:-50}" "$encoding_mode")
    log DEBUG "Using update interval: ${update_interval}s"
    
    # Temporary files
    local progress_file="${TEMP_DIR}/ffmpeg_progress_$$.txt"
    local stderr_file="${TEMP_DIR}/ffmpeg_stderr_$$.txt"
    
    # Extend FFmpeg command with progress output
    local ffmpeg_cmd=("${cmd[@]}")
    ffmpeg_cmd+=(-progress "$progress_file" -nostats)
    
    # Start FFmpeg in background
    "${ffmpeg_cmd[@]}" 2>"$stderr_file" &
    local pid=$!
    
    # Progress tracking variables
    local last_progress=0
    local stall_count=0
    local start_time
    start_time=$(date +%s)
    
    # Main progress monitoring loop
    while kill -0 "$pid" 2>/dev/null; do
        sleep "$update_interval"
        
        local elapsed_time=$(($(date +%s) - start_time))
        local progress_info
        progress_info=$(parse_ffmpeg_progress "$progress_file" "$input_duration" "$total_frames")
        
        IFS=':' read -r method current_progress fps frame speed <<< "$progress_info"
        
        # Get current output file size and calculate estimated final size
        local current_file_size="" estimated_final_size=""
        if [[ -f "$output_file" ]]; then
            local size_bytes
            size_bytes=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
            current_file_size=$(format_file_size "$size_bytes")
            
            # Calculate estimated final size if we have meaningful progress (>1%)
            if [[ -n "$current_progress" ]] && (( $(echo "$current_progress > 0.01" | bc -l 2>/dev/null || echo 0) )); then
                local estimated_bytes
                estimated_bytes=$(bc -l <<< "scale=0; $size_bytes / $current_progress" 2>/dev/null || echo "$size_bytes")
                estimated_final_size=$(format_file_size "$estimated_bytes")
            fi
        else
            current_file_size="0B"
        fi
        
        # Handle stalled progress
        if [[ "$method" != "unknown" ]]; then
            if [[ "$current_progress" == "$last_progress" ]]; then
                ((stall_count++))
                if [[ $stall_count -gt $((10 / update_interval)) ]]; then  # ~10 seconds of stall
                    # Just check if process is still running, no warning message
                    if ! kill -0 "$pid" 2>/dev/null; then
                        break
                    fi
                    stall_count=0  # Reset and continue
                fi
            else
                stall_count=0
            fi
        fi
        
        # Calculate ETA
        local eta
        eta=$(calculate_eta "$current_progress" "$elapsed_time" "$fps" "$total_frames" "$speed")
        
        # Update progress display
        if [[ "$method" != "unknown" ]] && [[ -n "$current_progress" ]] && (( $(echo "$current_progress >= 0" | bc -l 2>/dev/null || echo 0) )); then
            show_enhanced_progress "$description" "$current_progress" "$eta" "$current_file_size" "$estimated_final_size"
        else
            # Fallback to simple spinner for early stages
            printf "\r\033[K%s: Processing... [%ds elapsed]" "$description" "$elapsed_time"
        fi
        
        last_progress="$current_progress"
    done
    
    wait "$pid"
    local exit_code=$?
    
    # Final progress display
    if [[ $exit_code -eq 0 ]]; then
        local final_file_size="0B"
        if [[ -f "$output_file" ]]; then
            local size_bytes
            size_bytes=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
            final_file_size=$(format_file_size "$size_bytes")
        fi
        show_enhanced_progress "$description" "1" "0" "" "$final_file_size"
    fi
    printf "\n"
    
    # Error handling
    if [[ $exit_code -ne 0 && -f "$stderr_file" ]]; then
        log ERROR "FFmpeg failed with exit code $exit_code. Error output:"
        tail -n 20 "$stderr_file" >&2  # Show last 20 lines instead of entire file
    fi
    
    # Cleanup temporary files
    rm -f "$progress_file" "$stderr_file" 2>/dev/null || true
    
    return $exit_code
}

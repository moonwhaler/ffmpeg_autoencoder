#!/usr/bin/env bash

# Advanced FFmpeg Multi-Mode Encoding Script with Enhanced Grain Preservation
# Version: 2.4 - Content-Adaptive Encoding with Expert-Optimized Profiles
# CRF/ABR/CBR modes, Grain-Aware Analysis, and Automatic Parameter Optimization

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

# HINT: You can add new profiles anytime and also tweak certain 
#       parameters. HDR parameters will be added in the process, 
#       if HDR was found in the source video.

# 720p/1080p profiles 

# Modern 2D Anime (flat colors, minimal texture) - Target VMAF: 92-95
BASE_PROFILES["1080p_anime"]="title=1080p Modern Anime/2D Animation:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:ref=4:psy-rd=1.0:psy-rdoq=1.0:aq-mode=3:aq-strength=0.8:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:limit-refs=3:b-intra:weightb:weightp:cutree:scenecut=60:keyint=300:min-keyint=25:me=hex:subme=2:base_bitrate=2400:hdr_bitrate=2800:content_type=anime"

# Classic Anime with grain (90s content, film sources) - Target VMAF: 88-92 
BASE_PROFILES["1080p_classic_anime"]="title=1080p Classic Anime/2D Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:ref=6:psy-rd=1.5:psy-rdoq=2.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=40:keyint=240:min-keyint=24:me=umh:subme=3:base_bitrate=3800:hdr_bitrate=4400:content_type=classic_anime"

# 3D Animation/CGI (complex textures, gradients) - Target VMAF: 95-98
BASE_PROFILES["1080p_3d_animation"]="title=1080p 3D/CGI Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=6:psy-rd=2.0:psy-rdoq=1.5:aq-mode=3:aq-strength=1.0:deblock=0,0:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:b-intra:weightb:weightp:cutree:strong-intra-smoothing:me=umh:subme=4:merange=28:scenecut=45:keyint=250:min-keyint=25:base_bitrate=5800:hdr_bitrate=6800:content_type=3d_animation"

# Modern Live-Action Film (balanced approach) - Target VMAF: 90-94
BASE_PROFILES["1080p_film"]="title=1080p Live-Action Film:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=6:psy-rd=2.0:psy-rdoq=1.0:aq-mode=2:aq-strength=0.8:deblock=0,0:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:b-intra:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=40:keyint=240:min-keyint=24:base_bitrate=4600:hdr_bitrate=5400:content_type=film"

# Heavy Grain Film (classic films, archival) - Target VMAF: 85-90
BASE_PROFILES["1080p_heavygrain_film"]="title=1080p Heavy Grain Film:preset=slow:crf=17:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=5:b-adapt=2:ref=6:psy-rd=2.5:psy-rdoq=2.0:aq-mode=1:aq-strength=1.0:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.70:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=30:keyint=300:min-keyint=25:me=umh:subme=4:merange=28:base_bitrate=6200:hdr_bitrate=7400:content_type=heavy_grain"

# Light grain preservation (older films, some anime)
BASE_PROFILES["1080p_light_grain"]="title=1080p Light Grain Preservation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:b-adapt=2:ref=6:psy-rd=1.8:psy-rdoq=1.8:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.75:nr-intra=0:nr-inter=0:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=4200:hdr_bitrate=5000:content_type=light_grain"

# High-motion action content (sports, action films)
BASE_PROFILES["1080p_action"]="title=1080p High-Motion Action:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=4:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=40:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=5:merange=32:scenecut=25:keyint=120:min-keyint=12:base_bitrate=5200:hdr_bitrate=6200:content_type=action"

# Ultra-clean digital content (modern anime, digital intermediates)
BASE_PROFILES["1080p_clean_digital"]="title=1080p Clean Digital Content:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=0.8:aq-mode=3:aq-strength=0.7:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:nr-intra=2:nr-inter=2:b-intra:weightb:weightp:cutree:me=hex:subme=2:base_bitrate=2800:hdr_bitrate=3300:content_type=clean_digital"

# 4K Profiles 

# Modern 4K Anime (optimized for performance) - Target VMAF: 92-95
BASE_PROFILES["4k_anime"]="title=4K Modern Anime/2D Animation:preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:ref=4:psy-rd=1.0:psy-rdoq=1.0:aq-mode=3:aq-strength=0.8:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:limit-refs=3:b-intra:weightb:weightp:cutree:scenecut=60:keyint=300:min-keyint=25:me=hex:subme=2:base_bitrate=6800:hdr_bitrate=8000:content_type=anime"

# Classic 4K Anime with grain preservation - Target VMAF: 88-92
BASE_PROFILES["4k_classic_anime"]="title=4K Classic Anime/2D Animation:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:ref=6:psy-rd=1.5:psy-rdoq=2.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.65:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=40:keyint=240:min-keyint=25:me=umh:subme=3:base_bitrate=10200:hdr_bitrate=12000:content_type=classic_anime"

# 4K 3D Animation/CGI (balanced performance-quality) - Target VMAF: 95-98
BASE_PROFILES["4k_3d_animation"]="title=4K 3D/CGI Animation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=8:b-adapt=2:ref=5:psy-rd=2.0:psy-rdoq=1.5:aq-mode=3:aq-strength=1.0:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.65:b-intra:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=45:keyint=250:min-keyint=25:base_bitrate=13000:hdr_bitrate=15000:content_type=3d_animation"

# 4K Modern Film (production balance) - Target VMAF: 90-94
BASE_PROFILES["4k_film"]="title=4K Live-Action Film:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:sao:bframes=6:b-adapt=2:ref=5:psy-rd=2.0:psy-rdoq=1.0:aq-mode=2:aq-strength=0.8:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=3:merange=24:scenecut=40:keyint=240:min-keyint=25:base_bitrate=12600:hdr_bitrate=14800:content_type=film"

# 4K Heavy Grain Film (archival quality) - Target VMAF: 85-90
BASE_PROFILES["4k_heavygrain_film"]="title=4K Heavy Grain Film:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=5:b-adapt=2:ref=6:psy-rd=2.5:psy-rdoq=2.0:aq-mode=1:aq-strength=1.0:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=5:rdoq-level=2:qcomp=0.70:nr-intra=0:nr-inter=0:weightb:weightp:cutree:scenecut=30:keyint=300:min-keyint=25:me=umh:subme=3:merange=28:base_bitrate=14400:hdr_bitrate=17200:content_type=heavy_grain"

# Special Profile: Mixed content with moderate detail
BASE_PROFILES["4k_mixed_detail"]="title=4K Mixed Content Detail:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:sao:bframes=6:b-adapt=2:ref=5:psy-rd=1.8:psy-rdoq=1.2:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.7:weightb:weightp:cutree:me=umh:subme=3:merange=24:base_bitrate=13800:hdr_bitrate=16000:content_type=mixed"

# Light grain preservation (older films, some anime)
BASE_PROFILES["4k_light_grain"]="title=4K Light Grain Preservation:preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=6:b-adapt=2:ref=6:psy-rd=1.8:psy-rdoq=1.8:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=80:ctu=64:rd=4:rdoq-level=2:qcomp=0.75:nr-intra=0:nr-inter=0:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=11600:hdr_bitrate=13800:content_type=light_grain"

# High-motion action content (sports, action films)
BASE_PROFILES["4k_action"]="title=4K High-Motion Action:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:sao:bframes=4:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=3:aq-strength=0.9:deblock=0,0:rc-lookahead=40:ctu=64:rd=4:rdoq-level=2:qcomp=0.60:weightb:weightp:cutree:me=umh:subme=4:merange=28:scenecut=25:keyint=120:min-keyint=12:base_bitrate=14000:hdr_bitrate=16800:content_type=action"

# Ultra-clean digital content (modern anime, digital intermediates)
BASE_PROFILES["4k_clean_digital"]="title=4K Clean Digital Content:preset=slow:crf=22:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=0.8:aq-mode=3:aq-strength=0.7:deblock=1,1:rc-lookahead=60:ctu=64:rd=4:rdoq-level=2:qcomp=0.8:nr-intra=2:nr-inter=2:weightb:weightp:cutree:me=hex:subme=2:base_bitrate=7800:hdr_bitrate=9200:content_type=clean_digital"

BASE_PROFILES["4k"]="title=4K:preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:no-sao:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=1.0:aq-mode=2:aq-strength=0.9:deblock=-1,-1:rc-lookahead=40:ctu=32:rd=4:rdoq-level=2:qcomp=0.70:nr-intra=0:nr-inter=0:weightb:weightp:cutree:me=umh:subme=3:base_bitrate=12000:hdr_bitrate=15000:content_type=mixed"
BASE_PROFILES["4k_heavy_grain"]="title=4K Heavy Grain Film Optimized:preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:selective-sao=2:deblock=-1,-1:aq-mode=3:psy-rd=1.0:psy-rdoq=0.8:rskip=2:rskip-edge-threshold=2:bframes=5:b-adapt=2:ref=6:rc-lookahead=60:ctu=32:rd=4:rdoq-level=2:qcomp=0.75:vbv-maxrate=25000:vbv-bufsize=50000:nr-intra=25:nr-inter=100:keyint=240:min-keyint=24:me=umh:subme=7:merange=57:base_bitrate=12000:hdr_bitrate=15000:content_type=mixed"


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
    
    # Temporary file for capturing stderr output
    local stderr_file="${TEMP_DIR}/ffmpeg_stderr_$$.txt"
    
    # Start FFmpeg in background with stderr captured to avoid progress bar interference
    "${ffmpeg_cmd[@]}" 2>"$stderr_file" &
    local pid=$!
    
    # Monitor progress
    local current_time_us=0
    local last_progress_us=0
    local input_duration_us=$((input_duration * 1000000))  # Convert to microseconds
    
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -f "$progress_file" ]]; then
            # Read current progress from progress file - more robust parsing
            local out_time_us=$(grep "out_time_ms=" "$progress_file" 2>/dev/null | tail -1 | cut -d= -f2 || echo "0")
            
            if [[ "$out_time_us" =~ ^[0-9]+$ ]] && [[ $out_time_us -gt 0 ]]; then
                current_time_us=$out_time_us
                
                # Update progress bar more frequently and always show valid progress
                if [[ $input_duration_us -gt 0 ]]; then
                    # Clamp current_time_us to not exceed input_duration_us
                    if [[ $current_time_us -gt $input_duration_us ]]; then
                        current_time_us=$input_duration_us
                    fi
                    
                    # Update display if we have any progress change (using microseconds for smooth updates)
                    if [[ $current_time_us -gt $last_progress_us ]]; then
                        # Convert back to seconds for display
                        local current_seconds=$((current_time_us / 1000000))
                        show_progress "$current_seconds" "$input_duration" "$description"
                        last_progress_us=$current_time_us
                    fi
                fi
            fi
        fi
        sleep 0.2  # More frequent updates for better responsiveness
    done
    
    wait "$pid"
    local exit_code=$?
    
    # Show 100% on success
    if [[ $exit_code -eq 0 && $input_duration -gt 0 ]]; then
        show_progress "$input_duration" "$input_duration" "$description"
    fi
    printf "\n"
    
    # If there was an error, display the captured stderr for debugging
    if [[ $exit_code -ne 0 && -f "$stderr_file" ]]; then
        log ERROR "FFmpeg failed with exit code $exit_code. Error output:"
        cat "$stderr_file" >&2
    fi
    
    # Cleanup temporary files
    rm -f "$progress_file" "$stderr_file" 2>/dev/null || true
    
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

# Global variables for log file
LOG_FILE=""

# Initialize log file function
init_log_file() {
    local output_file=$1
    local log_dir="$(dirname "$output_file")"
    local log_basename="$(basename "$output_file")"
    local log_name="${log_basename%.*}.log"
    LOG_FILE="${log_dir}/${log_name}"
    
    # Create/clear the log file
    > "$LOG_FILE"
    
    log INFO "Log file initialized: $LOG_FILE"
}

# Logging function
log() {
    local level=$1; shift
    local msg=$*
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    local log_line="[${level}] ${ts} - ${msg}"
    
    case $level in
        INFO)  echo -e "${GREEN}[INFO]${NC} ${ts} - ${msg}" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN ]${NC} ${ts} - ${msg}" >&2 ;;
        ERROR) echo -e "${RED}[ERROR]${NC} ${ts} - ${msg}" >&2 ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} ${ts} - ${msg}" >&2 ;;
        ANALYSIS) echo -e "${PURPLE}[ANALYSIS]${NC} ${ts} - ${msg}" >&2 ;;
        CROP) echo -e "${CYAN}[CROP]${NC} ${ts} - ${msg}" >&2 ;;
    esac
    
    # Write to log file if it's set
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_line" >> "$LOG_FILE"
    fi
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

# Adjust bitrate based on complexity
calculate_adaptive_bitrate() {
    local base_bitrate=$1
    local complexity_score=$2
    local content_type=$3
    
    # Validate inputs - if base_bitrate is invalid, return it as-is
    if ! [[ "$base_bitrate" =~ ^[0-9]+k?$ ]]; then
        echo "$base_bitrate"  # Return original if invalid
        return
    fi
    [[ "$complexity_score" =~ ^[0-9.]+$ ]] || complexity_score="50"
    
    local base_value=$(echo "$base_bitrate" | sed 's/k$//')
    
    local type_modifier=1.0
    case $content_type in
        "anime")            type_modifier=0.90 ;;  # Increased from 0.85 - modern anime needs more bitrate
        "classic_anime")    type_modifier=0.85 ;;  # Keep original for classic content
        "3d_animation")     type_modifier=1.05 ;;  # Reduced from 1.1 - avoid over-allocation
        "film")             type_modifier=1.0 ;;   # Baseline
        "heavy_grain")      type_modifier=1.25 ;;  # Significant increase for grain preservation
        "light_grain")      type_modifier=1.10 ;;  # Moderate increase for light grain
        "action")           type_modifier=1.15 ;;  # Increased bitrate for motion complexity
        "clean_digital")    type_modifier=0.80 ;;  # Reduced bitrate for very clean content
        "mixed")            type_modifier=1.0 ;;   # Neutral for mixed content
    esac
    
    local complexity_factor
    complexity_factor=$(echo "scale=3; 0.7 + ($complexity_score / 100 * 0.6)" | bc -l 2>/dev/null || echo "1.0")
    [[ "$complexity_factor" =~ ^[0-9.]+$ ]] || complexity_factor="1.0"
    
    local adaptive_bitrate
    adaptive_bitrate=$(echo "scale=0; $base_value * $complexity_factor * $type_modifier / 1" | bc -l 2>/dev/null || echo "$base_value")
    [[ "$adaptive_bitrate" =~ ^[0-9]+$ ]] || adaptive_bitrate="$base_value"
    
    echo "${adaptive_bitrate}k"
}

# Adjust CRF based on complexity and content type
calculate_adaptive_crf() {
    local base_crf=$1
    local complexity_score=$2
    local content_type=$3
    
    # Validate inputs - if base_crf is invalid, return it as-is
    if ! [[ "$base_crf" =~ ^[0-9.]+$ ]]; then
        echo "$base_crf"  # Return original if invalid
        return
    fi
    [[ "$complexity_score" =~ ^[0-9.]+$ ]] || complexity_score="50"
    
    # Enhanced content-type specific CRF modifiers (based on expert analysis)
    local type_crf_modifier=0.0
    case $content_type in
        "anime")            type_crf_modifier=0.2 ;;   # Reduced from 0.5 - modern anime has detailed backgrounds
        "classic_anime")    type_crf_modifier=0.5 ;;   # Keep aggressive for classic anime
        "3d_animation")     type_crf_modifier=-0.4 ;;  # Reduced from -0.8 - avoid over-optimization
        "film")             type_crf_modifier=0.0 ;;   # Baseline for modern film
        "heavy_grain")      type_crf_modifier=-0.8 ;;  # Lower CRF for grain preservation
        "light_grain")      type_crf_modifier=-0.3 ;;  # Moderate CRF reduction for light grain
        "action")           type_crf_modifier=-0.2 ;;  # Slightly lower CRF for motion detail
        "clean_digital")    type_crf_modifier=0.3 ;;   # Higher CRF for very clean content
        "mixed")            type_crf_modifier=0.1 ;;   # Slightly conservative for mixed content
    esac
    
    # Complexity-based adjustment
    local complexity_adjustment
    complexity_adjustment=$(echo "scale=1; ($complexity_score - 50) * (-0.05)" | bc -l 2>/dev/null || echo "0")
    [[ "$complexity_adjustment" =~ ^-?[0-9.]+$ ]] || complexity_adjustment="0"
    
    # Apply both content-type and complexity adjustments
    local adaptive_crf
    adaptive_crf=$(echo "scale=1; $base_crf + $type_crf_modifier + $complexity_adjustment" | bc -l 2>/dev/null || echo "$base_crf")
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
    local denoise=$4
    local fc=""
    
    # Start with optional denoising filter
    if [[ "$denoise" == "true" ]]; then
        fc="[0:v]hqdn3d=1:1:2:2[denoised]"
        local current_label="denoised"
        log INFO "Pre-encode denoising enabled: hqdn3d=1:1:2:2 (light uniform grain reduction)"
    else
        fc="[0:v]null[v]"
        local current_label="v"
    fi
    
    # Apply cropping to the current stream
    local final_crop=""
    if [[ -n "$manual_crop" ]]; then
        final_crop="crop=$manual_crop"
        log DEBUG "Using manual crop: $manual_crop"
    elif [[ -n "$auto_crop" ]]; then
        final_crop="$auto_crop"
        log DEBUG "Using automatic crop: $auto_crop"
    fi
    
    if [[ -n "$final_crop" ]]; then
        if [[ "$denoise" == "true" ]]; then
            fc="${fc};[${current_label}]${final_crop}[v]"
        else
            fc="[0:v]${final_crop}[v]"
        fi
        current_label="v"
    elif [[ "$denoise" == "true" ]]; then
        # Rename denoised stream to 'v' for consistency
        fc="${fc};[${current_label}]null[v]"
        current_label="v"
    fi
    
    # Apply scaling if specified
    if [[ -n "$scale" ]]; then
        fc="${fc};[${current_label}]scale=$scale[v]"
    fi
    
    echo "$fc"
}

# Audio/Subs/Chapters Mapping
build_stream_mapping() {
    local f=$1 map=""
    
    local audio_streams=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams a -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    # Remove any newlines/whitespace
    audio_streams=$(echo "$audio_streams" | tr -d '\n\r ')
    if [[ "$audio_streams" =~ ^[0-9]+$ ]] && [[ $audio_streams -gt 0 ]]; then
        for i in $(seq 0 $((audio_streams-1))); do 
            map+=" -map 0:a:$i -c:a:$i copy"
        done
    fi
    
    local sub_streams=$(ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams s -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    # Remove any newlines/whitespace
    sub_streams=$(echo "$sub_streams" | tr -d '\n\r ')
    if [[ "$sub_streams" =~ ^[0-9]+$ ]] && [[ $sub_streams -gt 0 ]]; then
        for i in $(seq 0 $((sub_streams-1))); do 
            map+=" -map 0:s:$i -c:s:$i copy"
        done
    fi
    
    map+=" -map_chapters 0 -map_metadata 0"
    echo "$map"
}

# Parse base profile without complexity adaptation
parse_base_profile() {
    local profile_name=$1
    local str=${BASE_PROFILES[$profile_name]:-}
    [[ -n $str ]] || { log ERROR "Unknown profile: $profile_name"; exit 1; }
    
    # Extract base values from profile
    local base_bitrate=$(echo "$str" | grep -o 'base_bitrate=[^:]*' | cut -d= -f2)
    local base_crf=$(echo "$str" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    
    # Build final profile string with base parameters (remove metadata fields)
    local final_profile=$(echo "$str" | sed -E 's/(base_bitrate|hdr_bitrate|content_type)=[^:]*:?//g')
    final_profile=$(echo "$final_profile" | sed 's/::/:/g' | sed 's/:$//g')
    
    # Add bitrate and crf to final profile
    echo "${final_profile}:bitrate=${base_bitrate}:crf=${base_crf}"
}

# Parse profile and adapt through complexity analysis
parse_and_adapt_profile() {
    local profile_name=$1
    local input_file=$2
    local complexity_score=$3  # Add complexity_score as parameter
    local str=${BASE_PROFILES[$profile_name]:-}
    [[ -n $str ]] || { log ERROR "Unknown profile: $profile_name"; exit 1; }
    
    # HDR Detection
    local is_hdr=$(extract_hdr_metadata "$input_file")
    
    # Extract base values
    local base_bitrate=$(echo "$str" | grep -o 'base_bitrate=[^:]*' | cut -d= -f2)
    local hdr_bitrate=$(echo "$str" | grep -o 'hdr_bitrate=[^:]*' | cut -d= -f2)
    local base_crf=$(echo "$str" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    local content_type=$(echo "$str" | grep -o 'content_type=[^:]*' | cut -d= -f2)
    
    # Enhanced content type detection based on complexity analysis
    # Use grain level from complexity analysis to refine content type
    local grain_threshold=15
    if [[ "$content_type" == "anime" ]] && (( $(echo "$complexity_score > 60" | bc -l 2>/dev/null || echo 0) )); then
        content_type="classic_anime"
        log ANALYSIS "Content type refined to classic_anime based on complexity"
    elif [[ "$content_type" == "film" ]] && (( $(echo "$complexity_score > 80" | bc -l 2>/dev/null || echo 0) )); then
        content_type="heavy_grain"
        log ANALYSIS "Content type refined to heavy_grain based on complexity"
    fi
    
    # Use HDR bitrate if HDR content is detected
    local selected_bitrate="$base_bitrate"
    local selected_crf="$base_crf"
    if [[ "$is_hdr" == "true" ]]; then
        selected_bitrate="$hdr_bitrate"
        selected_crf=$(echo "scale=1; $base_crf + 2" | bc -l 2>/dev/null || echo "$base_crf")  # Slightly higher CRF for HDR
        log ANALYSIS "HDR content detected - using HDR optimized parameters"
    fi
    
    # Calculate adaptive parameters
    local adaptive_bitrate=$(calculate_adaptive_bitrate "$selected_bitrate" "$complexity_score" "$content_type")
    local adaptive_crf=$(calculate_adaptive_crf "$selected_crf" "$complexity_score" "$content_type")
    
    log ANALYSIS "Content Type: $content_type (refined from profile analysis)"
    log ANALYSIS "Adaptive parameters - Bitrate: $selected_bitrate → $adaptive_bitrate, CRF: $selected_crf → $adaptive_crf"
    log ANALYSIS "Complexity Score: $complexity_score (grain-aware calculation)"
    
    # Update profile with adaptive values and remove helper fields
    local adapted_profile=$(echo "$str" | sed "s|base_bitrate=[^:]*|bitrate=$adaptive_bitrate|" | sed "s|hdr_bitrate=[^:]*||" | sed "s|crf=[^:]*|crf=$adaptive_crf|" | sed 's|title=[^:]*:||' | sed 's|content_type=[^:]*||' | sed 's|::|:|g' | sed 's|^:||' | sed 's|:$||')
    
    # Add HDR-specific parameters if HDR content is detected
    if [[ "$is_hdr" == "true" ]]; then
        adapted_profile="${adapted_profile}:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1"
        log ANALYSIS "HDR encoding parameters added"
    fi
    
    echo "$adapted_profile"
}

# Log profile and encoding details
log_profile_details() {
    local profile_name=$1
    local mode=$2
    local adapted_profile=$3
    local complexity_score=$4
    local input_file=$5
    local output_file=$6
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE"
        echo "=== ENCODING SESSION DETAILS ===" >> "$LOG_FILE"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "Input File: $input_file" >> "$LOG_FILE"
        echo "Output File: $output_file" >> "$LOG_FILE"
        echo "Profile: $profile_name" >> "$LOG_FILE"
        echo "Encoding Mode: $mode" >> "$LOG_FILE"
        echo "Complexity Score: $complexity_score" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Extract and log profile details
        local profile_title=$(echo "${BASE_PROFILES[$profile_name]}" | grep -o 'title=[^:]*' | cut -d= -f2)
        local content_type=$(echo "${BASE_PROFILES[$profile_name]}" | grep -o 'content_type=[^:]*' | cut -d= -f2)
        
        echo "=== PROFILE INFORMATION ===" >> "$LOG_FILE"
        echo "Profile Title: $profile_title" >> "$LOG_FILE"
        echo "Content Type: $content_type" >> "$LOG_FILE"
        echo "Base Profile String: ${BASE_PROFILES[$profile_name]}" >> "$LOG_FILE"
        echo "Adapted Profile String: $adapted_profile" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Extract specific encoding parameters
        local bitrate=$(echo "$adapted_profile" | grep -o 'bitrate=[^:]*' | cut -d= -f2)
        local crf=$(echo "$adapted_profile" | grep -o 'crf=[^:]*' | cut -d= -f2)
        local preset=$(echo "$adapted_profile" | grep -o 'preset=[^:]*' | cut -d= -f2)
        local pix_fmt=$(echo "$adapted_profile" | grep -o 'pix_fmt=[^:]*' | cut -d= -f2)
        local profile_codec=$(echo "$adapted_profile" | grep -o 'profile=[^:]*' | cut -d= -f2)
        
        echo "=== ENCODING PARAMETERS ===" >> "$LOG_FILE"
        echo "Bitrate: $bitrate" >> "$LOG_FILE"
        echo "CRF: $crf" >> "$LOG_FILE"
        echo "Preset: $preset" >> "$LOG_FILE"
        echo "Pixel Format: $pix_fmt" >> "$LOG_FILE"
        echo "Codec Profile: $profile_codec" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
}

# Enhanced encoding with mode support (ABR/CRF/CBR)
run_encoding() {
    local in=$1 out=$2 prof=$3 title=$4 manual_crop=$5 scale=$6 mode=$7 use_complexity=$8 denoise=$9

    # Initialize log file
    init_log_file "$out"
    
    log INFO "Profile: $prof"
    
    # Video duration for progress
    local input_duration=$(get_video_duration "$in")
    
    # Automatic crop detection
    local auto_crop=""
    if [[ -z "$manual_crop" ]]; then
        auto_crop=$(detect_crop_values "$in")
        log INFO "Crop detection completed."
    fi
    
    # Get complexity score and adapted profile based on parameter
    local complexity_score="50"  # Default neutral complexity
    local ps=""
    
    if [[ "$use_complexity" == "true" ]]; then
        log ANALYSIS "Starting content analysis for adaptive parameter optimization..."
        complexity_score=$(perform_complexity_analysis "$in")
        ps=$(parse_and_adapt_profile "$prof" "$in" "$complexity_score")
    else
        # Use base profile without complexity analysis
        log INFO "Using base profile without complexity analysis"
        ps=$(parse_base_profile "$prof")
    fi
    
    # Log profile details to file
    log_profile_details "$prof" "$mode" "$ps" "$complexity_score" "$in" "$out"
    
    local bitrate=$(echo "$ps" | grep -o 'bitrate=[^:]*' | cut -d= -f2)
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's|title=[^:]*:||;s|preset=[^:]*:||;s|bitrate=[^:]*:||;s|pix_fmt=[^:]*:||;s|profile=[^:]*:||;s|crf=[^:]*:||;s|crf=[^:]*$||;s|base_bitrate=[^:]*:||;s|hdr_bitrate=[^:]*:||;s|content_type=[^:]*:||;s|^:||;s|:$||' | sed 's|:sao:|:sao=1:|g; s|:no-sao:|:sao=0:|g; s|:b-intra:|:b-intra=1:|g; s|:weightb:|:weightb=1:|g; s|:weightp:|:weightp=1:|g; s|:cutree:|:cutree=1:|g; s|:strong-intra-smoothing:|:strong-intra-smoothing=1:|g; s|^sao:|sao=1:|; s|^no-sao:|sao=0:|; s|^b-intra:|b-intra=1:|; s|^weightb:|weightb=1:|; s|^weightp:|weightp=1:|; s|^cutree:|cutree=1:|; s|^strong-intra-smoothing:|strong-intra-smoothing=1:|')
    local fc=$(build_filter_chain "$manual_crop" "$scale" "$auto_crop" "$denoise" 2>/dev/null)
    local streams=$(build_stream_mapping "$in")
    local stats="$TEMP_DIR/${STATS_PREFIX}_$(basename "$in" .${in##*.}).log"

    log INFO "Encoding mode: $mode - Adaptive parameters - Bitrate: $bitrate, CRF: $crf"
    
    # Execute encoding based on mode
    case $mode in
        "crf")
            run_crf_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration"
            ;;
        "cbr")
            run_cbr_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration" "$bitrate" "$stats"
            ;;
        "abr"|*)
            run_abr_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration" "$bitrate" "$stats"
            ;;
    esac
    
    # Final statistics
    local input_size=$(du -h "$in" | cut -f1)
    local output_size=$(du -h "$out" | cut -f1)
    local compression_ratio=$(echo "scale=1; $(du -k "$in" | cut -f1) / $(du -k "$out" | cut -f1)" | bc -l 2>/dev/null || echo "N/A")
    log INFO "Compression: $input_size → $output_size (Ratio: ${compression_ratio}:1)"
    log INFO "Encoding completed successfully!"
    
    # Log final statistics to file
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== ENCODING RESULTS ===" >> "$LOG_FILE"
        echo "Input Size: $input_size" >> "$LOG_FILE"
        echo "Output Size: $output_size" >> "$LOG_FILE"
        echo "Compression Ratio: ${compression_ratio}:1" >> "$LOG_FILE"
        echo "Encoding Status: SUCCESS" >> "$LOG_FILE"
        echo "Completion Time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "=== LOG END ===" >> "$LOG_FILE"
    fi
}

# Single-pass CRF encoding (Pure VBR)
run_crf_encoding() {
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7
    
    local bitrate=$(echo "$ps" | grep -o 'bitrate=[^:]*' | cut -d= -f2)
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's|title=[^:]*:||;s|preset=[^:]*:||;s|bitrate=[^:]*:||;s|pix_fmt=[^:]*:||;s|profile=[^:]*:||;s|crf=[^:]*:||;s|crf=[^:]*$||;s|base_bitrate=[^:]*:||;s|hdr_bitrate=[^:]*:||;s|content_type=[^:]*:||;s|^:||;s|:$||' | sed 's|:sao:|:sao=1:|g; s|:no-sao:|:sao=0:|g; s|:b-intra:|:b-intra=1:|g; s|:weightb:|:weightb=1:|g; s|:weightp:|:weightp=1:|g; s|:cutree:|:cutree=1:|g; s|:strong-intra-smoothing:|:strong-intra-smoothing=1:|g; s|^sao:|sao=1:|; s|^no-sao:|sao=0:|; s|^b-intra:|b-intra=1:|; s|^weightb:|weightb=1:|; s|^weightp:|weightp=1:|; s|^cutree:|cutree=1:|; s|^strong-intra-smoothing:|strong-intra-smoothing=1:|')
    
    log INFO "Starting single-pass CRF encoding (Pure VBR)..."
    
    # Log encoding pass details
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== CRF ENCODING PASS ===" >> "$LOG_FILE"
        echo "Pass Type: Single-pass CRF (Pure VBR)" >> "$LOG_FILE"
        echo "CRF Value: $crf" >> "$LOG_FILE"
        echo "Preset: $preset" >> "$LOG_FILE"
        echo "Pixel Format: $pix_fmt" >> "$LOG_FILE"
        echo "Codec Profile: $profile_codec" >> "$LOG_FILE"
        echo "x265 Parameters: $x265p" >> "$LOG_FILE"
        echo "Filter Chain: $fc" >> "$LOG_FILE"
        echo "Stream Mapping: $streams" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    # Single-pass CRF command (remove bitrate completely)
    local cmd=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd+=(-metadata title="$title")
    [[ -n $fc ]] && cmd+=(-filter_complex "$fc" -map "[v]") || cmd+=(-map 0:v:0)
    cmd+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd+=(-crf "$crf" -preset:v "$preset")
    # Clean x265 params by removing any bitrate references
    local clean_x265p=$(echo "$x265p" | sed 's|bitrate=[^:]*:||g;s|:bitrate=[^:]*||g;s|^bitrate=[^:]*$||g')
    [[ -n "$clean_x265p" ]] && cmd+=(-x265-params "$clean_x265p")
    cmd+=($streams -default_mode infer_no_subs -loglevel warning "$out")
    
    # Log the full command
    if [[ -n "$LOG_FILE" ]]; then
        echo "Command: ${cmd[*]}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    run_ffmpeg_with_progress "CRF Encoding (Single Pass)" "$input_duration" "${cmd[@]}" || { 
        log ERROR "CRF encoding failed"; exit 1; 
    }
}

# Two-pass CBR encoding
run_cbr_encoding() {
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7 bitrate=$8 stats=$9
    
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's|title=[^:]*:||;s|preset=[^:]*:||;s|bitrate=[^:]*:||;s|pix_fmt=[^:]*:||;s|profile=[^:]*:||;s|crf=[^:]*:||;s|crf=[^:]*$||;s|base_bitrate=[^:]*:||;s|hdr_bitrate=[^:]*:||;s|content_type=[^:]*:||;s|^:||;s|:$||' | sed 's|:sao:|:sao=1:|g; s|:no-sao:|:sao=0:|g; s|:b-intra:|:b-intra=1:|g; s|:weightb:|:weightb=1:|g; s|:weightp:|:weightp=1:|g; s|:cutree:|:cutree=1:|g; s|:strong-intra-smoothing:|:strong-intra-smoothing=1:|g; s|^sao:|sao=1:|; s|^no-sao:|sao=0:|; s|^b-intra:|b-intra=1:|; s|^weightb:|weightb=1:|; s|^weightp:|weightp=1:|; s|^cutree:|cutree=1:|; s|^strong-intra-smoothing:|strong-intra-smoothing=1:|')
    
    # Calculate CBR buffer constraints
    local bitrate_value=$(echo "$bitrate" | sed 's/k$//')
    local maxrate="${bitrate}"
    local minrate="${bitrate}"
    local bufsize="$((bitrate_value * 3 / 2))k"  # 1.5x bitrate for buffer
    
    log INFO "Starting two-pass CBR encoding (Constant Bitrate)..."
    log INFO "CBR Parameters - Rate: $bitrate, Buffer: $bufsize"
    
    # Log CBR encoding details
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== CBR ENCODING PASSES ===" >> "$LOG_FILE"
        echo "Pass Type: Two-pass CBR (Constant Bitrate)" >> "$LOG_FILE"
        echo "Target Bitrate: $bitrate" >> "$LOG_FILE"
        echo "Min Rate: $minrate" >> "$LOG_FILE"
        echo "Max Rate: $maxrate" >> "$LOG_FILE"
        echo "Buffer Size: $bufsize" >> "$LOG_FILE"
        echo "Preset: $preset" >> "$LOG_FILE"
        echo "Pixel Format: $pix_fmt" >> "$LOG_FILE"
        echo "Codec Profile: $profile_codec" >> "$LOG_FILE"
        echo "x265 Parameters: $x265p" >> "$LOG_FILE"
        echo "Stats File: $stats" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi

    # First pass with progress
    local cmd1=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd1+=(-metadata title="$title")
    [[ -n $fc ]] && cmd1+=(-filter_complex "$fc" -map "[v]") || cmd1+=(-map 0:v:0)
    cmd1+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd1+=(-x265-params "$x265p:pass=1:no-slow-firstpass=1:stats=$stats")
    cmd1+=(-b:v "$bitrate" -minrate "$minrate" -maxrate "$maxrate" -bufsize "$bufsize")
    cmd1+=(-preset:v slow -an -sn -dn -f mp4 -loglevel warning /dev/null)
    
    # Log first pass command
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== CBR FIRST PASS ===" >> "$LOG_FILE"
        echo "Command: ${cmd1[*]}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    run_ffmpeg_with_progress "CBR First Pass (Analysis)" "$input_duration" "${cmd1[@]}" || { 
        log ERROR "CBR first pass failed"; exit 1; 
    }

    # Second pass with progress
    local cmd2=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd2+=(-metadata title="$title")
    [[ -n $fc ]] && cmd2+=(-filter_complex "$fc" -map "[v]") || cmd2+=(-map 0:v:0)
    cmd2+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd2+=(-x265-params "$x265p:pass=2:stats=$stats")
    cmd2+=(-b:v "$bitrate" -minrate "$minrate" -maxrate "$maxrate" -bufsize "$bufsize")
    cmd2+=(-preset:v "$preset")
    cmd2+=($streams -default_mode infer_no_subs -loglevel warning "$out")
    
    # Log second pass command
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== CBR SECOND PASS ===" >> "$LOG_FILE"
        echo "Command: ${cmd2[*]}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    run_ffmpeg_with_progress "CBR Second Pass (Final Encoding)" "$input_duration" "${cmd2[@]}" || { 
        log ERROR "CBR second pass failed"; exit 1; 
    }
    
    # Cleanup stats
    rm -f "${stats}"* 2>/dev/null || true
}

# Two-pass ABR encoding (current behavior)
run_abr_encoding() {
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7 bitrate=$8 stats=$9
    
    # Ensure bitrate has 'k' suffix for FFmpeg
    if [[ "$bitrate" =~ ^[0-9]+$ ]]; then
        bitrate="${bitrate}k"
    fi
    
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | head -1 | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's|title=[^:]*:||;s|preset=[^:]*:||;s|bitrate=[^:]*:||;s|pix_fmt=[^:]*:||;s|profile=[^:]*:||;s|crf=[^:]*:||;s|crf=[^:]*$||;s|base_bitrate=[^:]*:||;s|hdr_bitrate=[^:]*:||;s|content_type=[^:]*:||;s|^:||;s|:$||' | sed 's|:sao:|:sao=1:|g; s|:no-sao:|:sao=0:|g; s|:b-intra:|:b-intra=1:|g; s|:weightb:|:weightb=1:|g; s|:weightp:|:weightp=1:|g; s|:cutree:|:cutree=1:|g; s|:strong-intra-smoothing:|:strong-intra-smoothing=1:|g; s|^sao:|sao=1:|; s|^no-sao:|sao=0:|; s|^b-intra:|b-intra=1:|; s|^weightb:|weightb=1:|; s|^weightp:|weightp=1:|; s|^cutree:|cutree=1:|; s|^strong-intra-smoothing:|strong-intra-smoothing=1:|')
    
    log INFO "Starting two-pass ABR encoding (Average Bitrate)..."
    
    # Log ABR encoding details
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== ABR ENCODING PASSES ===" >> "$LOG_FILE"
        echo "Pass Type: Two-pass ABR (Average Bitrate)" >> "$LOG_FILE"
        echo "Target Bitrate: $bitrate" >> "$LOG_FILE"
        echo "Preset: $preset" >> "$LOG_FILE"
        echo "Pixel Format: $pix_fmt" >> "$LOG_FILE"
        echo "Codec Profile: $profile_codec" >> "$LOG_FILE"
        echo "x265 Parameters: $x265p" >> "$LOG_FILE"
        echo "Stats File: $stats" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi

    local cmd1=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd1+=(-metadata title="$title")
    [[ -n $fc ]] && cmd1+=(-filter_complex "$fc" -map "[v]") || cmd1+=(-map 0:v:0)
    cmd1+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd1+=(-x265-params "$x265p:pass=1:no-slow-firstpass=1:stats=$stats")
    cmd1+=(-b:v "$bitrate" -preset:v slow -an -sn -dn -f mp4 -loglevel warning /dev/null)
    
    # Log first pass command
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== ABR FIRST PASS ===" >> "$LOG_FILE"
        echo "Command: ${cmd1[*]}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    run_ffmpeg_with_progress "ABR First Pass (Analysis)" "$input_duration" "${cmd1[@]}" || { 
        log ERROR "ABR first pass failed"; exit 1; 
    }

    # Second pass with progress
    local cmd2=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd2+=(-metadata title="$title")
    [[ -n $fc ]] && cmd2+=(-filter_complex "$fc" -map "[v]") || cmd2+=(-map 0:v:0)
    cmd2+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd2+=(-x265-params "$x265p:pass=2:stats=$stats")
    cmd2+=(-b:v "$bitrate" -preset:v "$preset")
    cmd2+=($streams -default_mode infer_no_subs -loglevel warning "$out")
    
    # Log second pass command
    if [[ -n "$LOG_FILE" ]]; then
        echo "=== ABR SECOND PASS ===" >> "$LOG_FILE"
        echo "Command: ${cmd2[*]}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
    fi
    
    run_ffmpeg_with_progress "ABR Second Pass (Final Encoding)" "$input_duration" "${cmd2[@]}" || { 
        log ERROR "ABR second pass failed"; exit 1; 
    }

    # Cleanup stats
    rm -f "${stats}"* 2>/dev/null || true
}

# Show help function
show_help() {
    echo "Advanced FFmpeg Encoder with Multi-Mode Support, Grain Preservation and HDR Detection"
    echo "Version: 2.4 - Content-Adaptive Encoding with Enhanced Grain Preservation"
    echo "Usage: $0 -i INPUT [-o OUTPUT] -p PROFILE [OPTIONS]"
    echo ""
    echo "Available Profiles (Optimized for Quality and Grain Preservation):"
    echo ""
    
    # Group profiles by category for better readability
    echo "  === 1080p Profiles ==="
    for profile in $(printf '%s\n' "${!BASE_PROFILES[@]}" | grep "^1080p" | sort); do
        local profile_data="${BASE_PROFILES[$profile]}"
        local title=$(echo "$profile_data" | grep -o 'title=[^:]*' | cut -d= -f2)
        printf "  %-25s %s\n" "$profile" "$title"
    done
    
    echo ""
    echo "  === 4K Profiles ==="
    for profile in $(printf '%s\n' "${!BASE_PROFILES[@]}" | grep "^4k" | sort); do
        local profile_data="${BASE_PROFILES[$profile]}"
        local title=$(echo "$profile_data" | grep -o 'title=[^:]*' | cut -d= -f2)
        printf "  %-25s %s\n" "$profile" "$title"
    done
    
    echo ""
    echo "Encoding Modes:"
    echo "  crf    Single-pass Constant Rate Factor (Pure VBR) - Best for archival/mastering"
    echo "  abr    Two-pass Average Bitrate (Default) - Best for streaming/delivery"
    echo "  cbr    Two-pass Constant Bitrate - Best for broadcast/live streaming"
    echo ""
    echo "Options:"
    echo "  -i, --input   Input video file"
    echo "  -o, --output  Output video file (optional, defaults to input_UUID.ext)"  
    echo "  -p, --profile Encoding profile (content-type based)"
    echo "  -m, --mode    Encoding mode: crf, abr, cbr (default: abr)"
    echo "  -t, --title   Video title metadata"
    echo "  -c, --crop       Manual crop (format: w:h:x:y)"
    echo "  -s, --scale      Scale resolution (format: w:h)"
    echo "  --denoise        Enable light pre-encode denoising (hqdn3d=1:1:2:2) for uniform grain"
    echo "  --use-complexity Enable complexity analysis for adaptive parameter optimization"
    echo "  --web-search     Enable web search for content validation (default: enabled)"
    echo "  --web-search-force  Force web search even with high technical confidence"
    echo "  --no-web-search  Disable web search validation"
    echo "  -h, --help       Show this help"
    echo ""
    echo "🔬 COMPLEXITY ANALYSIS:"
    echo "  By default, profiles use their base parameters without modification."
    echo "  Use --use-complexity to enable adaptive parameter optimization."
    echo ""
    echo "  When enabled, the system analyzes:"
    echo "    • Content type (anime, 3D animation, live-action film)"
    echo "    • Grain characteristics (heavy, light, clean digital)"
    echo "    • Motion complexity (action, standard, low-motion)"
    echo "    • Visual complexity and edge density"
    echo "    • HDR detection and resolution"
    echo ""
    echo "🤖 AUTOMATIC PROFILE SELECTION:"
    echo "  Use -p auto to enable intelligent profile selection based on content analysis."
    echo "  Note: Auto selection always uses complexity analysis regardless of --use-complexity flag."
    echo ""
    echo "📚 MANUAL PROFILE SELECTION:"
    echo "  Content Type Recommendations:"
    echo "    Simple 2D Anime:     1080p_anime, 4k_anime (flat colors, minimal texture)"
    echo "    Classic 90s Anime:   1080p_classic_anime, 4k_classic_anime (film grain)"
    echo "    3D CGI Films:        1080p_3d_animation, 4k_3d_animation (complex textures)"
    echo "    Modern Films:        1080p_film, 4k_film (balanced live-action)"
    echo "    Heavy Grain Films:   1080p_heavygrain_film, 4k_heavygrain_film (preservation)"
    echo "    Light Grain:         1080p_light_grain, 4k_light_grain (moderate preservation)"
    echo "    High-Motion:         1080p_action, 4k_action (sports, action sequences)"
    echo "    Clean Digital:       1080p_clean_digital, 4k_clean_digital (minimal noise)"
    echo ""
    echo "Examples:"
    echo ""
    echo "🤖 Automatic Profile Selection:"
    echo "  $0 -i movie.mkv -p auto -m crf                               # Let AI choose best profile"
    echo "  $0 -i anime.mp4 -p auto -m abr                               # Automatic anime detection"
    echo "  $0 -i video.mkv -p auto -o custom_name.mkv -m cbr             # Auto with custom output"
    echo ""
    echo "📚 Manual Profile Selection:"
    echo "  $0 -i input.mkv -o output.mkv -p 1080p_anime -m crf           # Single-pass CRF"
    echo "  $0 -i input.mkv -p 4k_film -m abr                           # Two-pass ABR with UUID output"
    echo "  $0 -i input.mkv -o output.mkv -p 1080p_heavygrain_film -m crf # Grain preservation"
    echo "  $0 -i input.mkv -p 1080p_classic_anime -m abr                # Classic anime with grain"
    echo "  $0 -i input.mkv -o output.mkv -p 4k_action -m cbr             # High-motion CBR"
    echo "  $0 -i classic_film.mkv -p 1080p_film --denoise -m crf        # Light denoising for uniform grain"
    echo ""
}

# Main function
main() {
    local input="" output="" profile="" title="" crop="" scale="" mode="abr" web_search_enabled="true" use_complexity_analysis="false" denoise="false"

    # Check dependencies
    for tool in ffmpeg ffprobe bc uuidgen; do
        command -v $tool >/dev/null || { log ERROR "$tool missing (install: apt install $tool)"; exit 1; }
    done

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)    
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Input file not specified for option $1"
                    show_help
                    exit 1
                fi
                input="$2"; shift 2 ;;
            -o|--output)   
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Output file not specified for option $1"
                    show_help
                    exit 1
                fi
                output="$2"; shift 2 ;;
            -p|--profile)  
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Profile not specified for option $1"
                    show_help
                    exit 1
                fi
                profile="$2"; shift 2 ;;
            -t|--title)    
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Title not specified for option $1"
                    show_help
                    exit 1
                fi
                title="$2"; shift 2 ;;
            -c|--crop)     
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Crop parameters not specified for option $1"
                    show_help
                    exit 1
                fi
                crop="$2"; shift 2 ;;
            -s|--scale)    
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Scale parameters not specified for option $1"
                    show_help
                    exit 1
                fi
                scale="$2"; shift 2 ;;
            -m|--mode)     
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Mode not specified for option $1"
                    show_help
                    exit 1
                fi
                mode="$2"; shift 2 ;;
            --web-search)
                web_search_enabled="true"
                shift ;;
            --web-search-force)
                web_search_enabled="force"
                shift ;;
            --no-web-search)
                web_search_enabled="false"
                shift ;;
            --use-complexity)
                use_complexity_analysis="true"
                shift ;;
            --denoise)
                denoise="true"
                shift ;;
            -h|--help)     
                show_help
                exit 0 ;;
            -*) 
                log ERROR "Unknown option: $1"
                show_help
                exit 1 ;;
            *) 
                log ERROR "Invalid argument: $1"
                show_help
                exit 1 ;;
        esac
    done

    # Generate UUID-based output filename if not provided
    if [[ -z $output ]]; then
        if [[ -z $input ]]; then
            log ERROR "Input file (-i) is required"
            show_help
            exit 1
        fi
        local basename="$(basename "$input")"
        local name="${basename%.*}"
        local ext="${basename##*.}"
        local uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
        local input_dir="$(dirname "$input")"
        output="${input_dir}/${name}_${uuid}.${ext}"
        log INFO "Generated output filename: $(basename "$output")"
    fi
    
    if [[ -z $input || -z $profile ]]; then
        log ERROR "Missing required arguments: -i INPUT -p PROFILE"
        show_help
        exit 1
    fi
    
    # Handle automatic profile selection
    if [[ "$profile" == "auto" ]]; then
        log INFO "Automatic profile selection requested..."
        
        local selector_script="$(dirname "$0")/automatic_profile_selector.sh"
        if [[ -f "$selector_script" ]]; then
            log INFO "Running intelligent content analysis..."
            local selected_profile
            
            # Use different analysis modes based on encoding mode for efficiency
            local analysis_mode="fast"
            case "$mode" in
                "crf")
                    analysis_mode="comprehensive"  # CRF benefits from thorough analysis
                    ;;
                "abr")
                    analysis_mode="fast"           # ABR is more forgiving
                    ;;
                "cbr")
                    analysis_mode="fast"           # CBR for broadcast doesn't need deep analysis
                    ;;
            esac
            
            # Run the selector (quiet mode for integration)
            local selector_args=(-i "$input" -m "$analysis_mode" -q)
            
            # Add web search parameter based on setting
            case "$web_search_enabled" in
                "true")
                    selector_args+=(--web-search)
                    ;;
                "force")
                    selector_args+=(--web-search-force)
                    ;;
                "false")
                    # No web search parameter added
                    ;;
            esac
            
            if selected_profile=$(bash "$selector_script" "${selector_args[@]}" 2>/dev/null); then
                if [[ -n "$selected_profile" ]] && [[ -n "${BASE_PROFILES[$selected_profile]:-}" ]]; then
                    profile="$selected_profile"
                    log INFO "Automatically selected profile: $profile"
                else
                    log WARN "Automatic selection returned invalid profile: $selected_profile"
                    # Fallback profile selection
                    profile=$(select_fallback_profile "$input")
                    log INFO "Using fallback profile: $profile"
                fi
            else
                log WARN "Automatic profile selection failed"
                # Fallback profile selection
                profile=$(select_fallback_profile "$input")
                log INFO "Using fallback profile: $profile"
            fi
        else
            log WARN "Automatic profile selector not found, using fallback"
            profile=$(select_fallback_profile "$input")
            log INFO "Using fallback profile: $profile"
        fi
    fi
    
    # Validate profile parameter
    if [[ -z "${BASE_PROFILES[$profile]:-}" ]]; then
        log ERROR "Unknown profile: $profile"
        show_help
        exit 1
    fi
    
    # Validate mode parameter
    case $mode in
        "crf"|"abr"|"cbr") ;; # Valid modes
        *) 
            log ERROR "Invalid mode: $mode. Use: crf, abr, or cbr"
            show_help
            exit 1 ;;
    esac
    
    validate_input "$input"

    log INFO "Starting content-adaptive encoding with auto-crop and HDR detection..."
    run_encoding "$input" "$output" "$profile" "$title" "$crop" "$scale" "$mode" "$use_complexity_analysis" "$denoise"
}

# Execute script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

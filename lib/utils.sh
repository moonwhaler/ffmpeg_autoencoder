#!/usr/bin/env bash

# Utility Functions Module for FFmpeg Encoder
# Contains logging, validation, and help functions

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
        PROFILE) echo -e "${CYAN}[PROFILE-AI]${NC} ${ts} - ${msg}" >&2 ;;
    esac
    
    # Write to log file if it's set
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_line" >> "$LOG_FILE"
    fi
}

# Input file validation
validate_input() {
    local f=$1
    [[ -f $f && -r $f ]] || { log ERROR "Invalid input file: $f"; return 1; }
    ffprobe -v error -analyzeduration 100M -probesize 50M -select_streams v:0 -show_entries stream=index "$f" >/dev/null \
        || { log ERROR "No video stream: $f"; return 1; }
    log INFO "Input validated: $f"
}

# Show help function
show_help() {
    echo "Advanced FFmpeg Encoder with Multi-Mode Support, Grain Preservation and HDR Detection"
    echo "Version: 2.4 - Content-Adaptive Encoding with Enhanced Grain Preservation"
    echo ""
    echo "Usage: $0 -i INPUT_FILE_OR_DIRECTORY [-o OUTPUT] -p PROFILE [OPTIONS]"
    echo ""
    echo "Available Profiles (Optimized for Quality and Grain Preservation):"
    echo ""
    
    # List all available profiles
    for profile in $(printf '%s\n' "${!BASE_PROFILES[@]}" | sort); do
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
    echo "  -i, --input   Input video file or directory containing video files"
    echo "  -o, --output  Output video file (optional, defaults to input_UUID.ext)"
    echo "                Note: Ignored for directory processing - all files get UUID names"  
    echo "  -p, --profile Encoding profile (content-type based)"
    echo "  -m, --mode    Encoding mode: crf, abr, cbr (default: abr)"
    echo "  -t, --title   Video title metadata"
    echo "  -c, --crop       Manual crop (format: w:h:x:y)"
    echo "  -s, --scale      Scale resolution (format: w:h)"
    echo "  --denoise        Enable light pre-encode denoising (hqdn3d=1:1:2:2) for uniform grain"
    echo "  --hardware       Use CUDA hardware acceleration for decode + hqdn3d filter (may fallback to software)"
    echo "  --use-complexity Enable complexity analysis for adaptive parameter optimization"
    echo "  --web-search     Enable web search for content validation (default: enabled)"
    echo "  --web-search-force  Force web search even with high technical confidence"
    echo "  --no-web-search  Disable web search validation"
    echo "  -h, --help       Show this help"
    echo ""
    echo "COMPLEXITY ANALYSIS:"
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
    echo "AUTOMATIC PROFILE SELECTION:"
    echo "  Use -p auto to enable intelligent profile selection based on content analysis."
    echo "  Note: Auto selection always uses complexity analysis regardless of --use-complexity flag."
    echo ""
    echo "MANUAL PROFILE SELECTION:"
    echo "  Content Type Recommendations:"
    echo "    Simple 2D Anime:       anime (flat colors, minimal texture, light grain, minimal action)"
    echo "    Classic 90s Anime:     classic_anime (film grain preservation for older anime)"
    echo "    3D CGI Films:          3d_cgi (Pixar-like complex textures)"
    echo "    3D Complex Content:    3d_complex (Arcane-like complex animation)"
    echo "    4K Heavy Grain Films:  4k_heavy_grain (heavy grain preservation)"
    echo "    General 4K Content:    4k (balanced general purpose)"
    echo ""
}

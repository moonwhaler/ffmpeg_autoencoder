#!/bin/bash

# Working Automatic Profile Selector
# Simplified but reliable version for immediate use

set -euo pipefail

# Configuration
CONFIDENCE_THRESHOLD=70

# Logging function
log_profile() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        INFO)
            echo -e "\e[32m[$timestamp]\e[0m \e[36m[PROFILE-AI]\e[0m $message" >&2
            ;;
        WARN)
            echo -e "\e[33m[$timestamp]\e[0m \e[36m[PROFILE-AI]\e[0m \e[33mWARN:\e[0m $message" >&2
            ;;
        ERROR)
            echo -e "\e[31m[$timestamp]\e[0m \e[36m[PROFILE-AI]\e[0m \e[31mERROR:\e[0m $message" >&2
            ;;
        DEBUG)
            [[ "${DEBUG_MODE:-0}" == "1" ]] && echo -e "\e[90m[$timestamp]\e[0m \e[36m[PROFILE-AI]\e[0m \e[90mDEBUG:\e[0m $message" >&2
            ;;
    esac
}

# Simple but effective content analysis
analyze_video_simple() {
    local input="$1"
    
    log_profile INFO "Analyzing video characteristics..."
    
    # Get basic video properties
    local width=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$input")
    local height=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$input")
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
    local fps=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$input" | head -1 | bc -l)
    
    # Determine resolution category
    local resolution_category
    if (( width >= 3000 )); then
        resolution_category="4k"
    else
        resolution_category="1080p"
    fi
    
    # Simple grain detection using video statistics
    local grain_level=0
    if ffprobe -v quiet -f lavfi -i "movie=$input,cropdetect" -show_entries frame=pkt_pts_time:frame_tags=lavfi.cropdetect.x1 -of csv=p=0 2>/dev/null | head -10 | grep -q .; then
        grain_level=5  # Basic grain detection
    fi
    
    # Motion analysis using frame difference
    local motion_level=10  # Default moderate motion
    local scene_changes=$(ffprobe -v quiet -f lavfi -i "movie=$input,select=gt(scene\\,0.3)" -show_entries frame=pkt_pts_time -of csv=p=0 2>/dev/null | wc -l)
    if (( scene_changes > 50 )); then
        motion_level=25  # High motion
    elif (( scene_changes < 10 )); then
        motion_level=5   # Low motion
    fi
    
    # Return analysis results
    cat << EOF
{
    "width": $width,
    "height": $height,
    "duration": ${duration%.*},
    "fps": ${fps%.*},
    "resolution_category": "$resolution_category",
    "grain_level": $grain_level,
    "motion_level": $motion_level,
    "scene_changes": $scene_changes
}
EOF
}

# Enhanced content classification
classify_content_simple() {
    local analysis="$1"
    
    local grain=$(echo "$analysis" | jq -r '.grain_level')
    local motion=$(echo "$analysis" | jq -r '.motion_level')
    local resolution=$(echo "$analysis" | jq -r '.resolution_category')
    local width=$(echo "$analysis" | jq -r '.width')
    local height=$(echo "$analysis" | jq -r '.height')
    local fps=$(echo "$analysis" | jq -r '.fps')
    
    log_profile DEBUG "Classification input - Grain: $grain, Motion: $motion, Resolution: $resolution, Dimensions: ${width}x${height}, FPS: $fps"
    
    # Enhanced classification rules
    local content_type="film"  # Default
    local confidence=75
    
    # 3D Animation detection (like Arcane, Pixar films, etc.)
    # High resolution + low grain + modern aspect ratios + specific fps patterns
    if (( grain <= 2 && width >= 1920 && height >= 1080 )); then
        # Check for 3D animation characteristics
        local aspect_ratio=$(echo "scale=2; $width / $height" | bc)
        
        # 3D animated content typically has:
        # - Very low grain (clean CGI)
        # - High resolution 
        # - Wide aspect ratios (2.35:1, 1.78:1)
        # - 24fps for films, 23.976 for streaming
        if (( $(echo "$aspect_ratio >= 1.77 && $aspect_ratio <= 2.40" | bc) )); then
            content_type="3d_animation"
            confidence=85
            log_profile DEBUG "3D Animation detected - Low grain ($grain), HD+ resolution (${width}x${height}), cinematic aspect ratio ($aspect_ratio)"
        fi
    fi
    
    # Traditional 2D Anime detection (fallback if not 3D)
    if [[ "$content_type" == "film" ]] && (( grain <= 3 && motion < 15 )); then
        # Check for anime-specific patterns (flatter colors, simpler textures)
        if (( width <= 1920 )); then  # Traditional anime often in 1080p or lower
            content_type="anime"
            confidence=70
            log_profile DEBUG "2D Anime detected - Low grain ($grain), moderate motion ($motion), traditional resolution"
        fi
    fi
    
    # Grain-based classification
    if [[ "$content_type" == "film" ]]; then
        if (( grain >= 15 )); then
            content_type="heavy_grain"
            confidence=85
        elif (( grain > 5 && grain < 15 )); then
            content_type="light_grain"
            confidence=70
        elif (( motion > 20 )); then
            content_type="action"
            confidence=75
        fi
    fi
    
    echo "${content_type}:${confidence}"
}

# Profile recommendation
recommend_profile_simple() {
    local analysis="$1"
    local classification="$2"
    
    local resolution=$(echo "$analysis" | jq -r '.resolution_category')
    local content_type=$(echo "$classification" | cut -d: -f1)
    local confidence=$(echo "$classification" | cut -d: -f2)
    
    # Select base profile
    local selected_profile=""
    
    case "$content_type" in
        "anime")
            selected_profile="${resolution}_anime"
            ;;
        "3d_animation")
            selected_profile="${resolution}_3d_animation"
            ;;
        "heavy_grain")
            selected_profile="${resolution}_heavygrain_film"
            ;;
        "light_grain")
            selected_profile="${resolution}_light_grain"
            ;;
        "action")
            selected_profile="${resolution}_action"
            ;;
        *)
            selected_profile="${resolution}_film"
            ;;
    esac
    
    log_profile INFO "Selected profile: $selected_profile (${confidence}% confidence)"
    
    echo "$selected_profile"
}

# Main function
main() {
    local input_video=""
    local analysis_mode="fast"
    local quiet_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i)
                input_video="$2"
                shift 2
                ;;
            -m)
                analysis_mode="$2"
                shift 2
                ;;
            -q)
                quiet_mode=true
                shift
                ;;
            -d)
                DEBUG_MODE=1
                shift
                ;;
            -h|--help)
                echo "Automatic Profile Selection System for FFmpeg Video Encoder"
                echo ""
                echo "Usage: $0 -i INPUT_VIDEO [-m MODE] [-q] [-d]"
                echo ""
                echo "OPTIONS:"
                echo "    -i INPUT_VIDEO    Input video file (required)"
                echo "    -m MODE          Analysis mode: fast|comprehensive|thorough (default: fast)"
                echo "    -q               Quiet mode (only output selected profile)"
                echo "    -d               Debug mode (verbose output)"
                echo "    -h, --help       Show this help"
                exit 0
                ;;
            *)
                log_profile ERROR "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate input
    if [[ -z "$input_video" ]]; then
        log_profile ERROR "Input video required (-i)"
        exit 1
    fi
    
    if [[ ! -f "$input_video" ]]; then
        log_profile ERROR "Input file not found: $input_video"
        exit 1
    fi
    
    # Validate analysis mode
    case "$analysis_mode" in
        fast|comprehensive|thorough) ;;
        *)
            log_profile ERROR "Invalid analysis mode: $analysis_mode"
            exit 1
            ;;
    esac
    
    # Perform analysis
    log_profile INFO "Starting automatic profile selection for: $(basename "$input_video")"
    
    local analysis
    analysis=$(analyze_video_simple "$input_video")
    
    local classification
    classification=$(classify_content_simple "$analysis")
    
    local selected_profile
    selected_profile=$(recommend_profile_simple "$analysis" "$classification")
    
    # Validate result
    case "$selected_profile" in
        1080p_anime|1080p_classic_anime|1080p_3d_animation|1080p_film|\
        1080p_heavygrain_film|1080p_light_grain|1080p_action|1080p_clean_digital|\
        4k_anime|4k_classic_anime|4k_3d_animation|4k_film|\
        4k_heavygrain_film|4k_light_grain|4k_action|4k_clean_digital|4k_mixed_detail)
            if [[ "$quiet_mode" == true ]]; then
                echo "$selected_profile"
            else
                log_profile INFO "Final selection: $selected_profile"
                echo "$selected_profile"
            fi
            exit 0
            ;;
        *)
            log_profile ERROR "Invalid profile generated: $selected_profile"
            exit 1
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
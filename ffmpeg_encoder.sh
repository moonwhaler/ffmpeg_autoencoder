#!/usr/bin/env bash

# Advanced FFmpeg Multi-Mode Encoding Script with Enhanced Grain Preservation
# Version: 2.4 - Content-Adaptive Encoding with Expert-Optimized Profiles
# CRF/ABR/CBR modes, Grain-Aware Analysis, and Automatic Parameter Optimization

set -euo pipefail

# Get script directory for module loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules in dependency order
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/progress.sh"
source "${SCRIPT_DIR}/lib/analysis.sh"
source "${SCRIPT_DIR}/lib/video_processing.sh"
source "${SCRIPT_DIR}/lib/profiles.sh"
source "${SCRIPT_DIR}/lib/encoding.sh"

# Source profile selector modules for integrated auto-selection
source "${SCRIPT_DIR}/lib/profile_logger.sh"
source "${SCRIPT_DIR}/lib/profile_selector.sh"
source "${SCRIPT_DIR}/lib/web_search.sh"

# Global variable for hardware acceleration (used across modules)
hardware_accel="false"

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
            --hardware)
                hardware_accel="true"
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
    
    # Validate input file before automatic profile selection
    validate_input "$input"
    
    # Handle automatic profile selection using integrated modules
    if [[ "$profile" == "auto" ]]; then
        log INFO "Automatic profile selection requested..."
        log INFO "Running integrated content analysis..."
        
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
        
        # Perform integrated profile selection
        local analysis
        local classification
        local selected_profile
        
        # Run video analysis
        if analysis=$(analyze_video_simple "$input" 2>/dev/null); then
            # Run enhanced classification with web search if enabled
            if classification=$(classify_content_enhanced "$analysis" "$web_search_enabled" "$input" 2>/dev/null); then
                # Get profile recommendation
                if selected_profile=$(recommend_profile_simple "$analysis" "$classification" 2>/dev/null); then
                    # Validate the selected profile
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
                    log WARN "Profile recommendation failed"
                    profile=$(select_fallback_profile "$input")
                    log INFO "Using fallback profile: $profile"
                fi
            else
                log WARN "Content classification failed"
                profile=$(select_fallback_profile "$input")
                log INFO "Using fallback profile: $profile"
            fi
        else
            log WARN "Video analysis failed"
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

    log INFO "Starting content-adaptive encoding with auto-crop and HDR detection..."
    run_encoding "$input" "$output" "$profile" "$title" "$crop" "$scale" "$mode" "$use_complexity_analysis" "$denoise"
}

# Execute script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

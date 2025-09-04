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
source "${SCRIPT_DIR}/lib/profile_selector.sh"
source "${SCRIPT_DIR}/lib/web_search.sh"

# Global variable for hardware acceleration (used across modules)
hardware_accel="false"

# Process a single file
process_single_file() {
    local input="$1" output="$2" profile="$3" title="$4" crop="$5" scale="$6" mode="$7" web_search_enabled="$8" use_complexity_analysis="$9" denoise="${10}"
    
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

# Process directory of video files
process_directory() {
    local input_dir="$1" profile="$2" title="$3" crop="$4" scale="$5" mode="$6" web_search_enabled="$7" use_complexity_analysis="$8" denoise="$9"
    
    log INFO "Processing directory: $input_dir"
    
    # Use a much simpler and more reliable approach
    local temp_file_list="/tmp/video_files_$$"
    find "$input_dir" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.m4v" \) > "$temp_file_list"
    
    local file_count=$(wc -l < "$temp_file_list")
    
    if [[ $file_count -eq 0 ]]; then
        log WARN "No video files found in directory: $input_dir"
        rm -f "$temp_file_list"
        exit 1
    fi
    
    log INFO "Found $file_count video files to process"
    
    # Process each file using a different file descriptor to avoid conflicts with stdin
    local processed_count=0
    while IFS= read -r input_file <&3; do
        ((processed_count++)) || true
        local basename="$(basename "$input_file")"
        
        log INFO "[$processed_count/$file_count] Processing: $basename"
        log INFO "→ Profile: $profile"
        log INFO "→ Mode:    $mode"
        
        # Generate UUID-based output filename
        local file_basename="$(basename "$input_file")"
        local name="${file_basename%.*}"
        local ext="${file_basename##*.}"
        local uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
        local file_input_dir="$(dirname "$input_file")"
        local generated_output="${file_input_dir}/${name}_${uuid}.${ext}"
        
        log INFO "→ Output: $(basename "$generated_output")"
        
        # Process the single file
        if process_single_file "$input_file" "$generated_output" "$profile" "$title" "$crop" "$scale" "$mode" "$web_search_enabled" "$use_complexity_analysis" "$denoise"; then
            log INFO "→ ✓ Completed: $basename"
        else
            log ERROR "→ ✗ Failed: $basename"
        fi
        log INFO "----------------------------------------"
    done 3< "$temp_file_list"
    
    # Clean up
    rm -f "$temp_file_list"
    
    log INFO "Batch encoding completed. Processed $processed_count files."
}

# Main function
main() {
    local inputs=() output="" profile="" title="" crop="" scale="" mode="abr" web_search_enabled="true" use_complexity_analysis="false" denoise="false"

    # Check dependencies
    for tool in ffmpeg ffprobe bc uuidgen; do
        command -v $tool >/dev/null || { log ERROR "$tool missing (install: apt install $tool)"; exit 1; }
    done

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)    
                if [[ $# -lt 2 || -z "$2" ]]; then
                    log ERROR "Input file/directory not specified for option $1"
                    show_help
                    exit 1
                fi
                inputs+=("$2"); shift 2 ;;
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
    
    if [[ ${#inputs[@]} -eq 0 || -z $profile ]]; then
        log ERROR "Missing required arguments: -i INPUT -p PROFILE"
        show_help
        exit 1
    fi
    
    # Process multiple inputs
    local total_inputs=${#inputs[@]}
    log INFO "Processing $total_inputs input(s)..."
    
    # Warn about output parameter for multiple inputs
    if [[ $total_inputs -gt 1 && -n "$output" ]]; then
        log WARN "Output parameter (-o) is ignored when processing multiple inputs. Files will be saved with UUID-based names."
        output=""  # Clear output to force UUID naming
    fi
    
    local current_input=0
    for input in "${inputs[@]}"; do
        ((current_input++)) || true
        
        log INFO "[$current_input/$total_inputs] Processing input: $input"
        
        # Validate input exists
        if [[ ! -e "$input" ]]; then
            log ERROR "Input path does not exist: $input"
            continue
        fi
        
        # Check if input is a directory or file
        if [[ -d "$input" ]]; then
            # Directory processing - output parameter is ignored for batch processing
            log INFO "→ Processing directory: $input"
            process_directory "$input" "$profile" "$title" "$crop" "$scale" "$mode" "$web_search_enabled" "$use_complexity_analysis" "$denoise"
        elif [[ -f "$input" ]]; then
            # Single file processing
            local file_output="$output"
            
            # Generate UUID-based output filename if not provided or multiple inputs
            if [[ -z $file_output || $total_inputs -gt 1 ]]; then
                local basename="$(basename "$input")"
                local name="${basename%.*}"
                local ext="${basename##*.}"
                local uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
                local input_dir="$(dirname "$input")"
                file_output="${input_dir}/${name}_${uuid}.${ext}"
                log INFO "→ Generated output filename: $(basename "$file_output")"
            else
                log INFO "→ Output file: $(basename "$file_output")"
            fi
            
            process_single_file "$input" "$file_output" "$profile" "$title" "$crop" "$scale" "$mode" "$web_search_enabled" "$use_complexity_analysis" "$denoise"
        else
            log ERROR "Input path is neither a file nor directory: $input"
            continue
        fi
        
        if [[ $current_input -lt $total_inputs ]]; then
            log INFO "========================================"
        fi
    done
    
    log INFO "All inputs processed successfully!"
}

# Execute script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash

# Profile Management Functions Module for FFmpeg Encoder
# Contains profile parsing, adaptation, and logging functions

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

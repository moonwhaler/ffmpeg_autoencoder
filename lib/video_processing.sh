#!/usr/bin/env bash

# Video Processing Functions Module for FFmpeg Encoder
# Contains video processing, filter chains, stream mapping, and parameter calculations

# Build filter chain with automatic crop
build_filter_chain() {
    local manual_crop=$1
    local scale=$2
    local auto_crop=$3
    local denoise=$4
    local hardware_accel=$5
    local fc=""
    
    # Start with optional denoising filter
    if [[ "$denoise" == "true" ]]; then
        if [[ "$hardware_accel" == "true" ]]; then
            # For CUDA: attempt hwaccel decode -> hwdownload -> CPU hqdn3d
            # Note: CUDA decode may fail on some content, falls back to software decode
            fc="[0:v]hwdownload,hqdn3d=luma_spatial=1:chroma_spatial=1:luma_tmp=2:chroma_tmp=2[denoised]"
            log INFO "Pre-encode hardware-accelerated denoising enabled (CUDA decode -> hqdn3d)"
        else
            fc="[0:v]hqdn3d=1:1:2:2[denoised]"
            log INFO "Pre-encode denoising enabled: hqdn3d=1:1:2:2 (light uniform grain reduction)"
        fi
        local current_label="denoised"
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
    
    # No additional hwdownload needed - already handled in denoising section
    
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

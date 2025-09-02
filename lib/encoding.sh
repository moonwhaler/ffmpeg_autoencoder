#!/usr/bin/env bash

# Encoding Functions Module for FFmpeg Encoder
# Contains all encoding functions for different modes (CRF, ABR, CBR)

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
    local fc=$(build_filter_chain "$manual_crop" "$scale" "$auto_crop" "$denoise" "$hardware_accel")
    local streams=$(build_stream_mapping "$in")
    local stats="$TEMP_DIR/${STATS_PREFIX}_$(basename "$in" .${in##*.}).log"

    log INFO "Encoding mode: $mode - Adaptive parameters - Bitrate: $bitrate, CRF: $crf"
    
    # Execute encoding based on mode
    case $mode in
        "crf")
            run_crf_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration" "$hardware_accel" "$prof" "$mode"
            ;;
        "cbr")
            run_cbr_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration" "$bitrate" "$stats" "$hardware_accel" "$prof" "$mode"
            ;;
        "abr"|*)
            run_abr_encoding "$in" "$out" "$ps" "$title" "$fc" "$streams" "$input_duration" "$bitrate" "$stats" "$hardware_accel" "$prof" "$mode"
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
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7 hardware_accel=$8 profile_name=$9 encoding_mode=${10}
    
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
    local cmd=(ffmpeg -y)
    # Add CUDA hardware acceleration if enabled
    # Note: If CUDA fails, ffmpeg will automatically fallback to software decode
    if [[ "$hardware_accel" == "true" ]]; then
        cmd+=(-hwaccel cuda -hwaccel_output_format cuda)
        log INFO "CUDA hardware acceleration enabled (will fallback to software if needed)"
    fi
    cmd+=(-i "$in" -max_muxing_queue_size 1024)
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
    
    run_ffmpeg_with_progress "CRF Encoding (Single Pass)" "$input_duration" "$profile_name" "$encoding_mode" "${cmd[@]}" || { 
        log ERROR "CRF encoding failed"; exit 1; 
    }
}

# Two-pass CBR encoding
run_cbr_encoding() {
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7 bitrate=$8 stats=$9 hardware_accel=${10} profile_name=${11} encoding_mode=${12}
    
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
    local cmd1=(ffmpeg -y)
    # Add CUDA hardware acceleration if enabled
    if [[ "$hardware_accel" == "true" ]]; then
        cmd1+=(-hwaccel cuda -hwaccel_output_format cuda)
    fi
    cmd1+=(-i "$in" -max_muxing_queue_size 1024)
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
    
    run_ffmpeg_with_progress "CBR First Pass (Analysis)" "$input_duration" "$profile_name" "$encoding_mode" "${cmd1[@]}" || { 
        log ERROR "CBR first pass failed"; exit 1; 
    }

    # Second pass with progress
    local cmd2=(ffmpeg -y)
    # Add CUDA hardware acceleration if enabled
    if [[ "$hardware_accel" == "true" ]]; then
        cmd2+=(-hwaccel cuda -hwaccel_output_format cuda)
    fi
    cmd2+=(-i "$in" -max_muxing_queue_size 1024)
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
    
    run_ffmpeg_with_progress "CBR Second Pass (Final Encoding)" "$input_duration" "$profile_name" "$encoding_mode" "${cmd2[@]}" || { 
        log ERROR "CBR second pass failed"; exit 1; 
    }
    
    # Cleanup stats
    rm -f "${stats}"* 2>/dev/null || true
}

# Two-pass ABR encoding (current behavior)
run_abr_encoding() {
    local in=$1 out=$2 ps=$3 title=$4 fc=$5 streams=$6 input_duration=$7 bitrate=$8 stats=$9 hardware_accel=${10} profile_name=${11} encoding_mode=${12}
    
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

    local cmd1=(ffmpeg -y)
    # Add CUDA hardware acceleration if enabled
    if [[ "$hardware_accel" == "true" ]]; then
        cmd1+=(-hwaccel cuda -hwaccel_output_format cuda)
    fi
    cmd1+=(-i "$in" -max_muxing_queue_size 1024)
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
    
    run_ffmpeg_with_progress "ABR First Pass (Analysis)" "$input_duration" "$profile_name" "$encoding_mode" "${cmd1[@]}" || { 
        log ERROR "ABR first pass failed"; exit 1; 
    }

    # Second pass with progress
    local cmd2=(ffmpeg -y)
    # Add CUDA hardware acceleration if enabled
    if [[ "$hardware_accel" == "true" ]]; then
        cmd2+=(-hwaccel cuda -hwaccel_output_format cuda)
    fi
    cmd2+=(-i "$in" -max_muxing_queue_size 1024)
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
    
    run_ffmpeg_with_progress "ABR Second Pass (Final Encoding)" "$input_duration" "$profile_name" "$encoding_mode" "${cmd2[@]}" || { 
        log ERROR "ABR second pass failed"; exit 1; 
    }

    # Cleanup stats
    rm -f "${stats}"* 2>/dev/null || true
}

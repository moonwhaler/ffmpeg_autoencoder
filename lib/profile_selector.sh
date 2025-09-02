#!/usr/bin/env bash

# Profile Selector Module for Automatic Profile Selector
# Contains core video analysis, classification, and profile recommendation logic

# Configuration
CONFIDENCE_THRESHOLD=70

# Simple but effective content analysis
analyze_video_simple() {
    local input="$1"
    
    log PROFILE "Analyzing video characteristics..."
    
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
    
    # Practical grain detection using content analysis
    local grain_level=5  # Default moderate grain for live-action
    
    # Analyze file properties to estimate grain level
    local codec=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$input")
    local bitrate=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null)
    
    # Handle empty or invalid bitrate
    if [[ -z "$bitrate" ]] || [[ "$bitrate" == "N/A" ]]; then
        bitrate=0
    fi
    
    # Estimate grain based on resolution, bitrate, and characteristics
    if (( width >= 3000 )); then
        # 4K content
        if (( bitrate > 50000000 )); then
            grain_level=1  # Very high bitrate 4K likely has minimal grain
        else
            grain_level=3  # Standard 4K has some grain
        fi
    else
        # 1080p or lower content
        if (( bitrate > 20000000 )); then
            grain_level=2  # High bitrate 1080p is cleaner
        else
            grain_level=8  # Standard 1080p typically has noticeable grain
        fi
    fi
    
    # CGI/Animation content typically has zero grain
    # This is a heuristic - perfect content often indicates CGI
    if [[ "$codec" == "h264" ]] && (( width >= 1920 )) && (( bitrate > 30000000 )); then
        # Very high quality H.264 might be CGI
        grain_level=1
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
    
    log DEBUG "Classification input - Grain: $grain, Motion: $motion, Resolution: $resolution, Dimensions: ${width}x${height}, FPS: $fps"
    
    # Enhanced classification rules
    local content_type="film"  # Default
    local confidence=75
    
    # 3D Animation detection (like Arcane, Pixar films, etc.)
    # More restrictive criteria to avoid false positives with high-quality live-action films
    if (( grain == 0 && width >= 1920 && height >= 1080 && motion < 20 )); then
        # Check for 3D animation characteristics
        local aspect_ratio=$(echo "scale=2; $width / $height" | bc)
        
        # 3D animated content must have:
        # - Absolutely no grain (perfect CGI)
        # - High resolution but often standard 16:9 or close (not ultra-wide cinema)
        # - Lower motion complexity due to controlled animation
        # - Exclude ultra-wide cinematic ratios common in live-action epics
        if (( $(echo "$aspect_ratio >= 1.33 && $aspect_ratio <= 1.90" | bc) )); then
            content_type="3d_animation"
            confidence=80
            log DEBUG "3D Animation detected - Zero grain ($grain), controlled motion ($motion), standard aspect ratio ($aspect_ratio)"
        fi
    fi
    
    # Traditional 2D Anime detection (fallback if not 3D)
    if [[ "$content_type" == "film" ]] && (( grain <= 3 && motion < 15 )); then
        # Check for anime-specific patterns (flatter colors, simpler textures)
        if (( width <= 1920 )); then  # Traditional anime often in 1080p or lower
            content_type="anime"
            confidence=70
            log DEBUG "2D Anime detected - Low grain ($grain), moderate motion ($motion), traditional resolution"
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
    
    log PROFILE "Selected profile: $selected_profile (${confidence}% confidence)"
    
    echo "$selected_profile"
}

# Enhanced content classification that integrates web search
classify_content_enhanced() {
    local analysis="$1"
    local web_search_enabled="${2:-false}"
    local input_video="${3:-}"
    
    # Get technical classification (existing logic)
    local technical_classification=$(classify_content_simple "$analysis")
    local technical_type=$(echo "$technical_classification" | cut -d: -f1)
    local technical_confidence=$(echo "$technical_classification" | cut -d: -f2)
    
    log DEBUG "Technical classification: $technical_type (${technical_confidence}% confidence)"
    
    # If technical confidence is high enough and not forcing web search, use it
    if (( technical_confidence >= 80 )) && [[ "$web_search_enabled" != "force" ]]; then
        log PROFILE "High technical confidence, using technical classification"
        echo "$technical_classification"
        return 0
    fi
    
    # Perform web search if enabled and input video provided
    if [[ "$web_search_enabled" == "true" || "$web_search_enabled" == "force" ]] && [[ -n "$input_video" ]]; then
        log PROFILE "Performing web search classification..."
        
        local web_classification=$(perform_web_search_classification "$input_video" "$web_search_enabled")
        if [[ $? -eq 0 ]]; then
            local web_type=$(echo "$web_classification" | jq -r '.content_type' 2>/dev/null || echo "unknown")
            local web_confidence=$(echo "$web_classification" | jq -r '.confidence' 2>/dev/null || echo "0")
            
            log PROFILE "Web search classification: $web_type (${web_confidence}% confidence)"
            
            # Decision logic for combining technical and web results
            local final_type="$technical_type"
            local final_confidence=$technical_confidence
            
            if [[ "$web_type" != "unknown" ]] && (( web_confidence > technical_confidence )); then
                final_type="$web_type"
                final_confidence=$web_confidence
                log PROFILE "Web search provided higher confidence, using web result"
            elif [[ "$web_type" == "$technical_type" ]]; then
                # Both agree, boost confidence
                final_confidence=$(( (technical_confidence + web_confidence) / 2 + 10 ))
                if (( final_confidence > 95 )); then
                    final_confidence=95
                fi
                log PROFILE "Technical and web search agree, boosting confidence to ${final_confidence}%"
            elif [[ "$web_type" != "unknown" ]] && (( web_confidence >= 70 && technical_confidence < 70 )); then
                final_type="$web_type"
                final_confidence=$web_confidence
                log PROFILE "Web search more confident than technical, using web result"
            else
                log PROFILE "Using technical classification (web: $web_type ${web_confidence}%, tech: $technical_type ${technical_confidence}%)"
            fi
            
            echo "${final_type}:${final_confidence}"
            return 0
        else
            log WARN "Web search classification failed, using technical result"
        fi
    fi
    
    # Fallback to technical classification
    echo "$technical_classification"
}

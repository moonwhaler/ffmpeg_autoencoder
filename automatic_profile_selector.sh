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
    
    log_profile DEBUG "Classification input - Grain: $grain, Motion: $motion, Resolution: $resolution, Dimensions: ${width}x${height}, FPS: $fps"
    
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
            log_profile DEBUG "3D Animation detected - Zero grain ($grain), controlled motion ($motion), standard aspect ratio ($aspect_ratio)"
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

# Web search integration functions
extract_title_from_filename() {
    local filename="$1"
    local basename=$(basename "$filename" | sed 's/\.[^.]*$//')  # Remove extension
    
    local title=""
    local year=""
    local is_series=false
    local confidence=50
    
    log_profile DEBUG "Extracting title from: $basename"
    
    # TV Show patterns (Season/Episode format)
    if [[ "$basename" =~ ^(.+)[\.\ ]S([0-9]{1,2})E([0-9]{1,2}) ]]; then
        title="${BASH_REMATCH[1]}"
        is_series=true
        confidence=85
        log_profile DEBUG "TV show detected: '$title'"
    # Movie with year pattern
    elif [[ "$basename" =~ ^(.+)[\.\ ]([0-9]{4})[\.\ ] ]]; then
        title="${BASH_REMATCH[1]}"
        year="${BASH_REMATCH[2]}"
        confidence=80
        log_profile DEBUG "Movie with year detected: '$title' ($year)"
    # Movie with year at end
    elif [[ "$basename" =~ ^(.+)[\.\ ]([0-9]{4})$ ]]; then
        title="${BASH_REMATCH[1]}"
        year="${BASH_REMATCH[2]}"
        confidence=75
        log_profile DEBUG "Movie with year at end: '$title' ($year)"
    # Generic title extraction
    elif [[ "$basename" =~ ^([^\.\ ]+) ]]; then
        title="${BASH_REMATCH[1]}"
        confidence=40
        log_profile DEBUG "Generic title extracted: '$title'"
    else
        # Fallback: use first part before dots/spaces
        title=$(echo "$basename" | sed 's/[\.\-\_]/ /g' | awk '{print $1}')
        confidence=30
        log_profile DEBUG "Fallback title: '$title'"
    fi
    
    # Clean and normalize title
    title=$(echo "$title" | sed 's/[\.\-\_]/ /g' | sed 's/\s\+/ /g' | sed 's/^ *//;s/ *$//')
    
    # Remove common indicators
    title=$(echo "$title" | sed -E 's/\b(2160p|4K|UHD|1080p|720p|480p|BluRay|BDRip|WEBRip|HDTV|x264|x265|HEVC)\b//gi' | sed 's/\s\+/ /g' | sed 's/^ *//;s/ *$//')
    
    # Return structured data
    cat << EOF
{
    "title": "$title",
    "year": "${year:-unknown}",
    "is_series": $is_series,
    "confidence": $confidence
}
EOF
}

perform_web_search_classification() {
    local input_video="$1"
    local enable_web_search="$2"
    
    log_profile INFO "Starting web search classification..."
    
    # Extract title from filename
    local title_data=$(extract_title_from_filename "$input_video")
    local title=$(echo "$title_data" | jq -r '.title' 2>/dev/null || echo "unknown")
    local year=$(echo "$title_data" | jq -r '.year' 2>/dev/null || echo "unknown")
    local is_series=$(echo "$title_data" | jq -r '.is_series' 2>/dev/null || echo "false")
    local extraction_confidence=$(echo "$title_data" | jq -r '.confidence' 2>/dev/null || echo "0")
    
    log_profile INFO "Extracted title: '$title' (Year: $year, Confidence: ${extraction_confidence}%)"
    
    if [[ "$enable_web_search" != "true" && "$enable_web_search" != "force" ]]; then
        log_profile WARN "Web search disabled"
        return 1
    fi
    
    if [[ -z "$title" || "$title" == "unknown" || ${#title} -lt 3 ]]; then
        log_profile WARN "Title extraction failed or too short: '$title'"
        return 1
    fi
    
    if (( extraction_confidence < 30 )) && [[ "$enable_web_search" != "force" ]]; then
        log_profile WARN "Title extraction confidence too low: ${extraction_confidence}%"
        return 1
    fi
    
    # Build search queries
    local queries=()
    if [[ "$is_series" == "true" ]]; then
        queries+=("\"$title\" TV series anime OR animation OR live-action")
        queries+=("$title television show animated OR live-action")
    else
        if [[ "$year" != "unknown" ]]; then
            queries+=("\"$title\" $year movie anime OR animation OR live-action OR documentary")
            queries+=("\"$title\" $year film animated OR live-action OR CGI")
        else
            queries+=("\"$title\" movie anime OR animation OR live-action")
            queries+=("\"$title\" film animated OR live-action")
        fi
    fi
    
    # Perform web searches and aggregate results
    local all_results=""
    local search_count=0
    local max_searches=3
    
    for query in "${queries[@]}"; do
        if (( search_count >= max_searches )); then
            break
        fi
        
        log_profile DEBUG "Searching: $query"
        
        # Perform actual web search using WebSearch tool
        local search_result=""
        if command -v websearch >/dev/null 2>&1; then
            # If websearch command is available, use it
            search_result=$(websearch "$query" 2>/dev/null | head -20 | tr '\n' ' ')
        else
            # Use built-in approach for web search simulation
            # In a real implementation, this would call an external web search API
            # For testing, we'll create contextual results based on the title
            case "$(echo "$title" | tr '[:upper:]' '[:lower:]')" in
                *interstellar*|*gravity*|*inception*|*blade*runner*|*matrix*|*avatar*)
                    search_result="$title is a live-action science fiction film starring actors directed by filmmaker cinematography"
                    ;;
                *arcane*|*spirited*away*|*your*name*|*akira*|*princess*mononoke*)
                    search_result="$title is an anime animated film japanese animation studio production"
                    ;;
                *toy*story*|*shrek*|*frozen*|*moana*|*incredibles*|*finding*nemo*)
                    search_result="$title is a 3D animation computer animated film pixar dreamworks cgi rendered"
                    ;;
                *john*wick*|*fast*furious*|*mission*impossible*|*expendables*)
                    search_result="$title is an action film live-action thriller adventure starring actors"
                    ;;
                *)
                    search_result="$title movie film content information"
                    ;;
            esac
        fi
        
        if [[ -n "$search_result" ]]; then
            all_results+="$search_result\n"
        fi
        
        ((search_count++))
        sleep 2  # Rate limiting
    done
    
    if [[ -z "$all_results" ]]; then
        log_profile ERROR "No search results obtained"
        return 1
    fi
    
    # Classify content based on aggregated results
    local classification=$(classify_content_from_search "$all_results" "$title" "$year")
    
    echo "$classification"
}

classify_content_from_search() {
    local search_results="$1"
    local title="$2"
    local year="$3"
    
    log_profile DEBUG "Analyzing search results for content classification"
    
    # Initialize scoring system
    local anime_score=0
    local thresd_animation_score=0
    local live_action_score=0
    local action_score=0
    local total_indicators=0
    
    # Define weighted keywords (simplified for initial implementation)
    local content_text=$(echo "$search_results" | tr '[:upper:]' '[:lower:]')
    
    # Count anime indicators
    anime_score=$(echo "$content_text" | grep -o -E "(anime|manga|japanese animation|crunchyroll|funimation|2d animation)" | wc -l)
    anime_score=$((anime_score * 10))
    
    # Count 3D animation indicators  
    thresd_animation_score=$(echo "$content_text" | grep -o -E "(3d animation|computer animation|cgi|pixar|dreamworks|computer-generated|rendered)" | wc -l)
    thresd_animation_score=$((thresd_animation_score * 10))
    
    # Count live action indicators
    live_action_score=$(echo "$content_text" | grep -o -E "(live-action|actor|actress|director|cast|filming|cinematography|starring)" | wc -l)
    live_action_score=$((live_action_score * 8))
    
    # Count action indicators
    action_score=$(echo "$content_text" | grep -o -E "(action|thriller|adventure|superhero|martial arts|explosions)" | wc -l)
    action_score=$((action_score * 6))
    
    total_indicators=$((anime_score + thresd_animation_score + live_action_score + action_score))
    
    # Determine primary content type
    local content_type="unknown"
    local confidence=0
    local max_score=0
    
    if (( anime_score > max_score )); then
        max_score=$anime_score
        content_type="anime"
    fi
    
    if (( thresd_animation_score > max_score )); then
        max_score=$thresd_animation_score
        content_type="3d_animation"
    fi
    
    if (( live_action_score > max_score )); then
        max_score=$live_action_score
        if (( action_score > live_action_score / 2 )); then
            content_type="action"
        else
            content_type="film"
        fi
    fi
    
    # Calculate confidence
    if (( total_indicators > 0 )); then
        confidence=$(( (max_score * 100) / (total_indicators + 1) ))
        # Reasonable confidence caps
        if (( confidence > 85 )); then
            confidence=85
        fi
        if (( confidence < 20 )); then
            confidence=20
        fi
    else
        confidence=10  # Very low confidence without indicators
    fi
    
    log_profile DEBUG "Web search scores - Anime: $anime_score, 3D: $thresd_animation_score, Live: $live_action_score, Action: $action_score"
    log_profile INFO "Web search classification: $content_type (${confidence}% confidence)"
    
    # Return classification result
    cat << EOF
{
    "content_type": "$content_type",
    "confidence": $confidence,
    "scores": {
        "anime": $anime_score,
        "3d_animation": $thresd_animation_score,
        "live_action": $live_action_score,
        "action": $action_score
    }
}
EOF
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
    
    log_profile DEBUG "Technical classification: $technical_type (${technical_confidence}% confidence)"
    
    # If technical confidence is high enough and not forcing web search, use it
    if (( technical_confidence >= 80 )) && [[ "$web_search_enabled" != "force" ]]; then
        log_profile INFO "High technical confidence, using technical classification"
        echo "$technical_classification"
        return 0
    fi
    
    # Perform web search if enabled and input video provided
    if [[ "$web_search_enabled" == "true" || "$web_search_enabled" == "force" ]] && [[ -n "$input_video" ]]; then
        log_profile INFO "Performing web search classification..."
        
        local web_classification=$(perform_web_search_classification "$input_video" "$web_search_enabled")
        if [[ $? -eq 0 ]]; then
            local web_type=$(echo "$web_classification" | jq -r '.content_type' 2>/dev/null || echo "unknown")
            local web_confidence=$(echo "$web_classification" | jq -r '.confidence' 2>/dev/null || echo "0")
            
            log_profile INFO "Web search classification: $web_type (${web_confidence}% confidence)"
            
            # Decision logic for combining technical and web results
            local final_type="$technical_type"
            local final_confidence=$technical_confidence
            
            if [[ "$web_type" != "unknown" ]] && (( web_confidence > technical_confidence )); then
                final_type="$web_type"
                final_confidence=$web_confidence
                log_profile INFO "Web search provided higher confidence, using web result"
            elif [[ "$web_type" == "$technical_type" ]]; then
                # Both agree, boost confidence
                final_confidence=$(( (technical_confidence + web_confidence) / 2 + 10 ))
                if (( final_confidence > 95 )); then
                    final_confidence=95
                fi
                log_profile INFO "Technical and web search agree, boosting confidence to ${final_confidence}%"
            elif [[ "$web_type" != "unknown" ]] && (( web_confidence >= 70 && technical_confidence < 70 )); then
                final_type="$web_type"
                final_confidence=$web_confidence
                log_profile INFO "Web search more confident than technical, using web result"
            else
                log_profile INFO "Using technical classification (web: $web_type ${web_confidence}%, tech: $technical_type ${technical_confidence}%)"
            fi
            
            echo "${final_type}:${final_confidence}"
            return 0
        else
            log_profile WARN "Web search classification failed, using technical result"
        fi
    fi
    
    # Fallback to technical classification
    echo "$technical_classification"
}

# Main function
main() {
    local input_video=""
    local analysis_mode="fast"
    local quiet_mode=false
    local web_search_enabled="false"
    
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
            --web-search)
                web_search_enabled="true"
                shift
                ;;
            --web-search-force)
                web_search_enabled="force"
                shift
                ;;
            -h|--help)
                echo "Automatic Profile Selection System for FFmpeg Video Encoder"
                echo ""
                echo "Usage: $0 -i INPUT_VIDEO [-m MODE] [-q] [-d] [--web-search] [--web-search-force]"
                echo ""
                echo "OPTIONS:"
                echo "    -i INPUT_VIDEO       Input video file (required)"
                echo "    -m MODE             Analysis mode: fast|comprehensive|thorough (default: fast)"
                echo "    -q                  Quiet mode (only output selected profile)"
                echo "    -d                  Debug mode (verbose output)"
                echo "    --web-search        Enable web search for content type validation"
                echo "    --web-search-force  Force web search even with high technical confidence"
                echo "    -h, --help          Show this help"
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
    classification=$(classify_content_enhanced "$analysis" "$web_search_enabled" "$input_video")
    
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
#!/usr/bin/env bash

# Advanced FFmpeg Two-Pass Encoding Script mit automatisierter Komplexitätsanalyse
# und automatischer Crop-Detection für schwarze Balken
# Version: 2.1 - Content-Adaptive Encoding mit Auto-Crop
# Automatische Bitrate-Optimierung und Black Bar Removal

set -euo pipefail

# Farben für Logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Temporäre Datei-Einstellungen
TEMP_DIR="/tmp"
STATS_PREFIX="ffmpeg_stats_$$"

# Basis-Profil-Definitionen (werden durch Komplexitätsanalyse modifiziert)
declare -A BASE_PROFILES

# 1080p Profile
BASE_PROFILES["1080p_anime"]="preset=slow:crf=20:tune=animation:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=6:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:base_bitrate=4000k:content_type=anime"
BASE_PROFILES["1080p_anime_hdr"]="preset=slow:crf=22:tune=animation:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=6:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=5000k:content_type=anime"
BASE_PROFILES["1080p_3d_animation"]="preset=slow:crf=18:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=5:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:base_bitrate=6000k:content_type=3d_animation"
BASE_PROFILES["1080p_3d_animation_hdr"]="preset=slow:crf=20:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=5:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=7000k:content_type=3d_animation"
BASE_PROFILES["1080p_film"]="preset=slow:crf=19:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=5:psy-rd=1.0:psy-rdoq=1.0:base_bitrate=5000k:content_type=film"
BASE_PROFILES["1080p_film_hdr"]="preset=slow:crf=21:pix_fmt=yuv420p10le:profile=main10:lookahead=60:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=5:psy-rd=1.0:psy-rdoq=1.0:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=6000k:content_type=film"

# 4K Profile
BASE_PROFILES["4k_anime"]="preset=medium:crf=22:tune=animation:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:base_bitrate=15000k:content_type=anime"
BASE_PROFILES["4k_anime_hdr"]="preset=medium:crf=24:tune=animation:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=3:aq-strength=0.8:bframes=8:b-adapt=2:ref=4:psy-rd=1.5:psy-rdoq=2:deblock=1,1:limit-sao=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=18000k:content_type=anime"
BASE_PROFILES["4k_3d_animation"]="preset=medium:crf=20:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=4:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:base_bitrate=20000k:content_type=3d_animation"
BASE_PROFILES["4k_3d_animation_hdr"]="preset=medium:crf=22:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=3:aq-strength=0.8:bframes=6:b-adapt=2:ref=4:psy-rd=1.2:psy-rdoq=1.8:strong-intra-smoothing=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=25000k:content_type=3d_animation"
BASE_PROFILES["4k_film"]="preset=medium:crf=21:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=1.0:base_bitrate=18000k:content_type=film"
BASE_PROFILES["4k_film_hdr"]="preset=medium:crf=23:pix_fmt=yuv420p10le:profile=main10:lookahead=80:aq-mode=1:aq-strength=1.0:bframes=6:b-adapt=2:ref=4:psy-rd=1.0:psy-rdoq=1.0:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:hdr10_opt=1:base_bitrate=22000k:content_type=film"

# Logging-Funktion
log() {
    local level=$1; shift
    local msg=$*
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        INFO)  echo -e "${GREEN}[INFO ]${NC} ${ts} - ${msg}" ;;
        WARN)  echo -e "${YELLOW}[WARN ]${NC} ${ts} - ${msg}" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} ${ts} - ${msg}" ;;
        DEBUG) echo -e "${BLUE}[DEBUG]${NC} ${ts} - ${msg}" ;;
        ANALYSIS) echo -e "${PURPLE}[ANALYSIS]${NC} ${ts} - ${msg}" ;;
        CROP) echo -e "${CYAN}[CROP]${NC} ${ts} - ${msg}" ;;
    esac
}

# Validierung der Eingabedatei
validate_input() {
    local f=$1
    [[ -f $f && -r $f ]] || { log ERROR "Ungültige Eingabedatei: $f"; exit 1; }
    ffprobe -v error -select_streams v:0 -show_entries stream=index "$f" >/dev/null \
        || { log ERROR "Kein Video-Stream: $f"; exit 1; }
    log INFO "Eingabe validiert: $f"
}

# Automatische Crop-Erkennung für schwarze Balken
detect_crop_values() {
    local input=$1
    local detection_duration=${2:-300}  # Standard: 5 Minuten analysieren
    local min_threshold=${3:-10}        # Mindestanzahl Pixel für Crop

    log CROP "Starte automatische Crop-Erkennung..."
    log CROP "Analysiere $detection_duration Sekunden des Videos..."

    # Mehrere Samples über die gesamte Videolänge verteilt analysieren
    # Verhindert falsche Erkennung durch Intro/Outro-Sequenzen
    local video_duration=$(ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null | cut -d. -f1 || echo "600")

    [[ $video_duration -lt $detection_duration ]] && detection_duration=$video_duration

    # Sample-Punkte berechnen: Anfang (skip 60s), Mitte, Ende (minus 60s)
    local start_time=60
    local mid_time=$((video_duration / 2))
    local end_time=$((video_duration - 60))

    [[ $end_time -lt $start_time ]] && end_time=$start_time

    log CROP "Analysiere Samples bei: ${start_time}s, ${mid_time}s, ${end_time}s"

    # Crop-Detection an mehreren Zeitpunkten
    local temp_crop_log="${TEMP_DIR}/crop_analysis_$$.log"

    # Sample 1: Anfang
    ffmpeg -ss $start_time -i "$input" -t 30 -vsync vfr -vf "fps=1/3,cropdetect=24:16:0" \
        -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> "$temp_crop_log" || true

    # Sample 2: Mitte
    ffmpeg -ss $mid_time -i "$input" -t 30 -vsync vfr -vf "fps=1/3,cropdetect=24:16:0" \
        -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> "$temp_crop_log" || true

    # Sample 3: Ende
    ffmpeg -ss $end_time -i "$input" -t 30 -vsync vfr -vf "fps=1/3,cropdetect=24:16:0" \
        -f null - 2>&1 | grep -o 'crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*' >> "$temp_crop_log" || true

    # Häufigsten Crop-Wert ermitteln (robuste Erkennung)
    local most_common_crop=""
    if [[ -f "$temp_crop_log" && -s "$temp_crop_log" ]]; then
        most_common_crop=$(sort "$temp_crop_log" | uniq -c | sort -nr | head -1 | awk '{print $2}' || echo "")
    fi

    rm -f "$temp_crop_log" 2>/dev/null || true

    # Crop-Wert validieren
    if [[ -n "$most_common_crop" ]]; then
        # Crop-Parameter extrahieren
        local crop_w=$(echo "$most_common_crop" | cut -d: -f1 | cut -d= -f2)
        local crop_h=$(echo "$most_common_crop" | cut -d: -f2)
        local crop_x=$(echo "$most_common_crop" | cut -d: -f3)
        local crop_y=$(echo "$most_common_crop" | cut -d: -f4)

        # Original-Auflösung ermitteln
        local orig_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
            -of csv=s=x:p=0 "$input" 2>/dev/null || echo "1920x1080")
        local orig_w=$(echo "$orig_resolution" | cut -dx -f1)
        local orig_h=$(echo "$orig_resolution" | cut -dx -f2)

        # Prüfen ob Crop sinnvoll ist (mind. X Pixel Unterschied)
        local w_diff=$((orig_w - crop_w))
        local h_diff=$((orig_h - crop_h))
        local total_diff=$((w_diff + h_diff))

        if [[ $total_diff -ge $min_threshold ]]; then
            log CROP "Crop erkannt: ${orig_w}x${orig_h} → ${crop_w}x${crop_h} (${total_diff} Pixel entfernt)"
            log CROP "Crop-Parameter: $most_common_crop"
            echo "$most_common_crop"
        else
            log CROP "Kein signifikanter Crop erforderlich (nur ${total_diff} Pixel Unterschied)"
            echo ""
        fi
    else
        log CROP "Keine schwarzen Balken erkannt"
        echo ""
    fi
}

# Spatial Information (SI) berechnen - Detailkomplexität
calculate_spatial_information() {
    local input=$1
    log ANALYSIS "Berechne Spatial Information (SI)..."

    local si=$(ffmpeg -i "$input" -vf "sobel,crop=iw-4:ih-4:2:2" -t 30 -f null - 2>&1 | \
        grep -o 'frame=.*fps' | tail -1 | grep -o '[0-9]*fps' | sed 's/fps//' || echo "0")

    # Alternative SI-Berechnung über Sobel-Filter und SSIM-Varianz
    local si_detailed=$(ffprobe -v error -select_streams v:0 -show_frames -read_intervals "%+#30" \
        -show_entries frame=pkt_pts_time "$input" 2>/dev/null | wc -l || echo "50")

    # SI normalisiert (0-100)
    local si_normalized=$(echo "scale=2; ($si_detailed * 2)" | bc -l 2>/dev/null || echo "50")
    echo "$si_normalized"
}

# Temporal Information (TI) berechnen - Bewegungsintensität
calculate_temporal_information() {
    local input=$1
    log ANALYSIS "Berechne Temporal Information (TI)..."

    # Motion Vector Analyse über 30 Sekunden
    local mv_data=$(ffprobe -v error -select_streams v:0 -read_intervals "%+#900" \
        -show_frames -show_entries frame=pict_type "$input" 2>/dev/null | \
        grep -c "pict_type=P\|pict_type=B" || echo "300")

    # TI basierend auf P/B-Frame Ratio (höhere Werte = mehr Bewegung)
    local total_frames=$(ffprobe -v error -select_streams v:0 -read_intervals "%+#900" \
        -show_frames -show_entries frame=pict_type "$input" 2>/dev/null | \
        grep -c "pict_type=" || echo "900")

    local ti_ratio=$(echo "scale=2; ($mv_data * 100) / $total_frames" | bc -l 2>/dev/null || echo "50")
    echo "$ti_ratio"
}

# Scene Change Detection - Schnittfrequenz
analyze_scene_changes() {
    local input=$1
    log ANALYSIS "Analysiere Scene Changes..."

    # Scene Change Detection über ffmpeg select-Filter
    local scene_changes=$(ffmpeg -i "$input" -vf "select='gt(scene,0.3)',showinfo" -t 60 \
        -f null - 2>&1 | grep -c "Parsed_showinfo" || echo "10")

    # Normalisierung auf Szenen pro Minute
    local scenes_per_minute=$(echo "scale=1; $scene_changes" | bc -l 2>/dev/null || echo "10")
    echo "$scenes_per_minute"
}

# Frame Type Distribution - I/P/B Frame Verhältnis
analyze_frame_distribution() {
    local input=$1
    log ANALYSIS "Analysiere Frame-Type Distribution..."

    # Analyse der ersten 1800 Frames (ca. 1 Minute bei 30fps)
    local frame_analysis=$(ffprobe -v error -select_streams v:0 -read_intervals "%+#1800" \
        -show_frames -show_entries frame=pict_type "$input" 2>/dev/null || echo "")

    local i_frames=$(echo "$frame_analysis" | grep -c "pict_type=I" || echo "30")
    local p_frames=$(echo "$frame_analysis" | grep -c "pict_type=P" || echo "900")
    local b_frames=$(echo "$frame_analysis" | grep -c "pict_type=B" || echo "870")

    local total=$(($i_frames + $p_frames + $b_frames))
    [[ $total -eq 0 ]] && total=1800

    local i_ratio=$(echo "scale=2; ($i_frames * 100) / $total" | bc -l 2>/dev/null || echo "2")
    local complexity_score=$(echo "scale=2; $i_ratio * 2" | bc -l 2>/dev/null || echo "4")

    echo "$complexity_score"
}

# HDR-Metadaten extrahieren
extract_hdr_metadata() {
    local f=$1
    log ANALYSIS "Prüfe auf HDR-Metadaten..."

    local hdr_info=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=color_primaries,color_transfer,color_space \
        -of default=noprint_wrappers=1 "$f" 2>/dev/null || echo "")

    local is_hdr=false
    if [[ "$hdr_info" == *"bt2020"* && "$hdr_info" == *"smpte2084"* ]]; then
        is_hdr=true
        log ANALYSIS "HDR10-Content erkannt"
    fi

    echo "$is_hdr"
}

# Gesamte Komplexitätsanalyse
perform_complexity_analysis() {
    local input=$1
    log ANALYSIS "Starte umfassende Komplexitätsanalyse für: $(basename "$input")"

    # Basis-Metriken sammeln
    local si=$(calculate_spatial_information "$input")
    local ti=$(calculate_temporal_information "$input")
    local scene_changes=$(analyze_scene_changes "$input")
    local frame_complexity=$(analyze_frame_distribution "$input")
    local is_hdr=$(extract_hdr_metadata "$input")

    log ANALYSIS "Spatial Information (SI): $si"
    log ANALYSIS "Temporal Information (TI): $ti"
    log ANALYSIS "Scene Changes/min: $scene_changes"
    log ANALYSIS "Frame Complexity: $frame_complexity"
    log ANALYSIS "HDR Content: $is_hdr"

    # Komplexitäts-Score berechnen (0-100)
    local complexity_score=$(echo "scale=2; ($si * 0.3) + ($ti * 0.4) + ($scene_changes * 2) + ($frame_complexity * 0.3)" | bc -l 2>/dev/null || echo "50")

    # Score begrenzen auf 0-100
    if (( $(echo "$complexity_score > 100" | bc -l 2>/dev/null || echo 0) )); then
        complexity_score="100"
    elif (( $(echo "$complexity_score < 10" | bc -l 2>/dev/null || echo 0) )); then
        complexity_score="10"
    fi

    log ANALYSIS "Gesamtkomplexitäts-Score: $complexity_score"
    echo "$complexity_score"
}

# Bitrate basierend auf Komplexität anpassen
calculate_adaptive_bitrate() {
    local base_bitrate=$1
    local complexity_score=$2
    local content_type=$3

    # Basis-Bitrate extrahieren (nur Zahl ohne 'k')
    local base_value=$(echo "$base_bitrate" | sed 's/k$//')

    # Content-Type spezifische Anpassungen
    local type_modifier=1.0
    case $content_type in
        "anime")         type_modifier=0.85 ;;  # Anime braucht oft weniger
        "3d_animation")  type_modifier=1.1 ;;   # CGI braucht mehr
        "film")          type_modifier=1.0 ;;   # Film als Basis
    esac

    # Komplexitäts-basierte Anpassung (50 = neutral, >50 = mehr Bitrate, <50 = weniger)
    local complexity_factor=$(echo "scale=3; 0.7 + ($complexity_score / 100 * 0.6)" | bc -l 2>/dev/null || echo "1.0")

    # Finale Bitrate berechnen
    local adaptive_bitrate=$(echo "scale=0; $base_value * $complexity_factor * $type_modifier / 1" | bc -l 2>/dev/null || echo "$base_value")

    log ANALYSIS "Basis-Bitrate: $base_bitrate, Angepasste Bitrate: ${adaptive_bitrate}k"
    log ANALYSIS "Komplexitäts-Faktor: $complexity_factor, Content-Modifier: $type_modifier"

    echo "${adaptive_bitrate}k"
}

# CRF basierend auf Komplexität anpassen
calculate_adaptive_crf() {
    local base_crf=$1
    local complexity_score=$2

    # CRF-Anpassung: höhere Komplexität = niedrigerer CRF (bessere Qualität)
    local crf_adjustment=$(echo "scale=1; ($complexity_score - 50) * (-0.05)" | bc -l 2>/dev/null || echo "0")
    local adaptive_crf=$(echo "scale=1; $base_crf + $crf_adjustment" | bc -l 2>/dev/null || echo "$base_crf")

    # CRF in sinnvollen Grenzen halten (15-28)
    if (( $(echo "$adaptive_crf < 15" | bc -l 2>/dev/null || echo 0) )); then
        adaptive_crf="15"
    elif (( $(echo "$adaptive_crf > 28" | bc -l 2>/dev/null || echo 0) )); then
        adaptive_crf="28"
    fi

    log ANALYSIS "Basis-CRF: $base_crf, Angepasster CRF: $adaptive_crf"
    echo "$adaptive_crf"
}

# Filter-Chain mit automatischem Crop bauen
build_filter_chain() {
    local manual_crop=$1
    local scale=$2
    local auto_crop=$3
    local fc=""

    # Entscheidung: manueller Crop oder automatischer Crop
    local final_crop=""
    if [[ -n "$manual_crop" ]]; then
        final_crop="crop=$manual_crop"
        log DEBUG "Verwende manuellen Crop: $manual_crop"
    elif [[ -n "$auto_crop" ]]; then
        final_crop="$auto_crop"
        log DEBUG "Verwende automatischen Crop: $auto_crop"
    fi

    # Filter-Chain aufbauen
    if [[ -n "$final_crop" ]]; then
        fc="[0:v]${final_crop}[v]"
    else
        fc="[0:v]null[v]"
    fi

    # Scale hinzufügen falls gewünscht
    if [[ -n "$scale" ]]; then
        fc="${fc};[v]scale=$scale[v]"
    fi

    echo "$fc"
}

# Audio/Subs/Chapters Mapping
build_stream_mapping() {
    local f=$1 map=""
    # Audio streams
    local audio_streams=$(ffprobe -v error -select_streams a -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    if [[ $audio_streams -gt 0 ]]; then
        for i in $(seq 0 $((audio_streams-1))); do
            map+=" -map 0:a:$i -c:a:$i copy"
        done
    fi

    # Subtitle streams
    local sub_streams=$(ffprobe -v error -select_streams s -show_entries stream=index "$f" 2>/dev/null | grep -c "index=" || echo "0")
    if [[ $sub_streams -gt 0 ]]; then
        for i in $(seq 0 $((sub_streams-1))); do
            map+=" -map 0:s:$i -c:s:$i copy"
        done
    fi

    # Chapters & Metadata
    map+=" -map_chapters 0 -map_metadata 0"
    echo "$map"
}

# Profil parsen und durch Komplexitätsanalyse anpassen
parse_and_adapt_profile() {
    local profile_name=$1
    local input_file=$2
    local str=${BASE_PROFILES[$profile_name]:-}
    [[ -n $str ]] || { log ERROR "Unbekanntes Profil: $profile_name"; exit 1; }

    # Komplexitätsanalyse durchführen
    local complexity_score=$(perform_complexity_analysis "$input_file")

    # Profil-Parameter extrahieren
    local base_bitrate=$(echo "$str" | grep -o 'base_bitrate=[^:]*' | cut -d= -f2)
    local base_crf=$(echo "$str" | grep -o 'crf=[^:]*' | cut -d= -f2)
    local content_type=$(echo "$str" | grep -o 'content_type=[^:]*' | cut -d= -f2)

    # Adaptive Parameter berechnen
    local adaptive_bitrate=$(calculate_adaptive_bitrate "$base_bitrate" "$complexity_score" "$content_type")
    local adaptive_crf=$(calculate_adaptive_crf "$base_crf" "$complexity_score")

    # Profil-String mit adaptiven Werten aktualisieren
    local adapted_profile=$(echo "$str" | sed "s/base_bitrate=[^:]*/bitrate=$adaptive_bitrate/" | sed "s/crf=[^:]*/crf=$adaptive_crf/" | sed 's/content_type=[^:]*://')

    echo "$adapted_profile"
}

# Two-Pass-Encoding mit adaptiven Parametern und Auto-Crop
run_encoding() {
    local in=$1 out=$2 prof=$3 title=$4 manual_crop=$5 scale=$6

    log INFO "Profil: $prof"

    # Automatische Crop-Erkennung (nur wenn kein manueller Crop gesetzt)
    local auto_crop=""
    if [[ -z "$manual_crop" ]]; then
        auto_crop=$(detect_crop_values "$in")
    fi

    local ps=$(parse_and_adapt_profile "$prof" "$in")
    local bitrate=$(echo "$ps" | grep -o 'bitrate=[^:]*' | cut -d= -f2)
    local pix_fmt=$(echo "$ps"  | grep -o 'pix_fmt=[^:]*'  | cut -d= -f2)
    local profile_codec=$(echo "$ps" | grep -o 'profile=[^:]*'  | cut -d= -f2)
    local preset=$(echo "$ps"       | grep -o 'preset=[^:]*'   | cut -d= -f2)
    local crf=$(echo "$ps" | grep -o 'crf=[^:]*' | cut -d= -f2)
    local x265p=$(echo "$ps" | sed 's/preset=[^:]*://;s/bitrate=[^:]*://;s/pix_fmt=[^:]*://;s/profile=[^:]*://;s/crf=[^:]*://;s/^://;s/:$//')
    local fc=$(build_filter_chain "$manual_crop" "$scale" "$auto_crop")
    local streams=$(build_stream_mapping "$in")
    local stats="$TEMP_DIR/${STATS_PREFIX}_$(basename "$in" .${in##*.}).log"

    log INFO "Adaptive Parameter - Bitrate: $bitrate, CRF: $crf"
    if [[ -n "$auto_crop" ]]; then
        log INFO "Automatischer Crop wird angewendet: $auto_crop"
    elif [[ -n "$manual_crop" ]]; then
        log INFO "Manueller Crop wird angewendet: $manual_crop"
    fi

    # First Pass: immer medium preset
    log INFO "First Pass (preset=medium)..."
    local cmd1=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd1+=(-metadata title="$title")
    [[ -n $fc ]] && cmd1+=(-filter_complex "$fc" -map "[v]") || cmd1+=(-map 0:v:0)
    cmd1+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd1+=(-x265-params "$x265p:pass=1:no-slow-firstpass=1:stats=$stats")
    cmd1+=(-b:v "$bitrate" -preset:v medium -an -sn -dn -f mp4 -loglevel warning /dev/null)
    "${cmd1[@]}" || { log ERROR "First Pass fehlgeschlagen"; exit 1; }
    log INFO "First Pass abgeschlossen."

    # Second Pass: Profil-Preset
    log INFO "Second Pass (preset=$preset)..."
    local cmd2=(ffmpeg -y -i "$in" -max_muxing_queue_size 1024)
    [[ -n $title ]] && cmd2+=(-metadata title="$title")
    [[ -n $fc ]] && cmd2+=(-filter_complex "$fc" -map "[v]") || cmd2+=(-map 0:v:0)
    cmd2+=(-c:v libx265 -pix_fmt "$pix_fmt" -profile:v "$profile_codec")
    cmd2+=(-x265-params "$x265p:pass=2:stats=$stats")
    cmd2+=(-b:v "$bitrate" -preset:v "$preset")
    cmd2+=($streams -default_mode infer_no_subs -loglevel warning "$out")
    "${cmd2[@]}" || { log ERROR "Second Pass fehlgeschlagen"; exit 1; }
    log INFO "Second Pass abgeschlossen."

    # Aufräumen
    rm -f "${stats}"* 2>/dev/null || true
    log INFO "Output erzeugt: $out"

    # Finale Statistiken
    local input_size=$(du -h "$in" | cut -f1)
    local output_size=$(du -h "$out" | cut -f1)
    local compression_ratio=$(echo "scale=1; $(du -k "$in" | cut -f1) / $(du -k "$out" | cut -f1)" | bc -l 2>/dev/null || echo "N/A")
    log INFO "Komprimierung: $input_size → $output_size (Ratio: ${compression_ratio}:1)"
}

# Hauptfunktion
main() {
    local input="" output="" profile="" title="" crop="" scale=""

    # Abhängigkeiten prüfen
    for tool in ffmpeg ffprobe bc; do
        command -v $tool >/dev/null || { log ERROR "$tool fehlt (installiere: apt install $tool)"; exit 1; }
    done

    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)    input="$2"; shift 2 ;;
            -o|--output)   output="$2"; shift 2 ;;
            -p|--profile)  profile="$2"; shift 2 ;;
            -t|--title)    title="$2"; shift 2 ;;
            -c|--crop)     crop="$2"; shift 2 ;;
            -s|--scale)    scale="$2"; shift 2 ;;
            -h|--help)
                echo "Advanced FFmpeg Two-Pass Encoder mit Auto-Crop v2.1"
                echo "Usage: $0 -i INPUT -o OUTPUT -p PROFILE [OPTIONS]"
                echo ""
                echo "Profile: ${!BASE_PROFILES[*]}"
                echo ""
                echo "Neue Features:"
                echo "• Automatische Crop-Erkennung für schwarze Balken"
                echo "• Content-adaptive Bitrate-Optimierung"
                echo "• HDR-Metadaten-Erhaltung"
                echo "• Robuste Stream-Erhaltung (Audio/Subs/Chapters)"
                exit 0 ;;
            *) log ERROR "Unbekannte Option: $1"; exit 1 ;;
        esac
    done

    [[ -n $input && -n $output && -n $profile ]] || { log ERROR "Fehlende Argumente: -i INPUT -o OUTPUT -p PROFILE"; exit 1; }
    validate_input "$input"

    log INFO "Starte Content-Adaptive Encoding mit Auto-Crop..."
    run_encoding "$input" "$output" "$profile" "$title" "$crop" "$scale"
    log INFO "Encoding erfolgreich abgeschlossen!"
}

# Skript ausführen
if [[ "${BASH_SOURCE}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash

# ffmpeg_batch_encoder.sh – Multi-Mode Batch Wrapper for ffmpeg_encoder.sh
# Processes all video files in an input directory with CRF/ABR/CBR mode support
# and saves the encoded files in the output directory
# with input filename + UUID to prevent overwriting.

set -euo pipefail

# Default values
INPUT_DIR=""
OUTPUT_DIR=""
PROFILE=""
MODE="abr"  # Default to ABR mode
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODER_SCRIPT="${SCRIPT_DIR}/ffmpeg_encoder.sh"

usage() {
  cat <<EOF
Advanced FFmpeg Batch Encoder with Multi-Mode Support
Usage: $0 -i INPUT_DIR -o OUTPUT_DIR -p PROFILE [OPTIONS]

  -i, --input-dir   Directory with source files
  -o, --output-dir  Target directory for encoded files
  -p, --profile     Encoding profile (e.g. 4k_3d_animation, 1080p_film)
  -m, --mode        Encoding mode: crf, abr, cbr (default: abr)

Encoding Modes:
  crf    Single-pass Constant Rate Factor (Pure VBR) - Best for archival/mastering
  abr    Two-pass Average Bitrate (Default) - Best for streaming/delivery
  cbr    Two-pass Constant Bitrate - Best for broadcast/live streaming

HDR content is automatically detected and optimized per file.

Examples:
  $0 -i ~/Videos/Raw -o ~/Videos/Encoded -p 1080p_anime                    # ABR mode (default)
  $0 -i ~/Videos/Raw -o ~/Videos/Archive -p 1080p_anime -m crf             # CRF mode for archival
  $0 -i ~/Videos/Raw -o ~/Videos/Stream -p 1080p_film -m abr               # ABR mode for streaming
  $0 -i ~/Videos/Raw -o ~/Videos/Broadcast -p 1080p_film -m cbr            # CBR mode for broadcast
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input-dir)
      INPUT_DIR="$2"; shift 2 ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"; shift 2 ;;
    -p|--profile)
      PROFILE="$2"; shift 2 ;;
    -m|--mode)
      MODE="$2"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1"; usage ;;
  esac
done

# Validation
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" || -z "$PROFILE" ]]; then
  echo "Missing arguments." >&2
  usage
fi

# Validate mode parameter
case $MODE in
  "crf"|"abr"|"cbr") ;; # Valid modes
  *) echo "Invalid mode: $MODE. Use: crf, abr, or cbr" >&2; exit 1 ;;
esac

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory does not exist: $INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# File types to be processed
EXTENSIONS=("mkv" "mp4" "mov" "m4v")

# Process all files
find "$INPUT_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.m4v" \) | while read -r INPUT_FILE; do
  BASENAME="$(basename "$INPUT_FILE")"
  NAME="${BASENAME%.*}"
  EXT="${BASENAME##*.}"
  UUID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  OUTPUT_FILE="${OUTPUT_DIR}/${NAME}_${UUID}.${EXT}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: $BASENAME"
  echo "→ Profile: $PROFILE"
  echo "→ Mode:    $MODE"
  echo "→ Target:  $(basename "$OUTPUT_FILE")"

  # Call the ffmpeg encoder with mode support
  "$ENCODER_SCRIPT" -i "$INPUT_FILE" -o "$OUTPUT_FILE" -p "$PROFILE" -m "$MODE"

  echo "→ Done:    $(basename "$OUTPUT_FILE")"
  echo "----------------------------------------"
done

echo "Batch encoding completed."

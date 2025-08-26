#!/usr/bin/env bash

# batch_encode.sh – Wrapper for ffmpeg_encoder.sh
# Processes all video files in an input directory
# and saves the encoded files in the output directory
# with input filename + UUID to prevent overwriting.

set -euo pipefail

# Default values
INPUT_DIR=""
OUTPUT_DIR=""
PROFILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODER_SCRIPT="${SCRIPT_DIR}/ffmpeg_encoder.sh"

usage() {
  cat <<EOF
Usage: $0 -i INPUT_DIR -o OUTPUT_DIR -p PROFILE

  -i, --input-dir   Directory with source files
  -o, --output-dir  Target directory for encoded files
  -p, --profile     Encoding profile (e.g. 4k_3d_animation, 1080p_film)

HDR content is automatically detected and optimized per file.

Example:
  $0 -i ~/Videos/Raw -o ~/Videos/Encoded -p 1080p_anime
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

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input directory does not exist: $INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# File types to be processed
EXTENSIONS=("mkv" "mp4" "mov" "m4v")

# Process all files
find "$INPUT_DIR" -type f \( \
  $(printf -- "-iname '*.%s' -o " "${EXTENSIONS[@]}" | sed 's/ -o $//') \
\) | while read -r INPUT_FILE; do
  BASENAME="$(basename "$INPUT_FILE")"
  NAME="${BASENAME%.*}"
  EXT="${BASENAME##*.}"
  UUID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  OUTPUT_FILE="${OUTPUT_DIR}/${NAME}_${UUID}.${EXT}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: $BASENAME"
  echo "→ Profile: $PROFILE"
  echo "→ Target:  $(basename "$OUTPUT_FILE")"

  # Call the ffmpeg encoder
  "$ENCODER_SCRIPT" -i "$INPUT_FILE" -o "$OUTPUT_FILE" -p "$PROFILE"

  echo "→ Done:    $(basename "$OUTPUT_FILE")"
  echo "----------------------------------------"
done

echo "Batch encoding completed."

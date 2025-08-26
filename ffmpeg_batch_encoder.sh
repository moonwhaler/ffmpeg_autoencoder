#!/usr/bin/env bash

# ffmpeg_batch_encoder.sh – Multi-Mode Batch Wrapper for ffmpeg_encoder.sh
# Processes all video files in an input directory with CRF/ABR/CBR mode support
# and saves the encoded files in the output directory.
# UUID generation is now handled by the main encoder script.

set -euo pipefail

# Default values
INPUT_DIR=""
PROFILE=""
MODE="abr"  # Default to ABR mode
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODER_SCRIPT="${SCRIPT_DIR}/ffmpeg_encoder.sh"

usage() {
  cat <<EOF
Advanced FFmpeg Batch Encoder with Multi-Mode Support
Usage: $0 -i INPUT_DIR -p PROFILE [OPTIONS]

  -i, --input-dir   Directory with source files
  -p, --profile     Encoding profile (e.g. 4k_3d_animation, 1080p_film)
  -m, --mode        Encoding mode: crf, abr, cbr (default: abr)

Encoding Modes:
  crf    Single-pass Constant Rate Factor (Pure VBR) - Best for archival/mastering
  abr    Two-pass Average Bitrate (Default) - Best for streaming/delivery
  cbr    Two-pass Constant Bitrate - Best for broadcast/live streaming

HDR content is automatically detected and optimized per file.

Examples:
  $0 -i ~/Videos/Raw -p 1080p_anime                                       # ABR mode (default)
  $0 -i ~/Videos/Raw -p 1080p_anime -m crf                                # CRF mode for archival
  $0 -i ~/Videos/Raw -p 1080p_film -m abr                                 # ABR mode for streaming
  $0 -i ~/Videos/Raw -p 1080p_film -m cbr                                 # CBR mode for broadcast

Note: Output files are automatically placed in the same directory as input files
with UUID-based naming to prevent overwriting.
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input-dir)
      INPUT_DIR="$2"; shift 2 ;;
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
if [[ -z "$INPUT_DIR" || -z "$PROFILE" ]]; then
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


# File types to be processed
EXTENSIONS=("mkv" "mp4" "mov" "m4v")

# Process all files
find "$INPUT_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.m4v" \) | while read -r INPUT_FILE; do
  BASENAME="$(basename "$INPUT_FILE")"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processing: $BASENAME"
  echo "→ Profile: $PROFILE"
  echo "→ Mode:    $MODE"

  # Call the ffmpeg encoder with mode support (UUID output auto-generated)
  "$ENCODER_SCRIPT" -i "$INPUT_FILE" -p "$PROFILE" -m "$MODE"

  echo "→ Done:    $BASENAME"
  echo "----------------------------------------"
done

echo "Batch encoding completed."

#!/usr/bin/env bash

# batch_encode.sh – Wrapper für ffmpeg_encoder.sh
# Verarbeitet alle Videodateien in einem Input-Verzeichnis
# und speichert die encodeten Dateien im Output-Verzeichnis
# mit Input-Dateiname + UUID, um Überschreiben zu vermeiden.

set -euo pipefail

# Default-Werte
INPUT_DIR=""
OUTPUT_DIR=""
PROFILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODER_SCRIPT="${SCRIPT_DIR}/ffmpeg_encoder.sh"

usage() {
  cat <<EOF
Usage: $0 -i INPUT_DIR -o OUTPUT_DIR -p PROFILE

  -i, --input-dir   Verzeichnis mit Quelldateien
  -o, --output-dir  Zielverzeichnis für encodierte Dateien
  -p, --profile     Encoding-Profil (z.B. 4k_3d_animation_hdr)

Beispiel:
  $0 -i ~/Videos/Raw -o ~/Videos/Encoded -p 1080p_anime
EOF
  exit 1
}

# Argumente parsen
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
      echo "Unbekannte Option: $1"; usage ;;
  esac
done

# Validierung
if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" || -z "$PROFILE" ]]; then
  echo "Fehlende Argumente." >&2
  usage
fi

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Input-Verzeichnis existiert nicht: $INPUT_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Dateitypen, die verarbeitet werden
EXTENSIONS=("mkv" "mp4" "mov" "m4v")

# Durchlaufe alle Dateien
find "$INPUT_DIR" -type f \( \
  $(printf -- "-iname '*.%s' -o " "${EXTENSIONS[@]}" | sed 's/ -o $//') \
\) | while read -r INPUT_FILE; do
  BASENAME="$(basename "$INPUT_FILE")"
  NAME="${BASENAME%.*}"
  EXT="${BASENAME##*.}"
  UUID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  OUTPUT_FILE="${OUTPUT_DIR}/${NAME}_${UUID}.${EXT}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verarbeite: $BASENAME"
  echo "→ Profil: $PROFILE"
  echo "→ Ziel:   $(basename "$OUTPUT_FILE")"

  # Aufruf des ffmpeg-Encoders
  "$ENCODER_SCRIPT" -i "$INPUT_FILE" -o "$OUTPUT_FILE" -p "$PROFILE"

  echo "→ Fertig: $(basename "$OUTPUT_FILE")"
  echo "----------------------------------------"
done

echo "Batch-Encoding abgeschlossen."

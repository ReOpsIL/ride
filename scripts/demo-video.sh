#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGES="${RIDE_SHOTS_DIR:-$ROOT/docs/images}"
OUT="${1:-$ROOT/target/demo/ride-demo.mp4}"
HOLD="${HOLD:-3.5}"
FADE="${FADE:-0.6}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ride-video.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$(dirname "$OUT")"
swiftc -O -o "$WORK/slide" "$ROOT/scripts/demo-slide.swift"

inputs=()
index=0
while IFS=$'\t' read -r scene title subtitle; do
  [[ -z "$scene" ]] && continue
  shot="-"
  if [[ "$scene" != "-" ]]; then
    shot="$IMAGES/ride-$scene.png"
    [[ -f "$shot" ]] || { echo "missing $shot" >&2; exit 1; }
  fi
  slide="$WORK/slide-$(printf %03d "$index").png"
  "$WORK/slide" "$slide" "$shot" "$title" "$subtitle"
  inputs+=(-loop 1 -framerate 30 -t "$(echo "$HOLD + $FADE" | bc)" -i "$slide")
  index=$((index + 1))
done <"$ROOT/scripts/demo-video.tsv"

filter=""
last="[0:v]"
offset=0
for ((i = 1; i < index; i++)); do
  offset=$(echo "$offset + $HOLD" | bc)
  filter+="${last}[$i:v]xfade=transition=fade:duration=$FADE:offset=$offset[v$i];"
  last="[v$i]"
done
filter+="${last}format=yuv420p[out]"

ffmpeg -y -loglevel error "${inputs[@]}" -filter_complex "$filter" -map "[out]" \
  -c:v libx264 -preset slow -crf 18 -movflags +faststart "$OUT"
echo "wrote $OUT ($index slides)"

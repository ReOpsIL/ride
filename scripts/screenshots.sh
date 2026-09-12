#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/target/xcode"
APP="$DERIVED/Build/Products/Debug/Ride.app/Contents/MacOS/Ride"
IMAGES="$ROOT/docs/images"
FRAME="1440x900"
STAGE_TIMEOUT=420

cd "$ROOT"

if [[ ! -d "$ROOT/app/RideEngine.xcframework" ]] || [[ ! -f "$ROOT/app/generated/RideEngine.swift" ]]; then
  "$ROOT/scripts/build-engine.sh"
fi

xcodebuild \
  -project "$ROOT/app/Ride.xcodeproj" \
  -scheme Ride \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

if [[ ! -x "$APP" ]]; then
  echo "Ride binary not found at $APP" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ride-shots.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/windowid" "$ROOT/scripts/windowid.swift"
swiftc -O -o "$WORK/compose" "$ROOT/scripts/compose.swift"
swiftc -O -o "$WORK/pngcheck" "$ROOT/scripts/pngcheck.swift"

mkdir -p "$WORK/clean" "$IMAGES"
cp -R "$ROOT/samples/rust-demo" "$WORK/rust-demo"
cp -R "$ROOT/samples/rust-demo" "$WORK/clean/rust-demo"
cp -R "$ROOT/samples/c-demo" "$WORK/c-demo"
cp -R "$ROOT/samples/cpp-demo" "$WORK/cpp-demo"
rm -rf "$WORK/cpp-demo/build/Debug" "$WORK/c-demo/build/Debug"

SCENES=(
  "editor rust-demo"
  "completion rust-demo"
  "cheatsheet rust-demo"
  "hover rust-demo"
  "quickdoc rust-demo"
  "peek rust-demo"
  "split rust-demo"
  "symbols rust-demo"
  "find rust-demo"
  "preview rust-demo"
  "light rust-demo"
  "problems clean/rust-demo"
  "toml rust-demo"
  "c c-demo"
  "cpp cpp-demo"
  "makefile cpp-demo"
  "cmake cpp-demo"
  "targets rust-demo"
  "run rust-demo"
  "tests rust-demo"
  "terminal rust-demo"
  "debug rust-demo"
)

await() {
  local scene="$1" ready="$2" pid="$3"
  local waited=0
  while [[ ! -f "$ready" ]]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "scene $scene exited before it was staged" >&2
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
    if ((waited >= STAGE_TIMEOUT)); then
      echo "scene $scene did not stage within ${STAGE_TIMEOUT}s" >&2
      kill -TERM "$pid" 2>/dev/null || true
      return 1
    fi
  done
}

quit() {
  local pid="$1" waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if ((waited >= 60)); then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done
  wait "$pid" 2>/dev/null || true
}

shoot() {
  local pid="$1" scene="$2" png="$3"
  local geometry id x y w h
  geometry="$("$WORK/windowid" "$pid")"
  local minx=1000000 miny=1000000 maxx=-1000000 maxy=-1000000
  while read -r id x y w h; do
    if [[ -z "$id" ]]; then
      continue
    fi
    if ((x < minx)); then minx=$x; fi
    if ((y < miny)); then miny=$y; fi
    if ((x + w > maxx)); then maxx=$((x + w)); fi
    if ((y + h > maxy)); then maxy=$((y + h)); fi
  done <<<"$geometry"
  local parts=() index=0
  while read -r id x y w h; do
    if [[ -z "$id" ]]; then
      continue
    fi
    screencapture -x -o -l "$id" "$WORK/part-$scene-$index.png"
    parts+=("$WORK/part-$scene-$index.png" "$((x - minx))" "$((y - miny))")
    index=$((index + 1))
  done <<<"$geometry"
  "$WORK/compose" "$png" "$((maxx - minx))" "$((maxy - miny))" "${parts[@]}" >/dev/null
}

capture() {
  local scene="$1"
  local folder="$WORK/$2"
  local ready="$WORK/ready-$scene"
  local png="$IMAGES/ride-$scene.png"
  rm -f "$ready"
  "$APP" --open "$folder" --demo "$scene" --frame "$FRAME" \
    --ready-file "$ready" --quit-after 15 >"$WORK/log-$scene.txt" 2>&1 &
  local pid=$!
  if ! await "$scene" "$ready" "$pid"; then
    return 1
  fi
  if ! shoot "$pid" "$scene" "$png"; then
    echo "scene $scene could not be captured" >&2
    kill -TERM "$pid" 2>/dev/null || true
    return 1
  fi
  quit "$pid"
  local stats
  if ! stats="$("$WORK/pngcheck" "$png")"; then
    echo "ride-$scene.png is a single colour: the terminal lacks the Screen Recording permission" >&2
    return 1
  fi
  echo "ride-$scene.png $stats"
}

for entry in "${SCENES[@]}"; do
  capture ${entry}
done

echo "wrote ${#SCENES[@]} screenshots to $IMAGES"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/target/xcode"
PROJECT="$ROOT/app/Ride.xcodeproj"

cd "$ROOT"

if [[ ! -d "$ROOT/app/RideEngine.xcframework" ]] || [[ ! -f "$ROOT/app/generated/RideEngine.swift" ]]; then
  "$ROOT/scripts/build-engine.sh"
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme Ride \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation \
  build

APP="$DERIVED/Build/Products/Debug/Ride.app"
if [[ ! -d "$APP" ]]; then
  echo "Ride.app not found at $APP" >&2
  exit 1
fi

if pgrep -x Ride >/dev/null; then
  osascript -e 'tell application "Ride" to quit' >/dev/null 2>&1 || true
  sleep 0.4
  pkill -x Ride >/dev/null 2>&1 || true
  sleep 0.2
fi

if [[ $# -ge 1 ]]; then
  FOLDER="$(cd "$1" && pwd)"
  open "$APP" --args --open "$FOLDER"
  echo "launched $APP --open $FOLDER"
else
  open "$APP"
  echo "launched $APP"
fi

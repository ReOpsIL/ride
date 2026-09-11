#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/target/release-app"
ARCHIVE="$OUT/Ride.xcarchive"
IDENTITY="${RIDE_SIGN_IDENTITY:--}"
VERSION="$(grep -m1 '^version' "$ROOT/Cargo.toml" | sed 's/.*"\(.*\)".*/\1/')"

cd "$ROOT"
"$ROOT/scripts/build-engine.sh"

rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild \
  -project "$ROOT/app/Ride.xcodeproj" \
  -scheme Ride \
  -configuration Release \
  -derivedDataPath "$ROOT/target/xcode-release" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  ARCHS="arm64 x86_64" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGNING_REQUIRED=NO \
  archive

APP="$ARCHIVE/Products/Applications/Ride.app"
if [[ ! -d "$APP" ]]; then
  echo "archive did not produce Ride.app" >&2
  exit 1
fi

if [[ -n "${RIDE_SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${RIDE_SPARKLE_PUBLIC_KEY}" "$APP/Contents/Info.plist"
fi

codesign --force --deep --sign "$IDENTITY" --options runtime "$APP"
codesign --verify --deep --strict "$APP"

ZIP="$OUT/Ride-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"

if [[ -n "${RIDE_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$RIDE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  shasum -a 256 "$ZIP" > "$ZIP.sha256"
fi

if [[ -z "${RIDE_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  echo "release: skip appcast (RIDE_SPARKLE_PRIVATE_KEY_FILE unset)"
else
  SPARKLE_GEN="$ROOT/target/xcode-release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
  if [[ ! -x "$SPARKLE_GEN" ]]; then
    SPARKLE_GEN="$(find "$ROOT/target/xcode-release/SourcePackages/artifacts" -name generate_appcast -type f 2>/dev/null | head -n 1)"
  fi
  if [[ -z "$SPARKLE_GEN" || ! -x "$SPARKLE_GEN" ]]; then
    echo "release: generate_appcast not found in SourcePackages" >&2
    exit 1
  fi
  "$SPARKLE_GEN" --ed-key-file "$RIDE_SPARKLE_PRIVATE_KEY_FILE" --maximum-deltas 0 "$OUT"
fi

echo "release: $ZIP"

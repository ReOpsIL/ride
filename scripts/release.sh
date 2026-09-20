#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/target/release-app"
ARCHIVE="$OUT/Ride.xcarchive"
IDENTITY="${RIDE_SIGN_IDENTITY:--}"
VERSION="$(grep -m1 '^version' "$ROOT/Cargo.toml" | sed 's/.*"\(.*\)".*/\1/')"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "release: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "release: could not read version from Cargo.toml" >&2
  exit 1
fi

agree_versions() {
  local pbx="$ROOT/app/Ride.xcodeproj/project.pbxproj"
  local found=0
  local mv
  while IFS= read -r mv; do
    found=1
    if [[ "$mv" != "$VERSION" ]]; then
      echo "release: MARKETING_VERSION $mv does not match Cargo.toml $VERSION" >&2
      exit 1
    fi
  done < <(sed -n 's/^[[:space:]]*MARKETING_VERSION = \([^;]*\);$/\1/p' "$pbx")
  if [[ "$found" -eq 0 ]]; then
    echo "release: no MARKETING_VERSION in $pbx" >&2
    exit 1
  fi
}

write_sha() {
  local file="$1"
  (cd "$(dirname "$file")" && shasum -a 256 "$(basename "$file")") >"$file.sha256"
}

print_plan() {
  echo "release: dry-run"
  echo "version: $VERSION"
  echo "identity: $IDENTITY"
  echo "engine: scripts/build-engine.sh"
  echo "archive: xcodebuild -project app/Ride.xcodeproj -scheme Ride -configuration Release -destination generic/platform=macOS ARCHS=arm64 x86_64 archive"
  echo "codesign: codesign --force --deep --sign $IDENTITY --options runtime"
  echo "zip: $OUT/Ride-$VERSION.zip"
  echo "dsym: $OUT/Ride-$VERSION.dSYM.zip"
  echo "notes: $OUT/RELEASE.md"
  if [[ -z "${RIDE_SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    echo "appcast: skip (RIDE_SPARKLE_PRIVATE_KEY_FILE unset)"
  else
    echo "appcast: generate_appcast $OUT"
  fi
  if [[ -z "${RIDE_NOTARY_PROFILE:-}" ]]; then
    echo "notary: skip (RIDE_NOTARY_PROFILE unset)"
  else
    echo "notary: notarytool submit --keychain-profile $RIDE_NOTARY_PROFILE"
  fi
}

agree_versions

if [[ -n "${RIDE_SPARKLE_PRIVATE_KEY_FILE:-}" && -z "${RIDE_SPARKLE_PUBLIC_KEY:-}" ]]; then
  echo "release: RIDE_SPARKLE_PRIVATE_KEY_FILE set but RIDE_SPARKLE_PUBLIC_KEY is not" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  print_plan
  exit 0
fi

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

DSYM="$ARCHIVE/dSYMs/Ride.app.dSYM"
if [[ ! -d "$DSYM" ]]; then
  echo "archive did not produce Ride.app.dSYM" >&2
  exit 1
fi

if [[ -n "${RIDE_SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${RIDE_SPARKLE_PUBLIC_KEY}" "$APP/Contents/Info.plist"
fi

codesign --force --deep --sign "$IDENTITY" --options runtime "$APP"
codesign --verify --deep --strict "$APP"

ZIP="$OUT/Ride-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
write_sha "$ZIP"

if [[ -n "${RIDE_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$RIDE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  write_sha "$ZIP"
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

DSYM_ZIP="$OUT/Ride-$VERSION.dSYM.zip"
ditto -c -k --keepParent "$DSYM" "$DSYM_ZIP"
write_sha "$DSYM_ZIP"

{
  echo "Ride $VERSION"
  echo
  cat "$ZIP.sha256"
  cat "$DSYM_ZIP.sha256"
} >"$OUT/RELEASE.md"

echo "release: $ZIP"

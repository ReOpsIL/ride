#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-/Applications}"
DERIVED="$ROOT/target/xcode-release"
APP_NAME="Ride.app"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

say "Checking prerequisites"
command -v xcodebuild >/dev/null || fail "Xcode is required (install from the App Store, then run: sudo xcodebuild -license accept)"
xcodebuild -version | head -1
if ! command -v cargo >/dev/null; then
  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else
    fail "Rust is required: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  fi
fi
rustc --version
if ! rustup component list --installed 2>/dev/null | grep -q '^rust-src'; then
  say "Adding rust-src so std, core and alloc are indexed"
  rustup component add rust-src
fi
say "Checking the Metal toolchain (SwiftTerm compiles shaders)"
xcodebuild -downloadComponent MetalToolchain >/dev/null 2>&1 || true

say "Building the engine and Swift bindings"
"$ROOT/scripts/build-engine.sh"

BUILT="$DERIVED/Build/Products/Release/$APP_NAME"
rm -rf "$BUILT"

say "Building $APP_NAME (Release)"
LOG="$DERIVED/install-build.log"
mkdir -p "$DERIVED"
set +e
xcodebuild \
  -project "$ROOT/app/Ride.xcodeproj" \
  -scheme Ride \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS,arch=$(uname -m)" \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGN_IDENTITY="${RIDE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_REQUIRED=NO \
  build >"$LOG" 2>&1
STATUS=$?
set -e
grep -E 'error:|\*\* BUILD' "$LOG" | tail -20 || true
[[ $STATUS -eq 0 ]] || fail "xcodebuild failed (full log: $LOG)"

[[ -d "$BUILT" ]] || fail "build did not produce $BUILT"
codesign --force --deep --sign "${RIDE_SIGN_IDENTITY:--}" "$BUILT"

say "Installing to $DEST"
mkdir -p "$DEST"
if [[ -d "$DEST/$APP_NAME" ]]; then
  if pgrep -x Ride >/dev/null; then
    osascript -e 'tell application "Ride" to quit' >/dev/null 2>&1 || true
    sleep 1
  fi
  rm -rf "$DEST/$APP_NAME"
fi
ditto "$BUILT" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true
touch "$DEST/$APP_NAME"

say "Installed $DEST/$APP_NAME"
cat <<MSG

Open it from Launchpad or with:  open "$DEST/$APP_NAME"
First launch indexes your cargo registry and the Rust sysroot (about a minute);
the progress bar sits in the status bar. Later launches are incremental.
Index location: ~/Library/Application Support/Ride/index
MSG

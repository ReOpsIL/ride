#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="aarch64-apple-darwin"
OUT_GEN="$ROOT/app/generated"
XCFRAMEWORK="$ROOT/app/RideEngine.xcframework"

rustup target add "$TARGET" >/dev/null

cargo build --release --target "$TARGET" --lib
cargo build --release --target "$TARGET" --bin ride-engine

rm -rf "$OUT_GEN"
mkdir -p "$OUT_GEN"

LIB="$ROOT/target/$TARGET/release/libride_engine.dylib"
if [[ ! -f "$LIB" ]]; then
  LIB="$ROOT/target/$TARGET/release/libride_engine.a"
fi

cargo run --release --bin uniffi-bindgen --features bindgen -- generate \
  --library "$LIB" \
  --language swift \
  --out-dir "$OUT_GEN"

HEADERS="$OUT_GEN/headers"
mkdir -p "$HEADERS"
if compgen -G "$OUT_GEN/*.h" >/dev/null; then
  cp "$OUT_GEN"/*.h "$HEADERS/"
fi
if compgen -G "$OUT_GEN/*.modulemap" >/dev/null; then
  cp "$OUT_GEN"/*.modulemap "$HEADERS/module.modulemap"
fi

STATICLIB="$ROOT/target/$TARGET/release/libride_engine.a"
rm -rf "$XCFRAMEWORK"
if [[ -f "$STATICLIB" ]] && [[ -d "$HEADERS" ]] && command -v xcodebuild >/dev/null; then
  xcodebuild -create-xcframework \
    -library "$STATICLIB" \
    -headers "$HEADERS" \
    -output "$XCFRAMEWORK"
fi

echo "built ride-engine and bindings in $OUT_GEN"

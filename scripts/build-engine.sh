#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARM="aarch64-apple-darwin"
INTEL="x86_64-apple-darwin"
OUT_GEN="$ROOT/app/generated"
XCFRAMEWORK="$ROOT/app/RideEngine.xcframework"
UNIVERSAL_LIB="$ROOT/target/universal/release/libride_engine.a"

rustup target add "$ARM" >/dev/null
rustup target add "$INTEL" >/dev/null

cargo build --release --target "$ARM" --lib
cargo build --release --target "$ARM" --bin ride-engine
cargo build --release --target "$INTEL" --lib

rm -rf "$OUT_GEN"
mkdir -p "$OUT_GEN"

LIB="$ROOT/target/$ARM/release/libride_engine.dylib"
if [[ ! -f "$LIB" ]]; then
  LIB="$ROOT/target/$ARM/release/libride_engine.a"
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

mkdir -p "$(dirname "$UNIVERSAL_LIB")"
lipo -create \
  "$ROOT/target/$ARM/release/libride_engine.a" \
  "$ROOT/target/$INTEL/release/libride_engine.a" \
  -output "$UNIVERSAL_LIB"

rm -rf "$XCFRAMEWORK"
if [[ -f "$UNIVERSAL_LIB" ]] && [[ -d "$HEADERS" ]] && command -v xcodebuild >/dev/null; then
  xcodebuild -create-xcframework \
    -library "$UNIVERSAL_LIB" \
    -headers "$HEADERS" \
    -output "$XCFRAMEWORK"
fi

echo "built ride-engine and bindings in $OUT_GEN"

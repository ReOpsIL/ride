#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASK="$ROOT/packaging/homebrew/ride.rb"
OUT="$ROOT/target/release-app"
VERSION="$(grep -m1 '^version' "$ROOT/Cargo.toml" | sed 's/.*"\(.*\)".*/\1/')"
SHA_FILE="$OUT/Ride-$VERSION.zip.sha256"

if [[ -z "$VERSION" ]]; then
  echo "cask-bump: could not read version from Cargo.toml" >&2
  exit 1
fi
if [[ ! -f "$SHA_FILE" ]]; then
  echo "cask-bump: missing $SHA_FILE" >&2
  exit 1
fi

SHA="$(awk '{print $1; exit}' "$SHA_FILE")"
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "cask-bump: invalid sha256 in $SHA_FILE" >&2
  exit 1
fi

tmp="$(mktemp)"
sed -E \
  -e "s/^  version \"[^\"]+\"/  version \"$VERSION\"/" \
  -e "s/^  sha256 \"[^\"]+\"/  sha256 \"$SHA\"/" \
  "$CASK" >"$tmp"
mv "$tmp" "$CASK"
echo "cask-bump: version $VERSION sha256 $SHA"

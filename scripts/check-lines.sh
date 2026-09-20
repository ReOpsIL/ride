#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOW="$ROOT/scripts/check-lines.allow"
LIMIT=220

allowed() {
  local path="$1"
  [[ -f "$ALLOW" ]] && grep -qxF "$path" "$ALLOW"
}

fail=0
while IFS= read -r file; do
  rel="${file#./}"
  lines=$(wc -l < "$file" | tr -d ' ')
  if (( lines > LIMIT )) && ! allowed "$rel"; then
    printf '%s %s\n' "$lines" "$rel"
    fail=1
  fi
done < <(
  cd "$ROOT"
  find . \
    \( -path ./target -o -path ./.git -o -path ./app/generated -o -path ./tests \
       -o -path ./app/RideTests -o -path ./app/RideEngine.xcframework \
       -o -path ./.claude -o -path '*/target' -o -path '*/build' \) -prune -o \
    \( -name '*.rs' -o -name '*.swift' \) -type f -print | LC_ALL=C sort
)

exit "$fail"

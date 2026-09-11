#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$ROOT/target/executor-logs"
mkdir -p "$LOGS"
cd "$ROOT"

for card in "$@"; do
  slug="$(echo "$card" | tr -c 'A-Za-z0-9.' '-' | sed 's/-*$//')"
  log="$LOGS/$slug.log"
  echo "=== $card start $(date +%H:%M:%S)" | tee -a "$LOGS/summary.txt"
  grok -p "You are the executor described in plan/roadmap/next-impl.md. Read sections 0 and 1 of that file in full first, then the card '$card' (sections 2, 6, 8 or 9). Implement that card and nothing else. Follow the repository rules in section 1.1 and the project facts in section 1.2 exactly. Run every gate in section 1.3 that applies to your change and fix what fails; when src/ffi or src/engine changed, run scripts/build-engine.sh before the xcodebuild gate. Do not commit. Do not edit files outside the card's scope, never touch the .claude directory, and do not edit README.md, AGENTS.md or docs/README.md. If a stop condition from section 1.4 applies, stop and say why. Finish by printing the hand-back block from section 1.4 with the tail of each gate's output pasted verbatim." \
    --permission-mode bypassPermissions --max-turns 200 --output-format plain > "$log" 2>&1
  status=$?
  changed="$(git status --short -- . ':!.claude' | wc -l | tr -d ' ')"
  if [[ "$changed" != "0" ]]; then
    git add -A -- . ':!.claude'
    git commit -q -m "card $card (executor)"
    sha="$(git rev-parse --short HEAD)"
  else
    sha="no-changes"
  fi
  echo "=== $card end $(date +%H:%M:%S) exit=$status files=$changed commit=$sha" | tee -a "$LOGS/summary.txt"
done
echo "=== all done $(date +%H:%M:%S)" | tee -a "$LOGS/summary.txt"

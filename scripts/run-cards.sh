#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CARDS_FILE="${CARDS_FILE:-plan/roadmap/next-impl.md}"
MAIN_ROOT="${MAIN_ROOT:-/Users/dovcaspi/develop/ride}"
LOGS="$ROOT/target/executor-logs"
mkdir -p "$LOGS"
cd "$ROOT"

ENV_FACTS="Environment: this checkout may lack the gitignored app/RideEngine.xcframework, app/generated/ and target/. If your card changes nothing under src/, copy them: cp -R $MAIN_ROOT/app/RideEngine.xcframework app/ && cp -R $MAIN_ROOT/app/generated app/ (if the copied bindings turn out stale, run bash scripts/build-engine.sh instead). If src/ffi or src/engine changed, run bash scripts/build-engine.sh (rm -rf app/RideEngine.xcframework first if a half-built one blocks it). The xcodebuild gate is: xcodebuild -project app/Ride.xcodeproj -scheme Ride -configuration Debug -derivedDataPath target/xcode -destination 'platform=macOS,arch=arm64' -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO build test. Self-tests run on a fresh never-reused copy of the sample (cp -R samples/rust-demo \"\$TMPDIR/<unique>\"; for C++ first rm -rf samples/cpp-demo/build/Debug), launching the Debug binary directly: target/xcode/Build/Products/Debug/Ride.app/Contents/MacOS/Ride -ApplePersistenceIgnoreState YES --demo selftest --open <copy> [--file src/shapes.cpp] --report <file>; never scripts/run.sh, never kill -9; wait for exit, then report grep -c '^PASS', grep -c '^FAIL', the EXIT line and every FAIL line. New Rust self-test steps go at the END of the Rust step array. When done, rm -rf target to free disk."

for card in "$@"; do
  slug="$(echo "$card" | tr -c 'A-Za-z0-9.' '-' | sed 's/-*$//')"
  log="$LOGS/$slug.log"
  echo "=== $card start $(date +%H:%M:%S)" | tee -a "$LOGS/summary.txt"
  grok -p "You are the executor described in plan/roadmap/next-impl.md. Read sections 0 and 1 of that file in full first, then the card '$card' in $CARDS_FILE. Implement that card and nothing else. Follow the repository rules in section 1.1 and the project facts in section 1.2 exactly. Run every gate the card lists and fix what fails. $ENV_FACTS Do not commit. Do not edit files outside the card's scope, never touch the .claude directory, and do not edit README.md, AGENTS.md or docs/README.md. If a stop condition from section 1.4 applies, stop and say why. Finish by printing the hand-back block from section 1.4 with the tail of each gate's output pasted verbatim." \
    --permission-mode bypassPermissions --max-turns 200 --output-format plain > "$log" 2>&1
  status=$?
  changed="$(git status --short -- . ':!.claude' | wc -l | tr -d ' ')"
  if [[ "$changed" != "0" ]]; then
    git add -A -- . ':!.claude'
    git commit -q -m "card $card (grok executor)"
    sha="$(git rev-parse --short HEAD)"
  else
    sha="no-changes"
  fi
  echo "=== $card end $(date +%H:%M:%S) exit=$status files=$changed commit=$sha" | tee -a "$LOGS/summary.txt"
done
echo "=== all done $(date +%H:%M:%S)" | tee -a "$LOGS/summary.txt"

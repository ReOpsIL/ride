#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RIDE_WRITE_MANUALS=1

xcodebuild \
  -project "$ROOT/app/Ride.xcodeproj" \
  -scheme Ride \
  -configuration Debug \
  -derivedDataPath "$ROOT/target/xcode" \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:RideTests/ShortcutsManualTests \
  test

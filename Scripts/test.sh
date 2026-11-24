#!/bin/bash
# Runs PurgioTests on the iPhone 17 simulator (iOS 27.0). Snapshot and UI tests are skipped.
# Usage: Scripts/test.sh [extra xcodebuild arguments]   (from anywhere; paths resolve from the repo root)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild test \
  -project Purgio.xcodeproj \
  -scheme Purgio \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -skip-testing:PurgioTests/SnapshotTests \
  -skip-testing:PurgioUITests \
  "$@"

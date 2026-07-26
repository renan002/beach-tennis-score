#!/bin/bash
# PROTOTYPE — throwaway. Delete with #148.
#
# One command to see the Dev Tools placement variants: builds the Dev flavor,
# installs it on a booted iPhone simulator and launches it. Flip between
# variants with the floating black bar at the bottom of Match List.
set -euo pipefail

DEVICE="${1:-iPhone 17}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/BeachTennisCounter"

xcodegen generate

DERIVED="$(mktemp -d)"
xcodebuild \
  -project BeachTennisCounter.xcodeproj \
  -scheme "Beach Dev" \
  -configuration Dev \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED/Build/Products/Dev-iphonesimulator/BeachTennisCounter.app"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" com.renan.beachtennis.dev

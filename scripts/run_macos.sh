#!/usr/bin/env bash
# Run GuidePoint on macOS (desktop app).
# Requires: Full Xcode from App Store, CocoaPods (sudo gem install cocoapods)
#
# First-time setup:
#   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
#   sudo xcodebuild -runFirstLaunch
#   sudo gem install cocoapods
#
# Usage: ./scripts/run_macos.sh

set -e
cd "$(dirname "$0")/.."

echo "Running GuidePoint on macOS..."
cd flutter_app
flutter pub get
flutter run -d macos

#!/usr/bin/env bash
# Launch the GuidePoint Android emulator from the command line.
# Usage: ./scripts/open_emulator.sh   (run from project root)

set -e
cd "$(dirname "$0")/.."

echo "Launching Android emulator (GuidePoint_Phone)..."
flutter emulators --launch GuidePoint_Phone

echo ""
echo "Wait 30–60 seconds for the emulator to boot, then run the app with:"
echo "  cd flutter_app && flutter run"
echo "  (choose the Android emulator when prompted, or: flutter run -d emulator-5554)"

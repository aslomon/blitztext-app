#!/bin/bash
set -euo pipefail

# Blitztext macOS App — Run unit tests
# Apple-Silicon only: WhisperKit (ArgmaxOSS) ships an arm64-only binary, so the test build
# must be pinned to arm64. The app's own ./build.sh produces a universal binary via `clean build`
# (not `test`) and is unaffected.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/BlitztextMac"
cd "$PROJECT_DIR"

if command -v xcodegen &>/dev/null; then
    echo "⚙️  Generiere Xcode-Projekt ..."
    xcodegen generate 2>&1
fi

echo "🧪 Führe Unit-Tests aus (arm64) ..."
xcodebuild test \
    -project BlitztextMac.xcodeproj \
    -scheme BlitztextMac \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    -derivedDataPath "$SCRIPT_DIR/.derivedData-tests" \
    | tail -60

echo "✅ Tests durchgelaufen."

#!/bin/bash
set -euo pipefail

# Blitztext macOS App - Build & Run
# Voraussetzungen: Full Xcode with Command Line Tools, xcodegen

RUN_AFTER=false
INSTALL_APP=false
BUILD_CONFIGURATION="Release"
UNIVERSAL_ARCHS="arm64 x86_64"

for arg in "$@"; do
    case "$arg" in
        --debug)
            BUILD_CONFIGURATION="Debug"
            ;;
        --run)
            RUN_AFTER=true
            ;;
        --install)
            INSTALL_APP=true
            ;;
        --release)
            BUILD_CONFIGURATION="Release"
            ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Verwendung: ./build.sh [--install] [--run] [--release] [--debug]"
            exit 1
            ;;
    esac
done

CODESIGN_IDENTITY_NAME="Blitztext Local Dev"
# Absolute path is set after PROJECT_DIR is known (see below).
ENTITLEMENTS_PATH=""
# Resolved once by resolve_codesign_identity(): "stable" or "adhoc".
CODESIGN_MODE="adhoc"

# Decides whether we can sign with the stable local identity or must fall back to
# ad-hoc. Stable signing requires BOTH: the identity exists in the codesigning
# keychain AND a throwaway test-sign with it actually succeeds (covers the case
# where the identity is listed but codesign has no key access yet).
resolve_codesign_identity() {
    if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$CODESIGN_IDENTITY_NAME"; then
        CODESIGN_MODE="adhoc"
        return
    fi

    local test_dir
    test_dir="$(mktemp -d -t blitztext-codesign-test)"
    local test_file="$test_dir/codesign-test"
    printf 'blitztext' > "$test_file"

    if codesign --force --sign "$CODESIGN_IDENTITY_NAME" "$test_file" >/dev/null 2>&1; then
        CODESIGN_MODE="stable"
    else
        CODESIGN_MODE="adhoc"
    fi

    rm -rf "$test_dir"
}

# Signs the app bundle using the resolved mode. Stable mode uses the local
# identity + hardened runtime + entitlements so the CDHash stays constant across
# rebuilds (TCC grants survive). Ad-hoc mode is the clean fallback when no
# identity is installed — the build still succeeds.
sign_app_bundle() {
    local target="$1"

    if [ "$CODESIGN_MODE" = "stable" ]; then
        echo "🔏 Signiere mit stabiler lokaler Identitaet (\"$CODESIGN_IDENTITY_NAME\"). Bedienungshilfen-Freigaben ueberleben Rebuilds."
        codesign --force --options runtime \
            --entitlements "$ENTITLEMENTS_PATH" \
            --sign "$CODESIGN_IDENTITY_NAME" "$target" 2>&1
    else
        echo "🔏 Signiere lokale Development-App ad-hoc. Dieses Artefakt ist nicht notarisiert."
        echo "   Tipp: Fuehre einmalig scripts/create-dev-cert.sh aus, damit Bedienungshilfen-Freigaben Rebuilds ueberleben."
        codesign --force --sign - "$target" 2>&1
    fi
}

verify_universal_app() {
    local app_path="$1"
    local app_name
    local binary_path
    local archs

    app_name="$(basename "$app_path" .app)"
    binary_path="$app_path/Contents/MacOS/$app_name"

    if [ ! -f "$binary_path" ]; then
        echo "❌ Konnte App-Binary nicht finden: $binary_path"
        exit 1
    fi

    archs="$(lipo -archs "$binary_path" 2>/dev/null || true)"

    if [[ -z "$archs" ]]; then
        echo "❌ Konnte Architekturen nicht lesen: $binary_path"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    if [[ " $archs " != *" arm64 "* || " $archs " != *" x86_64 "* ]]; then
        echo "❌ Build ist nicht universal. Erwartet: arm64 + x86_64"
        echo "   Gefunden: $archs"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    echo "✅ Universal Binary verifiziert: $archs"
}

ensure_xcodebuild_available() {
    if xcodebuild -version >/dev/null 2>&1; then
        return
    fi

    local default_xcode="/Applications/Xcode.app/Contents/Developer"
    if [ -d "$default_xcode" ]; then
        export DEVELOPER_DIR="$default_xcode"
        if xcodebuild -version >/dev/null 2>&1; then
            echo "⚠️  Aktiver Developer-Pfad nutzt kein vollständiges Xcode. Verwende: $DEVELOPER_DIR"
            return
        fi
    fi

    echo "❌ xcodebuild ist nicht verfügbar."
    echo "   Installiere Xcode und wähle es mit:"
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/BlitztextMac"
PROJECT_FILE="$PROJECT_DIR/BlitztextMac.xcodeproj"
DERIVED_DATA_PATH="$SCRIPT_DIR/.derivedData-blitztextmac-build"
ENTITLEMENTS_PATH="$PROJECT_DIR/Resources/BlitztextMac.entitlements"
cd "$PROJECT_DIR"

ensure_xcodebuild_available

if command -v xcodegen &> /dev/null; then
    echo "⚙️  Generiere Xcode-Projekt ..."
    xcodegen generate 2>&1
elif [ -d "$PROJECT_FILE" ]; then
    echo "⚠️  xcodegen nicht gefunden – nutze vorhandenes Xcode-Projekt."
else
    echo "❌ xcodegen fehlt."
    echo "   Installiere xcodegen explizit mit:"
    echo "   brew install xcodegen"
    echo "   Oder stelle sicher, dass $PROJECT_FILE vorhanden ist."
    exit 1
fi

# Bauen
echo "🔨 Baue Blitztext ..."
# ENABLE_DEBUG_DYLIB=NO: Xcode 16 splits Debug builds into a launcher + Blitztext.debug.dylib.
# Our standalone re-sign (sign_app_bundle) signs the bundle non-deep, so the nested debug dylib
# keeps its original signature → mismatched Team IDs → dyld aborts at launch. Forcing a single
# merged binary (as Release already is) keeps `--debug` builds launchable outside Xcode. No-op for
# Release. Does NOT affect Xcode's own interactive builds/previews (this only constrains build.sh).
xcodebuild \
    -project BlitztextMac.xcodeproj \
    -scheme BlitztextMac \
    -destination 'platform=macOS' \
    -configuration "$BUILD_CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="$UNIVERSAL_ARCHS" \
    ENABLE_DEBUG_DYLIB=NO \
    clean build

# App finden
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION/Blitztext.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build fehlgeschlagen – keine App gefunden."
    exit 1
fi

verify_universal_app "$APP_PATH"

# Resources manuell ins Bundle kopieren (xcodegen kopiert sie nicht automatisch)
echo "📋 Kopiere Resources ..."
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
cp -f "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/" 2>/dev/null || true
if [ -d "$PROJECT_DIR/Resources/AppIcon.icon" ]; then
    rm -rf "$RESOURCES_DIR/AppIcon.icon"
    ditto "$PROJECT_DIR/Resources/AppIcon.icon" "$RESOURCES_DIR/AppIcon.icon"
fi
cp -f "$PROJECT_DIR/Resources/menubar_icon.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/menubar_icon@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true

# In Projektordner kopieren
DEST="$SCRIPT_DIR/Blitztext.app"
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"
resolve_codesign_identity
sign_app_bundle "$DEST"
verify_universal_app "$DEST"

RUN_TARGET="$DEST"

if [ "$INSTALL_APP" = true ]; then
    APPS_DIR="/Applications"
    INSTALL_DEST="$APPS_DIR/Blitztext.app"
    if [ ! -w "$APPS_DIR" ]; then
        echo "❌ /Applications ist nicht beschreibbar."
        echo "   Fuehre den Befehl mit passenden Rechten erneut aus oder ziehe die App manuell nach /Applications."
        exit 1
    fi
    rm -rf "$INSTALL_DEST"
    cp -R "$DEST" "$INSTALL_DEST"
    sign_app_bundle "$INSTALL_DEST"
    verify_universal_app "$INSTALL_DEST"
    RUN_TARGET="$INSTALL_DEST"
fi

echo ""
echo "✅ Fertig! App liegt unter:"
echo "   $DEST"
if [ "$INSTALL_APP" = true ]; then
    echo "   $RUN_TARGET"
fi
echo ""
echo "Build-Typ: $BUILD_CONFIGURATION"
echo "Architekturen: $UNIVERSAL_ARCHS"
echo "Kompatibel: Apple Silicon + Intel (macOS 14+)"
echo ""
echo "Naechste Schritte:"
echo "1. App starten"
echo "2. Mikrofon erlauben"
echo "3. Fuer direktes Einfuegen zusaetzlich Bedienungshilfen erlauben"
echo "4. In Blitztext deinen eigenen OpenAI API Key eintragen"
echo "5. Loslegen und bei Bedarf im Code weiterbauen"
echo ""

# Optional: direkt starten
if [ "$RUN_AFTER" = true ]; then
    echo "🚀 Starte Blitztext ..."
    open "$RUN_TARGET"
fi

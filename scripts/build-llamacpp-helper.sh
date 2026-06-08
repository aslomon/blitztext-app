#!/bin/bash
set -euo pipefail

# Builds a pinned universal macOS llama.cpp `llama-server` helper for Blitztext packaging.
# Output stays in .derivedData-llamacpp-helper/ so generated source/build artifacts are not tracked.

LLAMACPP_REPO="${LLAMACPP_REPO:-https://github.com/ggml-org/llama.cpp.git}"
LLAMACPP_REF="${LLAMACPP_REF:-b9360}"
UNIVERSAL_ARCHS="${UNIVERSAL_ARCHS:-arm64;x86_64}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${LLAMACPP_WORK_DIR:-$ROOT_DIR/.derivedData-llamacpp-helper}"
SRC_DIR="$WORK_DIR/src"
BUILD_DIR="$WORK_DIR/build-$LLAMACPP_REF"
OUTPUT_DIR="$WORK_DIR/output"
OUTPUT_HELPER="$OUTPUT_DIR/llama-server"

usage() {
    echo "Usage: $0 [--ref <llama.cpp-release-or-commit>] [--repo <git-url>]"
    echo ""
    echo "Environment:"
    echo "  LLAMACPP_REF       llama.cpp release tag/commit (default: b9360)"
    echo "  LLAMACPP_REPO      git repository URL"
    echo "  UNIVERSAL_ARCHS    CMAKE_OSX_ARCHITECTURES value (default: arm64;x86_64)"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ref)
            LLAMACPP_REF="$2"
            shift 2
            ;;
        --repo)
            LLAMACPP_REPO="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1"
        exit 1
    fi
}

require_command git
require_command cmake
require_command lipo
require_command shasum

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

if [ ! -d "$SRC_DIR/.git" ]; then
    git clone --filter=blob:none "$LLAMACPP_REPO" "$SRC_DIR"
fi

git -C "$SRC_DIR" fetch --tags --force
git -C "$SRC_DIR" checkout --force "$LLAMACPP_REF"
git -C "$SRC_DIR" submodule update --init --recursive

rm -rf "$BUILD_DIR"
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$UNIVERSAL_ARCHS" \
    -DGGML_NATIVE=OFF \
    -DLLAMA_CURL=OFF

cmake --build "$BUILD_DIR" --config Release --target llama-server --parallel

BUILT_HELPER=""
for candidate in \
    "$BUILD_DIR/bin/llama-server" \
    "$BUILD_DIR/bin/Release/llama-server" \
    "$BUILD_DIR/tools/server/llama-server"; do
    if [ -x "$candidate" ]; then
        BUILT_HELPER="$candidate"
        break
    fi
done

if [ -z "$BUILT_HELPER" ]; then
    echo "Could not find built llama-server in $BUILD_DIR"
    exit 1
fi

cp -f "$BUILT_HELPER" "$OUTPUT_HELPER"
chmod 755 "$OUTPUT_HELPER"

ARCHS="$(lipo -archs "$OUTPUT_HELPER")"
if [[ " $ARCHS " != *" arm64 "* || " $ARCHS " != *" x86_64 "* ]]; then
    echo "Built helper is not universal. Found: $ARCHS"
    exit 1
fi

SHA256="$(shasum -a 256 "$OUTPUT_HELPER" | awk '{print $1}')"

echo ""
echo "llama-server built successfully"
echo "Path:   $OUTPUT_HELPER"
echo "Archs:  $ARCHS"
echo "SHA256: $SHA256"
echo ""
echo "Package with:"
echo "./build.sh --release --llamacpp-helper=\"$OUTPUT_HELPER\" --llamacpp-helper-sha256=\"$SHA256\""

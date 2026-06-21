#!/usr/bin/env bash
set -euo pipefail

MODE="auto"
SKIP_CODESIGN=false
SKIP_LIPO=false
SKIP_SIDECAR_RUN=false
REQUIRE_ICON=false
REQUIRED_VERSION=""
APP_PATH=""

usage() {
    cat <<USAGE
Usage: verify-app-bundle.sh [--mode auto|single|universal] [--require-icon] [--require-version VERSION] [--skip-codesign] [--skip-lipo] [--skip-sidecar-run] APP_PATH

Verifies a local MACKAN.app bundle layout.

Modes:
  auto       Infer layout from the app executable architecture. Default.
  single     Require direct Resources/MACKAN.Service/MACKAN.Service layout.
  universal  Require Resources/MACKAN.Service/osx-arm64 and osx-x64 layouts.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

require_file() {
    local path="$1"

    [[ -f "$path" ]] || fail "Required file missing: $path"
}

require_executable() {
    local path="$1"

    require_file "$path"
    [[ -x "$path" ]] || fail "Required executable is not executable: $path"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --skip-codesign)
            SKIP_CODESIGN=true
            shift
            ;;
        --skip-lipo)
            SKIP_LIPO=true
            shift
            ;;
        --skip-sidecar-run)
            SKIP_SIDECAR_RUN=true
            shift
            ;;
        --require-icon)
            REQUIRE_ICON=true
            shift
            ;;
        --require-version)
            REQUIRED_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$APP_PATH" ]]; then
                echo "Unexpected extra argument: $1" >&2
                usage >&2
                exit 2
            fi
            APP_PATH="$1"
            shift
            ;;
    esac
done

case "$MODE" in
    auto|single|universal)
        ;;
    *)
        echo "Unsupported mode: $MODE" >&2
        usage >&2
        exit 2
        ;;
esac

if [[ -z "$APP_PATH" ]]; then
    usage >&2
    exit 2
fi

if [[ "$SKIP_LIPO" == "true" && "$MODE" == "auto" ]]; then
    fail "--skip-lipo requires --mode single or --mode universal."
fi

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"

CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SERVICE_DIR="$RESOURCES_DIR/MACKAN.Service"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

require_file "$INFO_PLIST"
plutil -lint "$INFO_PLIST" >/dev/null

BUNDLE_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
[[ -n "$BUNDLE_EXECUTABLE" ]] || fail "CFBundleExecutable is empty in $INFO_PLIST"

if [[ -n "$REQUIRED_VERSION" ]]; then
    BUNDLE_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || true)"
    BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || true)"

    [[ -n "$BUNDLE_SHORT_VERSION" ]] || fail "CFBundleShortVersionString is missing in $INFO_PLIST"
    [[ -n "$BUNDLE_VERSION" ]] || fail "CFBundleVersion is missing in $INFO_PLIST"

    if [[ "$BUNDLE_SHORT_VERSION" != "$REQUIRED_VERSION" ]]; then
        fail "CFBundleShortVersionString '$BUNDLE_SHORT_VERSION' does not match required version '$REQUIRED_VERSION'."
    fi

    if [[ "$BUNDLE_VERSION" != "$REQUIRED_VERSION" ]]; then
        fail "CFBundleVersion '$BUNDLE_VERSION' does not match required version '$REQUIRED_VERSION'."
    fi
fi

if [[ "$REQUIRE_ICON" == "true" ]]; then
    BUNDLE_ICON_FILE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST" 2>/dev/null || true)"
    [[ -n "$BUNDLE_ICON_FILE" ]] || fail "CFBundleIconFile is missing in $INFO_PLIST"
    [[ "$BUNDLE_ICON_FILE" != *.icns ]] \
        || fail "CFBundleIconFile should omit the .icns extension so Finder resolves the app icon: $BUNDLE_ICON_FILE"
    case "$BUNDLE_ICON_FILE" in
        *.icns) ICON_FILE_NAME="$BUNDLE_ICON_FILE" ;;
        *) ICON_FILE_NAME="$BUNDLE_ICON_FILE.icns" ;;
    esac
    ICON_PATH="$RESOURCES_DIR/$ICON_FILE_NAME"
    [[ -f "$ICON_PATH" ]] || fail "App icon missing: $ICON_PATH"
    file "$ICON_PATH" | grep -F "Mac OS X icon" >/dev/null \
        || fail "App icon missing or not an .icns file: $ICON_PATH"
fi

APP_EXECUTABLE="$MACOS_DIR/$BUNDLE_EXECUTABLE"
require_executable "$APP_EXECUTABLE"

if [[ "$SKIP_LIPO" != "true" ]]; then
    LIPO_INFO="$(lipo -info "$APP_EXECUTABLE" 2>&1)" \
        || fail "Unable to inspect app executable architecture: $LIPO_INFO"

    HAS_ARM64=false
    HAS_X64=false
    if [[ "$LIPO_INFO" == *"arm64"* ]]; then
        HAS_ARM64=true
    fi
    if [[ "$LIPO_INFO" == *"x86_64"* ]]; then
        HAS_X64=true
    fi

    if [[ "$MODE" == "auto" ]]; then
        if [[ "$HAS_ARM64" == "true" && "$HAS_X64" == "true" ]]; then
            MODE="universal"
        else
            MODE="single"
        fi
    elif [[ "$MODE" == "universal" ]]; then
        [[ "$HAS_ARM64" == "true" && "$HAS_X64" == "true" ]] \
            || fail "Universal app executable must contain arm64 and x86_64: $LIPO_INFO"
    elif [[ "$HAS_ARM64" == "true" && "$HAS_X64" == "true" ]]; then
        fail "Single-arch app executable unexpectedly contains both arm64 and x86_64: $LIPO_INFO"
    fi
fi

case "$MODE" in
    single)
        SIDECAR_EXECUTABLE="$SERVICE_DIR/MACKAN.Service"
        require_executable "$SIDECAR_EXECUTABLE"
        ;;
    universal)
        ARM64_SIDECAR="$SERVICE_DIR/osx-arm64/MACKAN.Service"
        X64_SIDECAR="$SERVICE_DIR/osx-x64/MACKAN.Service"
        require_executable "$ARM64_SIDECAR"
        require_executable "$X64_SIDECAR"
        case "$(uname -m)" in
            arm64) SIDECAR_EXECUTABLE="$ARM64_SIDECAR" ;;
            x86_64) SIDECAR_EXECUTABLE="$X64_SIDECAR" ;;
            *) fail "Unsupported host architecture: $(uname -m)" ;;
        esac
        ;;
    *)
        fail "Internal error: unresolved mode $MODE"
        ;;
esac

if [[ "$SKIP_CODESIGN" != "true" ]]; then
    codesign --verify --deep --strict "$APP_PATH"
fi

if [[ "$SKIP_SIDECAR_RUN" != "true" ]]; then
    SIDECAR_RESPONSE="$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"app.version"}' | "$SIDECAR_EXECUTABLE" 2>&1)" \
        || fail "Sidecar app.version failed: $SIDECAR_RESPONSE"
    [[ "$SIDECAR_RESPONSE" == *'"result"'* ]] \
        || fail "Sidecar app.version did not return a JSON-RPC result: $SIDECAR_RESPONSE"
fi

echo "Verified $APP_PATH ($MODE)"

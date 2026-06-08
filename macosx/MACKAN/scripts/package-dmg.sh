#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_APP_SCRIPT="$SCRIPT_DIR/build-dev-app.sh"

APP_NAME="${APP_NAME:-MACKAN}"
APP_VERSION="${APP_VERSION:-}"
DEFAULT_BUILD_ROOT="${HOME}/Library/Caches/MACKAN/build"
BUILD_ROOT="${BUILD_ROOT:-$DEFAULT_BUILD_ROOT}"
BUILD_APP="${MACKAN_BUILD_APP:-true}"
VERIFY_CODESIGN="${MACKAN_VERIFY_CODESIGN:-true}"
UNIVERSAL="${MACKAN_UNIVERSAL:-false}"
VOLUME_NAME="${MACKAN_DMG_VOLUME_NAME:-$APP_NAME $APP_VERSION}"
APP_PATH="${APP_PATH:-$BUILD_ROOT/$APP_NAME.app}"
DMG_PATH="${DMG_PATH:-}"
STAGING_DIR=""

usage() {
    cat <<USAGE
Usage: package-dmg.sh [--app PATH] [--output PATH] [--volume-name NAME] [--no-build] [--universal]

Builds a local MACKAN DMG from a native .app bundle.

Environment:
  APP_NAME                 App bundle name. Default: MACKAN
  APP_VERSION              Bundle/DMG version. If set, reused for volume and default DMG naming.
                           If unset, version is inferred from APP_PATH Info.plist or falls back to 0.1.0.
  BUILD_ROOT               Build output root. Default: ~/Library/Caches/MACKAN/build
  MACKAN_BUILD_APP         true/false; run build-dev-app.sh before packaging. Default: true
  MACKAN_VERIFY_CODESIGN   true/false; verify app codesign before packaging. Default: true
  MACKAN_UNIVERSAL         true/false; build universal app before packaging. Default: false
  MACKAN_DMG_VOLUME_NAME   DMG mounted volume name. Default: "\$APP_NAME \$APP_VERSION"
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$2"
            shift 2
            ;;
        --output)
            DMG_PATH="$2"
            shift 2
            ;;
        --volume-name)
            VOLUME_NAME="$2"
            shift 2
            ;;
        --no-build)
            BUILD_APP=false
            shift
            ;;
        --universal)
            UNIVERSAL=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

resolve_app_version() {
    local info_plist="$APP_PATH/Contents/Info.plist"
    local short_version=""
    local bundle_version=""

    if [[ -z "$APP_VERSION" && -f "$info_plist" ]]; then
        short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist" 2>/dev/null || true)"
        bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist" 2>/dev/null || true)"
        APP_VERSION="${short_version:-$bundle_version}"
    fi

    APP_VERSION="${APP_VERSION:-0.1.0}"
    DMG_PATH="${DMG_PATH:-$BUILD_ROOT/$APP_NAME-$APP_VERSION.dmg}"
    VOLUME_NAME="${MACKAN_DMG_VOLUME_NAME:-$APP_NAME $APP_VERSION}"
}

case "$UNIVERSAL" in
    true|false)
        ;;
    *)
        echo "MACKAN_UNIVERSAL must be true or false." >&2
        exit 2
        ;;
esac

cleanup() {
    if [[ -n "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

if [[ "$BUILD_APP" == "true" ]]; then
    if [[ "$UNIVERSAL" == "true" ]]; then
        APP_PATH="$("$BUILD_APP_SCRIPT" --universal)"
    else
        APP_PATH="$("$BUILD_APP_SCRIPT")"
    fi
elif [[ "$BUILD_APP" != "false" ]]; then
    echo "MACKAN_BUILD_APP must be true or false." >&2
    exit 2
fi

resolve_app_version

if [[ "$UNIVERSAL" == "true" && "$DMG_PATH" == "$BUILD_ROOT/$APP_NAME-$APP_VERSION.dmg" ]]; then
    DMG_PATH="$BUILD_ROOT/$APP_NAME-$APP_VERSION-universal.dmg"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "App bundle not found: $APP_PATH" >&2
    exit 1
fi

if [[ "$APP_PATH" != *.app ]]; then
    echo "App path must point to a .app bundle: $APP_PATH" >&2
    exit 1
fi

if [[ "$VERIFY_CODESIGN" == "true" ]]; then
    codesign --verify --deep --strict "$APP_PATH"
elif [[ "$VERIFY_CODESIGN" != "false" ]]; then
    echo "MACKAN_VERIFY_CODESIGN must be true or false." >&2
    exit 2
fi

mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-dmg-stage.XXXXXX")"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
find "$STAGING_DIR" \( -name '.DS_Store' -o -name '._*' \) -delete
xattr -cr "$STAGING_DIR"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

hdiutil verify "$DMG_PATH" >/dev/null

echo "$DMG_PATH"

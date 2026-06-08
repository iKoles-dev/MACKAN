#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_LAUNCH="$SCRIPT_DIR/verify-app-launch.sh"

DMG_PATH=""
TIMEOUT_SECONDS="25"
APP_NAME=""
REQUIRED_VERSION=""

usage() {
    cat <<USAGE
Usage: test-clean-install-smoke.sh [--timeout SECONDS] [--app-name NAME] [--require-version VERSION] DMG_PATH

Mounts a DMG, copies the app into a clean temporary path, and runs the
launch smoke checks through verify-app-launch.sh.
USAGE
}

cleanup() {
    if [[ -n "${MOUNT_DIR:-}" && -d "$MOUNT_DIR" && "${MOUNTED:-false}" == true ]]; then
        for _ in {1..12}; do
            hdiutil detach "$MOUNT_DIR" -quiet && break || true
            hdiutil detach -force "$MOUNT_DIR" -quiet && break || true
            sleep 0.25
        done
    fi
    if [[ -n "${TMP_WORK_DIR:-}" && -d "$TMP_WORK_DIR" ]]; then
        rm -rf "$TMP_WORK_DIR" || true
    fi
}

trap cleanup EXIT

TMP_WORK_DIR=""
MOUNT_DIR=""
MOUNTED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --require-version)
            REQUIRED_VERSION="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$DMG_PATH" ]]; then
                echo "Unexpected extra argument: $1" >&2
                usage >&2
                exit 2
            fi
            DMG_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$DMG_PATH" ]]; then
    usage >&2
    exit 2
fi

[[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || {
    echo "--timeout must be a positive integer." >&2
    exit 2
}
[[ "$TIMEOUT_SECONDS" -gt 0 ]] || {
    echo "--timeout must be greater than zero." >&2
    exit 2
}

[[ -f "$DMG_PATH" ]] || {
    echo "DMG file not found: $DMG_PATH" >&2
    exit 1
}

TMP_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-clean-smoke.XXXXXX")"
MOUNT_DIR="$TMP_WORK_DIR/mount"
mkdir -p "$MOUNT_DIR"

hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" >/dev/null
MOUNTED=true

if [[ -n "$APP_NAME" ]]; then
    APP_PATH="$MOUNT_DIR/$APP_NAME.app"
    [[ -d "$APP_PATH" ]] || {
        echo "Expected app '$APP_NAME.app' in DMG mount: $DMG_PATH" >&2
        echo "Available entries at mount:" >&2
        find "$MOUNT_DIR" -maxdepth 2 -type d -name '*.app' -print
        exit 1
    }
else
    APP_PATH="$(find "$MOUNT_DIR" -maxdepth 2 -type d -name '*.app' | head -n 1 || true)"
    [[ -n "$APP_PATH" ]] || {
        echo "No .app bundle found in DMG mount: $DMG_PATH" >&2
        exit 1
    }
fi

if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    BUNDLE_SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
    BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"

    if [[ -n "$REQUIRED_VERSION" ]]; then
        [[ -n "$BUNDLE_SHORT_VERSION" ]] || {
            echo "CFBundleShortVersionString is missing in $APP_PATH/Contents/Info.plist" >&2
            exit 1
        }
        [[ -n "$BUNDLE_VERSION" ]] || {
            echo "CFBundleVersion is missing in $APP_PATH/Contents/Info.plist" >&2
            exit 1
        }
        [[ "$BUNDLE_SHORT_VERSION" == "$REQUIRED_VERSION" ]] || {
            echo "CFBundleShortVersionString '$BUNDLE_SHORT_VERSION' does not match required version '$REQUIRED_VERSION'." >&2
            exit 1
        }
        [[ "$BUNDLE_VERSION" == "$REQUIRED_VERSION" ]] || {
            echo "CFBundleVersion '$BUNDLE_VERSION' does not match required version '$REQUIRED_VERSION'." >&2
            exit 1
        }
    fi
fi

INSTALL_ROOT="$TMP_WORK_DIR/Applications"
mkdir -p "$INSTALL_ROOT"
INSTALL_APP_PATH="$INSTALL_ROOT/$(basename "$APP_PATH")"
cp -R "$APP_PATH" "$INSTALL_ROOT/"
xattr -cr "$INSTALL_APP_PATH" || true
xattr -d com.apple.quarantine "$INSTALL_APP_PATH"/* 2>/dev/null || true

"$VERIFY_LAUNCH" --timeout "$TIMEOUT_SECONDS" "$INSTALL_APP_PATH"

echo "Verified clean install launch smoke: $DMG_PATH"

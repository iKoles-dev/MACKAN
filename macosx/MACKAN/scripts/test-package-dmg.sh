#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_SCRIPT="$SCRIPT_DIR/package-dmg.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-dmg-test.XXXXXX")"
MOUNT_DIR="$WORK_DIR/mount"
APP_DIR="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/out/MACKAN-test.dmg"
ATTACHED=false

cleanup() {
    if [[ "$ATTACHED" == "true" ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS" "$WORK_DIR/out" "$MOUNT_DIR"
printf '#!/usr/bin/env bash\nexit 0\n' > "$APP_DIR/Contents/MacOS/MACKAN"
chmod +x "$APP_DIR/Contents/MacOS/MACKAN"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.test</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1-test</string>
    <key>CFBundleVersion</key>
    <string>0.1-test</string>
</dict>
</plist>
PLIST

MACKAN_BUILD_APP=false \
MACKAN_VERIFY_CODESIGN=false \
    "$PACKAGE_SCRIPT" \
    --app "$APP_DIR" \
    --output "$DMG_PATH" \
    --volume-name "MACKAN Test"

test -s "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" >/dev/null
ATTACHED=true

test -d "$MOUNT_DIR/MACKAN.app"
test -L "$MOUNT_DIR/Applications"

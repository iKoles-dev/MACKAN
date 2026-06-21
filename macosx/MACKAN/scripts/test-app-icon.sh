#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_ICON_SCRIPT="$SCRIPT_DIR/generate-app-icon.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-app-bundle.sh"
BUILD_APP_SCRIPT="$SCRIPT_DIR/build-dev-app.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-icon-test.XXXXXX")"
ICON_PATH="$WORK_DIR/MACKAN.icns"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

"$GENERATE_ICON_SCRIPT" --output "$ICON_PATH"
test -s "$ICON_PATH"
file "$ICON_PATH" | grep -F "Mac OS X icon" >/dev/null

ICONSET_PATH="$WORK_DIR/MACKAN.iconset"
iconutil -c iconset "$ICON_PATH" -o "$ICONSET_PATH"
swift - "$ICONSET_PATH/icon_512x512@2x.png" <<'SWIFT'
import AppKit
import Foundation

let path = CommandLine.arguments[1]
guard let data = try? Data(contentsOf: URL(filePath: path)),
      let image = NSBitmapImageRep(data: data) else {
    fputs("Could not read generated app icon PNG: \(path)\n", stderr)
    exit(1)
}

let corners = [
    (0, 0),
    (image.pixelsWide - 1, 0),
    (0, image.pixelsHigh - 1),
    (image.pixelsWide - 1, image.pixelsHigh - 1),
]

for (x, y) in corners {
    let alpha = image.colorAt(x: x, y: y)?.alphaComponent ?? 1
    if alpha > 0.01 {
        fputs("App icon corner at (\(x), \(y)) is not transparent.\n", stderr)
        exit(1)
    }
}
SWIFT

write_executable() {
    local path="$1"

    printf '#!/usr/bin/env bash\nexit 0\n' > "$path"
    chmod +x "$path"
}

make_app() {
    local app_dir="$1"
    local include_icon="$2"

    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/MACKAN.Service"
    write_executable "$app_dir/Contents/MacOS/MACKAN"
    write_executable "$app_dir/Contents/Resources/MACKAN.Service/MACKAN.Service"

    if [[ "$include_icon" == "true" ]]; then
        cp "$ICON_PATH" "$app_dir/Contents/Resources/MACKAN.icns"
    fi

    cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIconFile</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.test</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
}

ICON_APP="$WORK_DIR/Icon.app"
make_app "$ICON_APP" true
"$VERIFY_SCRIPT" \
    --mode single \
    --require-icon \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    "$ICON_APP"

MISSING_ICON_APP="$WORK_DIR/MissingIcon.app"
make_app "$MISSING_ICON_APP" false
ERROR_LOG="$WORK_DIR/missing-icon.err"
if "$VERIFY_SCRIPT" \
    --mode single \
    --require-icon \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    "$MISSING_ICON_APP" \
    2>"$ERROR_LOG"; then
    echo "Expected icon verification to fail without MACKAN.icns." >&2
    exit 1
fi
grep -F "App icon missing" "$ERROR_LOG" >/dev/null

EXTENSION_ICON_APP="$WORK_DIR/ExtensionIcon.app"
make_app "$EXTENSION_ICON_APP" true
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile MACKAN.icns' "$EXTENSION_ICON_APP/Contents/Info.plist"
EXTENSION_ERROR_LOG="$WORK_DIR/extension-icon.err"
if "$VERIFY_SCRIPT" \
    --mode single \
    --require-icon \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    "$EXTENSION_ICON_APP" \
    2>"$EXTENSION_ERROR_LOG"; then
    echo "Expected icon verification to fail when CFBundleIconFile includes .icns." >&2
    exit 1
fi
grep -F "CFBundleIconFile should omit the .icns extension" "$EXTENSION_ERROR_LOG" >/dev/null

BUILD_APP_SOURCE="$(cat "$BUILD_APP_SCRIPT")"
case "$BUILD_APP_SOURCE" in
    *'STAGING_APP_DIR="$BUILD_ROOT/.${APP_NAME}.staging.app"'* ) ;;
    *)
        echo "build-dev-app.sh must build into a hidden staging .app so Finder never sees an incomplete app icon bundle." >&2
        exit 1
        ;;
esac
case "$BUILD_APP_SOURCE" in
    *'mv "$STAGING_APP_DIR" "$FINAL_APP_DIR"'* ) ;;
    *)
        echo "build-dev-app.sh must atomically publish the completed app bundle with mv." >&2
        exit 1
        ;;
esac

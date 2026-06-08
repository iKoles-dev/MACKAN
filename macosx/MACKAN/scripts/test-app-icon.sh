#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_ICON_SCRIPT="$SCRIPT_DIR/generate-app-icon.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-app-bundle.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-icon-test.XXXXXX")"
ICON_PATH="$WORK_DIR/MACKAN.icns"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

"$GENERATE_ICON_SCRIPT" --output "$ICON_PATH"
test -s "$ICON_PATH"
file "$ICON_PATH" | grep -F "Mac OS X icon" >/dev/null

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

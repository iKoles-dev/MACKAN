#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-app-bundle.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-verify-app-test.XXXXXX")"
APP_VERSION="${APP_VERSION:-1.2.3}"
VERSION_MISMATCH_VERSION="${APP_VERSION}-mismatch"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

write_info_plist() {
    local app_dir="$1"
    local short_version="$2"
    local bundle_version="$3"

    cat > "$app_dir/Contents/Info.plist" <<PLIST
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
    <string>$short_version</string>
    <key>CFBundleVersion</key>
    <string>$bundle_version</string>
</dict>
</plist>
PLIST
}

write_executable() {
    local path="$1"

    printf '#!/usr/bin/env bash\nexit 0\n' > "$path"
    chmod +x "$path"
}

make_app() {
    local app_dir="$1"
    local short_version="$2"
    local bundle_version="$3"

    mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/MACKAN.Service"
    write_info_plist "$app_dir" "$short_version" "$bundle_version"
    write_executable "$app_dir/Contents/MacOS/MACKAN"
}

SINGLE_APP="$WORK_DIR/Single.app"
make_app "$SINGLE_APP" "$APP_VERSION" "$APP_VERSION"
write_executable "$SINGLE_APP/Contents/Resources/MACKAN.Service/MACKAN.Service"

"$VERIFY_SCRIPT" \
    --mode single \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    --require-version "$APP_VERSION" \
    "$SINGLE_APP"

UNIVERSAL_APP="$WORK_DIR/Universal.app"
make_app "$UNIVERSAL_APP" "$APP_VERSION" "$APP_VERSION"
mkdir -p \
    "$UNIVERSAL_APP/Contents/Resources/MACKAN.Service/osx-arm64" \
    "$UNIVERSAL_APP/Contents/Resources/MACKAN.Service/osx-x64"
write_executable "$UNIVERSAL_APP/Contents/Resources/MACKAN.Service/osx-arm64/MACKAN.Service"
write_executable "$UNIVERSAL_APP/Contents/Resources/MACKAN.Service/osx-x64/MACKAN.Service"

"$VERIFY_SCRIPT" \
    --mode universal \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    --require-version "$APP_VERSION" \
    "$UNIVERSAL_APP"

MISSING_X64_APP="$WORK_DIR/MissingX64.app"
make_app "$MISSING_X64_APP" "$APP_VERSION" "$APP_VERSION"
mkdir -p "$MISSING_X64_APP/Contents/Resources/MACKAN.Service/osx-arm64"
write_executable "$MISSING_X64_APP/Contents/Resources/MACKAN.Service/osx-arm64/MACKAN.Service"

if "$VERIFY_SCRIPT" \
    --mode universal \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    --require-version "$APP_VERSION" \
    "$MISSING_X64_APP"; then
    echo "Expected universal verification to fail without osx-x64 sidecar." >&2
    exit 1
fi

VERSION_MISMATCH_APP="$WORK_DIR/VersionMismatch.app"
make_app "$VERSION_MISMATCH_APP" "$VERSION_MISMATCH_VERSION" "$VERSION_MISMATCH_VERSION"
mkdir -p "$VERSION_MISMATCH_APP/Contents/Resources/MACKAN.Service"
write_executable "$VERSION_MISMATCH_APP/Contents/Resources/MACKAN.Service/MACKAN.Service"

if "$VERIFY_SCRIPT" \
    --mode single \
    --skip-codesign \
    --skip-lipo \
    --skip-sidecar-run \
    --require-version "$APP_VERSION" \
    "$VERSION_MISMATCH_APP"; then
    echo "Expected version check to fail when bundle versions differ." >&2
    exit 1
fi

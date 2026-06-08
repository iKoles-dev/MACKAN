#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
VERIFY_APP_SCRIPT="$SCRIPT_DIR/verify-app-bundle.sh"
GENERATE_ICON_SCRIPT="$SCRIPT_DIR/generate-app-icon.sh"

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="${APP_NAME:-MACKAN}"
APP_VERSION="${APP_VERSION:-0.1.0}"
SELF_CONTAINED="${MACKAN_SELF_CONTAINED:-true}"
DEFAULT_BUILD_ROOT="${HOME}/Library/Caches/MACKAN/build"
BUILD_ROOT="${BUILD_ROOT:-$DEFAULT_BUILD_ROOT}"
APP_DIR="$BUILD_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SERVICE_DIR="$RESOURCES_DIR/MACKAN.Service"
SERVICE_PUBLISH_DIR="$BUILD_ROOT/service-publish"
UNIVERSAL="${MACKAN_UNIVERSAL:-false}"
VERIFY_APP_BUNDLE="${MACKAN_VERIFY_APP_BUNDLE:-true}"
GENERATE_APP_ICON="${MACKAN_GENERATE_APP_ICON:-true}"

usage() {
    cat <<USAGE
Usage: build-dev-app.sh [--universal]

Builds a local MACKAN.app with a bundled MACKAN.Service sidecar.

Environment:
  APP_NAME                  App bundle name. Default: MACKAN
  APP_VERSION               Bundle version. Default: 0.1.0
  BUILD_ROOT                Build output root. Default: ~/Library/Caches/MACKAN/build
  CONFIGURATION             Swift build configuration. Default: release
  MACKAN_RUNTIME_IDENTIFIER Runtime identifier for single-arch sidecar.
  MACKAN_SELF_CONTAINED     true/false dotnet publish mode. Default: true
  MACKAN_UNIVERSAL          true/false; build universal app bundle. Default: false
  MACKAN_VERIFY_APP_BUNDLE  true/false; verify app layout and sidecar launch. Default: true
  MACKAN_GENERATE_APP_ICON  true/false; generate and bundle MACKAN.icns. Default: true
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

host_runtime_identifier() {
    case "$(uname -m)" in
        arm64) printf '%s\n' "osx-arm64" ;;
        x86_64) printf '%s\n' "osx-x64" ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

single_runtime_identifier() {
    case "${MACKAN_RUNTIME_IDENTIFIER:-}" in
        "")
            host_runtime_identifier
            ;;
        *)
            printf '%s\n' "$MACKAN_RUNTIME_IDENTIFIER"
            ;;
    esac
}

swift_build_single() {
    swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" >&2

    local swift_bin_dir
    swift_bin_dir="$(swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" \
        --show-bin-path)"
    cp "$swift_bin_dir/$APP_NAME" "$MACOS_DIR/$APP_NAME"
}

swift_build_universal() {
    local arm64_triple="arm64-apple-macosx13.0"
    local x64_triple="x86_64-apple-macosx13.0"

    swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" \
        --triple "$arm64_triple" >&2
    swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" \
        --triple "$x64_triple" >&2

    local arm64_bin_dir x64_bin_dir
    arm64_bin_dir="$(swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" \
        --triple "$arm64_triple" \
        --show-bin-path)"
    x64_bin_dir="$(swift build \
        --package-path "$PACKAGE_DIR" \
        -c "$CONFIGURATION" \
        --triple "$x64_triple" \
        --show-bin-path)"

    lipo -create \
        "$arm64_bin_dir/$APP_NAME" \
        "$x64_bin_dir/$APP_NAME" \
        -output "$MACOS_DIR/$APP_NAME"
}

publish_service() {
    local runtime_identifier="$1"
    local output_dir="$2"

    dotnet publish "$REPO_ROOT/MACKAN.Service/MACKAN.Service.csproj" \
        -c Release \
        -r "$runtime_identifier" \
        --self-contained "$SELF_CONTAINED" \
        -o "$output_dir" >&2
}

copy_service_publish() {
    local publish_dir="$1"
    local destination_dir="$2"

    mkdir -p "$destination_dir"
    cp -R "$publish_dir"/. "$destination_dir/"
    if [[ -f "$destination_dir/MACKAN.Service" ]]; then
        chmod +x "$destination_dir/MACKAN.Service"
    fi
}

case "$UNIVERSAL" in
    true|false)
        ;;
    *)
        echo "MACKAN_UNIVERSAL must be true or false." >&2
        exit 2
        ;;
esac

case "$VERIFY_APP_BUNDLE" in
    true|false)
        ;;
    *)
        echo "MACKAN_VERIFY_APP_BUNDLE must be true or false." >&2
        exit 2
        ;;
esac

case "$GENERATE_APP_ICON" in
    true|false)
        ;;
    *)
        echo "MACKAN_GENERATE_APP_ICON must be true or false." >&2
        exit 2
        ;;
esac

if [[ "$UNIVERSAL" == "true" && -n "${MACKAN_RUNTIME_IDENTIFIER:-}" ]]; then
    echo "MACKAN_RUNTIME_IDENTIFIER is only supported for single-arch builds." >&2
    exit 2
fi

case "$UNIVERSAL" in
    true)
        RUNTIME_IDENTIFIERS=("osx-arm64" "osx-x64")
        ;;
    false)
        RUNTIME_IDENTIFIERS=("$(single_runtime_identifier)")
        ;;
esac

case "${RUNTIME_IDENTIFIERS[0]}" in
    osx-arm64|osx-x64)
        ;;
    *)
        echo "Unsupported runtime identifier: ${RUNTIME_IDENTIFIERS[0]}" >&2
        exit 2
        ;;
esac

if [[ "${#RUNTIME_IDENTIFIERS[@]}" -gt 1 && "${RUNTIME_IDENTIFIERS[1]}" != "osx-x64" ]]; then
    echo "Unsupported runtime identifier: ${RUNTIME_IDENTIFIERS[1]}" >&2
    exit 2
fi

rm -rf "$APP_DIR" "$SERVICE_PUBLISH_DIR"
mkdir -p "$MACOS_DIR" "$SERVICE_DIR"

if [[ "$UNIVERSAL" == "true" ]]; then
    swift_build_universal
    for runtime_identifier in "${RUNTIME_IDENTIFIERS[@]}"; do
        publish_dir="$SERVICE_PUBLISH_DIR/$runtime_identifier"
        publish_service "$runtime_identifier" "$publish_dir"
        copy_service_publish "$publish_dir" "$SERVICE_DIR/$runtime_identifier"
    done
else
    swift_build_single
    publish_service "${RUNTIME_IDENTIFIERS[0]}" "$SERVICE_PUBLISH_DIR"
    copy_service_publish "$SERVICE_PUBLISH_DIR" "$SERVICE_DIR"
fi

if [[ "$GENERATE_APP_ICON" == "true" ]]; then
    "$GENERATE_ICON_SCRIPT" --output "$RESOURCES_DIR/MACKAN.icns"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
    </array>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null
find "$APP_DIR" \( -name '.DS_Store' -o -name '._*' \) -delete
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR" >/dev/null

if [[ "$VERIFY_APP_BUNDLE" == "true" ]]; then
    if [[ "$UNIVERSAL" == "true" ]]; then
        "$VERIFY_APP_SCRIPT" --mode universal --require-icon "$APP_DIR" >/dev/null
    else
        "$VERIFY_APP_SCRIPT" --mode single --require-icon "$APP_DIR" >/dev/null
    fi
fi

echo "$APP_DIR"

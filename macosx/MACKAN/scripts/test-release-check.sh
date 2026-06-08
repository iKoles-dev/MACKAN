#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_CHECK_SCRIPT="$SCRIPT_DIR/release-check.sh"

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected release-check dry-run output to contain: $needle" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected release-check dry-run output to not contain: $needle" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

APP_NAME="MACKAN"
BASE_APP_VERSION="2.3.4"
DMG_SMOKE_TOKEN="test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $BASE_APP_VERSION"
DMG_CLEAN_SMOKE_TOKEN="test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $BASE_APP_VERSION"
ACCESSIBILITY_SMOKE_TOKEN="test-accessibility-smoke.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-check-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

APP_DIR="$WORK_DIR/MACKAN.app"
mkdir -p "$APP_DIR/Contents/MacOS"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.test</string>
    <key>CFBundleShortVersionString</key>
    <string>${BASE_APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BASE_APP_VERSION}</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= "$RELEASE_CHECK_SCRIPT" --dry-run)"

assert_contains "$OUTPUT" "swift test --package-path"
assert_contains "$OUTPUT" "run_dotnet_with_retry list Tests/Tests.csproj package --vulnerable --include-transitive"
assert_contains "$OUTPUT" "run_dotnet_with_retry list MACKAN.Service/MACKAN.Service.csproj package --vulnerable --include-transitive"
assert_contains "$OUTPUT" "run_dotnet_with_retry list Core/CKAN-core.csproj package --vulnerable --include-transitive -f net10.0"
assert_contains "$OUTPUT" "run_dotnet_with_retry test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN"
assert_contains "$OUTPUT" "dotnet list Tests/Tests.csproj package --vulnerable --include-transitive"
assert_contains "$OUTPUT" "dotnet list MACKAN.Service/MACKAN.Service.csproj package --vulnerable --include-transitive"
assert_contains "$OUTPUT" "dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN"
assert_contains "$OUTPUT" "test-app-icon.sh"
assert_contains "$OUTPUT" "test-verify-app-bundle.sh"
assert_contains "$OUTPUT" "test-package-dmg.sh"
assert_contains "$OUTPUT" "test-release-dmg.sh"
assert_contains "$OUTPUT" "test-generate-release-provenance.sh"
assert_contains "$OUTPUT" "test-verify-release-artifact.sh"
assert_contains "$OUTPUT" "$ACCESSIBILITY_SMOKE_TOKEN"
assert_contains "$OUTPUT" "test-verify-app-launch.sh"
assert_contains "$OUTPUT" "test-run-ui-ux-audit.sh"
assert_contains "$OUTPUT" "test-verify-ui-ux-audit-evidence.sh"
assert_contains "$OUTPUT" "package-dmg.sh --universal"
assert_contains "$OUTPUT" "verify-app-bundle.sh --mode universal --require-icon"
assert_contains "$OUTPUT" "--require-version $BASE_APP_VERSION"
assert_contains "$OUTPUT" "generate-release-provenance.sh --app"
assert_contains "$OUTPUT" "verify-release-artifact.sh --app"
assert_contains "$OUTPUT" "verify-app-launch.sh --timeout 25"
assert_contains "$OUTPUT" "$DMG_SMOKE_TOKEN"
assert_not_contains "$OUTPUT" "$DMG_CLEAN_SMOKE_TOKEN"

SKIP_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= "$RELEASE_CHECK_SCRIPT" --dry-run --skip-package --skip-launch)"
assert_not_contains "$SKIP_OUTPUT" "package-dmg.sh --universal"
assert_not_contains "$SKIP_OUTPUT" "hdiutil verify"
assert_not_contains "$SKIP_OUTPUT" "generate-release-provenance.sh --app"
assert_not_contains "$SKIP_OUTPUT" "verify-release-artifact.sh --app"
assert_not_contains "$SKIP_OUTPUT" "$DMG_SMOKE_TOKEN"
assert_not_contains "$SKIP_OUTPUT" "verify-app-launch.sh --timeout 25"

SKIP_LAUNCH_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= "$RELEASE_CHECK_SCRIPT" --dry-run --skip-launch)"
assert_contains "$SKIP_LAUNCH_OUTPUT" "package-dmg.sh --universal"
assert_contains "$SKIP_LAUNCH_OUTPUT" "verify-app-bundle.sh --mode universal --require-icon"
assert_contains "$SKIP_LAUNCH_OUTPUT" "generate-release-provenance.sh --app"
assert_contains "$SKIP_LAUNCH_OUTPUT" "verify-release-artifact.sh --app"
assert_not_contains "$SKIP_LAUNCH_OUTPUT" "verify-app-launch.sh --timeout 25"
assert_not_contains "$SKIP_LAUNCH_OUTPUT" "$DMG_SMOKE_TOKEN"
assert_not_contains "$SKIP_LAUNCH_OUTPUT" "$DMG_CLEAN_SMOKE_TOKEN"

RELEASE_READINESS_STRICT_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS=true "$RELEASE_CHECK_SCRIPT" --dry-run --skip-launch --skip-package)"
assert_contains "$RELEASE_READINESS_STRICT_OUTPUT" "release-readiness.sh --strict"

RELEASE_READINESS_CREDENTIAL_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS=true MACKAN_RELEASE_CHECK_REQUIRE_RELEASE_CREDENTIALS=true "$RELEASE_CHECK_SCRIPT" --dry-run --skip-launch --skip-package)"
assert_contains "$RELEASE_READINESS_CREDENTIAL_OUTPUT" "release-readiness.sh --strict --require-release-credentials"

RELEASE_CREDENTIALS_IMPLY_STRICT_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= MACKAN_RELEASE_CHECK_REQUIRE_RELEASE_CREDENTIALS=true "$RELEASE_CHECK_SCRIPT" --dry-run --skip-launch --skip-package)"
assert_contains "$RELEASE_CREDENTIALS_IMPLY_STRICT_OUTPUT" "release-readiness.sh --strict --require-release-credentials"

CLEAN_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= MACKAN_RELEASE_CHECK_CLEAN_SMOKE=true "$RELEASE_CHECK_SCRIPT" --dry-run)"
assert_contains "$CLEAN_OUTPUT" "verify-app-launch.sh --timeout 25"
assert_contains "$CLEAN_OUTPUT" "$DMG_SMOKE_TOKEN"
assert_contains "$CLEAN_OUTPUT" "$DMG_CLEAN_SMOKE_TOKEN"

CLEAN_SKIP_PACKAGE_OUTPUT="$(APP_PATH="$APP_DIR" APP_VERSION= MACKAN_RELEASE_CHECK_CLEAN_SMOKE=true "$RELEASE_CHECK_SCRIPT" --dry-run --skip-package)"
assert_contains "$CLEAN_SKIP_PACKAGE_OUTPUT" "verify-app-launch.sh --timeout 25"
assert_not_contains "$CLEAN_SKIP_PACKAGE_OUTPUT" "$DMG_SMOKE_TOKEN"
assert_not_contains "$CLEAN_SKIP_PACKAGE_OUTPUT" "$DMG_CLEAN_SMOKE_TOKEN"

FAKE_BIN="$WORK_DIR/fake-bin"
FAKE_STATE="$WORK_DIR/fake-dotnet-count"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/dotnet" <<'SCRIPT'
#!/usr/bin/env bash
count_file="${MACKAN_FAKE_DOTNET_COUNT_FILE:?}"
count=0
if [[ -f "$count_file" ]]; then
    count="$(cat "$count_file")"
fi
count=$((count + 1))
printf '%s' "$count" > "$count_file"
if [[ "$count" -eq 1 ]]; then
    exit 139
fi
exit 0
SCRIPT
chmod +x "$FAKE_BIN/dotnet"

RETRY_OUTPUT="$(PATH="$FAKE_BIN:$PATH" MACKAN_FAKE_DOTNET_COUNT_FILE="$FAKE_STATE" MACKAN_RELEASE_CHECK_TEST_DOTNET_RETRY=true "$RELEASE_CHECK_SCRIPT" 2>&1)"
assert_contains "$RETRY_OUTPUT" "dotnet exited with 139 (SIGSEGV); retrying once"
if [[ "$(cat "$FAKE_STATE")" != "2" ]]; then
    echo "Expected dotnet retry self-test to run fake dotnet exactly twice." >&2
    echo "$RETRY_OUTPUT" >&2
    exit 1
fi

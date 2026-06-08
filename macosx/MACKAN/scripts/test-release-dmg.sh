#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_SCRIPT="$SCRIPT_DIR/release-dmg.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-test.XXXXXX")"
APP_DIR="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN.dmg"
APP_NAME="MACKAN"
APP_VERSION="${APP_VERSION:-}"
BASE_VERSION="2.3.4"
IDENTITY="Developer ID Application: Example Team (ABCDE12345)"
PROFILE="mackan-notary"
APP_NAME_TO_MATCH="MACKAN"
KEYCHAIN_PATH="$WORK_DIR/mackan-signing.keychain-db"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS"
printf '#!/usr/bin/env bash\nexit 0\n' > "$APP_DIR/Contents/MacOS/MACKAN"
chmod +x "$APP_DIR/Contents/MacOS/MACKAN"
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
    <string>$BASE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BASE_VERSION</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

APP_VERSION="${APP_VERSION:-$BASE_VERSION}"
touch "$DMG_PATH"
touch "$KEYCHAIN_PATH"

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected dry-run output to contain: $needle" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected dry-run output to not contain: $needle" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

INVALID_VERSION_LOG="$WORK_DIR/invalid-version.err"
if APP_VERSION="bad version" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    2>"$INVALID_VERSION_LOG"; then
    echo "Expected release script to reject invalid public release APP_VERSION." >&2
    exit 1
fi
grep -F "APP_VERSION must be a non-empty SemVer-like version" "$INVALID_VERSION_LOG" >/dev/null

INVALID_NOTARY_TIMEOUT_LOG="$WORK_DIR/invalid-notary-timeout.err"
if APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout "bad timeout" \
    2>"$INVALID_NOTARY_TIMEOUT_LOG"; then
    echo "Expected release script to reject invalid notary timeout values." >&2
    exit 1
fi
grep -F "MACKAN_NOTARY_TIMEOUT must be a notarytool duration" "$INVALID_NOTARY_TIMEOUT_LOG" >/dev/null

OUTPUT="$(APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m)"

assert_contains "$OUTPUT" "codesign --force --deep --options runtime --timestamp --sign '$IDENTITY' '$APP_DIR'"
assert_contains "$OUTPUT" "verify-app-bundle.sh --mode universal"
assert_contains "$OUTPUT" "--require-icon"
assert_contains "$OUTPUT" "--require-version $APP_VERSION"
assert_contains "$OUTPUT" "package-dmg.sh --app '$APP_DIR' --output '$DMG_PATH' --no-build --universal"
assert_contains "$OUTPUT" "codesign --force --timestamp --sign '$IDENTITY' '$DMG_PATH'"
assert_contains "$OUTPUT" "xcrun notarytool submit '$DMG_PATH' --keychain-profile '$PROFILE' --wait --timeout 15m"
assert_contains "$OUTPUT" "--output-format json"
assert_contains "$OUTPUT" "xcrun stapler staple '$DMG_PATH'"
assert_contains "$OUTPUT" "xcrun stapler validate '$DMG_PATH'"
assert_contains "$OUTPUT" "test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $APP_VERSION"
assert_contains "$OUTPUT" "test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME_TO_MATCH --require-version $APP_VERSION"
assert_contains "$OUTPUT" "generate-release-provenance.sh --app '$APP_DIR' --dmg '$DMG_PATH'"
assert_contains "$OUTPUT" "verify-release-artifact.sh --app '$APP_DIR' --dmg '$DMG_PATH' --require-version $APP_VERSION --require-public-release"
assert_contains "$OUTPUT" "shasum -a 256 '$DMG_PATH' '$DMG_PATH.provenance.json' '$DMG_PATH.notary.json'"
assert_contains "$OUTPUT" "generate-release-summary.sh --output '$DMG_PATH.release-summary.json' --version $APP_VERSION --app '$APP_DIR' --dmg '$DMG_PATH' --provenance '$DMG_PATH.provenance.json' --notary-json '$DMG_PATH.notary.json' --checksums '$DMG_PATH.sha256'"
assert_contains "$OUTPUT" "verify-public-release-handoff.sh --app '$APP_DIR' --dmg '$DMG_PATH' --provenance '$DMG_PATH.provenance.json' --notary-json '$DMG_PATH.notary.json' --checksums '$DMG_PATH.sha256' --summary '$DMG_PATH.release-summary.json' --require-version $APP_VERSION"

KEYCHAIN_OUTPUT="$(APP_VERSION="$APP_VERSION" MACKAN_SIGNING_KEYCHAIN_PATH="$KEYCHAIN_PATH" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m)"
assert_contains "$KEYCHAIN_OUTPUT" "xcrun notarytool submit '$DMG_PATH' --keychain-profile '$PROFILE' --keychain '$KEYCHAIN_PATH' --wait --timeout 15m --output-format json"

ERROR_LOG="$WORK_DIR/missing-identity.err"
if APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --keychain-profile "$PROFILE" \
    2>"$ERROR_LOG"; then
    echo "Expected release script to require a Developer ID Application identity." >&2
    exit 1
fi
grep -F "Developer ID Application identity is required" "$ERROR_LOG" >/dev/null

MISSING_IDENTITY_LOG="$WORK_DIR/missing-codesigning-identity.err"
if APP_VERSION="$APP_VERSION" \
    MACKAN_RELEASE_SECURITY_IDENTITIES_OUTPUT='  1) 0123456789ABCDEF "Developer ID Application: Other Team (ZZZZZ99999)"' \
    MACKAN_RELEASE_NOTARY_PROFILE_VALIDATED=true \
    "$RELEASE_SCRIPT" \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    2>"$MISSING_IDENTITY_LOG"; then
    echo "Expected release script to fail fast when the Developer ID Application identity is not discoverable." >&2
    exit 1
fi
grep -F "Developer ID Application identity not found" "$MISSING_IDENTITY_LOG" >/dev/null

INVALID_NOTARY_LOG="$WORK_DIR/invalid-notary-profile.err"
if APP_VERSION="$APP_VERSION" \
    MACKAN_RELEASE_SECURITY_IDENTITIES_OUTPUT="  1) ABCDEF0123456789 \"$IDENTITY\"" \
    MACKAN_RELEASE_NOTARY_PROFILE_VALIDATED=false \
    "$RELEASE_SCRIPT" \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    2>"$INVALID_NOTARY_LOG"; then
    echo "Expected release script to fail fast when the notary profile does not validate." >&2
    exit 1
fi
grep -F "notarytool keychain profile did not validate" "$INVALID_NOTARY_LOG" >/dev/null

NO_NOTARIZE_PUBLIC_LOG="$WORK_DIR/no-notarize-public.err"
if APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --no-notarize \
    2>"$NO_NOTARIZE_PUBLIC_LOG"; then
    echo "Expected release script to reject public release handoff when notarization is disabled." >&2
    exit 1
fi
grep -F "Public release provenance requires notarization and stapling" "$NO_NOTARIZE_PUBLIC_LOG" >/dev/null

NO_STAPLE_PUBLIC_LOG="$WORK_DIR/no-staple-public.err"
if APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --no-staple \
    2>"$NO_STAPLE_PUBLIC_LOG"; then
    echo "Expected release script to reject public release handoff when stapling is disabled." >&2
    exit 1
fi
grep -F "Public release provenance requires notarization and stapling" "$NO_STAPLE_PUBLIC_LOG" >/dev/null

NO_CLEAN_SMOKE_PUBLIC_LOG="$WORK_DIR/no-clean-smoke-public.err"
if APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --no-clean-smoke \
    2>"$NO_CLEAN_SMOKE_PUBLIC_LOG"; then
    echo "Expected release script to reject public release handoff when clean-install smoke is disabled." >&2
    exit 1
fi
grep -F "Public release provenance requires DMG launch smoke and clean-install smoke" "$NO_CLEAN_SMOKE_PUBLIC_LOG" >/dev/null

LOCAL_NO_NOTARIZE_OUTPUT="$(APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --no-notarize \
    --no-provenance)"
assert_contains "$LOCAL_NO_NOTARIZE_OUTPUT" "codesign --force --deep --options runtime --timestamp --sign '$IDENTITY' '$APP_DIR'"
assert_not_contains "$LOCAL_NO_NOTARIZE_OUTPUT" "notarytool submit"
assert_not_contains "$LOCAL_NO_NOTARIZE_OUTPUT" "stapler staple"
assert_not_contains "$LOCAL_NO_NOTARIZE_OUTPUT" "generate-release-provenance.sh"

FAKE_BIN="$WORK_DIR/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/security" <<'SH'
#!/usr/bin/env bash
expected_keychain="${MACKAN_TEST_EXPECTED_KEYCHAIN:?}"
if [[ "$1" == "find-identity" ]]; then
    [[ "$#" -eq 5 ]] || exit 3
    [[ "$2" == "-v" && "$3" == "-p" && "$4" == "codesigning" && "$5" == "$expected_keychain" ]] || exit 4
    printf '  1) ABCDEF0123456789 "%s"\n' "${MACKAN_TEST_EXPECTED_IDENTITY:?}"
    exit 0
fi
exit 2
SH
cat > "$FAKE_BIN/xcrun" <<'SH'
#!/usr/bin/env bash
expected_keychain="${MACKAN_TEST_EXPECTED_KEYCHAIN:?}"
[[ "$1" == "notarytool" && "$2" == "history" ]] || exit 2
shift 2
profile_seen=false
keychain_seen=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keychain-profile)
            [[ "$2" == "${MACKAN_TEST_EXPECTED_PROFILE:?}" ]] || exit 3
            profile_seen=true
            shift 2
            ;;
        --keychain)
            [[ "$2" == "$expected_keychain" ]] || exit 4
            keychain_seen=true
            shift 2
            ;;
        --output-format)
            [[ "$2" == "json" ]] || exit 5
            shift 2
            ;;
        --no-progress)
            shift
            ;;
        *)
            exit 6
            ;;
    esac
done
[[ "$profile_seen" == true && "$keychain_seen" == true ]] || exit 7
printf '{"history":[]}\n'
SH
chmod +x "$FAKE_BIN/security" "$FAKE_BIN/xcrun"

KEYCHAIN_VALIDATION_LOG="$WORK_DIR/keychain-validation.err"
if APP_VERSION="$APP_VERSION" PATH="$FAKE_BIN:$PATH" \
    MACKAN_RELEASE_DMG_SMOKE=false \
    MACKAN_RELEASE_PROVENANCE=false \
    MACKAN_SIGNING_KEYCHAIN_PATH="$KEYCHAIN_PATH" \
    MACKAN_TEST_EXPECTED_KEYCHAIN="$KEYCHAIN_PATH" \
    MACKAN_TEST_EXPECTED_IDENTITY="$IDENTITY" \
    MACKAN_TEST_EXPECTED_PROFILE="$PROFILE" \
    "$RELEASE_SCRIPT" \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    >"$WORK_DIR/keychain-validation.out" 2>"$KEYCHAIN_VALIDATION_LOG"; then
    echo "Expected release script to stop before packaging without a real Developer ID identity." >&2
    exit 1
fi
grep -F "no identity found" "$KEYCHAIN_VALIDATION_LOG" >/dev/null
if grep -F "notarytool keychain profile did not validate" "$KEYCHAIN_VALIDATION_LOG" >/dev/null; then
    echo "Expected explicit-keychain notary profile validation to pass before codesign failure." >&2
    cat "$KEYCHAIN_VALIDATION_LOG" >&2
    exit 1
fi

NO_SMOKE_OUTPUT="$(APP_VERSION="$APP_VERSION" MACKAN_RELEASE_DMG_SMOKE=true "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m \
    --no-smoke \
    --no-provenance)"

assert_contains "$NO_SMOKE_OUTPUT" "codesign --force --deep --options runtime --timestamp --sign '$IDENTITY' '$APP_DIR'"
assert_contains "$NO_SMOKE_OUTPUT" "verify-app-bundle.sh --mode universal"
assert_contains "$NO_SMOKE_OUTPUT" "--require-icon"
assert_contains "$NO_SMOKE_OUTPUT" "--require-version $APP_VERSION"
assert_contains "$NO_SMOKE_OUTPUT" "package-dmg.sh --app '$APP_DIR' --output '$DMG_PATH' --no-build --universal"
assert_contains "$NO_SMOKE_OUTPUT" "codesign --force --timestamp --sign '$IDENTITY' '$DMG_PATH'"
assert_contains "$NO_SMOKE_OUTPUT" "xcrun notarytool submit '$DMG_PATH' --keychain-profile '$PROFILE' --wait --timeout 15m"
assert_contains "$NO_SMOKE_OUTPUT" "--output-format json"
assert_contains "$NO_SMOKE_OUTPUT" "xcrun stapler staple '$DMG_PATH'"
assert_contains "$NO_SMOKE_OUTPUT" "xcrun stapler validate '$DMG_PATH'"
assert_not_contains "$NO_SMOKE_OUTPUT" "test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $APP_VERSION"
assert_not_contains "$NO_SMOKE_OUTPUT" "test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME_TO_MATCH --require-version $APP_VERSION"
assert_not_contains "$NO_SMOKE_OUTPUT" "generate-release-provenance.sh"
assert_not_contains "$NO_SMOKE_OUTPUT" "verify-release-artifact.sh"

NO_SMOKE_CLEAN_OUTPUT="$(APP_VERSION="$APP_VERSION" MACKAN_RELEASE_DMG_CLEAN_SMOKE=true "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m \
    --no-smoke \
    --no-provenance)"

assert_not_contains "$NO_SMOKE_CLEAN_OUTPUT" "test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $APP_VERSION"
assert_not_contains "$NO_SMOKE_CLEAN_OUTPUT" "test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME_TO_MATCH --require-version $APP_VERSION"
assert_not_contains "$NO_SMOKE_CLEAN_OUTPUT" "generate-release-provenance.sh"
assert_not_contains "$NO_SMOKE_CLEAN_OUTPUT" "verify-release-artifact.sh"

NO_CLEAN_SMOKE_OVERRIDE_OUTPUT="$(APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m \
    --no-clean-smoke \
    --no-provenance)"

assert_contains "$NO_CLEAN_SMOKE_OVERRIDE_OUTPUT" "test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $APP_VERSION"
assert_not_contains "$NO_CLEAN_SMOKE_OVERRIDE_OUTPUT" "test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME_TO_MATCH --require-version $APP_VERSION"

WITH_CLEAN_SMOKE_OUTPUT="$(APP_VERSION="$APP_VERSION" MACKAN_RELEASE_DMG_CLEAN_SMOKE=true "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m)"

assert_contains "$WITH_CLEAN_SMOKE_OUTPUT" "test-dmg-launch-smoke.sh --timeout 25 --app-name $APP_NAME --require-version $APP_VERSION"
assert_contains "$WITH_CLEAN_SMOKE_OUTPUT" "test-clean-install-smoke.sh --timeout 25 --app-name $APP_NAME_TO_MATCH --require-version $APP_VERSION"
assert_contains "$WITH_CLEAN_SMOKE_OUTPUT" "generate-release-provenance.sh --app '$APP_DIR' --dmg '$DMG_PATH'"
assert_contains "$WITH_CLEAN_SMOKE_OUTPUT" "verify-release-artifact.sh --app '$APP_DIR' --dmg '$DMG_PATH' --require-version $APP_VERSION --require-public-release"

INFERRED_OUTPUT="$(APP_VERSION= \
    "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --notary-timeout 15m)"
assert_contains "$INFERRED_OUTPUT" "--require-version $BASE_VERSION"
assert_not_contains "$INFERRED_OUTPUT" "Unable to parse version from app bundle Info.plist"

PROVENANCE_PATH="$WORK_DIR/custom-provenance.json"
PROVENANCE_OUTPUT="$(APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --provenance "$PROVENANCE_PATH")"
assert_contains "$PROVENANCE_OUTPUT" "generate-release-provenance.sh --app '$APP_DIR' --dmg '$DMG_PATH' --output '$PROVENANCE_PATH'"
assert_contains "$PROVENANCE_OUTPUT" "verify-release-artifact.sh --app '$APP_DIR' --dmg '$DMG_PATH' --require-version $APP_VERSION --require-public-release --provenance '$PROVENANCE_PATH'"
assert_contains "$PROVENANCE_OUTPUT" "shasum -a 256 '$DMG_PATH' '$PROVENANCE_PATH' '$DMG_PATH.notary.json'"
assert_contains "$PROVENANCE_OUTPUT" "verify-public-release-handoff.sh --app '$APP_DIR' --dmg '$DMG_PATH' --provenance '$PROVENANCE_PATH' --notary-json '$DMG_PATH.notary.json' --checksums '$DMG_PATH.sha256' --summary '$DMG_PATH.release-summary.json' --require-version $APP_VERSION"

NO_PROVENANCE_OUTPUT="$(APP_VERSION="$APP_VERSION" "$RELEASE_SCRIPT" \
    --dry-run \
    --no-build \
    --app "$APP_DIR" \
    --dmg "$DMG_PATH" \
    --identity "$IDENTITY" \
    --keychain-profile "$PROFILE" \
    --no-provenance)"
assert_not_contains "$NO_PROVENANCE_OUTPUT" "generate-release-provenance.sh"
assert_not_contains "$NO_PROVENANCE_OUTPUT" "verify-release-artifact.sh"

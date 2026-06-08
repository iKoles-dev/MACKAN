#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
READINESS_SCRIPT="$SCRIPT_DIR/release-readiness.sh"

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected output to contain: $needle" >&2
        echo "$haystack" >&2
        exit 1
    fi
}

assert_success() {
    local exit_code=$1
    local details="$2"
    if [[ "$exit_code" -ne 0 ]]; then
        echo "$details" >&2
        exit 1
    fi
}

json_value() {
    local key="$1"
    local json="$2"
    printf '%s\n' "$json" | sed -nE "s/.*\"${key}\":([0-9]+).*/\\1/p" | head -n 1
}

json_string_value() {
    local key="$1"
    local json="$2"
    printf '%s\n' "$json" | sed -nE "s/.*\"${key}\":\"([^\"]+)\".*/\\1/p" | head -n 1
}

READINESS_CONTENTS="$(cat "$READINESS_SCRIPT")"
assert_contains "$READINESS_CONTENTS" 'verify-release-log.sh'
assert_contains "$READINESS_CONTENTS" 'test-verify-release-log.sh'
assert_contains "$READINESS_CONTENTS" 'verify-ui-ux-audit-evidence.sh'
assert_contains "$READINESS_CONTENTS" 'test-verify-ui-ux-audit-evidence.sh'

# report-only mode should succeed despite pending matrix blockers.
OUTPUT="$($READINESS_SCRIPT 2>&1)"
assert_success "$?" "release-readiness report mode failed unexpectedly"
assert_contains "$OUTPUT" "MACKAN release readiness check"
assert_contains "$OUTPUT" "Docs: OK"
assert_contains "$OUTPUT" "Scripts: OK"
assert_contains "$OUTPUT" "Mode: report-only"
assert_contains "$OUTPUT" "Parity matrix required rows:"

# JSON mode should emit a machine-readable object.
JSON_OUTPUT="$($READINESS_SCRIPT --json 2>/dev/null)"
assert_contains "$JSON_OUTPUT" '"missingDocs":'
assert_contains "$JSON_OUTPUT" '"requiredParityPending":'
assert_contains "$JSON_OUTPUT" '"requiredParityCompleted":'
assert_contains "$JSON_OUTPUT" '"requiredParityParseFailures":'
assert_contains "$JSON_OUTPUT" '"requiredParityUnknown":'
assert_contains "$JSON_OUTPUT" '"requiredParityRows":'
assert_contains "$JSON_OUTPUT" '"requiredParityParseFailureRows":'
assert_contains "$JSON_OUTPUT" '"releaseCredentialsRequired":'
assert_contains "$JSON_OUTPUT" '"developerIdApplicationConfigured":'
assert_contains "$JSON_OUTPUT" '"developerIdApplicationFound":'
assert_contains "$JSON_OUTPUT" '"notaryKeychainProfileConfigured":'
assert_contains "$JSON_OUTPUT" '"notaryKeychainProfileValidated":'
assert_contains "$JSON_OUTPUT" '"releaseCredentialsReady":'

required_total="$(json_value requiredParityTotal "$JSON_OUTPUT")"
required_pending="$(json_value requiredParityPending "$JSON_OUTPUT")"
required_unknown="$(json_value requiredParityUnknown "$JSON_OUTPUT")"
required_scope_mode="$(json_string_value strictScopeMode "$JSON_OUTPUT")"

if [[ -z "$required_scope_mode" ]]; then
    echo "release-readiness JSON did not include strictScopeMode." >&2
    echo "$JSON_OUTPUT" >&2
    exit 1
fi

if [[ -z "$required_total" || -z "$required_pending" || -z "$required_unknown" ]]; then
    echo "release-readiness JSON did not include required counters." >&2
    echo "$JSON_OUTPUT" >&2
    exit 1
fi

assert_contains "$JSON_OUTPUT" "\"requiredParityTotal\":$required_total"
assert_contains "$JSON_OUTPUT" "\"requiredParityPending\":$required_pending"
assert_contains "$JSON_OUTPUT" "\"requiredParityUnknown\":$required_unknown"

# strict mode should fail while any required rows remain pending.
if (( required_pending > 0 )); then
    if "$READINESS_SCRIPT" --strict >/tmp/mackan-readiness-strict.out 2>&1; then
        echo "Expected strict readiness check to fail while required rows remain pending." >&2
        exit 1
    fi
    STRICT_OUTPUT="$(cat /tmp/mackan-readiness-strict.out)"
    rm -f /tmp/mackan-readiness-strict.out
    assert_contains "$STRICT_OUTPUT" "MACKAN release readiness check"
    assert_contains "$STRICT_OUTPUT" "required rows still pending"
    assert_contains "$STRICT_OUTPUT" "Mode: strict"
else
    STRICT_OUTPUT="$($READINESS_SCRIPT --strict 2>&1)"
    assert_contains "$STRICT_OUTPUT" "MACKAN release readiness check"
    assert_contains "$STRICT_OUTPUT" "Mode: strict"
    assert_contains "$STRICT_OUTPUT" "pending required rows: none"
fi

CREDENTIAL_IDENTITY="Developer ID Application: Example Team (ABCDE12345)"
CREDENTIAL_PROFILE="mackan-notary"
CREDENTIAL_IDENTITIES_OUTPUT="  1) ABCDEF0123456789 \"$CREDENTIAL_IDENTITY\""
CREDENTIAL_JSON_OUTPUT="$(MACKAN_DEVELOPER_ID_APPLICATION="$CREDENTIAL_IDENTITY" \
    MACKAN_NOTARY_KEYCHAIN_PROFILE="$CREDENTIAL_PROFILE" \
    MACKAN_READINESS_SECURITY_IDENTITIES_OUTPUT="$CREDENTIAL_IDENTITIES_OUTPUT" \
    MACKAN_READINESS_NOTARY_PROFILE_VALIDATED=true \
    "$READINESS_SCRIPT" --require-release-credentials --json 2>&1)"
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"releaseCredentialsRequired":true'
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"developerIdApplicationConfigured":true'
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"developerIdApplicationFound":true'
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"notaryKeychainProfileConfigured":true'
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"notaryKeychainProfileValidated":true'
assert_contains "$CREDENTIAL_JSON_OUTPUT" '"releaseCredentialsReady":true'

if MACKAN_DEVELOPER_ID_APPLICATION="$CREDENTIAL_IDENTITY" \
    MACKAN_NOTARY_KEYCHAIN_PROFILE= \
    MACKAN_READINESS_SECURITY_IDENTITIES_OUTPUT="$CREDENTIAL_IDENTITIES_OUTPUT" \
    MACKAN_READINESS_NOTARY_PROFILE_VALIDATED=true \
    "$READINESS_SCRIPT" --require-release-credentials --json >/tmp/mackan-readiness-credentials.out 2>&1; then
    echo "Expected release-readiness to fail when release credentials are required but notary profile is missing." >&2
    exit 1
fi
CREDENTIAL_FAIL_OUTPUT="$(cat /tmp/mackan-readiness-credentials.out)"
rm -f /tmp/mackan-readiness-credentials.out
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"releaseCredentialsRequired":true'
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"developerIdApplicationConfigured":true'
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"developerIdApplicationFound":true'
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"notaryKeychainProfileConfigured":false'
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"notaryKeychainProfileValidated":false'
assert_contains "$CREDENTIAL_FAIL_OUTPUT" '"releaseCredentialsReady":false'

if MACKAN_DEVELOPER_ID_APPLICATION="$CREDENTIAL_IDENTITY" \
    MACKAN_NOTARY_KEYCHAIN_PROFILE="$CREDENTIAL_PROFILE" \
    MACKAN_READINESS_SECURITY_IDENTITIES_OUTPUT="$CREDENTIAL_IDENTITIES_OUTPUT" \
    MACKAN_READINESS_NOTARY_PROFILE_VALIDATED=false \
    "$READINESS_SCRIPT" --require-release-credentials --json >/tmp/mackan-readiness-notary.out 2>&1; then
    echo "Expected release-readiness to fail when release credentials are required but the notary profile does not validate." >&2
    exit 1
fi
NOTARY_FAIL_OUTPUT="$(cat /tmp/mackan-readiness-notary.out)"
rm -f /tmp/mackan-readiness-notary.out
assert_contains "$NOTARY_FAIL_OUTPUT" '"releaseCredentialsRequired":true'
assert_contains "$NOTARY_FAIL_OUTPUT" '"developerIdApplicationConfigured":true'
assert_contains "$NOTARY_FAIL_OUTPUT" '"developerIdApplicationFound":true'
assert_contains "$NOTARY_FAIL_OUTPUT" '"notaryKeychainProfileConfigured":true'
assert_contains "$NOTARY_FAIL_OUTPUT" '"notaryKeychainProfileValidated":false'
assert_contains "$NOTARY_FAIL_OUTPUT" '"releaseCredentialsReady":false'

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-readiness-keychain-test.XXXXXX")"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

FAKE_BIN="$WORK_DIR/bin"
KEYCHAIN_PATH="$WORK_DIR/mackan-signing.keychain-db"
mkdir -p "$FAKE_BIN"
touch "$KEYCHAIN_PATH"

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

KEYCHAIN_JSON_OUTPUT="$(PATH="$FAKE_BIN:$PATH" \
    MACKAN_DEVELOPER_ID_APPLICATION="$CREDENTIAL_IDENTITY" \
    MACKAN_NOTARY_KEYCHAIN_PROFILE="$CREDENTIAL_PROFILE" \
    MACKAN_SIGNING_KEYCHAIN_PATH="$KEYCHAIN_PATH" \
    MACKAN_TEST_EXPECTED_KEYCHAIN="$KEYCHAIN_PATH" \
    MACKAN_TEST_EXPECTED_IDENTITY="$CREDENTIAL_IDENTITY" \
    MACKAN_TEST_EXPECTED_PROFILE="$CREDENTIAL_PROFILE" \
    "$READINESS_SCRIPT" --require-release-credentials --json 2>&1)"
assert_contains "$KEYCHAIN_JSON_OUTPUT" '"developerIdApplicationFound":true'
assert_contains "$KEYCHAIN_JSON_OUTPUT" '"notaryKeychainProfileValidated":true'
assert_contains "$KEYCHAIN_JSON_OUTPUT" '"releaseCredentialsReady":true'

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/build.yml"
SIGNED_RELEASE_WORKFLOW="$REPO_ROOT/.github/workflows/mackan-release.yml"

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Expected build workflow to contain: $needle" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Expected build workflow to not contain: $needle" >&2
        exit 1
    fi
}

[[ -f "$WORKFLOW" ]] || {
    echo "Build workflow not found: $WORKFLOW" >&2
    exit 1
}
[[ -f "$SIGNED_RELEASE_WORKFLOW" ]] || {
    echo "Signed MACKAN release workflow not found: $SIGNED_RELEASE_WORKFLOW" >&2
    exit 1
}

workflow_contents="$(cat "$WORKFLOW")"
signed_release_workflow_contents="$(cat "$SIGNED_RELEASE_WORKFLOW")"
signed_release_public_artifact_step="$(
    awk '
        /name: Verify public release artifact/ { capture = 1 }
        capture { print }
        /name: Verify clean install from signed DMG/ { exit }
    ' "$SIGNED_RELEASE_WORKFLOW"
)"

assert_contains "$workflow_contents" "macosx/MACKAN/scripts/release-check.sh --skip-launch"
assert_contains "$workflow_contents" "MACKAN_PROVENANCE_PATH="
assert_contains "$workflow_contents" "macosx/MACKAN/scripts/verify-release-artifact.sh"
assert_contains "$workflow_contents" '--app "$MACKAN_APP_PATH"'
assert_contains "$workflow_contents" "DMG filename must match MACKAN-<SemVer>-universal.dmg"
assert_contains "$workflow_contents" '"$APP_VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$'
assert_not_contains "$workflow_contents" "APP_VERSION=0.1.0"
assert_contains "$workflow_contents" "Upload MACKAN universal DMG artifact"
assert_contains "$workflow_contents" "Upload MACKAN provenance artifact"
assert_contains "$workflow_contents" "path: ~/Library/Caches/MACKAN/build/MACKAN-*-universal.dmg.provenance.json"

assert_contains "$signed_release_workflow_contents" "workflow_dispatch:"
assert_contains "$signed_release_workflow_contents" "MACKAN_DEVELOPER_ID_APPLICATION"
assert_contains "$signed_release_workflow_contents" "MACKAN_NOTARY_KEYCHAIN_PROFILE"
assert_contains "$signed_release_workflow_contents" 'MACKAN_NOTARIZE: "true"'
assert_contains "$signed_release_workflow_contents" 'MACKAN_STAPLE: "true"'
assert_contains "$signed_release_workflow_contents" 'MACKAN_RELEASE_DMG_SMOKE: "true"'
assert_contains "$signed_release_workflow_contents" "MACKAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64"
assert_contains "$signed_release_workflow_contents" "MACKAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD"
assert_contains "$signed_release_workflow_contents" "MACKAN_NOTARY_APPLE_ID"
assert_contains "$signed_release_workflow_contents" "MACKAN_NOTARY_TEAM_ID"
assert_contains "$signed_release_workflow_contents" "MACKAN_NOTARY_APP_SPECIFIC_PASSWORD"
assert_contains "$signed_release_workflow_contents" "Validate release secrets"
assert_contains "$signed_release_workflow_contents" "Validate release inputs"
assert_contains "$signed_release_workflow_contents" 'APP_VERSION must be a non-empty SemVer-like version'
assert_contains "$signed_release_workflow_contents" '"$APP_VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$'
assert_contains "$signed_release_workflow_contents" 'MACKAN_NOTARY_TIMEOUT must be a notarytool duration such as 30m, 120s, or 1h.'
assert_contains "$signed_release_workflow_contents" '"$MACKAN_NOTARY_TIMEOUT" =~ ^[1-9][0-9]*[smh]$'
assert_contains "$signed_release_workflow_contents" "missing_secrets=()"
assert_contains "$signed_release_workflow_contents" 'MACKAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64'
assert_contains "$signed_release_workflow_contents" 'MACKAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD'
assert_contains "$signed_release_workflow_contents" 'MACKAN_NOTARY_APPLE_ID'
assert_contains "$signed_release_workflow_contents" 'MACKAN_NOTARY_TEAM_ID'
assert_contains "$signed_release_workflow_contents" 'MACKAN_NOTARY_APP_SPECIFIC_PASSWORD'
assert_contains "$signed_release_workflow_contents" 'Missing required release secrets:'
assert_contains "$signed_release_workflow_contents" "security import"
assert_contains "$signed_release_workflow_contents" "xcrun notarytool store-credentials"
assert_contains "$signed_release_workflow_contents" "release-readiness.sh --strict --require-release-credentials"
assert_contains "$signed_release_workflow_contents" "macosx/MACKAN/scripts/release-dmg.sh"
assert_contains "$signed_release_workflow_contents" "release artifact validation failed:"
assert_contains "$signed_release_workflow_contents" '[[ -n "$MACKAN_DMG_PATH" ]] || fail_release_artifact'
assert_contains "$signed_release_workflow_contents" '[[ "$MACKAN_DMG_PATH" != *$'\''\n'\''* ]] || fail_release_artifact'
assert_contains "$signed_release_workflow_contents" "release-dmg.sh final output was empty"
assert_contains "$signed_release_workflow_contents" "release-dmg.sh final output contained a newline"
assert_contains "$signed_release_workflow_contents" "release-dmg.sh final output was not a DMG path"
assert_contains "$signed_release_workflow_contents" "DMG artifact missing"
assert_contains "$signed_release_workflow_contents" "app Info.plist missing"
assert_contains "$signed_release_workflow_contents" "provenance artifact missing"
assert_contains "$signed_release_workflow_contents" "notary JSON missing"
assert_contains "$signed_release_workflow_contents" "checksum manifest missing"
assert_contains "$signed_release_workflow_contents" "release summary missing"
assert_contains "$signed_release_workflow_contents" "release log missing or empty"
assert_contains "$signed_release_workflow_contents" '[[ "$MACKAN_DMG_PATH" == *.dmg ]] || fail_release_artifact'
assert_contains "$signed_release_workflow_contents" 'require_file "DMG artifact missing" "$MACKAN_DMG_PATH"'
assert_contains "$signed_release_workflow_contents" 'require_file "provenance artifact missing" "$MACKAN_PROVENANCE_PATH"'
assert_contains "$signed_release_workflow_contents" 'require_file "notary JSON missing" "$MACKAN_NOTARY_JSON_PATH"'
assert_contains "$signed_release_workflow_contents" 'require_file "checksum manifest missing" "$MACKAN_CHECKSUMS_PATH"'
assert_contains "$signed_release_workflow_contents" 'require_file "release summary missing" "$MACKAN_RELEASE_SUMMARY_PATH"'
assert_contains "$signed_release_workflow_contents" "MACKAN_RELEASE_LOG_PATH="
assert_contains "$signed_release_workflow_contents" "Verify signed release log"
assert_contains "$signed_release_workflow_contents" 'verify-release-log.sh "$MACKAN_RELEASE_LOG_PATH"'
assert_contains "$signed_release_workflow_contents" "verify-release-artifact.sh"
assert_contains "$signed_release_workflow_contents" "--require-public-release"
assert_contains "$signed_release_public_artifact_step" '--notary-json "$MACKAN_NOTARY_JSON_PATH"'
assert_contains "$signed_release_workflow_contents" "test-clean-install-smoke.sh"
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-dmg"
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-provenance"
assert_contains "$signed_release_workflow_contents" "MACKAN_NOTARY_JSON_PATH="
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-notary-json"
assert_contains "$signed_release_workflow_contents" "MACKAN_CHECKSUMS_PATH=\"\${MACKAN_DMG_PATH}.sha256\""
assert_contains "$signed_release_workflow_contents" "MACKAN_CHECKSUMS_PATH="
assert_not_contains "$signed_release_workflow_contents" "shasum -a 256"
assert_contains "$signed_release_workflow_contents" "verify-release-checksums.sh"
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-checksums"
assert_contains "$signed_release_workflow_contents" "MACKAN_RELEASE_SUMMARY_PATH=\"\${MACKAN_DMG_PATH}.release-summary.json\""
assert_not_contains "$signed_release_workflow_contents" "generate-release-summary.sh"
assert_contains "$signed_release_workflow_contents" "verify-release-summary.sh"
assert_contains "$signed_release_workflow_contents" "verify-public-release-handoff.sh"
assert_contains "$signed_release_workflow_contents" "MACKAN_RELEASE_SUMMARY_PATH="
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-summary"
assert_contains "$signed_release_workflow_contents" "MACKAN-signed-notarized-release-log"

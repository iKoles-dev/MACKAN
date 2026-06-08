#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-release-checksums.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-checksums-test.XXXXXX")"
DMG_PATH="$WORK_DIR/MACKAN.dmg"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
CHECKSUMS_PATH="$DMG_PATH.sha256"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

printf 'fake dmg bytes\n' > "$DMG_PATH"
printf '{"schemaVersion":1}\n' > "$PROVENANCE_PATH"
printf '{"id":"00000000-0000-0000-0000-000000000000","status":"Accepted"}\n' > "$NOTARY_JSON_PATH"
shasum -a 256 "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" > "$CHECKSUMS_PATH"

"$VERIFY_SCRIPT" \
    --checksums "$CHECKSUMS_PATH" \
    "$DMG_PATH" \
    "$PROVENANCE_PATH" \
    "$NOTARY_JSON_PATH"

printf 'tampered dmg bytes\n' > "$DMG_PATH"
if "$VERIFY_SCRIPT" --checksums "$CHECKSUMS_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" >/tmp/mackan-checksums-mismatch.out 2>&1; then
    echo "Expected checksum mismatch to fail." >&2
    exit 1
fi
grep -F "checksum mismatch" /tmp/mackan-checksums-mismatch.out >/dev/null
rm -f /tmp/mackan-checksums-mismatch.out

shasum -a 256 "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" > "$CHECKSUMS_PATH"
if "$VERIFY_SCRIPT" --checksums "$CHECKSUMS_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" >/tmp/mackan-checksums-missing.out 2>&1; then
    echo "Expected missing checksum line to fail." >&2
    exit 1
fi
grep -F "missing checksum line" /tmp/mackan-checksums-missing.out >/dev/null
rm -f /tmp/mackan-checksums-missing.out

printf 'fake dmg bytes\n' > "$DMG_PATH"
shasum -a 256 "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" > "$CHECKSUMS_PATH"
printf '%064d  %s\n' 0 "$DMG_PATH" >> "$CHECKSUMS_PATH"
if "$VERIFY_SCRIPT" --checksums "$CHECKSUMS_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" >/tmp/mackan-checksums-duplicate.out 2>&1; then
    echo "Expected duplicate checksum line to fail." >&2
    exit 1
fi
grep -F "duplicate checksum line" /tmp/mackan-checksums-duplicate.out >/dev/null
rm -f /tmp/mackan-checksums-duplicate.out

EXTRA_ARTIFACT_PATH="$WORK_DIR/extra-artifact.txt"
printf 'extra artifact bytes\n' > "$EXTRA_ARTIFACT_PATH"
shasum -a 256 "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" "$EXTRA_ARTIFACT_PATH" > "$CHECKSUMS_PATH"
if "$VERIFY_SCRIPT" --checksums "$CHECKSUMS_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" >/tmp/mackan-checksums-unexpected.out 2>&1; then
    echo "Expected unexpected checksum line to fail." >&2
    exit 1
fi
grep -F "unexpected checksum line" /tmp/mackan-checksums-unexpected.out >/dev/null
rm -f /tmp/mackan-checksums-unexpected.out

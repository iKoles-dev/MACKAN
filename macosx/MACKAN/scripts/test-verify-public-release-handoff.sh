#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-public-release-handoff.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-public-handoff-test.XXXXXX")"
APP_PATH="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN-1.2.3-universal.dmg"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
CHECKSUMS_PATH="$DMG_PATH.sha256"
SUMMARY_PATH="$DMG_PATH.release-summary.json"
FAKE_BIN="$WORK_DIR/bin"
APP_VERSION="1.2.3"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_PATH/Contents/MacOS" "$FAKE_BIN"
printf '#!/usr/bin/env bash\nexit 0\n' > "$APP_PATH/Contents/MacOS/MACKAN"
chmod +x "$APP_PATH/Contents/MacOS/MACKAN"
cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.test</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.3</string>
    <key>CFBundleVersion</key>
    <string>1.2.3</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

cat > "$FAKE_BIN/hdiutil" <<'SH'
#!/usr/bin/env bash
[[ "$1" == "verify" ]] || exit 2
exit 0
SH
cat > "$FAKE_BIN/codesign" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FAKE_BIN/spctl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FAKE_BIN/xcrun" <<'SH'
#!/usr/bin/env bash
[[ "$1" == "stapler" && "$2" == "validate" ]] || exit 2
exit 0
SH
chmod +x "$FAKE_BIN/hdiutil" "$FAKE_BIN/codesign" "$FAKE_BIN/spctl" "$FAKE_BIN/xcrun"

file_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
    stat -f '%z' "$1"
}

write_public_artifacts() {
    printf 'fake dmg bytes\n' > "$DMG_PATH"
    cat > "$NOTARY_JSON_PATH" <<JSON
{
  "id": "00000000-0000-0000-0000-000000000000",
  "status": "Accepted"
}
JSON

    local dmg_sha
    local dmg_size
    local notary_sha
    local notary_size
    dmg_sha="$(file_sha256 "$DMG_PATH")"
    dmg_size="$(file_size "$DMG_PATH")"
    notary_sha="$(file_sha256 "$NOTARY_JSON_PATH")"
    notary_size="$(file_size "$NOTARY_JSON_PATH")"

    cat > "$PROVENANCE_PATH" <<JSON
{
  "schemaVersion": 1,
  "generatedAtUtc": "2026-06-01T00:00:00Z",
  "app": {
    "name": "MACKAN",
    "version": "$APP_VERSION",
    "bundleIdentifier": "app.mackan.MACKAN.test",
    "bundleExecutable": "MACKAN",
    "path": "$APP_PATH",
    "sizeKiB": 1
  },
  "dmg": {
    "path": "$DMG_PATH",
    "sha256": "$dmg_sha",
    "sizeBytes": $dmg_size
  },
  "source": {
    "gitRevision": "test",
    "gitDirty": false
  },
  "verification": {
    "appCodesignValid": true,
    "appCodesignAuthority": "Developer ID Application: Example Team (ABCDE12345)",
    "appHardenedRuntime": true,
    "dmgCodesignValid": true,
    "dmgCodesignAuthority": "Developer ID Application: Example Team (ABCDE12345)",
    "dmgNotarizationStatus": "Accepted",
    "dmgNotarizationId": "00000000-0000-0000-0000-000000000000",
    "dmgNotaryJsonSha256": "$notary_sha",
    "dmgNotaryJsonSizeBytes": $notary_size,
    "dmgHdiutilValid": true,
    "dmgSpctlAccepted": true,
    "dmgStaplerValid": true
  }
}
JSON

    shasum -a 256 "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" > "$CHECKSUMS_PATH"
    "$SCRIPT_DIR/generate-release-summary.sh" \
        --output "$SUMMARY_PATH" \
        --version "$APP_VERSION" \
        --app "$APP_PATH" \
        --dmg "$DMG_PATH" \
        --provenance "$PROVENANCE_PATH" \
        --notary-json "$NOTARY_JSON_PATH" \
        --checksums "$CHECKSUMS_PATH" >/dev/null
}

write_public_artifacts
PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH" \
    --summary "$SUMMARY_PATH" \
    --require-version "$APP_VERSION"

printf 'tampered checksum manifest\n' > "$CHECKSUMS_PATH"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" --summary "$SUMMARY_PATH" --require-version "$APP_VERSION" >/tmp/mackan-handoff-checksums.out 2>&1; then
    echo "Expected tampered checksum manifest to fail." >&2
    exit 1
fi
grep -F "missing checksum line" /tmp/mackan-handoff-checksums.out >/dev/null
rm -f /tmp/mackan-handoff-checksums.out

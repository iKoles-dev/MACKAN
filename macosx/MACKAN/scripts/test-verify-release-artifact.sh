#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-release-artifact.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-artifact-test.XXXXXX")"
APP_DIR="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN.dmg"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
FAKE_BIN="$WORK_DIR/bin"
APP_VERSION="4.5.6"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS" "$FAKE_BIN"
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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
printf 'fake dmg bytes\n' > "$DMG_PATH"
expected_sha="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
expected_size="$(stat -f '%z' "$DMG_PATH")"

file_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
    stat -f '%z' "$1"
}

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

write_manifest() {
    local sha="$1"
    local size="$2"
    local app_codesign="$3"
    local dmg_codesign="$4"
    local hdiutil_valid="$5"
    local spctl_accepted="$6"
    local stapler_valid="$7"
    local git_dirty="${8:-true}"
    local app_authority="${9:-Developer ID Application: Example Team (ABCDE12345)}"
    local app_runtime="${10:-true}"
    local dmg_authority="${11:-Developer ID Application: Example Team (ABCDE12345)}"
    local dmg_notarization_status="${12:-Accepted}"
    local dmg_notarization_id="${13-00000000-0000-0000-0000-000000000000}"
    local dmg_notary_json_sha256="${14:-}"
    local dmg_notary_json_size="${15:-0}"

    cat > "$PROVENANCE_PATH" <<JSON
{
  "schemaVersion": 1,
  "generatedAtUtc": "2026-06-01T00:00:00Z",
  "app": {
    "name": "MACKAN",
    "version": "$APP_VERSION",
    "bundleIdentifier": "app.mackan.MACKAN.test",
    "bundleExecutable": "MACKAN",
    "path": "$APP_DIR",
    "sizeKiB": 1
  },
  "dmg": {
    "path": "$DMG_PATH",
    "sha256": "$sha",
    "sizeBytes": $size
  },
  "source": {
    "gitRevision": "test",
    "gitDirty": $git_dirty
  },
  "verification": {
    "appCodesignValid": $app_codesign,
    "appCodesignAuthority": "$app_authority",
    "appHardenedRuntime": $app_runtime,
    "dmgCodesignValid": $dmg_codesign,
    "dmgCodesignAuthority": "$dmg_authority",
    "dmgNotarizationStatus": "$dmg_notarization_status",
    "dmgNotarizationId": "$dmg_notarization_id",
    "dmgNotaryJsonSha256": "$dmg_notary_json_sha256",
    "dmgNotaryJsonSizeBytes": $dmg_notary_json_size,
    "dmgHdiutilValid": $hdiutil_valid,
    "dmgSpctlAccepted": $spctl_accepted,
    "dmgStaplerValid": $stapler_valid
  }
}
JSON
}

write_notary_json() {
    local status="${1:-Accepted}"
    local id="${2:-00000000-0000-0000-0000-000000000000}"

    cat > "$NOTARY_JSON_PATH" <<JSON
{
  "id": "$id",
  "status": "$status"
}
JSON
}

write_notary_json_with_extra_audit_field() {
    local status="${1:-Accepted}"
    local id="${2:-00000000-0000-0000-0000-000000000000}"

    cat > "$NOTARY_JSON_PATH" <<JSON
{
  "id": "$id",
  "status": "$status",
  "createdDate": "2026-06-01T00:00:00Z"
}
JSON
}

write_manifest "$expected_sha" "$expected_size" true false true false false
PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION"

write_manifest "$expected_sha" "$expected_size" true false true false false
/usr/bin/python3 - "$PROVENANCE_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["verification"].pop("dmgNotarizationStatus", None)
payload["verification"].pop("dmgNotarizationId", None)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY
PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION"

if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version 0.0.0 >/tmp/mackan-artifact-version.out 2>&1; then
    echo "Expected version mismatch to fail." >&2
    exit 1
fi
grep -F "does not match required version" /tmp/mackan-artifact-version.out >/dev/null
rm -f /tmp/mackan-artifact-version.out

write_manifest "0000" "$expected_size" true false true false false
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" >/tmp/mackan-artifact-sha.out 2>&1; then
    echo "Expected SHA-256 mismatch to fail." >&2
    exit 1
fi
grep -F "DMG SHA-256 mismatch" /tmp/mackan-artifact-sha.out >/dev/null
rm -f /tmp/mackan-artifact-sha.out

write_manifest "$expected_sha" "$expected_size" true false true false false false
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-public-release >/tmp/mackan-artifact-public.out 2>&1; then
    echo "Expected public-release verification to fail for unsigned manifest booleans." >&2
    exit 1
fi
grep -F "dmgCodesignValid must be true for public release" /tmp/mackan-artifact-public.out >/dev/null
rm -f /tmp/mackan-artifact-public.out

write_manifest "$expected_sha" "$expected_size" true true true true true
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-dirty.out 2>&1; then
    echo "Expected public-release verification to fail for dirty source provenance." >&2
    exit 1
fi
grep -F "source.gitDirty must be false for public release" /tmp/mackan-artifact-dirty.out >/dev/null
rm -f /tmp/mackan-artifact-dirty.out

write_manifest "$expected_sha" "$expected_size" true true true true true false "Apple Development: Example Team" true
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-identity.out 2>&1; then
    echo "Expected public-release verification to fail for non-Developer ID app signing authority." >&2
    exit 1
fi
grep -F "appCodesignAuthority must start with Developer ID Application for public release" /tmp/mackan-artifact-identity.out >/dev/null
rm -f /tmp/mackan-artifact-identity.out

write_manifest "$expected_sha" "$expected_size" true true true true true false "Developer ID Application: Example Team (ABCDE12345)" false
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-runtime.out 2>&1; then
    echo "Expected public-release verification to fail when hardened runtime is missing." >&2
    exit 1
fi
grep -F "appHardenedRuntime must be true for public release" /tmp/mackan-artifact-runtime.out >/dev/null
rm -f /tmp/mackan-artifact-runtime.out

write_manifest "$expected_sha" "$expected_size" true true true true true false "Developer ID Application: Example Team (ABCDE12345)" true "Apple Development: Example Team"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-dmg-identity.out 2>&1; then
    echo "Expected public-release verification to fail for non-Developer-ID DMG signing authority." >&2
    exit 1
fi
grep -F "dmgCodesignAuthority must start with Developer ID Application for public release" /tmp/mackan-artifact-dmg-identity.out >/dev/null
rm -f /tmp/mackan-artifact-dmg-identity.out

write_manifest "$expected_sha" "$expected_size" true true true true true false "Developer ID Application: Example Team (ABCDE12345)" true "Developer ID Application: Example Team (ABCDE12345)" "Invalid"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-status.out 2>&1; then
    echo "Expected public-release verification to fail for non-accepted notarization status." >&2
    exit 1
fi
grep -F "dmgNotarizationStatus must be Accepted for public release" /tmp/mackan-artifact-notary-status.out >/dev/null
rm -f /tmp/mackan-artifact-notary-status.out

write_manifest "$expected_sha" "$expected_size" true true true true true false "Developer ID Application: Example Team (ABCDE12345)" true "Developer ID Application: Example Team (ABCDE12345)" "Accepted" ""
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-id.out 2>&1; then
    echo "Expected public-release verification to fail for missing notarization submission id." >&2
    exit 1
fi
grep -F "dmgNotarizationId must be set for public release" /tmp/mackan-artifact-notary-id.out >/dev/null
rm -f /tmp/mackan-artifact-notary-id.out

write_manifest "$expected_sha" "$expected_size" true true true true true false
rm -f "$NOTARY_JSON_PATH"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-json-missing.out 2>&1; then
    echo "Expected public-release verification to fail when notary JSON is missing." >&2
    exit 1
fi
grep -F "Notary JSON not found" /tmp/mackan-artifact-notary-json-missing.out >/dev/null
rm -f /tmp/mackan-artifact-notary-json-missing.out

write_manifest "$expected_sha" "$expected_size" true true true true true false
write_notary_json "Invalid" "00000000-0000-0000-0000-000000000000"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-json-status.out 2>&1; then
    echo "Expected public-release verification to fail when notary JSON status mismatches provenance." >&2
    exit 1
fi
grep -F "Notary JSON status does not match provenance" /tmp/mackan-artifact-notary-json-status.out >/dev/null
rm -f /tmp/mackan-artifact-notary-json-status.out

write_manifest "$expected_sha" "$expected_size" true true true true true false
write_notary_json "Accepted" "11111111-1111-1111-1111-111111111111"
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-json-id.out 2>&1; then
    echo "Expected public-release verification to fail when notary JSON id mismatches provenance." >&2
    exit 1
fi
grep -F "Notary JSON id does not match provenance" /tmp/mackan-artifact-notary-json-id.out >/dev/null
rm -f /tmp/mackan-artifact-notary-json-id.out

write_notary_json
notary_sha="$(file_sha256 "$NOTARY_JSON_PATH")"
notary_size="$(file_size "$NOTARY_JSON_PATH")"
write_manifest "$expected_sha" "$expected_size" true true true true true false \
    "Developer ID Application: Example Team (ABCDE12345)" \
    true \
    "Developer ID Application: Example Team (ABCDE12345)" \
    "Accepted" \
    "00000000-0000-0000-0000-000000000000" \
    "$notary_sha" \
    "$notary_size"

write_notary_json_with_extra_audit_field
if PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release >/tmp/mackan-artifact-notary-json-sha.out 2>&1; then
    echo "Expected public-release verification to fail when notary JSON bytes do not match provenance." >&2
    exit 1
fi
grep -F "Notary JSON SHA-256 mismatch" /tmp/mackan-artifact-notary-json-sha.out >/dev/null
rm -f /tmp/mackan-artifact-notary-json-sha.out

write_notary_json
PATH="$FAKE_BIN:$PATH" "$VERIFY_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release

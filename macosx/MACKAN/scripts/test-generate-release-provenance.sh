#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVENANCE_SCRIPT="$SCRIPT_DIR/generate-release-provenance.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-provenance-test.XXXXXX")"
APP_DIR="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN.dmg"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
APP_VERSION="7.8.9"
NOTARY_ID="00000000-0000-0000-0000-000000000000"

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
cat > "$NOTARY_JSON_PATH" <<JSON
{
  "id": "$NOTARY_ID",
  "status": "Accepted"
}
JSON

expected_notary_sha="$(shasum -a 256 "$NOTARY_JSON_PATH" | awk '{print $1}')"
expected_notary_size="$(stat -f '%z' "$NOTARY_JSON_PATH")"

MACKAN_RELEASE_NOTARIZATION_STATUS=Accepted \
    MACKAN_RELEASE_NOTARIZATION_ID="$NOTARY_ID" \
    MACKAN_RELEASE_NOTARY_JSON_PATH="$NOTARY_JSON_PATH" \
    "$PROVENANCE_SCRIPT" --app "$APP_DIR" --dmg "$DMG_PATH" --output "$PROVENANCE_PATH" >/dev/null

/usr/bin/python3 - "$PROVENANCE_PATH" "$expected_notary_sha" "$expected_notary_size" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

verification = payload["verification"]
assert verification["dmgNotarizationStatus"] == "Accepted"
assert verification["dmgNotarizationId"] == "00000000-0000-0000-0000-000000000000"
assert verification["dmgNotaryJsonSha256"] == sys.argv[2]
assert str(verification["dmgNotaryJsonSizeBytes"]) == sys.argv[3]
PY

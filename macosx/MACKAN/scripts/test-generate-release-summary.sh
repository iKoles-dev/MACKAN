#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SCRIPT="$SCRIPT_DIR/generate-release-summary.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-summary-test.XXXXXX")"
APP_PATH="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN-1.2.3-universal.dmg"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
CHECKSUMS_PATH="$DMG_PATH.sha256"
SUMMARY_PATH="$DMG_PATH.release-summary.json"
SPACED_DIR="$WORK_DIR/path with spaces"
SPACED_APP_PATH="$SPACED_DIR/MACKAN.app"
SPACED_DMG_PATH="$SPACED_DIR/MACKAN 1.2.3 universal.dmg"
SPACED_PROVENANCE_PATH="$SPACED_DMG_PATH.provenance.json"
SPACED_NOTARY_JSON_PATH="$SPACED_DMG_PATH.notary.json"
SPACED_CHECKSUMS_PATH="$SPACED_DMG_PATH.sha256"
SPACED_SUMMARY_PATH="$SPACED_DMG_PATH.release-summary.json"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_PATH"
printf 'dmg\n' > "$DMG_PATH"
printf '{"schemaVersion":1}\n' > "$PROVENANCE_PATH"
printf '{"id":"00000000-0000-0000-0000-000000000000","status":"Accepted"}\n' > "$NOTARY_JSON_PATH"
shasum -a 256 "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" > "$CHECKSUMS_PATH"

"$GENERATE_SCRIPT" \
    --output "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH"

/usr/bin/python3 - "$SUMMARY_PATH" "$APP_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" "$CHECKSUMS_PATH" <<'PY'
import json
import sys

summary_path, app_path, dmg_path, provenance_path, notary_json_path, checksums_path = sys.argv[1:]
with open(summary_path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

def sha256(path):
    import hashlib
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def size(path):
    import os
    return os.path.getsize(path)

assert payload["schemaVersion"] == 1
assert payload["app"]["version"] == "1.2.3"
assert payload["artifacts"]["app"]["path"] == app_path
assert payload["artifacts"]["dmg"]["path"] == dmg_path
assert payload["artifacts"]["dmg"]["sha256"] == sha256(dmg_path)
assert payload["artifacts"]["dmg"]["sizeBytes"] == size(dmg_path)
assert payload["artifacts"]["provenance"]["path"] == provenance_path
assert payload["artifacts"]["provenance"]["sha256"] == sha256(provenance_path)
assert payload["artifacts"]["provenance"]["sizeBytes"] == size(provenance_path)
assert payload["artifacts"]["notaryJson"]["path"] == notary_json_path
assert payload["artifacts"]["notaryJson"]["sha256"] == sha256(notary_json_path)
assert payload["artifacts"]["notaryJson"]["sizeBytes"] == size(notary_json_path)
assert payload["artifacts"]["checksums"]["path"] == checksums_path
assert payload["artifacts"]["checksums"]["sha256"] == sha256(checksums_path)
assert payload["artifacts"]["checksums"]["sizeBytes"] == size(checksums_path)
assert payload["githubArtifacts"]["dmg"] == "MACKAN-signed-notarized-dmg"
assert payload["githubArtifacts"]["provenance"] == "MACKAN-signed-notarized-provenance"
assert payload["githubArtifacts"]["notaryJson"] == "MACKAN-signed-notarized-notary-json"
assert payload["githubArtifacts"]["checksums"] == "MACKAN-signed-notarized-checksums"
assert payload["githubArtifacts"]["releaseLog"] == "MACKAN-signed-notarized-release-log"
assert "verify-release-artifact.sh" in payload["verification"]["publicArtifactCommand"]
assert "--require-public-release" in payload["verification"]["publicArtifactCommand"]
assert "--notary-json" in payload["verification"]["publicArtifactCommand"]
assert notary_json_path in payload["verification"]["publicArtifactCommand"]
assert "verify-release-checksums.sh" in payload["verification"]["checksumsCommand"]
assert checksums_path in payload["verification"]["checksumsCommand"]
assert "verify-public-release-handoff.sh" in payload["verification"]["publicHandoffCommand"]
assert "--summary" in payload["verification"]["publicHandoffCommand"]
assert summary_path in payload["verification"]["publicHandoffCommand"]
assert checksums_path in payload["verification"]["publicHandoffCommand"]
PY

mkdir -p "$SPACED_APP_PATH"
printf 'spaced dmg\n' > "$SPACED_DMG_PATH"
printf '{"schemaVersion":1}\n' > "$SPACED_PROVENANCE_PATH"
printf '{"id":"00000000-0000-0000-0000-000000000000","status":"Accepted"}\n' > "$SPACED_NOTARY_JSON_PATH"
shasum -a 256 "$SPACED_DMG_PATH" "$SPACED_PROVENANCE_PATH" "$SPACED_NOTARY_JSON_PATH" > "$SPACED_CHECKSUMS_PATH"

"$GENERATE_SCRIPT" \
    --output "$SPACED_SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$SPACED_APP_PATH" \
    --dmg "$SPACED_DMG_PATH" \
    --provenance "$SPACED_PROVENANCE_PATH" \
    --notary-json "$SPACED_NOTARY_JSON_PATH" \
    --checksums "$SPACED_CHECKSUMS_PATH"

/usr/bin/python3 - "$SPACED_SUMMARY_PATH" "$SPACED_APP_PATH" "$SPACED_DMG_PATH" "$SPACED_PROVENANCE_PATH" "$SPACED_NOTARY_JSON_PATH" "$SPACED_CHECKSUMS_PATH" <<'PY'
import json
import sys

summary_path, app_path, dmg_path, provenance_path, notary_json_path, checksums_path = sys.argv[1:]
with open(summary_path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

commands = (
    payload["verification"]["publicArtifactCommand"],
    payload["verification"]["checksumsCommand"],
    payload["verification"]["publicHandoffCommand"],
)

for path in (app_path, dmg_path, provenance_path, notary_json_path, checksums_path, summary_path):
    quoted = "'" + path.replace("'", "'\\''") + "'"
    if not any(quoted in command for command in commands):
        raise SystemExit(f"quoted path missing from generated handoff commands: {quoted}")
PY

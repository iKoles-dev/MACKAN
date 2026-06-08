#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SCRIPT="$SCRIPT_DIR/generate-release-summary.sh"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-release-summary.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-summary-verify-test.XXXXXX")"
APP_PATH="$WORK_DIR/MACKAN.app"
DMG_PATH="$WORK_DIR/MACKAN-1.2.3-universal.dmg"
PROVENANCE_PATH="$DMG_PATH.provenance.json"
NOTARY_JSON_PATH="$DMG_PATH.notary.json"
CHECKSUMS_PATH="$DMG_PATH.sha256"
SUMMARY_PATH="$DMG_PATH.release-summary.json"
SPACED_DIR="$WORK_DIR/path with spaces"
SPACED_APP_PATH="$SPACED_DIR/MACKAN.app"
SPACED_DMG_PATH="$SPACED_DIR/MACKAN 1.2.3-universal.dmg"
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
    --checksums "$CHECKSUMS_PATH" >/dev/null

"$VERIFY_SCRIPT" \
    --summary "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH"

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "9.9.9" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-version.out 2>&1; then
    echo "Expected version mismatch to fail." >&2
    exit 1
fi
grep -F "summary app.version mismatch" /tmp/mackan-summary-version.out >/dev/null
rm -f /tmp/mackan-summary-version.out

printf 'tampered dmg\n' > "$DMG_PATH"
if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-digest.out 2>&1; then
    echo "Expected DMG digest mismatch to fail." >&2
    exit 1
fi
grep -F "summary artifacts.dmg.sha256 mismatch" /tmp/mackan-summary-digest.out >/dev/null
rm -f /tmp/mackan-summary-digest.out

printf 'dmg\n' > "$DMG_PATH"

/usr/bin/python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["githubArtifacts"].pop("summary", None)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-artifact.out 2>&1; then
    echo "Expected missing summary artifact name to fail." >&2
    exit 1
fi
grep -F "summary githubArtifacts.summary mismatch" /tmp/mackan-summary-artifact.out >/dev/null
rm -f /tmp/mackan-summary-artifact.out

"$GENERATE_SCRIPT" \
    --output "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH" >/dev/null

/usr/bin/python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["generatedAtUtc"] = "not-a-timestamp"
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-generated-at.out 2>&1; then
    echo "Expected invalid generatedAtUtc to fail." >&2
    exit 1
fi
grep -F "summary generatedAtUtc mismatch" /tmp/mackan-summary-generated-at.out >/dev/null
rm -f /tmp/mackan-summary-generated-at.out

"$GENERATE_SCRIPT" \
    --output "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH" >/dev/null

/usr/bin/python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["githubArtifacts"].pop("releaseLog", None)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-release-log.out 2>&1; then
    echo "Expected missing release log artifact name to fail." >&2
    exit 1
fi
grep -F "summary githubArtifacts.releaseLog mismatch" /tmp/mackan-summary-release-log.out >/dev/null
rm -f /tmp/mackan-summary-release-log.out

"$GENERATE_SCRIPT" \
    --output "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH" >/dev/null

/usr/bin/python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
payload["verification"].pop("publicHandoffCommand", None)
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-handoff.out 2>&1; then
    echo "Expected missing public handoff command to fail." >&2
    exit 1
fi
grep -F "summary verification.publicHandoffCommand mismatch" /tmp/mackan-summary-handoff.out >/dev/null
rm -f /tmp/mackan-summary-handoff.out

"$GENERATE_SCRIPT" \
    --output "$SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH" >/dev/null

/usr/bin/python3 - "$SUMMARY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
notary_path = payload["artifacts"]["notaryJson"]["path"]
quoted_notary_path = "'" + notary_path.replace("'", "'\\''") + "'"
payload["verification"]["publicArtifactCommand"] = payload["verification"]["publicArtifactCommand"].replace(" --notary-json " + quoted_notary_path, "")
payload["verification"]["publicArtifactCommand"] = payload["verification"]["publicArtifactCommand"].replace(" --notary-json " + notary_path, "")
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SUMMARY_PATH" --version "1.2.3" --app "$APP_PATH" --dmg "$DMG_PATH" --provenance "$PROVENANCE_PATH" --notary-json "$NOTARY_JSON_PATH" --checksums "$CHECKSUMS_PATH" >/tmp/mackan-summary-notary-command.out 2>&1; then
    echo "Expected public artifact command without notary JSON path to fail." >&2
    exit 1
fi
grep -F "summary verification.publicArtifactCommand mismatch" /tmp/mackan-summary-notary-command.out >/dev/null
rm -f /tmp/mackan-summary-notary-command.out

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
    --checksums "$SPACED_CHECKSUMS_PATH" >/dev/null

"$VERIFY_SCRIPT" \
    --summary "$SPACED_SUMMARY_PATH" \
    --version "1.2.3" \
    --app "$SPACED_APP_PATH" \
    --dmg "$SPACED_DMG_PATH" \
    --provenance "$SPACED_PROVENANCE_PATH" \
    --notary-json "$SPACED_NOTARY_JSON_PATH" \
    --checksums "$SPACED_CHECKSUMS_PATH"

/usr/bin/python3 - "$SPACED_SUMMARY_PATH" "$SPACED_APP_PATH" <<'PY'
import json
import sys

summary_path, app_path = sys.argv[1:]
quoted_app_path = "'" + app_path.replace("'", "'\\''") + "'"
with open(summary_path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)
for key in ("publicArtifactCommand", "publicHandoffCommand"):
    payload["verification"][key] = payload["verification"][key].replace(quoted_app_path, app_path)
with open(summary_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if "$VERIFY_SCRIPT" --summary "$SPACED_SUMMARY_PATH" --version "1.2.3" --app "$SPACED_APP_PATH" --dmg "$SPACED_DMG_PATH" --provenance "$SPACED_PROVENANCE_PATH" --notary-json "$SPACED_NOTARY_JSON_PATH" --checksums "$SPACED_CHECKSUMS_PATH" >/tmp/mackan-summary-unquoted-spaced.out 2>&1; then
    echo "Expected unquoted spaced path in summary verifier commands to fail." >&2
    exit 1
fi
grep -F "summary verification.publicArtifactCommand mismatch" /tmp/mackan-summary-unquoted-spaced.out >/dev/null
rm -f /tmp/mackan-summary-unquoted-spaced.out

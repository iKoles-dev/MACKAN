#!/usr/bin/env bash
set -euo pipefail

SUMMARY_PATH=""
APP_VERSION=""
APP_PATH=""
DMG_PATH=""
PROVENANCE_PATH=""
NOTARY_JSON_PATH=""
CHECKSUMS_PATH=""

usage() {
    cat <<USAGE
Usage: verify-release-summary.sh --summary PATH --version VERSION --app PATH --dmg PATH --provenance PATH --notary-json PATH --checksums PATH

Validates the signed MACKAN release handoff summary before it is uploaded as a
public-release artifact.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary)
            SUMMARY_PATH="${2:-}"
            shift 2
            ;;
        --version)
            APP_VERSION="${2:-}"
            shift 2
            ;;
        --app)
            APP_PATH="${2:-}"
            shift 2
            ;;
        --dmg)
            DMG_PATH="${2:-}"
            shift 2
            ;;
        --provenance)
            PROVENANCE_PATH="${2:-}"
            shift 2
            ;;
        --notary-json)
            NOTARY_JSON_PATH="${2:-}"
            shift 2
            ;;
        --checksums)
            CHECKSUMS_PATH="${2:-}"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

require_value() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        echo "$name is required." >&2
        usage >&2
        exit 2
    fi
}

require_existing_path() {
    local label="$1"
    local path="$2"

    if [[ ! -e "$path" ]]; then
        echo "$label does not exist: $path" >&2
        exit 1
    fi
}

require_value "--summary" "$SUMMARY_PATH"
require_value "--version" "$APP_VERSION"
require_value "--app" "$APP_PATH"
require_value "--dmg" "$DMG_PATH"
require_value "--provenance" "$PROVENANCE_PATH"
require_value "--notary-json" "$NOTARY_JSON_PATH"
require_value "--checksums" "$CHECKSUMS_PATH"

require_existing_path "Release summary" "$SUMMARY_PATH"
require_existing_path "App artifact" "$APP_PATH"
require_existing_path "DMG artifact" "$DMG_PATH"
require_existing_path "Provenance artifact" "$PROVENANCE_PATH"
require_existing_path "Notary JSON artifact" "$NOTARY_JSON_PATH"
require_existing_path "Checksums artifact" "$CHECKSUMS_PATH"

/usr/bin/python3 - "$SUMMARY_PATH" "$APP_VERSION" "$APP_PATH" "$DMG_PATH" "$PROVENANCE_PATH" "$NOTARY_JSON_PATH" "$CHECKSUMS_PATH" <<'PY'
import json
import hashlib
import os
import shlex
import sys
from datetime import datetime, timezone

summary_path, app_version, app_path, dmg_path, provenance_path, notary_json_path, checksums_path = sys.argv[1:]

def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)

try:
    with open(summary_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except Exception as exc:
    fail(f"summary JSON is unreadable: {exc}")

def require_equal(path: str, expected: object) -> None:
    current = payload
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            fail(f"summary {path} mismatch")
        current = current[part]
    if current != expected:
        fail(f"summary {path} mismatch")

def file_sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()

def require_file_digest(prefix: str, path: str) -> None:
    require_equal(f"{prefix}.sha256", file_sha256(path))
    require_equal(f"{prefix}.sizeBytes", os.path.getsize(path))

def require_command(command: str, expected: list[str], label: str) -> None:
    try:
        tokens = shlex.split(command)
    except ValueError as exc:
        fail(f"summary verification.{label} mismatch: {exc}")
    if tokens != expected:
        fail(f"summary verification.{label} mismatch")

require_equal("schemaVersion", 1)
generated_at_utc = payload.get("generatedAtUtc")
if not isinstance(generated_at_utc, str):
    fail("summary generatedAtUtc mismatch")
try:
    parsed_generated_at = datetime.strptime(generated_at_utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
except ValueError:
    fail("summary generatedAtUtc mismatch")
if parsed_generated_at.strftime("%Y-%m-%dT%H:%M:%SZ") != generated_at_utc:
    fail("summary generatedAtUtc mismatch")
require_equal("app.name", "MACKAN")
require_equal("app.version", app_version)
require_equal("artifacts.app.path", app_path)
require_equal("artifacts.dmg.path", dmg_path)
require_file_digest("artifacts.dmg", dmg_path)
require_equal("artifacts.provenance.path", provenance_path)
require_file_digest("artifacts.provenance", provenance_path)
require_equal("artifacts.notaryJson.path", notary_json_path)
require_file_digest("artifacts.notaryJson", notary_json_path)
require_equal("artifacts.checksums.path", checksums_path)
require_file_digest("artifacts.checksums", checksums_path)
require_equal("githubArtifacts.dmg", "MACKAN-signed-notarized-dmg")
require_equal("githubArtifacts.provenance", "MACKAN-signed-notarized-provenance")
require_equal("githubArtifacts.notaryJson", "MACKAN-signed-notarized-notary-json")
require_equal("githubArtifacts.checksums", "MACKAN-signed-notarized-checksums")
require_equal("githubArtifacts.summary", "MACKAN-signed-notarized-summary")
require_equal("githubArtifacts.releaseLog", "MACKAN-signed-notarized-release-log")

verification = payload.get("verification")
if not isinstance(verification, dict):
    fail("summary verification mismatch")

public_command = verification.get("publicArtifactCommand", "")
require_command(public_command, [
    "macosx/MACKAN/scripts/verify-release-artifact.sh",
    "--app", app_path,
    "--dmg", dmg_path,
    "--provenance", provenance_path,
    "--notary-json", notary_json_path,
    "--require-version", app_version,
    "--require-public-release",
], "publicArtifactCommand")

checksums_command = verification.get("checksumsCommand", "")
require_command(checksums_command, [
    "macosx/MACKAN/scripts/verify-release-checksums.sh",
    "--checksums", checksums_path,
    dmg_path,
    provenance_path,
    notary_json_path,
], "checksumsCommand")

public_handoff_command = verification.get("publicHandoffCommand", "")
require_command(public_handoff_command, [
    "macosx/MACKAN/scripts/verify-public-release-handoff.sh",
    "--app", app_path,
    "--dmg", dmg_path,
    "--provenance", provenance_path,
    "--notary-json", notary_json_path,
    "--checksums", checksums_path,
    "--summary", summary_path,
    "--require-version", app_version,
], "publicHandoffCommand")
PY

echo "Release summary verified: $SUMMARY_PATH"

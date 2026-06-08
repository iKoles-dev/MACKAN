#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH=""
APP_VERSION=""
APP_PATH=""
DMG_PATH=""
PROVENANCE_PATH=""
NOTARY_JSON_PATH=""
CHECKSUMS_PATH=""

usage() {
    cat <<USAGE
Usage: generate-release-summary.sh --output PATH --version VERSION --app PATH --dmg PATH --provenance PATH --notary-json PATH --checksums PATH

Writes a machine-readable handoff summary for the signed MACKAN public-release
artifacts. The summary intentionally records artifact paths, upload artifact
names, and verifier commands, but no signing or notary credentials.
USAGE
}

json_string() {
    /usr/bin/python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

file_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
    stat -f '%z' "$1"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_PATH="${2:-}"
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

require_value "--output" "$OUTPUT_PATH"
require_value "--version" "$APP_VERSION"
require_value "--app" "$APP_PATH"
require_value "--dmg" "$DMG_PATH"
require_value "--provenance" "$PROVENANCE_PATH"
require_value "--notary-json" "$NOTARY_JSON_PATH"
require_value "--checksums" "$CHECKSUMS_PATH"

require_existing_path "App artifact" "$APP_PATH"
require_existing_path "DMG artifact" "$DMG_PATH"
require_existing_path "Provenance artifact" "$PROVENANCE_PATH"
require_existing_path "Notary JSON artifact" "$NOTARY_JSON_PATH"
require_existing_path "Checksums artifact" "$CHECKSUMS_PATH"

mkdir -p "$(dirname "$OUTPUT_PATH")"
generated_at_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
quoted_output_path="$(shell_quote "$OUTPUT_PATH")"
quoted_app_version="$(shell_quote "$APP_VERSION")"
quoted_app_path="$(shell_quote "$APP_PATH")"
quoted_dmg_path="$(shell_quote "$DMG_PATH")"
quoted_provenance_path="$(shell_quote "$PROVENANCE_PATH")"
quoted_notary_json_path="$(shell_quote "$NOTARY_JSON_PATH")"
quoted_checksums_path="$(shell_quote "$CHECKSUMS_PATH")"
public_artifact_command="macosx/MACKAN/scripts/verify-release-artifact.sh --app $quoted_app_path --dmg $quoted_dmg_path --provenance $quoted_provenance_path --notary-json $quoted_notary_json_path --require-version $quoted_app_version --require-public-release"
checksums_command="macosx/MACKAN/scripts/verify-release-checksums.sh --checksums $quoted_checksums_path $quoted_dmg_path $quoted_provenance_path $quoted_notary_json_path"
public_handoff_command="macosx/MACKAN/scripts/verify-public-release-handoff.sh --app $quoted_app_path --dmg $quoted_dmg_path --provenance $quoted_provenance_path --notary-json $quoted_notary_json_path --checksums $quoted_checksums_path --summary $quoted_output_path --require-version $quoted_app_version"
dmg_sha256="$(file_sha256 "$DMG_PATH")"
dmg_size="$(file_size "$DMG_PATH")"
provenance_sha256="$(file_sha256 "$PROVENANCE_PATH")"
provenance_size="$(file_size "$PROVENANCE_PATH")"
notary_json_sha256="$(file_sha256 "$NOTARY_JSON_PATH")"
notary_json_size="$(file_size "$NOTARY_JSON_PATH")"
checksums_sha256="$(file_sha256 "$CHECKSUMS_PATH")"
checksums_size="$(file_size "$CHECKSUMS_PATH")"

cat > "$OUTPUT_PATH" <<JSON
{
  "schemaVersion": 1,
  "generatedAtUtc": $(json_string "$generated_at_utc"),
  "app": {
    "name": "MACKAN",
    "version": $(json_string "$APP_VERSION")
  },
  "artifacts": {
    "app": {
      "path": $(json_string "$APP_PATH")
    },
    "dmg": {
      "path": $(json_string "$DMG_PATH"),
      "sha256": $(json_string "$dmg_sha256"),
      "sizeBytes": $dmg_size
    },
    "provenance": {
      "path": $(json_string "$PROVENANCE_PATH"),
      "sha256": $(json_string "$provenance_sha256"),
      "sizeBytes": $provenance_size
    },
    "notaryJson": {
      "path": $(json_string "$NOTARY_JSON_PATH"),
      "sha256": $(json_string "$notary_json_sha256"),
      "sizeBytes": $notary_json_size
    },
    "checksums": {
      "path": $(json_string "$CHECKSUMS_PATH"),
      "sha256": $(json_string "$checksums_sha256"),
      "sizeBytes": $checksums_size
    }
  },
  "githubArtifacts": {
    "dmg": "MACKAN-signed-notarized-dmg",
    "provenance": "MACKAN-signed-notarized-provenance",
    "notaryJson": "MACKAN-signed-notarized-notary-json",
    "checksums": "MACKAN-signed-notarized-checksums",
    "summary": "MACKAN-signed-notarized-summary",
    "releaseLog": "MACKAN-signed-notarized-release-log"
  },
  "verification": {
    "publicArtifactCommand": $(json_string "$public_artifact_command"),
    "checksumsCommand": $(json_string "$checksums_command"),
    "publicHandoffCommand": $(json_string "$public_handoff_command")
  }
}
JSON

echo "$OUTPUT_PATH"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH=""
DMG_PATH=""
PROVENANCE_PATH=""
NOTARY_JSON_PATH=""
CHECKSUMS_PATH=""
SUMMARY_PATH=""
REQUIRE_VERSION=""

usage() {
    cat <<USAGE
Usage: verify-public-release-handoff.sh --app PATH --dmg PATH --provenance PATH --notary-json PATH --checksums PATH --summary PATH --require-version VERSION

Runs the complete public-release handoff verification for the signed MACKAN
artifact set: DMG/provenance/notary JSON, checksum manifest, and release
summary.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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
        --summary)
            SUMMARY_PATH="${2:-}"
            shift 2
            ;;
        --require-version)
            REQUIRE_VERSION="${2:-}"
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

require_value "--app" "$APP_PATH"
require_value "--dmg" "$DMG_PATH"
require_value "--provenance" "$PROVENANCE_PATH"
require_value "--notary-json" "$NOTARY_JSON_PATH"
require_value "--checksums" "$CHECKSUMS_PATH"
require_value "--summary" "$SUMMARY_PATH"
require_value "--require-version" "$REQUIRE_VERSION"

"$SCRIPT_DIR/verify-release-artifact.sh" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --require-version "$REQUIRE_VERSION" \
    --require-public-release

"$SCRIPT_DIR/verify-release-checksums.sh" \
    --checksums "$CHECKSUMS_PATH" \
    "$DMG_PATH" \
    "$PROVENANCE_PATH" \
    "$NOTARY_JSON_PATH"

"$SCRIPT_DIR/verify-release-summary.sh" \
    --summary "$SUMMARY_PATH" \
    --version "$REQUIRE_VERSION" \
    --app "$APP_PATH" \
    --dmg "$DMG_PATH" \
    --provenance "$PROVENANCE_PATH" \
    --notary-json "$NOTARY_JSON_PATH" \
    --checksums "$CHECKSUMS_PATH"

echo "Public release handoff verified: $DMG_PATH"

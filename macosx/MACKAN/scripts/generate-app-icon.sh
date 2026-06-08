#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
SOURCE_ICON="$REPO_ROOT/assets/mackan.icns"
OUTPUT_PATH=""

usage() {
    cat <<USAGE
Usage: generate-app-icon.sh --output PATH

Copies the selected MACKAN .icns app icon into the requested output path for
local and release macOS bundles.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_PATH="$2"
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

if [[ -z "$OUTPUT_PATH" ]]; then
    usage >&2
    exit 2
fi

if [[ ! -f "$SOURCE_ICON" ]]; then
    echo "Missing MACKAN app icon: $SOURCE_ICON" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp "$SOURCE_ICON" "$OUTPUT_PATH"

#!/usr/bin/env bash
set -euo pipefail

CHECKSUMS_PATH=""

usage() {
    cat <<USAGE
Usage: verify-release-checksums.sh --checksums PATH ARTIFACT...

Verifies that a release checksum file contains a current SHA-256 line for each
required public release artifact.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --checksums)
            CHECKSUMS_PATH="${2:-}"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

if [[ -z "$CHECKSUMS_PATH" ]]; then
    echo "--checksums is required." >&2
    usage >&2
    exit 2
fi
if [[ $# -eq 0 ]]; then
    echo "At least one artifact path is required." >&2
    usage >&2
    exit 2
fi
if [[ ! -s "$CHECKSUMS_PATH" ]]; then
    echo "Checksum file is missing or empty: $CHECKSUMS_PATH" >&2
    exit 1
fi

is_expected_artifact() {
    local checksum_path="$1"
    shift

    local artifact_path=""
    for artifact_path in "$@"; do
        if [[ "$checksum_path" == "$artifact_path" ]]; then
            return 0
        fi
    done
    return 1
}

verify_no_unexpected_artifacts() {
    local line=""
    local line_path=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([0-9a-fA-F]{64})[[:space:]][[:space:]](.+)$ ]]; then
            line_path="${BASH_REMATCH[2]}"
            if ! is_expected_artifact "$line_path" "$@"; then
                echo "unexpected checksum line for artifact: $line_path" >&2
                exit 1
            fi
        fi
    done < "$CHECKSUMS_PATH"
}

verify_artifact() {
    local artifact_path="$1"
    local expected_sha=""
    local actual_sha=""
    local line=""
    local line_sha=""
    local line_path=""
    local matches=0
    local found=false

    if [[ ! -f "$artifact_path" ]]; then
        echo "Release artifact is missing: $artifact_path" >&2
        exit 1
    fi

    actual_sha="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([0-9a-fA-F]{64})[[:space:]][[:space:]](.+)$ ]]; then
            line_sha="${BASH_REMATCH[1]}"
            line_path="${BASH_REMATCH[2]}"
            if [[ "$line_path" == "$artifact_path" ]]; then
                matches=$((matches + 1))
                if (( matches > 1 )); then
                    echo "duplicate checksum line for artifact: $artifact_path" >&2
                    exit 1
                fi
                found=true
                expected_sha="$line_sha"
            fi
        fi
    done < "$CHECKSUMS_PATH"

    if [[ "$found" == "false" ]]; then
        echo "missing checksum line for artifact: $artifact_path" >&2
        exit 1
    fi
    if [[ "$expected_sha" != "$actual_sha" ]]; then
        echo "checksum mismatch for artifact: $artifact_path" >&2
        echo "expected: $expected_sha" >&2
        echo "actual:   $actual_sha" >&2
        exit 1
    fi
}

verify_no_unexpected_artifacts "$@"

for artifact in "$@"; do
    verify_artifact "$artifact"
done

echo "Release checksums verified: $CHECKSUMS_PATH"

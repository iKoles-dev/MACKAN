#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${1:-}"
ARTIFACT_MARKER="Verified release artifact:"
CHECKSUM_MARKER="Release checksums verified:"
SUMMARY_MARKER="Release summary verified:"
HANDOFF_MARKER="Public release handoff verified:"

usage() {
    cat <<USAGE
Usage: verify-release-log.sh LOG_PATH

Validates the captured release-dmg.sh transcript for public release handoff.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

require_single_marker() {
    local marker="$1"
    local missing_label="$2"
    local count
    count="$(grep -F -c "$marker" "$LOG_PATH" || true)"
    if [[ "$count" == "0" ]]; then
        fail "Release log missing $missing_label marker: $marker"
    fi
    if [[ "$count" != "1" ]]; then
        fail "Release log marker must appear exactly once: $marker"
    fi
}

if [[ -z "$LOG_PATH" || "$LOG_PATH" == "--help" || "$LOG_PATH" == "-h" ]]; then
    usage >&2
    [[ -n "$LOG_PATH" ]] && exit 0
    exit 2
fi

[[ -f "$LOG_PATH" ]] || fail "Release log not found: $LOG_PATH"
[[ -s "$LOG_PATH" ]] || fail "Release log is empty: $LOG_PATH"

require_single_marker "$ARTIFACT_MARKER" "release artifact"
require_single_marker "$CHECKSUM_MARKER" "checksum"
require_single_marker "$SUMMARY_MARKER" "summary"
require_single_marker "$HANDOFF_MARKER" "handoff"

artifact_dmg_path="$(sed -nE "s|^${ARTIFACT_MARKER//\//\\/} (.+)$|\\1|p" "$LOG_PATH" | tail -n 1)"
checksum_path="$(sed -nE "s|^${CHECKSUM_MARKER//\//\\/} (.+)$|\\1|p" "$LOG_PATH" | tail -n 1)"
summary_path="$(sed -nE "s|^${SUMMARY_MARKER//\//\\/} (.+)$|\\1|p" "$LOG_PATH" | tail -n 1)"
handoff_dmg_path="$(sed -nE "s|^${HANDOFF_MARKER//\//\\/} (.+)$|\\1|p" "$LOG_PATH" | tail -n 1)"
final_dmg_count="$(grep -E -c '^/.+[.]dmg$' "$LOG_PATH" || true)"
if [[ "$final_dmg_count" != "1" ]]; then
    fail "Release log final DMG output must appear exactly once: $LOG_PATH"
fi
final_dmg_path="$(grep -E '^/.+[.]dmg$' "$LOG_PATH")"

if [[ -z "$artifact_dmg_path" || -z "$checksum_path" || -z "$summary_path" || -z "$handoff_dmg_path" || -z "$final_dmg_path" ]]; then
    fail "Release log missing parseable DMG path markers: $LOG_PATH"
fi

if [[ "$artifact_dmg_path" != "$handoff_dmg_path" || "$artifact_dmg_path" != "$final_dmg_path" ]]; then
    fail "Release log DMG paths do not match: artifact=$artifact_dmg_path handoff=$handoff_dmg_path final=$final_dmg_path"
fi

if [[ "$checksum_path" != "$artifact_dmg_path.sha256" ]]; then
    fail "Release log checksum path does not match DMG path: checksum=$checksum_path dmg=$artifact_dmg_path"
fi

if [[ "$summary_path" != "$artifact_dmg_path.release-summary.json" ]]; then
    fail "Release log summary path does not match DMG path: summary=$summary_path dmg=$artifact_dmg_path"
fi

echo "Release log verified: $LOG_PATH"

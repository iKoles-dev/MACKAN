#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_DIR=""

usage() {
    cat <<USAGE
Usage: verify-ui-ux-audit-evidence.sh EVIDENCE_DIR

Verifies a completed MACKAN real-app UI/UX audit evidence bundle. This is the
post-audit gate: run-ui-ux-audit.sh creates the bundle, then the visual audit
operator checks every mandatory item and this verifier rejects incomplete or
blocking-defect evidence.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

verify_png() {
    local label="$1"
    local path="$2"
    local signature
    signature="$(LC_ALL=C od -An -N8 -tx1 -v "$path" | tr -d ' \n')"
    if [[ "$signature" != "89504e470d0a1a0a" ]]; then
        fail "$label screenshot is not a PNG: $path"
    fi
}

json_value() {
    local json_path="$1"
    local key_path="$2"
    /usr/bin/plutil -extract "$key_path" raw -o - "$json_path" 2>/dev/null || true
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -n "$EVIDENCE_DIR" ]]; then
                echo "Unexpected extra argument: $1" >&2
                usage >&2
                exit 2
            fi
            EVIDENCE_DIR="$1"
            shift
            ;;
    esac
done

if [[ -z "$EVIDENCE_DIR" ]]; then
    usage >&2
    exit 2
fi

[[ -d "$EVIDENCE_DIR" ]] || fail "UI/UX audit evidence directory not found: $EVIDENCE_DIR"

launch_log="$EVIDENCE_DIR/launch-smoke.txt"
screenshot_path="$EVIDENCE_DIR/main-window.png"
adaptive_minimum_path="$EVIDENCE_DIR/adaptive-minimum.png"
adaptive_medium_path="$EVIDENCE_DIR/adaptive-medium.png"
adaptive_wide_path="$EVIDENCE_DIR/adaptive-wide.png"
window_summary_path="$EVIDENCE_DIR/window-summary.txt"
checklist_path="$EVIDENCE_DIR/ui-ux-audit.md"
metadata_path="$EVIDENCE_DIR/audit-metadata.json"

[[ -s "$launch_log" ]] || fail "Launch evidence missing or empty: $launch_log"
[[ -s "$screenshot_path" ]] || fail "Main screenshot missing or empty: $screenshot_path"
[[ -s "$adaptive_minimum_path" ]] || fail "Adaptive minimum screenshot missing or empty: $adaptive_minimum_path"
[[ -s "$adaptive_medium_path" ]] || fail "Adaptive medium screenshot missing or empty: $adaptive_medium_path"
[[ -s "$adaptive_wide_path" ]] || fail "Adaptive wide screenshot missing or empty: $adaptive_wide_path"
[[ -s "$window_summary_path" ]] || fail "Window summary missing or empty: $window_summary_path"
[[ -s "$checklist_path" ]] || fail "UI/UX audit checklist missing or empty: $checklist_path"
[[ -s "$metadata_path" ]] || fail "UI/UX audit metadata missing or empty: $metadata_path"

verify_png "Main" "$screenshot_path"
verify_png "Adaptive minimum" "$adaptive_minimum_path"
verify_png "Adaptive medium" "$adaptive_medium_path"
verify_png "Adaptive wide" "$adaptive_wide_path"

if ! grep -F -- "- Launch evidence: \`$launch_log\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist launch evidence path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Audit metadata: \`$metadata_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist metadata path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Main screenshot: \`$screenshot_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist main screenshot path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Adaptive minimum screenshot: \`$adaptive_minimum_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist adaptive minimum screenshot path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Adaptive medium screenshot: \`$adaptive_medium_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist adaptive medium screenshot path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Adaptive wide screenshot: \`$adaptive_wide_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist adaptive wide screenshot path does not match evidence file: $checklist_path"
fi
if ! grep -F -- "- Window summary: \`$window_summary_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit checklist window summary path does not match evidence file: $checklist_path"
fi

if ! /usr/bin/plutil -convert json -o /dev/null "$metadata_path" >/dev/null 2>&1; then
    fail "UI/UX audit metadata is not parseable JSON: $metadata_path"
fi

schema_version="$(json_value "$metadata_path" "schemaVersion")"
if [[ "$schema_version" != "1" ]]; then
    fail "UI/UX audit metadata schemaVersion must be 1: $metadata_path"
fi

captured_at_utc="$(json_value "$metadata_path" "capturedAtUtc")"
if [[ ! "$captured_at_utc" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    fail "UI/UX audit metadata capturedAtUtc must be an ISO-8601 UTC timestamp: $metadata_path"
fi
if ! grep -F -- "- Captured at UTC: \`$captured_at_utc\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit metadata capturedAtUtc does not match checklist timestamp: $metadata_path"
fi

metadata_app_path="$(json_value "$metadata_path" "appPath")"
if [[ -z "$metadata_app_path" || "$metadata_app_path" != *.app ]]; then
    fail "UI/UX audit metadata appPath must point to a .app bundle: $metadata_path"
fi
if ! grep -F -- "- App: \`$metadata_app_path\`" "$checklist_path" >/dev/null; then
    fail "UI/UX audit metadata appPath does not match checklist app: $metadata_path"
fi

main_screenshot_name="$(json_value "$metadata_path" "screenshots.main")"
minimum_screenshot_name="$(json_value "$metadata_path" "screenshots.adaptiveMinimum.path")"
medium_screenshot_name="$(json_value "$metadata_path" "screenshots.adaptiveMedium.path")"
wide_screenshot_name="$(json_value "$metadata_path" "screenshots.adaptiveWide.path")"
[[ "$main_screenshot_name" == "main-window.png" ]] || fail "UI/UX audit metadata main screenshot path mismatch: $metadata_path"
[[ "$minimum_screenshot_name" == "adaptive-minimum.png" ]] || fail "UI/UX audit metadata adaptive minimum screenshot path mismatch: $metadata_path"
[[ "$medium_screenshot_name" == "adaptive-medium.png" ]] || fail "UI/UX audit metadata adaptive medium screenshot path mismatch: $metadata_path"
[[ "$wide_screenshot_name" == "adaptive-wide.png" ]] || fail "UI/UX audit metadata adaptive wide screenshot path mismatch: $metadata_path"

[[ "$(json_value "$metadata_path" "screenshots.adaptiveMinimum.width")" == "760" ]] || fail "UI/UX audit metadata adaptive minimum width mismatch: $metadata_path"
[[ "$(json_value "$metadata_path" "screenshots.adaptiveMinimum.height")" == "620" ]] || fail "UI/UX audit metadata adaptive minimum height mismatch: $metadata_path"
[[ "$(json_value "$metadata_path" "screenshots.adaptiveMedium.width")" == "1000" ]] || fail "UI/UX audit metadata adaptive medium width mismatch: $metadata_path"
[[ "$(json_value "$metadata_path" "screenshots.adaptiveMedium.height")" == "700" ]] || fail "UI/UX audit metadata adaptive medium height mismatch: $metadata_path"
[[ "$(json_value "$metadata_path" "screenshots.adaptiveWide.width")" == "1280" ]] || fail "UI/UX audit metadata adaptive wide width mismatch: $metadata_path"
[[ "$(json_value "$metadata_path" "screenshots.adaptiveWide.height")" == "820" ]] || fail "UI/UX audit metadata adaptive wide height mismatch: $metadata_path"

launch_pid="$(sed -nE 's/.*\(pid ([0-9]+), windows [0-9]+\).*/\1/p' "$launch_log" | head -n 1)"
if [[ -z "$launch_pid" ]]; then
    fail "Launch evidence did not include a MACKAN PID: $launch_log"
fi
metadata_launch_pid="$(json_value "$metadata_path" "launchPid")"
if [[ "$metadata_launch_pid" != "$launch_pid" ]]; then
    fail "UI/UX audit metadata launchPid does not match launch evidence: $metadata_path"
fi
launch_window_count="$(sed -nE 's/.*\(pid [0-9]+, windows ([0-9]+)\).*/\1/p' "$launch_log" | head -n 1)"
if [[ -z "$launch_window_count" || "$launch_window_count" == "0" ]]; then
    fail "Launch evidence did not report a visible MACKAN window: $launch_log"
fi

window_count="$(sed -nE 's/^MACKAN window count: ([0-9]+)$/\1/p' "$window_summary_path" | head -n 1)"
if [[ -z "$window_count" || "$window_count" == "0" ]]; then
    fail "Window summary did not report a visible MACKAN window: $window_summary_path"
fi
window_pid="$(sed -nE 's/^MACKAN process pid: ([0-9]+)$/\1/p' "$window_summary_path" | head -n 1)"
if [[ -z "$window_pid" ]]; then
    fail "Window summary did not include a MACKAN process PID: $window_summary_path"
fi
if [[ "$window_pid" != "$launch_pid" ]]; then
    fail "Window summary PID does not match launch PID: $window_summary_path"
fi

awk '
    /^## Mandatory Pass Checklist$/ {
        in_mandatory = 1
        next
    }
    /^## / && in_mandatory {
        in_mandatory = 0
    }
    in_mandatory && /^- \[[[:space:]]\]/ {
        print
        exit 1
    }
' "$checklist_path" >/tmp/mackan-ui-ux-unchecked.$$ || {
    unchecked_item="$(cat /tmp/mackan-ui-ux-unchecked.$$)"
    rm -f /tmp/mackan-ui-ux-unchecked.$$
    fail "Mandatory UI/UX checklist item is not checked: $unchecked_item"
}
rm -f /tmp/mackan-ui-ux-unchecked.$$

required_checklist_items=(
    "Instances:"
    "Repositories:"
    "Catalog:"
    "Change set:"
    "Operations:"
    "Maintenance:"
    "Settings:"
    "Help/About/Updates:"
    "Adaptive layout:"
    "Long content:"
    "Accessibility:"
)

for item in "${required_checklist_items[@]}"; do
    if ! grep -E "^- \\[[xX]\\] ${item}" "$checklist_path" >/dev/null; then
        fail "Mandatory UI/UX checklist item is missing: $item"
    fi
done

if ! grep -E '^- \[[xX]\] No blocking defects found\.$' "$checklist_path" >/dev/null; then
    fail "No-blocking-defects confirmation is not checked: $checklist_path"
fi

if grep -E '^- \[[xX]\] Blocking defects recorded with screenshot path, reproduction steps, and fix owner\.$' "$checklist_path" >/dev/null; then
    fail "Blocking defects are recorded in the UI/UX audit checklist: $checklist_path"
fi

echo "UI/UX audit evidence verified: $EVIDENCE_DIR"

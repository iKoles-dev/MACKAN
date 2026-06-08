#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-ui-ux-audit-evidence.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-ui-audit-evidence-test.XXXXXX")"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

write_png_placeholder() {
    local path="$1"
    printf '\x89PNG\r\n\x1a\nfake png payload\n' > "$path"
}

write_valid_evidence() {
    local dir="$1"
    mkdir -p "$dir"
    printf 'Verified GUI launch without Terminal and with visible window: MACKAN.app (pid 4242, windows 1)\n' > "$dir/launch-smoke.txt"
    write_png_placeholder "$dir/main-window.png"
    write_png_placeholder "$dir/adaptive-minimum.png"
    write_png_placeholder "$dir/adaptive-medium.png"
    write_png_placeholder "$dir/adaptive-wide.png"
    printf 'MACKAN process pid: 4242\nMACKAN window count: 1\n' > "$dir/window-summary.txt"
    cat > "$dir/audit-metadata.json" <<'JSON'
{
  "schemaVersion": 1,
  "appPath": "/Applications/MACKAN.app",
  "capturedAtUtc": "2026-06-01T12:00:00Z",
  "launchPid": 4242,
  "screenshots": {
    "main": "main-window.png",
    "adaptiveMinimum": {
      "path": "adaptive-minimum.png",
      "width": 760,
      "height": 620
    },
    "adaptiveMedium": {
      "path": "adaptive-medium.png",
      "width": 1000,
      "height": 700
    },
    "adaptiveWide": {
      "path": "adaptive-wide.png",
      "width": 1280,
      "height": 820
    }
  }
}
JSON
    cat > "$dir/ui-ux-audit.md" <<MD
# MACKAN Real-App UI/UX Audit

- App: \`/Applications/MACKAN.app\`
- Captured at UTC: \`2026-06-01T12:00:00Z\`
- Launch evidence: \`$dir/launch-smoke.txt\`
- Audit metadata: \`$dir/audit-metadata.json\`
- Main screenshot: \`$dir/main-window.png\`
- Adaptive minimum screenshot: \`$dir/adaptive-minimum.png\`
- Adaptive medium screenshot: \`$dir/adaptive-medium.png\`
- Adaptive wide screenshot: \`$dir/adaptive-wide.png\`
- Window summary: \`$dir/window-summary.txt\`

## Mandatory Pass Checklist

- [x] Instances: add, clone, fake, rename, forget, set default, reveal folder, launch warnings.
- [x] Repositories: add, remove, reorder, refresh, recover from refresh failure.
- [x] Catalog: search syntax, filters, tags, labels, saved searches, columns, sort, details inspector.
- [x] Change set: preview, provider choices, recommendations, conflicts, apply, clear, retry.
- [x] Operations: progress, cancellation, download failures, registry lock recovery, diagnostics copy.
- [x] Maintenance: unmanaged files, history, play time, download statistics, cache, deduplicate, repair.
- [x] Settings: General, Compatibility, Stability, Auth Tokens, Install Filters, Launch, Repositories, Cache.
- [x] Help/About/Updates: about sheet, update check, help links, diagnostics.
- [x] Adaptive layout: minimum, medium, and wide windows; sidebar/inspector hidden and visible states.
- [x] Long content: long paths, long module names, long repository names, empty/loading/error states.
- [x] Accessibility: keyboard focus path, VoiceOver labels, default/cancel actions, menu shortcuts.

## Defects

- [x] No blocking defects found.
- [ ] Blocking defects recorded with screenshot path, reproduction steps, and fix owner.
MD
}

assert_fails_with() {
    local expected="$1"
    shift
    local log="$WORK_DIR/failure-$(date +%s%N).log"
    if "$@" 2>"$log"; then
        echo "Expected command to fail: $*" >&2
        exit 1
    fi
    grep -F "$expected" "$log" >/dev/null || {
        echo "Expected failure to contain: $expected" >&2
        cat "$log" >&2
        exit 1
    }
}

VALID_DIR="$WORK_DIR/valid"
write_valid_evidence "$VALID_DIR"
SUCCESS_OUTPUT="$("$VERIFY_SCRIPT" "$VALID_DIR")"
[[ "$SUCCESS_OUTPUT" == *"UI/UX audit evidence verified:"* ]] || {
    echo "Expected verifier success output." >&2
    echo "$SUCCESS_OUTPUT" >&2
    exit 1
}

MISSING_SCREENSHOT_DIR="$WORK_DIR/missing-screenshot"
write_valid_evidence "$MISSING_SCREENSHOT_DIR"
rm "$MISSING_SCREENSHOT_DIR/main-window.png"
assert_fails_with "Main screenshot missing or empty" "$VERIFY_SCRIPT" "$MISSING_SCREENSHOT_DIR"

MISSING_METADATA_DIR="$WORK_DIR/missing-metadata"
write_valid_evidence "$MISSING_METADATA_DIR"
rm "$MISSING_METADATA_DIR/audit-metadata.json"
assert_fails_with "UI/UX audit metadata missing or empty" "$VERIFY_SCRIPT" "$MISSING_METADATA_DIR"

MISMATCHED_METADATA_APP_DIR="$WORK_DIR/mismatched-metadata-app"
write_valid_evidence "$MISMATCHED_METADATA_APP_DIR"
perl -0pi -e 's#/Applications/MACKAN\.app#/Applications/Other.app#' "$MISMATCHED_METADATA_APP_DIR/audit-metadata.json"
assert_fails_with "UI/UX audit metadata appPath does not match checklist app" "$VERIFY_SCRIPT" "$MISMATCHED_METADATA_APP_DIR"

MISMATCHED_METADATA_TIMESTAMP_DIR="$WORK_DIR/mismatched-metadata-timestamp"
write_valid_evidence "$MISMATCHED_METADATA_TIMESTAMP_DIR"
perl -0pi -e 's/2026-06-01T12:00:00Z/2026-06-01T12:05:00Z/' "$MISMATCHED_METADATA_TIMESTAMP_DIR/audit-metadata.json"
assert_fails_with "UI/UX audit metadata capturedAtUtc does not match checklist timestamp" "$VERIFY_SCRIPT" "$MISMATCHED_METADATA_TIMESTAMP_DIR"

MISMATCHED_CHECKLIST_SCREENSHOT_DIR="$WORK_DIR/mismatched-checklist-screenshot"
write_valid_evidence "$MISMATCHED_CHECKLIST_SCREENSHOT_DIR"
perl -0pi -e 's#main-window[.]png#other-main-window.png#' "$MISMATCHED_CHECKLIST_SCREENSHOT_DIR/ui-ux-audit.md"
assert_fails_with "UI/UX audit checklist main screenshot path does not match evidence file" "$VERIFY_SCRIPT" "$MISMATCHED_CHECKLIST_SCREENSHOT_DIR"

MISMATCHED_CHECKLIST_LAUNCH_DIR="$WORK_DIR/mismatched-checklist-launch"
write_valid_evidence "$MISMATCHED_CHECKLIST_LAUNCH_DIR"
perl -0pi -e 's#launch-smoke[.]txt#other-launch-smoke.txt#' "$MISMATCHED_CHECKLIST_LAUNCH_DIR/ui-ux-audit.md"
assert_fails_with "UI/UX audit checklist launch evidence path does not match evidence file" "$VERIFY_SCRIPT" "$MISMATCHED_CHECKLIST_LAUNCH_DIR"

MISSING_LAUNCH_PID_DIR="$WORK_DIR/missing-launch-pid"
write_valid_evidence "$MISSING_LAUNCH_PID_DIR"
printf 'Verified GUI launch without Terminal and with visible window: MACKAN.app\n' > "$MISSING_LAUNCH_PID_DIR/launch-smoke.txt"
assert_fails_with "Launch evidence did not include a MACKAN PID" "$VERIFY_SCRIPT" "$MISSING_LAUNCH_PID_DIR"

ZERO_LAUNCH_WINDOW_DIR="$WORK_DIR/zero-launch-window"
write_valid_evidence "$ZERO_LAUNCH_WINDOW_DIR"
printf 'Verified GUI launch without Terminal and with visible window: MACKAN.app (pid 4242, windows 0)\n' > "$ZERO_LAUNCH_WINDOW_DIR/launch-smoke.txt"
assert_fails_with "Launch evidence did not report a visible MACKAN window" "$VERIFY_SCRIPT" "$ZERO_LAUNCH_WINDOW_DIR"

MISSING_ADAPTIVE_SCREENSHOT_DIR="$WORK_DIR/missing-adaptive-screenshot"
write_valid_evidence "$MISSING_ADAPTIVE_SCREENSHOT_DIR"
rm "$MISSING_ADAPTIVE_SCREENSHOT_DIR/adaptive-medium.png"
assert_fails_with "Adaptive medium screenshot missing or empty" "$VERIFY_SCRIPT" "$MISSING_ADAPTIVE_SCREENSHOT_DIR"

CORRUPT_SCREENSHOT_DIR="$WORK_DIR/corrupt-screenshot"
write_valid_evidence "$CORRUPT_SCREENSHOT_DIR"
printf 'not a png\n' > "$CORRUPT_SCREENSHOT_DIR/adaptive-wide.png"
assert_fails_with "Adaptive wide screenshot is not a PNG" "$VERIFY_SCRIPT" "$CORRUPT_SCREENSHOT_DIR"

ZERO_WINDOW_DIR="$WORK_DIR/zero-window"
write_valid_evidence "$ZERO_WINDOW_DIR"
printf 'MACKAN process pid: 4242\nMACKAN window count: 0\n' > "$ZERO_WINDOW_DIR/window-summary.txt"
assert_fails_with "Window summary did not report a visible MACKAN window" "$VERIFY_SCRIPT" "$ZERO_WINDOW_DIR"

MISMATCHED_WINDOW_PID_DIR="$WORK_DIR/mismatched-window-pid"
write_valid_evidence "$MISMATCHED_WINDOW_PID_DIR"
printf 'MACKAN process pid: 9999\nMACKAN window count: 1\n' > "$MISMATCHED_WINDOW_PID_DIR/window-summary.txt"
assert_fails_with "Window summary PID does not match launch PID" "$VERIFY_SCRIPT" "$MISMATCHED_WINDOW_PID_DIR"

UNCHECKED_DIR="$WORK_DIR/unchecked"
write_valid_evidence "$UNCHECKED_DIR"
perl -0pi -e 's/- \[x\] Catalog:/- [ ] Catalog:/' "$UNCHECKED_DIR/ui-ux-audit.md"
assert_fails_with "Mandatory UI/UX checklist item is not checked" "$VERIFY_SCRIPT" "$UNCHECKED_DIR"

MISSING_REQUIRED_ITEM_DIR="$WORK_DIR/missing-required-item"
write_valid_evidence "$MISSING_REQUIRED_ITEM_DIR"
perl -0pi -e 's/- \[x\] Catalog: search syntax, filters, tags, labels, saved searches, columns, sort, details inspector\.\n//' "$MISSING_REQUIRED_ITEM_DIR/ui-ux-audit.md"
assert_fails_with "Mandatory UI/UX checklist item is missing: Catalog:" "$VERIFY_SCRIPT" "$MISSING_REQUIRED_ITEM_DIR"

BLOCKING_DEFECT_DIR="$WORK_DIR/blocking-defect"
write_valid_evidence "$BLOCKING_DEFECT_DIR"
perl -0pi -e 's/- \[ \] Blocking defects recorded/- [x] Blocking defects recorded/' "$BLOCKING_DEFECT_DIR/ui-ux-audit.md"
assert_fails_with "Blocking defects are recorded" "$VERIFY_SCRIPT" "$BLOCKING_DEFECT_DIR"

NO_CLEAR_DEFECT_DIR="$WORK_DIR/no-clear-defect"
write_valid_evidence "$NO_CLEAR_DEFECT_DIR"
perl -0pi -e 's/- \[x\] No blocking defects found/- [ ] No blocking defects found/' "$NO_CLEAR_DEFECT_DIR/ui-ux-audit.md"
assert_fails_with "No-blocking-defects confirmation is not checked" "$VERIFY_SCRIPT" "$NO_CLEAR_DEFECT_DIR"

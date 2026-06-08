#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/run-ui-ux-audit.sh"
AUDIT_SCRIPT_CONTENTS="$(cat "$AUDIT_SCRIPT")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-ui-audit-test.XXXXXX")"
APP_DIR="$WORK_DIR/MACKAN.app"
OUTPUT_DIR="$WORK_DIR/evidence"
ERROR_LOG="$WORK_DIR/error.log"
export MACKAN_UI_AUDIT_CATALOG_READY_TIMEOUT_SECONDS=0

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS"
printf '#!/usr/bin/env bash\nsleep 1\n' > "$APP_DIR/Contents/MacOS/MACKAN"
chmod +x "$APP_DIR/Contents/MacOS/MACKAN"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.audit-test</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

if [[ "$AUDIT_SCRIPT_CONTENTS" != *"set position of window 1"* || "$AUDIT_SCRIPT_CONTENTS" != *"set size of window 1"* ]]; then
    echo "Expected audit runner to fall back from bounds-based resize to position/size resize." >&2
    exit 1
fi
if [[ "$AUDIT_SCRIPT_CONTENTS" != *"--wait-catalog"* ]]; then
    echo "Expected audit runner to expose a catalog-ready wait option for public-RC screenshots." >&2
    exit 1
fi

if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=Yes \
    "$AUDIT_SCRIPT" --output "$OUTPUT_DIR" "$APP_DIR" 2>"$ERROR_LOG"; then
    echo "Expected UI/UX audit runner to fail clearly when the desktop is locked." >&2
    exit 1
fi
grep -F "desktop is locked" "$ERROR_LOG" >/dev/null

FAKE_VERIFY="$WORK_DIR/verify-app-launch"
cat > "$FAKE_VERIFY" <<'SH'
#!/usr/bin/env bash
if [[ "$1" != "--keep-running" ]]; then
    echo "expected --keep-running before audit screenshots" >&2
    exit 64
fi
printf 'Verified GUI launch without Terminal and with visible window: %s (pid 4242, windows 1)\n' "${@: -1}"
SH
chmod +x "$FAKE_VERIFY"

FAKE_VERIFY_WITHOUT_PID="$WORK_DIR/verify-app-launch-without-pid"
cat > "$FAKE_VERIFY_WITHOUT_PID" <<'SH'
#!/usr/bin/env bash
if [[ "$1" != "--keep-running" ]]; then
    echo "expected --keep-running before audit screenshots" >&2
    exit 64
fi
printf 'Verified GUI launch without Terminal and with visible window: %s\n' "${@: -1}"
SH
chmod +x "$FAKE_VERIFY_WITHOUT_PID"

FAKE_SCREENSHOT="$WORK_DIR/screencapture"
cat > "$FAKE_SCREENSHOT" <<'SH'
#!/usr/bin/env bash
printf 'fake screenshot\n' > "${@: -1}"
SH
chmod +x "$FAKE_SCREENSHOT"

FAKE_WINDOW_BOUNDS="$WORK_DIR/set-window-bounds"
cat > "$FAKE_WINDOW_BOUNDS" <<'SH'
#!/usr/bin/env bash
printf '%s %s %s\n' "$1" "$2" "$3" >> "${MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG:?}"
SH
chmod +x "$FAKE_WINDOW_BOUNDS"
WINDOW_BOUNDS_LOG="$WORK_DIR/window-bounds.log"

FAKE_SLEEP="$WORK_DIR/sleep"
cat > "$FAKE_SLEEP" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "${MACKAN_UI_AUDIT_SLEEP_LOG:?}"
SH
chmod +x "$FAKE_SLEEP"
SLEEP_LOG="$WORK_DIR/sleep.log"

FAKE_QUIT="$WORK_DIR/quit-launched-app"
cat > "$FAKE_QUIT" <<'SH'
#!/usr/bin/env bash
printf '%s %s\n' "$1" "$2" >> "${MACKAN_UI_AUDIT_QUIT_LOG:?}"
SH
chmod +x "$FAKE_QUIT"
QUIT_LOG="$WORK_DIR/quit.log"

SUCCESS_OUTPUT="$(MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_SLEEP_TOOL="$FAKE_SLEEP" \
    MACKAN_UI_AUDIT_SLEEP_LOG="$SLEEP_LOG" \
    MACKAN_UI_AUDIT_SETTLE_SECONDS=0.01 \
    MACKAN_UI_AUDIT_QUIT_TOOL="$FAKE_QUIT" \
    MACKAN_UI_AUDIT_QUIT_LOG="$QUIT_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    "$AUDIT_SCRIPT" --output "$OUTPUT_DIR" --timeout 1 "$APP_DIR")"

[[ "$SUCCESS_OUTPUT" == *"UI/UX audit evidence"* ]] || {
    echo "Expected success output to mention UI/UX audit evidence." >&2
    echo "$SUCCESS_OUTPUT" >&2
    exit 1
}

[[ -f "$OUTPUT_DIR/main-window.png" ]] || {
    echo "Expected audit runner to capture main-window.png." >&2
    exit 1
}
[[ -s "$OUTPUT_DIR/main-window.png" ]] || {
    echo "Expected audit runner to capture a non-empty main-window.png." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/adaptive-minimum.png" ]] || {
    echo "Expected audit runner to capture adaptive-minimum.png." >&2
    exit 1
}
[[ -s "$OUTPUT_DIR/adaptive-minimum.png" ]] || {
    echo "Expected audit runner to capture a non-empty adaptive-minimum.png." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/adaptive-medium.png" ]] || {
    echo "Expected audit runner to capture adaptive-medium.png." >&2
    exit 1
}
[[ -s "$OUTPUT_DIR/adaptive-medium.png" ]] || {
    echo "Expected audit runner to capture a non-empty adaptive-medium.png." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/adaptive-wide.png" ]] || {
    echo "Expected audit runner to capture adaptive-wide.png." >&2
    exit 1
}
[[ -s "$OUTPUT_DIR/adaptive-wide.png" ]] || {
    echo "Expected audit runner to capture a non-empty adaptive-wide.png." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/ui-ux-audit.md" ]] || {
    echo "Expected audit runner to write ui-ux-audit.md." >&2
    exit 1
}
[[ -f "$OUTPUT_DIR/audit-metadata.json" ]] || {
    echo "Expected audit runner to write audit-metadata.json." >&2
    exit 1
}

grep -F "$APP_DIR" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F '"schemaVersion": 1' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F "\"appPath\": \"$APP_DIR\"" "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"launchPid": 4242' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"capturedAtUtc": "' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"width": 760' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"height": 620' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"width": 1000' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"height": 700' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"width": 1280' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F '"height": 820' "$OUTPUT_DIR/audit-metadata.json" >/dev/null
grep -F "MACKAN process pid: 4242" "$OUTPUT_DIR/window-summary.txt" >/dev/null
grep -F "MACKAN window count: 1" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "Instances" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "Repositories" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "Catalog" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "Settings" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "adaptive-minimum.png" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "adaptive-medium.png" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "adaptive-wide.png" "$OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F "MACKAN 760 620" "$WINDOW_BOUNDS_LOG" >/dev/null
grep -F "MACKAN 1000 700" "$WINDOW_BOUNDS_LOG" >/dev/null
grep -F "MACKAN 1280 820" "$WINDOW_BOUNDS_LOG" >/dev/null
[[ "$(grep -c '^0[.]01$' "$SLEEP_LOG")" == "4" ]] || {
    echo "Expected audit runner to wait for launch and resize layout settle before screenshots." >&2
    cat "$SLEEP_LOG" >&2
    exit 1
}
grep -F "MACKAN 4242" "$QUIT_LOG" >/dev/null

MISSING_PID_OUTPUT="$WORK_DIR/missing-pid-evidence"
MISSING_PID_LOG="$WORK_DIR/missing-pid.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY_WITHOUT_PID" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_QUIT_TOOL="$FAKE_QUIT" \
    MACKAN_UI_AUDIT_QUIT_LOG="$QUIT_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    "$AUDIT_SCRIPT" --output "$MISSING_PID_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$MISSING_PID_LOG"; then
    echo "Expected UI/UX audit runner to fail when launch evidence has no PID." >&2
    exit 1
fi
grep -F "launch evidence did not include a MACKAN PID" "$MISSING_PID_LOG" >/dev/null

ZERO_WINDOW_OUTPUT="$WORK_DIR/zero-window-evidence"
ZERO_WINDOW_LOG="$WORK_DIR/zero-window.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 0" \
    "$AUDIT_SCRIPT" --output "$ZERO_WINDOW_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$ZERO_WINDOW_LOG"; then
    echo "Expected UI/UX audit runner to fail when no app windows are visible." >&2
    exit 1
fi
grep -F "no visible MACKAN windows" "$ZERO_WINDOW_LOG" >/dev/null

EMPTY_WINDOW_OUTPUT="$WORK_DIR/empty-window-evidence"
EMPTY_WINDOW_LOG="$WORK_DIR/empty-window.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="" \
    "$AUDIT_SCRIPT" --output "$EMPTY_WINDOW_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$EMPTY_WINDOW_LOG"; then
    echo "Expected UI/UX audit runner to fail when the window summary is empty." >&2
    exit 1
fi
grep -F "window summary did not report a MACKAN window count" "$EMPTY_WINDOW_LOG" >/dev/null

INVALID_WINDOW_OUTPUT="$WORK_DIR/invalid-window-evidence"
INVALID_WINDOW_LOG="$WORK_DIR/invalid-window.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN windows unknown" \
    "$AUDIT_SCRIPT" --output "$INVALID_WINDOW_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$INVALID_WINDOW_LOG"; then
    echo "Expected UI/UX audit runner to fail when the window summary is invalid." >&2
    exit 1
fi
grep -F "window summary did not report a MACKAN window count" "$INVALID_WINDOW_LOG" >/dev/null

EMPTY_SCREENSHOT="$WORK_DIR/empty-screencapture"
cat > "$EMPTY_SCREENSHOT" <<'SH'
#!/usr/bin/env bash
: > "${@: -1}"
SH
chmod +x "$EMPTY_SCREENSHOT"

EMPTY_SCREENSHOT_OUTPUT="$WORK_DIR/empty-screenshot-evidence"
EMPTY_SCREENSHOT_LOG="$WORK_DIR/empty-screenshot.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$EMPTY_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    "$AUDIT_SCRIPT" --output "$EMPTY_SCREENSHOT_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$EMPTY_SCREENSHOT_LOG"; then
    echo "Expected UI/UX audit runner to fail when screenshot capture is empty." >&2
    exit 1
fi
grep -F "screenshot capture did not produce an image" "$EMPTY_SCREENSHOT_LOG" >/dev/null

FAILING_WINDOW_BOUNDS="$WORK_DIR/failing-window-bounds"
cat > "$FAILING_WINDOW_BOUNDS" <<'SH'
#!/usr/bin/env bash
if [[ "$2" == "1000" ]]; then
    echo "accessibility denied" >&2
    exit 42
fi
SH
chmod +x "$FAILING_WINDOW_BOUNDS"

RESIZE_FAILURE_OUTPUT="$WORK_DIR/resize-failure-evidence"
RESIZE_FAILURE_LOG="$WORK_DIR/resize-failure.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAILING_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    "$AUDIT_SCRIPT" --output "$RESIZE_FAILURE_OUTPUT" --timeout 1 "$APP_DIR" \
    2>"$RESIZE_FAILURE_LOG"; then
    echo "Expected UI/UX audit runner to fail clearly when adaptive resize fails." >&2
    exit 1
fi
grep -F "window resize failed for MACKAN at 1000x700" "$RESIZE_FAILURE_LOG" >/dev/null

CATALOG_READY_TOOL="$WORK_DIR/catalog-ready"
CATALOG_READY_LOG="$WORK_DIR/catalog-ready.log"
cat > "$CATALOG_READY_TOOL" <<'SH'
#!/usr/bin/env bash
count_file="${MACKAN_UI_AUDIT_CATALOG_READY_LOG:?}"
if [[ -f "$count_file" ]]; then
    count="$(wc -l < "$count_file" | tr -d '[:space:]')"
else
    count=0
fi
next_count=$((count + 1))
printf '%s %s\n' "$1" "$2" >> "$count_file"
if [[ "$next_count" -lt 3 ]]; then
    exit 1
fi
exit 0
SH
chmod +x "$CATALOG_READY_TOOL"

WAIT_OUTPUT_DIR="$WORK_DIR/catalog-wait-evidence"
WAIT_SLEEP_LOG="$WORK_DIR/catalog-wait-sleep.log"
WAIT_OUTPUT="$(MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_SLEEP_TOOL="$FAKE_SLEEP" \
    MACKAN_UI_AUDIT_SLEEP_LOG="$WAIT_SLEEP_LOG" \
    MACKAN_UI_AUDIT_SETTLE_SECONDS=0.01 \
    MACKAN_UI_AUDIT_QUIT_TOOL="$FAKE_QUIT" \
    MACKAN_UI_AUDIT_QUIT_LOG="$QUIT_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    MACKAN_UI_AUDIT_CATALOG_READY_TOOL="$CATALOG_READY_TOOL" \
    MACKAN_UI_AUDIT_CATALOG_READY_LOG="$CATALOG_READY_LOG" \
    "$AUDIT_SCRIPT" --output "$WAIT_OUTPUT_DIR" --timeout 1 --wait-catalog 3 "$APP_DIR")"
[[ "$WAIT_OUTPUT" == *"UI/UX audit evidence"* ]] || {
    echo "Expected catalog-wait audit run to succeed." >&2
    echo "$WAIT_OUTPUT" >&2
    exit 1
}
[[ "$(wc -l < "$CATALOG_READY_LOG" | tr -d '[:space:]')" == "3" ]] || {
    echo "Expected catalog-ready probe to run until it reports ready." >&2
    cat "$CATALOG_READY_LOG" >&2
    exit 1
}
grep -F -- "- Catalog ready wait: \`3 seconds\`" "$WAIT_OUTPUT_DIR/ui-ux-audit.md" >/dev/null
grep -F '"catalogReadyWaitSeconds": 3' "$WAIT_OUTPUT_DIR/audit-metadata.json" >/dev/null

CATALOG_UNKNOWN_OUTPUT="$WORK_DIR/catalog-unknown-evidence"
CATALOG_UNKNOWN_SLEEP_LOG="$WORK_DIR/catalog-unknown-sleep.log"
CATALOG_UNKNOWN_RUN_OUTPUT="$(MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_LOG="$WINDOW_BOUNDS_LOG" \
    MACKAN_UI_AUDIT_SLEEP_TOOL="$FAKE_SLEEP" \
    MACKAN_UI_AUDIT_SLEEP_LOG="$CATALOG_UNKNOWN_SLEEP_LOG" \
    MACKAN_UI_AUDIT_SETTLE_SECONDS=0.01 \
    MACKAN_UI_AUDIT_QUIT_TOOL="$FAKE_QUIT" \
    MACKAN_UI_AUDIT_QUIT_LOG="$QUIT_LOG" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    MACKAN_UI_AUDIT_CATALOG_READY_OUTPUT=unknown \
    "$AUDIT_SCRIPT" --output "$CATALOG_UNKNOWN_OUTPUT" --timeout 1 --wait-catalog 3 "$APP_DIR")"
[[ "$CATALOG_UNKNOWN_RUN_OUTPUT" == *"UI/UX audit evidence"* ]] || {
    echo "Expected catalog-unknown audit run to succeed after conservative wait." >&2
    echo "$CATALOG_UNKNOWN_RUN_OUTPUT" >&2
    exit 1
}
grep -F -- "- Catalog ready mode: \`inconclusive-wait\`" "$CATALOG_UNKNOWN_OUTPUT/ui-ux-audit.md" >/dev/null
grep -F '"catalogReadyMode": "inconclusive-wait"' "$CATALOG_UNKNOWN_OUTPUT/audit-metadata.json" >/dev/null
[[ "$(grep -c '^3$' "$CATALOG_UNKNOWN_SLEEP_LOG")" == "1" ]] || {
    echo "Expected inconclusive catalog readiness to wait the full requested duration once." >&2
    cat "$CATALOG_UNKNOWN_SLEEP_LOG" >&2
    exit 1
}

CATALOG_NEVER_READY_TOOL="$WORK_DIR/catalog-never-ready"
cat > "$CATALOG_NEVER_READY_TOOL" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$CATALOG_NEVER_READY_TOOL"

CATALOG_TIMEOUT_OUTPUT="$WORK_DIR/catalog-timeout-evidence"
CATALOG_TIMEOUT_LOG="$WORK_DIR/catalog-timeout.err"
if MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT="$FAKE_VERIFY" \
    MACKAN_UI_AUDIT_SCREENSHOT_TOOL="$FAKE_SCREENSHOT" \
    MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL="$FAKE_WINDOW_BOUNDS" \
    MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT="MACKAN window count: 1" \
    MACKAN_UI_AUDIT_CATALOG_READY_TOOL="$CATALOG_NEVER_READY_TOOL" \
    "$AUDIT_SCRIPT" --output "$CATALOG_TIMEOUT_OUTPUT" --timeout 1 --wait-catalog 2 "$APP_DIR" \
    2>"$CATALOG_TIMEOUT_LOG"; then
    echo "Expected UI/UX audit runner to fail when catalog loading never completes." >&2
    exit 1
fi
grep -F "catalog was still loading after 2 seconds" "$CATALOG_TIMEOUT_LOG" >/dev/null

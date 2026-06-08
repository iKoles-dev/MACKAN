#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_LAUNCH_SCRIPT="${MACKAN_UI_AUDIT_VERIFY_LAUNCH_SCRIPT:-$SCRIPT_DIR/verify-app-launch.sh}"
SCREENSHOT_TOOL="${MACKAN_UI_AUDIT_SCREENSHOT_TOOL:-/usr/sbin/screencapture}"
WINDOW_BOUNDS_TOOL="${MACKAN_UI_AUDIT_WINDOW_BOUNDS_TOOL:-}"
SLEEP_TOOL="${MACKAN_UI_AUDIT_SLEEP_TOOL:-/bin/sleep}"
SETTLE_SECONDS="${MACKAN_UI_AUDIT_SETTLE_SECONDS:-0.5}"
QUIT_TOOL="${MACKAN_UI_AUDIT_QUIT_TOOL:-}"
CATALOG_READY_TOOL="${MACKAN_UI_AUDIT_CATALOG_READY_TOOL:-}"
CATALOG_READY_TIMEOUT_SECONDS="${MACKAN_UI_AUDIT_CATALOG_READY_TIMEOUT_SECONDS:-60}"
TIMEOUT_SECONDS=25
APP_PATH=""
OUTPUT_DIR="${MACKAN_UI_AUDIT_OUTPUT_DIR:-}"
AUDIT_EXECUTABLE_NAME=""
AUDIT_APP_PID=""
CATALOG_READY_MODE="not-waited"

usage() {
    cat <<USAGE
Usage: run-ui-ux-audit.sh [--output DIR] [--timeout SECONDS] [--wait-catalog SECONDS] APP_PATH

Launches the built MACKAN.app, verifies that a visible native window appears,
captures a screenshot, and writes a real-app UI/UX audit evidence checklist.
This runner prepares evidence for the mandatory visual release gate; it does
not replace human/computer-use inspection of every listed control.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

cleanup() {
    if [[ -n "$QUIT_TOOL" && -n "$AUDIT_EXECUTABLE_NAME" && -n "$AUDIT_APP_PID" ]]; then
        "$QUIT_TOOL" "$AUDIT_EXECUTABLE_NAME" "$AUDIT_APP_PID" >/dev/null 2>&1 || true
        return
    fi

    if [[ -n "$AUDIT_APP_PID" ]] && kill -0 "$AUDIT_APP_PID" 2>/dev/null; then
        kill "$AUDIT_APP_PID" >/dev/null 2>&1 || true
        return
    fi

    if [[ -n "$AUDIT_EXECUTABLE_NAME" ]]; then
        osascript -e "tell application \"$AUDIT_EXECUTABLE_NAME\" to quit" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

console_locked() {
    if [[ -n "${MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT+x}" ]]; then
        printf '%s\n' "$MACKAN_UI_AUDIT_CONSOLE_LOCKED_OUTPUT"
        return 0
    fi

    ioreg -n Root -d1 2>/dev/null \
        | awk -F'= ' '
            /"IOConsoleLocked"/ && !found {
                gsub(/[ ";]/, "", $2)
                print $2
                found = 1
            }
            /"CGSSessionScreenIsLocked"/ && !found {
                gsub(/[ ";]/, "", $2)
                print $2
                found = 1
            }
            END {
                if (!found) {
                    print "No"
                }
            }'
}

window_summary() {
    local executable_name="$1"

    if [[ -n "${MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT+x}" ]]; then
        printf '%s\n' "$MACKAN_UI_AUDIT_WINDOW_SUMMARY_OUTPUT"
        return 0
    fi

    osascript <<OSA 2>/dev/null || true
tell application "System Events"
    if exists process "$executable_name" then
        tell process "$executable_name"
            set windowCount to count windows
            return "$executable_name window count: " & windowCount
        end tell
    end if
end tell
OSA
}

set_window_bounds() {
    local executable_name="$1"
    local width="$2"
    local height="$3"
    local resize_output

    if [[ -n "$WINDOW_BOUNDS_TOOL" ]]; then
        if ! resize_output="$("$WINDOW_BOUNDS_TOOL" "$executable_name" "$width" "$height" 2>&1)"; then
            fail "Cannot run real-app UI/UX audit because window resize failed for $executable_name at ${width}x${height}: $resize_output"
        fi
        return 0
    fi

    if ! resize_output="$(osascript <<OSA 2>&1 >/dev/null
tell application "System Events"
    if not (exists process "$executable_name") then error "MACKAN process is not running."
    tell process "$executable_name"
        if (count windows) is 0 then error "MACKAN has no windows."
        try
            set bounds of window 1 to {80, 80, 80 + $width, 80 + $height}
        on error
            set position of window 1 to {80, 80}
            set size of window 1 to {$width, $height}
        end try
    end tell
end tell
OSA
)"; then
        fail "Cannot run real-app UI/UX audit because window resize failed for $executable_name at ${width}x${height}: $resize_output"
    fi
}

capture_screenshot() {
    local output_path="$1"
    "$SCREENSHOT_TOOL" -x "$output_path"
    [[ -s "$output_path" ]] || fail "Cannot run real-app UI/UX audit because screenshot capture did not produce an image: $output_path"
}

settle_before_capture() {
    "$SLEEP_TOOL" "$SETTLE_SECONDS"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

catalog_readiness() {
    local executable_name="$1"

    if [[ -n "${MACKAN_UI_AUDIT_CATALOG_READY_OUTPUT+x}" ]]; then
        printf '%s\n' "$MACKAN_UI_AUDIT_CATALOG_READY_OUTPUT"
        return 0
    fi

    if [[ -n "$CATALOG_READY_TOOL" ]]; then
        if "$CATALOG_READY_TOOL" "$executable_name" "$AUDIT_APP_PID"; then
            printf 'ready\n'
        else
            printf 'loading\n'
        fi
        return 0
    fi

    osascript <<OSA 2>/dev/null || true
tell application "System Events"
    if not (exists process "$executable_name") then return "loading"
    tell process "$executable_name"
        if (count windows) is 0 then return "loading"
        set loadingFound to false
        set inspectedText to false
        repeat with itemRef in entire contents of window 1
            try
                set candidateTexts to {}
                try
                    set end of candidateTexts to (value of itemRef as text)
                end try
                try
                    set end of candidateTexts to (name of itemRef as text)
                end try
                try
                    set end of candidateTexts to (title of itemRef as text)
                end try
                try
                    set end of candidateTexts to (description of itemRef as text)
                end try
                repeat with candidateText in candidateTexts
                    if candidateText is not "" then set inspectedText to true
                    if candidateText contains "Loading catalog" then set loadingFound to true
                end repeat
                if loadingFound then
                    exit repeat
                end if
            end try
        end repeat
        if loadingFound then
            return "loading"
        else if inspectedText then
            return "ready"
        else
            return "unknown"
        end if
    end tell
end tell
OSA
}

wait_for_catalog_ready() {
    local executable_name="$1"
    local waited_seconds=0
    local readiness

    if [[ "$CATALOG_READY_TIMEOUT_SECONDS" -eq 0 ]]; then
        CATALOG_READY_MODE="disabled"
        return 0
    fi

    while [[ "$waited_seconds" -le "$CATALOG_READY_TIMEOUT_SECONDS" ]]; do
        readiness="$(catalog_readiness "$executable_name" | tail -n 1 | tr -d '[:space:]')"
        case "$readiness" in
            ready)
                CATALOG_READY_MODE="accessibility-ready"
                return 0
                ;;
            loading)
                ;;
            unknown)
                CATALOG_READY_MODE="inconclusive-wait"
                "$SLEEP_TOOL" "$CATALOG_READY_TIMEOUT_SECONDS"
                return 0
                ;;
            *)
                fail "Cannot run real-app UI/UX audit because catalog readiness probe returned unexpected status: $readiness"
                ;;
        esac
        if [[ "$waited_seconds" -eq "$CATALOG_READY_TIMEOUT_SECONDS" ]]; then
            break
        fi
        "$SLEEP_TOOL" 1
        waited_seconds=$((waited_seconds + 1))
    done

    fail "Cannot run real-app UI/UX audit because catalog was still loading after ${CATALOG_READY_TIMEOUT_SECONDS} seconds."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --wait-catalog)
            CATALOG_READY_TIMEOUT_SECONDS="$2"
            shift 2
            ;;
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
            if [[ -n "$APP_PATH" ]]; then
                echo "Unexpected extra argument: $1" >&2
                usage >&2
                exit 2
            fi
            APP_PATH="$1"
            shift
            ;;
    esac
done

[[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || fail "--timeout must be a positive integer."
[[ "$TIMEOUT_SECONDS" -gt 0 ]] || fail "--timeout must be greater than zero."
[[ "$CATALOG_READY_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || fail "--wait-catalog must be a non-negative integer."

if [[ -z "$APP_PATH" ]]; then
    usage >&2
    exit 2
fi

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"
[[ -x "$VERIFY_LAUNCH_SCRIPT" ]] || fail "Launch verifier is not executable: $VERIFY_LAUNCH_SCRIPT"
[[ -x "$SCREENSHOT_TOOL" ]] || fail "Screenshot tool is not executable: $SCREENSHOT_TOOL"
[[ -x "$SLEEP_TOOL" ]] || fail "Sleep tool is not executable: $SLEEP_TOOL"
[[ "$SETTLE_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "MACKAN_UI_AUDIT_SETTLE_SECONDS must be a non-negative number."
if [[ -n "$WINDOW_BOUNDS_TOOL" && ! -x "$WINDOW_BOUNDS_TOOL" ]]; then
    fail "Window bounds tool is not executable: $WINDOW_BOUNDS_TOOL"
fi
if [[ -n "$QUIT_TOOL" && ! -x "$QUIT_TOOL" ]]; then
    fail "Quit tool is not executable: $QUIT_TOOL"
fi
if [[ -n "$CATALOG_READY_TOOL" && ! -x "$CATALOG_READY_TOOL" ]]; then
    fail "Catalog-ready tool is not executable: $CATALOG_READY_TOOL"
fi

locked_state="$(console_locked | tr -d '[:space:]')"
if [[ "$locked_state" == "Yes" ]]; then
    fail "Cannot run real-app UI/UX audit because the macOS desktop is locked."
fi

info_plist="$APP_PATH/Contents/Info.plist"
[[ -f "$info_plist" ]] || fail "Info.plist missing: $info_plist"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist")"
[[ -n "$executable_name" ]] || fail "CFBundleExecutable is empty in $info_plist"
AUDIT_EXECUTABLE_NAME="$executable_name"

timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
captured_at_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="${TMPDIR:-/tmp}/mackan-ui-audit-$timestamp"
fi
mkdir -p "$OUTPUT_DIR"

launch_log="$OUTPUT_DIR/launch-smoke.txt"
screenshot_path="$OUTPUT_DIR/main-window.png"
adaptive_minimum_path="$OUTPUT_DIR/adaptive-minimum.png"
adaptive_medium_path="$OUTPUT_DIR/adaptive-medium.png"
adaptive_wide_path="$OUTPUT_DIR/adaptive-wide.png"
window_summary_path="$OUTPUT_DIR/window-summary.txt"
checklist_path="$OUTPUT_DIR/ui-ux-audit.md"
metadata_path="$OUTPUT_DIR/audit-metadata.json"

"$VERIFY_LAUNCH_SCRIPT" --keep-running --timeout "$TIMEOUT_SECONDS" "$APP_PATH" | tee "$launch_log" >/dev/null
AUDIT_APP_PID="$(sed -nE 's/.*\(pid ([0-9]+),.*/\1/p' "$launch_log" | head -n 1)"
[[ -n "$AUDIT_APP_PID" ]] || fail "Cannot run real-app UI/UX audit because launch evidence did not include a MACKAN PID: $launch_log"
wait_for_catalog_ready "$executable_name"
settle_before_capture
capture_screenshot "$screenshot_path"
set_window_bounds "$executable_name" 760 620
settle_before_capture
capture_screenshot "$adaptive_minimum_path"
set_window_bounds "$executable_name" 1000 700
settle_before_capture
capture_screenshot "$adaptive_medium_path"
set_window_bounds "$executable_name" 1280 820
settle_before_capture
capture_screenshot "$adaptive_wide_path"
cat > "$metadata_path" <<EOF
{
  "schemaVersion": 1,
  "appPath": "$(json_escape "$APP_PATH")",
  "capturedAtUtc": "$captured_at_utc",
  "launchPid": $AUDIT_APP_PID,
  "catalogReadyWaitSeconds": $CATALOG_READY_TIMEOUT_SECONDS,
  "catalogReadyMode": "$CATALOG_READY_MODE",
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
EOF
{
    printf '%s process pid: %s\n' "$executable_name" "$AUDIT_APP_PID"
    window_summary "$executable_name"
} > "$window_summary_path"

if ! grep -E "^${executable_name} window count: [0-9]+$" "$window_summary_path" >/dev/null 2>&1; then
    fail "Cannot run real-app UI/UX audit because the window summary did not report a MACKAN window count."
fi

if grep -E "^${executable_name} window count: 0$" "$window_summary_path" >/dev/null 2>&1; then
    fail "Cannot run real-app UI/UX audit because no visible MACKAN windows were detected."
fi

cat > "$checklist_path" <<EOF
# MACKAN Real-App UI/UX Audit

- App: \`$APP_PATH\`
- Captured at UTC: \`$captured_at_utc\`
- Catalog ready wait: \`$CATALOG_READY_TIMEOUT_SECONDS seconds\`
- Catalog ready mode: \`$CATALOG_READY_MODE\`
- Launch evidence: \`$launch_log\`
- Audit metadata: \`$metadata_path\`
- Main screenshot: \`$screenshot_path\`
- Adaptive minimum screenshot: \`$adaptive_minimum_path\`
- Adaptive medium screenshot: \`$adaptive_medium_path\`
- Adaptive wide screenshot: \`$adaptive_wide_path\`
- Window summary: \`$window_summary_path\`

## Window Summary

\`\`\`
$(cat "$window_summary_path")
\`\`\`

## Mandatory Pass Checklist

- Required adaptive screenshots before post-audit verification:
  - \`$OUTPUT_DIR/adaptive-minimum.png\`
  - \`$OUTPUT_DIR/adaptive-medium.png\`
  - \`$OUTPUT_DIR/adaptive-wide.png\`

- [ ] Instances: add, clone, fake, rename, forget, set default, reveal folder, launch warnings.
- [ ] Repositories: add, remove, reorder, refresh, recover from refresh failure.
- [ ] Catalog: search syntax, filters, tags, labels, saved searches, columns, sort, details inspector.
- [ ] Change set: preview, provider choices, recommendations, conflicts, apply, clear, retry.
- [ ] Operations: progress, cancellation, download failures, registry lock recovery, diagnostics copy.
- [ ] Maintenance: unmanaged files, history, play time, download statistics, cache, deduplicate, repair.
- [ ] Settings: General, Compatibility, Stability, Auth Tokens, Install Filters, Launch, Repositories, Cache.
- [ ] Help/About/Updates: about sheet, update check, help links, diagnostics.
- [ ] Adaptive layout: minimum, medium, and wide windows; sidebar/inspector hidden and visible states.
- [ ] Long content: long paths, long module names, long repository names, empty/loading/error states.
- [ ] Accessibility: keyboard focus path, VoiceOver labels, default/cancel actions, menu shortcuts.

## Defects

- [ ] No blocking defects found.
- [ ] Blocking defects recorded with screenshot path, reproduction steps, and fix owner.
EOF

echo "UI/UX audit evidence: $OUTPUT_DIR"

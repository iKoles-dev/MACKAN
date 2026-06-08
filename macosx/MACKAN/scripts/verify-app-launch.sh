#!/usr/bin/env bash
set -euo pipefail

TIMEOUT_SECONDS=20
APP_PATH=""
APP_PID=""
SIDE_CAR_PIDS=""
REQUIRE_WINDOW="${MACKAN_VERIFY_APP_LAUNCH_REQUIRE_WINDOW:-true}"
KEEP_RUNNING=false
SHOULD_CLEANUP=true

usage() {
    cat <<USAGE
Usage: verify-app-launch.sh [--keep-running] [--timeout SECONDS] APP_PATH

Launches MACKAN.app through Launch Services and verifies that normal GUI
startup does not spawn Terminal.app. The script quits only the process it
started unless --keep-running is set.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

process_ids_for_name() {
    local name="$1"

    pgrep -x "$name" 2>/dev/null || true
}

new_process_ids() {
    local before="$1"
    local after="$2"

    comm -13 \
        <(printf '%s\n' "$before" | sed '/^$/d' | sort -n) \
        <(printf '%s\n' "$after" | sed '/^$/d' | sort -n)
}

window_count_for_name() {
    local name="$1"

    if [[ -n "${MACKAN_VERIFY_APP_LAUNCH_WINDOW_COUNT_OUTPUT+x}" ]]; then
        printf '%s\n' "$MACKAN_VERIFY_APP_LAUNCH_WINDOW_COUNT_OUTPUT"
        return 0
    fi

    osascript -e "tell application \"System Events\" to count windows of process \"$name\"" 2>/dev/null || true
}

console_locked() {
    if [[ -n "${MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT+x}" ]]; then
        printf '%s\n' "$MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT"
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

cleanup() {
    if [[ "$SHOULD_CLEANUP" != "true" ]]; then
        return
    fi

    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        osascript -e 'tell application "MACKAN" to quit' >/dev/null 2>&1 || true
        for _ in {1..20}; do
            if ! kill -0 "$APP_PID" 2>/dev/null; then
                break
            fi
            sleep 0.25
        done
        if kill -0 "$APP_PID" 2>/dev/null; then
            kill "$APP_PID" >/dev/null 2>&1 || true
        fi
    fi

    if [[ -n "$SIDE_CAR_PIDS" ]]; then
        while IFS= read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" >/dev/null 2>&1 || true
            fi
        done <<< "$SIDE_CAR_PIDS"
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-running)
            KEEP_RUNNING=true
            shift
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
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
case "$REQUIRE_WINDOW" in
    true|false)
        ;;
    *)
        fail "MACKAN_VERIFY_APP_LAUNCH_REQUIRE_WINDOW must be true or false."
        ;;
esac

if [[ -z "$APP_PATH" ]]; then
    usage >&2
    exit 2
fi

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"

if [[ "$REQUIRE_WINDOW" == "true" ]]; then
    LOCKED_STATE="$(console_locked | tr -d '[:space:]')"
    if [[ "$LOCKED_STATE" == "Yes" ]]; then
        fail "Cannot verify visible MACKAN window because the macOS desktop is locked."
    fi
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "Info.plist missing: $INFO_PLIST"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
[[ -n "$EXECUTABLE_NAME" ]] || fail "CFBundleExecutable is empty in $INFO_PLIST"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
[[ -x "$EXECUTABLE_PATH" ]] || fail "App executable missing or not executable: $EXECUTABLE_PATH"

before_app_pids="$(process_ids_for_name "$EXECUTABLE_NAME")"
before_terminal_pids="$(process_ids_for_name Terminal)"
before_sidecar_pids="$(process_ids_for_name MACKAN.Service)"

open -n "$APP_PATH"

deadline=$((SECONDS + TIMEOUT_SECONDS))
while [[ "$SECONDS" -le "$deadline" ]]; do
    after_app_pids="$(process_ids_for_name "$EXECUTABLE_NAME")"
    candidate_pids="$(new_process_ids "$before_app_pids" "$after_app_pids")"
    if [[ -n "$candidate_pids" ]]; then
        APP_PID="$(printf '%s\n' "$candidate_pids" | head -n 1)"
        break
    fi
    sleep 0.25
done

[[ -n "$APP_PID" ]] || fail "MACKAN process did not launch within ${TIMEOUT_SECONDS}s."

actual_command="$(ps -p "$APP_PID" -o command=)"
actual_comm="$(ps -p "$APP_PID" -o comm=)"

APP_COMMAND_OK=false
if [[ "$actual_comm" == "$EXECUTABLE_NAME" ]]; then
    APP_COMMAND_OK=true
fi

if [[ "$APP_COMMAND_OK" == false && -n "$actual_command" && "$actual_command" == *"/Contents/MacOS/$EXECUTABLE_NAME"* ]]; then
    APP_COMMAND_OK=true
fi

if [[ "$APP_COMMAND_OK" == false ]]; then
    fail "Launched process does not match expected app executable name '$EXECUTABLE_NAME'. command=$actual_command comm=$actual_comm"
fi


sleep 1

after_terminal_pids="$(process_ids_for_name Terminal)"
new_terminal_pids="$(new_process_ids "$before_terminal_pids" "$after_terminal_pids")"
[[ -z "$new_terminal_pids" ]] || fail "Terminal.app launched unexpectedly with PID(s): $new_terminal_pids"

after_sidecar_pids="$(process_ids_for_name MACKAN.Service)"
SIDE_CAR_PIDS="$(new_process_ids "$before_sidecar_pids" "$after_sidecar_pids")"

WINDOW_COUNT=""
if [[ "$REQUIRE_WINDOW" == "true" ]]; then
    deadline=$((SECONDS + TIMEOUT_SECONDS))
    while [[ "$SECONDS" -le "$deadline" ]]; do
        WINDOW_COUNT="$(window_count_for_name "$EXECUTABLE_NAME" | tr -d '[:space:]')"
        if [[ "$WINDOW_COUNT" =~ ^[0-9]+$ && "$WINDOW_COUNT" -gt 0 ]]; then
            break
        fi
        sleep 0.25
    done

    [[ "$WINDOW_COUNT" =~ ^[0-9]+$ ]] || fail "Could not determine visible window count for $EXECUTABLE_NAME."
    [[ "$WINDOW_COUNT" -gt 0 ]] || fail "No visible MACKAN window appeared within ${TIMEOUT_SECONDS}s."
fi

if [[ "$REQUIRE_WINDOW" == "true" ]]; then
    if [[ "$KEEP_RUNNING" == "true" ]]; then
        SHOULD_CLEANUP=false
    fi
    echo "Verified GUI launch without Terminal and with visible window: $APP_PATH (pid $APP_PID, windows $WINDOW_COUNT)"
else
    if [[ "$KEEP_RUNNING" == "true" ]]; then
        SHOULD_CLEANUP=false
    fi
    echo "Verified GUI launch without Terminal: $APP_PATH (pid $APP_PID)"
fi

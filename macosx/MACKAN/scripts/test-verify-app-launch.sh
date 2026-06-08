#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-app-launch.sh"

ERROR_LOG="$(mktemp "${TMPDIR:-/tmp}/mackan-launch-test.XXXXXX.err")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-launch-test.XXXXXX")"
cleanup() {
    rm -f "$ERROR_LOG"
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if "$VERIFY_SCRIPT" --timeout 1 "/not/a/MACKAN.app" 2>"$ERROR_LOG"; then
    echo "Expected launch verifier to fail for a missing app bundle." >&2
    exit 1
fi

grep -F "App bundle not found" "$ERROR_LOG" >/dev/null

FAKE_APP="$WORK_DIR/MACKAN.app"
FAKE_TOOLS="$WORK_DIR/tools"
FAKE_STATE="$WORK_DIR/opened"
mkdir -p "$FAKE_APP/Contents/MacOS" "$FAKE_TOOLS"
cat > "$FAKE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MACKAN</string>
    <key>CFBundleIdentifier</key>
    <string>app.mackan.MACKAN.launch-test</string>
    <key>CFBundleName</key>
    <string>MACKAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST
printf '#!/usr/bin/env bash\nsleep 10\n' > "$FAKE_APP/Contents/MacOS/MACKAN"
chmod +x "$FAKE_APP/Contents/MacOS/MACKAN"

cat > "$FAKE_TOOLS/open" <<'SCRIPT'
#!/usr/bin/env bash
touch "$MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE"
SCRIPT
chmod +x "$FAKE_TOOLS/open"

cat > "$FAKE_TOOLS/pgrep" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$*" == "-x MACKAN" && -f "$MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE" ]]; then
    echo 4242
fi
SCRIPT
chmod +x "$FAKE_TOOLS/pgrep"

cat > "$FAKE_TOOLS/ps" <<'SCRIPT'
#!/usr/bin/env bash
case "$*" in
    "-p 4242 -o command=")
        echo "/tmp/MACKAN.app/Contents/MacOS/MACKAN"
        ;;
    "-p 4242 -o comm=")
        echo "MACKAN"
        ;;
esac
SCRIPT
chmod +x "$FAKE_TOOLS/ps"

cat > "$FAKE_TOOLS/kill" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
chmod +x "$FAKE_TOOLS/kill"

cat > "$FAKE_TOOLS/osascript" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
chmod +x "$FAKE_TOOLS/osascript"

SUCCESS_OUTPUT="$(PATH="$FAKE_TOOLS:$PATH" \
    MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE="$FAKE_STATE" \
    MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_VERIFY_APP_LAUNCH_WINDOW_COUNT_OUTPUT=1 \
    "$VERIFY_SCRIPT" --timeout 1 "$FAKE_APP")"
[[ "$SUCCESS_OUTPUT" == *"visible window"* ]] || {
    echo "Expected launch verifier success output to mention visible window." >&2
    echo "$SUCCESS_OUTPUT" >&2
    exit 1
}

rm -f "$FAKE_STATE"
KEEP_RUNNING_OUTPUT="$(PATH="$FAKE_TOOLS:$PATH" \
    MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE="$FAKE_STATE" \
    MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_VERIFY_APP_LAUNCH_WINDOW_COUNT_OUTPUT=1 \
    "$VERIFY_SCRIPT" --keep-running --timeout 1 "$FAKE_APP")"
[[ "$KEEP_RUNNING_OUTPUT" == *"visible window"* ]] || {
    echo "Expected keep-running launch verifier success output to mention visible window." >&2
    echo "$KEEP_RUNNING_OUTPUT" >&2
    exit 1
}

rm -f "$FAKE_STATE"
if PATH="$FAKE_TOOLS:$PATH" \
    MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE="$FAKE_STATE" \
    MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT=No \
    MACKAN_VERIFY_APP_LAUNCH_WINDOW_COUNT_OUTPUT=0 \
    "$VERIFY_SCRIPT" --timeout 1 "$FAKE_APP" 2>"$ERROR_LOG"; then
    echo "Expected launch verifier to fail when MACKAN has no visible windows." >&2
    exit 1
fi

grep -F "No visible MACKAN window" "$ERROR_LOG" >/dev/null

rm -f "$FAKE_STATE"
if PATH="$FAKE_TOOLS:$PATH" \
    MACKAN_VERIFY_APP_LAUNCH_FAKE_STATE="$FAKE_STATE" \
    MACKAN_VERIFY_APP_LAUNCH_CONSOLE_LOCKED_OUTPUT=Yes \
    "$VERIFY_SCRIPT" --timeout 1 "$FAKE_APP" 2>"$ERROR_LOG"; then
    echo "Expected launch verifier to fail clearly when the desktop is locked." >&2
    exit 1
fi

grep -F "desktop is locked" "$ERROR_LOG" >/dev/null

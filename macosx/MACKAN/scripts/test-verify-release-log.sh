#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-release-log.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mackan-release-log-test.XXXXXX")"
VALID_LOG="$WORK_DIR/release.log"
MISSING_MARKER_LOG="$WORK_DIR/missing-marker.log"
MISSING_ARTIFACT_MARKER_LOG="$WORK_DIR/missing-artifact-marker.log"
MISSING_CHECKSUM_MARKER_LOG="$WORK_DIR/missing-checksum-marker.log"
MISSING_SUMMARY_MARKER_LOG="$WORK_DIR/missing-summary-marker.log"
MISMATCHED_DMG_LOG="$WORK_DIR/mismatched-dmg.log"
MISMATCHED_CHECKSUM_LOG="$WORK_DIR/mismatched-checksum.log"
MISMATCHED_SUMMARY_LOG="$WORK_DIR/mismatched-summary.log"
DUPLICATE_ARTIFACT_MARKER_LOG="$WORK_DIR/duplicate-artifact-marker.log"
DUPLICATE_FINAL_DMG_LOG="$WORK_DIR/duplicate-final-dmg.log"
EMPTY_LOG="$WORK_DIR/empty.log"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cat > "$VALID_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISSING_MARKER_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISSING_ARTIFACT_MARKER_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISSING_CHECKSUM_MARKER_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISSING_SUMMARY_MARKER_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISMATCHED_DMG_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.4-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISMATCHED_CHECKSUM_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.4-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$MISMATCHED_SUMMARY_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.4-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$DUPLICATE_ARTIFACT_MARKER_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.2-universal.dmg
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

cat > "$DUPLICATE_FINAL_DMG_LOG" <<'LOG'
codesign --force --deep --options runtime --timestamp --sign Developer ID Application: Example
Verified release artifact: /tmp/MACKAN-1.2.3-universal.dmg
Release checksums verified: /tmp/MACKAN-1.2.3-universal.dmg.sha256
Release summary verified: /tmp/MACKAN-1.2.3-universal.dmg.release-summary.json
Public release handoff verified: /tmp/MACKAN-1.2.3-universal.dmg
/tmp/MACKAN-1.2.2-universal.dmg
/tmp/MACKAN-1.2.3-universal.dmg
LOG

: > "$EMPTY_LOG"

"$VERIFY_SCRIPT" "$VALID_LOG" >/tmp/mackan-release-log-valid.out
grep -F "Release log verified" /tmp/mackan-release-log-valid.out >/dev/null
rm -f /tmp/mackan-release-log-valid.out

if "$VERIFY_SCRIPT" "$MISSING_MARKER_LOG" >/tmp/mackan-release-log-missing.out 2>&1; then
    echo "Expected release log verifier to reject a log missing the handoff marker." >&2
    exit 1
fi
grep -F "handoff marker" /tmp/mackan-release-log-missing.out >/dev/null
rm -f /tmp/mackan-release-log-missing.out

if "$VERIFY_SCRIPT" "$MISSING_ARTIFACT_MARKER_LOG" >/tmp/mackan-release-log-artifact.out 2>&1; then
    echo "Expected release log verifier to reject a log missing the release artifact marker." >&2
    exit 1
fi
grep -F "release artifact marker" /tmp/mackan-release-log-artifact.out >/dev/null
rm -f /tmp/mackan-release-log-artifact.out

if "$VERIFY_SCRIPT" "$MISSING_CHECKSUM_MARKER_LOG" >/tmp/mackan-release-log-checksum.out 2>&1; then
    echo "Expected release log verifier to reject a log missing the checksum marker." >&2
    exit 1
fi
grep -F "checksum marker" /tmp/mackan-release-log-checksum.out >/dev/null
rm -f /tmp/mackan-release-log-checksum.out

if "$VERIFY_SCRIPT" "$MISSING_SUMMARY_MARKER_LOG" >/tmp/mackan-release-log-summary.out 2>&1; then
    echo "Expected release log verifier to reject a log missing the summary marker." >&2
    exit 1
fi
grep -F "summary marker" /tmp/mackan-release-log-summary.out >/dev/null
rm -f /tmp/mackan-release-log-summary.out

if "$VERIFY_SCRIPT" "$MISMATCHED_DMG_LOG" >/tmp/mackan-release-log-mismatch.out 2>&1; then
    echo "Expected release log verifier to reject mismatched DMG paths." >&2
    exit 1
fi
grep -F "Release log DMG paths do not match" /tmp/mackan-release-log-mismatch.out >/dev/null
rm -f /tmp/mackan-release-log-mismatch.out

if "$VERIFY_SCRIPT" "$MISMATCHED_CHECKSUM_LOG" >/tmp/mackan-release-log-checksum-mismatch.out 2>&1; then
    echo "Expected release log verifier to reject mismatched checksum path." >&2
    exit 1
fi
grep -F "Release log checksum path does not match DMG path" /tmp/mackan-release-log-checksum-mismatch.out >/dev/null
rm -f /tmp/mackan-release-log-checksum-mismatch.out

if "$VERIFY_SCRIPT" "$MISMATCHED_SUMMARY_LOG" >/tmp/mackan-release-log-summary-mismatch.out 2>&1; then
    echo "Expected release log verifier to reject mismatched summary path." >&2
    exit 1
fi
grep -F "Release log summary path does not match DMG path" /tmp/mackan-release-log-summary-mismatch.out >/dev/null
rm -f /tmp/mackan-release-log-summary-mismatch.out

if "$VERIFY_SCRIPT" "$DUPLICATE_ARTIFACT_MARKER_LOG" >/tmp/mackan-release-log-duplicate-artifact.out 2>&1; then
    echo "Expected release log verifier to reject duplicate release artifact markers." >&2
    exit 1
fi
grep -F "Release log marker must appear exactly once" /tmp/mackan-release-log-duplicate-artifact.out >/dev/null
rm -f /tmp/mackan-release-log-duplicate-artifact.out

if "$VERIFY_SCRIPT" "$DUPLICATE_FINAL_DMG_LOG" >/tmp/mackan-release-log-duplicate-final.out 2>&1; then
    echo "Expected release log verifier to reject duplicate final DMG outputs." >&2
    exit 1
fi
grep -F "Release log final DMG output must appear exactly once" /tmp/mackan-release-log-duplicate-final.out >/dev/null
rm -f /tmp/mackan-release-log-duplicate-final.out

if "$VERIFY_SCRIPT" "$EMPTY_LOG" >/tmp/mackan-release-log-empty.out 2>&1; then
    echo "Expected release log verifier to reject an empty log." >&2
    exit 1
fi
grep -F "Release log is empty" /tmp/mackan-release-log-empty.out >/dev/null
rm -f /tmp/mackan-release-log-empty.out

if "$VERIFY_SCRIPT" "$WORK_DIR/does-not-exist.log" >/tmp/mackan-release-log-missing-file.out 2>&1; then
    echo "Expected release log verifier to reject a missing log file." >&2
    exit 1
fi
grep -F "Release log not found" /tmp/mackan-release-log-missing-file.out >/dev/null
rm -f /tmp/mackan-release-log-missing-file.out

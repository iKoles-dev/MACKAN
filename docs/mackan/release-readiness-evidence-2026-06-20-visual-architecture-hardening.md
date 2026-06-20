# Release Readiness Evidence: Visual Architecture Hardening

Date: 2026-06-20

## Commands

- `swift test --package-path macosx/MACKAN`
  - Result: PASS, 332 tests, 0 failures.
- `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --filter MACKAN`
  - Result: PASS, 1451 tests, 0 failures.
- `macosx/MACKAN/scripts/test-accessibility-smoke.sh`
  - Result: PASS after updating the smoke check to follow the extracted `MainWindowToolbar.swift` launch label.
- `macosx/MACKAN/scripts/build-dev-app.sh`
  - Result: PASS, built `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app`.
- `macosx/MACKAN/scripts/verify-app-launch.sh --timeout 30 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app`
  - Result: PASS, GUI launched without Terminal and with one visible window.
- `macosx/MACKAN/scripts/run-ui-ux-audit.sh --wait-catalog 60 --output /tmp/mackan-visual-architecture-hardening-final /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app`
  - Result: PASS, final screenshot bundle captured.
- `macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh /tmp/mackan-visual-architecture-hardening-final`
  - Result: EXPECTED FAIL for this pass, because the full mandatory UI/function checklist was not manually repeated. First unchecked item: `Instances: add, clone, fake, rename, forget, set default, reveal folder, launch warnings.`
- `macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh --capture-only /tmp/mackan-visual-architecture-hardening-final`
  - Result: PASS, target-window screenshots, metadata, launch evidence, and window summary verified.
- `macosx/MACKAN/scripts/release-check.sh --skip-launch`
  - Result: PASS. The command also rebuilt universal packaging artifacts and verified the generated DMG/release artifact. Existing `SYSLIB0050` warnings from CKAN core remain.

## Visual Evidence

- `/tmp/mackan-visual-architecture-hardening-final/main-window.png`
- `/tmp/mackan-visual-architecture-hardening-final/adaptive-minimum.png`
- `/tmp/mackan-visual-architecture-hardening-final/adaptive-medium.png`
- `/tmp/mackan-visual-architecture-hardening-final/adaptive-wide.png`
- `/tmp/mackan-visual-architecture-hardening-final/audit-metadata.json`
- `/tmp/mackan-visual-architecture-hardening-final/window-summary.txt`
- `/tmp/mackan-visual-architecture-hardening-final/launch-smoke.txt`

## Result

The final visual audit captured the MACKAN target window, not the desktop or a different process. The main window, toolbar, sidebar, catalog table, and bottom action strip render as a stable native macOS workspace across minimum, medium, and wide breakpoints.

The minimum capture keeps the catalog readable without an empty inspector. The medium capture preserves source-list density while giving the catalog the main working area. The wide capture keeps sidebar and catalog proportions stable; no empty inspector is shown when no module is selected.

This evidence is a visual-architecture hardening gate, not a repeat of the full 2026-06-06 functional UI audit. Full `verify-ui-ux-audit-evidence.sh` correctly remains gated on manually checking the mandatory functional checklist. The capture-only verifier is the appropriate automated check for this visual bundle.

Public release remains gated by credential-backed Developer ID signing/notarization for distribution builds when credentials are required. The non-credential local release gate passed.

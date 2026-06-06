# MACKAN Full UI/Function Audit Evidence (2026-06-06)

## Run Policy

- Real mutating checks are allowed.
- No preliminary backup/rollback layer is used.
- Start-state capture is evidence only.
- Auth-token tests use a dummy non-secret token only.

## Start State

| Item | Evidence |
| --- | --- |
| Git status | captured verbatim at `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/git-status-short.txt`; existing dirty/untracked worktree retained |
| Built app path | `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` |
| App version | `0.1.0` (`CFBundleShortVersionString` and `CFBundleVersion`) |
| Selected instance | not captured |
| Repository list | not captured |
| Installed modules summary | not captured |
| Current staged changes | not captured |
| Settings summary | not captured |
| Initial screenshots | not captured |
| Strict readiness JSON | not captured |

## Command Log

| Time | Command | Result | Notes |
| --- | --- | --- | --- |
| 2026-06-06T14:11:15+0300 | `rg --files macosx/MACKAN/Tests/MACKANKitTests &#124; sort` | exit 0 | Listed 22 Swift XCTest files for automation proof mapping. |
| 2026-06-06T14:11:15+0300 | `rg --files Tests/MACKAN &#124; sort` | exit 0 | Listed 9 .NET MACKAN test files for sidecar/provider/dispatcher proof mapping. |
| 2026-06-06T14:11:15+0300 | `rg --files macosx/MACKAN/scripts &#124; sort` | exit 0 | Listed 37 script gates, including UI/UX audit, app launch, accessibility, bundle, DMG and release verifier scripts. |
| 2026-06-06T14:25:08+0300 | `python3 ... matrix proof mapping verification` | exit 0 | 102 rows, no malformed rows, no duplicate IDs, 0 empty/`not mapped` proof cells, 2 `proof-missing` rows, runnable script args present. |
| 2026-06-06T14:25:08+0300 | `git diff --check -- docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md` | exit 0 | Task 5 correction diff has no whitespace errors. |
| 2026-06-06T14:29:00+0300 | `git status --short` | exit 0 | Raw output saved to `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/git-status-short.txt`; existing unrelated dirty/untracked files were not reverted. |
| 2026-06-06T14:29:00+0300 | `ps aux ... MACKAN/MackanService/CKAN` | exit 0 | Raw output saved to `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/processes-before-baseline.txt`; existing default build MACKAN app and sidecar were already running. |
| 2026-06-06T14:29:29+0300 | `swift test --package-path macosx/MACKAN` | exit 0 | 291 tests passed, 0 failures; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/swift-test.log`. |
| 2026-06-06T14:29:31+0300 | `bash -lc 'dotnet test Tests/Tests.csproj --filter MACKAN'` | exit 1 | Bash resolved `/usr/local/share/dotnet/dotnet` with SDK 9.0.203; failed with `NETSDK1045` for `net10.0`; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan.log`. |
| 2026-06-06T14:30:00+0300 | `DOTNET_ROLL_FORWARD=Major dotnet test Tests/Tests.csproj --filter MACKAN` | exit 1 | Same `/usr/local` SDK 9 path under bash; failed with `NETSDK1045`; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-rollforward.log`. |
| 2026-06-06T14:31:00+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --filter MACKAN` | exit 1 | Homebrew SDK 10.0.105 builds further but all-target macOS run fails on `net481` nullable compile and `net10.0-windows` WindowsForms framework reference; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-homebrew-sdk10.log`. |
| 2026-06-06T14:32:00+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter MACKAN` | exit 0 | Scoped macOS MACKAN command passed: 1450 passed, 0 failed, 0 skipped; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-net10.log`. |
| 2026-06-06T14:32:40+0300 | `macosx/MACKAN/scripts/test-run-ui-ux-audit.sh` | exit 0 | Harness test passed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/test-run-ui-ux-audit.log`. |
| 2026-06-06T14:32:40+0300 | `macosx/MACKAN/scripts/test-accessibility-smoke.sh` | exit 0 | Accessibility smoke passed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/test-accessibility-smoke.log`. |
| 2026-06-06T14:33:10+0300 | `macosx/MACKAN/scripts/build-dev-app.sh` | exit 0 | Built `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app`; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/build-dev-app.log`. |
| 2026-06-06T14:33:30+0300 | `macosx/MACKAN/scripts/verify-app-bundle.sh --mode auto --require-icon --require-version 0.1.0 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` | exit 0 | Verified single-arch app bundle; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/verify-app-bundle.log`. |
| 2026-06-06T14:33:30+0300 | `macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` | exit 0 | Verified GUI launch without Terminal and with 1 visible window; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/verify-app-launch.log`. |

## Live Mutations

| Time | Matrix Row | Action | Observed State Change |
| --- | --- | --- | --- |

## Defects

| Matrix Row | Severity | Summary | Owner Files | Fix Status | Verification |
| --- | --- | --- | --- | --- | --- |
| BASELINE-DOTNET-001 | P0 | Plan baseline `dotnet test Tests/Tests.csproj --filter MACKAN` fails on macOS all-target build; scoped `--framework net10.0` MACKAN tests pass. | `Tests/Tests.csproj`; `Core/Configuration/KeychainAuthTokenConfiguration.cs`; `Cmdline/CKAN-cmdline.csproj`; local dotnet PATH selection | open | Failing logs: `dotnet-test-mackan*.log`; passing scoped log: `dotnet-test-mackan-net10.log` |

## Screenshots and Artifacts

| Artifact | Path | Matrix Rows |
| --- | --- | --- |
| Baseline git status | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/git-status-short.txt` | Task 6 |
| Baseline process state | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/processes-before-baseline.txt` | Task 6 |
| Swift test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/swift-test.log` | Task 6 |
| .NET all-target failure log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-homebrew-sdk10.log` | `BASELINE-DOTNET-001` |
| .NET scoped MACKAN pass log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-net10.log` | Task 6; MACKAN .NET rows |
| UI/UX harness test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/test-run-ui-ux-audit.log` | Task 6 |
| Accessibility smoke log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/test-accessibility-smoke.log` | Task 6 |
| Build dev app log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/build-dev-app.log` | Task 6 |
| Bundle verification log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/verify-app-bundle.log` | Task 6 |
| Launch verification log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/verify-app-launch.log` | `APP-STARTUP-001`; Task 6 |

## Automated Proof Mapping Summary

| Item | Value |
| --- | --- |
| Matrix rows mapped | 103 |
| Swift XCTest files found | 22 |
| .NET MACKAN test files found | 9 |
| Script gates found | 37 |
| Rows with `Automation Proof` still `not mapped` | 0 |
| `proof-missing` rows | 2 |
| `proof-missing` row IDs | `SET-PLUGINS-001`, `FUNC-NONUI-003` |

Notes: Task 5 maps existing automation only; mapped rows remain `not-run` until Task 6 or later execution actually runs the proof. `SET-PLUGINS-001` is `proof-missing` because no current automation asserts the Plugins tab unsupported-state copy or CKAN links. `FUNC-NONUI-003` is `proof-missing` because .NET route/provider proof exists, but no current Swift `SidecarClientTests` method asserts `SidecarClient.refreshRepositories` uses `repositories.refresh`.

## Baseline Command Run Summary

| Item | Result |
| --- | --- |
| Swift package tests | pass: 291 passed, 0 failed |
| .NET MACKAN all-target command | fail: `dotnet test Tests/Tests.csproj --filter MACKAN` does not pass on macOS all targets |
| .NET MACKAN scoped `net10.0` command | pass: 1450 passed, 0 failed, 0 skipped |
| UI/UX harness script test | pass |
| Accessibility smoke script test | pass |
| Development app build | pass: `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` |
| Bundle verification | pass |
| GUI launch verification | pass: no Terminal, 1 visible window |

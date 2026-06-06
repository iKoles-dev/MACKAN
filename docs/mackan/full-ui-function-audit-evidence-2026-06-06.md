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
| Selected instance | CKAN CLI selected/default instance: `Авто KSP`, KSP `1.12.5.3190`, path `/Users/elijahn/Library/Application Support/Steam/SteamApps/common/Kerbal Space Program`; raw output `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-instances.txt` |
| Repository list | not captured |
| Installed modules summary | CKAN CLI installed modules captured at `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-installed-mods.txt`; includes up-to-date, auto-installed, unmanaged and upgradable markers |
| Current staged changes | not captured |
| Settings summary | not captured |
| Initial screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/main-window.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-minimum.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-medium.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-wide.png` |
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
| 2026-06-06T14:41:05+0300 | `macosx/MACKAN/scripts/run-ui-ux-audit.sh --wait-catalog 60 --output /tmp/mackan-full-ui-function-audit-2026-06-06 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` | exit 0 | Created real-app scaffold with main/adaptive screenshots, metadata, launch smoke, window summary and checklist. Catalog readiness mode was `inconclusive-wait`. |
| 2026-06-06T14:42:10+0300 | `macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh /tmp/mackan-full-ui-function-audit-2026-06-06` | exit 1 | Expected at start-state stage: verifier rejected incomplete mandatory checklist item `Instances: add, clone, fake, rename, forget, set default, reveal folder, launch warnings.` Raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/verify-ui-ux-audit-evidence-task7.log`. |
| 2026-06-06T14:42:30+0300 | `\"/Applications/CKAN.app/Contents/MacOS/arm64/CKAN-CmdLine\" instance list` | exit 0 | Raw output `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-instances.txt`; default instance `Авто KSP`. |
| 2026-06-06T14:42:34+0300 | `\"/Applications/CKAN.app/Contents/MacOS/arm64/CKAN-CmdLine\" list` | exit 0 | Raw output `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-installed-mods.txt`; KSP `1.12.5.3190`, installed/unmanaged/upgradable module markers captured. |
| 2026-06-06T14:47:06+0300 | `swift test --package-path macosx/MACKAN --filter DiagnosticsBundleTests` | exit 0 | 1 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-diagnostics-bundle-tests.log`. |
| 2026-06-06T14:47:07+0300 | `swift test --package-path macosx/MACKAN --filter HelpLinkTests` | exit 0 | 5 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-help-link-tests.log`. |
| 2026-06-06T14:47:10+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter ServiceDispatcherTests` | exit 0 | 86 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-service-dispatcher-tests-net10.log`. |
| 2026-06-06T14:47:30+0300 | `open /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app; osascript ... menu enablement snapshot` | exit 0 | MACKAN frontmost with 1 window; menu enablement saved to `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-menu-enablements.txt`. |
| 2026-06-06T14:48:00+0300 | `Help/About/Update/Diagnostics menu automation plus screenshots` | exit 0 | Captured About, stable update error sheet, diagnostics alert, clipboard head and diagnostics bundle path. |
| 2026-06-06T14:50:00+0300 | `Help > User Guide` | exit 0 | External link opened in Arc to GitHub `KSP-CKAN/CKAN` wiki `User guide`; screenshot `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-user-guide-external.png`. |

## Baseline Git Status Verbatim

```text
 M .github/workflows/build.yml
 M .gitignore
 M ConsoleUI/CKAN-ConsoleUI.csproj
 M Core/CKAN-core.csproj
 M Core/GameInstance.cs
 M Core/IO/HardLink.cs
 M Core/IO/InstalledFilesDeduplicator.cs
 M Core/IO/ModuleImporter.cs
 M Core/Net/NetModuleCache.cs
 M Core/ServiceLocator.cs
 M README.md
 M Tests/Core/Configuration/FakeConfiguration.cs
 M Tests/Tests.csproj
?? .github/workflows/mackan-release.yml
?? Core/Configuration/KeychainAuthTokenConfiguration.cs
?? MACKAN.Service/
?? Tests/Core/Configuration/KeychainAuthTokenConfigurationTests.cs
?? Tests/MACKAN/
?? docs/mackan/README.md
?? docs/mackan/architecture.md
?? docs/mackan/brainstorming-release-plan-v1.md
?? docs/mackan/brainstorming-session-kit-v1.0.md
?? docs/mackan/brainstorming-session-plan.md
?? docs/mackan/brainstorming-workshop-v1.md
?? docs/mackan/brainstorming.md
?? docs/mackan/implementation-candidate-backlog.md
?? docs/mackan/next-iteration-plan.md
?? docs/mackan/parity-focus-initial.md
?? docs/mackan/parity-matrix.md
?? docs/mackan/product-spec.md
?? docs/mackan/release-execution-checklist.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-1.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-10.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-11.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-12.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-13.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-14.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-15.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-16.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-17.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-18.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-19.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-2.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-20.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-21.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-22.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-23.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-3.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-4.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-5.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-6.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-7.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-8.md
?? docs/mackan/release-readiness-evidence-2026-05-31-impl-pass-9.md
?? docs/mackan/release-readiness-evidence-2026-05-31.md
?? docs/mackan/release-readiness-evidence-2026-06-01-canonical-repositories.md
?? docs/mackan/release-readiness-evidence-2026-06-01-catalog-full-list.md
?? docs/mackan/release-readiness-evidence-2026-06-01-catalog-labels-tags.md
?? docs/mackan/release-readiness-evidence-2026-06-01-catalog-search.md
?? docs/mackan/release-readiness-evidence-2026-06-01-catalog-smart-filters.md
?? docs/mackan/release-readiness-evidence-2026-06-01-changeset-apply-provider.md
?? docs/mackan/release-readiness-evidence-2026-06-01-changeset-replace-recommendations.md
?? docs/mackan/release-readiness-evidence-2026-06-01-clean-smoke.md
?? docs/mackan/release-readiness-evidence-2026-06-01-maintenance-file-workflows.md
?? docs/mackan/release-readiness-evidence-2026-06-01-operations-registry-lock.md
?? docs/mackan/release-readiness-evidence-2026-06-01-operations-updates-closeout.md
?? docs/mackan/release-readiness-evidence-2026-06-01-rc-full-smoke.md
?? docs/mackan/release-readiness-evidence-2026-06-01-repo-mutations.md
?? docs/mackan/release-readiness-evidence-2026-06-01-repo-refresh-recovery.md
?? docs/mackan/release-readiness-evidence-2026-06-01-signed-workflow.md
?? docs/mackan/release-readiness-evidence-2026-06-01-ui-ux-hardening.md
?? docs/mackan/release-readiness-evidence-2026-06-05-product-design-ui-hardening.md
?? docs/mackan/release-roadmap.md
?? docs/mackan/sprint-0-execution-pack.md
?? docs/mackan/sprint-1-execution-log.md
?? docs/mackan/sprint-1-instances-repositories-pack.md
?? docs/mackan/sprint-1-runbook.md
?? docs/mackan/sprint-1-static-proof-matrix.txt
?? docs/mackan/sprint-2-catalog-changeset-pack.md
?? docs/mackan/v1-release-execution-runbook.md
?? docs/superpowers/plans/2026-05-31-mackan-native-macos-release-plan.md
?? docs/superpowers/plans/2026-05-31-mackan-v1-required-only-execution-plan.md
?? docs/superpowers/specs/2026-05-30-mackan-native-macos-design.md
?? docs/superpowers/specs/2026-05-31-mackan-implementation-plan.md
?? docs/superpowers/specs/2026-05-31-mackan-release-blueprint-approved-design.md
?? docs/superpowers/specs/2026-05-31-mackan-release-blueprint.md
?? docs/superpowers/specs/2026-05-31-mackan-release-execution-plan.md
?? docs/superpowers/specs/2026-05-31-mackan-release-implementation-plan.md
?? docs/superpowers/specs/2026-05-31-mackan-v1-design.md
?? docs/superpowers/specs/2026-05-31-mackan-v1-ultimate-release-design.md
?? macosx/MACKAN/
```

## Live Mutations

| Time | Matrix Row | Action | Observed State Change |
| --- | --- | --- | --- |
| 2026-06-06T14:48:00+0300 | `APP-ABOUT-001` | Opened MACKAN menu then About MACKAN | About sheet displayed app `0.1.0`, service/core `v1.36.5.26146`, protocol `1`, .NET `10.0.5`, macOS `26.5.0`, Arm64; Return closed sheet. |
| 2026-06-06T14:48:00+0300 | `APP-UPDATE-001` | Opened Help then Check for Updates | Update sheet displayed stable-channel visible error state: current `v1.36.5.26146`, latest unavailable, manual download required, metadata unreadable; no crash/hang. |
| 2026-06-06T14:49:00+0300 | `APP-DIAGNOSTICS-001` | Opened Help then Report Client Issue | Diagnostics report copied to clipboard, diagnostics zip written at `/var/folders/f3/71_ydpz12073fp4rj6zxd1tr0000gn/T/MACKAN-Diagnostics-20260606T114919Z.zip`, alert shown and closed. |
| 2026-06-06T14:50:00+0300 | `APP-MENU-005` | Opened Help then User Guide | Arc opened GitHub `KSP-CKAN/CKAN` wiki `User guide`; no Terminal fallback. |

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
| Main window screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/main-window.png` | Task 7 |
| Adaptive minimum screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-minimum.png` | Task 7; adaptive layout rows |
| Adaptive medium screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-medium.png` | Task 7; adaptive layout rows |
| Adaptive wide screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-wide.png` | Task 7; adaptive layout rows |
| UI/UX audit metadata | `/tmp/mackan-full-ui-function-audit-2026-06-06/audit-metadata.json` | Task 7 |
| UI/UX audit checklist | `/tmp/mackan-full-ui-function-audit-2026-06-06/ui-ux-audit.md` | Task 7 |
| UI/UX verifier failure log | `/tmp/mackan-full-ui-function-audit-2026-06-06/verify-ui-ux-audit-evidence-task7.log` | Task 7 |
| CKAN instance list | `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-instances.txt` | Task 7 |
| CKAN installed modules | `/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-installed-mods.txt` | Task 7 |
| Task 8 menu enablement snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-menu-enablements.txt` | `APP-MENU-*` |
| Task 8 About screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-about.png` | `APP-ABOUT-001` |
| Task 8 update sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-update-open.png` | `APP-UPDATE-001` |
| Task 8 diagnostics alert screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-diagnostics-alert.png` | `APP-DIAGNOSTICS-001` |
| Task 8 diagnostics clipboard excerpt | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-diagnostics-clipboard-head.txt` | `APP-DIAGNOSTICS-001` |
| Task 8 diagnostics bundle path | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-diagnostics-bundles.txt` | `APP-DIAGNOSTICS-001` |
| Task 8 User Guide external screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-user-guide-external.png` | `APP-MENU-005` |
| Task 8 HelpLinkTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-help-link-tests.log` | `APP-MENU-005` |
| Task 8 DiagnosticsBundleTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-diagnostics-bundle-tests.log` | `APP-DIAGNOSTICS-001` |
| Task 8 ServiceDispatcherTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task8-service-dispatcher-tests-net10.log` | `APP-UPDATE-*`; sidecar dispatcher |

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

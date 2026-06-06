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
| 2026-06-06T16:03:00+0300 | `macosx/MACKAN/scripts/build-dev-app.sh` | exit 0 | Rebuilt patched app after Add Repository sheet fix; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-build-dev-app-after-repo-fix.log`. |
| 2026-06-06T16:23:41+0300 | `swift test --package-path macosx/MACKAN --filter ModalSheetLayoutPolicyTests` | exit 0 | 5 passed, 0 failed; includes Add Repository sheet height and known-source field regression tests; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-modal-sheet-layout-policy-tests-after-repo-fix.log`. |
| 2026-06-06T16:24:00+0300 | `swift test --package-path macosx/MACKAN --filter AppModelTests` | exit 0 | 140 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-app-model-tests-after-repo-fix.log`. |
| 2026-06-06T16:24:30+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter CoreMackanRepositoryProviderTests` | exit 0 | 5 passed, 0 failed; existing SYSLIB0050 warnings only; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-core-repository-provider-tests-net10-after-repo-fix.log`. |
| 2026-06-06T16:25:00+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter ServiceDispatcherTests` | exit 0 | 86 passed, 0 failed; existing SYSLIB0050 warnings only; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-service-dispatcher-tests-net10-after-repo-fix.log`. |
| 2026-06-06T17:57:12+0300 | `swift test --package-path macosx/MACKAN --filter 'CatalogReadinessPresentationStateTests&#124;InspectorEmptyPresentationStateTests&#124;ModuleRelationshipGraphTests&#124;ModuleActionPresentationStateTests&#124;CatalogToolbarLayoutPolicyTests&#124;CatalogGridIdentityPolicyTests'` | exit 0 | 16 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-swift-catalog-inspector.log`. |
| 2026-06-06T17:58:00+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter "FullyQualifiedName~CoreMackanModuleProviderTests&#124;FullyQualifiedName~ServiceDispatcherTests"` | exit 0 | 88 passed, 0 failed; existing SYSLIB0050 warnings only; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-dotnet-module-dispatcher.log`. |
| 2026-06-06T18:20:21+0300 | `swift test --package-path macosx/MACKAN --filter 'testBuiltInSavedSearchAppliesCatalogFilterAndClearsAdHocSearch&#124;testSavedCatalogSearchLoadsSavesAndAppliesState&#124;testSavedCatalogSearchReplacesByNameAndDeletesPersistently'` | exit 0 | 3 passed, 0 failed; raw log `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-swift-saved-search.log`. |

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
| 2026-06-06T15:02:00+0300 | `INST-FAKE-001` | Opened Instance then Fake Instance and clicked Create | UI created a real fake KSP instance at `/Users/elijahn/Library/Application Support/Steam/SteamApps/common/KSP Fake`; CKAN CLI listed `KSP Fake`; later renamed for audit. |
| 2026-06-06T15:05:00+0300 | `INST-MANAGE-001`, `INST-MANAGE-002` | Opened Manage Instances and used row actions | Manage sheet listed real and audit instances; set audit fake as default, revealed its folder in Finder, renamed it to `MACKAN Audit Renamed`, forgot cloned/added audit rows, and restored `Авто KSP` as selected/default. |
| 2026-06-06T15:10:00+0300 | `INST-MANAGE-002` | Clicked Show in Finder for audit fake row | Finder opened `.../Steam/steamapps/common` with `KSP Fake` selected; a Codex-to-Finder TCC prompt appeared during inspection and was allowed. |
| 2026-06-06T15:15:00+0300 | `INST-CLONE-001` | Cloned audit fake instance | Clone sheet loaded source/default destination, clone completed to `/Users/elijahn/Library/Application Support/Steam/SteamApps/common/KSP Fake Clone`, CKAN CLI listed `MACKAN Audit Renamed Clone`. |
| 2026-06-06T15:18:00+0300 | `INST-MANAGE-002` | Forgot cloned audit instance | Confirmation text stated the instance would be removed from CKAN's instance list and the game folder would not be deleted; CKAN CLI removed the clone row and the folder still existed. |
| 2026-06-06T15:21:00+0300 | `INST-ADD-001` | Added the existing clone folder as a game instance | Add form accepted `/Users/elijahn/Library/Application Support/Steam/SteamApps/common/KSP Fake Clone` with name `MACKAN Audit Added`; CKAN CLI listed the added instance. |
| 2026-06-06T15:25:00+0300 | `INST-LAUNCHCMD-001`, `APP-MENU-002` | Edited launch command line and launched missing command | Saved `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/missing-launch-command`; Instance menu submenu reflected the saved value. |
| 2026-06-06T15:27:00+0300 | `WIN-ALERT-004`, `APP-MENU-002` | Launched missing command from submenu and via Launch Game | Both launch attempts showed `Failed to launch game` with command details and `Retry Launch`; no real KSP process was started. |
| 2026-06-06T15:30:00+0300 | `INST-LAUNCHCMD-001` | Reset launch command lines to defaults | Reset to Defaults then Save restored the launch submenu to `./KSP.app/Contents/MacOS/KSP`. |
| 2026-06-06T15:36:00+0300 | `APP-MENU-001`, `INST-MANAGE-002` | Cleaned audit registry state and smoke-opened direct Add/Clone menu sheets | Final CKAN CLI registry contained only `Авто KSP` as default; audit folders `KSP Fake` and `KSP Fake Clone` remained on disk, matching the Forget contract. Direct menu Add/Clone sheets opened and were cancelled without mutation. |
| 2026-06-06T15:46:00+0300 | `SET-REPO-001` | Opened Settings then Repositories | Repository table rendered real `KSP-стандартный` source; CKAN CLI snapshot saved at `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-before.txt`. |
| 2026-06-06T15:52:00+0300 | `SET-REPO-002` | Opened Add Repository on the pre-fix build | Add Repository sheet was `470x260`, footer buttons were below the sheet bottom, and clicking Known Sources rows left Name/URL blank; screenshots and field dumps captured. |
| 2026-06-06T16:08:00+0300 | `SET-REPO-002` | Rebuilt patched app and reopened Add Repository | Sheet expanded to `620x520`; `Cancel`/`Add` were fully visible and inside the sheet; known source row click populated Name/URL. |
| 2026-06-06T16:14:00+0300 | `SET-REPO-002` | Selected `KSP-backup` known source and clicked Add | CKAN CLI listed `KSP-backup` at priority `1`; Add sheet closed and Repositories table selected the new row. |
| 2026-06-06T16:16:00+0300 | `SET-REPO-004` | Clicked Move Up on `KSP-backup` | CKAN CLI listed `KSP-backup` at priority `0` and `KSP-стандартный` at priority `1`. |
| 2026-06-06T16:17:00+0300 | `SET-REPO-004` | Clicked Move Down on `KSP-backup` | CKAN CLI restored `KSP-стандартный` priority `0` and `KSP-backup` priority `1`. |
| 2026-06-06T16:18:00+0300 | `SET-REPO-004` | Clicked Remove on selected `KSP-backup` | CKAN CLI returned to the single original `KSP-стандартный` repository; no leftover audit repository remained. |
| 2026-06-06T16:20:00+0300 | `SET-REPO-003` | Clicked Refresh in the Repositories pane | UI showed `Refreshing repositories...` with busy indicator and event log, then completed as `Updated - 2,247 compatible modules`; repository list stayed clean. |
| 2026-06-06T16:22:00+0300 | `SET-REPO-003` | Started Refresh again and used the active Cancel control | AX button count changed from 5 to 6, script clicked the inserted Cancel button, final UI returned to `Up to date - 2,247 compatible modules`; repository list still contained only `KSP-стандартный`. |
| 2026-06-06T16:45:00+0300 | `CAT-SEARCH-001`, `CAT-SEARCH-002` | Set catalog search queries and used Search Syntax examples | Direct text-field state set `is:installed`; Search Syntax menu opened and populated `scatterer @blackrack`; filter reset to All as expected. |
| 2026-06-06T16:50:00+0300 | `CAT-FILTER-001`, `CAT-TAG-001`, `CAT-SORT-001`, `CAT-SORT-002` | Exercised filter, tag, primary sort and secondary sort controls | Installed, Not Installed, Upgradable, Compatible, Incompatible, Cached, Uncached, New and Replaceable filters selected; `graphics` tag applied; primary sort changed to Identifier; secondary sort state captured. |
| 2026-06-06T17:05:00+0300 | `CAT-COLUMN-001`, `CAT-LOADING-001` | Opened Columns menu, toggled visible columns, then restored defaults by deleting `mackan.visibleModuleColumns` and relaunching | Headers changed without hiding all columns; relaunch showed catalog loading overlay and then loaded catalog; only column-visibility defaults were reset. |
| 2026-06-06T17:20:00+0300 | `CAT-ROW-001`, `WIN-TOOLBAR-002`, `CAT-ACTION-001`, `WIN-SHEET-001`, `OPS-PREVIEW-001` | Selected `4kSP_Expanded`, tried row/pending-cell staging, staged through toolbar Install, opened Preview, then cleared | Row/status/pending-cell clicks did not stage; toolbar Install produced `1 change staged`; Preview showed `Install 4kSP_Expanded 0.2.2` with reason `User requested`; Close and Clear returned to `No changes staged`. |
| 2026-06-06T17:35:00+0300 | `CAT-LABEL-001`, `CAT-LABEL-002`, `SID-LABEL-001` | Opened Labels menu and Labels Manager, created a new-label draft and attempted Save through click, AXPress and paste paths | Built-in labels and manager UI rendered; new-label draft accepted name, scope, color and two flags, but Save did not create the label; sheet closed with no persisted audit label. |
| 2026-06-06T17:45:00+0300 | `INS-HEADER-001`, `INS-OVERVIEW-001`, `INS-RELATIONSHIP-001`, `INS-VERSION-001`, `INS-CONTENT-001`, `INS-RESOURCE-001` | Switched inspector tabs for selected `4kSP_Expanded` | Overview, Relationships, Versions, Contents and Resources tabs all rendered populated module details; Resources listed Homepage, SpaceDock, Repository, Bug Tracker and Remote AVC links. |
| 2026-06-06T18:18:00+0300 | `CAT-SAVEDSEARCH-001` | Saved current search, reopened Saved Searches menu, deleted the saved search through submenu, and confirmed cleanup | Save sheet opened; saved entry appeared as `identifier:Eternal`; Delete Saved Search submenu removed it and the menu returned to `No Saved Searches`. Attempted custom pasted name was not reflected in this live pass. |
| 2026-06-06T18:25:00+0300 | `CAT-SEARCH-001`, `CAT-SAVEDSEARCH-001` | Relaunched into Task 12 and inspected persisted catalog state | Catalog appeared empty/stale while visible search field looked blank; `defaults` showed active `mackan.moduleCatalogState.searchText` as `identifier:Eternal`. Deleting only `mackan.moduleCatalogState` restored rows for this run. |
| 2026-06-06T18:35:00+0300 | `CAT-ACTION-001`, `OPS-PREVIEW-001` | Searched for `4kSP_Expanded`, selected the visible row, staged install and opened Preview | Preview resolved a one-change install for `(ATHSS) AtomicTech Hardware Serializing System` / `AtomicTechFlags-ATHSS`, not the visible searched row. The flow exposed stale selected-module/action state; the preview itself rendered table rows and Apply. |
| 2026-06-06T18:40:00+0300 | `OPS-RESULT-001`, `OPS-RETRY-001` | Applied the one-change install, clicked Refresh Status and inspected CKAN state | Operation sheet showed Running, `Refresh Status`, `Cancel` and `Close`; Refresh Status moved status to Completed. CKAN list confirmed `AtomicTechFlags-ATHSS 1.0` installed, but completed progress rows still displayed `0%`/`0 bytes`. |
| 2026-06-06T18:48:00+0300 | `CAT-ACTION-001`, `OPS-PREVIEW-001`, `OPS-RESULT-001` | Switched to hidden/offscreen window-level evidence mode, staged Remove for `AtomicTechFlags-ATHSS`, previewed and applied | Hidden MACKAN window remained non-frontmost; window-level screenshots showed Remove staged, preview resolved, Apply completed and the module returned to Available. CKAN list after remove had no `AtomicTechFlags-ATHSS` line. |
| 2026-06-06T19:00:00+0300 | `CAT-ACTION-001`, `OPS-PREVIEW-001`, `OPS-RESULT-001` | Staged Upgrade All, previewed 10 changes and applied | Preview showed `10 changes ready`; after Apply, action strip returned to `No changes staged`. CKAN list showed multiple upgraded versions such as `ContractConfigurator v2.13.1.0`, `Kopernicus 2:release-1.12.1-244`, `KSPCommunityFixes 1:1.41.0`, `KSPTextureLoader 1.0.35`, `SystemHeat 0.9.1` and `Waterfall 0.11.0`; some upgradable markers remained, so this is not claimed as a clean all-upgraded state. |
| 2026-06-06T19:08:00+0300 | `OPS-PROVIDER-001`, `OPS-RECOMMEND-001`, `OPS-CONFLICT-001` | Checked real preview preconditions for provider/recommendation/conflict/replace paths | Current install/remove/upgrade previews did not surface provider choices, optional recommendations or conflicts; `is:replaceable` returned no visible rows in the live catalog. Rows are deferred rather than marked pass. |
| 2026-06-06T19:12:00+0300 | `OPS-LOCK-001` | Ran CKAN CLI while MACKAN held registry access | CKAN CLI surfaced a live `CKAN.RegistryInUseKraken`/`registry.locked` guard and prompted not to delete the lock unless stale. The in-app registry-lock notice did not surface, so destructive Remove Lock File was not pressed. |
| 2026-06-06T21:45:00+0300 | `FILE-EXPORTLIST-001` | Opened Mods > Export Mod List > Plain Text in the real app | Native `NSSavePanel` opened with suggested filename `Авто KSP-mods.txt`. Hidden/offscreen automation could not reliably drive target-directory selection; an attempted save selected a prior `Asset Store-5.x` folder suggestion and later produced a Replace prompt, which was cancelled without overwrite. |
| 2026-06-06T21:54:00+0300 | `FILE-EXPORTLIST-001` | Exported all five mod-list formats through `exports.modList` sidecar route | Plain text, Markdown, BBCode, CSV and TSV files were written under `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/` and verified non-empty. |
| 2026-06-06T21:55:00+0300 | `FILE-EXPORTPACK-001` | Exported `MACKAN-Audit-Pack.ckan` through `exports.modpack` | Generated `.ckan` file was non-empty and contained requested metadata plus Depends `B9PartSwitch`, Recommends `ClickThroughBlocker`, Suggests `CommunityResourcePack` and Ignore `CommunityTechTree` relationship assignment; ignore check confirmed `CommunityTechTree` absent from output relationships. |
| 2026-06-06T21:59:00+0300 | `FILE-CKAN-001`, `OPS-PROVIDER-002`, `OPS-RECOMMEND-002`, `OPS-DOWNLOADFAIL-002` | Installed generated `.ckan` through same-session `operations.startInstallCkanFiles`, then removed it | Install completed as `MACKAN-Audit-Pack 1.0.0` metapackage; cleanup remove completed in the same sidecar session and CKAN CLI cleanup check found no remaining `MACKAN-Audit-Pack`. No provider, recommendation or incompatible-file notice surfaced for this valid file. |
| 2026-06-06T22:01:00+0300 | `FILE-IMPORT-001`, `OPS-IMPORTOPTIONS-001` | Imported a disposable copy of real `AtomicTechFlags-ATHSS-1.0.zip` through `operations.startImportDownloads` | Delete-original import completed and removed the disposable input copy; preview-before-install import completed with an install change for `AtomicTechFlags-ATHSS` while leaving the copied input file intact. Final CKAN cleanup check found neither `AtomicTechFlags-ATHSS` nor `MACKAN-Audit-Pack` installed. |
| 2026-06-06T22:03:00+0300 | Task 13 automation | Ran file/export workflow tests | Swift `ImportDownloadsDraftTests`, `CkanFileInstallDraftTests` and `FileImportFlowStateTests` passed. All-target .NET command failed for the already-known macOS baseline build issue; scoped `--framework net10.0` export/operation provider run passed 24/24. |

## Defects

| Matrix Row | Severity | Summary | Owner Files | Fix Status | Verification |
| --- | --- | --- | --- | --- | --- |
| BASELINE-DOTNET-001 | P0 | Plan baseline `dotnet test Tests/Tests.csproj --filter MACKAN` fails on macOS all-target build; scoped `--framework net10.0` MACKAN tests pass. | `Tests/Tests.csproj`; `Core/Configuration/KeychainAuthTokenConfiguration.cs`; `Cmdline/CKAN-cmdline.csproj`; local dotnet PATH selection | open | Failing logs: `dotnet-test-mackan*.log`; passing scoped log: `dotnet-test-mackan-net10.log` |
| SET-REPO-002 | P1 | Add Repository sheet clipped its footer buttons and Known Sources row selection did not populate Name/URL fields, blocking the normal canonical-source add workflow. | `macosx/MACKAN/Sources/MACKAN/RepositoryPreferencesView.swift`; `macosx/MACKAN/Sources/MACKANKit/AddRepositorySheetPresentationPolicy.swift`; `macosx/MACKAN/Tests/MACKANKitTests/ModalSheetLayoutPolicyTests.swift` | fixed | Failing artifacts: `task10/add-repository-open-3.png`, `task10/add-repository-row-selected-fields.txt`; fixed artifacts: `task10/add-repository-after-fix-open.png`, `task10/add-repository-ksp-backup-selected-fields.txt`; tests: `task10-modal-sheet-layout-policy-tests-after-repo-fix.log` |
| CAT-ROW-001 | P1 | Catalog row double-click and status/pending cell clicks did not stage the preferred install action, while toolbar Install staged the same selected module immediately. | `macosx/MACKAN/Sources/MACKAN/CatalogViews.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`; `macosx/MACKAN/Sources/MACKANKit/ModuleActionPresentationState.swift` | open | Failing artifacts: `task11/row-double-click-staged-install.png`, `task11/status-cell-click-staged-install.png`, `task11/pending-cell-click-staged.png`; passing contrast: `task11/toolbar-install-staged-repeat.png` |
| CAT-LABEL-002 | P1 | Labels Manager New Label form accepts name/scope/color/flags, but Save does not upsert or add the draft to the label list; custom label toggle/filter coverage is blocked. | `macosx/MACKAN/Sources/MACKAN/LabelsManagerSheet.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Labels.swift`; `MACKAN.Service` label routes | open | Failing artifacts: `task11/labels-manager-created.png`, `task11/labels-manager-saved-axpress.png`, `task11/labels-manager-saved-paste.png`, `task11/labels-manager-saved-paste-ax.txt`; dispatcher/module tests passed in `task11-dotnet-module-dispatcher.log` |
| CAT-SEARCH-001 | P1 | Persisted `identifier:Eternal` survived saved-search cleanup and filtered the catalog to empty while the visible search field looked blank; `identifier:` is not currently a supported scoped token in `ModuleSearchQuery`. | `macosx/MACKAN/Sources/MACKANKit/ModuleSearchQuery.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Presentation.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+InstanceState.swift` | open | Failing artifacts: `task12/defaults-before-reset.plist`, `task12/user-defaults-before-catalog-reset.txt`, `task12/after-catalog-state-reset.png`; run cleanup deleted only `mackan.moduleCatalogState` to restore the catalog. |
| CAT-ACTION-001 | P0 | After filtering/searching, the visible selected row and the action model diverged: preview/apply targeted stale `AtomicTechFlags-ATHSS` while the catalog showed `4kSP_Expanded`. This can mutate the wrong module. | `macosx/MACKAN/Sources/MACKAN/CatalogViews.swift`; `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Presentation.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+InstanceState.swift` | open | Failing artifacts: `task12/4ksp-selected-after-escape-click.png`, `task12/install-preview-stale-selection-atomictechflags.png`; cleanup artifacts: `task12/ckan-list-after-install-atomictechflags.txt`, `task12/ckan-list-after-remove-atomictechflags.txt`. |
| OPS-RESULT-001 | P2 | Completed install operation showed successful status and event timeline, but progress rows still displayed `0%` and `0 bytes`; hidden/background apply flows also had limited stable result-sheet visibility. | `macosx/MACKAN/Sources/MACKAN/OperationSheets.swift`; `macosx/MACKAN/Sources/MACKAN/PresentationExtensions.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Operations.swift`; `macosx/MACKAN/Sources/MACKANKit/OperationPresentationState.swift` | open | Partial artifacts: `task12/install-apply-click-result-second.png`, `task12/install-operation-after-refresh-status.png`, `task12/remove-operation-result-initial-windowshot.png`, `task12/upgrade-all-after-apply-final-windowshot.png`; tests passed in `task12-swift-operation-presentation.log` and `task12-dotnet-operation.log`. |
| FILE-EXPORTLIST-001 | P2 | Export Mod List opens a native save panel and service export content is valid, but hidden/offscreen automation could not reliably select a target directory; one attempt selected an unrelated prior Go-to-folder suggestion and required cancelling a Replace prompt. | `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`; native `NSSavePanel` handling | open | Partial artifacts: `task13/export-list-plain-savepanel-windowshot.png`, `task13/export-list-plain-goto-folder-windowshot.png`, `task13/export-list-plain-current-child-windowshot.png`, `task13/export-list-savepanel-anomaly.txt`; functional sidecar outputs under `task13/export-list/`. |

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
| Task 9 AppModelTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9-app-model-tests.log` | `APP-MENU-001`; `APP-MENU-002`; `INST-*` |
| Task 9 LaunchErrorPresentationStateTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9-launch-error-tests.log` | `WIN-ALERT-004` |
| Task 9 CoreMackanInstanceProviderTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9-core-instance-provider-tests-net10.log` | `INST-*`; `APP-MENU-001`; `APP-MENU-002` |
| Task 9 direct Add menu sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/add-menu-open.png` | `APP-MENU-001`; `INST-ADD-001` |
| Task 9 direct Clone menu sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/clone-menu-open.png` | `APP-MENU-001`; `INST-CLONE-001` |
| Task 9 fake instance screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/fake-after-create.png` | `INST-FAKE-001`; `APP-MENU-001` |
| Task 9 Manage Instances screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/manage-open.png` | `INST-MANAGE-001`; `INST-MANAGE-002` |
| Task 9 Finder reveal screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/finder-after-allow.png` | `INST-MANAGE-002` |
| Task 9 rename screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/manage-after-rename-ascii-keycode.png` | `INST-MANAGE-002` |
| Task 9 clone result screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/clone-after-create.png` | `INST-CLONE-001` |
| Task 9 add result screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/add-after-submit.png` | `INST-ADD-001` |
| Task 9 launch command save menu snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/instance-menu-after-launch-command-save.txt` | `INST-LAUNCHCMD-001`; `APP-MENU-002` |
| Task 9 launch command reset menu snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/instance-menu-after-launch-command-reset.txt` | `INST-LAUNCHCMD-001`; `APP-MENU-002` |
| Task 9 launch submenu failure alert screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/launch-failure-alert.png` | `WIN-ALERT-004`; `APP-MENU-002` |
| Task 9 default Launch Game failure alert screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/launch-default-failure-alert.png` | `WIN-ALERT-004`; `APP-MENU-002` |
| Task 9 final cleanup registry snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/ckan-instances-after-final-cleanup.txt` | `INST-MANAGE-001`; `INST-MANAGE-002`; cleanup |
| Task 9 post menu-open/cancel registry snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task9/ckan-instances-after-menu-open-cancel.txt` | `APP-MENU-001`; cleanup |
| Task 10 build log after repository sheet fix | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-build-dev-app-after-repo-fix.log` | `SET-REPO-002` |
| Task 10 Add Repository pre-fix clipped sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/add-repository-open-3.png` | `SET-REPO-002`; defect |
| Task 10 Add Repository pre-fix blank known-source fields | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/add-repository-row-selected-fields.txt` | `SET-REPO-002`; defect |
| Task 10 Add Repository fixed sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/add-repository-after-fix-open.png` | `SET-REPO-002` |
| Task 10 Add Repository fixed known-source fields | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/add-repository-ksp-backup-selected-fields.txt` | `SET-REPO-002` |
| Task 10 repository add result screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/repositories-after-add-backup.png` | `SET-REPO-002` |
| Task 10 repository list after add | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-after-add-backup.txt` | `SET-REPO-002`; `SET-REPO-004` |
| Task 10 repository list after Move Up | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-after-move-up.txt` | `SET-REPO-004` |
| Task 10 repository list after Move Down | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-after-move-down.txt` | `SET-REPO-004` |
| Task 10 repository cleanup snapshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-after-remove-backup.txt` | `SET-REPO-004`; cleanup |
| Task 10 repository refresh running screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/repositories-refresh-running.png` | `SET-REPO-003` |
| Task 10 repository refresh complete screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/repositories-refresh-complete.png` | `SET-REPO-003` |
| Task 10 repository refresh cancel attempt log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/repositories-refresh-cancel-attempt.txt` | `SET-REPO-003` |
| Task 10 repository list after refresh cancel | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10/ckan-repositories-after-refresh-cancel.txt` | `SET-REPO-003`; cleanup |
| Task 10 ModalSheetLayoutPolicyTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-modal-sheet-layout-policy-tests-after-repo-fix.log` | `SET-REPO-002` |
| Task 10 AppModelTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-app-model-tests-after-repo-fix.log` | `SET-REPO-*` |
| Task 10 CoreMackanRepositoryProviderTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-core-repository-provider-tests-net10-after-repo-fix.log` | `SET-REPO-*` |
| Task 10 ServiceDispatcherTests log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task10-service-dispatcher-tests-net10-after-repo-fix.log` | `SET-REPO-*`; sidecar dispatcher |
| Task 11 catalog/inspector Swift test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-swift-catalog-inspector.log` | `CAT-*`; `INS-*`; `WIN-TOOLBAR-002` |
| Task 11 saved-search Swift test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-swift-saved-search.log` | `CAT-SAVEDSEARCH-001` |
| Task 11 module/dispatcher .NET test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11-dotnet-module-dispatcher.log` | `CAT-*`; `INS-*`; `CAT-LABEL-*`; sidecar dispatcher |
| Task 11 catalog loading screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/columns-defaults-restored-after-relaunch.png` | `CAT-LOADING-001`; `INS-EMPTY-001` |
| Task 11 catalog search evidence | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/catalog-search-is-installed-setvalue.png` | `CAT-SEARCH-001` |
| Task 11 Search Syntax evidence | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/search-syntax-menu-open-direct.png` | `CAT-SEARCH-002` |
| Task 11 filter pass state log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/filter-pass-states.txt` | `CAT-FILTER-001` |
| Task 11 tag filter screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/tag-graphics-applied.png` | `CAT-TAG-001` |
| Task 11 sort state screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/catalog-compatible-identifier-sort.png` | `CAT-SORT-001` |
| Task 11 secondary sort state | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/catalog-secondary-sort-identifier-state.txt` | `CAT-SORT-002` |
| Task 11 columns menu screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/columns-menu-open.png` | `CAT-COLUMN-001` |
| Task 11 columns toggled screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/columns-five-hidden-visible.png` | `CAT-COLUMN-001` |
| Task 11 header click retest screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/header-name-sort-click.png` | `CAT-COLUMN-002` |
| Task 11 selected module screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/first-compatible-row-selected.png` | `CAT-ROW-001`; `INS-HEADER-001` |
| Task 11 row no-op screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/row-double-click-staged-install.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/status-cell-click-staged-install.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/pending-cell-click-staged.png` | `CAT-ROW-001`; defect |
| Task 11 toolbar staging screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/toolbar-install-staged-repeat.png` | `WIN-TOOLBAR-002`; `CAT-ACTION-001` |
| Task 11 change preview screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/change-preview-sheet-open.png` | `WIN-SHEET-001`; `OPS-PREVIEW-001`; `CAT-ACTION-001` |
| Task 11 preview cleared screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/preview-closed-cleared.png` | `CAT-ACTION-001`; cleanup |
| Task 11 Labels menu screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/labels-menu-open.png` | `CAT-LABEL-001`; `SID-LABEL-001` |
| Task 11 Labels Manager open screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/labels-manager-open.png` | `CAT-LABEL-002`; `SID-LABEL-001` |
| Task 11 Labels Manager failing save screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/labels-manager-created.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/labels-manager-saved-paste.png` | `CAT-LABEL-002`; defect |
| Task 11 inspector Overview screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/inspector-overview-tab.png` | `INS-OVERVIEW-001`; `INS-HEADER-001` |
| Task 11 inspector Relationships screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/inspector-relationships-tab.png` | `INS-RELATIONSHIP-001` |
| Task 11 inspector Versions screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/inspector-versions-tab.png` | `INS-VERSION-001` |
| Task 11 inspector Contents screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/inspector-contents-tab.png` | `INS-CONTENT-001` |
| Task 11 inspector Resources screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/inspector-resources-tab.png` | `INS-RESOURCE-001` |
| Task 11 Saved Searches menu screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/saved-searches-menu-open-actual.png` | `CAT-SAVEDSEARCH-001` |
| Task 11 Save Search sheet screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/saved-search-save-sheet-open.png` | `CAT-SAVEDSEARCH-001` |
| Task 11 Saved Search saved/deleted screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/saved-searches-menu-after-save.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/saved-searches-menu-after-delete.png` | `CAT-SAVEDSEARCH-001`; cleanup |
| Task 11 final clean catalog screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task11/final-catalog-clean-state.png` | Task 11 cleanup |
| Task 12 catalog persisted-state evidence | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/defaults-before-reset.plist`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/user-defaults-before-catalog-reset.txt`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/after-catalog-state-reset.png` | `CAT-SEARCH-001`; `CAT-SAVEDSEARCH-001`; defect |
| Task 12 deterministic pre-list | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-list-before-4ksp.txt` | Task 12 precondition |
| Task 12 stale selection/action screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/4ksp-selected-after-escape-click.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/install-preview-stale-selection-atomictechflags.png` | `CAT-ACTION-001`; `OPS-PREVIEW-001`; defect |
| Task 12 install operation screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/install-apply-click-result-second.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/install-operation-after-refresh-status.png` | `OPS-RESULT-001`; `OPS-RETRY-001` |
| Task 12 install verification list | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-list-after-install-atomictechflags.txt` | `OPS-RESULT-001`; cleanup target |
| Task 12 hidden/offscreen remove screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/windowshot-hidden-mackan-remove-state.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/remove-staged-atomictechflags-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/remove-preview-resolved-or-stuck-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/remove-after-apply-final-windowshot.png` | `CAT-ACTION-001`; `OPS-PREVIEW-001`; `OPS-RESULT-001` |
| Task 12 remove verification list | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-list-after-remove-atomictechflags.txt` | `OPS-RESULT-001`; cleanup |
| Task 12 Upgrade All screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/upgrade-all-staged-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/upgrade-all-preview-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/upgrade-all-after-apply-final-windowshot.png` | `CAT-ACTION-001`; `OPS-PREVIEW-001`; `OPS-RESULT-001`; deferred provider/recommend/conflict preconditions |
| Task 12 Upgrade All verification list | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-list-after-upgrade-all.txt` | `OPS-RESULT-001` |
| Task 12 replaceable/provider precondition screenshot | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/search-is-replaceable-windowshot.png` | `OPS-PROVIDER-001`; `OPS-CONFLICT-001`; deferred |
| Task 12 registry lock CLI evidence | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-search-athss-before-install.txt`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12/ckan-list-after-install-remove-clean.txt` | `OPS-LOCK-001` |
| Task 12 Swift operation test logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-swift-operation-flow.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-swift-operation-retry.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-swift-operation-presentation.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-swift-operation-activity.log` | `OPS-*` |
| Task 12 .NET operation test logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-dotnet-changeset.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task12-dotnet-operation.log` | `OPS-*`; sidecar dispatcher |
| Task 13 Export Mod List save panel screenshots | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list-plain-savepanel-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list-plain-goto-folder-windowshot.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list-plain-current-child-windowshot.png` | `FILE-EXPORTLIST-001`; partial UI evidence |
| Task 13 Export Mod List save panel anomaly | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list-savepanel-anomaly.txt` | `FILE-EXPORTLIST-001`; defect |
| Task 13 exported mod-list files | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/plainText.txt`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/markdown.md`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/bbcode.txt`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/csv.csv`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-list/tsv.tsv` | `FILE-EXPORTLIST-001` |
| Task 13 exported modpack | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/MACKAN-Audit-Pack.ckan`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-modpack.request.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-modpack.response.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/export-modpack-ignore-check.txt`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/installed-modules-for-modpack.tsv` | `FILE-EXPORTPACK-001` |
| Task 13 install `.ckan` transcript and cleanup | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/install-ckan-file-same-session-transcript.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/install-ckan-file-cleanup-check.txt` | `FILE-CKAN-001`; `OPS-PROVIDER-002`; `OPS-RECOMMEND-002`; cleanup |
| Task 13 import downloads transcript and cleanup | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/import-downloads-same-session-transcript.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/import-download-AtomicTechFlags-ATHSS-1.0.zip`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13/post-file-workflows-cleanup-check.txt` | `FILE-IMPORT-001`; `OPS-IMPORTOPTIONS-001`; cleanup |
| Task 13 Swift file workflow test logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13-swift-import-downloads.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13-swift-ckan-file-install.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13-swift-file-import-flow.log` | `FILE-*`; `OPS-IMPORTOPTIONS-001` |
| Task 13 .NET file workflow logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task13-dotnet-export-operation.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task13-dotnet-export-operation-net10.log` | `BASELINE-DOTNET-001`; `FILE-*`; operation/export providers |

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

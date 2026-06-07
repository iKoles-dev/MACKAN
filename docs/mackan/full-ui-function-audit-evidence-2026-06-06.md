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
| 2026-06-06T22:08:00+0300 | `APP-MENU-004`, `SID-MAINT-001`, `WIN-ALERT-001`, `MAINT-UNMANAGED-001`, `MAINT-HISTORY-001`, `MAINT-STATS-001` | Ran same-session maintenance service transcript on selected instance `Авто KSP` | Scan completed with `changed=false`, `detectedDllCount=4`, `detectedDlcCount=2`; unmanaged files returned 6 rows; installation history returned 33 entries; download statistics returned 3 hosts. Native sheet/alert screenshots were not captured in this hidden/offscreen pass. |
| 2026-06-06T22:09:00+0300 | `MAINT-PLAYTIME-001` | Updated play time through `maintenance.updatePlayTime`, then restored original value | Original hours were `2.116757240138889`; audit update saved `2.126757240138889`; restore returned the value to `2.116757240138889`. |
| 2026-06-06T22:10:00+0300 | `MAINT-CACHE-001`, `MAINT-CACHE-002` | Ran cache info, purge-to-limit and clear-cache routes | Cache started at 127 files / `10.2 GiB` under `/Users/elijahn/.local/share/CKAN/downloads`; no limit was configured so purge-to-limit was a no-op; clear-cache purged 127 files / `10.2 GiB`. Direct filesystem check showed 0 files afterward. |
| 2026-06-06T22:11:00+0300 | `MAINT-DEDUP-001`, `MAINT-REPAIR-001`, `WIN-ALERT-002` | Ran deduplicate and repair registry routes | Deduplicate completed with `No duplicate installed files found.` Repair Registry failed with `An item with the same key has already been added. Key: GameData/ContractPacks`; scan after repair still completed with `changed=false`, `detectedDllCount=4`, `detectedDlcCount=2`. |
| 2026-06-06T22:12:00+0300 | Task 14 automation | Ran maintenance-focused tests | Swift `DownloadStatisticsChartTests` passed 4/4. Scoped .NET `--framework net10.0 --filter FullyQualifiedName~CoreMackanMaintenanceProviderTests` passed 9/9. |
| 2026-06-06T22:20:00+0300 | `SET-GENERAL-001`, `SET-CACHE-001`, `SET-STABILITY-001`, `SET-HOSTS-001`, `SET-FILTERS-001`, `SET-LAUNCH-001`, `SET-AUTH-001` | Ran same-session settings service transcript on selected instance `Авто KSP` | 38 JSON-RPC calls completed without errors. General flags were toggled and restored; cache limit changed from unlimited to a finite audit limit then restored; stability overall and `ContractConfigurator` module override were changed/restored; preferred hosts normalized to `archive.org`, placeholder, `spacedock.info` and restored; global/instance filter duplicates were deduped and restored; launch command `MACKAN_AUDIT_COMMAND` was saved then restored; dummy auth host `mackan-audit.invalid` was added with preview `********oken`, raw token was not exposed, and the dummy host was removed. |
| 2026-06-06T22:21:00+0300 | `SET-COMPAT-001` | Added compatible version `999.999`, restored original version set, then repaired the pre-run default/legacy state | `settings.updateCompatibleVersions` persisted `999.999`, then removing it via the route left a normalized `compatible_ksp_versions.json` with `GameVersionWhenWritten=1.12.5.3190`; deleting the audit-created file restored the pre-run service state: `gameVersionWhenWritten=null`, `compatibleVersionsAreFromDifferentGameVersion=true`, versions `1.8`, `1.9`, `1.10`, `1.11`, `1.12`. |
| 2026-06-06T22:23:00+0300 | Task 15 automation | Ran settings-focused tests | Swift `PreferencesLayoutPolicyTests` passed 2/2. Scoped .NET `--framework net10.0 --filter FullyQualifiedName~CoreMackanSettingsProviderTests` passed 7/7. |
| 2026-06-06T22:27:00+0300 | `WIN-TOOLBAR-006`, `WIN-SHEET-004`, adaptive layout surfaces | Ran adaptive UI/UX screenshot capture against `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` | `run-ui-ux-audit.sh` exited 0 and wrote main/minimum/medium/wide screenshots plus metadata under `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/`. The catalog readiness mode was `inconclusive-wait`; captures are full-screen rather than window-only and include desktop/Dock/widgets plus a system iCloud notification, so they are usable but noisy evidence. |
| 2026-06-06T22:28:00+0300 | `WIN-TOOLBAR-006`, `WIN-SHEET-004`, adaptive layout surfaces | Visually inspected adaptive screenshots | Within the MACKAN window, toolbar/filter/action strip/sidebar/content fit at minimum/medium/wide sizes, and wide mode showed the inspector column/cards with no obvious internal text overlap. The current persisted search was `is:replaceable`, so catalog rows were sparse/empty in the captured state. |
| 2026-06-06T22:29:00+0300 | Accessibility and localization | Ran accessibility smoke and Russian localization key coverage check | `test-accessibility-smoke.sh` passed with VoiceOver label, keyboard shortcut and dynamic type hook coverage. The English/Russian `.strings` key comparison produced zero missing Russian keys. |
| 2026-06-06T22:39:00+0300 | `CAT-ACTION-001` | Added a failing regression test, patched selected-module presentation, then reran targeted and package tests | Pre-fix targeted test failed because `selectedModule` still exposed hidden `HiddenMod` after filtering to visible `VisibleMod`. Patch changed `selectedModule` to resolve from `filteredModules`; targeted retest passed 1/1 and full Swift package passed 294/294. Rebuilt-app visual retest is still pending to avoid taking over the active desktop. |
| 2026-06-06T22:45:00+0300 | `CAT-SEARCH-001` | Added failing identifier-token regression tests, patched search parser/help, then reran targeted and package tests | Pre-fix targeted test failed because `identifier:ModuleManager` and `id:Scatter` returned empty results and Search Syntax did not list identifier search. Patch added `identifier:`/`id:` scoped terms matching module identifiers by prefix; targeted retest passed 2/2 and full Swift package passed 295/295. Rebuilt-app relaunch/search retest is still pending. |
| 2026-06-06T22:54:00+0300 | `MAINT-REPAIR-001` | Patched `Registry.ReindexInstalled()` duplicate-owner handling and reran Repair Registry through rebuilt service on `Авто KSP` | Pre-fix targeted provider test reproduced `failed` repair on duplicate `GameData/ContractPacks` ownership. Core fix groups rebuilt installed-file index entries by path and keeps a deterministic owner instead of throwing. Real rebuilt-service retest returned `completed`, `error=null`; post-repair scan returned `changed=false`, DLL=4, DLC=2. |
| 2026-06-06T22:59:00+0300 | `BASELINE-DOTNET-001` | Made the test project target-framework selection platform-aware and reran the original MACKAN baseline command on macOS | `Tests.csproj` now keeps `net481;net10.0;net10.0-windows` on Windows and uses `net10.0` on non-Windows. `dotnet test Tests/Tests.csproj --filter MACKAN` resolved to Homebrew .NET 10.0.105 in this shell and passed 1451/1451. |
| 2026-06-06T23:20:00+0300 | `CAT-LABEL-002` | Reproduced the Labels Manager AX/paste save failure on a fresh rebuilt app, patched focused name-field commit handling, then retested create/save/delete in the real app | Pre-fix `labels.upsert`/`labels.delete` service smoke passed, but live UI Save stayed disabled because AX/pasted visible text had not committed into `draft.name`. Patch tracks name-field focus, enables Save while the name field is focused, resigns first responder before save, and yields once before reading the draft. Rebuilt-app retest saved `MACKAN Audit Fixed 20260606T2320`, `labels.list` saw it, Delete confirmation appeared, UI delete removed it, and post-delete `labels.list` returned only `Favorites`, `Held`, `Hidden`. |
| 2026-06-06T23:52:00+0300 | `CAT-ROW-001` | Patched catalog cell interaction handling and reran real row/status/pending staging on a rebuilt app | Pre-fix live evidence showed row double-click, status-cell click and pending-cell click did not stage while toolbar Install did. Patch makes pending cells use the same preferred-action toggle as status cells, keeps double-click recognition through SwiftUI row re-renders, and supports low-level real mouse double-click events. Rebuilt-app retest staged `Project Orion` with CGEvent double-click on the Name cell, AX status-cell click, and AX pending-cell click; final Clear returned to `No changes staged`. |
| 2026-06-07T03:06:00+0300 | `CAT-SEARCH-001` | Relaunched the rebuilt app and retested identifier search in the live catalog | Setting the search field to `identifier:4kSP` filtered the visible table to the expected `4kSP` and `4kSP_Expanded` rows; screenshot `/tmp/mackan-full-fix-2026-06-07/cat-search-identifier-4ksp-axset.png`. |
| 2026-06-07T03:16:00+0300 | `CAT-ACTION-001` | Retested staged action target after filtered selection | Preview resolved `Install 4kSP_Expanded 0.2.2`, matching the visible filtered row, and Clear returned the strip to `No changes staged`; screenshots `cat-action-preview-4ksp-expanded-button2.png` and `cat-action-after-explicit-clear2.png`. |
| 2026-06-07T03:33:00+0300 | `WIN-TOOLBAR-004`, `FILE-CKAN-001`, `FILE-IMPORT-001` | Replaced unreliable SwiftUI file import presentation with explicit native panels and retested toolbar actions | `Install from CKAN File` and `Import Downloads` both opened native dialogs from the toolbar. The CKAN-file panel defaulted to Downloads and visibly showed `MACKAN-Audit-Pack.ckan`; AX selection inside the native list remained unreliable, so the deeper file flows stay partial in the matrix. |
| 2026-06-07T03:53:00+0300 | `FILE-EXPORTLIST-001` | Patched export save-panel defaults and exported a plain-text mod list through the UI | The save panel opened at Downloads with title/prompt `Export Mod List`/`Export` and wrote `/Users/elijahn/Downloads/Авто KSP-mods.txt` (3681 bytes); copy retained at `/tmp/mackan-full-fix-2026-06-07/export-ui/auto-ksp-mods-ui-export.txt`. |
| 2026-06-07T04:25:00+0300 | `WIN-TOOLBAR-003`, `WIN-SHEET-002`, `OPS-RESULT-001` | Retested Preview/Apply against `4kSP_Expanded` in the live rebuilt app | Preview opened for `4kSP_Expanded`, Apply completed, Operation Result showed Completed plus real progress/download rows instead of stale `0%`/`0 bytes`, and CKAN CLI cleanup removed the installed test module identifier `4kSPExpanded`. |
| 2026-06-07T05:03:00+0300 | Task 18 targeted regression tests | Ran targeted Swift tests for the new presentation states and sidecar route coverage | `OperationPresentationStateTests`, `PluginRuntimeSupportStateTests`, `SidecarClientTests.testSynchronousRepositoryRefreshUsesExpectedMethodAndParams`, `FileImportFlowStateTests` and `ExportSavePanelConfigurationTests` all passed. |
| 2026-06-07T05:08:26+0300 | `swift test --package-path macosx/MACKAN` | exit 0 | Full Swift package passed: 302 tests, 0 failures. |
| 2026-06-07T05:09:50+0300 | `/opt/homebrew/bin/dotnet test Tests/Tests.csproj --filter MACKAN` | exit 0 | MACKAN .NET suite passed on `net10.0`: 1451 passed, 0 failed, 0 skipped; only existing `SYSLIB0050` warnings appeared. |
| 2026-06-07T05:10:00+0300 | `git diff --check` | exit 0 | No whitespace errors; Git warned that existing `Tests/Tests.csproj` line endings will be normalized to CRLF when touched. |
| 2026-06-07T05:10:00+0300 | `python3 ... matrix proof mapping spot check` | exit 0 | 103 matrix data rows, `proof_missing=[]`, `not_mapped=[]`; evidence summary reports 24 Swift XCTest files and 0 proof-missing rows. |
| 2026-06-07T05:10:00+0300 | `CKAN-CmdLine list --instance "Авто KSP" &#124; rg "4kSP&#124;4kSPExpanded"` | exit 1 | Expected no-match result confirmed the live `4kSP_Expanded` install retest was cleaned up. |
| 2026-06-07T05:20:00+0300 | Task 19 shell UI retest | Opened Mods and Maintenance menus plus toolbar Settings in the rebuilt live app | Mods menu listed Refresh, Upgrade, Apply, Install from File, Import Downloads, Export Mod List and Export Modpack. Maintenance menu listed Scan GameData, Unmanaged Files, History, Play Time, Download Statistics, Deduplicate Files, Repair Registry and Clean Cache. Settings toolbar click opened Preferences. |
| 2026-06-07T05:24:00+0300 | `APP-MENU-003`, `FILE-EXPORTLIST-001`, `FILE-IMPORT-001`, `FILE-CKAN-001` | Drove visible Mods menu routes for file/import/export panels | Visible menu-click opened Install-from-file and Import Downloads native panels; Export Mod List > Plain Text opened the Downloads save panel with `Export Mod List` title and `Export` prompt. Panels were cancelled without file mutation. |
| 2026-06-07T05:25:00+0300 | `FILE-EXPORTPACK-001` | Drove visible Mods menu route for Export Modpack and found clipped sheet content on large installed-module set | The sheet opened, but the large relationship list consumed the presentation so metadata/footer were not reliably visible together; screenshot `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-export-modpack-coordinate-click.png`. |
| 2026-06-07T05:33:24+0300 | `swift test --package-path macosx/MACKAN --filter ModalSheetLayoutPolicyTests.testExportModpackRelationshipListLeavesRoomForMetadataAndFooter` | exit 0 | Added regression policy for bounded Export Modpack relationship-list height; targeted test passed 1/1 after initially failing to compile before the constants existed. |
| 2026-06-07T05:35:00+0300 | `BUILD_ROOT=/Users/elijahn/Library/Caches/MACKAN/task19-shell-fix MACKAN_SELF_CONTAINED=true macosx/MACKAN/scripts/build-dev-app.sh` | exit 0 | Built `/Users/elijahn/Library/Caches/MACKAN/task19-shell-fix/MACKAN.app`; only existing `SYSLIB0050` warnings appeared during sidecar publish. |
| 2026-06-07T05:36:48+0300 | `FILE-EXPORTPACK-001` | Retested Export Modpack sheet in the rebuilt app after the layout fix | The sheet displayed title/metadata, bounded relationship list with scrollbar and Cancel/Export footer together; screenshot `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/export-modpack-sheet-after-layout-fix.png`. |
| 2026-06-07T05:47:00+0300 | `WIN-KEYBOARD-003`, `WIN-KEYBOARD-004` | Attempted to continue live keyboard shortcut proof with persisted disposable `identifier:4kSP` state | Further keyboard/apply verification was blocked by a macOS privacy prompt requiring manual approval for `Codex.app` to access other apps. The prompt resisted automation clicks/keyboard selection, so these rows remain not-run rather than overclaimed. Persisted search was cleared afterward. |
| 2026-06-07T06:18:00+0300 | `CAT-SAVEDSEARCH-001` | Added red/green regression for deleting an applied saved search | Pre-fix targeted Swift test failed with persisted `identifier:Eternal`, `compatible` and `graphics`; after the fix `AppModelTests.testDeletingAppliedSavedCatalogSearchClearsPersistedCatalogFilter` passed, and full `swift test --package-path macosx/MACKAN` passed 304/304. |

## Defects

| Matrix Row | Severity | Summary | Owner Files | Fix Status | Verification |
| --- | --- | --- | --- | --- | --- |
| BASELINE-DOTNET-001 | P0 | Plan baseline `dotnet test Tests/Tests.csproj --filter MACKAN` failed on macOS all-target build because the test project tried to build `net481` and `net10.0-windows` targets. Task 17 makes target-framework selection platform-aware. | `Tests/Tests.csproj`; local dotnet PATH selection | fixed | Failing logs: `dotnet-test-mackan*.log`; fixed log: `task17-repair/dotnet-test-mackan-alltarget-after-baseline-fix.log`; scoped passing log: `dotnet-test-mackan-net10.log`. |
| SET-REPO-002 | P1 | Add Repository sheet clipped its footer buttons and Known Sources row selection did not populate Name/URL fields, blocking the normal canonical-source add workflow. | `macosx/MACKAN/Sources/MACKAN/RepositoryPreferencesView.swift`; `macosx/MACKAN/Sources/MACKANKit/AddRepositorySheetPresentationPolicy.swift`; `macosx/MACKAN/Tests/MACKANKitTests/ModalSheetLayoutPolicyTests.swift` | fixed | Failing artifacts: `task10/add-repository-open-3.png`, `task10/add-repository-row-selected-fields.txt`; fixed artifacts: `task10/add-repository-after-fix-open.png`, `task10/add-repository-ksp-backup-selected-fields.txt`; tests: `task10-modal-sheet-layout-policy-tests-after-repo-fix.log` |
| CAT-ROW-001 | P1 | Catalog row double-click and status/pending cell clicks did not stage the preferred install action, while toolbar Install staged the same selected module immediately. Task 17 patches catalog cell interaction handling. | `macosx/MACKAN/Sources/MACKAN/CatalogViews.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`; `macosx/MACKAN/Sources/MACKANKit/ModuleActionPresentationState.swift` | fixed | Failing artifacts: `task11/row-double-click-staged-install.png`, `task11/status-cell-click-staged-install.png`, `task11/pending-cell-click-staged.png`; fixed artifacts: `task17-row-live/row-double-click-cgevent-after-state-patch.png`, `task17-row-live/status-cell-click-final.png`, `task17-row-live/pending-cell-click-final.png`, `task17-row-live/row-final-clean.png`; tests/logs: `task17-row/swift-build-after-row-state-patch.log`, `task17-row/swift-module-action-after-row-state-patch.log`, `task17-row/swift-package-after-row-patch.log`. |
| CAT-LABEL-002 | P1 | Labels Manager New Label form visually accepted name/scope/color/flags through AX/paste paths, but Save did not upsert because the focused TextField editor value had not committed into `draft.name`. Task 17 patches name-field focus/commit handling before save. | `macosx/MACKAN/Sources/MACKAN/LabelsManagerSheet.swift`; `macosx/MACKAN/Sources/MACKANKit/AppModel+Labels.swift`; `MACKAN.Service` label routes | fixed | Failing artifacts: `task11/labels-manager-created.png`, `task11/labels-manager-saved-axpress.png`, `task11/labels-manager-saved-paste.png`, `task17-label-live/after-setvalue-save.png`; fixed artifacts: `task17-label-fixed/after-ax-setvalue-save.png`, `task17-label-fixed/delete-confirmation.png`, `task17-label-fixed/after-ui-delete.png`, `task17-label-fixed/labels-list-after-ui-save-summary.json`, `task17-label-fixed/labels-list-after-ui-delete-summary.json`; tests/logs: `task17-label-live/swift-build-after-label-patch.log`, `task17-label-live/swift-appmodel-after-label-patch.log`, `task17-label-fixed/swift-package-after-label-patch.log`. |
| CAT-SEARCH-001 | P1 | Persisted `identifier:Eternal` survived saved-search cleanup and filtered the catalog to empty while the visible search field looked blank; `identifier:` was parsed as literal plain text. Task 17 patches `identifier:` and `id:` as scoped identifier-prefix tokens and documents them in Search Syntax. | `macosx/MACKAN/Sources/MACKANKit/ModuleSearchQuery.swift`; `macosx/MACKAN/Sources/MACKANKit/ModuleSearchHelp.swift`; `macosx/MACKAN/Tests/MACKANKitTests/AppModelTests.swift` | fixed | Failing artifacts: `task12/defaults-before-reset.plist`, `task12/user-defaults-before-catalog-reset.txt`, `task12/after-catalog-state-reset.png`; fix logs: `task17-search/identifier-search-targeted.log`, `task17-search/swift-package.log`; live fixed screenshot: `/tmp/mackan-full-fix-2026-06-07/cat-search-identifier-4ksp-axset.png`. |
| CAT-SAVEDSEARCH-001 | P2 | Deleting a saved search removed the saved entry but left the active applied search/filter/tag in persisted catalog state, so a stale `identifier:Eternal` query could survive cleanup and affect the next launch. Task 20 clears the active catalog filter only when it still matches the deleted saved search. | `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`; `macosx/MACKAN/Tests/MACKANKitTests/AppModelTests.swift` | fixed | Red/green proof: `AppModelTests.testDeletingAppliedSavedCatalogSearchClearsPersistedCatalogFilter` failed before the fix and passed after it; full Swift package passed 304/304. |
| CAT-ACTION-001 | P0 | After filtering/searching, the visible selected row and the action model diverged: preview/apply targeted stale `AtomicTechFlags-ATHSS` while the catalog showed `4kSP_Expanded`. This can mutate the wrong module. Task 17 patches `selectedModule` so toolbar/action presentation cannot resolve a hidden filtered-out module. | `macosx/MACKAN/Sources/MACKANKit/AppModel+Presentation.swift`; `macosx/MACKAN/Tests/MACKANKitTests/AppModelTests.swift`; related UI callers in `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift` | fixed | Failing artifacts: `task12/4ksp-selected-after-escape-click.png`, `task12/install-preview-stale-selection-atomictechflags.png`; fix logs: `task17/selected-module-hidden-filter-targeted.log`, `task17/swift-package.log`; fixed screenshots: `/tmp/mackan-full-fix-2026-06-07/cat-action-preview-4ksp-expanded-button2.png`, `/tmp/mackan-full-fix-2026-06-07/cat-action-after-explicit-clear2.png`, `/tmp/mackan-full-fix-2026-06-07/apply-operation-result-after-apply-correct-click.png`. |
| OPS-RESULT-001 | P2 | Completed install operation showed successful status and event timeline, but progress rows still displayed `0%` and `0 bytes`; hidden/background apply flows also had limited stable result-sheet visibility. Task 18 filters superseded zero-progress completed events from the displayed timeline. | `macosx/MACKAN/Sources/MACKAN/OperationSheets.swift`; `macosx/MACKAN/Sources/MACKANKit/OperationTimelinePresentationState.swift`; `macosx/MACKAN/Sources/MACKANKit/OperationPresentationState.swift`; `macosx/MACKAN/Tests/MACKANKitTests/OperationPresentationStateTests.swift` | fixed | Partial artifacts: `task12/install-apply-click-result-second.png`, `task12/install-operation-after-refresh-status.png`, `task12/remove-operation-result-initial-windowshot.png`, `task12/upgrade-all-after-apply-final-windowshot.png`; fixed screenshot: `/tmp/mackan-full-fix-2026-06-07/apply-operation-result-after-apply-correct-click.png`; tests: `OperationPresentationStateTests`. |
| WIN-TOOLBAR-004 | P0 | Enabled `Install from File` and `Import Downloads` toolbar/menu actions did not reliably present SwiftUI `fileImporter`, leaving native file workflows stuck before file selection. Task 18 replaces those entry points with explicit `NSOpenPanel` presentation and reset handling. | `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`; `macosx/MACKAN/Sources/MACKANKit/FileImportPanelConfiguration.swift`; `macosx/MACKAN/Tests/MACKANKitTests/FileImportFlowStateTests.swift` | fixed | Fixed screenshots: `/tmp/mackan-full-fix-2026-06-07/win-toolbar-install-from-file-fixed-open-panel.png`, `/tmp/mackan-full-fix-2026-06-07/win-toolbar-import-downloads-fixed-open-panel.png`, `/tmp/mackan-full-fix-2026-06-07/file-ckan-install-panel-with-downloads-file.png`; tests: `FileImportFlowStateTests`. |
| FILE-EXPORTLIST-001 | P2 | Export Mod List opened a native save panel and service export content was valid, but the panel inherited unrelated system state and could target a stale folder/suggested file. Task 18 pins the export panel to Downloads with stable title, prompt and filename. | `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`; `macosx/MACKAN/Sources/MACKANKit/ExportSavePanelConfiguration.swift`; `macosx/MACKAN/Tests/MACKANKitTests/ExportSavePanelConfigurationTests.swift` | fixed | Partial artifacts: `task13/export-list-plain-savepanel-windowshot.png`, `task13/export-list-plain-goto-folder-windowshot.png`, `task13/export-list-savepanel-anomaly.txt`; fixed artifacts: `/tmp/mackan-full-fix-2026-06-07/file-export-list-fixed-save-panel-open-downloads.png`, `/Users/elijahn/Downloads/Авто KSP-mods.txt`, `/tmp/mackan-full-fix-2026-06-07/export-ui/auto-ksp-mods-ui-export.txt`; tests: `ExportSavePanelConfigurationTests`. |
| FILE-EXPORTPACK-001 | P1 | Export Modpack sheet opened from the real Mods menu, but on the selected large instance the relationship picker list could consume the sheet so metadata and footer controls were not reliably visible together. Task 19 bounds the relationship list and keeps metadata/footer visible. | `macosx/MACKAN/Sources/MACKAN/ExportModpackSheet.swift`; `macosx/MACKAN/Sources/MACKANKit/ModalSheetLayoutPolicy.swift`; `macosx/MACKAN/Tests/MACKANKitTests/ModalSheetLayoutPolicyTests.swift` | fixed | Failing screenshot: `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-export-modpack-coordinate-click.png`; fixed screenshot: `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/export-modpack-sheet-after-layout-fix.png`; test: `ModalSheetLayoutPolicyTests.testExportModpackRelationshipListLeavesRoomForMetadataAndFooter`. |
| MAINT-REPAIR-001 | P1 | Repair Registry failed on the selected real instance with duplicate key `GameData/ContractPacks`; MACKAN surfaced a typed failed result, but the repair did not complete. Task 17 fixes duplicate installed-file owner handling during registry reindexing. | `Core/Registry/Registry.cs`; `Tests/Core/Registry/Registry.cs`; service retest through rebuilt `MACKAN.Service.dll` | fixed | Failing artifact: `task14/maintenance-service-transcript.json`; fixed artifacts: `task17-repair/repair-registry-retest-transcript.json`, `task17-repair/repair-registry-retest-summary.json`; tests: `task17-repair/dotnet-registry-repair-duplicate-owner-targeted.log`, `task17-repair/dotnet-maintenance-provider-net10.log`, `task17-repair/dotnet-core-registry-net10.log`, `task17-repair/dotnet-mackan-net10-after-repair-fix.log`. |

## Screenshots and Artifacts

| Artifact | Path | Matrix Rows |
| --- | --- | --- |
| Baseline git status | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/git-status-short.txt` | Task 6 |
| Baseline process state | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/processes-before-baseline.txt` | Task 6 |
| Swift test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/swift-test.log` | Task 6 |
| .NET all-target failure log | `/tmp/mackan-full-ui-function-audit-2026-06-06/baseline/dotnet-test-mackan-homebrew-sdk10.log` | `BASELINE-DOTNET-001` |
| .NET all-target fixed baseline log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/dotnet-test-mackan-alltarget-after-baseline-fix.log` | `BASELINE-DOTNET-001`; fixed |
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
| Task 14 baseline maintenance state | `/tmp/mackan-full-ui-function-audit-2026-06-06/task14/baseline-maintenance-state.jsonl`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task14/baseline-maintenance-state.pretty.json` | Task 14 precondition |
| Task 14 maintenance service transcript and summary | `/tmp/mackan-full-ui-function-audit-2026-06-06/task14/maintenance-service-transcript.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task14/maintenance-service-summary.json` | `APP-MENU-004`; `SID-MAINT-001`; `WIN-ALERT-001`; `WIN-ALERT-002`; `MAINT-*`; defect |
| Task 14 Swift download statistics chart test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task14-swift-download-statistics-chart.log` | `MAINT-STATS-001` |
| Task 14 .NET maintenance provider test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task14-dotnet-maintenance-net10.log` | `MAINT-*`; `WIN-ALERT-*`; sidecar dispatcher |
| Task 15 settings service transcript and summaries | `/tmp/mackan-full-ui-function-audit-2026-06-06/task15/settings-service-transcript.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task15/settings-service-summary.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task15/settings-service-summary-post-restore.json` | `SET-GENERAL-001`; `SET-CACHE-001`; `SET-COMPAT-001`; `SET-STABILITY-001`; `SET-HOSTS-001`; `SET-FILTERS-001`; `SET-LAUNCH-001`; `SET-AUTH-001` |
| Task 15 compatibility post-restore check | `/tmp/mackan-full-ui-function-audit-2026-06-06/task15/compatible-versions-after-file-restore.jsonl` | `SET-COMPAT-001`; cleanup |
| Task 15 Swift preferences layout test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task15-swift-preferences-layout.log` | `SET-*`; Preferences shell layout |
| Task 15 .NET settings provider test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task15-dotnet-settings-net10.log` | `SET-*`; sidecar dispatcher |
| Task 16 adaptive UI/UX harness log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task16-run-ui-ux-audit.log` | `WIN-TOOLBAR-006`; `WIN-SHEET-004`; adaptive layout |
| Task 16 adaptive screenshots and metadata | `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/main-window.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/adaptive-minimum.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/adaptive-medium.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/adaptive-wide.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/audit-metadata.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/ui-ux-audit.md`; `/tmp/mackan-full-ui-function-audit-2026-06-06-adaptive/window-summary.txt` | `WIN-TOOLBAR-006`; `WIN-SHEET-004`; adaptive layout |
| Task 16 accessibility smoke log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task16-accessibility-smoke.log` | accessibility smoke |
| Task 16 localization missing-key check | `/tmp/mackan-full-ui-function-audit-2026-06-06/task16-localization-missing-ru-keys.txt` | localization; zero missing Russian keys |
| Task 17 hidden-selection targeted test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17/selected-module-hidden-filter-targeted.log` | `CAT-ACTION-001`; fixed-automated |
| Task 17 full Swift package test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17/swift-package.log` | `CAT-ACTION-001`; regression |
| Task 17 search identifier targeted test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-search/identifier-search-targeted.log` | `CAT-SEARCH-001`; fixed-automated |
| Task 17 search full Swift package test log | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-search/swift-package.log` | `CAT-SEARCH-001`; regression |
| Task 17 Labels Manager pre-fix live repro | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-live/after-setvalue-save.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-live/labels-list-after-setvalue-save-summary.json` | `CAT-LABEL-002`; defect |
| Task 17 Labels Manager fixed live create/delete | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/after-ax-setvalue-save.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/delete-confirmation.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/after-ui-delete.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/labels-list-after-ui-save-summary.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/labels-list-after-ui-delete-summary.json` | `CAT-LABEL-002`; fixed |
| Task 17 Labels Manager Swift logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-live/swift-build-after-label-patch.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-live/swift-appmodel-after-label-patch.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-label-fixed/swift-package-after-label-patch.log` | `CAT-LABEL-002`; regression |
| Task 17 catalog row fixed live staging | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row-live/row-double-click-cgevent-after-state-patch.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row-live/status-cell-click-final.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row-live/pending-cell-click-final.png`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row-live/row-final-clean.png` | `CAT-ROW-001`; fixed |
| Task 17 catalog row Swift logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row/swift-build-after-row-state-patch.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row/swift-module-action-after-row-state-patch.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-row/swift-package-after-row-patch.log` | `CAT-ROW-001`; regression |
| Task 17 Repair Registry real retest | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/repair-registry-retest-transcript.json`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/repair-registry-retest-summary.json` | `MAINT-REPAIR-001`; fixed |
| Task 17 Repair Registry .NET test logs | `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/dotnet-registry-repair-duplicate-owner-targeted.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/dotnet-maintenance-provider-net10.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/dotnet-core-registry-net10.log`; `/tmp/mackan-full-ui-function-audit-2026-06-06/task17-repair/dotnet-mackan-net10-after-repair-fix.log` | `MAINT-REPAIR-001`; registry regression |
| Task 18 search/action live retest screenshots | `/tmp/mackan-full-fix-2026-06-07/cat-search-identifier-4ksp-axset.png`; `/tmp/mackan-full-fix-2026-06-07/cat-action-preview-4ksp-expanded-button2.png`; `/tmp/mackan-full-fix-2026-06-07/cat-action-after-explicit-clear2.png` | `CAT-SEARCH-001`; `CAT-ACTION-001`; fixed |
| Task 18 apply/result live retest screenshots | `/tmp/mackan-full-fix-2026-06-07/apply-preview-before-apply-sheet.png`; `/tmp/mackan-full-fix-2026-06-07/apply-operation-result-after-apply-correct-click.png`; `/tmp/mackan-full-fix-2026-06-07/apply-operation-result-after-close-correct.png` | `WIN-TOOLBAR-003`; `WIN-SHEET-002`; `OPS-RESULT-001`; fixed |
| Task 18 file-panel live retest screenshots | `/tmp/mackan-full-fix-2026-06-07/win-toolbar-install-from-file-fixed-open-panel.png`; `/tmp/mackan-full-fix-2026-06-07/win-toolbar-import-downloads-fixed-open-panel.png`; `/tmp/mackan-full-fix-2026-06-07/file-ckan-install-panel-with-downloads-file.png` | `WIN-TOOLBAR-004`; `FILE-CKAN-001`; `FILE-IMPORT-001`; fixed/partial |
| Task 18 export-list live retest artifacts | `/tmp/mackan-full-fix-2026-06-07/file-export-list-fixed-save-panel-open-downloads.png`; `/Users/elijahn/Downloads/Авто KSP-mods.txt`; `/tmp/mackan-full-fix-2026-06-07/export-ui/auto-ksp-mods-ui-export.txt` | `FILE-EXPORTLIST-001`; fixed |
| Task 18 new Swift proof files | `macosx/MACKAN/Tests/MACKANKitTests/PluginRuntimeSupportStateTests.swift`; `macosx/MACKAN/Tests/MACKANKitTests/ExportSavePanelConfigurationTests.swift`; `macosx/MACKAN/Sources/MACKANKit/PluginRuntimeSupportState.swift`; `macosx/MACKAN/Sources/MACKANKit/ExportSavePanelConfiguration.swift` | `SET-PLUGINS-001`; `FILE-EXPORTLIST-001`; proof mapped |
| Task 19 shell UI launch/status/settings screenshots | `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/main-after-launch.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/catalog-search-cleared.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/settings-toolbar-click.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/relaunch-after-privacy-allow.png` | `SID-STATUS-001`; `WIN-TOOLBAR-006`; shell UI |
| Task 19 menu screenshots | `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-open.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/maintenance-menu-open.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-install-from-file-visible-click-panel.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-import-downloads-visible-click-panel.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-export-list-save-panel.png` | `APP-MENU-003`; `APP-MENU-004`; file/export menu routes |
| Task 19 Export Modpack layout fix screenshots | `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/mods-menu-export-modpack-coordinate-click.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/export-modpack-sheet-after-layout-fix.png` | `FILE-EXPORTPACK-001`; fixed |
| Task 19 privacy blocker screenshots | `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/after-swift-privacy-allow.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/after-privacy-tab-space.png`; `/tmp/mackan-full-fix-2026-06-07/task19-shell-ui/after-privacy-return.png` | `WIN-KEYBOARD-003`; `WIN-KEYBOARD-004`; blocker |

## Automated Proof Mapping Summary

| Item | Value |
| --- | --- |
| Matrix rows mapped | 103 |
| Swift XCTest files found | 24 |
| .NET MACKAN test files found | 9 |
| Script gates found | 37 |
| Rows with `Automation Proof` still `not mapped` | 0 |
| `proof-missing` rows | 0 |
| `proof-missing` row IDs | `(none)` |

Notes: Task 5 maps existing automation only; mapped rows remain `not-run` until Task 6 or later execution actually runs the proof. Task 18 adds direct Swift proof for the Plugins unsupported-runtime presentation state and the synchronous `SidecarClient.refreshRepositories` fallback, so the previous `proof-missing` rows are now mapped.

## Baseline Command Run Summary

| Item | Result |
| --- | --- |
| Swift package tests | pass: 291 passed, 0 failed |
| .NET MACKAN all-target command | fixed/pass: `dotnet test Tests/Tests.csproj --filter MACKAN` passed 1451/1451 on macOS after platform-aware target selection |
| .NET MACKAN scoped `net10.0` command | pass: 1450 passed, 0 failed, 0 skipped |
| UI/UX harness script test | pass |
| Accessibility smoke script test | pass |
| Development app build | pass: `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app` |
| Bundle verification | pass |
| GUI launch verification | pass: no Terminal, 1 visible window |

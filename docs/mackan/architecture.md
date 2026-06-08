# MACKAN Architecture

## Decision

MACKAN will be a SwiftUI/AppKit macOS application backed by a dedicated .NET
sidecar service that references CKAN Core. The sidecar exposes typed JSON-RPC
APIs over a local process channel. Swift owns presentation, macOS integration,
menus, sheets, preferences, notifications, and accessibility. C# owns CKAN
domain behavior.

This avoids two bad outcomes:

- Rewriting CKAN dependency resolution and install transactions in Swift.
- Reusing the existing WinForms UI or ConsoleUI and calling it native.

## Components

### `Core/`

Existing upstream CKAN domain library. MACKAN must treat this as the source of
truth for metadata, repositories, dependency resolution, registry transactions,
downloads, cache handling, installed files, exports, and game instance logic.

### `MACKAN.Service/`

.NET service target. It references `Core/CKAN-core.csproj` and exposes stable
JSON contracts for the native app. Implemented so far:

- `app.health`
- `app.version` returns MACKAN service, CKAN Core, protocol, .NET runtime,
  operating system, and process architecture metadata for diagnostics and
  packaging checks
- `app.checkForUpdates` returns CKAN Core stable/dev-build update status,
  release notes, download URLs, and a manual-install message until signed
  in-app installation is available
- `instances.add`
- `instances.clone`
- `instances.cloneOptions`
- `instances.fake`
- `instances.list`
- `instances.setDefault`
- `instances.remove`
- `instances.rename`
- `instances.launchOptions` returns configured/default launch command lines and
  unsuppressed incompatible installed modules for native launch warnings; it
  also reads legacy Windows CKAN `GUIConfig.xml` command-line settings when no
  JSON GUI config exists
- `instances.updateLaunchOptions`
- `instances.launch` accepts a suppression flag and starts the selected game
  through CKAN Core
- `mods.list`
- `mods.details`
- `mods.setAutoInstalled`
- `repositories.list`
- `repositories.available`
- `repositories.add`
- `repositories.remove`
- `repositories.setPriority`
- `repositories.refresh`
- `mods.resolveChanges`
- `operations.applyChanges`
- `operations.startApplyChanges`
- `operations.installCkanFiles`
- `operations.startInstallCkanFiles`
- `operations.importDownloads`
- `operations.startImportDownloads`
- `operations.status`
- `operations.cancel`
- `exports.modList`
- `exports.modpack`
- `maintenance.scan`
- `maintenance.unmanagedFiles`
- `maintenance.history`
- `maintenance.playTime`
- `maintenance.updatePlayTime`
- `maintenance.downloadStatistics`
- `maintenance.cacheInfo`
- `maintenance.clearCache`
- `maintenance.purgeCacheToLimit`
- `maintenance.deduplicate`
- `maintenance.repairRegistry`
- `settings.get`
- `settings.update`
- `settings.general`
- `settings.updateGeneral`
- `settings.compatibleVersions`
- `settings.updateCompatibleVersions`
- `settings.stabilityTolerance`
- `settings.updateStabilityTolerance`
- `settings.updateModuleStabilityTolerance`
- `settings.preferredHosts`
- `settings.updatePreferredHosts`
- `settings.installFilters`
- `settings.updateInstallFilters`
- `settings.authTokens`
- `settings.addAuthToken`
- `settings.removeAuthToken`
- `labels.list`
- `labels.toggleModule`
- `labels.upsert`
- `labels.delete`

The first service milestone is instance/catalog discovery plus targeted
repository settings mutation. Repository refresh now returns captured CKAN Core
message/progress events with the final refresh result. The first operation
milestone is read-only install/remove/upgrade/replace change-set preview. The
second operation milestone is a Core-backed apply path that returns captured
operation events, and the primary native Apply Changes, local `.ckan` install,
and import-download flows now start asynchronously through
`operations.startApplyChanges`, `operations.startInstallCkanFiles`, and
`operations.startImportDownloads`. Swift keeps a long-lived stdio sidecar
session per `SidecarClient`, so same-process endpoints such as
`operations.status` can observe operation state while the operation sheet polls,
and `operations.cancel` can request cancellation through the operation's CKAN
Core cancellation token. Richer live event streaming and broader lock handling
remain pending. Persistent
recommendation suppression preferences are stored in the selected instance's
existing `GUIConfig.json` `SuppressRecommendations` value via
`settings.recommendations` and `settings.updateRecommendations`. Explicit
stale-lock removal is routed through `maintenance.removeRegistryLock`, which
deletes only the selected instance's `registry.locked` file after the native UI
has shown the path and required confirmation.
General Windows GUI preferences are split by CKAN's existing ownership model:
`settings.general`/`settings.updateGeneral` store per-instance GUI preferences
such as update checks on launch, repository refresh on launch, and update-column
auto-sort in `GUIConfig.json`, while the dev-build channel flag continues to
write through CKAN Core `IConfiguration.DevBuilds`.

### `macosx/MACKAN/`

SwiftUI/AppKit app package. It launches and supervises `MACKAN.Service`, maps
JSON DTOs to view models, and renders native macOS UI. It must not parse human
CLI output for product behavior. Temporary `dotnet run -- --health` fallback is
allowed only for developer health checks, not user-facing release features.

Current package layout:

- `Sources/MACKAN/` contains the native app entrypoint and views.
- `Sources/MACKANKit/` contains app models and sidecar protocol code, including
  the persistent stdio transport that supervises the sidecar process.
- `Tests/MACKANKitTests/` contains Swift contract tests for JSON-RPC decoding.
- `scripts/build-dev-app.sh` creates a local development bundle with a
  self-contained sidecar and ad-hoc signing. It defaults to
  `~/Library/Caches/MACKAN/build/MACKAN.app` because FileProvider-managed
  folders such as `Documents` can reattach Finder metadata that breaks strict
  codesign verification.
- `scripts/generate-app-icon.sh` creates a deterministic `MACKAN.icns` from a
  scripted AppKit drawing and `iconutil`; development and release bundles use
  it through `CFBundleIconFile`.
- `scripts/package-dmg.sh` packages an existing or freshly built app bundle
  into a compressed DMG, stages the app with an `/Applications` symlink,
  verifies codesign by default, and runs `hdiutil verify`. It is suitable for
  local distribution checks; public releases still require Developer ID
  signing, hardened runtime, notarization, and stapling. Passing `--universal`
  builds a fat Swift executable and emits
  `~/Library/Caches/MACKAN/build/MACKAN-<version>-universal.dmg`.
- `scripts/verify-app-bundle.sh` verifies a local `.app` layout in single or
  universal mode. It checks `Info.plist`, the app executable architecture,
  `CFBundleIconFile`/`.icns` when required, direct or arch-specific sidecar
  placement, strict codesign status, and the host sidecar's `app.version`
  JSON-RPC response. `build-dev-app.sh` runs this verifier by default after
  signing.
- `scripts/release-dmg.sh` runs the public-release packaging chain when
  Developer ID credentials are available: build universal app, sign the app
  with `codesign --options runtime --timestamp`, verify the bundle, package and
  sign the DMG, submit it with `xcrun notarytool --output-format json`, require
  an `Accepted` notary status, then staple and validate the ticket with
  `xcrun stapler`. It then writes a release provenance JSON manifest next to
  the DMG by default. Non-dry public release runs fail fast before
  building if the requested Developer ID identity is not discoverable through
  `security find-identity` or the notary keychain profile does not validate.
  When `MACKAN_SIGNING_KEYCHAIN_PATH` is set, both `release-dmg.sh` and
  `release-readiness.sh --require-release-credentials` use that explicit
  keychain for Developer ID identity lookup and notarytool profile
  validation/submission, so CI promotion validates and submits from the same
  ephemeral keychain that imported the certificate and stored notarytool
  credentials.
- `scripts/generate-release-provenance.sh` records the app version, bundle id,
  DMG SHA-256, artifact sizes, git revision/dirty state, app signing authority,
  app Team ID, app hardened-runtime presence, DMG signing authority,
  notarytool submission status/id, raw notarytool JSON SHA-256/size, and final
  `codesign`/`hdiutil`/`spctl`/`stapler` verification booleans. The default
  output path is `<DMG>.provenance.json`; `release-dmg.sh --provenance PATH`
  can pin it explicitly.
- `scripts/verify-release-artifact.sh` verifies that the current DMG bytes still
  match the provenance manifest SHA-256/size/path/version metadata, reruns
  `hdiutil verify`, and in `--require-public-release` mode also requires live
  DMG `codesign`, Gatekeeper `spctl`, stapler validation, Developer ID
  Application app and DMG authority, `dmgNotarizationStatus=Accepted`,
  non-empty `dmgNotarizationId`, matching `<DMG>.notary.json` `status`/`id`
  plus notary JSON SHA-256/size,
  app hardened runtime, non-empty `source.gitRevision`, and
  `source.gitDirty=false`. `release-dmg.sh` runs this
  public-release verifier after generating provenance.
- `scripts/verify-app-launch.sh` runs the no-Terminal launch smoke check. It
  opens the app through Launch Services, waits for the new `MACKAN` process,
  verifies the process path comes from the tested bundle, checks that no new
  `Terminal.app` process appeared, verifies that System Events can see a visible
  MACKAN window, and cleans up only the process it launched.
- `scripts/run-ui-ux-audit.sh` wraps the real-app public-RC visual audit setup:
  it fails fast when the active macOS desktop is locked, runs the launch smoke
  verifier, captures a non-empty main-window screenshot, records a window
  summary with the launched PID, requires a parseable `MACKAN window count: N`
  result, rejects `N=0`, captures minimum/medium/wide adaptive screenshots,
  writes `audit-metadata.json` with the app path, UTC timestamp, launch PID, and
  adaptive breakpoint dimensions, and writes a checklist/evidence bundle for the
  mandatory computer-use/manual inspection pass.
- `scripts/verify-ui-ux-audit-evidence.sh` verifies the completed visual-audit
  bundle after manual/computer-use inspection: launch evidence, non-empty
  main-window screenshot, non-empty adaptive screenshots for minimum, medium,
  and wide main-window states, parseable audit metadata whose launch PID matches
  launch evidence and whose adaptive dimensions match the runner, visible-window
  summary whose PID matches launch evidence, checked mandatory checklist items,
  and a checked
  no-blocking-defects confirmation.
- `scripts/release-check.sh` runs the non-credential release gate: Swift tests,
  net10 MACKAN tests, NuGet vulnerability audits, packaging helper tests,
  whitespace checks, universal DMG packaging, bundle verification, local
  provenance manifest generation, local artifact verification, and optional
  Launch Services smoke. The macOS CI job calls it with `--skip-launch` because
  Launch Services smoke is a local interactive-session gate, then runs the
  artifact verifier and uploads both the universal DMG and its provenance JSON.
- `.github/workflows/mackan-release.yml` is the credential-backed promotion
  workflow. It uploads the signed/notarized DMG, provenance JSON, raw
  notarytool submit JSON, and SHA-256 checksums as separate artifacts so the
  public release can be audited against both the derived manifest and Apple's
  submission response.

### Packaging

The release app bundles:

- SwiftUI app executable.
- Self-contained .NET sidecar. The default development bundle publishes the
  host architecture (`osx-arm64` or `osx-x64`) directly under
  `Resources/MACKAN.Service`. The universal local package bundles both
  architectures under `Resources/MACKAN.Service/osx-arm64` and
  `Resources/MACKAN.Service/osx-x64`; `SidecarClient` selects the current
  runtime identifier first and falls back to the legacy direct sidecar layout
  for development bundles.
- CKAN assets and localization resources.
- Signed helper executables with hardened runtime.

Distribution target is a signed and notarized DMG. App Store sandboxing is not
the primary target because CKAN must modify arbitrary KSP install directories.
Local release automation exists, but final release acceptance still requires a
credentials-backed notarization run and clean-Mac first-launch verification.

## Data Flow

1. App starts and creates a persistent stdio session to the sidecar.
2. App requests version, health, known instances, current instance, and cached
   repository state.
3. User can add an existing game folder through the native Instance menu;
   Swift sends `instances.add` with the chosen folder path and name, C# validates
   and registers it through CKAN Core `GameInstanceManager.AddInstance`, and
   Swift selects the added instance.
4. User can clone a valid game folder through the native Instance menu; Swift
   requests `instances.cloneOptions` for game-specific optional paths, then
   sends `instances.clone` with source instance, destination path, new name,
   stock-folder sharing choice, and selected leave-empty paths. C# copies via
   CKAN Core
   `GameInstanceManager.CloneInstance`, clones non-Steam launch command lines,
   and Swift selects the cloned instance.
5. User can create a fake test/dev game instance through the native Instance
   menu; Swift sends `instances.fake` with name, path, game, version, optional
   KSP DLC versions, and default-instance choice, C# validates with CKAN Core
   `KnownGames`/`GameVersion` and creates the folder structure through
   `GameInstanceManager.FakeInstance`.
   Disposable provider coverage runs the instance-management flows against real
   disposable KSP folders with injectable `IConfiguration` and
   `RepositoryDataManager`, covering add, clone, fake, rename, set-default,
   remove, and configured launch-option copying without relying on global
   sidecar state.
6. User selects an instance.
7. App requests module list and CKAN Core labels for the selected instance. The
   sidecar returns the full catalog plus explicit installed,
   compatible, cached, new, update, replacement, auto-installed, autodetected,
   compatibility, size, date, download-count, and metadata tag fields plus the
   selected instance's catalog-applicable `ModuleLabelList` summaries and the
   cross-instance manageable label list for the Labels manager. Module summaries
   include abstract, description, and localization fields for native
   `desc:`/`lang:` matching. Swift applies native filter/search/sort/tag/label/
   column state locally, including Windows-style scoped search tokens for
   available summary fields, normalized `label:` matching against selected-instance
   CKAN labels, locally persisted current catalog state, locally persisted saved
   searches, and locally persisted table-column visibility, while heavier
   server-side paging remains available if large-list profiling requires it.
8. Repository settings changes call the service directly and return the updated
   ordered repository list. Core provider coverage injects disposable
   configuration and repository data to verify list, add, duplicate rejection,
   priority changes, removal, and registry persistence against real CKAN
   registry files.
9. Settings panes call the service directly and mutate CKAN Core configuration
   rather than duplicating settings files in Swift. Core provider coverage
   injects disposable configuration and repository data to verify cache
   path/limit persistence, compatible-version files, stability tolerance files,
   preferred-host priority, install filters, and auth-token masking/list/add/remove
   behavior.
10. Launch commands and Settings Launch preferences ask `instances.launchOptions`
   for configured/default command lines and warning data. Launching calls
   `instances.launch`; saving command-line preferences calls
   `instances.updateLaunchOptions`. Legacy Windows CKAN `GUIConfig.xml`
   command-line arguments are imported into the same command list. Suppressed
   incompatible-mod warnings are written through CKAN Core's existing
   suppression file.
11. User stages mod changes locally in Swift view state.
12. App asks the service to resolve the staged change set. Replace selections
   travel as a dedicated `replace` identifier list so the preview can show both
   the installed module being replaced and the replacement module being added.
13. Service returns exact installs/removals/upgrades/replacements, dependency
   additions, reverse dependency removals, unused auto removals, conflicts,
   warnings, and provider alternatives. Provider alternatives come from CKAN
   Core `TooManyModsProvideKraken` and are returned as `providerChoices`; the
   native preview presents them as blocking dependency choices until the user
   selects a provider. The sidecar probes iteratively so independent virtual
   dependencies in the same change set can produce multiple choices. Swift sends
   each selected alternative back as `providerSelections` for the next
   preview/apply pass, and C# treats it as an automatic provider install rather
   than a direct user-requested install. Optional recommendations, suggestions,
   and supporters come from
   CKAN Core `ModuleInstaller.FindRecommendations` and are returned as
   `recommendationChoices`; the native preview can stage one without blocking
   Apply. The same preview carries the selected instance's persistent
   `SuppressRecommendations` preference so the native sheet can keep the
   Windows "always uncheck recommendations" behavior in sync with
   `GUIConfig.json`.
14. User confirms choices.
15. Service applies operations via CKAN Core `ModuleInstaller`. The native
    Apply Changes path starts a running operation through
    `operations.startApplyChanges`, keeps the result queryable inside the same
    sidecar session, auto-polls `operations.status`, and can request
    cancellation through `operations.cancel`; `operations.applyChanges` remains
    available for compatibility and synchronous tests.
16. For Install from `.ckan`, Swift uses a native file picker and sends selected
    file paths to `operations.startInstallCkanFiles` for async
    status/cancel polling; C# parses metadata with `CkanModule.FromFile` and
    uses the same `ModuleInstaller` transaction path.
    `operations.installCkanFiles` remains available for compatibility and
    synchronous tests.
17. For Import Downloads, Swift uses a native file/folder picker, then shows a
    native options sheet for install-after-import, preview-before-install, and
    delete-originals choices. Preview-before-install sends selected paths to
    `operations.startImportDownloads` with `previewBeforeInstall`, so CKAN Core
    imports matched archives into the cache and returns install preview changes
    without running `ModuleInstaller`; Swift stages those imported modules and
    opens the normal change-set preview/apply workflow. Direct install still
    uses the same C# CKAN Core `ModuleImporter`
    and `ModuleInstaller` event path. `operations.importDownloads` remains
    available for compatibility and synchronous tests.
18. For Export Mod List, Swift asks `exports.modList` for the selected format
    and writes the returned CKAN Core `Exporter` payload through `NSSavePanel`.
19. For Export Modpack, Swift collects editable modpack metadata in a native
    sheet, includes per-installed-module relationship assignments for
    Depends/Recommends/Suggests/Ignore, asks `exports.modpack` for a CKAN Core
    `GenerateModpack` payload, and writes the returned `.ckan` JSON through
    `NSSavePanel`.
20. For Scan GameData, Swift calls `maintenance.scan`; C# runs CKAN Core
    `ScanUnmanagedFiles`, saves changed registry state, returns whether the
    registry changed plus detected DLL/DLC counts, and Swift refreshes the
    selected instance state.
21. For View Unmanaged Files, Swift calls `maintenance.unmanagedFiles`; C# runs
    the same unmanaged scan, returns registry-detected DLL paths and DLC
    versions, and Swift presents them in a native table.
22. For Installation History, Swift calls `maintenance.history`; C# reads
    `CKAN/history/*.ckan` snapshots, enriches dependency rows from the read-only
    registry, and Swift presents a native split history/mod table with latest
    missing-mod staging plus exact snapshot restore. Exact restore uses
    `installVersions` in `mods.resolveChanges`/`operations.startApplyChanges`
    so preview and apply select the recorded module version instead of the
    latest compatible release. The Core maintenance provider accepts injectable
    configuration and repository data for disposable-instance coverage while
    keeping the default ServiceLocator-backed production constructor.
23. For Play Time, Swift calls `maintenance.playTime`; C# reads all known
    instance `TimeLog` values and Swift presents editable hours. Saving calls
    `maintenance.updatePlayTime`, which writes the selected instance's
    `CKAN/playtime.json` using CKAN Core's existing `TimeLog` format.
24. For Download Statistics, Swift calls `maintenance.downloadStatistics`; C#
    opens the selected read-only registry, asks CKAN Core cache metadata for
    cached bytes by host, formats the byte totals with `CkanModule.FmtSize`,
    and Swift presents a native host table with support links. Disposable
    coverage uses a real `NetModuleCache` file plus registry download URL data.
25. For Clean Cache, Swift calls `maintenance.cacheInfo` before showing the
    sheet. `maintenance.clearCache` calls CKAN Core `NetModuleCache.RemoveAll`
    after native confirmation; `maintenance.purgeCacheToLimit` calls
    `NetModuleCache.EnforceSizeLimit` using the selected instance read-only
    registry and configured `CacheSizeLimit`, with disposable coverage for both
    removal paths.
26. For Deduplicate, Swift asks for native confirmation and then calls
    `maintenance.deduplicate`; C# runs CKAN Core `InstalledFilesDeduplicator`
    across known game instances and returns captured messages/progress for a
    native result sheet. Disposable coverage exercises two real KSP instances
    and the macOS hard-link metadata path (`stat -f`) before verifying the
    resulting linked installed files.
27. For Repair Registry, Swift asks for native confirmation and then calls
    `maintenance.repairRegistry`; C# opens the selected instance's
    `RegistryManager`, calls CKAN Core `Registry.Repair()`, rescans unmanaged
    files after the reindex so installed files are not misclassified as
    autodetected, saves the registry, and returns captured messages/errors for
    a native result sheet. Disposable coverage verifies installed-file
    reindexing, autodetected DLL refresh, and unchanged download-cache contents.
28. For Cache Settings, Swift calls `settings.get` to populate the native Cache
    preferences pane and `settings.update` to save the download cache folder and
    cache size limit through CKAN Core configuration. If the path changes,
    Swift also sends a `cacheMigrationChoice` matching CKAN Core's cache
    migration actions: move, delete, open both folders, keep old files, or
    revert/cancel. C# uses `GameInstanceManager.TrySetupCache` for path changes
    and `IConfiguration.CacheSizeLimit` for the byte limit.
29. For Compatible Game Versions, Swift calls `settings.compatibleVersions` for
    the selected instance and saves selected/custom versions through
    `settings.updateCompatibleVersions`. C# reads `GameInstance.CompatibleVersions`,
    known game versions, and stored baseline version, and saves via CKAN Core
    `GameInstance.SetCompatibleVersions`.
30. For Stability Tolerance, Swift calls `settings.stabilityTolerance` for the
    selected instance and saves the overall tolerance or module-specific
    overrides through `settings.updateStabilityTolerance` and
    `settings.updateModuleStabilityTolerance`. C# reads and writes CKAN Core
    `GameInstance.StabilityToleranceConfig`, including null module tolerance
    updates to clear an override.
31. For Preferred Hosts, Swift calls `settings.preferredHosts` for the selected
    instance and saves the ordered host list through `settings.updatePreferredHosts`.
    C# reads available hosts from the selected instance's CKAN Core registry via
    `Registry.GetAllHosts()` and writes the nullable priority list to
    `IConfiguration.PreferredHosts`; the null item is the Windows "all other
    hosts" marker.
32. For Install Filters, Swift calls `settings.installFilters` for the selected
    instance and saves global plus instance filters through
    `settings.updateInstallFilters`. C# reads game-global filters from
    `IConfiguration.GetGlobalInstallFilters(instance.Game)`, per-instance
    filters from `GameInstance.InstallFilters`, exposes
    `instance.Game.InstallFilterPresets`, and writes back through
    `IConfiguration.SetGlobalInstallFilters` plus `GameInstance.InstallFilters`.
33. For Auth Tokens, Swift calls `settings.authTokens` to list saved hosts with
    masked previews only, `settings.addAuthToken` to add or update a host token,
    and `settings.removeAuthToken` to delete one. C# validates host names,
    writes through CKAN Core `IConfiguration.SetAuthToken`, and never serializes
    saved raw token values back to Swift. On macOS, the registered
    `IConfiguration` is wrapped by `KeychainAuthTokenConfiguration`: new tokens
    are written to Keychain, `config.json` keeps only a non-secret marker, and
    legacy raw config tokens migrate to Keychain on first lookup when Keychain
    accepts the secret. If that migration write fails, the legacy token remains
    usable from the existing config entry so downloads do not regress.
34. For Labels, Swift asks `labels.list` for CKAN Core `ModuleLabelList`
    summaries. The result separates `labels` for selected-instance catalog
    matching from `manageableLabels` for cross-instance label management. Swift
    calls `labels.toggleModule` to add or remove the selected module identifier
    from an existing selected-instance label. The native Labels manager calls
    `labels.upsert` and `labels.delete` to create, rename, recolor, rescope, and
    edit Windows label flags before refreshing local label assignments.
35. For Auto Installed, Swift calls `mods.setAutoInstalled` from the native
    catalog's auto column. C# rejects non-installed, autodetected, and DLC
    modules, updates the selected installed module's `AutoInstalled` flag,
    saves the CKAN registry, and returns a refreshed catalog.
36. App refreshes instance/catalog/history after completion.

## Error Handling

All service calls return either a typed result or a typed error with:

- stable error code
- user-facing message
- technical details
- suggested recovery action
- optional diagnostic log path

Registry locks are not silently deleted. The sidecar maps
`RegistryInUseKraken` to typed `registryLock` details in JSON-RPC errors and
operation results, and the native preview/apply sheets show the lock path with
a Retry action. Explicit stale-lock removal is available as a high-friction
destructive action: the UI shows the path and risk, then calls
`maintenance.removeRegistryLock` and retries the preview/apply flow only after
the lock file was actually removed.

CKAN Core `ModuleDownloadErrorsKraken` is mapped to operation-result
`downloadFailures` details. Each failed module row includes identifier, display
name, version, Core error message, and download URLs, so the native operation
sheet can show recoverable download failure context instead of only a flat error
string. Apply Changes, local `.ckan` install, and direct install-after-import
requests also accept `skipDownloadFailures`; the native operation sheet can
retry the same workflow while asking CKAN Core to skip modules whose downloads
failed and any install-set modules that depend on them. Broader per-file live
streaming remains a later operation workflow.

Repository refresh uses a separate async lifecycle because its result shape is
repository metadata rather than a mod change set. `repositories.startRefresh`
starts CKAN Core repository data update work and returns a running
`RepositoryRefreshResult` with `operationId` and `operationStatus`;
`repositories.refreshStatus` returns the latest event snapshot and final
repository summary, and `repositories.cancelRefresh` requests cancellation and
marks the native UI as cancelling while the Core update settles. The Swift model
only reloads repository/module state after a completed refresh snapshot, so
running updates can stream events without replacing the visible catalog with
partial data.

## Testing Strategy

- C# unit tests for service DTOs, command routing, operation lifecycle, lock
  handling, and Core integration boundaries.
- Swift unit tests for view models, filtering state, selection state, staged
  change set state, and JSON decoding.
- Contract tests using captured JSON fixtures shared between C# and Swift.
- UI smoke tests with XCTest for first launch, instance selection, catalog load,
  change set preview, settings, and error sheets.
- Packaging tests verifying `.app` layout, sidecar launch, code signing status,
  Info.plist, icons, and no Terminal launch. Current script coverage includes
  local DMG staging/verification, deterministic icon generation, required-icon
  bundle checks, single/universal app-layout fixture tests, and Launch
  Services no-Terminal smoke coverage.

## Known Release Risks

- NuGet critical/high advisory warnings must stay clean before public release.
  The previous `System.Drawing.Common 4.7.0` and
  `System.Security.Cryptography.Xml 10.0.0` warnings are remediated for the
  current net10 MACKAN path; keep `dotnet list package --vulnerable` in the
  release gate so future upstream dependency drift is caught.
- WinForms GUI uses global singleton access in many places; MACKAN should not
  depend on WinForms UI classes for app behavior.
- Existing macOS Makefile creates an app bundle that opens Terminal. That path is
  retained only as historical reference and fallback packaging knowledge.
- Direct Swift-to-.NET embedding is not chosen for the first release because it
  increases runtime and memory ownership risk. A sidecar process gives a clearer
  failure boundary.

# MACKAN full UI/function audit design

Дата: 2026-06-06
Статус: approved in brainstorming

## 1. Цель

Составить и затем выполнить полный план проверки и исправления MACKAN так,
чтобы каждый существующий UI-элемент и каждая существующая пользовательская
функция имели проверяемый статус.

Итоговый результат будущего implementation plan должен быть не общим
"полишингом", а трассируемой матрицей:

```text
UI surface -> control/action -> AppModel/Sidecar/Core function
-> expected state or mutation -> automated proof -> real-app proof
-> defect/fix status
```

План намеренно допускает реальные mutating-проверки текущего CKAN/KSP
состояния. По решению пользователя предварительный backup/rollback слой не
входит в scope. Перед выполнением live-прохода фиксируется только стартовое
состояние как evidence-снимок: версия приложения, selected instance,
repository list, installed modules, staged changes, settings summary и
screenshots. Этот снимок не является rollback-механизмом и не должен блокировать
реальные проверки.

## 2. Источники правды

- `docs/mackan/product-spec.md`: продуктовая цель MACKAN как native macOS CKAN
  GUI с parity не ниже Windows CKAN.
- `docs/mackan/architecture.md`: граница SwiftUI/AppKit UI и .NET sidecar.
- `docs/mackan/parity-matrix.md`: перечень Windows CKAN capabilities и статус
  MACKAN parity.
- `docs/mackan/release-execution-checklist.md`: release/readiness gates,
  включая обязательный full UI/UX release gate.
- `macosx/MACKAN/Sources/MACKAN`: реальные SwiftUI/AppKit UI-поверхности.
- `macosx/MACKAN/Sources/MACKANKit`: AppModel, presentation state,
  SidecarClient и локальные policy/helpers.
- `MACKAN.Service` и `Tests/MACKAN`: JSON-RPC dispatcher, CKAN Core providers,
  DTO contracts и disposable/integration evidence.

SwiftUI не должен становиться источником CKAN-доменной правды. Любая
функциональная проверка должна трассироваться к CKAN Core через sidecar, кроме
чисто presentation-only элементов вроде layout policy, badges, empty states и
keyboard/focus affordances.

## 3. Scope покрытия

### 3.1 UI surfaces

Матрица должна включить все текущие зоны:

1. `MACKANApp.swift`
   - app commands;
   - Instance, Mods, Maintenance, Help menus;
   - About, Check for Updates, diagnostics, export commands;
   - app-level sheets, alerts, confirmations and file/save panels.
2. `MainWindowView.swift`
   - three-pane shell;
   - toolbar commands;
   - operation sheets;
   - maintenance sheets;
   - launch warning/error alerts;
   - registry lock removal confirmation;
   - keyboard shortcuts and command enablement.
3. `SidebarViews.swift`
   - instance list and selection;
   - instance context menu;
   - saved searches;
   - labels;
   - maintenance navigation;
   - service status;
   - rename/forget/default/reveal actions.
4. `CatalogViews.swift`
   - catalog loading state;
   - search field and syntax insertion;
   - filter, tag, sort, secondary sort and columns controls;
   - module table rows/cells/header clicks/double-clicks;
   - action menu for install/remove/upgrade/replace/auto-installed;
   - staged-action strip;
   - saved search sheet;
   - labels manager sheet entry.
5. `InspectorViews.swift`
   - contextual empty states;
   - module header, badges, metric tiles;
   - Overview, Relationships, Versions, Contents, Resources tabs;
   - launch incompatible-mod warning sheet.
6. `OperationSheets.swift`
   - Import Downloads options;
   - Change Set Preview;
   - provider choices;
   - optional recommendation choices;
   - conflict panel;
   - operation result timeline;
   - polling/refresh/cancel;
   - registry lock, failed download, incompatible `.ckan`, retry/skip notices.
7. `InstanceManagementSheets.swift` and `InstanceEditorSheets.swift`
   - Manage Instances;
   - Add Instance;
   - Clone Instance;
   - Fake Instance;
   - Launch Command Lines.
8. `MaintenanceSheets.swift`
   - unmanaged files;
   - installation history;
   - play time editing;
   - download statistics;
   - cache maintenance;
   - deduplicate result;
   - repair registry result.
9. Settings panes
   - `PreferencesViews.swift`;
   - `GeneralPreferencesView.swift`;
   - `RepositoryPreferencesView.swift`;
   - `CachePreferencesView.swift`;
   - `CompatibilityPreferencesView.swift`;
   - `StabilityPreferencesView.swift`;
   - `PreferredHostsPreferencesView.swift`;
   - `InstallFiltersPreferencesView.swift`;
   - `LaunchCommandsPreferencesView.swift`;
   - `AuthTokensPreferencesView.swift`;
   - `PluginsPreferencesView.swift`.
10. File/export surfaces
    - `ExportModpackSheet.swift`;
    - Install from File picker path;
    - Import Downloads picker/options path;
    - Export Mod List save panel path.
11. Shared visible components
    - `CatalogBadges.swift`;
    - `PresentationExtensions.swift`;
    - `ModalSheetFrame.swift`;
    - link buttons and help links.

Every button, menu item, toolbar item, context-menu item, picker, toggle,
text field, list row, table column/header, tab, alert action, sheet action,
file/save panel command, empty state, loading state, error state, keyboard
shortcut and focus path must get at least one row in the matrix.

### 3.2 Function surfaces

The function inventory must include all current user-facing functions, all
behavior-owning AppModel paths and all sidecar routes exposed by
`SidecarClient`/`MackanServiceDispatcher`. Private formatting/layout helpers do
not need separate live rows when they are fully covered by their owning UI row,
but the inventory report must still map each discovered helper to either a
direct row or a parent row. Any helper that owns independent state transitions,
validation, persistence, error handling, enablement or external effects must
get its own row.

Minimum route groups:

- App: `app.health`, `app.version`, `app.checkForUpdates`.
- Instances: `instances.list`, `instances.add`, `instances.cloneOptions`,
  `instances.clone`, `instances.fake`, `instances.setDefault`,
  `instances.remove`, `instances.rename`, `instances.launchOptions`,
  `instances.updateLaunchOptions`, `instances.launch`.
- Mods/catalog: `mods.list`, `mods.startList`, `mods.listStatus`,
  `mods.cancelList`, `mods.details`, `mods.setAutoInstalled`,
  `mods.resolveChanges`.
- Labels: `labels.list`, `labels.toggleModule`, `labels.upsert`,
  `labels.delete`.
- Repositories: `repositories.list`, `repositories.available`,
  `repositories.add`, `repositories.remove`, `repositories.setPriority`,
  `repositories.refresh`, `repositories.startRefresh`,
  `repositories.refreshStatus`, `repositories.cancelRefresh`.
- Operations: `operations.applyChanges`, `operations.startApplyChanges`,
  `operations.installCkanFiles`, `operations.startInstallCkanFiles`,
  `operations.importDownloads`, `operations.startImportDownloads`,
  `operations.status`, `operations.cancel`.
- Exports: `exports.modList`, `exports.modpack`.
- Maintenance: `maintenance.scan`, `maintenance.unmanagedFiles`,
  `maintenance.history`, `maintenance.playTime`,
  `maintenance.updatePlayTime`, `maintenance.downloadStatistics`,
  `maintenance.cacheInfo`, `maintenance.clearCache`,
  `maintenance.purgeCacheToLimit`, `maintenance.deduplicate`,
  `maintenance.repairRegistry`, `maintenance.removeRegistryLock`.
- Settings: `settings.get`, `settings.update`, `settings.general`,
  `settings.updateGeneral`, `settings.compatibleVersions`,
  `settings.updateCompatibleVersions`, `settings.stabilityTolerance`,
  `settings.updateStabilityTolerance`,
  `settings.updateModuleStabilityTolerance`, `settings.preferredHosts`,
  `settings.updatePreferredHosts`, `settings.installFilters`,
  `settings.updateInstallFilters`, `settings.recommendations`,
  `settings.updateRecommendations`, `settings.authTokens`,
  `settings.addAuthToken`, `settings.removeAuthToken`.

Minimum AppModel groups:

- `AppModel+Instances`: refresh/select/add/clone/fake/default/remove/rename,
  reveal folder and unmanaged files.
- `AppModel+InstanceState`: selected-instance state, catalog load progress.
- `AppModel+Catalog`: module selection, details, saved catalog state, labels.
- `AppModel+Operations`: stage/preview/apply/cancel/status, `.ckan` install,
  import downloads, export mod list, export modpack.
- `AppModel+Repositories`: list/add/remove/reorder/refresh/cancel.
- `AppModel+Maintenance`: scan, unmanaged, history, play time, stats, cache,
  deduplicate, repair, lock removal.
- `AppModel+Settings`: general, cache, compatibility, stability, hosts,
  install filters, recommendations, auth tokens.
- `AppModel+Launch`: launch, launch warning, command lines, launch failures.
- `AppModel+Updates`: update checks and launch-time update behavior.
- Presentation/policy helpers: action enablement, layout sizing, retry state,
  empty state, diagnostics, search parsing and table/sort policy.

## 4. Audit matrix schema

Future implementation must create or update a dedicated evidence matrix under
`docs/mackan/`, for example:

```text
docs/mackan/full-ui-function-audit-matrix.md
docs/mackan/full-ui-function-audit-evidence-YYYY-MM-DD.md
```

Each matrix row must contain:

- `id`: stable identifier, e.g. `CAT-SEARCH-001`.
- `surface`: file/view/menu/sheet.
- `element`: exact UI element or state.
- `trigger`: click, keyboard shortcut, menu command, context command,
  launch-time state, resize state, file/save panel, polling tick.
- `function trace`: AppModel method, sidecar route, CKAN Core provider or
  presentation-only helper.
- `preconditions`: selected instance, module state, repository state, staged
  state, cache/registry state, window size.
- `real action`: what will be done in the real app.
- `expected result`: visible result plus persistent state/mutation.
- `automation proof`: unit/contract/integration/script command.
- `real-app proof`: screenshot, app log, evidence file, computer-use notes,
  live output or observed state.
- `risk`: P0/P1/P2/P3.
- `status`: not-run, pass, fail, fixed, deferred, intentionally-unsupported.
- `defect link`: file/function to patch and retest command.

Rows cannot be closed by "looked fine" alone. A closed row needs at least one
state assertion and one visible/rendered assertion unless it is purely
non-visual.

## 5. Execution order

### Phase 0: Live-state capture, not backup

Record current state before changing anything:

- `git status --short`;
- built app path and `app.version`;
- selected CKAN instance and list of instances;
- repositories;
- installed modules and available updates;
- current staged changes;
- relevant settings summary;
- initial main-window/adaptive screenshots;
- current `release-readiness.sh --strict --json` status.

This phase does not create a backup and does not restore state later. It only
makes the live run auditable.

### Phase 1: Static inventory

Build the full matrix from:

- SwiftUI files in `macosx/MACKAN/Sources/MACKAN`;
- AppModel and policy/helper files in `macosx/MACKAN/Sources/MACKANKit`;
- sidecar route list in `SidecarClient.swift` and `MackanServiceDispatcher.cs`;
- parity rows in `docs/mackan/parity-matrix.md`;
- release gate requirements in `docs/mackan/release-execution-checklist.md`.

No testing is considered complete until the matrix proves that every public
route and every visible control has a mapped row.

### Phase 2: Baseline build and launch

Run the current non-credential baseline:

```sh
swift test --package-path macosx/MACKAN
dotnet test Tests/Tests.csproj --filter MACKAN
macosx/MACKAN/scripts/build-dev-app.sh
macosx/MACKAN/scripts/verify-app-bundle.sh --mode auto --require-icon \
  --require-version 0.1.0 ~/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 \
  ~/Library/Caches/MACKAN/build/MACKAN.app
```

If baseline tests fail, do not continue to broad live mutation. First classify
the failure as existing blocker, environment blocker, or direct regression.

### Phase 3: Zone-by-zone real-app audit

Audit zones in this order:

1. Startup, service status, menus, About, Help, update check and diagnostics.
2. Instances and launch:
   - select/default;
   - add/clone/fake/rename/forget;
   - reveal folder;
   - launch with default and configured command line;
   - incompatible-mod warning and suppression.
3. Repositories:
   - list/canonical sources;
   - add/remove/reorder;
   - refresh, async status, cancel;
   - download failure recovery when reproducible.
4. Catalog and inspector:
   - loading/empty/error states;
   - search syntax and saved searches;
   - filters, tag filter, labels, sort, columns;
   - table row selection, double-click and context/action menus;
   - inspector tabs and long-content rendering.
5. Change set and operations:
   - install/remove/upgrade/replace;
   - provider choices;
   - recommendations;
   - conflicts;
   - apply, polling, cancel, retry;
   - registry lock and failed download recovery.
6. File workflows:
   - install local `.ckan`;
   - import downloads with every option combination;
   - export mod list formats;
   - export modpack metadata and relationship assignments.
7. Maintenance:
   - scan/unmanaged;
   - history restore;
   - play time edit;
   - download statistics;
   - cache info, clear and purge;
   - deduplicate;
   - repair registry;
   - stale lock removal if the app surfaces a lock.
8. Settings:
   - General;
   - Repositories;
   - Cache;
   - Compatibility;
   - Stability;
   - Preferred Hosts;
   - Install Filters;
   - Launch Commands;
   - Auth Tokens with non-secret dummy token only;
   - Plugins unsupported-status pane.
9. Adaptive UI/accessibility/localization:
   - minimum, medium and wide window sizes;
   - sidebar expanded/collapsed;
   - long module names, long paths, long URLs;
   - keyboard-only paths;
   - VoiceOver/accessibility labels where scripts can observe them;
   - English and Russian resources for key surfaces.
10. Packaging/release UI gate:
    - `run-ui-ux-audit.sh`;
    - evidence verification;
    - DMG launch and clean-install smoke when the build path is ready.

### Phase 4: Fix loop

For each failed row:

1. Classify severity:
   - P0: crash, app cannot launch, data-destroying bug, unrecoverable mutation,
     Apply/registry broken, Terminal opens for GUI flow.
   - P1: button/menu exists but does not work, wrong sidecar mutation,
     user-blocking layout overlap/clipping, broken recovery path, disabled state
     wrong for real workflow.
   - P2: confusing state, missing progress, weak error copy, accessibility gap,
     non-critical clipping, long-text layout issue.
   - P3: polish, cosmetic consistency, optional shortcut/help improvement.
2. Patch the narrowest file set that owns the defect.
3. Add or update the closest durable automated proof:
   - Swift presentation/model tests;
   - C# dispatcher/provider tests;
   - script tests;
   - release/readiness verifier checks.
4. Re-run targeted tests first, then the affected live row.
5. Update the matrix row from `fail` to `fixed` only after real-app evidence is
   captured.
6. Re-run broader gates after every cluster of related fixes.

No P0/P1 issue may be left open for release-candidate readiness. P2 can be
deferred only with an explicit user-visible reason and a linked follow-up.

## 6. Real mutating policy

The implementation plan must execute real functionality, including mutation,
unless a route is technically unavailable or would require secrets.

Allowed real mutations:

- CKAN instance add/clone/fake/rename/remove/default changes;
- repository add/remove/reorder/refresh;
- module install/remove/upgrade/replace/apply;
- local `.ckan` install and import-download operations;
- launch command editing and launch attempts;
- settings persistence changes;
- cache clear/purge;
- scan/repair/deduplicate;
- play time edits;
- dummy auth token add/remove using a non-secret test value.

No preliminary backup is required. The implementation should still avoid
inventing unrelated destructive actions outside MACKAN UI/sidecar flows.
Deletion or mutation is acceptable when it is the expected result of the tested
MACKAN function.

Auth-token tests must not use real credentials. They should use a clearly dummy
host/token and then exercise the remove path.

## 7. Computer-use and visual evidence

Native MACKAN is not a web app, so browser inspection is not a substitute for
real-app checks. The plan should combine:

- `verify-app-launch.sh` for no-Terminal native launch;
- `run-ui-ux-audit.sh` for unlocked desktop, visible window and adaptive
  screenshot setup;
- `verify-ui-ux-audit-evidence.sh` for completed evidence bundle validation;
- computer-use/manual visual inspection of the actual running `.app`;
- screenshots for every major zone and every P0/P1 fix;
- script-driven Accessibility/System Events checks where available;
- in-app browser only for companion dashboards, evidence previews or local web
  artifacts, not as proof of native UI behavior.

Each visual pass must check:

- no overlapping critical text or controls;
- no clipped primary action labels;
- no unreachable buttons/menus;
- stable layout at minimum/medium/wide window sizes;
- table column resizing and sort feedback;
- focus traversal and keyboard command availability;
- modal sheet sizing, scrolling and cancellation;
- visible loading/progress/error/recovery states.

## 8. Subagent decomposition

Implementation may use parallel subagents because the work naturally splits
into independent inventory and audit lanes. The recommended lanes are:

1. UI inventory agent:
   - enumerate SwiftUI surfaces and visible controls;
   - produce matrix rows for views, sheets, alerts, menus and toolbar actions.
2. Function trace agent:
   - enumerate AppModel methods, SidecarClient routes and dispatcher methods;
   - map each to UI triggers and tests.
3. Test/evidence agent:
   - map every route/control to existing Swift, C# and script tests;
   - identify missing proof.
4. Real-app audit agent:
   - run built `.app`, inspect visible state, capture screenshots and note
     defects by matrix row.
5. Fix agents by zone:
   - one zone at a time, scoped to the files that own failing rows.

Subagents must not make conflicting edits to the same files. If two lanes point
at the same file, one active editor owns that file and the other returns notes.

## 9. Verification commands

The final implementation plan should use this command ladder:

```sh
swift test --package-path macosx/MACKAN --filter <targeted Swift test>
swift test --package-path macosx/MACKAN
dotnet test Tests/Tests.csproj --filter MACKAN
macosx/MACKAN/scripts/test-run-ui-ux-audit.sh
macosx/MACKAN/scripts/test-accessibility-smoke.sh
macosx/MACKAN/scripts/build-dev-app.sh
macosx/MACKAN/scripts/verify-app-bundle.sh --mode auto --require-icon \
  --require-version 0.1.0 ~/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 \
  ~/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/run-ui-ux-audit.sh --wait-catalog 60 \
  --output /tmp/mackan-full-ui-function-audit-YYYY-MM-DD \
  ~/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh \
  /tmp/mackan-full-ui-function-audit-YYYY-MM-DD
MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS=true \
  macosx/MACKAN/scripts/release-check.sh --skip-launch
macosx/MACKAN/scripts/release-readiness.sh --strict --json
```

If credential-backed public release checks are requested later, add:

```sh
macosx/MACKAN/scripts/release-readiness.sh \
  --require-release-credentials --json
macosx/MACKAN/scripts/release-dmg.sh
macosx/MACKAN/scripts/verify-public-release-handoff.sh <artifact-set>
```

Credential-backed notarization remains outside this design unless the required
Developer ID and notary credentials are configured.

## 10. Acceptance criteria

The full audit/fix program is complete only when:

1. Every current UI element and state in scope has a matrix row.
2. Every current public AppModel action and sidecar route has a matrix row.
3. Every matrix row is marked `pass`, `fixed`, `deferred`, or
   `intentionally-unsupported`; no row remains `not-run` or unclassified.
4. No P0/P1 defect remains open.
5. Every fixed defect has:
   - code change;
   - targeted automated proof;
   - real-app proof for visible behavior;
   - updated matrix status.
6. Main test gates pass:
   - Swift tests;
   - MACKAN .NET tests;
   - UI/UX audit script tests;
   - accessibility smoke;
   - dev bundle verification;
   - launch smoke;
   - strict release readiness.
7. Real-app evidence bundle exists and passes
   `verify-ui-ux-audit-evidence.sh`.
8. `docs/mackan/release-execution-checklist.md`,
   `docs/mackan/parity-matrix.md` or related evidence docs are updated if the
   audit changes release-readiness claims.

## 11. Non-goals

- Rewriting CKAN Core behavior in Swift.
- Replacing the sidecar architecture.
- Adding in-app auto-update installation beyond the existing manual update
  check path.
- Blocking the audit on credential-backed notarization when credentials are not
  configured.
- Creating a backup/rollback system before live mutating verification.

## 12. Immediate next step

After this design doc is reviewed, invoke the writing-plans skill and produce a
detailed implementation plan that:

1. creates the audit matrix artifact;
2. assigns subagent lanes where useful;
3. defines the first concrete live-app audit pass;
4. specifies targeted tests and gates per zone;
5. sequences fixes so P0/P1 blockers are patched and reverified before broad
   polish.

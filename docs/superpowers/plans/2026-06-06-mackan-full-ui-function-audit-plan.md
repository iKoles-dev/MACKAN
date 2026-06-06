# MACKAN Full UI/Function Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Построить и выполнить полную трассируемую программу аудита MACKAN, где каждый текущий UI-элемент и каждая user-facing/behavior-owning функция получают проверенный статус, evidence и fix-loop.

**Architecture:** План сохраняет существующую границу: SwiftUI/AppKit отвечает за native UX, `MACKANKit` за состояние/presentation/sidecar client, `MACKAN.Service` за CKAN Core behavior. Сначала создается audit matrix, затем real-app mutating pass на текущем CKAN/KSP состоянии, затем scoped P0/P1 fixes with tests and evidence.

**Tech Stack:** Swift 6 Package (`macosx/MACKAN`), SwiftUI/AppKit, .NET `MACKAN.Service`, CKAN Core, JSON-RPC stdio sidecar, bash release scripts, macOS Launch Services/System Events, computer-use visual inspection.

---

## Scope Check

Этот plan сознательно является master plan. Spec покрывает несколько подсистем:
startup/menus, instances, repositories, catalog, inspector, operations, file
workflows, maintenance, settings, help/update/diagnostics and packaging gates.

Execution rule:

- Master plan создает matrix, evidence discipline and zone order.
- Каждый P0/P1 defect found during execution получает отдельный scoped fix row
  в matrix и отдельный zone-local patch task before broad polishing.
- Если один zone-fix занимает больше одного рабочего блока, execution lead
  splits it into a child plan under `docs/superpowers/plans/` before editing
  more files.

## File Structure

Create:

- `docs/mackan/full-ui-function-audit-matrix.md`
  - Owner: inventory and status source of truth.
  - Responsibility: one row per UI element/state/function trace.
- `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
  - Owner: live run notes, commands, screenshots, observed mutations and
    defect log.
- `/tmp/mackan-full-ui-function-audit-2026-06-06/`
  - Runtime evidence directory for screenshots, app launch evidence and
    UI/UX audit runner output.

Modify when findings require it:

- `docs/mackan/parity-matrix.md`
  - Only when audit changes a parity/readiness claim.
- `docs/mackan/release-execution-checklist.md`
  - Only when audit changes release gate wording or evidence status.
- `docs/mackan/README.md`
  - Only to link final audit evidence after a completed pass.
- `macosx/MACKAN/Sources/MACKAN/*.swift`
  - UI-only fixes, command wiring, sheets, layout, menus, labels and
    presentation behavior.
- `macosx/MACKAN/Sources/MACKANKit/*.swift`
  - AppModel, SidecarClient, presentation state, layout policy and helper fixes.
- `MACKAN.Service/*.cs`
  - JSON-RPC dispatch/provider/DTO fixes when live UI exposes a service defect.
- `Tests/MACKAN/*.cs`
  - C# contract/provider/disposable integration proofs.
- `macosx/MACKAN/Tests/MACKANKitTests/*.swift`
  - Swift model/presentation/policy proofs.
- `macosx/MACKAN/scripts/*.sh`
  - Release, UI/UX audit, accessibility or packaging verifier fixes.

Do not modify:

- CKAN Core behavior in Swift.
- Real credentials or secret storage values.
- Unrelated upstream CKAN files unless a MACKAN row proves the defect reaches
  CKAN Core integration and requires that file.

## Task 1: Create Audit Matrix Artifact

**Files:**
- Create: `docs/mackan/full-ui-function-audit-matrix.md`
- Read: `docs/superpowers/specs/2026-06-06-mackan-full-ui-function-audit-design.md`
- Read: `docs/mackan/parity-matrix.md`

- [ ] **Step 1: Create the matrix file**

Use `apply_patch` to add `docs/mackan/full-ui-function-audit-matrix.md` with this exact top-level structure:

```markdown
# MACKAN Full UI/Function Audit Matrix

Date: 2026-06-06
Source spec: `docs/superpowers/specs/2026-06-06-mackan-full-ui-function-audit-design.md`

## Status Values

- `not-run`: row is inventoried but no proof exists.
- `pass`: row has automated proof and real-app proof when applicable.
- `fail`: row has a defect that needs a fix.
- `fixed`: row failed, was patched, and was reverified.
- `deferred`: row is intentionally postponed with a recorded reason.
- `intentionally-unsupported`: row is a visible unsupported state with release-approved rationale.

## Severity Values

- `P0`: app cannot launch, destructive/unrecoverable mutation, broken apply/registry path, or Terminal opens for GUI flow.
- `P1`: visible control/function is broken, wrong mutation, blocking layout/accessibility issue, or recovery path unusable.
- `P2`: confusing state, missing progress, weak error copy, non-critical clipping, accessibility gap.
- `P3`: polish or optional workflow improvement.

## Matrix

| ID | Surface | Element | Trigger | Function Trace | Preconditions | Real Action | Expected Result | Automation Proof | Real-App Proof | Risk | Status | Defect Link |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

- [ ] **Step 2: Verify the file exists**

Run:

```sh
test -f docs/mackan/full-ui-function-audit-matrix.md
```

Expected: exit `0`.

- [ ] **Step 3: Commit the matrix skeleton**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md
git commit -m "docs: add MACKAN full audit matrix"
```

Expected: commit succeeds and only `docs/mackan/full-ui-function-audit-matrix.md` is staged for that commit.

## Task 2: Create Evidence Log Artifact

**Files:**
- Create: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`

- [ ] **Step 1: Create the evidence file**

Use `apply_patch` to add `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`:

```markdown
# MACKAN Full UI/Function Audit Evidence (2026-06-06)

## Run Policy

- Real mutating checks are allowed.
- No preliminary backup/rollback layer is used.
- Start-state capture is evidence only.
- Auth-token tests use a dummy non-secret token only.

## Start State

| Item | Evidence |
| --- | --- |
| Git status | not captured |
| Built app path | not captured |
| App version | not captured |
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

## Live Mutations

| Time | Matrix Row | Action | Observed State Change |
| --- | --- | --- | --- |

## Defects

| Matrix Row | Severity | Summary | Owner Files | Fix Status | Verification |
| --- | --- | --- | --- | --- | --- |

## Screenshots and Artifacts

| Artifact | Path | Matrix Rows |
| --- | --- | --- |
```

- [ ] **Step 2: Update the matrix header with evidence link**

In `docs/mackan/full-ui-function-audit-matrix.md`, add this line after the source spec line:

```markdown
Evidence log: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
```

- [ ] **Step 3: Commit evidence skeleton**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: add MACKAN full audit evidence log"
```

Expected: commit succeeds with only the matrix header update and evidence log.

## Task 3: UI Inventory Pass

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Read: `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/SidebarViews.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/CatalogViews.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/OperationSheets.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/InstanceManagementSheets.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/InstanceEditorSheets.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/MaintenanceSheets.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/*PreferencesView.swift`
- Read: `macosx/MACKAN/Sources/MACKAN/ExportModpackSheet.swift`

- [ ] **Step 1: Extract UI control candidates**

Run:

```sh
rg -n "struct .*: View|Button\\(|Menu\\(|ToolbarItem|CommandGroup|\\.sheet\\(|\\.alert\\(|TextField\\(|Toggle\\(|Picker\\(|Table\\(|List\\(|NavigationSplitView|TabView|DisclosureGroup|\\.contextMenu" macosx/MACKAN/Sources/MACKAN
```

Expected: command prints candidates from app, main window, sidebar, catalog, inspector, operation, maintenance, settings and instance sheets.

- [ ] **Step 2: Add row groups for app/menu/window surfaces**

Append rows with these ID prefixes:

```text
APP-STARTUP
APP-MENU
APP-ABOUT
APP-UPDATE
APP-DIAGNOSTICS
WIN-TOOLBAR
WIN-SHEET
WIN-ALERT
WIN-KEYBOARD
```

Each row must use `not-run` status, a concrete trigger, and a concrete file/view in the `Surface` column.

- [ ] **Step 3: Add row groups for sidebar, catalog and inspector surfaces**

Append rows with these ID prefixes:

```text
SID-INSTANCE
SID-SAVEDSEARCH
SID-LABEL
SID-MAINT
SID-STATUS
CAT-LOADING
CAT-SEARCH
CAT-FILTER
CAT-TAG
CAT-SORT
CAT-COLUMN
CAT-ROW
CAT-ACTION
CAT-SAVEDSEARCH
CAT-LABEL
INS-EMPTY
INS-HEADER
INS-OVERVIEW
INS-RELATIONSHIP
INS-VERSION
INS-CONTENT
INS-RESOURCE
```

Each row must point to a visible UI element or visible state from the current SwiftUI files.

- [ ] **Step 4: Add row groups for operations, instances, maintenance, settings and file workflows**

Append rows with these ID prefixes:

```text
OPS-IMPORTOPTIONS
OPS-PREVIEW
OPS-PROVIDER
OPS-RECOMMEND
OPS-CONFLICT
OPS-RESULT
OPS-RETRY
OPS-LOCK
OPS-DOWNLOADFAIL
INST-MANAGE
INST-ADD
INST-CLONE
INST-FAKE
INST-LAUNCHCMD
MAINT-UNMANAGED
MAINT-HISTORY
MAINT-PLAYTIME
MAINT-STATS
MAINT-CACHE
MAINT-DEDUP
MAINT-REPAIR
SET-GENERAL
SET-REPO
SET-CACHE
SET-COMPAT
SET-STABILITY
SET-HOSTS
SET-FILTERS
SET-LAUNCH
SET-AUTH
SET-PLUGINS
FILE-CKAN
FILE-IMPORT
FILE-EXPORTLIST
FILE-EXPORTPACK
```

Rows that require file/save panels should say `file panel` or `save panel` in `Trigger`.

- [ ] **Step 5: Check that every current MACKAN view file is represented**

Run:

```sh
for file in macosx/MACKAN/Sources/MACKAN/*.swift; do
  base="$(basename "$file")"
  if ! rg -q "$base" docs/mackan/full-ui-function-audit-matrix.md; then
    echo "missing UI file in matrix: $base"
  fi
done
```

Expected: no `missing UI file in matrix:` lines. Any line printed becomes a `UI-INVENTORY` fail row before continuing.

- [ ] **Step 6: Commit UI inventory rows**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md
git commit -m "docs: inventory MACKAN UI audit surfaces"
```

Expected: commit succeeds with only matrix row additions.

## Task 4: Function Trace Inventory Pass

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Read: `macosx/MACKAN/Sources/MACKANKit/SidecarClient.swift`
- Read: `MACKAN.Service/MackanServiceDispatcher.cs`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Instances.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Operations.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Repositories.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Maintenance.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Settings.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Launch.swift`
- Read: `macosx/MACKAN/Sources/MACKANKit/AppModel+Updates.swift`

- [ ] **Step 1: Extract sidecar routes**

Run:

```sh
rg -n "\"(app|instances|mods|labels|repositories|operations|exports|maintenance|settings)\\.[A-Za-z0-9]+\"" macosx/MACKAN/Sources/MACKANKit/SidecarClient.swift MACKAN.Service/MackanServiceDispatcher.cs
```

Expected: output includes all route groups listed in the approved design spec.

- [ ] **Step 2: Extract AppModel behavior functions**

Run:

```sh
rg -n "^\\s*(public func|func|private func)\\s+[A-Za-z0-9_]+\\(" macosx/MACKAN/Sources/MACKANKit/AppModel*.swift
```

Expected: output includes instance, catalog, operation, repository, maintenance, settings, launch and update behavior functions.

- [ ] **Step 3: Map every sidecar route to matrix rows**

For each sidecar route, ensure the matrix has one row with the route in `Function Trace`.

Routes with no direct UI trigger must get one of these statuses:

- `not-run` if it should be reached through a user flow;
- `intentionally-unsupported` if it is a developer-only fallback;
- `fail` if no valid UI path exists but parity says it should.

- [ ] **Step 4: Map behavior-owning helpers**

For each AppModel/helper function that owns state transition, validation,
persistence, error handling, enablement or external effects, ensure the matrix
has either:

- its own row; or
- a parent row that names the helper in `Function Trace`.

Formatting-only helpers may be grouped under parent UI rows.

- [ ] **Step 5: Check route coverage mechanically**

Run:

```sh
python3 - <<'PY'
import re
from pathlib import Path
routes = set()
for path in [
    Path("macosx/MACKAN/Sources/MACKANKit/SidecarClient.swift"),
    Path("MACKAN.Service/MackanServiceDispatcher.cs"),
]:
    text = path.read_text()
    routes.update(re.findall(r'"((?:app|instances|mods|labels|repositories|operations|exports|maintenance|settings)\\.[A-Za-z0-9]+)"', text))
matrix = Path("docs/mackan/full-ui-function-audit-matrix.md").read_text()
missing = sorted(route for route in routes if route not in matrix)
for route in missing:
    print(route)
raise SystemExit(1 if missing else 0)
PY
```

Expected: exit `0` and no printed routes.

- [ ] **Step 6: Commit function trace inventory**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md
git commit -m "docs: map MACKAN function traces for full audit"
```

Expected: commit succeeds with route/function trace rows in matrix.

## Task 5: Automated Proof Mapping

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Read: `macosx/MACKAN/Tests/MACKANKitTests/*.swift`
- Read: `Tests/MACKAN/*.cs`
- Read: `macosx/MACKAN/scripts/*.sh`

- [ ] **Step 1: List Swift tests**

Run:

```sh
rg --files macosx/MACKAN/Tests/MACKANKitTests | sort
```

Expected: output includes `AppModelTests.swift`, `SidecarClientTests.swift`,
presentation state tests, policy tests, diagnostics tests and operation tests.

- [ ] **Step 2: List .NET MACKAN tests**

Run:

```sh
rg --files Tests/MACKAN | sort
```

Expected: output includes dispatcher tests and CoreMackan provider tests for
instances, modules, repositories, change sets, operations, maintenance,
settings and exports.

- [ ] **Step 3: List script gates**

Run:

```sh
rg --files macosx/MACKAN/scripts | sort
```

Expected: output includes release check, app launch, UI/UX audit, accessibility, bundle, DMG and handoff verifier scripts.

- [ ] **Step 4: Fill `Automation Proof` for every matrix row**

Use these mappings:

- UI presentation rows: closest Swift test or `test-run-ui-ux-audit.sh`.
- AppModel rows: `swift test --package-path macosx/MACKAN --filter AppModelTests`.
- Sidecar routes: matching `Tests/MACKAN/*ProviderTests.cs` or `ServiceDispatcherTests.cs`.
- Script behavior: matching `macosx/MACKAN/scripts/test-*.sh`.
- Native launch/layout rows: `verify-app-launch.sh`, `run-ui-ux-audit.sh`,
  `verify-ui-ux-audit-evidence.sh`, `test-accessibility-smoke.sh`.

Rows without an existing proof must be marked `fail` with `Defect Link` value
`proof-missing`.

- [ ] **Step 5: Commit proof mapping**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: map automated proofs for MACKAN full audit"
```

Expected: commit succeeds.

## Task 6: Baseline Command Run

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`

- [ ] **Step 1: Capture git state**

Run:

```sh
git status --short
```

Expected: output is recorded verbatim in the evidence file. Existing dirty files are not reverted.

- [ ] **Step 2: Run Swift tests**

Run:

```sh
swift test --package-path macosx/MACKAN
```

Expected: exit `0`. If exit is non-zero, add a `P0` matrix row with `Defect Link` value `baseline-swift-test-failure`.

- [ ] **Step 3: Run .NET MACKAN tests**

Run:

```sh
dotnet test Tests/Tests.csproj --filter MACKAN
```

Expected: exit `0`. If the installed SDK requires roll-forward, rerun:

```sh
DOTNET_ROLL_FORWARD=Major dotnet test Tests/Tests.csproj --filter MACKAN
```

Expected after rerun: exit `0`. A second failure creates `baseline-dotnet-test-failure`.

- [ ] **Step 4: Run UI/UX and accessibility script tests**

Run:

```sh
macosx/MACKAN/scripts/test-run-ui-ux-audit.sh
macosx/MACKAN/scripts/test-accessibility-smoke.sh
```

Expected: both commands exit `0`.

- [ ] **Step 5: Build development app**

Run:

```sh
macosx/MACKAN/scripts/build-dev-app.sh
```

Expected: exit `0`, final output contains `/Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app`.

- [ ] **Step 6: Verify app bundle and launch**

Run:

```sh
macosx/MACKAN/scripts/verify-app-bundle.sh --mode auto --require-icon --require-version 0.1.0 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
```

Expected: both commands exit `0`; launch evidence confirms no new Terminal process.

- [ ] **Step 7: Commit baseline evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: record MACKAN full audit baseline"
```

Expected: commit succeeds if evidence files changed. If no evidence file changed, stop and record why the evidence file was not updated before continuing.

## Task 7: Real-App Start-State Capture

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Runtime: `/tmp/mackan-full-ui-function-audit-2026-06-06/`

- [ ] **Step 1: Create runtime evidence directory**

Run:

```sh
mkdir -p /tmp/mackan-full-ui-function-audit-2026-06-06
```

Expected: exit `0`.

- [ ] **Step 2: Capture real-app UI/UX audit scaffold**

Run:

```sh
macosx/MACKAN/scripts/run-ui-ux-audit.sh --wait-catalog 60 --output /tmp/mackan-full-ui-function-audit-2026-06-06 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
```

Expected: exit `0`; directory contains `main-window.png`, `adaptive-minimum.png`, `adaptive-medium.png`, `adaptive-wide.png`, `audit-metadata.json`, `window-summary.txt` and `ui-ux-audit.md`.

- [ ] **Step 3: Verify audit scaffold**

Run:

```sh
macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh /tmp/mackan-full-ui-function-audit-2026-06-06
```

Expected: exit `0` after checklist-required fields are completed. If it fails because the checklist is intentionally not complete yet, record the failure text in evidence and continue only after manual/computer-use inspection fills the required checklist items.

- [ ] **Step 4: Capture CKAN CLI read-only state**

Run:

```sh
"/Applications/CKAN.app/Contents/MacOS/arm64/CKAN-CmdLine" instance list > /tmp/mackan-full-ui-function-audit-2026-06-06/ckan-instances.txt
"/Applications/CKAN.app/Contents/MacOS/arm64/CKAN-CmdLine" list > /tmp/mackan-full-ui-function-audit-2026-06-06/ckan-installed-mods.txt
```

Expected: commands exit `0` or write a concrete CKAN error into the files. A CKAN error becomes a matrix row with risk based on whether MACKAN can still operate.

- [ ] **Step 5: Update evidence start-state table**

Record exact paths:

```text
/tmp/mackan-full-ui-function-audit-2026-06-06/main-window.png
/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-minimum.png
/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-medium.png
/tmp/mackan-full-ui-function-audit-2026-06-06/adaptive-wide.png
/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-instances.txt
/tmp/mackan-full-ui-function-audit-2026-06-06/ckan-installed-mods.txt
```

- [ ] **Step 6: Commit start-state evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-evidence-2026-06-06.md docs/mackan/full-ui-function-audit-matrix.md
git commit -m "docs: capture MACKAN full audit start state"
```

Expected: commit succeeds.

## Task 8: Startup, Menus, Help, Updates and Diagnostics Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect: `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`
- Inspect: `macosx/MACKAN/Sources/MACKANKit/AppModel+Updates.swift`
- Inspect: `macosx/MACKAN/Sources/MACKANKit/DiagnosticsReport.swift`

- [ ] **Step 1: Launch the app visibly**

Run:

```sh
open /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
```

Expected: MACKAN opens with a visible main window and no Terminal window.

- [ ] **Step 2: Use computer-use to exercise app-level commands**

Run through:

```text
About MACKAN
Help > Check for Updates
Help > Copy Diagnostics and Report Client Issue
Help user guide/support links
Instance menu enablement with and without selected instance
Mods menu enablement with and without staged changes
Maintenance menu enablement with selected instance
```

Expected: every menu item either performs the documented action or is disabled
for an explained state. Any enabled no-op is `P1`.

- [ ] **Step 3: Validate app/update/diagnostic routes**

Run targeted tests:

```sh
swift test --package-path macosx/MACKAN --filter HelpLinkTests
swift test --package-path macosx/MACKAN --filter DiagnosticsBundleTests
dotnet test Tests/Tests.csproj --filter ServiceDispatcherTests
```

Expected: all exit `0`.

- [ ] **Step 4: Record screenshots and update rows**

Capture screenshots for About, update sheet and diagnostics result. Mark matching `APP-*` rows `pass`, `fail`, or `fixed`.

- [ ] **Step 5: Commit app-level audit evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN app-level commands"
```

Expected: commit succeeds.

## Task 9: Instances and Launch Live Mutation Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/SidebarViews.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/InstanceManagementSheets.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/InstanceEditorSheets.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Instances.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanInstanceProvider.cs`

- [ ] **Step 1: Exercise instance selection/default/reveal**

Use the real app to:

```text
Select each visible instance.
Set a non-default instance as default when more than one instance exists.
Reveal selected game folder.
Open Manage Instances sheet.
Use row Select, Default, Reveal and Done actions.
```

Expected: selection/default state updates visibly; Finder reveal opens the selected path; Manage Instances row state matches sidebar state.

- [ ] **Step 2: Exercise add/clone/fake/rename/forget**

Use real UI:

```text
Add Instance through folder picker when a valid existing KSP/KSP2 folder is available.
Clone selected instance to a user-chosen destination.
Create Fake Instance with KSP or KSP2 game selector.
Rename one audit-created instance.
Forget one audit-created instance.
```

Expected: each mutation is visible in sidebar and `instances.list`; forgotten instance is removed from CKAN config, not necessarily from disk.

- [ ] **Step 3: Exercise launch command paths**

Use real UI:

```text
Open Launch Command Lines.
Add a command line.
Save.
Launch with default command.
Launch with configured command.
Reset command lines to defaults.
```

Expected: launch either starts the game or shows typed launch failure with retry guidance. An enabled launch button that silently does nothing is `P1`.

- [ ] **Step 4: Run instance tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter AppModelTests
swift test --package-path macosx/MACKAN --filter LaunchErrorPresentationStateTests
dotnet test Tests/Tests.csproj --filter CoreMackanInstanceProviderTests
```

Expected: all exit `0`.

- [ ] **Step 5: Commit instance audit evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN instance and launch workflows"
```

Expected: commit succeeds.

## Task 10: Repositories Live Mutation Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/RepositoryPreferencesView.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Repositories.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanRepositoryProvider.cs`

- [x] **Step 1: Exercise repository list and canonical sources**

Use Settings > Repositories:

```text
Open Repositories pane.
Open Add Repository sheet.
Select an available canonical repository row.
Confirm name and URL fields populate.
Cancel.
```

Expected: canonical sources are visible and selection populates fields without mutation.

- [x] **Step 2: Exercise add/remove/reorder mutation**

Use real UI:

```text
Add the first canonical repository not already configured.
If every canonical repository is already configured, add custom repository named "MACKAN Audit Repository" with URL "https://github.com/KSP-CKAN/CKAN-meta/archive/master.zip".
Move the added repository up once when enabled.
Move the added repository down once when enabled.
Remove the added repository.
```

Expected: table order and repository list reflect each change. Disabled move buttons must match row position.

- [x] **Step 3: Exercise refresh/status/cancel**

Use toolbar or Mods menu:

```text
Start Refresh Repositories.
Observe progress events.
Use cancel when refresh is still active.
Start refresh again and let it complete.
```

Expected: running/cancelling/completed state is visible and repository metadata updates or reports typed download failure.

- [x] **Step 4: Run repository tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter ModalSheetLayoutPolicyTests
swift test --package-path macosx/MACKAN --filter AppModelTests
/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter CoreMackanRepositoryProviderTests
/opt/homebrew/bin/dotnet test Tests/Tests.csproj --framework net10.0 --filter ServiceDispatcherTests
```

Expected: all exit `0`.

- [x] **Step 5: Commit repository audit evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN repository workflows"
```

Expected: commit succeeds.

## Task 11: Catalog, Labels and Inspector Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/CatalogViews.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/LabelsManagerSheet.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Catalog.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/ModuleSearchQuery.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanModuleProvider.cs`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanLabelProvider.cs`

- [x] **Step 1: Exercise loading and empty states**

Use real app:

```text
Select an instance with catalog.
Observe Loading catalog state if it appears.
Select no module and inspect contextual empty state.
Select a module and verify inspector tabs populate.
```

Expected: loading/empty states are specific and do not block table interaction after catalog load completes.

- [x] **Step 2: Exercise search/filter/tag/sort/columns**

Use real app:

```text
Type "is:installed" in search.
Use Search Syntax menu insertion.
Apply Installed, Not Installed, Upgradable, Compatible, Incompatible, Cached, Uncached, New and Replaceable filters where available.
Apply Tag filter.
Change primary sort.
Add secondary sort.
Hide and show at least five columns.
Resize table columns.
```

Expected: table contents update; selected module state remains coherent; persisted state survives app relaunch.

- [x] **Step 3: Exercise row/action behavior**

Use deterministic selection rule:

```text
Sort by identifier ascending.
Select the first compatible not-installed module visible in the filtered catalog.
Record its exact identifier in the evidence log before staging any change.
Double-click the row.
Open action menu.
Stage install.
Clear staged action.
Select an installed non-autodetected module if present.
Toggle auto-installed state.
```

Expected: staged strip/action badges update and inspector follows selected row.

- [x] **Step 4: Exercise labels**

Use real UI:

```text
Open Labels Manager.
Create label named "MACKAN Audit Label".
Set a color.
Toggle at least two label flags.
Save.
Apply label to selected module.
Filter/search by label.
Delete "MACKAN Audit Label".
```

Expected: label appears in sidebar/search, applies to selected module, then disappears after delete.

- [x] **Step 5: Exercise inspector tabs**

For one selected module, verify:

```text
Overview cards and details.
Relationships graph/tree.
Versions list.
Contents path list.
Resources link list.
Long description scrolling.
```

Expected: no critical clipping, resource links are selectable/openable, relationship rows are accessible.

- [x] **Step 6: Run catalog/inspector tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter CatalogReadinessPresentationStateTests
swift test --package-path macosx/MACKAN --filter InspectorEmptyPresentationStateTests
swift test --package-path macosx/MACKAN --filter ModuleRelationshipGraphTests
swift test --package-path macosx/MACKAN --filter ModuleActionPresentationStateTests
swift test --package-path macosx/MACKAN --filter CatalogToolbarLayoutPolicyTests
dotnet test Tests/Tests.csproj --filter CoreMackanModuleProviderTests
```

Expected: all exit `0`.

- [x] **Step 7: Commit catalog/inspector evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN catalog and inspector workflows"
```

Expected: commit succeeds.

## Task 12: Change Set and Operations Live Mutation Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/OperationSheets.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Operations.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanChangeSetProvider.cs`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanOperationProvider.cs`

- [ ] **Step 1: Exercise preview without apply**

Use real app:

```text
Stage install for the deterministic module selected in Task 11.
Open Change Set Preview.
Observe changes table.
Close preview.
Clear staged changes.
```

Expected: preview shows change rows and Clear/Close/Apply state is coherent.

- [ ] **Step 2: Exercise install/apply mutation**

Use real app:

```text
Stage install for the deterministic compatible not-installed module.
Preview.
Apply Changes.
Observe operation result timeline until complete or typed failure.
Refresh operation status.
Close sheet.
Verify installed state in catalog.
```

Expected: module installs or a typed recoverable error appears. Silent failure is `P0`.

- [ ] **Step 3: Exercise remove mutation**

Use real app:

```text
Select the module installed in Step 2.
Stage remove.
Preview.
Apply Changes.
Verify module is no longer installed.
```

Expected: remove transaction completes or surfaces typed recoverable error.

- [ ] **Step 4: Exercise upgrade/replace/provider/recommendation/conflict paths when real catalog exposes them**

Use real app:

```text
Stage Upgrade All if upgradable modules exist.
Stage Replace for a replaceable module if one exists.
Trigger provider choice when preview presents alternatives.
Select a provider and re-preview.
Stage optional recommendation when preview presents recommendations.
Trigger conflict path if the selected module set naturally creates one.
```

Expected: rows with unavailable real preconditions are marked `deferred` with reason `not present in current live catalog`; rows with visible preconditions must be tested.

- [ ] **Step 5: Exercise cancel/retry/recovery controls**

Use operation sheet:

```text
Start an async operation that remains active long enough for status polling.
Press Refresh Status.
Press Cancel when enabled.
For typed failed download notice, press Retry and Skip failed downloads when available.
For registry lock notice, inspect path and do not press Remove Lock File unless the app surfaces a stale lock in the current selected instance.
```

Expected: cancel/status/retry controls mutate operation state and never become enabled no-ops.

- [ ] **Step 6: Run operation tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter OperationFlowStateTests
swift test --package-path macosx/MACKAN --filter OperationRetryStateTests
swift test --package-path macosx/MACKAN --filter OperationPresentationStateTests
swift test --package-path macosx/MACKAN --filter OperationActivityStateTests
dotnet test Tests/Tests.csproj --filter CoreMackanChangeSetProviderTests
dotnet test Tests/Tests.csproj --filter CoreMackanOperationProviderTests
```

Expected: all exit `0`.

- [ ] **Step 7: Commit change-set/operation evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN change-set and operation workflows"
```

Expected: commit succeeds.

## Task 13: File Workflows Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/ExportModpackSheet.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/OperationSheets.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Operations.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanExportProvider.cs`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanOperationProvider.cs`

- [ ] **Step 1: Export mod list formats**

Use Mods menu:

```text
Export Mod List > Plain text.
Export Mod List > Markdown.
Export Mod List > BBCode.
Export Mod List > CSV.
Export Mod List > TSV.
Save each file under /tmp/mackan-full-ui-function-audit-2026-06-06/.
```

Expected: each save panel succeeds and each saved file is non-empty.

- [ ] **Step 2: Export modpack**

Use Mods menu:

```text
Open Export Modpack.
Enter identifier "MACKAN-Audit-Pack".
Enter name "MACKAN Audit Pack".
Enter summary "MACKAN audit export".
Enter author "MACKAN Audit".
Enter version "1.0.0".
Enter license "MIT".
Toggle include pinned versions.
Toggle include optional relationships.
Set at least one installed module relationship to Depends, Recommends, Suggests and Ignore when enough installed modules exist.
Save under /tmp/mackan-full-ui-function-audit-2026-06-06/MACKAN-Audit-Pack.ckan.
```

Expected: exported `.ckan` file exists and is non-empty.

- [ ] **Step 3: Install from `.ckan`**

Use Mods menu:

```text
Install from File.
Select /tmp/mackan-full-ui-function-audit-2026-06-06/MACKAN-Audit-Pack.ckan.
Observe operation sheet or preview.
Exercise provider/recommendation/incompatible notices if they appear.
Close after recording result.
```

Expected: app either installs/previews valid file content or reports typed `.ckan` incompatibility; silent no-op is `P1`.

- [ ] **Step 4: Import downloads**

Use Mods menu:

```text
Import Downloads.
Select a real downloaded archive/folder if available.
Toggle Install imported modules.
Toggle Preview install changes before applying.
Toggle Delete imported files after successful import only when selected test input can be deleted.
Run Import.
```

Expected: app reports matched imports, preview or operation result, and delete-original behavior matches toggle.

- [ ] **Step 5: Run file/export tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter ImportDownloadsDraftTests
swift test --package-path macosx/MACKAN --filter CkanFileInstallDraftTests
swift test --package-path macosx/MACKAN --filter FileImportFlowStateTests
dotnet test Tests/Tests.csproj --filter CoreMackanExportProviderTests
dotnet test Tests/Tests.csproj --filter CoreMackanOperationProviderTests
```

Expected: all exit `0`.

- [ ] **Step 6: Commit file workflow evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN file workflows"
```

Expected: commit succeeds.

## Task 14: Maintenance Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/MaintenanceSheets.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/SidebarViews.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Maintenance.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanMaintenanceProvider.cs`

- [ ] **Step 1: Exercise scan/unmanaged files**

Use Maintenance menu and sidebar:

```text
Scan GameData.
View Unmanaged Files.
Reveal a file-backed unmanaged row if present.
Close sheet.
```

Expected: scan result is visible; unmanaged list reflects CKAN Core scan state.

- [ ] **Step 2: Exercise history and play time**

Use Maintenance sidebar:

```text
Open Installation History.
Select a history snapshot.
Stage restore/missing modules if action is enabled.
Open Play Time.
Edit one instance's hours by adding 0.01.
Save.
Refresh/reopen Play Time.
```

Expected: history actions stage correct preview rows; play time persists the edited value.

- [ ] **Step 3: Exercise download statistics**

Use Maintenance sidebar:

```text
Open Download Statistics.
Inspect stacked chart.
Inspect host table.
Open support links when available.
Resize sheet.
```

Expected: chart/table do not overlap and link actions work or are disabled.

- [ ] **Step 4: Exercise cache maintenance**

Use Maintenance > Clean Cache:

```text
Open Cache Maintenance.
Open cache folder if button exists.
Run Purge to Limit.
Run Purge All only after recording current cache file count in evidence.
Close sheet.
```

Expected: result sheet/event text reflects cache mutation. Empty cache after purge is acceptable.

- [ ] **Step 5: Exercise deduplicate and repair**

Use Maintenance menu:

```text
Deduplicate Files.
Confirm destructive prompt.
Record result events.
Repair Registry.
Confirm destructive prompt.
Record result events.
```

Expected: result sheets show captured Core events; app refreshes selected-instance state after repair.

- [ ] **Step 6: Run maintenance tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter DownloadStatisticsChartTests
dotnet test Tests/Tests.csproj --filter CoreMackanMaintenanceProviderTests
```

Expected: all exit `0`.

- [ ] **Step 7: Commit maintenance evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN maintenance workflows"
```

Expected: commit succeeds.

## Task 15: Settings Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/PreferencesViews.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/*PreferencesView.swift`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKANKit/AppModel+Settings.swift`
- Inspect/fix if needed: `MACKAN.Service/CoreMackanSettingsProvider.cs`

- [ ] **Step 1: Exercise General and Cache panes**

Use Settings:

```text
Toggle Check for CKAN updates on launch.
Toggle Use CKAN dev builds.
Toggle Update repositories on launch.
Toggle Auto-sort by update after staging upgrades.
Save.
Open Cache pane.
Edit cache size limit.
Toggle unlimited cache size.
Use cache migration choice picker.
Save.
```

Expected: Save enablement matches changes and saved values reload.

- [ ] **Step 2: Exercise Compatibility and Stability panes**

Use Settings:

```text
Open Compatibility.
Toggle one known game version.
Add a custom version "999.999-mackan-audit".
Save.
Clear the custom version if UI supports removal.
Open Stability.
Change overall tolerance.
Add module override for a real selected module identifier.
Clear the override.
```

Expected: values persist through sidecar and selected-instance refresh follows save.

- [ ] **Step 3: Exercise Hosts and Filters panes**

Use Settings:

```text
Open Hosts.
Move one host into preferred list.
Move it up and down.
Remove it.
Save.
Open Filters.
Append one preset.
Edit global filter text.
Edit instance filter text.
Clear filters.
Save.
```

Expected: list movement, preset dedupe and save state are visible.

- [ ] **Step 4: Exercise Launch, Auth and Plugins panes**

Use Settings:

```text
Open Launch.
Add command line "MACKAN_AUDIT_COMMAND".
Save.
Reset to defaults.
Open Auth.
Add host "mackan-audit.invalid" with token "mackan-audit-token".
Verify saved token is masked and raw value is not displayed.
Remove the dummy token.
Open Plugins.
Verify unsupported status text and no broken controls.
```

Expected: dummy token add/remove works without exposing raw saved token; Plugins pane is intentionally unsupported and clear.

- [ ] **Step 5: Run settings tests**

Run:

```sh
swift test --package-path macosx/MACKAN --filter PreferencesLayoutPolicyTests
dotnet test Tests/Tests.csproj --filter CoreMackanSettingsProviderTests
```

Expected: all exit `0`.

- [ ] **Step 6: Commit settings evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN settings workflows"
```

Expected: commit succeeds.

## Task 16: Adaptive Layout, Accessibility and Localization Audit

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/Resources/en.lproj/Localizable.strings`
- Inspect/fix if needed: `macosx/MACKAN/Sources/MACKAN/Resources/ru.lproj/Localizable.strings`
- Inspect/fix if needed: layout policy files in `macosx/MACKAN/Sources/MACKANKit`

- [ ] **Step 1: Re-run adaptive screenshot capture**

Run:

```sh
macosx/MACKAN/scripts/run-ui-ux-audit.sh --wait-catalog 60 --output /tmp/mackan-full-ui-function-audit-2026-06-06-adaptive /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
```

Expected: command exits `0` and captures minimum, medium and wide screenshots.

- [ ] **Step 2: Inspect adaptive screenshots**

Use computer-use or image inspection for:

```text
No overlapping critical text.
No clipped primary action labels.
Visible sidebar/content/inspector relationship.
Toolbar buttons fit.
Table columns remain usable.
Sheets remain scrollable.
```

Expected: every blocking visual defect becomes P0/P1 row.

- [ ] **Step 3: Run accessibility smoke**

Run:

```sh
macosx/MACKAN/scripts/test-accessibility-smoke.sh
```

Expected: exit `0`.

- [ ] **Step 4: Check localization resource coverage**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
en = Path("macosx/MACKAN/Sources/MACKAN/Resources/en.lproj/Localizable.strings").read_text()
ru = Path("macosx/MACKAN/Sources/MACKAN/Resources/ru.lproj/Localizable.strings").read_text()
def keys(text):
    return {line.split("=", 1)[0].strip().strip('"') for line in text.splitlines() if "=" in line and line.strip().startswith('"')}
missing = sorted(keys(en) - keys(ru))
for key in missing:
    print(key)
raise SystemExit(1 if missing else 0)
PY
```

Expected: exit `0`; missing Russian keys become `SET-LOCALIZATION` rows.

- [ ] **Step 5: Commit adaptive/accessibility evidence**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: audit MACKAN adaptive UI and accessibility"
```

Expected: commit succeeds.

## Task 17: P0/P1 Fix Loop

**Files:**
- Modify: files named in each failing matrix row.
- Modify tests closest to each defect.
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`

- [ ] **Step 1: List open P0/P1 rows**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
rows = []
for line in Path("docs/mackan/full-ui-function-audit-matrix.md").read_text().splitlines():
    if line.startswith("|") and ("| P0 |" in line or "| P1 |" in line) and "| fail |" in line:
        rows.append(line)
for row in rows:
    print(row)
raise SystemExit(1 if rows else 0)
PY
```

Expected: if rows print, execution continues with scoped fixes; if exit `0`, skip to Task 18.

- [ ] **Step 2: For each printed P0/P1 row, create a scoped fix note**

Add a `Defects` entry in `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md` with:

```text
Matrix Row
Severity
Observed behavior
Expected behavior
Owner Files
Targeted test command
Real-app retest action
```

Expected: no P0/P1 row lacks owner files and a test command.

- [ ] **Step 3: Create a child fix plan for the first P0/P1 row**

Before editing source code, create a scoped child plan under
`docs/superpowers/plans/` for the first printed row. The child plan must name
one exact matrix row id, exact owner files from the defect note, exact test file
to modify, exact failing test content, exact implementation target, exact
targeted command and exact real-app retest action.

Generate the child plan path with:

```sh
python3 - <<'PY'
import re
from pathlib import Path
for line in Path("docs/mackan/full-ui-function-audit-matrix.md").read_text().splitlines():
    if line.startswith("|") and ("| P0 |" in line or "| P1 |" in line) and "| fail |" in line:
        row_id = line.strip("|").split("|", 1)[0].strip()
        slug = re.sub(r"[^a-z0-9]+", "-", row_id.lower()).strip("-")
        print(f"docs/superpowers/plans/2026-06-06-mackan-audit-row-{slug}-fix.md")
        break
PY
```

Use the printed path for the child plan.

Expected: one child plan exists for the selected failing row and contains no
placeholder text.

- [ ] **Step 4: Execute the child fix plan**

Use `superpowers:subagent-driven-development` for the child plan when possible.
If subagents are unavailable, use `superpowers:executing-plans`. The child plan
owns all source/test edits for that defect.

Expected: child plan ends with targeted automated proof passing and real-app row
proof captured under `/tmp/mackan-full-ui-function-audit-2026-06-06/`.

- [ ] **Step 5: Update matrix row and evidence**

After the child plan succeeds, update:

```text
docs/mackan/full-ui-function-audit-matrix.md
docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
```

The matrix row status changes from `fail` to `fixed`. The evidence row records
the child plan path, commit hash, targeted command result and real-app proof
path.

Expected: the fixed row no longer appears in Step 1 output.

- [ ] **Step 6: Commit the matrix/evidence update**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: record fixed MACKAN audit row"
```

Expected: commit succeeds. Source/test edits are committed by the child fix
plan, not by this evidence update step.

- [ ] **Step 7: Repeat until no P0/P1 fail rows remain**

Run Step 1 again after each fix commit. Continue until Step 1 exits `0`.

## Task 18: P2/P3 Triage

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-matrix.md`
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`

- [ ] **Step 1: List open P2/P3 rows**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
rows = []
for line in Path("docs/mackan/full-ui-function-audit-matrix.md").read_text().splitlines():
    if line.startswith("|") and ("| P2 |" in line or "| P3 |" in line) and "| fail |" in line:
        rows.append(line)
for row in rows:
    print(row)
PY
```

Expected: printed rows are triaged.

- [ ] **Step 2: Fix quick P2 defects**

Apply the same loop as Task 17 for any P2 defect that is local, low-risk and
has a direct test/evidence path.

Expected: fixed P2 rows become `fixed`.

- [ ] **Step 3: Defer remaining P2/P3 rows explicitly**

For each remaining P2/P3 row, set status `deferred` and add a concrete reason
in `Defect Link`, such as:

```text
post-rc-polish-long-copy
post-rc-optional-shortcut
post-rc-nonblocking-layout-polish
```

Expected: no row remains `fail` without a decision.

- [ ] **Step 4: Commit P2/P3 triage**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: triage nonblocking MACKAN audit findings"
```

Expected: commit succeeds if rows changed.

## Task 19: Final Gates

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`
- Modify when status claims change: `docs/mackan/parity-matrix.md`
- Modify when gate wording changes: `docs/mackan/release-execution-checklist.md`
- Modify when final evidence is linked: `docs/mackan/README.md`

- [ ] **Step 1: Verify no unclosed matrix rows**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
bad_status = []
allowed = {"pass", "fixed", "deferred", "intentionally-unsupported"}
for line in Path("docs/mackan/full-ui-function-audit-matrix.md").read_text().splitlines():
    if not line.startswith("|") or line.startswith("| ---") or line.startswith("| ID "):
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) >= 12 and cells[11] not in allowed:
        bad_status.append(line)
for row in bad_status:
    print(row)
raise SystemExit(1 if bad_status else 0)
PY
```

Expected: exit `0`.

- [ ] **Step 2: Run full Swift and .NET gates**

Run:

```sh
swift test --package-path macosx/MACKAN
dotnet test Tests/Tests.csproj --filter MACKAN
```

Expected: both exit `0`.

- [ ] **Step 3: Run script gates**

Run:

```sh
macosx/MACKAN/scripts/test-run-ui-ux-audit.sh
macosx/MACKAN/scripts/test-accessibility-smoke.sh
macosx/MACKAN/scripts/build-dev-app.sh
macosx/MACKAN/scripts/verify-app-bundle.sh --mode auto --require-icon --require-version 0.1.0 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 /Users/elijahn/Library/Caches/MACKAN/build/MACKAN.app
```

Expected: all exit `0`.

- [ ] **Step 4: Run real-app audit evidence verification**

Run:

```sh
macosx/MACKAN/scripts/verify-ui-ux-audit-evidence.sh /tmp/mackan-full-ui-function-audit-2026-06-06
```

Expected: exit `0`.

- [ ] **Step 5: Run strict release readiness**

Run:

```sh
MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS=true macosx/MACKAN/scripts/release-check.sh --skip-launch
macosx/MACKAN/scripts/release-readiness.sh --strict --json
```

Expected: both exit `0`; strict JSON reports `requiredParityPending` as `0` and `requiredParityParseFailures` as `0`.

- [ ] **Step 6: Update release docs only if claims changed**

If the audit changes readiness or parity claims, update:

```text
docs/mackan/parity-matrix.md
docs/mackan/release-execution-checklist.md
docs/mackan/README.md
```

Expected: changed docs cite the matrix/evidence file and do not claim a gate passed unless the command log contains the passing command.

- [ ] **Step 7: Commit final audit closeout**

Run:

```sh
git add docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md docs/mackan/parity-matrix.md docs/mackan/release-execution-checklist.md docs/mackan/README.md
git commit -m "docs: close MACKAN full UI function audit"
```

Expected: commit succeeds. If some listed docs did not change, remove them from `git add` before committing.

## Task 20: Execution Summary

**Files:**
- Modify: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`

- [ ] **Step 1: Write final summary**

Add a final section to the evidence file:

```markdown
## Final Summary

- Matrix rows closed:
- P0/P1 remaining:
- P2/P3 deferred:
- Real mutations performed:
- Final Swift gate:
- Final .NET gate:
- Final UI/UX evidence gate:
- Final strict readiness:
- Known release blockers:
```

Each bullet must contain a concrete value before the final commit.

- [ ] **Step 2: Verify summary has no empty values**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
text = Path("docs/mackan/full-ui-function-audit-evidence-2026-06-06.md").read_text()
section = text.split("## Final Summary", 1)[1]
empty = [line for line in section.splitlines() if line.strip().endswith(":")]
for line in empty:
    print(line)
raise SystemExit(1 if empty else 0)
PY
```

Expected: exit `0`.

- [ ] **Step 3: Commit final summary**

Run:

```sh
git add docs/mackan/full-ui-function-audit-evidence-2026-06-06.md
git commit -m "docs: summarize MACKAN full audit results"
```

Expected: commit succeeds if evidence summary changed.

## Completion Criteria

This plan is complete when:

- `docs/mackan/full-ui-function-audit-matrix.md` exists and covers all current UI surfaces, controls, states, public sidecar routes and behavior-owning AppModel paths.
- `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md` records command output, screenshots/artifacts, live mutations and defect decisions.
- No P0/P1 matrix row remains `fail`.
- Every code fix has a targeted automated proof and real-app proof.
- Final gates in Task 19 pass or are recorded as environment blockers with exact command output.
- The final response reports changed files, commits, commands run and remaining blockers.

# MACKAN Build & Verification Analysis

## 1. Project Build Configuration & Compilation Commands

The macOS application part of MACKAN is structured as a Swift Package located in `macosx/MACKAN/`. It consists of:
- **`MACKANKit`**: A Swift library containing the core logic, model, API client definitions, and state structs.
- **`MACKAN`**: A Swift executable target that defines the SwiftUI views and app entry point, depending on `MACKANKit`.

### Raw Build Commands
To compile the Swift project targets individually:
- Build package: `swift build --package-path macosx/MACKAN`
- Build package in release configuration: `swift build --package-path macosx/MACKAN -c release`

### Application Packaging & Developer Build Script
Because the native macOS app requires a bundled `.NET` sidecar service (`MACKAN.Service`) to communicate with the CKAN Core library, a developer helper script is provided to compile and pack the entire app bundle:
- Command: `macosx/MACKAN/scripts/build-dev-app.sh`
- This script does the following:
  1. Compiles the Swift executable `MACKAN` (using single-arch or universal `--universal` triples).
  2. Runs `dotnet publish` on `MACKAN.Service/MACKAN.Service.csproj` to compile the C# sidecar service.
  3. Packages everything into an app bundle (`MACKAN.app`) inside `~/Library/Caches/MACKAN/build` (or customized via `$BUILD_ROOT`).
  4. Bundles the app icon and generates an `Info.plist`.
  5. Performs ad-hoc codesigning on the resulting app bundle.

---

## 2. Test Suite Commands

MACKAN has testing setups covering both Swift code and .NET contract interactions:

- **Swift Unit Tests**: Test the presentation states, formatting, utility types, and API client mocks.
  - Run command: `swift test --package-path macosx/MACKAN`
- **.NET Integration / Contract Tests**: Verify that the JSON-RPC communication between the macOS client and the .NET service behaves according to expectations.
  - Run command: `dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN`
- **Full Release Check / Gate**: Verifies Swift tests, .NET tests, NuGet vulnerabilities, bundle validation, DMG creation, and launch smoke checks.
  - Run command: `macosx/MACKAN/scripts/release-check.sh --skip-launch`

---

## 3. Sheet Structure & Compilation after Refactoring State

### Current Sheet Structure
Sheets in the project are primarily structured in the following locations:
1. **App-wide Sheets (`MACKANApp.swift`)**:
   Declared as modifiers on `MainWindowView` in `MACKANApp`:
   - `LaunchCommandLinesSheet` (bound to `$isEditingLaunchCommandLines`)
   - `InstanceManagementSheet` (bound to `$isManagingInstances`)
   - `AddInstanceSheet` (bound to `$isAddingInstance`)
   - `CloneInstanceSheet` (bound to `$isCloningInstance`)
   - `FakeInstanceSheet` (bound to `$isFakingInstance`)
   - `ExportModpackSheet` (bound to `$isExportingModpack`)
   - `AboutMACKANSheet` (bound to `$isShowingAbout`)
   - `UpdateCheckSheet` (bound to `$isShowingUpdateCheck`)

2. **Main Window Sheets (`MainWindowView.swift`)**:
   - `ChangeSetPreviewSheet` (bound to `operationSheetIsPresented(.changePreview)`)
   - `OperationResultSheet` (bound to `operationSheetIsPresented(.operationResult)`)
   - `ImportDownloadsOptionsSheet` (bound to `$fileImports.isShowingImportDownloadsOptions`)
   - `LaunchWarningSheet` (bound to `pendingLaunchWarningIsPresented`)
   - **Maintenance Sheets**: `UnmanagedFilesSheet`, `InstallationHistorySheet`, `PlayTimeSheet`, `DownloadStatisticsSheet`, and `CacheMaintenanceSheet`. These are conditionally presented as sheets (via `maintenanceSheetIsPresented(for:)`) if they are *not* currently active as full-screen content panes (checked via `model.shouldPresentMaintenanceSheet(for:)`).
   - `DeduplicateResultSheet` (bound to `deduplicateResultIsPresented`)
   - `RepairRegistryResultSheet` (bound to `repairRegistryResultIsPresented`)

3. **Sub-view Sheets**:
   - `SaveSearchSheet` (bound to `$isShowingSaveSearchSheet` in `CatalogViews.swift`)
   - `LabelsManagerSheet` (bound to `$isShowingLabelsManagerSheet` in `CatalogViews.swift`)
   - Add Repository Sheet (bound to `$isAddingRepository` in `RepositoryPreferencesView.swift`)
   - Rename Instance Sheet (bound to `isShowingRenameSheet` in `SidebarViews.swift` & `InstanceManagementSheets.swift`)

### State Management & Compilation after Refactor
If sheet presentation state is refactored (for example, moving the `@State` booleans from `MACKANApp`/`MainWindowView` to a unified router/navigator object or centralizing it in `AppModel`), you can compile and verify the project using:
1. **Iterative compilation**: Run `swift build --package-path macosx/MACKAN` to check for compiler errors.
2. **Swift tests**: Run `swift test --package-path macosx/MACKAN` to ensure any states tested by `OperationFlowStateTests` and `OperationPresentationStateTests` are correct.
3. **Smoke tests**: Run `macosx/MACKAN/scripts/build-dev-app.sh` and perform manual verification on the compiled app bundle in `~/Library/Caches/MACKAN/build/MACKAN.app`.

---

## 4. Existing Test Coverage (Sheets, Routing, and App Initialization)

There are extensive existing unit tests in `Tests/MACKANKitTests/` that cover sheet, routing, and app initialization logic:

### App Initialization Tests
Located in `Tests/MACKANKitTests/AppModelTests.swift`:
- `testInitialProductionStateDoesNotExposeSampleInstancesOrModules()`: Asserts that a new `AppModel` begins with empty collections, no active selections, and nil models.
- `testRefreshLoadsInstancesFromSidecar()`: Asserts that calling `refresh()` fetches KSP instances, repository info, and launch commands, and sets the sidecar and health state appropriately.
- `testRefreshMarksServiceReadyBeforeInstanceCatalogFinishesLoading()`: Asserts that the app transitionally reports ready/loading state during the registry read sequence.

### Sheet & Routing State Tests
1. **Maintenance & Navigation Routing (`AppModelTests.swift`)**:
   - `testMaintenancePaneSelectionUsesPersistentMainContentRouteUntilInstanceSelection()`: Asserts that selected maintenance route persists correctly and reverts to the catalog route when the game instance selection changes.
   - `testMaintenancePaneSheetPresentationIsSuppressedByPersistentPane()`: Asserts that `shouldPresentMaintenanceSheet(for:)` properly yields `true` when a maintenance result is available *only if* the user is not already displaying that pane in the main content routing area.

2. **Operation Flow & Sheet Presentation (`OperationFlowStateTests.swift` & `OperationPresentationStateTests.swift`)**:
   - `testPresentationKeepsSheetsMutuallyExclusive()`: Asserts that only one operation sheet (e.g. `.changePreview` vs `.operationResult`) can be presented at a time.
   - `testPresentingOneSheetExcludesTheOther()`, `testDismissOnlyClearsMatchingSheet()`, and `testClearRemovesAnyPresentedSheet()`: Verify basic state management of the `OperationPresentationState` struct.
   - `testImportDownloadsResultPresentationDependsOnPreviewAndChangeSet()`: Asserts that the flow dynamically routes the user to either the change preview sheet or the operation result sheet depending on their preference and pending actions.
   - `testRegistryLockRemovalRequestIsExplicitAndClearable()`: Asserts the lifecycle of sheet prompts for removing locked CKAN registries.

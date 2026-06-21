# Modal Sheets State Management Analysis

## Overview
This report provides a detailed analysis of how modal sheets are currently opened and closed in the MACKAN macOS project, including a full inventory of existing flags, views, and parent files. It also details the build and test process and proposes a comprehensive refactoring strategy using centralized enums/Routers.

---

## 1. Project Build & Test Process
The macOS portion of the MACKAN project is structured as a Swift Package Manager (SPM) package.
- **Package Manifest**: `/Users/elijahn/GitHub/MACKAN/macosx/MACKAN/Package.swift`
- **Build Command**: `swift build` (executed within `/Users/elijahn/GitHub/MACKAN/macosx/MACKAN`)
- **Test Command**: `swift test` (executed within `/Users/elijahn/GitHub/MACKAN/macosx/MACKAN`)
  - Running `swift test` executes 309 unit tests in `MACKANKitTests` target, all of which pass successfully in ~0.2 seconds.
- **Application Bundle Build**: The root `/Users/elijahn/GitHub/MACKAN/macosx/Makefile` builds the `CKAN.app` and `.dmg` package by wrapping the C# `.net10.0` CKAN Core client and the MACKAN Swift frontend.

---

## 2. Inventory of Existing Modal Sheets
Modal sheets are scattered across multiple SwiftUI views, using separate `@State private var isShowing...: Bool` or custom binding states. Below is the complete inventory of the 24 modal sheets found in the application:

### A. App-Level Sheets (in `MACKANApp.swift`)
All sheets here are attached directly to the main `WindowGroup`'s scene body.
1. **`LaunchCommandLinesSheet`**
   - **Trigger Flag**: `@State private var isEditingLaunchCommandLines = false` (line 10)
   - **View Modifier**: `.sheet(isPresented: $isEditingLaunchCommandLines) { LaunchCommandLinesSheet(model: model) }` (lines 52-54)
   - **Trigger Point**: Command menu item "Edit Command Lines..." (line 178)
2. **`InstanceManagementSheet`**
   - **Trigger Flag**: `@State private var isManagingInstances = false` (line 11)
   - **View Modifier**: `.sheet(isPresented: $isManagingInstances) { InstanceManagementSheet(...) }` (lines 55-61)
   - **Trigger Point**: Command menu item "Manage Instances..." (line 129)
3. **`AddInstanceSheet`**
   - **Trigger Flag**: `@State private var isAddingInstance = false` (line 12)
   - **View Modifier**: `.sheet(isPresented: $isAddingInstance) { AddInstanceSheet(model: model) }` (lines 62-64)
   - **Trigger Point**: Command menu item "Add Instance" (line 134), or via the `onAdd` callback inside `InstanceManagementSheet` (line 58).
4. **`CloneInstanceSheet`**
   - **Trigger Flag**: `@State private var isCloningInstance = false` (line 13)
   - **View Modifier**: `.sheet(isPresented: $isCloningInstance) { CloneInstanceSheet(model: model) }` (lines 65-67)
   - **Trigger Point**: Command menu item "Clone Instance" (line 137), or via the `onClone` callback inside `InstanceManagementSheet` (line 59).
5. **`FakeInstanceSheet`**
   - **Trigger Flag**: `@State private var isFakingInstance = false` (line 14)
   - **View Modifier**: `.sheet(isPresented: $isFakingInstance) { FakeInstanceSheet(model: model) }` (lines 68-70)
   - **Trigger Point**: Command menu item "Fake Instance" (line 141), or via the `onFake` callback inside `InstanceManagementSheet` (line 60).
6. **`ExportModpackSheet`**
   - **Trigger Flag**: `@State private var isExportingModpack = false` (line 18)
   - **View Modifier**: `.sheet(isPresented: $isExportingModpack) { ExportModpackSheet(model: model) }` (lines 71-73)
   - **Trigger Point**: Command menu item "Export Modpack" (line 217)
7. **`AboutMACKANSheet`**
   - **Trigger Flag**: `@State private var isShowingAbout = false` (line 29)
   - **View Modifier**: `.sheet(isPresented: $isShowingAbout) { AboutMACKANSheet(info: model.aboutInfo()) }` (lines 74-76)
   - **Trigger Point**: Command menu item "About MACKAN" (line 123)
8. **`UpdateCheckSheet`**
   - **Trigger Flag**: `@State private var isShowingUpdateCheck = false` (line 30)
   - **View Modifier**: `.sheet(isPresented: $isShowingUpdateCheck) { UpdateCheckSheet(...) }` (lines 77-82)
   - **Trigger Point**: Help menu item "Check for Updates" (line 259), or automatically on launch inside `.task` if needed (line 113).

---

### B. Main Window Sheets (in `MainWindowView.swift`)
Attached to the root container of `MainWindowView`.
9. **`ChangeSetPreviewSheet`**
   - **Trigger Flag**: Derived binding from `operationFlow.isPresenting(.changePreview)` (line 281)
   - **View Modifier**: `.sheet(isPresented: operationSheetIsPresented(.changePreview)) { ChangeSetPreviewSheet(...) }`
   - **Trigger Point**: Toolbar/button triggers `previewChanges()` (lines 197, 781) which calls `model.resolveChanges()` and presents the sheet.
10. **`OperationResultSheet`**
    - **Trigger Flag**: Derived binding from `operationFlow.isPresenting(.operationResult)` (line 319)
    - **View Modifier**: `.sheet(isPresented: operationSheetIsPresented(.operationResult)) { OperationResultSheet(...) }`
    - **Trigger Point**: Triggered upon completion or failure of major sidecar operations (e.g. `applyChanges()`, `installCkanFiles()`, `importDownloads()`).
11. **`ImportDownloadsOptionsSheet`**
    - **Trigger Flag**: `@State private var fileImports = FileImportFlowState()` binding `$fileImports.isShowingImportDownloadsOptions` (line 359)
    - **View Modifier**: `.sheet(isPresented: $fileImports.isShowingImportDownloadsOptions) { ImportDownloadsOptionsSheet(...) }`
    - **Trigger Point**: Selecting file archives to import downloads in `presentImportDownloadsOpenPanel()` (line 605).
12. **`LaunchWarningSheet`**
    - **Trigger Flag**: Derived binding `pendingLaunchWarningIsPresented` mapping to `model.pendingLaunchWarning != nil` (line 373)
    - **View Modifier**: `.sheet(isPresented: pendingLaunchWarningIsPresented) { LaunchWarningSheet(...) }`
    - **Trigger Point**: Triggered when trying to launch the game with incompatible mods (line 101 in `AppModel`).
13. **`UnmanagedFilesSheet`**
    - **Trigger Flag**: Derived binding `maintenanceSheetIsPresented(for: .unmanagedFiles)` (line 386)
    - **View Modifier**: `.sheet(isPresented: maintenanceSheetIsPresented(for: .unmanagedFiles)) { UnmanagedFilesSheet(...) }`
    - **Trigger Point**: Help/Maintenance menu or Sidebar triggers `model.showMaintenancePane(.unmanagedFiles)` (line 228) which loads and displays unmanaged files results.
14. **`InstallationHistorySheet`**
    - **Trigger Flag**: Derived binding `maintenanceSheetIsPresented(for: .history)` (line 394)
    - **View Modifier**: `.sheet(isPresented: maintenanceSheetIsPresented(for: .history)) { InstallationHistorySheet(...) }`
    - **Trigger Point**: Maintenance menu item "Installation History" (line 231) or sidebar selection.
15. **`PlayTimeSheet`**
    - **Trigger Flag**: Derived binding `maintenanceSheetIsPresented(for: .playTime)` (line 407)
    - **View Modifier**: `.sheet(isPresented: maintenanceSheetIsPresented(for: .playTime)) { PlayTimeSheet(...) }`
    - **Trigger Point**: Maintenance menu item "Play Time" (line 235) or sidebar selection.
16. **`DownloadStatisticsSheet`**
    - **Trigger Flag**: Derived binding `maintenanceSheetIsPresented(for: .downloadStatistics)` (line 417)
    - **View Modifier**: `.sheet(isPresented: maintenanceSheetIsPresented(for: .downloadStatistics)) { DownloadStatisticsSheet(...) }`
    - **Trigger Point**: Maintenance menu item "Download Statistics" (line 239) or sidebar selection.
17. **`CacheMaintenanceSheet`**
    - **Trigger Flag**: Derived binding `maintenanceSheetIsPresented(for: .cache)` (line 424)
    - **View Modifier**: `.sheet(isPresented: maintenanceSheetIsPresented(for: .cache)) { CacheMaintenanceSheet(...) }`
    - **Trigger Point**: Maintenance menu item "Clean Cache" (line 251) or sidebar selection.
18. **`DeduplicateResultSheet`**
    - **Trigger Flag**: Derived binding `deduplicateResultIsPresented` checking if `model.lastDeduplicateResult != nil` (line 441)
    - **View Modifier**: `.sheet(isPresented: deduplicateResultIsPresented) { DeduplicateResultSheet(...) }`
    - **Trigger Point**: Triggered post-execution of file deduplication (line 472).
19. **`RepairRegistryResultSheet`**
    - **Trigger Flag**: Derived binding `repairRegistryResultIsPresented` checking if `model.lastRepairRegistryResult != nil` (line 448)
    - **View Modifier**: `.sheet(isPresented: repairRegistryResultIsPresented) { RepairRegistryResultSheet(...) }`
    - **Trigger Point**: Triggered post-execution of registry repair (line 485).

---

### C. Contextual/Child Sheets
20. **`SaveSearchSheet`** (in `CatalogViews.swift`)
    - **Trigger Flag**: `@State private var isShowingSaveSearchSheet = false` (line 176)
    - **View Modifier**: `.sheet(isPresented: $isShowingSaveSearchSheet) { SaveSearchSheet(...) }` (lines 424-436)
    - **Trigger Point**: Click on "Save Search" button in search bar.
21. **`LabelsManagerSheet`** (in `CatalogViews.swift`)
    - **Trigger Flag**: `@State private var isShowingLabelsManagerSheet = false` (line 177)
    - **View Modifier**: `.sheet(isPresented: $isShowingLabelsManagerSheet) { LabelsManagerSheet(model: model) }` (lines 438-440)
    - **Trigger Point**: Click on "Manage Labels..." in label filter dropdown (line 260).
22. **`InstanceManagementRenameSheet`** (in `InstanceManagementSheets.swift`)
    - **Trigger Flag**: Derived binding `isShowingRenameSheet` checking if local `@State private var pendingRename: InstanceManagementRow?` is not nil (line 95)
    - **View Modifier**: `.sheet(isPresented: isShowingRenameSheet) { InstanceManagementRenameSheet(...) }`
    - **Trigger Point**: Inline action button on instance row (line 69).
23. **`AddRepositorySheet`** (in `RepositoryPreferencesView.swift`)
    - **Trigger Flag**: `@State private var isAddingRepository = false` (line 137)
    - **View Modifier**: `.sheet(isPresented: $isAddingRepository) { AddRepositorySheet(...) }`
    - **Trigger Point**: Clicking the "+" (Add) button under repository settings list (line 122).
24. **`RenameInstanceSheet`** (in `SidebarViews.swift`)
    - **Trigger Flag**: Derived binding `isShowingRenameSheet` checking if local `@State private var instancePendingRename: GameInstanceSummary?` is not nil (line 274)
    - **View Modifier**: `.sheet(isPresented: isShowingRenameSheet) { RenameInstanceSheet(...) }`
    - **Trigger Point**: Context menu item "Rename..." on sidebar instance row.

---

## 3. Refactoring Plan & Strategy
To improve state encapsulation, eliminate bugs due to overlapping sheets, and reduce SwiftUI view modifier clutter, we propose refactoring the sheet management using **Centralized Enums** and a **Router Pattern**.

### Phase 1: Consolidate App-Level Sheets in `MACKANApp.swift`
We replace the 8 boolean `@State` variables with a single `@State private var presentedAppSheet: AppSheet? = nil` using a new enum.

#### Proposed Code Structure
```swift
// In a new file AppNavigation.swift (or directly inside MACKANApp.swift)
public enum AppSheet: Identifiable, Equatable, Hashable, Sendable {
    case editLaunchCommandLines
    case manageInstances
    case addInstance
    case cloneInstance
    case fakeInstance
    case exportModpack
    case about
    case updateCheck
    
    public var id: Self { self }
}
```

In `MACKANApp.swift`, the sheet modifiers are simplified to a single `.sheet(item: $presentedAppSheet)`:
```swift
// BEFORE:
// @State private var isEditingLaunchCommandLines = false
// @State private var isManagingInstances = false
// ... [8 different booleans]

// AFTER:
@State private var presentedAppSheet: AppSheet? = nil

// Body View:
.sheet(item: $presentedAppSheet) { sheet in
    switch sheet {
    case .editLaunchCommandLines:
        LaunchCommandLinesSheet(model: model)
    case .manageInstances:
        InstanceManagementSheet(
            model: model,
            onAdd: { presentInstanceSubsheet { presentedAppSheet = .addInstance } },
            onClone: { presentInstanceSubsheet { presentedAppSheet = .cloneInstance } },
            onFake: { presentInstanceSubsheet { presentedAppSheet = .fakeInstance } }
        )
    case .addInstance:
        AddInstanceSheet(model: model)
    case .cloneInstance:
        CloneInstanceSheet(model: model)
    case .fakeInstance:
        FakeInstanceSheet(model: model)
    case .exportModpack:
        ExportModpackSheet(model: model)
    case .about:
        AboutMACKANSheet(info: model.aboutInfo())
    case .updateCheck:
        UpdateCheckSheet(
            model: model,
            onCheckStable: { checkForUpdates(useDevBuilds: false) },
            onCheckDev: { checkForUpdates(useDevBuilds: true) }
        )
    }
}
```
**Benefits:**
- Reduces scene-level boilerplate in `MACKANApp.swift` significantly.
- Ensures absolute mutual exclusivity: SwiftUI guarantees only one app-level sheet can show at a time.

---

### Phase 2: Consolidate Main Window Sheets in `MainWindowView.swift`
We replace the 11 separate `.sheet` modifiers in `MainWindowView.swift` with a single `.sheet(item: activeMainWindowSheet)` modifier using a unified enum.

#### Proposed Code Structure
```swift
// In a new navigation file or inside MainWindowView.swift
public enum MainWindowSheet: Identifiable, Equatable, Sendable {
    case changePreview
    case operationResult
    case importDownloadsOptions
    case launchWarning
    case unmanagedFiles
    case history
    case playTime
    case downloadStatistics
    case cache
    case deduplicateResult
    case repairRegistryResult

    public var id: Self { self }
}
```

In `MainWindowView.swift`, we define a read-write computed binding property that maps the disparate state sources to/from our unified `MainWindowSheet` enum:
```swift
private var activeMainWindowSheet: Binding<MainWindowSheet?> {
    Binding {
        if operationFlow.isPresenting(.changePreview) {
            return .changePreview
        } else if operationFlow.isPresenting(.operationResult) {
            return .operationResult
        } else if fileImports.isShowingImportDownloadsOptions {
            return .importDownloadsOptions
        } else if model.pendingLaunchWarning != nil {
            return .launchWarning
        } else if model.shouldPresentMaintenanceSheet(for: .unmanagedFiles) {
            return .unmanagedFiles
        } else if model.shouldPresentMaintenanceSheet(for: .history) {
            return .history
        } else if model.shouldPresentMaintenanceSheet(for: .playTime) {
            return .playTime
        } else if model.shouldPresentMaintenanceSheet(for: .downloadStatistics) {
            return .downloadStatistics
        } else if model.shouldPresentMaintenanceSheet(for: .cache) {
            return .cache
        } else if model.lastDeduplicateResult != nil {
            return .deduplicateResult
        } else if model.lastRepairRegistryResult != nil {
            return .repairRegistryResult
        }
        return nil
    } set: { newSheet in
        guard newSheet == nil else { return }
        
        // Handle dismissals cleanly by resetting the underlying state trigger
        let current = activeMainWindowSheet.wrappedValue
        switch current {
        case .changePreview:
            operationFlow.dismiss(.changePreview)
        case .operationResult:
            operationFlow.dismiss(.operationResult)
        case .importDownloadsOptions:
            fileImports.cancelImportDownloadsOptions()
        case .launchWarning:
            model.cancelPendingLaunchWarning()
        case .unmanagedFiles:
            model.clearMaintenanceResult(for: .unmanagedFiles)
        case .history:
            model.clearMaintenanceResult(for: .history)
        case .playTime:
            model.clearMaintenanceResult(for: .playTime)
        case .downloadStatistics:
            model.clearMaintenanceResult(for: .downloadStatistics)
        case .cache:
            model.clearMaintenanceResult(for: .cache)
        case .deduplicateResult:
            model.clearDeduplicateResult()
        case .repairRegistryResult:
            model.clearRepairRegistryResult()
        case nil:
            break
        }
    }
}
```

Then, replace the 11 `.sheet` modifiers at the end of the body with:
```swift
.sheet(item: activeMainWindowSheet) { sheet in
    switch sheet {
    case .changePreview:
        ChangeSetPreviewSheet(
            result: model.pendingChangeSet,
            conflictNotice: model.pendingChangeSetConflictNotice,
            dependencyChoiceNotice: model.pendingDependencyChoiceNotice,
            errorMessage: model.changeSetError,
            errorDetails: model.changeSetErrorDetails,
            isApplying: operationFlow.isActive(.applyingChanges),
            suppressRecommendations: model.pendingChangeSet?.suppressRecommendations ?? false,
            onClose: { operationFlow.dismiss(.changePreview) },
            onClear: {
                model.clearAllStagedChanges()
                operationFlow.dismiss(.changePreview)
            },
            onStageProvider: { choice, option in
                model.stageProviderOption(choice: choice, option: option)
                previewChanges()
            },
            onStageRecommendation: { identifier in
                model.stageRecommendationChoice(identifier)
            },
            onToggleSuppressRecommendations: { suppressRecommendations in
                updateSuppressRecommendations(suppressRecommendations)
            },
            onRetry: { previewChanges() },
            onRemoveLock: { beginRegistryLockRemoval(details: model.changeSetErrorDetails, followUp: .preview) },
            onApply: { applyChanges() }
        )
    case .operationResult:
        OperationResultSheet(...)
    case .importDownloadsOptions:
        ImportDownloadsOptionsSheet(...)
    case .launchWarning:
        LaunchWarningSheet(...)
    case .unmanagedFiles:
        UnmanagedFilesSheet(...)
    case .history:
        InstallationHistorySheet(...)
    case .playTime:
        PlayTimeSheet(...)
    case .downloadStatistics:
        DownloadStatisticsSheet(...)
    case .cache:
        CacheMaintenanceSheet(...)
    case .deduplicateResult:
        DeduplicateResultSheet(...)
    case .repairRegistryResult:
        RepairRegistryResultSheet(...)
    }
}
```
**Benefits:**
- Solves multiple-sheet attachment bugs.
- Localizes sheet priorities: if multiple operations are pending (e.g., launch warning and repair result), the computed getter acts as a natural priority resolver.

---

### Phase 3: Consolidate Local Views Sheets (Catalog & Preferences)
Similarly, local views can group their multiple sheets into a single enum:
1. **`CatalogViews.swift`**: Replace `isShowingSaveSearchSheet` and `isShowingLabelsManagerSheet` with `presentedCatalogSheet: CatalogSheet?`.
2. **Preferences**: If settings sheets grow further, `RepositoryPreferencesView` could centralize its sheets.

This refactoring plan maintains clean separation of concerns and reduces the number of layout hierarchy sheets from 24 down to 3 main routing enums.

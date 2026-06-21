# Analysis: Modal Sheet State Management & Refactoring Strategy

## Executive Summary
This report analyzes how modal sheets are currently managed in the MACKAN macOS project, specifically focusing on `MACKANApp.swift` and its interaction with `MainWindowView.swift`. Currently, sheet presentation is controlled via eight independent `@State` boolean flags in `MACKANApp.swift`, plus multiple local/operation-specific flags in `MainWindowView.swift` and subviews. We propose a centralized Router pattern using an `AppSheet` enum stored inside the shared `AppModel` or a separate `AppRouter` object. This eliminates redundant states, simplifies the view hierarchies, and solves sheet-to-sheet presentation conflicts in a unified manner.

---

## 1. Modal Sheet State in `MACKANApp.swift`
`MACKANApp.swift` defines eight distinct `@State` variables to manage the visibility of modal sheets:

| State Boolean Variable | Sheet View | Purpose / Trigger |
|---|---|---|
| `isEditingLaunchCommandLines` | `LaunchCommandLinesSheet` | Editing custom command line arguments for game launch. |
| `isManagingInstances` | `InstanceManagementSheet` | Listing and managing game instances. |
| `isAddingInstance` | `AddInstanceSheet` | Creating/adding a new KSP game instance. |
| `isCloningInstance` | `CloneInstanceSheet` | Cloning an existing game instance. |
| `isFakingInstance` | `FakeInstanceSheet` | Creating a dummy/fake instance for testing. |
| `isExportingModpack` | `ExportModpackSheet` | Exporting the installed mods as a modpack. |
| `isShowingAbout` | `AboutMACKANSheet` | Displaying application version and legal info. |
| `isShowingUpdateCheck` | `UpdateCheckSheet` | Checking for MACKAN application updates. |

### Presentation Logic and Modifiers
In `MACKANApp.swift`, these sheets are attached directly to the `MainWindowView` in the body of the `WindowGroup`:
```swift
MainWindowView(
    model: model,
    isInstallingFromCkanFile: $isInstallingFromCkanFile,
    isImportingDownloads: $isImportingDownloads,
    applyChangesRequestID: $applyChangesRequestID,
    onCopyDiagnostics: copyDiagnosticsReport)
    ...
    .sheet(isPresented: $isEditingLaunchCommandLines) {
        LaunchCommandLinesSheet(model: model)
    }
    .sheet(isPresented: $isManagingInstances) {
        InstanceManagementSheet(
            model: model,
            onAdd: { presentInstanceSubsheet { isAddingInstance = true } },
            onClone: { presentInstanceSubsheet { isCloningInstance = true } },
            onFake: { presentInstanceSubsheet { isFakingInstance = true } })
    }
    .sheet(isPresented: $isAddingInstance) {
        AddInstanceSheet(model: model)
    }
    .sheet(isPresented: $isCloningInstance) {
        CloneInstanceSheet(model: model)
    }
    .sheet(isPresented: $isFakingInstance) {
        FakeInstanceSheet(model: model)
    }
    .sheet(isPresented: $isExportingModpack) {
        ExportModpackSheet(model: model)
    }
    .sheet(isPresented: $isShowingAbout) {
        AboutMACKANSheet(info: model.aboutInfo())
    }
    .sheet(isPresented: $isShowingUpdateCheck) {
        UpdateCheckSheet(...)
    }
```

### Sheet-to-Sheet Transitions
Because SwiftUI on macOS does not reliably support presenting one sheet on top of another from the same view, MACKAN uses a helper function `presentInstanceSubsheet` to transition from `InstanceManagementSheet` to the sub-sheets (`AddInstanceSheet`, `CloneInstanceSheet`, `FakeInstanceSheet`):
```swift
private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
    isManagingInstances = false
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 150_000_000)
        present()
    }
}
```
This forces the management sheet to dismiss, waits for the animation/dismissal to finish (150ms), and then triggers the presentation of the next sheet.

---

## 2. Other Views and Modals in the Workspace
Beyond `MACKANApp.swift`, several other files manage modal sheets:

### A. `MainWindowView.swift`
`MainWindowView` manages sheets using localized states or `AppModel` properties:
- **Operation Sheets**: Controlled by `operationFlow = OperationFlowState()`:
  - `ChangeSetPreviewSheet` (for `.changePreview`)
  - `OperationResultSheet` (for `.operationResult`)
- **Import Sheets**:
  - `ImportDownloadsOptionsSheet` (controlled by `$fileImports.isShowingImportDownloadsOptions`)
- **Warning/Launch Sheets**:
  - `LaunchWarningSheet` (controlled by `model.pendingLaunchWarning != nil`)
- **Maintenance Sheets**: Controlled by `model.shouldPresentMaintenanceSheet(for: pane)`:
  - `UnmanagedFilesSheet`
  - `InstallationHistorySheet`
  - `PlayTimeSheet`
  - `DownloadStatisticsSheet`
  - `CacheMaintenanceSheet`
- **Result Sheets**:
  - `DeduplicateResultSheet` (controlled by `model.lastDeduplicateResult != nil`)
  - `RepairRegistryResultSheet` (controlled by `model.lastRepairRegistryResult != nil`)

### B. Sub-Views
- **`CatalogViews.swift`**:
  - `.sheet(isPresented: $isShowingSaveSearchSheet) { SaveSearchSheet(...) }`
  - `.sheet(isPresented: $isShowingLabelsManagerSheet) { LabelsManagerSheet(...) }`
- **`RepositoryPreferencesView.swift`**:
  - `.sheet(isPresented: $isAddingRepository) { AddRepositorySheet(...) }`
- **`SidebarViews.swift`**:
  - `.sheet(isPresented: isShowingRenameSheet) { RenameInstanceSheet(...) }`

These sheets are fully local to their respective parent views and do not leak into the global app flow.

---

## 3. Build & Test Setup
The MACKAN Mac application is a swift-based project configured via Swift Package Manager (SPM).

- **Configuration File**: `macosx/MACKAN/Package.swift`
  - Defines the targets `MACKANKit` (shared business logic library), `MACKAN` (native macOS executable), and `MACKANKitTests` (unit testing suite).
- **Compilation**:
  - Main build command: `swift build --package-path macosx/MACKAN`
  - Development app script: `macosx/MACKAN/scripts/build-dev-app.sh` compiles and constructs a standalone `.app` bundle with the embedded `.NET` service sidecar (`MACKAN.Service`).
- **Running Tests**:
  - Test command: `swift test --package-path macosx/MACKAN`
  - Verified local execution: Executes 309 unit tests across all logic, states, policies, and mock clients.

---

## 4. Refactoring Strategy: Centralized Router Pattern
To simplify state management, we can define a single `AppSheet` enum that unifies all top-level modal sheets under a single source of truth.

### Step A: Define the `AppSheet` Enum
Create a new file `macosx/MACKAN/Sources/MACKAN/AppSheet.swift` (or inside `MACKANKit` if the model needs direct dependency):
```swift
import Foundation

public enum AppSheet: Identifiable, Hashable, Sendable {
    case about
    case updateCheck
    case manageInstances
    case addInstance
    case cloneInstance
    case fakeInstance
    case editLaunchCommandLines
    case exportModpack

    public var id: Self { self }
}
```

### Step B: Add Router State to `AppModel` or App State
Add a `@Published` variable inside `AppModel.swift`:
```swift
@Published public var activeSheet: AppSheet? = nil

@MainActor
public func presentSheet(_ sheet: AppSheet) {
    self.activeSheet = sheet
}

@MainActor
public func dismissSheet() {
    self.activeSheet = nil
}
```

### Step C: Refactor `MACKANApp.swift`
1. **Remove Separate States**: Remove the 8 `@State` variables in `MACKANApp`.
2. **Update Menu Item Handlers**:
   Instead of setting boolean flags, trigger the sheet via `model.activeSheet` or `model.presentSheet(...)`:
   - `Button("About MACKAN") { model.presentSheet(.about) }`
   - `Button("Manage Instances...") { model.presentSheet(.manageInstances) }`
   - `Button("Add Instance") { model.presentSheet(.addInstance) }`
   - `Button("Clone Instance") { model.presentSheet(.cloneInstance) }`
   - `Button("Fake Instance") { model.presentSheet(.fakeInstance) }`
   - `Button("Edit Command Lines...") { model.presentSheet(.editLaunchCommandLines) }`
   - `Button("Export Modpack") { model.presentSheet(.exportModpack) }`
3. **Refactor Sheet Transitioning Helper**:
   ```swift
   private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
       model.dismissSheet() // Sets activeSheet = nil
       Task { @MainActor in
           try? await Task.sleep(nanoseconds: 150_000_000)
           present() // Sets model.activeSheet = .addInstance, etc.
       }
   }
   ```
4. **Attach a Single Sheet Modifier**:
   Replace the 8 `.sheet(isPresented:)` modifiers on `MainWindowView` with a single `.sheet(item:)` modifier:
   ```swift
   .sheet(item: $model.activeSheet) { sheet in
       switch sheet {
       case .about:
           AboutMACKANSheet(info: model.aboutInfo())
       case .updateCheck:
           UpdateCheckSheet(
               model: model,
               onCheckStable: { checkForUpdates(useDevBuilds: false) },
               onCheckDev: { checkForUpdates(useDevBuilds: true) })
       case .manageInstances:
           InstanceManagementSheet(
               model: model,
               onAdd: { presentInstanceSubsheet { model.activeSheet = .addInstance } },
               onClone: { presentInstanceSubsheet { model.activeSheet = .cloneInstance } },
               onFake: { presentInstanceSubsheet { model.activeSheet = .fakeInstance } })
       case .addInstance:
           AddInstanceSheet(model: model)
       case .cloneInstance:
           CloneInstanceSheet(model: model)
       case .fakeInstance:
           FakeInstanceSheet(model: model)
       case .editLaunchCommandLines:
           LaunchCommandLinesSheet(model: model)
       case .exportModpack:
           ExportModpackSheet(model: model)
       }
   }
   ```

### Benefits of the Refactored Design
- **Source of Truth**: Prevents the UI from being in an invalid state where multiple sheets are requested to be presented concurrently.
- **Simplified Structure**: Reduces boilerplate code in `MACKANApp.swift` significantly.
- **Architectural Flexibility**: Allows presenting sheets programmatically from anywhere in the codebase that has access to the shared `AppModel` (including views nested deep in the view hierarchy or background services).

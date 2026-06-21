# Centralized Sheet Presentation Analysis & Refactoring Strategy

## 1. Overview of Sheet State Management in MACKAN

Currently, the presentation of modal sheets in MACKAN is managed via multiple scattered `@State` variables, custom bindings, and direct model status properties across several views. This results in decoupled logic, difficulty tracking which sheet is open, and potential SwiftUI rendering glitches when transitioning between sheets (particularly on macOS where presenting multiple sheets simultaneously or too quickly is prone to bugs).

### 1.1 Sheet Triggers and Controllers in `MACKANApp`
The main entry point `MACKANApp` defines 14 state properties and coordinates several sheets:
- `isEditingLaunchCommandLines`: Presents `LaunchCommandLinesSheet`
- `isManagingInstances`: Presents `InstanceManagementSheet`
- `isAddingInstance`: Presents `AddInstanceSheet`
- `isCloningInstance`: Presents `CloneInstanceSheet`
- `isFakingInstance`: Presents `FakeInstanceSheet`
- `isExportingModpack`: Presents `ExportModpackSheet`
- `isShowingAbout`: Presents `AboutMACKANSheet`
- `isShowingUpdateCheck`: Presents `UpdateCheckSheet`
- `isInstallingFromCkanFile` & `isImportingDownloads`: Passed to `MainWindowView` as bindings to open file panels.

### 1.2 Sheet Triggers in `MainWindowView`
Inside `MainWindowView`, sheets are managed via additional flags:
- `operationFlow` (`OperationFlowState`): Controls `.changePreview` and `.operationResult` sheets.
- `fileImports` (`FileImportFlowState`): Controls `isShowingImportDownloadsOptions`.
- `pendingLaunchWarningIsPresented`: Controls `LaunchWarningSheet` (derived from `model.pendingLaunchWarning != nil`).
- `maintenanceSheetIsPresented(for:)`: Controls maintenance sheets (derived from `model.shouldPresentMaintenanceSheet(for:)`).
- `deduplicateResultIsPresented`: Controls `DeduplicateResultSheet` (derived from `model.lastDeduplicateResult != nil`).
- `repairRegistryResultIsPresented`: Controls `RepairRegistryResultSheet` (derived from `model.lastRepairRegistryResult != nil`).

---

## 2. Inventory of Sheets & Views

Here is a full inventory of the sheets in the project, their triggering flags, and current files:

| Sheet / View | Trigger Flag / Property | Presented In | Target Sheet View | Notes |
|---|---|---|---|---|
| About MACKAN | `isShowingAbout` | `MACKANApp` | `AboutMACKANSheet` | Triggered from App Menu |
| Check for Updates | `isShowingUpdateCheck` | `MACKANApp` | `UpdateCheckSheet` | Triggered from Help Menu & App Launch |
| Edit Command Lines | `isEditingLaunchCommandLines` | `MACKANApp` | `LaunchCommandLinesSheet` | Triggered from Instance Menu |
| Manage Instances | `isManagingInstances` | `MACKANApp` | `InstanceManagementSheet` | Triggered from Instance Menu |
| Add Instance | `isAddingInstance` | `MACKANApp` | `AddInstanceSheet` | Triggered from Instance Menu / Manage Instances |
| Clone Instance | `isCloningInstance` | `MACKANApp` | `CloneInstanceSheet` | Triggered from Instance Menu / Manage Instances |
| Fake Instance | `isFakingInstance` | `MACKANApp` | `FakeInstanceSheet` | Triggered from Instance Menu / Manage Instances |
| Export Modpack | `isExportingModpack` | `MACKANApp` | `ExportModpackSheet` | Triggered from Mods Menu |
| Change Preview | `operationFlow.presentedSheet == .changePreview` | `MainWindowView` | `ChangeSetPreviewSheet` | Triggered during mod catalog operations |
| Operation Result | `operationFlow.presentedSheet == .operationResult` | `MainWindowView` | `OperationResultSheet` | Triggered upon operations completion |
| Import Downloads Options | `fileImports.isShowingImportDownloadsOptions` | `MainWindowView` | `ImportDownloadsOptionsSheet` | Triggered during download imports |
| Launch Warning | `model.pendingLaunchWarning != nil` | `MainWindowView` | `LaunchWarningSheet` | Triggered on game launch with incompatible mods |
| Maintenance Sheets | `model.shouldPresentMaintenanceSheet(for: pane)` | `MainWindowView` | Various (e.g. `PlayTimeSheet`, `UnmanagedFilesSheet`, etc.) | Triggered by selecting maintenance section in sidebar |
| Deduplicate Result | `model.lastDeduplicateResult != nil` | `MainWindowView` | `DeduplicateResultSheet` | Maintenance action result |
| Repair Registry Result | `model.lastRepairRegistryResult != nil` | `MainWindowView` | `RepairRegistryResultSheet` | Maintenance action result |

### 2.1 Nested Sheets and Inter-sheet Communication
In `InstanceManagementSheet.swift`, the sheet can present another sheet (`InstanceManagementRenameSheet`) on top of itself:
- `isShowingRenameSheet` binding (checks `pendingRename != nil`).
It also triggers sub-sheets from `MACKANApp` via closures:
- `onAdd`, `onClone`, `onFake` dismiss `isManagingInstances` and present the respective sheet after `150,000,000` nanoseconds delay using `presentInstanceSubsheet`.

In `SidebarViews.swift`, `SidebarView` also presents `RenameInstanceSheet` via its own sheet binding when `instancePendingRename != nil`.

---

## 3. Build and Test Analysis

The MACKAN project is organized as follows:
- **Swift Core & GUI**: Stored in `macosx/MACKAN/`. It utilizes Swift Package Manager (SPM).
- **Sidecar Service**: Stored in `MACKAN.Service` (.NET 10 project).
- **Core C# Solution**: CKAN's main visual studio solution (`CKAN.sln`) is located in the repository root.

### 3.1 Building the Swift App and Kit
The Swift project can be compiled directly via the Swift Package Manager command line tool or via Xcode.
- Clean build command:
  ```bash
  swift build --package-path macosx/MACKAN
  ```

### 3.2 Running the Tests
MACKAN's Swift test targets (`MACKANKitTests`) can be run using the Swift compiler:
- Test execution command:
  ```bash
  swift test --package-path macosx/MACKAN
  ```
The test suite consists of 309 unit tests (e.g., testing `SidecarClient`, `AppModel`, and network serialization), all passing successfully.

---

## 4. Refactoring Strategy: Centralized Router Pattern

To centralize sheet management, we should replace the discrete boolean states with a type-safe `Router` pattern.

### 4.1 Proposed Route Representation (`MACKANSheet`)
We can define an enum representing all possible modal views, along with associated values for sheets requiring inputs:

```swift
import Foundation
import MACKANKit

public enum MACKANSheet: Identifiable, Equatable {
    case about(AboutInfo)
    case updateCheck
    case editLaunchCommandLines
    case manageInstances
    case addInstance
    case cloneInstance
    case fakeInstance
    case exportModpack
    case changePreview
    case operationResult
    case importDownloadsOptions(fileCount: Int)
    case launchWarning(PendingLaunchWarning)
    case maintenance(MaintenancePane)
    case deduplicateResult(DeduplicateResult)
    case repairRegistryResult(RepairRegistryResult)

    public var id: String {
        switch self {
        case .about: return "about"
        case .updateCheck: return "updateCheck"
        case .editLaunchCommandLines: return "editLaunchCommandLines"
        case .manageInstances: return "manageInstances"
        case .addInstance: return "addInstance"
        case .cloneInstance: return "cloneInstance"
        case .fakeInstance: return "fakeInstance"
        case .exportModpack: return "exportModpack"
        case .changePreview: return "changePreview"
        case .operationResult: return "operationResult"
        case .importDownloadsOptions: return "importDownloadsOptions"
        case .launchWarning(let warning): return "launchWarning-\(warning.id)"
        case .maintenance(let pane): return "maintenance-\(pane.rawValue)"
        case .deduplicateResult: return "deduplicateResult"
        case .repairRegistryResult: return "repairRegistryResult"
        }
    }
}
```

### 4.2 Centralized Router Class (`AppRouter`)
A centralized router can be introduced as an `ObservableObject` and injected into the SwiftUI environment, or owned directly by the `AppModel`:

```swift
import SwiftUI

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var activeSheet: MACKANSheet?

    public init(activeSheet: MACKANSheet? = nil) {
        self.activeSheet = activeSheet
    }

    /// Present a sheet
    public func present(_ sheet: MACKANSheet) {
        activeSheet = sheet
    }

    /// Dismiss the active sheet
    public func dismiss() {
        activeSheet = nil
    }

    /// Safely dismiss the current sheet and present a new one after a delay (workaround for macOS sheet clashing)
    public func dismissAndPresent(_ sheet: MACKANSheet, delayNanoseconds: UInt64 = 150_000_000) {
        activeSheet = nil
        Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            activeSheet = sheet
        }
    }
}
```

### 4.3 Integration in SwiftUI View Tree
We attach a single sheet handler to the root main window view in `MACKANApp.swift`:

```swift
struct MACKANApp: App {
    @StateObject private var model = AppModel(sidecar: SidecarClient.defaultClient())
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            MainWindowView(model: model)
                .environmentObject(router)
                .sheet(item: $router.activeSheet) { sheet in
                    sheetView(for: sheet)
                }
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: MACKANSheet) -> some View {
        switch sheet {
        case .about(let info):
            AboutMACKANSheet(info: info)
        case .updateCheck:
            UpdateCheckSheet(model: model, ...)
        case .editLaunchCommandLines:
            LaunchCommandLinesSheet(model: model)
        case .manageInstances:
            InstanceManagementSheet(model: model, router: router)
        case .addInstance:
            AddInstanceSheet(model: model)
        case .cloneInstance:
            CloneInstanceSheet(model: model)
        case .fakeInstance:
            FakeInstanceSheet(model: model)
        case .exportModpack:
            ExportModpackSheet(model: model)
        case .changePreview:
            ChangeSetPreviewSheet(...)
        case .operationResult:
            OperationResultSheet(...)
        case .importDownloadsOptions(let fileCount):
            ImportDownloadsOptionsSheet(...)
        case .launchWarning(let warning):
            LaunchWarningSheet(warning: warning, ...)
        case .maintenance(let pane):
            maintenanceSheet(for: pane)
        case .deduplicateResult(let result):
            DeduplicateResultSheet(result: result)
        case .repairRegistryResult(let result):
            RepairRegistryResultSheet(result: result)
        }
    }
}
```

### 4.4 Resolving Key Implementation Challenges
1. **Model Synchronization**: Some states (like `model.pendingLaunchWarning` or `model.lastDeduplicateResult`) are updated by operations within `AppModel`. If we centralize routes, `AppModel` can either publish an event to the `AppRouter` or trigger active sheet mutations via direct references. Alternatively, we can let `AppRouter` observe relevant fields in `AppModel` to automatically update `activeSheet`.
2. **Sequential Transitions**: The helper `dismissAndPresent` solves SwiftUI's sheet conflict issues by automating the 150ms sleep timer, standardizing transition delays.

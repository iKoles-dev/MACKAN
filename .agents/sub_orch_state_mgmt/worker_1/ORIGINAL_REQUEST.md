## 2026-06-19T06:35:21Z

Your task is to implement the centralized SwiftUI State Management Refactoring (R1) for sheet presentations and action triggers in the MACKAN macOS app.

### Verification Commands to run:
- Compile project: `swift build --package-path macosx/MACKAN`
- Run Swift unit tests: `swift test --package-path macosx/MACKAN`
- Run C# contract tests: `dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN` (if dotnet is available)

### Exact Implementation Steps:
1. Create `macosx/MACKAN/Sources/MACKANKit/AppSheet.swift` containing:
```swift
import Foundation

public enum AppSheet: Identifiable, Hashable, Sendable {
    case about
    case addInstance
    case cloneInstance
    case editLaunchCommandLines
    case exportModpack
    case fakeInstance
    case manageInstances
    case updateCheck

    public var id: Self { self }
}
```

2. Add the following `@Published` properties directly to `AppModel` class definition in `macosx/MACKAN/Sources/MACKANKit/AppModel.swift` (around line 66, next to `mainContentRoute`):
```swift
    @Published public var activeSheet: AppSheet? = nil
    @Published public var installFromCkanFileTrigger = false
    @Published public var importDownloadsTrigger = false
    @Published public var applyChangesTrigger = false
```

3. Create `macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift` containing:
```swift
import Foundation
import SwiftUI

extension AppModel {
    /// Safe method to present a sheet, handling SwiftUI dismiss/present transition overlaps.
    @MainActor
    public func presentSheet(_ sheet: AppSheet) {
        if activeSheet != nil {
            // Dismiss current sheet first
            activeSheet = nil
            // Wait for dismiss transition to finish before presenting the next one
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.activeSheet = sheet
            }
        } else {
            self.activeSheet = sheet
        }
    }

    /// Dismisses the currently presented app-level sheet.
    @MainActor
    public func dismissSheet() {
        self.activeSheet = nil
    }
}
```

4. Refactor `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`:
   - Remove the 8 boolean `@State` properties for sheets:
     `isEditingLaunchCommandLines`, `isManagingInstances`, `isAddingInstance`, `isCloningInstance`, `isFakingInstance`, `isExportingModpack`, `isShowingAbout`, `isShowingUpdateCheck`
   - Remove the 3 `@State` properties for action triggers:
     `isInstallingFromCkanFile`, `isImportingDownloads`, `applyChangesRequestID`
   - Simplify `MainWindowView` instantiation inside `WindowGroup` to:
     ```swift
     MainWindowView(
         model: model,
         onCopyDiagnostics: copyDiagnosticsReport)
     ```
   - Replace the multiple `.sheet` modifiers on `MainWindowView` (lines 52-82) with a single `.sheet(item: $model.activeSheet)` block:
     ```swift
                 .sheet(item: $model.activeSheet) { sheet in
                     switch sheet {
                     case .editLaunchCommandLines:
                         LaunchCommandLinesSheet(model: model)
                     case .manageInstances:
                         InstanceManagementSheet(
                             model: model,
                             onAdd: { model.presentSheet(.addInstance) },
                             onClone: { model.presentSheet(.cloneInstance) },
                             onFake: { model.presentSheet(.fakeInstance) })
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
                             onCheckDev: { checkForUpdates(useDevBuilds: true) })
                     }
                 }
     ```
   - Update commands/menus (e.g. `Button("About MACKAN")`, `Button("Manage Instances...")`, `Button("Add/Clone/Fake Instance")`, `Button("Edit Command Lines...")`, `Button("Export Modpack")`) to call `model.presentSheet(.name)`.
   - Update commands (e.g. `Button("Apply Changes")`, `Button("Install from File")`, `Button("Import Downloads")`) to set the respective `model.applyChangesTrigger = true`, `model.installFromCkanFileTrigger = true`, `model.importDownloadsTrigger = true`.
   - Update on-launch task to use `model.presentSheet(.updateCheck)` instead of `isShowingUpdateCheck = true`.
   - Update helper `showUpdateCheck()` to use `model.presentSheet(.updateCheck)` instead of `isShowingUpdateCheck = true`.
   - Remove `presentInstanceSubsheet` entirely.

5. Refactor `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`:
   - Remove the `@Binding` variables:
     `@Binding var isInstallingFromCkanFile: Bool`, `@Binding var isImportingDownloads: Bool`, `@Binding var applyChangesRequestID: Int`
   - Update `.onChange` modifiers:
     - `.onChange(of: model.applyChangesTrigger)`:
       ```swift
       .onChange(of: model.applyChangesTrigger) { isTriggered in
           guard isTriggered else { return }
           model.applyChangesTrigger = false
           guard model.canApplyPendingChangeSet else {
               return
           }
           applyChanges()
       }
       ```
     - `.onChange(of: model.installFromCkanFileTrigger)`:
       ```swift
       .onChange(of: model.installFromCkanFileTrigger) { isTriggered in
           guard isTriggered else { return }
           model.installFromCkanFileTrigger = false
           DispatchQueue.main.async {
               presentCkanFileOpenPanel()
           }
       }
       ```
     - `.onChange(of: model.importDownloadsTrigger)`:
       ```swift
       .onChange(of: model.importDownloadsTrigger) { isTriggered in
           guard isTriggered else { return }
           model.importDownloadsTrigger = false
           DispatchQueue.main.async {
               presentImportDownloadsOpenPanel()
           }
       }
       ```
   - Update toolbar buttons (around lines 226, 236) to set `model.installFromCkanFileTrigger = true` and `model.importDownloadsTrigger = true` instead of `isInstallingFromCkanFile = true` and `isImportingDownloads = true`.
   - Remove the local binding resets inside `presentCkanFileOpenPanel()` and `presentImportDownloadsOpenPanel()`.

6. Run the build and test suites, ensuring they compile cleanly and pass.
7. Write your changes and build/test verification details to `/Users/elijahn/GitHub/MACKAN/.agents/sub_orch_state_mgmt/worker_1/handoff.md` and report back.

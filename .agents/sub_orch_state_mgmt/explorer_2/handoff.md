# Handoff — Explorer 2 (Sheet Lifecycle & Bindings)

## 1. Observation

Direct observations made in the codebase:

*   **Sheet Declarations**: In `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`, 8 `@State` boolean flags are used to control sheet presentation (lines 10-14, 18, 29-30):
    ```swift
    @State private var isEditingLaunchCommandLines = false
    @State private var isManagingInstances = false
    @State private var isAddingInstance = false
    @State private var isCloningInstance = false
    @State private var isFakingInstance = false
    ...
    @State private var isExportingModpack = false
    ...
    @State private var isShowingAbout = false
    @State private var isShowingUpdateCheck = false
    ```
    These are bound to individual `.sheet(isPresented:)` modifiers in `MACKANApp`'s body (lines 52-82).

*   **Subsheet Transition Delay**: In `MACKANApp.swift`, transitions from `InstanceManagementSheet` to the creation subsheets (Add, Clone, Fake) are delayed by 150ms after dismissing the management sheet (lines 55-60, 319-325):
    ```swift
    .sheet(isPresented: $isManagingInstances) {
        InstanceManagementSheet(
            model: model,
            onAdd: { presentInstanceSubsheet { isAddingInstance = true } },
            onClone: { presentInstanceSubsheet { isCloningInstance = true } },
            onFake: { presentInstanceSubsheet { isFakingInstance = true } })
    }
    ...
    private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
        isManagingInstances = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            present()
        }
    }
    ```

*   **Command Bindings**: Three variables are declared in `MACKANApp.swift` and passed as bindings to `MainWindowView` to bridge menu bar commands to view actions (lines 15-17, 40-44):
    ```swift
    @State private var isInstallingFromCkanFile = false
    @State private var isImportingDownloads = false
    @State private var applyChangesRequestID = 0
    ...
    MainWindowView(
        model: model,
        isInstallingFromCkanFile: $isInstallingFromCkanFile,
        isImportingDownloads: $isImportingDownloads,
        applyChangesRequestID: $applyChangesRequestID,
        onCopyDiagnostics: copyDiagnosticsReport)
    ```

*   **Binding Observation and Resets**: In `macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`, the bindings are observed to execute actions and immediately reset (lines 39-41, 119-140, 587-606):
    ```swift
    @Binding var isInstallingFromCkanFile: Bool
    @Binding var isImportingDownloads: Bool
    @Binding var applyChangesRequestID: Int
    ...
    .onChange(of: isInstallingFromCkanFile) { isPresented in
        guard isPresented else { return }
        DispatchQueue.main.async { presentCkanFileOpenPanel() }
    }
    ...
    private func presentCkanFileOpenPanel() {
        let urls = runOpenPanel(configuration: .ckanFileInstall)
        isInstallingFromCkanFile = false
        ...
    }
    ```

*   **Localized Sheets**: Some secondary sheets are internal, such as `InstanceManagementRenameSheet` in `InstanceManagementSheet.swift` (line 95):
    ```swift
    .sheet(isPresented: isShowingRenameSheet) {
        InstanceManagementRenameSheet(...)
    }
    ```
    And maintenance sheets in `MainWindowView.swift` (lines 386-440) which are driven directly by `AppModel`'s state via `shouldPresentMaintenanceSheet(for:)` without boolean `@State` properties in `MACKANApp`.

---

## 2. Logic Chain

1.  **SwiftUI Sheet Constraint**: Because SwiftUI on macOS cannot display two sheets from the same container simultaneously, setting `isManagingInstances = false` and immediately setting `isAddingInstance = true` fails. The 150ms delay in `presentInstanceSubsheet` allows the first sheet's dismissal animation to finish (Observation 2).
2.  **Centralizing Sheets**: An `AppSheet` enum and `AppRouter` containing `@Published var activeSheet: AppSheet?` can consolidate the 8 boolean properties (Observation 1). The router can handle the 150ms transition delay internally inside a `present(_:)` method, setting `activeSheet = nil` first, sleeping for 150ms, and then setting `activeSheet = newSheet`.
3.  **Encapsulation of Sheet Views**: The sheets themselves call `@Environment(\.dismiss) private var dismiss` to close (Observation 5). Because SwiftUI's dismiss environment variable works regardless of whether the sheet is bound to a boolean or a nullable enum item, the sheet view implementations do not need to be modified.
4.  **Consolidating Command Bindings**: Command bindings (Observation 3, 4) act as command triggers between the system menu bar and `MainWindowView`. We can consolidate them by adding `@Published` trigger properties to the centralized `AppRouter` (e.g., `installFromCkanFileTrigger`). `MainWindowView` can observe `router` and reset the triggers inside its `.onChange` blocks.

---

## 3. Caveats

*   **Assumptions**: We assume the 150ms delay remains sufficient across all target macOS versions. It is currently used in the codebase and has proven stable.
*   **Excluded Scope**: Localized sheets (like `RenameSheet`) and dialogs/alerts are excluded from centralization to prevent polluting the router and breaking view encapsulation (Observation 5).

---

## 4. Conclusion

Consolidate the 8 boolean `@State` sheet flags in `MACKANApp.swift` and the 3 `@State`/`@Binding` command flags passed to `MainWindowView.swift` into a single `AppRouter` class and `AppSheet` enum defined in `MACKANKit`.
This keeps sheet views unmodified, preserves SwiftUI animation timing, eliminates the duplicate bindings, and keeps the code layout clean and modular.

---

## 5. Verification Method

To verify the design:
1.  **Compile & Run Unit Tests**: Run `swift test` in the `macosx/MACKAN` directory. The project must compile successfully, and all 309 unit tests must pass.
2.  **Manual Verification**:
    *   Open "Manage Instances" -> Click "Add Instance". The management sheet must dismiss, and the add sheet must appear after 150ms.
    *   Test "About MACKAN" and "Check for Updates" from the menu bar to verify they present and dismiss correctly.
    *   Test "Install from File" and "Import Downloads" from the menu bar and toolbar. They must open the file picker and successfully run their respective workflows.

# Handoff Report - Router Architecture & Enum Design

## 1. Observation

Direct observations made on the codebase structure and specific files:

- **App entry point and view structure**: `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift` defines the app's entry structure and holds 8 separate `@State` properties to control sheets:
  - Lines 10-16, 18, 29, 30:
    ```swift
    @State private var isEditingLaunchCommandLines = false
    @State private var isManagingInstances = false
    @State private var isAddingInstance = false
    @State private var isCloningInstance = false
    @State private var isFakingInstance = false
    @State private var isInstallingFromCkanFile = false
    @State private var isImportingDownloads = false
    ...
    @State private var isExportingModpack = false
    ...
    @State private var isShowingAbout = false
    @State private var isShowingUpdateCheck = false
    ```
  - Sheets are bound using `.sheet(isPresented:)` at lines 52-82:
    ```swift
    .sheet(isPresented: $isEditingLaunchCommandLines) { ... }
    .sheet(isPresented: $isManagingInstances) { ... }
    .sheet(isPresented: $isAddingInstance) { ... }
    .sheet(isPresented: $isCloningInstance) { ... }
    .sheet(isPresented: $isFakingInstance) { ... }
    .sheet(isPresented: $isExportingModpack) { ... }
    .sheet(isPresented: $isShowingAbout) { ... }
    .sheet(isPresented: $isShowingUpdateCheck) { ... }
    ```
  - Menu commands trigger sheets by mutating these `@State` properties directly:
    - Line 123: `isShowingAbout = true`
    - Line 129: `isManagingInstances = true`
    - Line 134: `isAddingInstance = true`
    - Line 138: `isCloningInstance = true`
    - Line 142: `isFakingInstance = true`
    - Line 178: `isEditingLaunchCommandLines = true`
    - Line 217: `isExportingModpack = true`
  - Sub-sheet presentation delay workaround (lines 319-325):
    ```swift
    private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
        isManagingInstances = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            present()
        }
    }
    ```

- **AppModel and package targets**:
  - `macosx/MACKAN/Sources/MACKANKit/AppModel.swift` defines `public final class AppModel: ObservableObject` inside the `MACKANKit` library.
  - `macosx/MACKAN/Sources/MACKANKit/AppModel+Presentation.swift` contains presentation properties.
  - `macosx/MACKAN/Sources/MACKANKit/MaintenanceNavigation.swift` contains `MainContentRoute` and `MaintenancePane`.
  - `macosx/MACKAN/Sources/MACKANKit/OperationPresentationState.swift` contains `OperationPresentationSheet` enum.

---

## 2. Logic Chain

1. **Multiple Sheet States**: The use of 8 separate boolean `@State` properties in `MACKANApp.swift` to control sheet presentation leads to state duplication and manual orchestration (e.g. resetting `isManagingInstances = false` before setting `isAddingInstance = true`).
2. **SwiftUI Best Practices**: In SwiftUI, particularly on macOS, the `.sheet(item:)` modifier is the standard and cleanest way to manage mutually exclusive sheets. It requires an enum conforming to `Identifiable`.
3. **centralized Navigation State**: Since `AppModel` is the central coordinator injected globally throughout the app and already holds main content route navigation (`mainContentRoute` of type `MainContentRoute`) and sheet-like alerts (`pendingLaunchWarning`), it is the logical location to centralize the active sheet state.
4. **Transition Workaround**: Setting `activeSheet` to `nil` and immediately to another case can fail in SwiftUI due to overlapping animation transitions. Spawning a task with a 150ms sleep solves this. Moving this logic to a centralized helper method on the model/router (e.g. `presentSheet(_:)`) removes the workaround boilerplate from the SwiftUI views.
5. **Package Structure**: Because `AppModel` resides in `MACKANKit` and cannot reference types defined in the main `MACKAN` app target, the routing enum (`AppSheet`) and transition helpers must reside in `MACKANKit`.

---

## 3. Caveats

- We did not investigate sheet presentation behaviors inside sub-views (like `PreferencesView` or `CatalogViews`) that are not managed by `MACKANApp.swift` or `MainWindowView.swift`.
- We assumed that the 150ms sleep duration remains sufficient for the macOS system's sheet transition completion.

---

## 4. Conclusion

We conclude that the sheet presentation state in `MACKANApp.swift` should be refactored to use a centralized routing enum (`AppSheet`) defined in `MACKANKit`, managed by a single `@Published var activeSheet: AppSheet?` state inside `AppModel`. This removes redundant `@State` properties, eliminates transition boilerplate from views, and permits business logic/menus to trigger sheets directly through `AppModel`.

Detailed designs are documented in `/Users/elijahn/GitHub/MACKAN/.agents/sub_orch_state_mgmt/explorer_1/analysis.md`.

---

## 5. Verification Method

To verify the validity of the design proposal:
1. Inspect `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift` using `view_file` to confirm the list of sheet-controlling properties matches those analyzed.
2. Confirm `AppModel` resides in the `MACKANKit` module and that the app target imports `MACKANKit`, validating that the enum must reside in `MACKANKit`.
3. Check compile and test command execution via shell to confirm no existing build errors.

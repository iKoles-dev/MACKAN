# Analysis — Sheet Lifecycle & Bindings

An analysis of sheet dismissal, subsheet presentation logic, and bindings in `MACKANApp.swift` and related views, proposing a design for SwiftUI state centralization.

---

## 1. Subsheet Presentation Logic

### Current Design and Observations
In `MACKANApp.swift`, instance management and creation are split across multiple sheets:
*   `InstanceManagementSheet` (bound to `isManagingInstances`)
*   `AddInstanceSheet` (bound to `isAddingInstance`)
*   `CloneInstanceSheet` (bound to `isCloningInstance`)
*   `FakeInstanceSheet` (bound to `isFakingInstance`)

Because SwiftUI on macOS does not natively support presenting multiple sheets at the same hierarchy level simultaneously, opening a secondary sheet (e.g., `AddInstanceSheet`) directly from another sheet (`InstanceManagementSheet`) is problematic. To resolve this, MACKAN uses `presentInstanceSubsheet` to dismiss the manager sheet first, wait for the dismissal animation to complete, and then present the editor sheet:

```swift
// MACKANApp.swift
55:                 .sheet(isPresented: $isManagingInstances) {
56:                     InstanceManagementSheet(
57:                         model: model,
58:                         onAdd: { presentInstanceSubsheet { isAddingInstance = true } },
59:                         onClone: { presentInstanceSubsheet { isCloningInstance = true } },
60:                         onFake: { presentInstanceSubsheet { isFakingInstance = true } })
61:                 }

...

319:     private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
320:         isManagingInstances = false
321:         Task { @MainActor in
322:             try? await Task.sleep(nanoseconds: 150_000_000)
323:             present()
324:         }
325:     }
```

### Routing Integration
To centralize these flags using a centralized `AppSheet` enum and an `AppRouter` object:
1.  **Define `AppSheet` Enum**: Represents all 8 app-wide sheets.
    ```swift
    public enum AppSheet: Hashable, Identifiable, Sendable {
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
2.  **Define `AppRouter`**: An `ObservableObject` managing the sheet presentation state.
    ```swift
    @MainActor
    public final class AppRouter: ObservableObject {
        @Published public var activeSheet: AppSheet?

        public func present(_ sheet: AppSheet) {
            if activeSheet != nil {
                activeSheet = nil
                Task {
                    // Retain the exact 150ms delay for safe dismissal-to-presentation transition
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    activeSheet = sheet
                }
            } else {
                activeSheet = sheet
            }
        }

        public func dismiss() {
            activeSheet = nil
        }
    }
    ```
3.  **UI Sheet Binding**: Consolidation in `MACKANApp.swift`:
    ```swift
    .sheet(item: $router.activeSheet) { sheet in
        switch sheet {
        case .editLaunchCommandLines:
            LaunchCommandLinesSheet(model: model)
        case .manageInstances:
            InstanceManagementSheet(
                model: model,
                onAdd: { router.present(.addInstance) },
                onClone: { router.present(.cloneInstance) },
                onFake: { router.present(.fakeInstance) })
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
This integrates transition delay directly within the routing logic and reduces 8 sheet modifiers on the main window down to a single `.sheet(item:)` modifier.

---

## 2. Bindings & Command Triggers

### Current Design and Observations
There are three bindings passed from `MACKANApp.swift` to `MainWindowView.swift`:
*   `isInstallingFromCkanFile` (triggers `presentCkanFileOpenPanel()`)
*   `isImportingDownloads` (triggers `presentImportDownloadsOpenPanel()`)
*   `applyChangesRequestID` (triggers `applyChanges()`)

These flags are defined as `@State` in `MACKANApp.swift` and passed as `@Binding` variables because macOS `CommandGroup` and `CommandMenu` items reside outside `MainWindowView` but must trigger functions inside it:

```swift
// MACKANApp.swift
40:             MainWindowView(
41:                 model: model,
42:                 isInstallingFromCkanFile: $isInstallingFromCkanFile,
43:                 isImportingDownloads: $isImportingDownloads,
44:                 applyChangesRequestID: $applyChangesRequestID,
45:                 onCopyDiagnostics: copyDiagnosticsReport)

...

194:                 Button("Apply Changes") {
195:                     applyChangesRequestID += 1
196:                 }

...

200:                 Button("Install from File") {
201:                     isInstallingFromCkanFile = true
202:                 }
```

In `MainWindowView.swift`:
*   Setting `isInstallingFromCkanFile` to `true` calls `.onChange` in `MainWindowView` which invokes `presentCkanFileOpenPanel()` and resets the binding to `false`.
*   Setting `isImportingDownloads` to `true` calls `.onChange` which invokes `presentImportDownloadsOpenPanel()` and resets it to `false`.
*   Incrementing `applyChangesRequestID` triggers `.onChange` which invokes `applyChanges()`.
*   Additionally, toolbar buttons inside `MainWindowView.swift` set `isInstallingFromCkanFile = true` and `isImportingDownloads = true` to trigger their respective file-picker flows.

### Consolidating with AppRouter
Instead of passing three separate bindings, we can centralize these commands in `AppRouter` by declaring published trigger flags:

```swift
@MainActor
public final class AppRouter: ObservableObject {
    @Published public var activeSheet: AppSheet?

    // Action Triggers
    @Published public var installFromCkanFileTrigger = false
    @Published public var importDownloadsTrigger = false
    @Published public var applyChangesTrigger = false

    public func triggerInstallFromCkanFile() {
        installFromCkanFileTrigger = true
    }

    public func triggerImportDownloads() {
        importDownloadsTrigger = true
    }

    public func triggerApplyChanges() {
        applyChangesTrigger = true
    }
}
```

`MainWindowView` will accept `router` as an `@ObservedObject` and observe the triggers:
```swift
// MainWindowView.swift
.onChange(of: router.installFromCkanFileTrigger) { isTriggered in
    guard isTriggered else { return }
    router.installFromCkanFileTrigger = false
    presentCkanFileOpenPanel()
}
.onChange(of: router.importDownloadsTrigger) { isTriggered in
    guard isTriggered else { return }
    router.importDownloadsTrigger = false
    presentImportDownloadsOpenPanel()
}
.onChange(of: router.applyChangesTrigger) { isTriggered in
    guard isTriggered else { return }
    router.applyChangesTrigger = false
    if model.canApplyPendingChangeSet {
        applyChanges()
    }
}
```

This cleans up the interface, removes the `@Binding` props from `MainWindowView`, and removes the incrementing `applyChangesRequestID` hack.

---

## 3. Regression Prevention & Identical Behavior

To ensure a safe, regression-free refactoring:

1.  **Do Not Modify Sheet Internals**: All sheets (e.g. `AddInstanceSheet`, `CloneInstanceSheet`, `FakeInstanceSheet`, `UpdateCheckSheet`) use `@Environment(\.dismiss) private var dismiss`. Calling `dismiss()` automatically sets the `.sheet(item:)` binding (i.e. `router.activeSheet`) to `nil`. We should keep the sheets unmodified to preserve encapsulation.
2.  **Keep Localized Sheets Local**: Sheets like `InstanceManagementRenameSheet` (inside `InstanceManagementSheet`), `SaveSearchSheet` (inside `CatalogViews`), `LabelsManagerSheet`, and `isAddingRepository` are purely local to their parent views. They do not have menu triggers or need global coordination. They should stay local to their views, keeping the global router focused and clean.
3.  **Strict Transition Timing**: Maintain the exact `150_000_000` nanoseconds (150ms) delay in `AppRouter.present(_:)` when transitioning between sheets. This is verified to prevent sheet collision issues in SwiftUI on macOS.
4.  **Preserve Launch-Time and Programmatic Sheets**:
    *   On-launch update check sheet must be triggered via `router.present(.updateCheck)` in the task modifier of `MACKANApp`.
    *   `showUpdateCheck()` menu handler must call `router.present(.updateCheck)`.
5.  **Verify UI Commands & Shortcuts**: All menu bar items and keyboard shortcuts must trigger the correct methods on `router`.

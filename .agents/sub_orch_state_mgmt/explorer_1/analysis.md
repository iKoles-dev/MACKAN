# Sheet Routing Architecture & Enum Design Analysis

This analysis examines the sheet presentation architecture in the MACKAN macOS app and proposes a design to centralize sheet management using a routing enum and centralized state management.

## 1. Existing Sheet Presentation in `MACKANApp.swift`

Currently, `MACKANApp.swift` maintains 8 separate `@State` boolean flags to control the presentation of individual sheets:

| State Property | Presented Sheet View | Dependencies / Bindings | Trigger Source |
| :--- | :--- | :--- | :--- |
| `isShowingAbout` | `AboutMACKANSheet` | `info: AboutInfo` (from `model.aboutInfo()`) | App Info Command Menu ("About MACKAN") |
| `isShowingUpdateCheck` | `UpdateCheckSheet` | `model: AppModel`, `onCheckStable`, `onCheckDev` | Help Command Menu ("Check for Updates"), App launch update check task |
| `isManagingInstances` | `InstanceManagementSheet` | `model: AppModel`, callbacks: `onAdd`, `onClone`, `onFake` | Instance Command Menu ("Manage Instances...") |
| `isAddingInstance` | `AddInstanceSheet` | `model: AppModel` | Instance Command Menu ("Add Instance"), Callback from `InstanceManagementSheet` |
| `isCloningInstance` | `CloneInstanceSheet` | `model: AppModel` | Instance Command Menu ("Clone Instance"), Callback from `InstanceManagementSheet` |
| `isFakingInstance` | `FakeInstanceSheet` | `model: AppModel` | Instance Command Menu ("Fake Instance"), Callback from `InstanceManagementSheet` |
| `isExportingModpack` | `ExportModpackSheet` | `model: AppModel` | Mods Command Menu ("Export Modpack") |
| `isEditingLaunchCommandLines` | `LaunchCommandLinesSheet` | `model: AppModel` | Instance Command Menu ("Edit Command Lines...") |

### Dependencies and Callbacks Analysis

1. **`AppModel` Dependency**: Almost all sheets require the central `AppModel` instance, which is declared as an `@StateObject` at the app level.
2. **About Info**: `AboutMACKANSheet` is lightweight, only needing an `AboutInfo` struct which is generated from the model on-demand: `model.aboutInfo()`.
3. **Update Check Callbacks**: `UpdateCheckSheet` triggers update checks by executing methods on `model` within a new Task context.
4. **Subsheet Transitioning**: The `InstanceManagementSheet` allows navigating to `AddInstanceSheet`, `CloneInstanceSheet`, or `FakeInstanceSheet`. To perform this transition in SwiftUI, the view dismisses the management sheet, sleeps for `150,000,000` nanoseconds (150ms) to allow the dismiss transition to complete, and then presents the sub-sheet. This is currently managed via a local helper function `presentInstanceSubsheet` in the view:
   ```swift
   private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
       isManagingInstances = false
       Task { @MainActor in
           try? await Task.sleep(nanoseconds: 150_000_000)
           present()
       }
   }
   ```

---

## 2. Best Patterns for Sheet State in SwiftUI macOS Apps

SwiftUI provides two primary ways to present sheets:
1. `.sheet(isPresented:)`: Controls presentation via a boolean binding. This requires a separate boolean state for every sheet and can result in state pollution and complex view-transition logic.
2. `.sheet(item:content:)`: Controls presentation via an optional binding to an `Identifiable` object. Setting the item to non-nil presents the sheet; setting it to `nil` dismisses it.

### The `Identifiable` Enum Pattern
Using `.sheet(item:)` with an enum is the recommended pattern for managing mutually exclusive sheets:

```swift
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

### Key Considerations for macOS:
- **Sheet Dismiss Transitions**: Chaining sheet dismissals and presentations too fast in SwiftUI (e.g. dismissing `manageInstances` and instantly opening `addInstance`) can cause the presentation request to be ignored because the window's sheet dismiss animation is still in progress.
- **Centralizing the Transition Workaround**: A centralized router or model method can handle this delay automatically. The views only need to state what they want to present next, and the model handles the transition timing.

---

## 3. Proposed Architecture & Code Designs

We propose two viable options: **Option A (Centralized in `AppModel`)** and **Option B (Separate `AppRouter` ObservableObject)**.

### Option A: Centralized inside `AppModel` (Recommended)

Since `AppModel` is already the central coordinator of presentation state (e.g., `mainContentRoute`, `pendingLaunchWarning`, maintenance pane results) and is injected throughout the app, adding `activeSheet` directly to `AppModel` is the cleanest design.

#### Step 1: Add `AppSheet` enum to `MACKANKit`
Create `macosx/MACKAN/Sources/MACKANKit/AppSheet.swift`:
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

#### Step 2: Update `AppModel.swift`
Define the state property in the main `AppModel` class:
```swift
@Published public var activeSheet: AppSheet? = nil
```

#### Step 3: Create `AppModel+Sheets.swift` (or append to `AppModel+Presentation.swift`)
Implement presentation transition helpers in `MACKANKit`:
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

---

### Option B: Standalone `AppRouter` ObservableObject

If separating UI routing state from business logic is preferred, a standalone `AppRouter` class can be introduced.

#### Step 1: Create `AppRouter` in `MACKANKit` or `MACKAN`
```swift
import Foundation
import SwiftUI

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var activeSheet: AppSheet? = nil

    public init() {}

    public func presentSheet(_ sheet: AppSheet) {
        if activeSheet != nil {
            activeSheet = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                self.activeSheet = sheet
            }
        } else {
            activeSheet = sheet
        }
    }

    public func dismissSheet() {
        activeSheet = nil
    }
}
```

#### Step 2: Inject in `MACKANApp`
```swift
@StateObject private var router = AppRouter()
```
Pass the router to subviews using `.environmentObject(router)` or by direct parameter injection.

---

### Comparison of Option A vs. Option B

| Dimension | Option A (In `AppModel`) | Option B (Standalone `AppRouter`) |
| :--- | :--- | :--- |
| **Boilerplate** | Low (uses existing model) | Medium (new class, new StateObject, injection) |
| **Triggering Sheets from Business Logic** | Very Easy (e.g. update check on launch task or background tasks inside `AppModel` can directly set `activeSheet`) | Harder (requires delegation or `AppModel` holding a reference to `AppRouter`) |
| **Separation of Concerns** | Low (mixes data & routing) | High (routing is isolated from model) |
| **Consistency** | High (consistent with `mainContentRoute` and `pendingLaunchWarning` which are already in `AppModel`) | Low (splits app routing across two classes) |

**Recommendation**: **Option A** is highly recommended because it matches the existing architecture where `AppModel` manages other presentation navigation (`mainContentRoute` and maintenance pane states) and allows direct triggers from launch tasks or menus without delegates.

---

## 4. Package Structure Integration

MACKAN is divided into two modules:
1. `MACKAN` (app target): Contains views and the app entry point.
2. `MACKANKit` (framework target): Contains business logic, models, and `AppModel`.

```
macosx/MACKAN/Sources/
├── MACKAN/                 # (App Target) Imports MACKANKit
│   └── MACKANApp.swift     # Window group declaration & sheet views
└── MACKANKit/              # (Framework Target) Business logic
    ├── AppModel.swift      # Main AppModel definition (add `@Published var activeSheet`)
    ├── AppSheet.swift      # (Proposed) Defines the AppSheet enum
    └── AppModel+Presentation.swift # (Proposed) Contains sheet helpers
```

### Residence Decision:
The `AppSheet` enum and sheet helpers **must reside in `MACKANKit`**.
Since `AppModel` needs to declare the `activeSheet` property and manage its value, and `AppModel` resides in `MACKANKit`, all sheet routing models must be defined in `MACKANKit` as well (to avoid circular dependency issues, since `MACKANKit` cannot import the main `MACKAN` app target).

---

## 5. Proposed Changes in `MACKANApp.swift` (Applying Option A)

With Option A implemented, `MACKANApp.swift` becomes significantly simpler and cleaner.

### Step 1: Remove Old State
Remove the following lines:
```swift
    @State private var isEditingLaunchCommandLines = false
    @State private var isManagingInstances = false
    @State private var isAddingInstance = false
    @State private var isCloningInstance = false
    @State private var isFakingInstance = false
    @State private var isExportingModpack = false
    @State private var isShowingAbout = false
    @State private var isShowingUpdateCheck = false
```

### Step 2: Use Single Sheet Modifier
Replace lines 52-82 with:
```swift
                .sheet(item: $model.activeSheet) { sheet in
                    switch sheet {
                    case .about:
                        AboutMACKANSheet(info: model.aboutInfo())
                    case .addInstance:
                        AddInstanceSheet(model: model)
                    case .cloneInstance:
                        CloneInstanceSheet(model: model)
                    case .editLaunchCommandLines:
                        LaunchCommandLinesSheet(model: model)
                    case .exportModpack:
                        ExportModpackSheet(model: model)
                    case .fakeInstance:
                        FakeInstanceSheet(model: model)
                    case .manageInstances:
                        InstanceManagementSheet(
                            model: model,
                            onAdd: { model.presentSheet(.addInstance) },
                            onClone: { model.presentSheet(.cloneInstance) },
                            onFake: { model.presentSheet(.fakeInstance) })
                    case .updateCheck:
                        UpdateCheckSheet(
                            model: model,
                            onCheckStable: { checkForUpdates(useDevBuilds: false) },
                            onCheckDev: { checkForUpdates(useDevBuilds: true) })
                    }
                }
```

### Step 3: Simplify Commands and Tasks
- Update Menu commands to use `model.presentSheet(...)`:
  ```swift
  Button("About MACKAN") {
      model.presentSheet(.about)
  }
  ...
  Button("Manage Instances...") {
      model.presentSheet(.manageInstances)
  }
  ...
  Button("Add Instance") {
      model.presentSheet(.addInstance)
  }
  ...
  Button("Clone Instance") {
      model.presentSheet(.cloneInstance)
  }
  ...
  Button("Fake Instance") {
      model.presentSheet(.fakeInstance)
  }
  ...
  Button("Edit Command Lines...") {
      model.presentSheet(.editLaunchCommandLines)
  }
  ...
  Button("Export Modpack") {
      model.presentSheet(.exportModpack)
  }
  ```
- Update launch tasks:
  ```swift
  .task {
      await model.refreshHealth()
      if await model.checkForUpdatesOnLaunchIfNeeded() {
          model.presentSheet(.updateCheck)
      }
  }
  ```
- Simplify `showUpdateCheck()` helper:
  ```swift
  private func showUpdateCheck() {
      model.presentSheet(.updateCheck)
      checkForUpdates(useDevBuilds: nil)
  }
  ```
- Remove `presentInstanceSubsheet` helper entirely from `MACKANApp.swift`.

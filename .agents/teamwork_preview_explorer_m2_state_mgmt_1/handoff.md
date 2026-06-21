# Handoff Report — Codebase Explorer 1

## 1. Observation
- **State variables in `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`**:
  Lines 10–16 and 29–30 declare independent boolean flags to manage sheet presentation state:
  ```swift
  @State private var isEditingLaunchCommandLines = false
  @State private var isManagingInstances = false
  @State private var isAddingInstance = false
  @State private var isCloningInstance = false
  @State private var isFakingInstance = false
  @State private var isInstallingFromCkanFile = false
  @State private var isImportingDownloads = false
  ...
  @State private var isShowingAbout = false
  @State private var isShowingUpdateCheck = false
  ```
- **Sheet modifiers in `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`**:
  Lines 52–82 declare the individual `.sheet(isPresented:)` blocks:
  ```swift
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
      UpdateCheckSheet(
          model: model,
          onCheckStable: { checkForUpdates(useDevBuilds: false) },
          onCheckDev: { checkForUpdates(useDevBuilds: true) })
  }
  ```
- **Dismissal sleep in `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`**:
  Lines 319–325 declare:
  ```swift
  private func presentInstanceSubsheet(_ present: @escaping @MainActor () -> Void) {
      isManagingInstances = false
      Task { @MainActor in
          try? await Task.sleep(nanoseconds: 150_000_000)
          present()
      }
  }
  ```
- **Project Structure**:
  - Located a Swift Package Manager file: `macosx/MACKAN/Package.swift`.
- **Test execution**:
  - Running `swift test` in `macosx/MACKAN` output:
    `Test Suite 'All tests' passed at 2026-06-19 09:32:42.566. Executed 309 tests, with 0 failures (0 unexpected) in 0.145 (0.165) seconds`

---

## 2. Logic Chain
1. Multiple independent `@State` boolean flags (such as `isManagingInstances`, `isAddingInstance`, etc.) are used to drive sheet presentations.
2. Because these are distinct booleans, nothing in the compiler or type system prevents multiple booleans from being set to `true` at the same time, which is an invalid state in SwiftUI (a single view container cannot display multiple sheets concurrently, leading to silent presentation failures or visual glitches on macOS).
3. To safely navigate from one sheet to another (e.g. from instance management to adding/cloning instances), the codebase currently relies on manual dismissal followed by an arbitrary asynchronous sleep duration (`150_000_000` nanoseconds) before setting the next boolean flag to `true`.
4. A centralized, mutually exclusive enum state (e.g. `AppSheet` enum) mapped to a single `@Published var activeSheet: AppSheet?` property in the shared `AppModel` would inherently guarantee mutual exclusivity at the type level.
5. Setting `activeSheet = nil` would dismiss any currently active sheet, and setting it to a new case would present the new sheet, keeping the transition logic unified and type-safe.

---

## 3. Caveats
- We did not investigate how the SwiftUI sheet presentation behaves on older versions of macOS (below macOS 14.0).
- We assumed that the 150ms sleep in `presentInstanceSubsheet` is still required on macOS due to the native animation delay of sheet dismissals. The Router plan accommodates this by preserving the sleep before setting the new enum value.

---

## 4. Conclusion
The current `@State` boolean flags are spread across `MACKANApp.swift` and present a risk of concurrent presentation conflicts. Refactoring the top-level sheets to use a centralized `AppSheet` enum property (`activeSheet`) inside the shared `AppModel` is the cleanest, most idiomatic solution. This is actionable, fully compatible with the existing view structure, and preserves the asynchronous dismissal delays required by macOS.

---

## 5. Verification Method
- **Compilation & Test Suite**:
  Run the test suite from the terminal to verify no regressions are introduced:
  ```bash
  swift test --package-path macosx/MACKAN
  ```
- **Manual Verification**:
  1. Open the application.
  2. Open "Manage Instances" from the menu or keyboard shortcut.
  3. Click "Add" or "Clone". Verify that the "Manage Instances" sheet dismisses smoothly, and after a brief delay, the "Add Instance" or "Clone Instance" sheet appears.
  4. Dismiss the sub-sheet and verify the app returns to the normal main window.

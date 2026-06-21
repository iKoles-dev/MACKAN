# Challenge Report

## Challenge Summary

**Overall risk assessment**: HIGH

This report documents the adversarial review of the state management action triggers (`installFromCkanFileTrigger`, `importDownloadsTrigger`, `applyChangesTrigger`) in `AppModel` and `MainWindowView`, along with the current status of the Swift test suite.

---

## Challenges

### [High] Challenge 1: Stuck Triggers via macOS Global Menu Bar

- **Assumption challenged**: That the view `MainWindowView` is always mounted and active to observe and reset trigger properties on the shared `AppModel`.
- **Attack scenario**: 
  1. The user closes all application windows but does not terminate the app (the app remains running in the macOS Dock).
  2. The user selects any trigger-based action from the macOS system menu (under the "Mods" menu), such as "Apply Changes" or "Install from File".
  3. This modifies the `@Published` property on the `AppModel` (e.g., `model.applyChangesTrigger = true`).
  4. Because no windows are open, the `MainWindowView` is not mounted. The corresponding `.onChange(of: model.applyChangesTrigger)` modifier is not active and does not execute.
  5. The trigger value remains `true` in `AppModel` indefinitely.
  6. The user opens a new window, recreating the `MainWindowView`. The `.onChange` modifier observes the initial value as `true`. Because `.onChange` only triggers when the value *changes*, the handler does not run.
  7. When the user attempts to trigger the menu command again, setting the property to `true` has no effect (as it is already `true`). The action is completely broken and cannot be triggered until the app is restarted.
- **Blast radius**: High. Renders key functions (applying changes, file installation, download imports) completely inoperable.
- **Mitigation**: Avoid using transient view triggers inside a shared, long-lived `AppModel`. Instead, handle menu actions by calling direct functions on `AppModel`, or inspect/reset triggers during the view's `.onAppear` lifecycle.

### [High] Challenge 2: Concurrent Execution and Race Conditions

- **Assumption challenged**: That the triggers ensure exactly-once execution of operations.
- **Attack scenario**:
  1. The menu items in `MACKANApp.swift` (e.g., "Apply Changes", "Install from File", "Import Downloads") are only disabled based on `AppModel` properties (like `canApplyPendingChangeSet`). They do not check if the operations are currently active since `operationFlow` is stored locally in `MainWindowView`.
  2. The user triggers "Apply Changes" (via Cmd+Return shortcut or menu item) while an apply operation is already executing.
  3. `model.applyChangesTrigger` is set to `true`, and the view's `.onChange` callback executes.
  4. It resets `applyChangesTrigger = false` and launches a *second* asynchronous `Task` calling `applyChanges()`.
  5. The second task runs concurrently with the first one, causing overlapping calls to the sidecar's `startApplyChanges` API. This can result in database locks, race conditions, or file access conflicts in the CKAN environment.
  6. Furthermore, when the first task completes, its `defer` block calls `operationFlow.finish(.applyingChanges)`. This resets the activity flag to idle, showing the operation completion sheet prematurely while the second task is still running.
- **Blast radius**: High. Causes potential data/CKAN environment corruption, sidecar failures, and incoherent UI behavior.
- **Mitigation**: 
  1. Elevate operation activity tracking to `AppModel` so that `MACKANApp` menu buttons can disable themselves when operations are active.
  2. Guard the invocation paths in the view (e.g., `applyChanges()`) to immediately return if `operationFlow.isActive(...)` is `true`.

### [Medium] Challenge 3: Test Suite Compilation Failure

- **Assumption challenged**: That the existing test suite compiles and runs successfully.
- **Attack scenario**: Executing `swift test --package-path macosx/MACKAN` fails to compile because `E2ETests.swift` is out of sync with recent changes to the `OperationEvent` initializer signature.
- **Blast radius**: Medium. Blocks development feedback loops and continuous integration.
- **Mitigation**: Update `E2ETests.swift` to pass the newly required parameters (`remainingBytes`, `totalBytes`, etc.) in `OperationEvent` mock instantiations.

---

## Stress Test Results

| Scenario | Expected Behavior | Actual Behavior | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **Invoke menu action with closed window** | Action runs or queue is ignored / reset on window open | Trigger gets stuck at `true`, breaking menu command | **FAIL** |
| **Double trigger "Apply Changes" during active run** | Command is ignored/disabled | Launches second concurrent task, causing premature completion event | **FAIL** |
| **Compile and Run Tests** | Build and test suite pass cleanly | Test suite target fails compilation due to out-of-date signatures | **FAIL** |

---

## Unchallenged Areas

- **Memory leak of the triggers themselves** — Not challenged as there is no evidence of strong reference cycles between the `@ObservedObject var model` and the SwiftUI view hierarchy since the model does not hold references back to the view or its closures.

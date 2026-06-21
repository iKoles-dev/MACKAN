# Centralized Sheet Navigation and Transition Logic Challenge Report

## Challenge Summary

**Overall risk assessment**: **HIGH**

Although the centralized sheet presentation method `presentSheet(_:)` attempts to avoid SwiftUI sheet presentation collisions by setting `activeSheet = nil` and introducing a 150ms delay via `Task.sleep` before setting the next sheet, the lack of task cancellation and state tracking of the dismissal window leads to severe race conditions, transition bypasses, and state inconsistency when calls are made rapidly or in parallel. Furthermore, the Swift test suite fails to compile under Swift 6 strict concurrency checks due to an unsynchronized mutable global variable (`isStaleVar`) and various actor-isolation warnings in `E2ETests.swift`.

---

## Challenges

### [High] Challenge 1: Overwriting Newer Sheet Presentations (Race Condition)

*   **Assumption challenged**: Spawning an un-tracked asynchronous `Task` to set `self.activeSheet = sheet` will always result in the correct final sheet.
*   **Attack scenario**:
    1.  The app is showing Sheet A (e.g., `.about`).
    2.  `presentSheet(.updateCheck)` is called. Since `activeSheet` is not nil, it sets `activeSheet = nil` synchronously and spawns `Task 1` to set `activeSheet = .updateCheck` after 150ms.
    3.  Before 150ms passes (e.g., at 50ms), a user action or system event triggers `presentSheet(.manageInstances)`.
    4.  Since `activeSheet` is currently `nil` (set synchronously in step 2), the method enters the `else` block and sets `activeSheet = .manageInstances` *immediately*.
    5.  At 150ms, `Task 1` wakes up and executes `self.activeSheet = .updateCheck`.
*   **Blast radius**: The latest user/system request (`.manageInstances`) is silently overwritten by the older delayed request (`.updateCheck`). The application ends up in a state that contradicts the actual sequence of requests.
*   **Mitigation**: Retain a reference to the active presentation `Task` and cancel it whenever a new presentation request arrives.
    ```swift
    private var presentationTask: Task<Void, Never>?
    // ...
    presentationTask?.cancel()
    ```

---

### [High] Challenge 2: Bypassing Dismissal Delay (SwiftUI Transition Collision)

*   **Assumption challenged**: Setting `activeSheet = nil` and checking `activeSheet != nil` is sufficient to delay the next sheet presentation until the previous dismiss transition completes.
*   **Attack scenario**:
    1.  The app is showing Sheet A (e.g., `.about`).
    2.  `presentSheet(.updateCheck)` is called. `activeSheet` is set to `nil`, and `Task 1` is spawned to sleep 150ms.
    3.  At 50ms (while Sheet A is still in the middle of its slide-down dismiss animation), `presentSheet(.manageInstances)` is called.
    4.  Since `activeSheet` is `nil`, the method immediately assigns `activeSheet = .manageInstances`.
*   **Blast radius**: Sheet `.manageInstances` is presented immediately, overlapping with Sheet A's dismissal. In SwiftUI, presenting a sheet while another sheet is actively dismissing frequently leads to layout freezes, presentation failure, or permanent sheet hangs.
*   **Mitigation**: Track the timestamp of the last sheet dismissal to enforce the 150ms delay if another presentation is requested within the transition window.
    ```swift
    private var lastDismissTime: Date?
    ```

---

### [Medium] Challenge 3: Rapid Double Click / Duplicate Presentation Flashing

*   **Assumption challenged**: Repeatedly calling `presentSheet` with the same sheet type is handled gracefully.
*   **Attack scenario**:
    1.  The user rapidly double-clicks a button bound to `presentSheet(.manageInstances)`.
    2.  First click: `activeSheet` goes from `nil` to `.manageInstances` immediately.
    3.  Second click: Since `activeSheet` is `.manageInstances` (not nil), the method sets `activeSheet = nil` and schedules a Task to set `activeSheet = .manageInstances` after 150ms.
*   **Blast radius**: The sheet is presented, immediately dismissed/hidden, and then presented again 150ms later. This causes a highly jarring flashing effect.
*   **Mitigation**: Check if the requested sheet is already the active sheet, and ignore the call if so.
    ```swift
    if activeSheet == sheet { return }
    ```

---

### [Critical] Challenge 4: Test Suite Compilation Failure (Swift 6 Concurrency)

*   **Assumption challenged**: The test suite compiles and runs correctly on Swift 6.
*   **Attack scenario**: Running `swift test --package-path macosx/MACKAN` under Swift 6 strict concurrency checks.
*   **Blast radius**: The test target `MACKANKitTests` fails to compile with:
    `error: var 'isStaleVar' is not concurrency-safe because it is nonisolated global shared mutable state`
    Additionally, multiple compiler warnings are emitted concerning main actor-isolated properties (`tempDir`, `bookmarkManager`, `spotlightController`) being mutated/referenced from a nonisolated context in `setUp` and `tearDown` methods of `E2ETests.swift`.
*   **Mitigation**:
    1.  Remove the non-concurrency-safe global variable `isStaleVar` in `Tests/MACKANKitTests/E2ETests.swift`. Use a local variable like in other test methods.
    2.  Annotate the `E2ETests` class with `@MainActor` or handle the setup asynchronously in a concurrency-safe manner.

---

## Stress Test Results

| Scenario / Input Sequence | Expected Behavior | Actual/Predicted Behavior | Pass/Fail |
| :--- | :--- | :--- | :--- |
| **Initial State**: `.about`<br>1. `presentSheet(.updateCheck)` at t=0ms<br>2. `presentSheet(.manageInstances)` at t=50ms | 1. Dismisses `.about`<br>2. Delays and presents `.manageInstances` at t=150ms (or 150ms from first dismiss). `.updateCheck` is ignored. | 1. Synchronously sets `activeSheet = nil`<br>2. Synchronously sets `activeSheet = .manageInstances` at t=50ms (causing UI collision with dismissal animation)<br>3. At t=150ms, sets `activeSheet = .updateCheck` (overwriting the newer presentation). | **FAIL** |
| **Initial State**: `nil`<br>1. `presentSheet(.manageInstances)` at t=0ms<br>2. `presentSheet(.manageInstances)` at t=10ms | Keeps `.manageInstances` presented without disruption. | Sets `activeSheet = nil` on second click, then sets `activeSheet = .manageInstances` after 150ms (causing flashing). | **FAIL** |
| **Swift Compilation**: `swift build` | Successful build of application. | Successful build. | **PASS** |
| **Swift Test Execution**: `swift test` | Successful compilation and execution of test suite. | Compilation fails due to concurrency checks on `isStaleVar`. | **FAIL** |

---

## Unchallenged Areas

- **Platform-specific sheets** — macOS sheets vs. iOS/iPadOS sheets are out of scope as this target specifically compiles for macOS 13+.
- **Sheet contents layout/memory leaks** — Verification focused strictly on presentation logic, state transitions, and test execution.

---

## Proposed Robust Implementation of `presentSheet(_:)`

To address all identified race conditions, transition bypasses, and duplicate clicks, the following implementation is proposed for `AppModel+Sheets.swift`:

```swift
import Foundation
import SwiftUI

extension AppModel {
    private static var lastDismissTime: Date?
    private static var presentationTask: Task<Void, Never>?

    /// Safe method to present a sheet, handling SwiftUI dismiss/present transition overlaps and race conditions.
    @MainActor
    public func presentSheet(_ sheet: AppSheet) {
        // 1. Cancel any pending delayed presentation to prevent older requests from overwriting newer ones.
        Self.presentationTask?.cancel()
        Self.presentationTask = nil

        // 2. Prevent duplicate click resetting.
        guard activeSheet != sheet else { return }

        let now = Date()
        let timeSinceLastDismiss = Self.lastDismissTime.map { now.timeIntervalSince($0) } ?? 1.0
        
        // We need a delay if we are currently displaying a sheet, OR if we dismissed one very recently (< 150ms ago)
        let needsDelay = activeSheet != nil || timeSinceLastDismiss < 0.150

        if activeSheet != nil {
            activeSheet = nil
            Self.lastDismissTime = Date()
        }

        if needsDelay {
            let delay = max(0.150 - timeSinceLastDismiss, 0.0)
            Self.presentationTask = Task { @MainActor in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
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
        Self.lastDismissTime = Date()
        Self.presentationTask?.cancel()
        Self.presentationTask = nil
    }
}
```

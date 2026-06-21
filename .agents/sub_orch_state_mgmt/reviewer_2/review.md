# Review Report — AppModel Sheet Transitions and Dismissal

## Review Summary

**Verdict**: REQUEST_CHANGES

This verdict is based on:
1. **Critical compilation failure** of the unit test target (`MACKANKitTests`) due to concurrency-safety issues under Swift 6 strict concurrency checks.
2. **Major race condition and state synchronization vulnerabilities** identified in the 150ms delay transition mechanism in `presentSheet(_:)`.

---

## Quality Review Findings

### [Critical] Finding 1: Test Suite Compilation Failure (Concurrency-Safety Violation)
- **What**: The unit test target `MACKANKitTests` fails to compile because of mutable global state `isStaleVar` not being concurrency-safe, and unsafe mutations of actor-isolated properties (like `tempDir` and `bookmarkManager`) from nonisolated contexts in `E2ETests.swift`.
- **Where**: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift`, lines 109, 110, 111, 112, 113, 117, 118, 527, and 639.
- **Why**: Under Swift 6 strict concurrency checks, sharing mutable global variables and mutating main actor-isolated properties from nonisolated test methods is a compiler error. This prevents the unit tests from compiling and running.
- **Suggestion**:
  - Mark the `E2ETests` class as `@MainActor`.
  - Convert `isStaleVar` to a local mutable variable inside the test case, or isolate it to a thread-safe context/actor.

### [Major] Finding 2: Flawed Rapid Presentation Test Assertion
- **What**: The unit test `testR1_RapidDoubleClicks` asserts that `model.activeSheet` is `.manageInstances` immediately after calling `presentSheet(.manageInstances)` twice.
- **Where**: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift`, lines 338–344.
- **Why**: When `presentSheet` is called the second time, since `activeSheet` is not nil (it was set in the first call), it enters the `if` block, setting `activeSheet = nil` immediately and scheduling the presentation in a background task after 150ms. Thus, immediately after the second call, `model.activeSheet` is actually `nil`, and the test would fail if it compiled and ran.
- **Suggestion**: The test needs to wait for the transition to finish or mock/evaluate the state correctly.

---

## Adversarial Challenges (Stress-Test & Attack Surface)

**Overall risk assessment**: HIGH

### [High] Challenge 1: Out-of-order Transition Race Condition
- **Assumption challenged**: Sequential calls to `presentSheet` will present the sheets in the requested order and settle on the final sheet requested.
- **Attack scenario**:
  1. `activeSheet` is currently `.about`.
  2. User (or code) triggers presentation of sheet B (`.manageInstances`).
     - Since `activeSheet != nil`, it is set to `nil` immediately, and Task B is scheduled to set `activeSheet = .manageInstances` after 150ms.
  3. 50ms later (while Task B is sleeping), the user triggers sheet C (`.addInstance`).
     - Because `activeSheet` is now `nil` (Call 2 set it to `nil`), the `else` branch is executed.
     - `activeSheet` is set to `.addInstance` immediately (no delay).
  4. 100ms later (total 150ms from Call 2), Task B completes sleep and sets `activeSheet = .manageInstances`.
- **Blast radius**: The user requested sheet C last, but the app finishes by showing sheet B. This leaves the app in an incorrect, out-of-order sheet state and confuses the user.
- **Mitigation**: Introduce a task cancellation token or transition sequence tracking. Keep track of the active presentation `Task` in a property on `AppModel`, and cancel any pending presentation tasks when `presentSheet` is called.

### [Medium] Challenge 2: Arbitrary 150ms Delay Insufficiency
- **Assumption challenged**: 150ms is always sufficient for the SwiftUI dismiss animation to complete on all macOS systems.
- **Attack scenario**: On older Macs, systems under heavy CPU load, or when system animation scales are altered, the sheet dismissal animation can exceed 150ms.
- **Blast radius**: If the dismissal animation takes 200ms+, SwiftUI will attempt to present the next sheet before the previous sheet is fully deallocated, leading to console errors: `"Attempt to present <...> on <...> which is already presenting"` and the second sheet fails to open.
- **Mitigation**: Instead of hardcoded sleep delays, use SwiftUI's native completion flows, or increase the safety margin (e.g., 300ms) or make sheet presentation state-driven through a queue.

---

## Verified Claims

- **App compilation** → verified via `swift build --package-path macosx/MACKAN` → **PASS** (App compiles successfully).
- **Unit tests compilation and execution** → verified via `swift test --package-path macosx/MACKAN` → **FAIL** (Compilation fails in `E2ETests.swift` due to concurrency violations).
- **Sheet dismissal via `@Environment(\.dismiss)`** → verified via source code inspection in `ExportModpackSheet.swift` and `InstanceManagementSheets.swift` → **PASS** (Calling standard `dismiss()` updates `$model.activeSheet` to `nil` correctly through SwiftUI's two-way binding).

---

## Coverage Gaps

- **SwiftUI View Transition Testing** — risk level: low — SwiftUI animation timing and rendering are not testable via standard unit tests; they require UI/host tests.

## Unverified Items

- None.

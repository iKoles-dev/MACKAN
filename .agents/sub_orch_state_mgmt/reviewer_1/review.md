## Review Summary

**Verdict**: REQUEST_CHANGES

## Findings

### [Critical] Finding 1: Test Suite Compilation Failure (Concurrency-Safety Violation)

- What: The unit test target `MACKANKitTests` fails to compile under Swift 6 strict concurrency checks.
- Where: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift`, line 639
- Why: The global mutable variable `isStaleVar` is not concurrency-safe, resulting in:
  ```
  error: var 'isStaleVar' is not concurrency-safe because it is nonisolated global shared mutable state
  ```
  Additionally, multiple compiler warnings are emitted regarding main actor-isolated properties (such as `tempDir`, `bookmarkManager`, and `spotlightController`) being mutated from nonisolated test contexts.
- Suggestion: Convert `isStaleVar` to a local variable inside the test case (or make the class `@MainActor` and use a thread-safe context).

### [Major] Finding 2: Flawed Rapid Presentation Test Assertion

- What: The unit test `testR1_RapidDoubleClicks` has a flawed assertion logic that would fail even if it compiled.
- Where: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift`, lines 338-344
- Why: The test asserts `model.activeSheet` is `.manageInstances` immediately after triggering it twice. However, due to the 150ms safety delay in `presentSheet(_:)`, the second call immediately sets `activeSheet = nil` and schedules presentation after a sleep. Hence, immediately after the call, `activeSheet` is `nil`.
- Suggestion: The test must await the transition or sleep for at least 150ms before asserting the final sheet state.

### [Major] Finding 3: Potential Out-of-order Transition Race Condition in `presentSheet`

- What: Multiple rapid sheet transitions can result in showing the wrong/stale sheet due to lack of task cancellation.
- Where: `macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift`
- Why: When `presentSheet` is called while `activeSheet != nil`, the code sets `activeSheet = nil` and spawns a background `Task` with a 150ms sleep. If a second `presentSheet` call occurs during this 150ms window:
  1. The second call sees `activeSheet` as `nil` (set by the first call).
  2. It executes the `else` branch, setting `activeSheet` to the new sheet immediately.
  3. When the first `Task` completes its sleep, it overwrites `activeSheet` with the first requested sheet.
  This results in showing the first requested sheet instead of the second one, creating an out-of-order state.
- Suggestion: Track the current presentation `Task` on `AppModel` and cancel it before starting a new transition.

## Verified Claims

- **App compilation** → verified via `swift build --package-path macosx/MACKAN` → **PASS** (App compiles successfully)
- **Unit tests execution** → verified via `swift test --package-path macosx/MACKAN` → **FAIL** (Test compilation fails due to concurrency checks in `E2ETests.swift`)
- **Sheets elimination** → verified via source code diff of `MACKANApp.swift` → **PASS** (Local sheet `@State` variables were successfully eliminated and refactored)

## Coverage Gaps

- **Sheet Transition Concurrency and Timings** — risk level: medium — SwiftUI sheets can collide and fail to present if animations do not complete in time. An arbitrary 150ms delay is fragile across different hardware. Recommendation: Implement task cancellation or queue-based transition sequencing.

## Unverified Items

- None.

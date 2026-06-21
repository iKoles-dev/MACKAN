# Review Report — AppModel Sheet Transitions and Dismissal

## Review Summary

**Verdict**: REQUEST_CHANGES

This verdict is issued because:
1. **Critical compilation failure** of the unit test target (`MACKANKitTests`) due to duplicate declarations of helper classes between `E2ETests.swift` and `E2E/E2ETestHelpers.swift`, as well as Swift 6 concurrency violations.
2. **Major edge cases and race conditions** identified in the 150ms animation delay mechanism in `presentSheet` on `AppModel`.

---

## Quality Review Findings

### [Critical] Finding 1: Unit Test Compilation Failure (Duplicate Declarations & Concurrency Violations)
- **What**: The unit test target `MACKANKitTests` fails to compile under `swift test`.
- **Where**: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift` and files under `macosx/MACKAN/Tests/MACKANKitTests/E2E/`
- **Why**: 
  1. `E2ETests.swift` duplicates helper definitions (`NotificationStreamingTransport`, `MackanSandboxBookmarkManager`, and `MackanSpotlightController`) that are already declared in `E2ETestHelpers.swift`.
  2. Under Swift 6 strict concurrency checks, `isStaleVar` in `E2ETests.swift` is flagged as an unsafe mutable global variable, and mutating main actor-isolated properties (like `tempDir` and `bookmarkManager`) from nonisolated contexts triggers compiler errors.
- **Suggestion**: 
  - Remove duplicate helper definitions from `E2ETests.swift` or delete the duplicate file if the tests are already segregated in the `E2E/` folder.
  - Mark test classes using actor-isolated fields with `@MainActor`.
  - Avoid global mutable state in tests.

### [Major] Finding 2: Flawed Rapid Presentation Test Assertion
- **What**: The test `testR1_RapidDoubleClicks` asserts that `model.activeSheet` is `.manageInstances` immediately after calling it twice.
- **Where**: `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift` (lines 339–345)
- **Why**: The second call to `presentSheet` finds `activeSheet != nil` (set by the first call), so it sets `activeSheet = nil` immediately and schedules presentation on a background task. Thus, checking `model.activeSheet` synchronously immediately after the second call will return `nil` rather than `.manageInstances`.
- **Suggestion**: Wait for the background transition task to complete using an asynchronous wait or mock the clock.

---

## Verified Claims

- **App compiles successfully** → verified via `swift build --package-path macosx/MACKAN` → **PASS**
- **Unit tests pass** → verified via `swift test --package-path macosx/MACKAN` → **FAIL** (test compilation fails)
- **Dismissing sheets via `@Environment(\.dismiss)` works correctly** → verified via source code review of `ExportModpackSheet.swift` and others → **PASS** (SwiftUI's two-way binding correctly sets `$model.activeSheet` to `nil` when the environment dismiss action is invoked).

---

## Coverage Gaps

- **SwiftUI Layout/Animation Timing Tests** — risk level: low — Animation glitches and transition overlaps are highly dependent on UI rendering cycles and OS performance, which are not covered by unit tests.

---

## Unverified Items

- **Runtime behavioral execution of the E2E tests** — reason: Test target compilation fails, blocking execution.

---

## Challenge Summary

**Overall risk assessment**: HIGH

---

## Challenges (Stress Testing & Attack Surface)

### [High] Challenge 1: Out-of-Order Transition Race Condition
- **Assumption challenged**: Calling `presentSheet` sequentially will cleanly transition to and settle on the final sheet requested.
- **Attack scenario**:
  1. `activeSheet` is `.about`.
  2. `presentSheet(.manageInstances)` is called. Since `activeSheet != nil`, it sets `activeSheet = nil` and schedules Task A to set it to `.manageInstances` after 150ms.
  3. 50ms later, `presentSheet(.addInstance)` is called. Since `activeSheet` is now `nil` (from Step 2), the `else` block runs, setting `activeSheet = .addInstance` immediately.
  4. 100ms later, Task A wakes up and executes `self.activeSheet = .manageInstances`.
- **Blast radius**: The final active sheet is `.manageInstances`, even though the user's last action requested `.addInstance`. This causes serious out-of-order UI states.
- **Mitigation**: Track the current presentation `Task` in a private property on `AppModel`, and cancel any active presentation task when `presentSheet` is called.

### [Medium] Challenge 2: Duplicate Click Sheet Flashing
- **Assumption challenged**: Duplicate presentation calls are handled gracefully.
- **Attack scenario**:
  1. `activeSheet` is `nil`.
  2. User double-clicks a button presenting `.manageInstances`.
  3. Click 1 sets `activeSheet = .manageInstances` immediately.
  4. Click 2 executes. Since `activeSheet` is `.manageInstances` (not nil), it sets `activeSheet = nil` and schedules presentation after 150ms.
- **Blast radius**: The sheet starts opening, instantly closes (flashing), and opens again after 150ms.
- **Mitigation**: Add a guard check `guard activeSheet != sheet else { return }` at the start of `presentSheet(_:)`.

### [High] Challenge 3: Bypassing Animation Delay After Dismissal
- **Assumption challenged**: `activeSheet == nil` always means it is safe to present a sheet immediately without delay.
- **Attack scenario**:
  1. Sheet A is open.
  2. The sheet is dismissed via `dismissSheet()` or `@Environment(\.dismiss)` (setting `activeSheet = nil`).
  3. Immediately after, the app presents Sheet B.
  4. Since `activeSheet` is `nil` at the moment of the presentation call, the code sets `activeSheet = B` immediately.
- **Blast radius**: SwiftUI is still mid-animation dismissing Sheet A when Sheet B's presentation is requested. This triggers SwiftUI presentation warnings and can block Sheet B from opening.
- **Mitigation**: Track `lastDismissTime` and enforce a safety delay (e.g., `0.150 - timeSinceLastDismiss`) if a dismissal occurred very recently (< 150ms ago).

### [Medium] Challenge 4: Magic Delay Timing Insufficiency
- **Assumption challenged**: 150ms is always sufficient for the sheet dismissal transition to complete.
- **Attack scenario**: On older macOS systems or under heavy CPU load, the sheet dismissal transition animation may take longer than 150ms.
- **Blast radius**: The delayed presentation will execute before the dismissal transition completes, resulting in presentation collision.
- **Mitigation**: Enforce a slightly larger safety margin or queue sheet transitions in a state-driven manner.

---

## Stress Test Results

- **Rapid double-click on a button** → Sheet presents immediately, dismisses immediately, and then presents again after 150ms → **FAIL** (triggers flashing UI)
- **Rapid sequential transition (A -> B -> C)** → Final sheet settles on B instead of C → **FAIL** (out-of-order presentation)
- **Immediate presentation after dismissal** → Safety delay bypassed because `activeSheet` was already `nil` → **FAIL** (risk of SwiftUI collision)

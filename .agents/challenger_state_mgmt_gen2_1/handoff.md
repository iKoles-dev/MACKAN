# Handoff Report — Challenger 1 for Milestone 1 (Centralized State Management)

## 1. Observation
- **Centralized Sheet Presentation Implementation**:
  In `/Users/elijahn/GitHub/MACKAN/macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift` (lines 7–19):
  ```swift
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
  ```
  And `dismissSheet()` is implemented on lines 23–25:
  ```swift
  @MainActor
  public func dismissSheet() {
      self.activeSheet = nil
  }
  ```

- **Stress Test Implementation and Execution**:
  Added test file `/Users/elijahn/GitHub/MACKAN/macosx/MACKAN/Tests/MACKANKitTests/AppSheetConcurrencyTests.swift` containing tests:
  1. `testConcurrentSheetPresentationOverwritesNewerSheet`
  2. `testRapidDismissalGetsOverwrittenByPendingTransition`
  3. `testRapidDoubleClickCausesFlashing`

- **Test Suite Results**:
  Executed `swift test --package-path macosx/MACKAN` resulting in:
  ```
  Test Suite 'MACKANPackageTests.xctest' passed at 2026-06-19 21:38:37.945.
  Executed 312 tests, with 0 failures (0 unexpected) in 1.028 (1.048) seconds
  ```
  The new tests triggered the expected `XCTExpectFailure` blocks, confirming that the race conditions and flashing occur under the current implementation.

- **Dotnet Test Suite Results**:
  Executed `dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN` resulting in:
  ```
  Passed!  - Failed:     0, Passed:   146, Skipped:     0, Total:   146, Duration: 9 s - CKAN.Tests.dll (net10.0)
  ```

---

## 2. Logic Chain
1. **Un-tracked/Un-cancellable Presentation Tasks (Observation 1)**:
   - When a sheet is already active and `presentSheet(_:)` is called, it assigns `activeSheet = nil` and spawns a new `Task { @MainActor in ... }` to set `self.activeSheet = sheet` after a 150ms sleep.
   - This task is not stored or tracked, meaning it cannot be cancelled if subsequent state changes occur.
2. **Race Condition - Overwriting Newer Requests**:
   - If a new sheet presentation (e.g. `.cloneInstance`) is requested *immediately* after setting `activeSheet = nil` but *before* the 150ms sleep finishes, `activeSheet` is currently `nil`.
   - The method routes to the `else` branch, setting `activeSheet = .cloneInstance` immediately.
   - When the 150ms task for the previous request (e.g., `.addInstance`) completes, it executes `self.activeSheet = .addInstance`, overwriting `.cloneInstance` with `.addInstance`.
   - This causes the application state to display `.addInstance` instead of the newer requested `.cloneInstance` (empirically confirmed in `testConcurrentSheetPresentationOverwritesNewerSheet`).
3. **Race Condition - Overwriting Explicit Dismissals**:
   - If a sheet presentation is pending (the 150ms task is sleeping) and the user/system triggers `dismissSheet()`, `activeSheet` is set to `nil`.
   - Once the 150ms task wakes up, it sets `activeSheet = .addInstance`, ignoring the explicit dismissal request and popping up the sheet (empirically confirmed in `testRapidDismissalGetsOverwrittenByPendingTransition`).
4. **Flashing - Rapid Double Presentations**:
   - If `presentSheet(.manageInstances)` is called twice rapidly, the first call sets it immediately. The second call sees `activeSheet != nil`, sets `activeSheet = nil` and schedules a 150ms task to show it again, causing a visual flash (empirically confirmed in `testRapidDoubleClickCausesFlashing`).

---

## 3. Caveats
- Tested strictly in a local macOS environment using simulated unit tests. UI responsiveness and layout rendering during these transitions on actual hardware under resource constraints (low memory/CPU throttling) could worsen the symptoms.
- No modifications were made to the implementation code in `Sources/MACKANKit/AppModel+Sheets.swift` per the "Review-only — do NOT modify implementation code" constraint.

---

## 4. Conclusion
The enum-based `activeSheet` state management in `AppModel+Sheets.swift` is susceptible to severe race conditions, transition bypasses, and layout flashing when transitions are triggered rapidly or concurrently. Because the presentation tasks are not tracked, cancellation is impossible, leading to older requests overriding newer requests or overriding explicit dismissals.

**Mitigation Recommendation**:
Update `AppModel+Sheets.swift` to:
1. Retain and cancel the active presentation task whenever a new presentation is requested.
2. Track the timestamp of the last sheet dismissal to enforce a safe transition delay (e.g., 150ms) if another presentation is requested within the transition window, preventing SwiftUI sheet collision bugs.
3. Reject presentation requests if the requested sheet is already the active sheet.

---

## 5. Verification Method
1. Run build to verify project integrity:
   `swift build --package-path macosx/MACKAN`
2. Run the Swift test suite:
   `swift test --package-path macosx/MACKAN`
3. Inspect `Tests/MACKANKitTests/AppSheetConcurrencyTests.swift` to see the stress-test assertions. Verify that they pass because the issues are caught under `XCTExpectFailure`.
4. Run the Dotnet test suite:
   `dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN`

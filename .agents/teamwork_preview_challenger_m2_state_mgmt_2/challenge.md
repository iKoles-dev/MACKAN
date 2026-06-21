## Challenge Summary

**Overall risk assessment**: HIGH

Through adversarial analysis and empirical unit testing, we identified a critical concurrency bug in `AppModel.presentSheet(_:)` where rapid/concurrent sheet presentation requests bypass safety delays and cause state corruption (out-of-order sheet overrides).

---

## Challenges

### [High] Challenge 1: Race Condition and State Override in Centralized Sheet Presentation

- **Assumption challenged**: `AppModel.presentSheet(_:)` safely manages sheet transitions and prevents sheet presentation overlaps or incorrect final state.
- **Attack scenario**: Calling `presentSheet` multiple times in rapid succession:
  1. `model.presentSheet(.about)` -> sets `activeSheet = .about` immediately.
  2. `model.presentSheet(.addInstance)` -> since `activeSheet != nil`, sets `activeSheet = nil` and schedules a `Task` to set `activeSheet = .addInstance` after 150ms.
  3. `model.presentSheet(.cloneInstance)` -> called before the 150ms sleep completes. Since `activeSheet` is currently `nil` (from step 2), it enters the `else` block and sets `activeSheet = .cloneInstance` immediately (ignoring the 150ms dismiss transition delay).
  4. The task from step 2 wakes up after 150ms and sets `activeSheet = .addInstance`, overwriting `.cloneInstance`.
- **Blast radius**: 
  - **SwiftUI UI Glitches**: Presenting `.cloneInstance` immediately while `.about` is still dismissing violates the transition overlap guard, leading to SwiftUI console warnings or broken sheet presentation.
  - **Wrong Sheet Displayed**: The final active sheet is `.addInstance` instead of the last-requested `.cloneInstance`, violating correct state mapping.
- **Mitigation**: Track the pending task and whether a transition is in progress, cancelling outdated tasks and enforcing transition delay.
  ```swift
  private var pendingPresentationTask: Task<Void, Never>?

  @MainActor
  public func presentSheet(_ sheet: AppSheet) {
      let wasPresenting = activeSheet != nil || pendingPresentationTask != nil
      pendingPresentationTask?.cancel()
      pendingPresentationTask = nil
      
      if wasPresenting {
          activeSheet = nil
          pendingPresentationTask = Task { @MainActor in
              try? await Task.sleep(nanoseconds: 150_000_000)
              guard !Task.isCancelled else { return }
              self.activeSheet = sheet
              self.pendingPresentationTask = nil
          }
      } else {
          self.activeSheet = sheet
      }
  }
  ```

---

## Stress Test Results

- **Scenario 1: Single Sheet Presentation**
  - **Expected behavior**: Sets `activeSheet` to target sheet immediately.
  - **Actual behavior**: Sets `activeSheet` to target sheet immediately.
  - **Result**: PASS

- **Scenario 2: Double Sheet Presentation (Sequential)**
  - **Expected behavior**: First sheet dismissed immediately, second sheet presented after 150ms.
  - **Actual behavior**: First sheet dismissed immediately, second sheet presented after 150ms.
  - **Result**: PASS

- **Scenario 3: Triple Sheet Presentation (Rapid / Concurrent)**
  - **Expected behavior**: Stale sheets discarded, last-requested sheet presented after dismiss transition delay.
  - **Actual behavior**: Third sheet (`.cloneInstance`) presented immediately, and then overwritten by second sheet (`.addInstance`) after 150ms.
  - **Result**: FAIL (Identified Race Condition)

---

## Unchallenged Areas

- **Sheet View Implementations themselves** — The internal behaviors of the individual sheets (e.g., `AboutMACKANSheet`, `AddInstanceSheet`, etc.) are out of scope as they rely on standard SwiftUI inputs and the focus was on the centralized presentation state mapping and transition robustness under concurrent triggers.

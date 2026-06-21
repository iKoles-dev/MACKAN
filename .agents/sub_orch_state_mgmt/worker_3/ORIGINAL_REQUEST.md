## 2026-06-19T18:39:12Z

You are Worker 3.
Your working directory is `/Users/elijahn/GitHub/MACKAN/.agents/sub_orch_state_mgmt/worker_3`.
Your task is to fix the following issues in the codebase:
1. **Swift Concurrency Compiler Error in E2ETests.swift**:
   When running `swift test --package-path macosx/MACKAN`, the compilation fails because of a concurrency safety error:
   `error: var 'isStaleVar' is not concurrency-safe because it is nonisolated global shared mutable state [#MutableGlobalVariable]`
   Locate and remove or refactor `isStaleVar` (which might be declared as a global mutable variable at the end of the file or captured incorrectly) to be concurrency-safe. Also resolve any compiler warnings regarding main actor-isolated properties (`tempDir`, `bookmarkManager`, etc.) being mutated from a nonisolated context in `E2ETests.swift`.
2. **Sheet Transition Race Conditions & Flashing**:
   Challenger 3 identified that the current implementation of `presentSheet(_:)` in `macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift` has race conditions.
   Implement the proposed robust transition logic in `AppModel+Sheets.swift`:
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
3. Run `swift build --package-path macosx/MACKAN` and `swift test --package-path macosx/MACKAN` to confirm that the package compiles cleanly and all tests pass.
4. Write your handoff.md in your working directory and message the orchestrator back.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

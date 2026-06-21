## 2026-06-19T18:40:19Z
You are Worker 3 for Milestone 1 (Centralized State Management) under MACKAN macOS app enhancements.
Your working directory is: /Users/elijahn/GitHub/MACKAN/.agents/worker_state_mgmt_gen2_1.

Your task is to fix sheet presentation race conditions and double-presentation flashing.
1. Add these internal properties to `AppModel` inside `macosx/MACKAN/Sources/MACKANKit/AppModel.swift`:
   - `internal var sheetPresentationTask: Task<Void, Never>? = nil`
   - `internal var lastDismissalTime: TimeInterval = 0`
2. Refactor `macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift` to handle safe race-free presentations:
   - Cancel `sheetPresentationTask` and set to `nil` first.
   - If `activeSheet == sheet`, return.
   - If `activeSheet != nil`:
     - Set `activeSheet = nil`
     - Record `lastDismissalTime = ProcessInfo.processInfo.systemUptime`
     - Schedule the presentation in `sheetPresentationTask` with a sleep of 150ms. Make sure to check `Task.isCancelled` before setting `self.activeSheet = sheet`.
   - Else if the time elapsed since `lastDismissalTime` is less than 150ms:
     - Schedule the presentation in `sheetPresentationTask` after the remaining delay (0.150 - (ProcessInfo.processInfo.systemUptime - lastDismissalTime)). Make sure to check `Task.isCancelled` before setting `self.activeSheet = sheet`.
   - Else:
     - Set `activeSheet = sheet` immediately.
   - Update `dismissSheet()` to:
     - Cancel `sheetPresentationTask` and set to `nil`.
     - If `activeSheet != nil`, set `activeSheet = nil` and record `lastDismissalTime = ProcessInfo.processInfo.systemUptime`.
3. Refactor `macosx/MACKAN/Tests/MACKANKitTests/AppSheetConcurrencyTests.swift` to remove the `XCTExpectFailure` blocks, so they assert the correct race-free behaviors directly.
4. Verify that the app builds cleanly and all Swift and dotnet unit tests pass:
   - Build: swift build --package-path macosx/MACKAN
   - Swift tests: swift test --package-path macosx/MACKAN
   - Dotnet tests: dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN

Write a handoff.md in your working directory.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

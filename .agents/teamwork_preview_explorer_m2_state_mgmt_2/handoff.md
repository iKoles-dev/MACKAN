# Handoff Report

## 1. Observation
- File `MACKANApp.swift` (lines 10-30) contains 8 independent boolean state flags for modal sheet triggers:
  ```swift
  @State private var isEditingLaunchCommandLines = false
  @State private var isManagingInstances = false
  @State private var isAddingInstance = false
  @State private var isCloningInstance = false
  @State private var isFakingInstance = false
  ...
  @State private var isExportingModpack = false
  ...
  @State private var isShowingAbout = false
  @State private var isShowingUpdateCheck = false
  ```
- File `MainWindowView.swift` contains 11 separate `.sheet` modifiers (lines 281-454):
  - `.sheet(isPresented: operationSheetIsPresented(.changePreview))`
  - `.sheet(isPresented: operationSheetIsPresented(.operationResult))`
  - `.sheet(isPresented: $fileImports.isShowingImportDownloadsOptions)`
  - `.sheet(isPresented: pendingLaunchWarningIsPresented)`
  - `.sheet(isPresented: maintenanceSheetIsPresented(for: .unmanagedFiles))`
  - `.sheet(isPresented: maintenanceSheetIsPresented(for: .history))`
  - `.sheet(isPresented: maintenanceSheetIsPresented(for: .playTime))`
  - `.sheet(isPresented: maintenanceSheetIsPresented(for: .downloadStatistics))`
  - `.sheet(isPresented: maintenanceSheetIsPresented(for: .cache))`
  - `.sheet(isPresented: deduplicateResultIsPresented)`
  - `.sheet(isPresented: repairRegistryResultIsPresented)`
- File `Package.swift` in `macosx/MACKAN/` defines the `MACKAN` executable target, `MACKANKit` library target, and `MACKANKitTests` test target.
- Running `swift build` and `swift test` inside `macosx/MACKAN/` successfully compiles the project and executes 309 unit tests with 0 failures:
  ```
  Test Suite 'All tests' passed at 2026-06-19 09:32:18.247.
  	 Executed 309 tests, with 0 failures (0 unexpected) in 0.206 (0.230) seconds
  ```

## 2. Logic Chain
- **Step 1**: Multiple independent boolean state variables in a single view container (like `MACKANApp.swift` or `MainWindowView.swift`) can easily allow multiple sheets to resolve to `true` simultaneously. In SwiftUI, this leads to presentation conflicts or runtime UI glitches.
- **Step 2**: Defining centralized enums (`AppSheet` and `MainWindowSheet`) ensures that at most one sheet can be selected/active in a given scope, fulfilling the mutual exclusion requirement by design.
- **Step 3**: The triggers for `MainWindowView` sheets are currently stored across `operationFlow`, `fileImports`, and `model`. Rather than rewriting all underlying VM/flow architectures, a read-write computed SwiftUI `Binding<MainWindowSheet?>` can map these sources to a single enum seamlessly.
- **Step 4**: Project builds and tests are run via standard Swift package manager toolchain (`swift build`/`swift test` in `macosx/MACKAN`), meaning any refactored view layout can be validated locally for compilation and target safety.

## 3. Caveats
- No actual code changes were applied to the codebase, strictly adhering to the read-only explorer constraint.
- Nested contextual sheets (such as `InstanceManagementRenameSheet` inside `InstanceManagementSheet`) were left out of the global router enums to keep the enums clean and local where appropriate.

## 4. Conclusion
The modal sheet architecture of MACKAN is spread across 24 sheets, with 8 in `MACKANApp.swift` and 11 in `MainWindowView.swift` using independent boolean flags or separate bindings. We propose a 3-phase refactoring strategy using centralized routing enums (`AppSheet` and `MainWindowSheet`) combined with a computed read-write SwiftUI binding in `MainWindowView` to consolidate the sheet modifiers down to a single `.sheet(item:)` modifier per view, eliminating overlapping sheet bugs.

## 5. Verification Method
- **Compilation check**: Run `swift build` in `macosx/MACKAN` directory to verify syntax compatibility.
- **Test execution**: Run `swift test` in `macosx/MACKAN` directory to run unit tests.
- **Visual Inspection**: Open `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift` and check that the multiple sheet modifiers are replaced by a single `.sheet(item: $presentedAppSheet)`.

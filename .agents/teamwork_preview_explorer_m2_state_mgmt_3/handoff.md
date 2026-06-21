# Handoff Report - Centralized State Management (R1)

## 1. Observation

Direct observations in `/Users/elijahn/GitHub/MACKAN/`:

### 1.1 `MACKANApp.swift` (`macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`)
The main SwiftUI App struct declares multiple scattered `@State` variables for managing sheet presentations:
- Line 10: `@State private var isEditingLaunchCommandLines = false`
- Line 11: `@State private var isManagingInstances = false`
- Line 12: `@State private var isAddingInstance = false`
- Line 13: `@State private var isCloningInstance = false`
- Line 14: `@State private var isFakingInstance = false`
- Line 15: `@State private var isInstallingFromCkanFile = false`
- Line 16: `@State private var isImportingDownloads = false`
- Line 18: `@State private var isExportingModpack = false`
- Line 29: `@State private var isShowingAbout = false`
- Line 30: `@State private var isShowingUpdateCheck = false`

Sheets are presented sequentially or in nested forms on the root WindowGroup (lines 52–82):
```swift
.sheet(isPresented: $isEditingLaunchCommandLines) { LaunchCommandLinesSheet(model: model) }
.sheet(isPresented: $isManagingInstances) { InstanceManagementSheet(model: model, ...) }
.sheet(isPresented: $isAddingInstance) { AddInstanceSheet(model: model) }
.sheet(isPresented: $isCloningInstance) { CloneInstanceSheet(model: model) }
.sheet(isPresented: $isFakingInstance) { FakeInstanceSheet(model: model) }
.sheet(isPresented: $isExportingModpack) { ExportModpackSheet(model: model) }
.sheet(isPresented: $isShowingAbout) { AboutMACKANSheet(info: model.aboutInfo()) }
.sheet(isPresented: $isShowingUpdateCheck) { UpdateCheckSheet(...) }
```

### 1.2 `MainWindowView.swift` (`macosx/MACKAN/Sources/MACKAN/MainWindowView.swift`)
Presents operation, import, and maintenance sheets using multiple custom bindings and models:
- Lines 281-294: `.sheet(isPresented: operationSheetIsPresented(.changePreview)) { ChangeSetPreviewSheet(...) }`
- Lines 319-358: `.sheet(isPresented: operationSheetIsPresented(.operationResult)) { OperationResultSheet(...) }`
- Lines 359-372: `.sheet(isPresented: $fileImports.isShowingImportDownloadsOptions) { ImportDownloadsOptionsSheet(...) }`
- Lines 373-385: `.sheet(isPresented: pendingLaunchWarningIsPresented) { ... LaunchWarningSheet(...) }`
- Lines 386-440: Maintenance sheets (e.g. `UnmanagedFilesSheet`, `InstallationHistorySheet`, `PlayTimeSheet`, etc.) using `maintenanceSheetIsPresented(for:)`.
- Lines 441-454: Deduplicate and Repair Registry sheets.

### 1.3 `InstanceManagementSheets.swift` (`macosx/MACKAN/Sources/MACKAN/InstanceManagementSheets.swift`)
Presents a nested sheet:
- Lines 95-102: `.sheet(isPresented: isShowingRenameSheet) { InstanceManagementRenameSheet(...) }`

### 1.4 Command Execution Results
Ran `swift test` under `macosx/MACKAN` to verify tests pass:
```
Test Suite 'All tests' passed at 2026-06-19 09:31:52.989.
	 Executed 309 tests, with 0 failures (0 unexpected) in 0.242 (0.266) seconds
```

---

## 2. Logic Chain

1. **Scattered Presentation State**: Based on observations in `MACKANApp.swift` (1.1) and `MainWindowView.swift` (1.2), sheet visibility is controlled by 10 separate `@State` variables in the App struct, plus several auxiliary models (`OperationFlowState`, `FileImportFlowState`, etc.) in `MainWindowView`.
2. **Transition Fragility**: In `MACKANApp.swift`, transitioning from the instance management view to add/clone/fake sub-views requires dismissing the parent sheet and waiting `150,000,000` nanoseconds before presenting the child.
3. ** مرکزی Router/Enum Strategy**: A centralized enum `MACKANSheet` and router `AppRouter` class (as analyzed in `analysis.md`) would unify all sheet presentations into a single `activeSheet` reference.
4. **Transition Safety**: By incorporating a `dismissAndPresent(_:delayNanoseconds:)` method in the centralized router, we can standardize the 150ms delay required for SwiftUI/macOS sheet dismissal transitions.

---

## 3. Caveats

- **No Code Modifications**: Because I am operating in a read-only investigation role, no code modifications have been applied to the workspace.
- **Environment Scope**: Assumptions have been made that sheet transitions on macOS still require the explicit delay. This is standard behavior for AppKit-hosted SwiftUI sheets.

---

## 4. Conclusion

The MACKAN project is built cleanly and test targets are completely verified. The sheet presentation architecture can be successfully refactored from scattered `@State` variables to a unified `AppRouter` using a `MACKANSheet` enum to control sheets on the main view tree. This resolves the structural clutter in `MACKANApp.swift` and `MainWindowView.swift`, simplifies inter-sheet transitions, and prevents SwiftUI sheet clashing bugs.

---

## 5. Verification Method

- **Build/Test Command**: Execute the following command in the terminal to verify the package still compiles and passes tests:
  ```bash
  swift test --package-path macosx/MACKAN
  ```
- **Files to Inspect**: Review the refactoring strategy details in `analysis.md` located in this agent's folder:
  `/Users/elijahn/GitHub/MACKAN/.agents/teamwork_preview_explorer_m2_state_mgmt_3/analysis.md`

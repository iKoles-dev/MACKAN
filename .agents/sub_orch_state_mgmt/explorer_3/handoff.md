# Handoff Report — Explorer 3 (Build & Verification)

## 1. Observation
We observed the following build configuration, scripts, source files, and test files:
- **`macosx/MACKAN/Package.swift`**: Shows targets `MACKANKit`, `MACKAN`, and `MACKANKitTests`.
- **`macosx/MACKAN/scripts/build-dev-app.sh`**: Lines 85-96 run:
  ```bash
  swift_build_single() {
      swift build \
          --package-path "$PACKAGE_DIR" \
          -c "$CONFIGURATION" >&2
      ...
  }
  ```
  It also runs `dotnet publish "$REPO_ROOT/MACKAN.Service/MACKAN.Service.csproj"` (lines 129-138) and packages the app bundle.
- **`macosx/MACKAN/scripts/release-check.sh`**: Line 182 runs `swift test --package-path "$PACKAGE_DIR"` and line 187 runs:
  ```bash
  run_dotnet_with_retry test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN
  ```
- **Swift Unit Tests**: Executed `swift test --package-path macosx/MACKAN`, resulting in:
  ```
  Test Suite 'SidecarClientTests' passed at 2026-06-19 09:32:44.505.
       Executed 89 tests, with 0 failures (0 unexpected) in 0.030 (0.035) seconds
  Test Suite 'MACKANPackageTests.xctest' passed at 2026-06-19 09:32:44.506.
       Executed 309 tests, with 0 failures (0 unexpected) in 0.145 (0.165) seconds
  ```
- **Views containing sheets**:
  - `MACKANApp.swift`: Lines 52, 55, 62, 65, 68, 71, 74, 77 contain `.sheet(isPresented: ...)` declarations.
  - `MainWindowView.swift`: Lines 281, 319, 359, 373, 386, 394, 407, 417, 424, 441, 448 contain `.sheet(isPresented: ...)` declarations.
  - `CatalogViews.swift`: Lines 424, 438 contain `.sheet(isPresented: ...)` declarations.
- **Test files covering initialization & routing**:
  - `Tests/MACKANKitTests/AppModelTests.swift`: Contains initialization tests (lines 17-87), diagnostics (lines 89-143), routing tests (`testMaintenancePaneSelectionUsesPersistentMainContentRouteUntilInstanceSelection`, lines 695-707), and sheet/routing suppression tests (`testMaintenancePaneSheetPresentationIsSuppressedByPersistentPane`, lines 709-731).
  - `Tests/MACKANKitTests/OperationFlowStateTests.swift` & `OperationPresentationStateTests.swift`: Verify operation sheet/routing logic and exclusivity.

## 2. Logic Chain
1. By examining `Package.swift` and the shell scripts (`build-dev-app.sh`, `release-check.sh`), we identified that MACKAN is standard Swift compilation (`swift build`) alongside a .NET sidecar (`dotnet publish`).
2. By reading `release-check.sh` and running the test commands, we verified that unit tests for the Swift component run under `swift test` and contract/integration tests for the .NET service sidecar run under `dotnet test`.
3. By grepping the codebase for `.sheet(isPresented:` and tracing imports/models, we determined that sheets are triggered either by View-local `@State` variables or bindings mapped to structural state variables like `OperationFlowState` or `AppModel.mainContentRoute`.
4. By examining the test suite `Tests/MACKANKitTests`, we confirmed the existence of tests that verify:
   - Initial states and refresh workflows (app initialization).
   - `mainContentRoute` transitioning and its interactions with `shouldPresentMaintenanceSheet(for:)` (routing and sheet presentation logic).
   - Sheet exclusivity and specific triggers in `OperationFlowState`.

## 3. Caveats
- No caveats. Investigation covers all requested questions with direct proof and verification.

## 4. Conclusion
1. Compile MACKAN macOS app using `swift build --package-path macosx/MACKAN` (executable target) or build/package the full app bundle using `macosx/MACKAN/scripts/build-dev-app.sh`.
2. Run unit tests using `swift test --package-path macosx/MACKAN` and sidecar contract tests using `dotnet test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN`.
3. Sheets are structured using a mix of View-local `@State` variables and Model-driven state bindings.
4. App initialization and routing/sheet presentation logic are thoroughly covered in `AppModelTests.swift`, `OperationFlowStateTests.swift`, and `OperationPresentationStateTests.swift`.

## 5. Verification Method
- Execute `swift test --package-path macosx/MACKAN` to confirm that all 309 Swift tests pass successfully.
- Verify `analysis.md` exists and contains correct file paths and commands.

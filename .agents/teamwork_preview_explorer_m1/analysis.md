# MACKAN macOS E2E Exploration & Analysis Report

## 1. Executive Summary
This report provides a comprehensive architectural analysis of the MACKAN application, its build/test configuration, E2E test design, and the implementation status of key features (R1–R4). The codebase consists of a native macOS SwiftUI frontend (`macosx/MACKAN`) and a C# .NET 10 sidecar service (`MACKAN.Service`) communicating via JSON-RPC 2.0 over standard I/O (stdin/stdout). 

All unit tests (309 in Swift, and accompanying C# tests) pass successfully. Several advanced integrations (duplex JSON-RPC streaming, sandbox bookmarks, and Spotlight deep-linking) are currently planned or exist as placeholders, and E2E test infrastructure must be designed to validate both current and planned behaviors in an opaque-box manner.

---

## 2. MACKAN App Layout & Architecture

```
                                  +---------------------------------------+
                                  |              macOS App                |
                                  |  +---------------------------------+  |
                                  |  |        SwiftUI View Tree        |  |
                                  |  |      (MainWindowView, etc.)     |  |
                                  |  +-----------------+---------------+  |
                                  |                    |                  |
                                  |                    v                  |
                                  |  +-----------------+---------------+  |
                                  |  |            AppModel             |  |
                                  |  +-----------------+---------------+  |
                                  |                    |                  |
                                  |                    v                  |
                                  |  +-----------------+---------------+  |
                                  |  |          SidecarClient          |  |
                                  |  +-----------------+---------------+  |
                                  +--------------------|------------------+
                                                       | (Stdio pipes)
                                                       v
                                  +---------------------------------------+
                                  |            MACKAN.Service             |
                                  |            (.NET 10 Core)             |
                                  +---------------------------------------+
```

### 2.1 Component Architecture
1. **SwiftUI Frontend (`macosx/MACKAN/Sources/MACKAN`)**: Core UI views, sheet management, and user interaction. The root entry point is `MACKANApp.swift`, and the main workspace is `MainWindowView.swift`.
2. **MACKANKit Library (`macosx/MACKAN/Sources/MACKANKit`)**: The business logic, state containers, and communication client. It defines the main state container `AppModel` and the JSON-RPC interface client `SidecarClient`.
3. **MACKAN.Service Sidecar (`MACKAN.Service/`)**: A .NET 10 console application wrapper around CKAN Core. It executes CKAN database, repository, installation, and maintenance operations.
4. **Communication Channel**: Communicates over standard input/output pipes. `StdioSidecarTransport` writes JSON-RPC request payloads to standard input of the `MACKAN.Service` process and reads standard output lines to receive JSON-RPC response payloads.

### 2.2 Sandbox & Entitlements
- **Dev Configuration**: Local dev builds (built via `build-dev-app.sh`) are signed ad-hoc (`codesign -s -`) and **do not** include an entitlements file or enable App Sandbox.
- **Sandbox Operations**: Standard security-scoped resources are accessed when importing downloads or opening CKAN files via `NSOpenPanel` using `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()` (see `MainWindowView.swift:635, 665`).

---

## 3. Build & Test System

### 3.1 Xcode Project & Swift Package
- There is no Xcode project file (`.xcodeproj` or `.xcworkspace`) checked into the repository for MACKAN.
- The project is configured as a Swift Package with `Package.swift` at the package root (`macosx/MACKAN/Package.swift`).
- Three targets are defined:
  - `MACKANKit` (target library)
  - `MACKAN` (executable target, depends on `MACKANKit`, contains resources)
  - `MACKANKitTests` (unit test target, depends on `MACKANKit`)

### 3.2 Build and Verification Scripts
The directory `macosx/MACKAN/scripts/` contains crucial build and sanity check scripts:
1. `build-dev-app.sh`: Orchestrates the complete build pipeline:
   - Publishes the sidecar service: `dotnet publish MACKAN.Service/MACKAN.Service.csproj` (Release configuration, targeted at the host architecture runtime, e.g. `osx-arm64`).
   - Compiles the Swift application: `swift build --package-path macosx/MACKAN` (either single-architecture or universal lipo-merged).
   - Assembles the `.app` bundle: copies the Swift executable to `Contents/MacOS/MACKAN` and the published sidecar to `Contents/Resources/MACKAN.Service`.
   - Generates and bundles `MACKAN.icns`.
   - Dynamically writes `Contents/Info.plist`.
   - Ad-hoc signs the entire bundle.
   - Runs `verify-app-bundle.sh` to check the layout.
2. `verify-app-bundle.sh`: Validates the internal structure of the built `MACKAN.app`. It also runs a sidecar sanity check: pipes `{"jsonrpc":"2.0","id":1,"method":"app.version"}` into the sidecar process and asserts a valid response is returned.
3. `verify-app-launch.sh`: Launches the built app bundle via Launch Services (`open -n MACKAN.app`) and uses AppleScript (`osascript`) to assert that the app successfully spawned a GUI window and did not launch Terminal.app.
4. `test-verify-app-launch.sh` / `test-verify-app-bundle.sh`: Self-testing scripts that mock inputs using shims to verify the functionality of the verification scripts.

### 3.3 Test Suite Execution
- **Swift Unit Tests**: Run via command-line:
  ```bash
  swift test --package-path macosx/MACKAN
  ```
  *Status*: 309 unit tests passed successfully.
- **C# Sidecar Tests**: C# unit/integration tests are located in `Tests/MACKAN/` and can be run via:
  ```bash
  dotnet test
  ```

---

## 4. E2E Test Strategy & Placement

### 4.1 E2E Test Placement Options
We recommend placing E2E test suites in one of two formats:
1. **Dedicated SPM E2E Target**: Define a separate `MACKANE2ETests` target in `Package.swift` that runs opaque-box integration tests. These tests can dynamically build the app, launch it, pipe custom mock JSON-RPC inputs to a mocked sidecar binary (or execute real sidecar transactions), and verify responses.
2. **Standalone Shell/AppleScript Harness**: Placed under `macosx/MACKAN/scripts/e2e/`. These scripts can build the dev app using `build-dev-app.sh`, launch it via `verify-app-launch.sh`, and use AppleScript GUI scripting (`osascript`) to simulate user actions (such as adding instances or checking updates) and read window contents.

### 4.2 Invoking Built App Binary/Test Target
- To compile the app:
  ```bash
  CONFIGURATION=release BUILD_ROOT=./build macosx/MACKAN/scripts/build-dev-app.sh
  ```
  This creates `./build/MACKAN.app`.
- To launch the app programmatically:
  ```bash
  open -n ./build/MACKAN.app
  ```
- To test the GUI state via command-line AppleScript:
  ```bash
  osascript -e 'tell application "System Events" to count windows of process "MACKAN"'
  ```
- To run unit tests:
  ```bash
  swift test --package-path macosx/MACKAN
  ```

---

## 5. Requirements Investigation (R1–R4)

### 5.1 R1: Modal State & Presentation
- **Current Status**: Implemented, but uses scattered state. `MACKANApp.swift` defines 10 separate `@State` boolean variables (`isManagingInstances`, `isAddingInstance`, etc.) to toggle sheets.
- **Transition Fragility**: Opening sub-sheets from other sheets (e.g. going from "Manage Instances" to "Add Instance") requires dismissing the parent sheet and sleeping for 150ms via `presentInstanceSubsheet` before presenting the child. This is a workaround for SwiftUI sheet presentation collisions on macOS.
- **Refactoring Goal**: Unify sheets using a type-safe `Router` pattern with a `MACKANSheet` enum and an `AppRouter` class, binding all modal views to a single `.sheet(item:)` modifier.

### 5.2 R2: JSON-RPC Live Event Streaming
- **Current Status**: **Client-side polling**. The sidecar client currently performs long-running operations asynchronously by initiating them (e.g., `operations.startApplyChanges` or `repositories.startRefresh`) and having the SwiftUI views poll their status (`operations.status` or `repositories.refreshStatus`) at 1-second intervals using `.task(id: pollingID)` (see `OperationSheets.swift:504` and `MainWindowView.swift:141`).
- **Refactoring Goal**: Replace the polling model with server-initiated duplex streaming. The sidecar should push events as asynchronous JSON-RPC notifications over stdout (`method: operations.event`). The Swift client must implement a full-duplex asynchronous stdout reading loop with a thread-safe message-ID dispatch map to route notifications directly.

### 5.3 R3: Sandbox Bookmarks Persistence
- **Current Status**: Not fully implemented. The app currently calls `startAccessingSecurityScopedResource` on selected URLs only during the active operation session (in `MainWindowView.swift`). It does not persist security-scoped bookmarks across app launches.
- **Refactoring Goal**: Implement a `SandboxBookmarkManager` to resolve and persist bookmark data in `UserDefaults` for game instance directories, ensuring MACKAN maintains read/write permissions for external directories after relaunch.

### 5.4 R4: CoreSpotlight Indexing & Deep-linking
- **Current Status**: **Not implemented**. There are no references to Spotlight, `CSSearchableItem`, or deep-linking schemes in the current codebase.
- **Refactoring Goal**: Implement a `SpotlightIndexer` in the Swift client to index all installed mods and handle `onContinueUserActivity` to automatically navigate the app to the selected module details view.

---

## 6. Recommendations for E2E Tests
To test the R1–R4 requirements effectively:
1. **R1 E2E Test**: Script `osascript` to open "Manage Instances", click the "Add Instance" button, verify the 150ms transition safely dismisses the parent and opens the child, and assert that no sheet clashes occur.
2. **R2 E2E Test**: Execute a mock service that sends asynchronous JSON-RPC notifications (`operations.event`) to stdout. Verify that the MACKAN UI updates progress percentages and messages dynamically without polling `operations.status`.
3. **R3 E2E Test**: Build a test target with sandboxing enabled, add an instance outside the sandbox container, relaunch the app, and verify that it resolves the security-scoped bookmark to read the instance registry.
4. **R4 E2E Test**: Index a set of mock modules, use the macOS command-line tool `mdfind` to search for them, and simulate deep-linking via user activity to verify the app updates its details view route.

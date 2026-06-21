# E2E Test Infra: MACKAN macOS App Enhancements

## Test Philosophy
- **Opaque-box, requirement-driven**: Verify the application enhancements from an end-user and integration perspective, without assuming internal implementation details except for standard public API boundaries and JSON-RPC contracts.
- **Methodology**: Apply Category-Partition Testing, Boundary Value Analysis (BVA), Pairwise Combinatorial Testing, and Real-World Workload Testing across four distinct tiers.

## Feature Inventory
| # | Feature | Source (requirement) | Tier 1 (Coverage) | Tier 2 (Boundary) | Tier 3 (Cross) | Tier 4 (Workloads) |
|---|---------|---------------------|:------:|:------:|:------:|:------:|
| 1 | Centralized State Management | R1 (SwiftUI sheet router) | 5 | 5 | ✓ | ✓ |
| 2 | Duplex JSON-RPC Event Streaming | R2 (Progress notifications) | 5 | 5 | ✓ | ✓ |
| 3 | Sandbox Bookmarks | R3 (Security-scoped bookmarks)| 5 | 5 | ✓ | ✓ |
| 4 | Spotlight Integration | R4 (CoreSpotlight & Deep-linking) | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Test Runner**:
  - The E2E tests are implemented as a distinct suite of test cases integrated into the `MACKANKitTests` SPM target, allowing seamless automated execution via:
    ```bash
    swift test --package-path macosx/MACKAN --filter E2E
    ```
  - An orchestrating CLI harness is provided at `macosx/MACKAN/scripts/test-e2e-suite.sh` which handles the complete end-to-end flow: compiles the MACKAN application, sets up mock sandboxes and sidecar environment variables, executes the SPM E2E target, performs system-level verification (e.g., AppleScript and `mdfind`), and reports the final verdict.
- **Test Case Format**:
  - **Swift integration test cases** using `XCTest` that initialize and drive `AppModel` and `SidecarClient` with either a real sidecar (using stdio pipes) or a custom recorded/mocked duplex transport (`RecordingSidecarTransport` / `NotificationStreamingTransport`).
  - **Shell-based verification scripts** invoking macOS system APIs to test sandbox directory resolution, Spotlight cache presence, and AppleScript window enumeration.
- **Directory Layout**:
  - `macosx/MACKAN/Tests/MACKANKitTests/E2E/`: Core Swift E2E test files.
  - `macosx/MACKAN/scripts/test-e2e-suite.sh`: The master E2E test runner script.

## Feature-Specific Test Plans (Tiers 1-4)

### Tier 1 - Feature Coverage (≥5 per feature)
- **Centralized State Management (R1)**:
  - `testR1_OpenCloseAboutSheet`: Open and close About sheet, verify state transitions.
  - `testR1_OpenCloseUpdateSheet`: Open and close Update Check sheet, verify state transitions.
  - `testR1_OpenCloseInstanceManagerSheet`: Open and close Instance Manager sheet, verify state transitions.
  - `testR1_OpenCloseAddInstanceSheet`: Open and close Add Instance sheet, verify state transitions.
  - `testR1_SequentialSheetTransitions`: Perform a series of sheet presentations (e.g., open manager, then open add, dismiss child, dismiss parent) to verify no window presentation collision occurs.
- **Duplex JSON-RPC Event Streaming (R2)**:
  - `testR2_NotificationStreaming`: Sidecar writes an unprompted progress event to stdout; client parses and updates internal states.
  - `testR2_StreamingProgressUpdates`: Progress percentage changes update the UI progress bar bindings.
  - `testR2_StreamingStatusMessages`: Operation status messages update the UI text fields dynamically.
  - `testR2_StreamingMultipleOperations`: Event streaming handles multiple separate operation IDs without cross-talk.
  - `testR2_StreamingStopAndCancel`: Terminating/canceling an operation stops the event stream on both client and sidecar.
- **Sandbox Bookmarks (R3)**:
  - `testR3_BookmarkPersistence`: Selecting a directory registers a security-scoped bookmark.
  - `testR3_BookmarkResolutionOnLaunch`: Simulated app launch resolves the security-scoped bookmark from `UserDefaults` and grants read/write access.
  - `testR3_MultipleBookmarksPersistence`: App successfully manages bookmarks for multiple distinct instance directories.
  - `testR3_StaleBookmarkHandling`: App detects when a bookmarked directory no longer exists and removes it from settings.
  - `testR3_BookmarkRelease`: App releases sandbox access claims upon deleting the instance folder from MACKAN.
- **Spotlight Integration (R4)**:
  - `testR4_SpotlightIndexUpdate`: Index a newly installed mod in CoreSpotlight.
  - `testR4_SpotlightIndexDeletion`: Delete index entry upon uninstalling a mod.
  - `testR4_SpotlightMdfindMatch`: Run `mdfind` from the terminal and assert the indexed mod returns results linked to MACKAN.
  - `testR4_SpotlightDeepLinking`: Launch MACKAN via a Spotlight user activity and assert the router navigates directly to the mod details view.
  - `testR4_SpotlightClearIndex`: Verify full index teardown when MACKAN settings are reset.

### Tier 2 - Boundary & Corner Cases (≥5 per feature)
- **Centralized State Management (R1)**:
  - `testR1_RapidDoubleClicks`: Trigger a sheet presentation double-click and verify the router throttles duplicate sheets.
  - `testR1_ConcurrentPresentations`: Attempt to trigger a sheet while another is in the middle of dismissal (verifies transition protection).
  - `testR1_DismissViaEscapeKey`: Verify that typing the Escape key triggers sheet dismissal action.
  - `testR1_DeepNestedRelaunch`: Relaunch the app with active sheet routes saved in state, ensuring recovery.
  - `testR1_SheetResizeTransition`: Resize the window during active sheets to verify presentation containment.
- **Duplex JSON-RPC Event Streaming (R2)**:
  - `testR2_OutOfOrderEvents`: Verify the stream parser tolerates out-of-order progress percentages.
  - `testR2_MalformedPayload`: Verify client ignores malformed JSON or invalid event formats without crashing.
  - `testR2_HighFrequencyFlood`: Verify client handles high-frequency event streaming (100+ notifications/sec) by throttling UI updates.
  - `testR2_NullOrEmptyEventFields`: Verify client handles notifications containing null/empty parameters gracefully.
  - `testR2_SidecarCrashMidStream`: Verify client detects sidecar stdout close mid-operation and transitions to a failed state.
- **Sandbox Bookmarks (R3)**:
  - `testR3_CorruptedBookmarkInDefaults`: Verify client falls back to manual folder picker if bookmark data in `UserDefaults` is corrupted.
  - `testR3_RestrictedDirectoryAccess`: Verify app reports readable/writable failures if sandbox bookmark cannot acquire folder permissions.
  - `testR3_SymlinkedGameFolder`: Verify bookmark resolves correctly when target is a symlink.
  - `testR3_MaxBookmarksExceeded`: Verify app handles scaling limits when maintaining 50+ concurrent sandbox bookmarks.
  - `testR3_SandboxMigrationUnsandboxed`: Verify app migrates legacy unsandboxed paths to security-scoped bookmarks.
- **Spotlight Integration (R4)**:
  - `testR4_DuplicateModIndexing`: Verify Spotlight index maintains separate identities for two instances containing the same mod.
  - `testR4_IndexingConcurrency`: Verify Spotlight indexing executes safely in a background thread while events stream on the main thread.
  - `testR4_InvalidMetadataUnicode`: Verify indexing handles emojis or non-ASCII characters in mod metadata without failure.
  - `testR4_HighVolumeIndexing`: Verify indexing 2000+ mods simultaneously does not block the UI thread.
  - `testR4_MalformedDeepLinkURL`: Verify the application rejects malformed or non-existent mod deep links on launch and displays main view.

### Tier 3 - Cross-Feature Combinations (Pairwise Coverage)
- **State Management + Sandbox Bookmarks (testR1_R3_AddInstanceSheetDirectorySelector)**:
  - Open the Add Instance sheet (State Management), click browse folder to trigger the sandbox permission request (Sandbox Bookmarks), select the directory, and ensure the sheet stays active and updates with the selected path.
- **Event Streaming + State Management (testR2_R1_ProgressSheetDismissal)**:
  - Start a mod installation streaming progress notifications (Event Streaming), and test closing/opening sheets (State Management) during the stream to verify that background task updates remain bound to the UI model without crash.
- **Sandbox Bookmarks + Spotlight Integration (testR3_R4_SpotlightRelaunchSandboxedInstance)**:
  - Persist game directories via security-scoped bookmarks (Sandbox Bookmarks). Launch MACKAN via a Spotlight mod deep-link (Spotlight Integration), and verify the app resolves the sandbox bookmark to immediately render the instance's mod listing.
- **Spotlight Integration + State Management (testR4_R1_DeepLinkWhileSheetOpen)**:
  - Simulate receiving a Spotlight deep-link event (Spotlight Integration) while an application preferences sheet is open (State Management). Assert that the app safely dismisses the open sheets and routes to the selected mod view.

### Tier 4 - Real-World Application Scenarios (≥5 realistic workloads)
- **Scenario 1 (The Clean Install Workflow)**:
  - User launches MACKAN, registers a sandbox directory, imports a CKAN modpack, starts installation (streams duplex progress 0% -> 100%), and Spotlight indexes the new mods.
- **Scenario 2 (The Multi-Instance Upgrade Workflow)**:
  - User opens the Instance Manager sheet, creates a second instance (persisting bookmark), switches active instance (updates state), runs mod update check (streaming progress), and verifies Spotlight re-indexing.
- **Scenario 3 (The Interrupted Installation Recovery)**:
  - User starts installing mods, events stream, the sidecar process is abruptly killed, the app UI catches the stream disconnect, presents an error dialog using centralized state management, and keeps sandbox access intact.
- **Scenario 4 (Spotlight-to-Detail Deep-link)**:
  - User searches for an installed mod in Spotlight, clicks it, MACKAN launches, resolves the sandboxed game directory, dismisses the initial setup sheet, and goes directly to the mod's description view.
- **Scenario 5 (The Settings & Repository Sync)**:
  - User opens Preferences sheet, modifies preferred hosts, triggers repository synchronization (event streaming updates progress view), and verifies settings are persisted.

## Coverage Thresholds
- **Tier 1 (Feature Coverage)**: ≥5 test cases per feature.
- **Tier 2 (Boundary & Corner Cases)**: ≥5 test cases per feature.
- **Tier 3 (Cross-Feature)**: Cover all major feature-pair interactions.
- **Tier 4 (Real-World Application)**: ≥5 realistic scenarios.
- **Acceptance Criterion**: 100% of defined tests must pass via `test-e2e-suite.sh` and exit with 0.

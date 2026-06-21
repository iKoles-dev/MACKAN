# E2E Test Case Plan (49 Cases)

## Feature 1: SwiftUI State Management (R1)
- **Description**: Centralized state management using `AppRouter` and `AppSheet` enum to control modals (About, Update Check, Instance Management, etc.).
- **Tier 1 (Feature Coverage)**:
  - F1-T1-1: Router presents the About sheet and updates the activeSheet state.
  - F1-T1-2: Router presents the Update Check sheet and updates the activeSheet state.
  - F1-T1-3: Router presents the Instance Management sheet and updates the activeSheet state.
  - F1-T1-4: Router dismisses the currently active sheet, resetting activeSheet to nil.
  - F1-T1-5: Router handles sequential presentation (e.g. from Instance Management to Add Instance) correctly.
- **Tier 2 (Boundary & Corner Cases)**:
  - F1-T2-1: Router handles presentation request when another sheet is already active (overwrites or queues properly).
  - F1-T2-2: Router dismissal works when activeSheet is already nil (no-op, does not crash).
  - F1-T2-3: Router updates activeSheet state on the main actor to prevent race conditions and layout glitches.
  - F1-T2-4: Rapid sequential sheet presentations and dismissals (stress testing state synchronization).
  - F1-T2-5: View layout adjusts correctly when deep-linked sheet presentation is triggered from outside the main window lifecycle.

## Feature 2: Live Event Streaming via JSON-RPC (R2)
- **Description**: Async/duplex JSON-RPC transport loop over stdio where .NET sidecar pushes events (e.g., progress notifications) to the Swift client.
- **Tier 1 (Feature Coverage)**:
  - F2-T1-1: Transport parses unprompted notifications with method "operations.event".
  - F2-T1-2: SidecarClient registers event handlers/delegates to receive live events.
  - F2-T1-3: Swift client processes installation progress notifications and updates progress percentages in memory.
  - F2-T1-4: JSON-RPC duplex transport processes normal request-response calls concurrent with receiving notifications.
  - F2-T1-5: Live event streaming terminates cleanly when the operation completes (completed status notification).
- **Tier 2 (Boundary & Corner Cases)**:
  - F2-T1-6: Transport handles malformed event notifications gracefully without crashing.
  - F2-T1-7: Live event updates with negative percent or out-of-bounds progress are bounded/clamped or ignored safely.
  - F2-T1-8: Transport processes empty or null message fields in operation progress notifications.
  - F2-T1-9: Simultaneous notification events from sidecar are serialized/processed without data races.
  - F2-T1-10: Connection drop/re-launch of sidecar during operation handles pending notifications gracefully (cleans up or reports failure).

## Feature 3: Security-Scoped Bookmarks (R3)
- **Description**: Persisting secure file system access (App Sandbox) for game directories across launches.
- **Tier 1 (Feature Coverage)**:
  - F3-T1-1: Swift client resolves security-scoped bookmark from saved data and accesses the game directory successfully.
  - F3-T1-2: Swift client creates and saves security-scoped bookmark when a new game directory is selected.
  - F3-T1-3: App model checks startAccessingSecurityScopedResource and returns true for resolved bookmark.
  - F3-T1-4: App model correctly calls stopAccessingSecurityScopedResource when finished reading/writing.
  - F3-T1-5: Persistent storage (UserDefaults/Keychain) holds the bookmark data key-value pair correctly.
- **Tier 2 (Boundary & Corner Cases)**:
  - F3-T1-6: Bookmarking handles invalid/corrupted bookmark data gracefully (reports authorization failure instead of crashing).
  - F3-T1-7: Bookmarking handles directories that have been moved/deleted on disk (handles resolution failure).
  - F3-T1-8: Bookmarking handles permission revocation by the user in macOS settings.
  - F3-T1-9: Booking/resuming access works correctly with empty or read-only directory paths.
  - F3-T1-10: Resolving bookmark repeatedly does not leak file descriptors or resource access tokens.

## Feature 4: macOS Spotlight Integration (R4)
- **Description**: CoreSpotlight indexing of installed KSP mods, and opening the app via Spotlight deep-link.
- **Tier 1 (Feature Coverage)**:
  - F4-T1-1: CoreSpotlight indexes a newly installed mod (identifier, title, abstract).
  - F4-T1-2: CoreSpotlight de-indexes/removes a mod when it is uninstalled.
  - F4-T1-3: Spotlight index is fully rebuilt or updated when the game instance changes.
  - F4-T1-4: Terminal command `mdfind` returns the index attributes of the mod associated with the MACKAN bundle identifier.
  - F4-T1-5: Clicking a Spotlight item deep-link passes the mod identifier to the app's `onOpenURL` or NSUserActivity handler.
- **Tier 2 (Boundary & Corner Cases)**:
  - F4-T1-6: Spotlight indexing handles mods with special characters or emoji in their name or description.
  - F4-T1-7: Spotlight indexing does not block main UI thread (runs asynchronously on background queue).
  - F4-T1-8: Spotlight indexing behaves correctly when search attributes (description/author) are empty or null.
  - F4-T1-9: Deep link handler handles invalid/non-existent mod identifiers gracefully (notifying user or no-op).
  - F4-T1-10: Stress-indexing: indexing hundreds of mods simultaneously does not exceed memory or system limits.

## Tier 3 (Cross-Feature Combinations - 4 cases)
- F3-T3-1 (R1 + R2): When a live event progress notification triggers a modal sheet transition, the sheet is shown via the Router, and live progress updating resumes in the new view.
- F3-T3-2 (R2 + R3): Operation progress event streaming accesses the game directory using security-scoped bookmarks to verify files on disk without needing user dialogs mid-operation.
- F3-T3-3 (R1 + R4): Clicking a Spotlight deep-link for a mod closes any open modal sheet using the Router and focuses on the selected mod in the main list.
- F3-T3-4 (R3 + R4): Application resolves security-scoped bookmark at launch to verify installed mods, which then synchronizes the CoreSpotlight index correctly.

## Tier 4 (Real-World Application Scenarios - 5 cases)
- F4-T4-1: Fresh Launch & Setup. App starts up, resolves the sandbox bookmark for the primary instance, index updates in CoreSpotlight, and the main screen is presented.
- F4-T4-2: Installation Flow with Live Progress. User selects a mod, triggers the install operation, gets real-time progress updates via JSON-RPC event streaming, and when complete, the Spotlight index is updated with the new mod.
- F4-T4-3: Deep-Link from Search. User searches a mod in Spotlight, clicks the link, the app handles the deep-link activity, dismisses any active sheet via the Router, and displays the mod info.
- F4-T4-4: Instance Switch & Re-indexing. User switches KSP instance using the Instance Manager modal sheet (Router), app resolves the new sandbox bookmark, loads mod list, updates CoreSpotlight index, and cleans the old instance Spotlight records.
- F4-T4-5: Error Resiliency. Sidecar crashes or drops stdio connection during an install operation. Swift client catches the stream disconnection, presents the failure/alert using the Router, and releases directory resources properly.

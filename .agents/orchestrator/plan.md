# MACKAN macOS Architecture & Feature Enhancements Plan

This plan details the implementation of state management refactoring, live JSON-RPC event streaming, Security-Scoped Bookmarks (App Sandbox support), and macOS Spotlight integration.

## Problem Taxonomy
- **Category**: SWE (Software Engineering) / macOS-specific Integration
- **Key Challenges**:
  1. Refactoring SwiftUI state safely without breaking UI sheets.
  2. Converting a synchronous request-reply stdio channel into an asynchronous, full-duplex, ID-mapped JSON-RPC event streamer without blocking.
  3. Correctly managing security-scoped bookmarks for sandboxed directory persistence.
  4. CoreSpotlight indexing and app routing.

## Milestones

### Milestone 1: Centralized State Management (R1)
- **Goal**: Clean up the many `@State` private variables in `MACKANApp.swift` using a centralized router or Enum-driven modal state.
- **Tasks**:
  1. Define a centralized `ActiveSheet` enum or navigation router in the Swift codebase.
  2. Update `MACKANApp.swift` to bind sheets to this centralized state.
  3. Ensure transitions (e.g. from instance management to add/clone subsheets) work correctly.
  4. Verify compilation and UI sheet opening/closing behaviors.

### Milestone 2: Live Event Streaming via Duplex JSON-RPC (R2)
- **Goal**: Replace the current polling model (`operations.status`) with server-to-client notifications.
- **Tasks**:
  1. Refactor `StdioSidecarTransport` in Swift client to run an asynchronous reading loop from stdout, using a thread-safe message-ID map to route standard responses to their callers.
  2. Update request-construction to use unique request IDs instead of hardcoded `id: 1`.
  3. Implement event callback hooks in .NET sidecar (`MackanServiceDispatcher` and `CoreMackanOperationProvider`) to push operation events down `Console.Out` as JSON-RPC notifications (e.g. method `operations.event`).
  4. In `AppModel` and views, subscribe to these notifications to update progress dynamically, removing active polling tasks.

### Milestone 3: Security-Scoped Bookmarks for Sandboxing (R3)
- **Goal**: Enable MACKAN to retain directory access across launches under strict App Sandbox enforcement.
- **Tasks**:
  1. Create a `SandboxBookmarkManager` helper in the Swift client to generate, persist, and resolve security-scoped bookmark data.
  2. Integrate bookmark saving in panels where game paths are selected (`AddInstanceSheet`, `CloneInstanceSheet`, `FakeInstanceSheet`).
  3. Resolve bookmarks on startup / instance load, calling `startAccessingSecurityScopedResource()` and maintaining active access handles.

### Milestone 4: macOS Spotlight Integration (R4)
- **Goal**: Index installed mods so they can be searched natively using macOS Spotlight.
- **Tasks**:
  1. Implement a `SpotlightIndexer` in the Swift client that indexes all installed mods in the active instance using `CoreSpotlight` APIs.
  2. Trigger index updates whenever the module list loads or is modified.
  3. Handle `onContinueUserActivity` in SwiftUI views to automatically focus MACKAN on the clicked Spotlight mod.
  4. Verify with `mdfind` and system search query simulation.

### Milestone 5: Verification & Adversarial Hardening (Tiers 1-5)
- **Goal**: Build opaque-box E2E test cases, execute existing unit tests, audit with Forensic Auditor, and perform adversarial coverage checks.
- **Tasks**:
  1. Verify all unit tests compile and pass via CLI.
  2. Implement E2E test cases validating sheet navigation, event streaming notifications, bookmark recovery, and spotlight indexing.
  3. Execute Forensic Auditor and correct any identified issues.
  4. Perform adversarial coverage verification.

## Interface Contracts
- **JSON-RPC Stdio Protocol Enhancements**:
  - Request format remains standard: `{"jsonrpc":"2.0", "id": <number>, "method": "...", "params": {...}}`
  - Notification format: `{"jsonrpc":"2.0", "method": "operations.event", "params": {"operationId": "...", "event": <MackanOperationEvent>}}`
  - The sidecar outputs notification lines asynchronously onto stdout. The client filters out lines that do not have an `id` field and dispatches them to event stream observers.

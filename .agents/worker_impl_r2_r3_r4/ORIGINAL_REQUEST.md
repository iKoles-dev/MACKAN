## 2026-06-19T18:19:48Z
You are the teamwork_preview_worker. Your task is to implement the remaining requirements for the MACKAN macOS app enhancements:
1. R2: JSON-RPC Live Event Streaming (Duplex transport & progress notifications).
2. R3: Security-Scoped Bookmarks (App Sandbox support).
3. R4: macOS Spotlight Integration.

Read:
- /Users/elijahn/GitHub/MACKAN/PROJECT.md
- /Users/elijahn/GitHub/MACKAN/TEST_INFRA.md
- /Users/elijahn/GitHub/MACKAN/macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift
- /Users/elijahn/GitHub/MACKAN/.agents/orchestrator/plan.md

Your working directory is /Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4. Please follow workflow conventions, update progress.md, and output a handoff report at handoff.md when complete.

Implementation details:
- R2 (Duplex Transport):
  - In MACKAN.Service (.NET sidecar), update Program.cs to thread-safe lock Console.Out when writing. Pass a progress notification callback from MackanServiceDispatcher to CoreMackanOperationProvider's OperationEventRecorder, so progress events write "operations.event" notifications directly to stdout.
  - In Swift's StdioSidecarTransport, implement an asynchronous read loop on stdout. Map request IDs using a thread-safe registry so request(...) resumes the matching continuation. Generate unique IDs instead of hardcoded 1. Expose an AsyncStream of notification lines.
  - In AppModel, observe the notifications stream and update the progress state of the running operation dynamically. Remove any polling timers in UI/views.
- R3 (Sandbox Bookmarks):
  - Create a SandboxBookmarkManager in MACKANKit to save URLs as security-scoped bookmarks in UserDefaults using the path as the key.
  - Save bookmarks when a game folder is chosen in AddInstanceSheet, CloneInstanceSheet, and FakeInstanceSheet.
  - Resolve and call startAccessingSecurityScopedResource() on loadInstanceState(for:) in AppModel, holding the accessed URL.
- R4 (Spotlight Integration):
  - Create a SpotlightIndexer using CoreSpotlight. Trigger mod indexing on publishLoadedModules/loadInstanceState for the current instance.
  - Implement .onContinueUserActivity in MainWindowView to deep-link to the selected mod, switching instance if necessary.

You MUST verify your implementation by running the existing unit tests and the E2E tests target (swift test --package-path macosx/MACKAN --filter E2E). Document your test output and verify layout compliance.
DO NOT CHEAT. All implementations must be genuine. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

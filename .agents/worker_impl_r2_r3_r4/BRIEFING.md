# BRIEFING — 2026-06-19T18:20:00Z

## Mission
Implement the remaining requirements for the MACKAN macOS app enhancements: R2 (JSON-RPC Live Event Streaming), R3 (Security-Scoped Bookmarks), and R4 (macOS Spotlight Integration).

## 🔒 My Identity
- Archetype: implementer/qa/specialist
- Roles: implementer, qa, specialist
- Working directory: /Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4
- Original parent: b7e9a7a2-1d5f-47e4-add0-b86568d8654f
- Milestone: Implementation of R2, R3, R4

## 🔒 Key Constraints
- CODE_ONLY network mode: No external network/HTTP client requests.
- DO NOT CHEAT: No dummy, hardcoded, or facade implementations.
- Verify changes by running existing unit tests and the E2E tests target (`swift test --package-path macosx/MACKAN --filter E2E`).
- File Workspace Directory Discipline: write only to our own directory `/Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4` for agent metadata.
- Layout Compliance: source code must be in designated directories; tests must be co-located; BUILD files per module; `.agents/` must contain only metadata.

## Current Parent
- Conversation ID: b7e9a7a2-1d5f-47e4-add0-b86568d8654f
- Updated: not yet

## Task Summary
- **R2 (Duplex Transport)**:
  - C# sidecar: thread-safe console writing, progress events written as "operations.event" notifications directly to stdout.
  - Swift sidecar transport: async read loop on stdout, thread-safe request ID registry mapping to continuations, generate unique IDs, expose AsyncStream of notification lines.
  - AppModel: observe notifications stream, dynamically update operation progress, remove polling timers.
- **R3 (Sandbox Bookmarks)**:
  - SandboxBookmarkManager in MACKANKit to save URLs as security-scoped bookmarks in UserDefaults using path as key.
  - Save bookmarks when a game folder is chosen (AddInstanceSheet, CloneInstanceSheet, FakeInstanceSheet).
  - Resolve and call startAccessingSecurityScopedResource() on loadInstanceState(for:) in AppModel.
- **R4 (Spotlight Integration)**:
  - SpotlightIndexer using CoreSpotlight. Index mods on publishLoadedModules/loadInstanceState.
  - Implement .onContinueUserActivity in MainWindowView to deep-link to mod, switching instance if necessary.
- **Success criteria**: All requirements implemented, unit & E2E tests pass, no hardcoding, no layout compliance issues.
- **Interface contracts**: PROJECT.md, TEST_INFRA.md, Tests/MACKANKitTests/E2ETests.swift, and .agents/orchestrator/plan.md.

## Key Decisions Made
- [TBD]

## Artifact Index
- /Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4/ORIGINAL_REQUEST.md — Original User Request
- /Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4/BRIEFING.md — Current Briefing File
- /Users/elijahn/GitHub/MACKAN/.agents/worker_impl_r2_r3_r4/progress.md — Liveness Heartbeat

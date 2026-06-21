# Scope: E2E Testing Track

## Architecture
- Target: MACKAN macOS app.
- Key features to test:
  - R1: SwiftUI State Management modal presentation.
  - R2: JSON-RPC Live Event Streaming (operation progress updates UI without active polling).
  - R3: App Sandbox Security-Scoped Bookmarks persistence across launches.
  - R4: macOS CoreSpotlight indexing, mdfind verification, and deep-linking.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Infrastructure Design | Create TEST_INFRA.md, design 49+ test cases across 4 tiers | None | PLANNED |
| 2 | Test Case Implementation | Implement test runner, script harnesses, mock/simulated inputs for R1-R4 | M1 | PLANNED |
| 3 | Verification & Auditing | Run test suite, check layout and integrity, ensure 100% pass | M2 | PLANNED |
| 4 | Finalization & Handoff | Generate and publish TEST_READY.md, report back to parent orchestrator | M3 | PLANNED |

## Interface Contracts
- The E2E test runner will be invoked as defined in TEST_INFRA.md.
- It must interface with the MACKAN app or test binaries opaque-box style (no direct implementation dependencies).
- Verification channels: stdout/stderr, files, OS-level searches (mdfind), and Apple Event / UI testing hooks if necessary.

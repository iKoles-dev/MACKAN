# Original User Request

## Initial Request — 2026-06-19T09:30:39+03:00

You are the E2E Testing Track Orchestrator. Working directory: /Users/elijahn/GitHub/MACKAN/.agents/e2e_testing_orch/
Your mission is to design and build a comprehensive opaque-box E2E test suite for the MACKAN macOS app.
Requirements to cover:
- R1: SwiftUI State Management modal presentation.
- R2: JSON-RPC Live Event Streaming (operation progress updates UI without active polling).
- R3: App Sandbox Security-Scoped Bookmarks persistence across launches.
- R4: macOS CoreSpotlight indexing, mdfind verification, and deep-linking.

Follow the Project Pattern's E2E Testing Track rules:
1. Create TEST_INFRA.md at project root using the template in the system instructions.
2. Design test cases using the 4-tier approach (Tiers 1-4).
3. Minimum test count thresholds: Given N=4 features, you need at least:
   - Tier 1: 20 test cases
   - Tier 2: 20 test cases
   - Tier 3: 4 test cases (pairwise coverage)
   - Tier 4: 5 application-level test cases
   Total minimum: 49 test cases.
4. Implement the test suite. If needed, write scripts/harnesses.
5. Publish TEST_READY.md at project root when all Tier 1-4 tests are ready and documented.
6. Verify and run your test suite. Do not modify implementation code files.
Initialize your SCOPE.md in your working directory and track progress in progress.md (with 'Last visited: [timestamp]' heartbeat header).
Once complete, publish TEST_READY.md and report back to the parent orchestrator (conversation ID: 2b41607b-5f7c-4bb7-903c-0550435692cc) with a summary.

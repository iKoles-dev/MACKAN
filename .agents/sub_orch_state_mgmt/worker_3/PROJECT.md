# Project: MACKAN Codebase Fixes (Worker 3 Scope)

## Architecture
- Swift package containing MACKANKit and associated tests (including E2ETests.swift).
- AppModel+Sheets.swift contains sheet presentation logic using `@MainActor`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Swift Concurrency Fix | Fix E2ETests.swift compile error with `isStaleVar` and main actor mutation warnings | none | PLANNED |
| 2 | Sheet Transition Race Conditions | Implement robust transition logic in `AppModel+Sheets.swift` | none | PLANNED |
| 3 | Verification | Compile cleanly and pass all tests via `swift test --package-path macosx/MACKAN` | M1, M2 | PLANNED |

## Code Layout
- Target files:
  - `macosx/MACKAN/Tests/MACKANKitTests/E2ETests.swift` (or similar, we will let the subagent locate it or find it ourselves)
  - `macosx/MACKAN/Sources/MACKANKit/AppModel+Sheets.swift`

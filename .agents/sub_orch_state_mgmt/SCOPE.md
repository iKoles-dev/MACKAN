# Scope: SwiftUI State Management Refactoring (MACKAN macOS)

## Architecture
- Refactor presentation state in `MACKANApp.swift` and related views.
- Eliminate multiple `@State private var isShowing...` boolean flags by introducing a centralized modal state (e.g. enum and/or Router) in `MACKANKit` or `MACKAN` executable.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Centralized Enum & Router | Define ActiveSheet and bind AppModel/Router to sheet presentation | none | PLANNED |
| 2 | App Refactoring | Replace boolean @State flags in MACKANApp.swift and update presentation logic | M1 | PLANNED |
| 3 | Verification | Compile app and check all sheets function exactly as before | M2 | PLANNED |

## Interface Contracts
- None. Internals refactoring only.

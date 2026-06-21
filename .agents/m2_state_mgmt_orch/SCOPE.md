# Scope: R1. SwiftUI State Management Refactoring

## Architecture
- Centralized state management for modals in `MACKANApp.swift`.
- Transition from multiple independent `@State` boolean flags (e.g., `isShowingAbout`, `isShowingUpdateCheck`, `isShowingInstanceManagement`) to a unified pattern, such as:
  - An `enum ActiveSheet: Identifiable` (representing each modal sheet).
  - A central state manager or Router class (ObservableObject / @Observable) containing the active sheet state.
- Data Flow:
  - Views request modal presentation by setting the active sheet state.
  - The main app view or Router presents the corresponding modal sheet based on the active sheet enum value.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Planning | Locate MACKANApp.swift, identify all presentation boolean flags, plan Router/Enum architecture, identify build and test commands | None | DONE |
| 2 | Refactoring Implementation | Refactor MACKANApp.swift and related views to use centralized enum/Router, eliminating the individual boolean flags | M1 | DONE |
| 3 | Review & Verification | Run build/test verify, perform code review, test modal opens/closes, run forensic audit checks | M2 | DONE |

## Interface Contracts
### ActiveSheet Enum
- Represents all modal presentation states: `about`, `updateCheck`, `instanceManagement`, etc.
- Must conform to `Identifiable` (with `id = self`).
- Must handle clean transition/dismissal (setting to `nil`).

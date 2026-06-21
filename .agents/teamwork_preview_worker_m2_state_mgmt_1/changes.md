# Change Log

## [2026-06-19]

### Added
- `macosx/MACKAN/Sources/MACKAN/Router.swift`:
  - Defined the `MACKANSheet` enum with 8 cases conforming to `Identifiable` and `Equatable`.
  - Defined the `AppRouter` class conforming to `ObservableObject` and bound to `@MainActor` with `activeSheet`, `present`, `dismiss`, and `dismissAndPresent` methods.

### Changed
- `macosx/MACKAN/Sources/MACKAN/MACKANApp.swift`:
  - Removed 8 individual `@State` private variables for controlling the sheet presentation.
  - Declared `@StateObject private var router = AppRouter()`.
  - Injected `router` environment object to `MainWindowView` via `.environmentObject(router)`.
  - Replaced the 8 individual `.sheet(isPresented:)` modifiers with a single `.sheet(item: $router.activeSheet)` that switches on `sheet` and returns the appropriate sheet view.
  - Replaced all setting of old sheet flags to `true`/`false` with `router.present(...)` calls.
  - Removed local helper `presentInstanceSubsheet(_:)` method, replacing its callers with `router.dismissAndPresent(...)`.

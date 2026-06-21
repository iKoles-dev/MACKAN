# Original User Request

## Initial Request — 2026-06-19T06:27:46Z

Implement all High and Medium priority UI/UX improvements to the MACKAN (CKAN GUI) application to modernize its visual design and improve usability.

Working directory: /Users/elijahn/GitHub/MACKAN
Integrity mode: development

## Requirements

### R1. Dark Theme Integration
Provide a built-in switch in the application Settings (or a suitable menu) to toggle between Light and Dark themes. The dark theme should apply to all main application windows, replacing the need for the manual `DarkTheme.reg` registry patch.

### R2. Human-Readable File Sizes
Format the display of file sizes in the main mod table (e.g., the "Download (KB)" column) to use human-readable units (e.g., MB, GB) instead of raw kilobytes.

### R3. Modernized Data Grid
Improve the readability of the main mod list by increasing the row height and implementing zebra striping (alternating row background colors). Ensure the active row selection uses a theme-appropriate accent color rather than the default system blue.

### R4. Unified Toolbar and Search
Unify the styling and sizing of toolbar icons. Consolidate the three separate filter fields (name, author, description) into a single, unified search bar with a dropdown or similar mechanism to select the filter target.

## Acceptance Criteria

### Automated Verification
- [ ] All existing unit/UI tests in the MACKAN project must pass via CLI (e.g. `dotnet test` or `msbuild`) after UI modifications are made.

### UI Verification (Agent-as-Judge)
- [ ] An independent subagent must verify that the application successfully compiles and launches.
- [ ] An independent subagent must verify that the file sizes in the grid are formatted in human-readable strings (e.g., "1.5 MB").
- [ ] An independent subagent must verify that the new unified search component correctly filters the mod list.
- [ ] An independent subagent must verify the presence of zebra striping and unified toolbar icons by inspecting the updated UI component properties.

## Follow-up — 2026-06-19T06:28:42Z

# Teamwork Project Prompt

Implement major architectural and feature enhancements for the MACKAN macOS app, focusing on state management, event streaming, sandbox support, and Spotlight integration.

Working directory: ~/GitHub/MACKAN
Integrity mode: development

## Requirements

### R1. SwiftUI State Management Refactoring
Refactor `MACKANApp.swift` and related views to use a centralized state management pattern (such as a Router or active sheet Enum). The goal is to eliminate the large number of individual `@State private var isShowing...` boolean flags used for modal presentation.

### R2. Live Event Streaming via JSON-RPC
Implement server-to-client notifications over the existing JSON-RPC stdio channel. The .NET sidecar should push operation progress events to the Swift client, replacing the current polling mechanism (`operations.status`).

### R3. Security-Scoped Bookmarks (App Sandbox Support)
Implement Security-Scoped Bookmarks in the Swift client to persist access to user-selected KSP game directories. This should allow MACKAN to retain file system access across application launches, even if macOS App Sandbox is strictly enforced.

### R4. macOS Spotlight Integration
Integrate with macOS CoreSpotlight to index installed KSP mods from the CKAN registry. Users should be able to search for their installed mods using the native macOS Spotlight (Cmd+Space).

## Acceptance Criteria

### State Management
- [ ] `MACKANApp.swift` no longer relies on multiple individual `@State` booleans for presenting application sheets.
- [ ] All existing modal sheets (About, Update Check, Instance Management, etc.) open and close correctly using the new pattern.

### Event Streaming
- [ ] The JSON-RPC transport layer successfully receives and handles unprompted notifications from the .NET sidecar.
- [ ] The UI updates correctly during an installation operation without requiring active polling from the Swift client.

### Security-Scoped Bookmarks
- [ ] After selecting a game directory, the application can read/write to that directory on a subsequent launch without showing an open file dialog.
- [ ] Bookmarks are securely persisted across sessions.

### Spotlight Integration
- [ ] Running the terminal command `mdfind` for a uniquely named installed mod returns a result associated with the MACKAN app.
- [ ] Clicking a Spotlight search result for a mod opens MACKAN.

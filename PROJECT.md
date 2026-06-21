# Project: MACKAN macOS App Architectural & Feature Enhancements

## Architecture
- Main GUI application: Swift + SwiftUI app (`macosx/MACKAN`) targeting macOS 13+.
- Core logic sidecar: .NET 10 app (`MACKAN.Service`) providing JSON-RPC APIs over stdio.
- Shared communication protocol: JSON-RPC 2.0 over standard I/O.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Centralized State Management | SwiftUI sheets refactoring (R1) | none | DONE |
| 2 | Duplex JSON-RPC Event Streaming | Async transport loop + server progress notifications (R2) | none | IN_PROGRESS (b7e9a7a2-1d5f-47e4-add0-b86568d8654f) |
| 3 | Sandbox Bookmarks | Security-scoped bookmarks persistence for sandbox (R3) | none | IN_PROGRESS (b7e9a7a2-1d5f-47e4-add0-b86568d8654f) |
| 4 | Spotlight Integration | CoreSpotlight indexing + mod deep-linking (R4) | none | IN_PROGRESS (b7e9a7a2-1d5f-47e4-add0-b86568d8654f) |
| 5 | E2E Testing Suite | Requirements validation suite (Tiers 1-4) | none | IN_PROGRESS (b7e9a7a2-1d5f-47e4-add0-b86568d8654f) |
| 6 | Integration & Verification | E2E passes + adversarial gaps (Tier 5) + Forensic Audit | M1, M2, M3, M4, M5 | PLANNED |

## Interface Contracts
### Client (Swift) ↔ Sidecar (.NET)
- Standard JSON-RPC 2.0 protocol over stdio.
- Requests: `{"jsonrpc": "2.0", "id": <int>, "method": "<method_name>", "params": { ... }}`
- Responses: `{"jsonrpc": "2.0", "id": <int>, "result": { ... }}` or `{"jsonrpc": "2.0", "id": <int>, "error": { ... }}`
- Notifications (new): `{"jsonrpc": "2.0", "method": "operations.event", "params": {"operationId": "<id>", "event": { "kind": "<kind>", "message": "<msg>", "percent": <pct>, ... }}}`

## Code Layout
- Swift Application: `macosx/MACKAN`
- Sidecar Application: `MACKAN.Service`
- Test Suites: `macosx/MACKAN/Tests/MACKANKitTests`

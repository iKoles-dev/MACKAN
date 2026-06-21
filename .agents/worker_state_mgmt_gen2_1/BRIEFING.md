# BRIEFING — 2026-06-19T21:40:19+03:00

## Mission
Fix sheet presentation race conditions and double-presentation flashing in the MACKAN macOS app.

## 🔒 My Identity
- Archetype: Teamwork agent
- Roles: implementer, qa, specialist
- Working directory: /Users/elijahn/GitHub/MACKAN/.agents/worker_state_mgmt_gen2_1
- Original parent: 28f4ae03-83cd-4d30-b03b-353363b53a85
- Milestone: Milestone 1 (Centralized State Management)

## 🔒 Key Constraints
- CODE_ONLY network mode: No external websites, services, curl/wget, etc.
- No dummy/facade implementations, no hardcoding test results.
- Minimum change principle. No "while I'm here" refactoring.
- Keep BRIEFING.md under 100 lines.

## Current Parent
- Conversation ID: 28f4ae03-83cd-4d30-b03b-353363b53a85
- Updated: not yet

## Task Summary
- **What to build**: Safe, race-free sheet presentations and dismissals. Prevent race conditions and double-presentation flashing by using a dismissal delay buffer (150ms) and cancelling any pending task.
- **Success criteria**: Swift and dotnet unit tests build and pass cleanly. No race conditions or double presentations.
- **Interface contracts**: Inside AppModel.swift and AppModel+Sheets.swift.
- **Code layout**: AppModel inside macosx/MACKAN/Sources/MACKANKit/, tests inside macosx/MACKAN/Tests/MACKANKitTests/.

## Key Decisions Made
- [TBD]

## Artifact Index
- /Users/elijahn/GitHub/MACKAN/.agents/worker_state_mgmt_gen2_1/handoff.md — Final handoff report.
- /Users/elijahn/GitHub/MACKAN/.agents/worker_state_mgmt_gen2_1/progress.md — Liveness heartbeat.

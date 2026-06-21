# Module Inspector Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the module inspector more useful and scannable by promoting primary links/actions, reorganizing overview content, formatting technical fields, and hiding raw metadata behind a quieter disclosure.

**Architecture:** Keep this pass on the SwiftUI presentation layer because `ModuleDetails.resources`, summary fields, relationship data, and module detail caching already exist. Avoid new sidecar calls for selection changes; derive quick actions and overview facts from `ModuleSummary` plus cached `ModuleDetails`.

**Tech Stack:** macOS SwiftUI, MACKANKit models, XCTest source-level regression tests, existing `swift test --package-path macosx/MACKAN` validation.

---

### Task 1: Inspector structure regression tests

**Files:**
- Modify: `macosx/MACKAN/Tests/MACKANKitTests/InspectorViewsImplementationTests.swift`
- Modify: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`

- [ ] Add source-level tests proving the inspector has header quick actions, a promoted overview, human date formatting helpers, and a collapsible technical details section.
- [ ] Run `swift test --package-path macosx/MACKAN --filter InspectorViewsImplementationTests` and verify the new tests fail before implementation.

### Task 2: Header quick actions

**Files:**
- Modify: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`

- [ ] Add `ModuleHeaderAction`, resource prioritization, compact icon links for Homepage/Repository/Bug Tracker/SpaceDock/Curse/Manual/License, and a `Copy ID` button.
- [ ] Keep all links available in the `Links` tab while surfacing only the highest-value links in the header.

### Task 3: Overview redesign

**Files:**
- Modify: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`

- [ ] Replace the current `Summary` + large `Metadata` first impression with `At a glance`, description, tags, relationship summary, and `Technical details`.
- [ ] Format release/install dates into localized medium dates where possible and fall back to source text when parsing fails.
- [ ] Move raw metadata into `DisclosureGroup("Technical details")`.

### Task 4: Link presentation polish

**Files:**
- Modify: `macosx/MACKAN/Sources/MACKAN/InspectorViews.swift`

- [ ] Make the `Links` tab use the same icon vocabulary and cleaner row shape as header actions.
- [ ] Preserve URL visibility for inspection and text selection where a link is malformed.

### Task 5: Verification

**Files:**
- Build artifact: `.build/mackan-app/MACKAN.app`

- [ ] Run targeted inspector tests.
- [ ] Run `swift test --package-path macosx/MACKAN`.
- [ ] Run `macosx/MACKAN/scripts/build-dev-app.sh`.
- [ ] Launch with `open -g`, capture the MACKAN window by id, and verify the inspector visually without stealing focus.

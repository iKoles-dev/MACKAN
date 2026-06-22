# MACKAN Documentation

MACKAN is a native macOS CKAN preview app for Kerbal Space Program players. This
folder is the public documentation index for the native app, sidecar boundary,
release plan, and parity work.

## Start Here

| Need | Read |
| --- | --- |
| Product scope and target experience | [Product spec](product-spec.md) |
| Native app, sidecar, and CKAN Core boundaries | [Architecture](architecture.md) |
| What is implemented versus Windows CKAN | [Parity matrix](parity-matrix.md) |
| What blocks a broader public release | [Release roadmap](release-roadmap.md) |
| Concrete signing and release gates | [Release execution checklist](release-execution-checklist.md) |
| Operational release flow | [v1 release runbook](v1-release-execution-runbook.md) |
| Public-preview hygiene status | [Public readiness report](public-readiness-report.md) |

## Current Preview Shape

MACKAN keeps CKAN Core as the source of truth and adds:

- `macosx/MACKAN`: the SwiftUI/AppKit app that owns native macOS UI,
  presentation state, windows, menus, and user-facing workflows.
- `MACKAN.Service`: the .NET JSON-RPC sidecar that exposes CKAN Core operations
  to the native app.
- `macosx/MACKAN/scripts`: bundle, DMG, verification, launch-smoke,
  release-readiness, and provenance scripts.

The preview app is useful for testing native macOS workflows now. A broader
public release still requires Developer ID signing, hardened runtime,
notarization, stapling, checksums, provenance, and clean-install smoke evidence.

## For Testers

Useful feedback includes:

- macOS version and CPU architecture.
- KSP install source and path shape, without private personal paths when
  possible.
- Whether this is a fresh MACKAN run or existing CKAN data.
- The exact workflow: first launch, instance selection, repository refresh,
  catalog search, install/remove/upgrade preview, cache cleanup, or export.
- Expected result, actual result, and whether retrying changed the outcome.

Use the GitHub issue templates from the repository root when reporting preview
feedback.

## For Contributors

Before changing behavior, check the owning boundary:

- Native macOS presentation belongs in `macosx/MACKAN`.
- JSON-RPC contract and CKAN Core calls belong in `MACKAN.Service`.
- Mod metadata, dependency resolution, downloads, registry mutation,
  compatibility decisions, and exports remain CKAN Core responsibilities.

Avoid duplicating CKAN Core logic in Swift. Add a sidecar contract when the
native UI needs new CKAN behavior.

## Planning And Evidence Files

Older sprint plans, UI audit logs, generated release-readiness evidence, and
planning artifacts may exist in this folder. They are useful for audits, but the
documents listed in Start Here are the public entry points. When an evidence run
matters publicly, summarize it in a maintained public document instead of making
readers reconstruct the state from raw logs.

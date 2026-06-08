# MACKAN Documentation

This directory contains the public documentation for MACKAN, the native macOS
CKAN GUI preview.

## Public Entry Points

- [Architecture](architecture.md): app/sidecar/Core boundaries, JSON-RPC shape,
  packaging model, and release artifact expectations.
- [Product spec](product-spec.md): target user experience and scope.
- [Parity matrix](parity-matrix.md): Windows CKAN capability coverage and MACKAN
  status by area.
- [Release roadmap](release-roadmap.md): release sequencing, remaining gates,
  and signed/notarized handoff requirements.
- [Release execution checklist](release-execution-checklist.md): concrete
  release gates and evidence requirements.
- [v1 release runbook](v1-release-execution-runbook.md): operational release
  flow for the native macOS app.
- [Public readiness report](public-readiness-report.md): current public-preview
  hygiene status, verification commands, and commit grouping guidance.

## Current Preview Position

MACKAN keeps CKAN Core as the source of truth and adds:

- `MACKAN.Service`, a .NET JSON-RPC sidecar that exposes CKAN Core behavior to
  the native app.
- `macosx/MACKAN`, a SwiftUI/AppKit app that owns the native macOS UI and
  presentation state.
- macOS bundle, DMG, verification, launch-smoke, release-readiness, and
  provenance scripts under `macosx/MACKAN/scripts`.

The repository is suitable for public source preview when the hygiene gates in
the root README are kept current. A public binary release still requires
Developer ID signing, hardened runtime, notarization, stapling, checksums, and
release provenance.

## Local Evidence And Planning Snapshots

Older sprint plans, full UI audit logs, generated release-readiness evidence,
and superpowers planning artifacts may exist in local working trees while the
project is being audited. Those files often contain local paths, temporary
directories, screenshots, or machine-specific context, so they are excluded from
the public tree by `.gitignore`.

When a local evidence run matters publicly, summarize it in one of the public
documents above instead of committing the raw evidence packet.

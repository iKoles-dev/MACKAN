# MACKAN Full UI/Function Audit Matrix

Date: 2026-06-06
Source spec: `docs/superpowers/specs/2026-06-06-mackan-full-ui-function-audit-design.md`
Evidence log: `docs/mackan/full-ui-function-audit-evidence-2026-06-06.md`

## Status Values

- `not-run`: row is inventoried but no proof exists.
- `pass`: row has automated proof and real-app proof when applicable.
- `fail`: row has a defect that needs a fix.
- `fixed`: row failed, was patched, and was reverified.
- `deferred`: row is intentionally postponed with a recorded reason.
- `intentionally-unsupported`: row is a visible unsupported state with release-approved rationale.

## Severity Values

- `P0`: app cannot launch, destructive/unrecoverable mutation, broken apply/registry path, or Terminal opens for GUI flow.
- `P1`: visible control/function is broken, wrong mutation, blocking layout/accessibility issue, or recovery path unusable.
- `P2`: confusing state, missing progress, weak error copy, non-critical clipping, accessibility gap.
- `P3`: polish or optional workflow improvement.

## Matrix

| ID | Surface | Element | Trigger | Function Trace | Preconditions | Real Action | Expected Result | Automation Proof | Real-App Proof | Risk | Status | Defect Link |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

# MACKAN Full UI/Function Audit Evidence (2026-06-06)

## Run Policy

- Real mutating checks are allowed.
- No preliminary backup/rollback layer is used.
- Start-state capture is evidence only.
- Auth-token tests use a dummy non-secret token only.

## Start State

| Item | Evidence |
| --- | --- |
| Git status | not captured |
| Built app path | not captured |
| App version | not captured |
| Selected instance | not captured |
| Repository list | not captured |
| Installed modules summary | not captured |
| Current staged changes | not captured |
| Settings summary | not captured |
| Initial screenshots | not captured |
| Strict readiness JSON | not captured |

## Command Log

| Time | Command | Result | Notes |
| --- | --- | --- | --- |
| 2026-06-06T14:11:15+0300 | `rg --files macosx/MACKAN/Tests/MACKANKitTests &#124; sort` | exit 0 | Listed 22 Swift XCTest files for automation proof mapping. |
| 2026-06-06T14:11:15+0300 | `rg --files Tests/MACKAN &#124; sort` | exit 0 | Listed 9 .NET MACKAN test files for sidecar/provider/dispatcher proof mapping. |
| 2026-06-06T14:11:15+0300 | `rg --files macosx/MACKAN/scripts &#124; sort` | exit 0 | Listed 37 script gates, including UI/UX audit, app launch, accessibility, bundle, DMG and release verifier scripts. |
| 2026-06-06T14:25:08+0300 | `python3 ... matrix proof mapping verification` | exit 0 | 102 rows, no malformed rows, no duplicate IDs, 0 empty/`not mapped` proof cells, 2 `proof-missing` rows, runnable script args present. |
| 2026-06-06T14:25:08+0300 | `git diff --check -- docs/mackan/full-ui-function-audit-matrix.md docs/mackan/full-ui-function-audit-evidence-2026-06-06.md` | exit 0 | Task 5 correction diff has no whitespace errors. |

## Live Mutations

| Time | Matrix Row | Action | Observed State Change |
| --- | --- | --- | --- |

## Defects

| Matrix Row | Severity | Summary | Owner Files | Fix Status | Verification |
| --- | --- | --- | --- | --- | --- |

## Screenshots and Artifacts

| Artifact | Path | Matrix Rows |
| --- | --- | --- |

## Automated Proof Mapping Summary

| Item | Value |
| --- | --- |
| Matrix rows mapped | 102 |
| Swift XCTest files found | 22 |
| .NET MACKAN test files found | 9 |
| Script gates found | 37 |
| Rows with `Automation Proof` still `not mapped` | 0 |
| `proof-missing` rows | 2 |
| `proof-missing` row IDs | `SET-PLUGINS-001`, `FUNC-NONUI-003` |

Notes: Task 5 maps existing automation only; mapped rows remain `not-run` until Task 6 or later execution actually runs the proof. `SET-PLUGINS-001` is `proof-missing` because no current automation asserts the Plugins tab unsupported-state copy or CKAN links. `FUNC-NONUI-003` is `proof-missing` because .NET route/provider proof exists, but no current Swift `SidecarClientTests` method asserts `SidecarClient.refreshRepositories` uses `repositories.refresh`.

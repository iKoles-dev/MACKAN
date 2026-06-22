# MACKAN Troubleshooting

Use this page when the preview app does not open, cannot find Kerbal Space
Program, cannot refresh repositories, or fails during a mod operation.

## Gatekeeper Blocks The App

Current preview builds are ad-hoc signed but not Developer ID signed or
notarized yet.

Try this first:

1. Unzip the release archive.
2. In Finder, right-click `MACKAN.app`.
3. Choose Open.
4. Confirm that you want to open the app.

If macOS still refuses to open it, verify the checksum from [INSTALL.md](../../INSTALL.md)
and download the archive again if it does not match.

## The App Opens But The Sidecar Fails

MACKAN uses a .NET sidecar to call CKAN Core. If the UI opens but operations
fail immediately:

- Reopen the app once to rule out a stale process.
- Check whether the error mentions sidecar launch, sidecar health, JSON-RPC, or
  CKAN Core.
- Include the visible error text in the report.
- Do not paste full local paths or private logs into public issues.

## KSP Instance Is Missing

If MACKAN does not find your KSP install:

- Add the instance manually if the UI offers that path.
- Mention the install source, such as Steam, GOG, Epic, or manual install.
- Mention the path shape, such as `~/Games/...` or an external drive, without
  posting private personal path segments.
- Confirm whether the same instance already has CKAN data.

## Repository Refresh Fails

Repository refresh failures are most useful when reported with:

- The selected repository set.
- Whether the failure happens every time or only once.
- The visible network or metadata error text.
- Whether retrying after reopening the app changes the result.

## Install, Remove, Or Upgrade Preview Fails

Before applying broad changes to a real KSP install, test with a small operation
or a copied instance when possible.

Useful details:

- The module identifier or visible module name.
- Whether the failure is in preview, dependency resolution, download, install,
  registry lock, or apply.
- The expected result and the actual result.
- Whether retry, cancel, or reopening the app recovers the state.

## Import, Export, Or Cache Maintenance Fails

Include the workflow name and sanitized path shape:

- Local `.ckan` install.
- Manual download import.
- Mod list export.
- `.ckan` modpack export.
- Cache cleanup or deduplication.
- Registry repair.

Do not attach full exports, logs, or diagnostics bundles publicly until you have
reviewed [Diagnostics and privacy](diagnostics-privacy.md).

## Good Bug Report Shape

```text
MACKAN build:
macOS and Mac:
KSP source and path shape:
Fresh run or existing CKAN data:
Workflow:
Steps:
Expected:
Actual:
Visible error:
Retry result:
Sanitized diagnostics:
```

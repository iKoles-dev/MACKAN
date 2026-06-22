# GitHub Repository Settings

These settings complete the public MACKAN repository presentation. They require
GitHub repository Settings access because the current automation environment
does not expose repository metadata, issue enablement, label creation, or pinned
issue APIs.

## About Section

Set these fields in the repository About panel:

```text
Description:
Native macOS CKAN mod management for Kerbal Space Program.

Website:
https://ikoles-dev.github.io/MACKAN/

Topics:
macos
swiftui
kerbal-space-program
ksp
ckan
mods
mod-manager
```

## Features

Enable:

- Issues
- Releases
- Discussions, optional, if you want a lower-friction feedback channel

Issues must be enabled before `.github/ISSUE_TEMPLATE` forms and
`/issues/new/choose` links work.

## Suggested Labels

Create or keep these labels:

| Label | Color | Purpose |
| --- | --- | --- |
| `preview-feedback` | `477a59` | General MACKAN preview testing notes |
| `bug` | `d73a4a` | Reproducible failures |
| `packaging` | `5319e7` | App bundle, zip, signing, notarization, DMG |
| `gatekeeper` | `d876e3` | macOS open/signing/notarization friction |
| `instances` | `1d76db` | KSP instance detection and management |
| `repositories` | `0e8a16` | Repository list, refresh, source management |
| `catalog` | `a2eeef` | Search, filters, labels, module details |
| `install-flow` | `fbca04` | Install/remove/upgrade/apply workflows |
| `diagnostics` | `bfdadc` | Logs, diagnostics bundles, health checks |
| `needs-repro` | `ededed` | More reproduction detail needed |

## Pinned Feedback Issue

After Issues are enabled, create and pin an issue with this title:

```text
MACKAN Preview Feedback
```

Suggested body:

```markdown
Use this issue for broad MACKAN preview feedback that is not yet a focused bug report.

Preview download:
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview

Website:
https://ikoles-dev.github.io/MACKAN/

Install guide:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/INSTALL.md

Troubleshooting:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/docs/mackan/troubleshooting.md

Useful feedback includes:

- MACKAN build, release tag, or workflow run
- macOS version and Apple Silicon/Intel
- KSP install source and path shape, without private personal paths
- fresh run or existing CKAN data
- first launch and Gatekeeper open flow
- KSP instance detection
- repository refresh
- catalog browsing, search, filtering, and module details
- install/remove/upgrade preview and apply flow
- visible error text and short reproduction steps

Before posting logs or diagnostics publicly, review:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/docs/mackan/diagnostics-privacy.md
```

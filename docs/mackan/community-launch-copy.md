# Community Launch Copy

Use these short drafts when asking Mac Kerbal Space Program players to test the
MACKAN preview. Keep the links current before posting.

## Short Forum Or Discord Post

MACKAN is a native macOS preview app for CKAN mod management in Kerbal Space
Program.

It keeps CKAN Core as the mod metadata, dependency, download, install, and
registry engine, while adding a SwiftUI/AppKit desktop UI for Mac players.

Preview build:
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview

Website:
https://ikoles-dev.github.io/MACKAN/

This preview is ad-hoc signed and not notarized yet, so Gatekeeper may require
Finder right-click -> Open. The most useful testing feedback covers first
launch, KSP instance detection, repository refresh, catalog browsing, module
details, install/remove/upgrade previews, and apply/recovery behavior.

## Reddit Post Draft

Title:

```text
MACKAN: native macOS CKAN preview app looking for testers
```

Body:

```text
I am testing MACKAN, a native macOS preview app for CKAN mod management in Kerbal Space Program.

The goal is to keep CKAN Core as the source of truth for metadata, dependency resolution, downloads, installs, exports, and registry state, while replacing the Terminal-style Mac workflow with a SwiftUI/AppKit desktop app.

Preview download:
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview

Website:
https://ikoles-dev.github.io/MACKAN/

The current build is ad-hoc signed and not notarized yet, so macOS may require Finder right-click -> Open. A signed/notarized DMG is still a release gate.

Useful feedback:
- macOS version and Apple Silicon/Intel
- KSP install source and path shape
- fresh run or existing CKAN data
- first launch and instance detection
- repository refresh
- catalog search/filtering
- module detail view
- install/remove/upgrade preview and apply flow
- visible errors with short repro steps
```

## Ultra-Short Status Line

```text
MACKAN is a native macOS CKAN preview for KSP mod management. Test build: https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview
```

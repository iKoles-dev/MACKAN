# Community Launch Copy

Use these short drafts when asking Mac Kerbal Space Program players to test the
MACKAN preview. Keep the links current before posting.

## Short Forum Or Discord Post

MACKAN v0.1.0-preview.1 is a native macOS preview app for CKAN mod management
in Kerbal Space Program.

It keeps CKAN Core as the mod metadata, dependency, download, install, and
registry engine, while adding a SwiftUI/AppKit desktop UI for Mac players.

Preview build:
https://github.com/iKoles-dev/MACKAN/releases/tag/v0.1.0-preview.1

Latest preview channel:
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview

Website:
https://ikoles-dev.github.io/MACKAN/

This preview is ad-hoc signed and not notarized yet, so Gatekeeper may require
Finder right-click -> Open or System Settings -> Privacy & Security -> Open
Anyway. Useful testing feedback covers first launch, KSP instance detection,
repository refresh, catalog browsing, module details, install/remove/upgrade
previews, and apply/recovery behavior.

## KSP Forum Topic Draft

Title:

```text
[Mac] MACKAN v0.1.0-preview.1 - native macOS CKAN mod manager
```

Tags:

```text
macos, ckan, mod-manager, tool, utility, preview
```

Body:

```text
MACKAN v0.1.0-preview.1 is a native macOS public preview app for CKAN mod management in Kerbal Space Program.

It keeps CKAN Core as the engine for metadata, dependency resolution, downloads, installs, exports, registry state, and compatibility decisions, while adding a SwiftUI/AppKit desktop UI for Mac players.

Screenshot:
https://ikoles-dev.github.io/MACKAN/assets/screenshots/mackan-catalog.png

Download:
https://github.com/iKoles-dev/MACKAN/releases/tag/v0.1.0-preview.1

Latest preview channel:
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview

Website:
https://ikoles-dev.github.io/MACKAN/

Source code:
https://github.com/iKoles-dev/MACKAN/tree/mackan-native

License:
MIT. The download includes the project license file, and the license is also available in the repository:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/LICENSE.md

Important status:
- This is a public preview, not a finished production release.
- This is an independent MACKAN preview/fork direction and not an official CKAN release.
- The current build is ad-hoc signed and not notarized yet.
- macOS may require Finder right-click -> Open, or System Settings -> Privacy & Security -> Open Anyway.
- A Developer ID signed and notarized DMG remains a release gate.

Platform:
- macOS 13+
- Universal preview archive for Apple Silicon and Intel Macs
- KSP1 testing first

What is included:
- Native macOS app UI built with SwiftUI/AppKit
- A bundled .NET sidecar service used by the app
- CKAN Core behavior used for repository metadata, dependency solving, downloads, installs, cache, registry, and compatibility logic
- No third-party KSP mods are bundled with the app

Network access:
MACKAN contacts CKAN/GitHub/repository endpoints and mod download hosts as needed to refresh repositories, check preview releases, and download mod archives selected through CKAN metadata. It receives repository metadata, release information, and mod archives. It does not intentionally collect or transmit personally identifiable information.

File access:
MACKAN manages the KSP instances selected by the user. It can write mod files, registry/cache state, and related CKAN data for the chosen KSP instance when the user applies changes. It also uses normal macOS app support/cache/log locations for app state and diagnostics.

What is ready to test:
- First launch and KSP instance detection
- Repository refresh and catalog browsing
- Search, filters, tags, saved searches, and labels
- Module details/inspector
- Install/remove/upgrade preview flows
- Apply/retry/recovery behavior for low-risk changes
- Cache, history, unmanaged files, and maintenance views

Useful feedback:
- macOS version and Apple Silicon/Intel
- KSP install source: Steam, GOG, or manual
- Sanitized path shape, for example ~/Games/KSP or /Volumes/External/KSP
- Fresh MACKAN run or existing CKAN data
- Exact steps, expected result, actual result
- Visible error text or screenshot with private data removed

Install notes:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/INSTALL.md

Troubleshooting:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/docs/mackan/troubleshooting.md

Diagnostics and privacy:
https://github.com/iKoles-dev/MACKAN/blob/mackan-native/docs/mackan/diagnostics-privacy.md

Please report focused bugs on GitHub Issues:
https://github.com/iKoles-dev/MACKAN/issues/new/choose
```

## Reddit Post Draft

Title:

```text
MACKAN v0.1.0-preview.1: native macOS CKAN preview app looking for testers
```

Body:

```text
I am testing MACKAN v0.1.0-preview.1, a native macOS preview app for CKAN mod management in Kerbal Space Program.

The goal is to keep CKAN Core as the source of truth for metadata, dependency resolution, downloads, installs, exports, and registry state, while replacing the Terminal-style Mac workflow with a SwiftUI/AppKit desktop app.

Preview download:
https://github.com/iKoles-dev/MACKAN/releases/tag/v0.1.0-preview.1

Website:
https://ikoles-dev.github.io/MACKAN/

The current build is ad-hoc signed and not notarized yet, so macOS may require Finder right-click -> Open or System Settings -> Privacy & Security -> Open Anyway. A signed/notarized DMG is still a release gate.

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
MACKAN v0.1.0-preview.1 is a native macOS CKAN preview for KSP mod management. Test build: https://github.com/iKoles-dev/MACKAN/releases/tag/v0.1.0-preview.1
```

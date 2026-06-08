# Contributing To MACKAN

MACKAN is currently a public-preview fork direction for a native macOS CKAN UI.
The codebase still contains the upstream CKAN projects, so contributions should
be explicit about whether they target upstream CKAN behavior or MACKAN-specific
native macOS behavior.

## Before Starting

- Read [docs/mackan/README.md](docs/mackan/README.md).
- Check [docs/mackan/parity-matrix.md](docs/mackan/parity-matrix.md) for
  feature status.
- Check [docs/mackan/architecture.md](docs/mackan/architecture.md) before
  changing sidecar or native app boundaries.

## MACKAN Boundary

- SwiftUI/AppKit code in `macosx/MACKAN` owns native macOS UI and presentation.
- `MACKAN.Service` owns JSON-RPC contracts and calls CKAN Core.
- CKAN Core owns mod metadata, dependency resolution, registry mutation,
  downloads, installation, exports, and compatibility decisions.

Avoid duplicating CKAN Core logic in Swift. Prefer adding an explicit sidecar
contract and tests when the native UI needs new CKAN behavior.

## Local Checks

Useful commands:

```bash
swift test --package-path macosx/MACKAN
dotnet test Tests/Tests.csproj --framework net10.0 --filter MACKAN
macosx/MACKAN/scripts/release-check.sh --skip-launch
```

For packaging work:

```bash
macosx/MACKAN/scripts/package-dmg.sh --universal
macosx/MACKAN/scripts/verify-app-bundle.sh --mode universal --require-icon \
    "$HOME/Library/Caches/MACKAN/build/MACKAN.app"
```

## Public Preview Quality Bar

Changes that affect the native app should include focused tests or clear manual
evidence for the touched workflow. Public-facing documentation should avoid
local absolute paths, private machine state, temporary logs, or credentials.

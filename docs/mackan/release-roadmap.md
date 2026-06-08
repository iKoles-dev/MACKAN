# MACKAN Release Roadmap

MACKAN has two different release tracks:

- **Source preview:** the repository can be public when documentation, workflow
  safety, attribution, and privacy hygiene are clean.
- **Binary release:** a downloadable DMG requires signing, notarization,
  stapling, checksums, provenance, and launch-smoke evidence.

## Current Position

The native app, sidecar contracts, packaging helpers, parity tracking, and local
release gates are present in the tree. The project should still be presented as
a preview until the signed/notarized release path is exercised with real Apple
Developer ID credentials.

## Milestone 1: Public Source Preview

Required before making the repository public:

- MACKAN-first README and docs index.
- Clear CKAN upstream attribution and KSP/Kerbal Space Program disclaimer.
- Upstream CKAN deploy/release workflows guarded so this fork cannot
  accidentally publish upstream infrastructure artifacts.
- Final MACKAN icon assets committed without generated design variants.
- Raw local evidence, screenshots, sprint logs, and planning snapshots excluded
  from public commits.
- Secret/privacy scan shows no credentials, local KSP instance names, or private
  machine paths in committed public docs.

## Milestone 2: Unsigned Local RC

Required for engineering confidence before a public binary:

```bash
macosx/MACKAN/scripts/release-check.sh --skip-launch
macosx/MACKAN/scripts/package-dmg.sh --universal
macosx/MACKAN/scripts/verify-app-bundle.sh --mode universal --require-icon \
    "$HOME/Library/Caches/MACKAN/build/MACKAN.app"
```

Optional but expected on a machine with GUI access:

```bash
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 \
    "$HOME/Library/Caches/MACKAN/build/MACKAN.app"
```

## Milestone 3: Signed And Notarized RC

Required for public downloadable artifacts:

- `MACKAN_DEVELOPER_ID_APPLICATION` resolves to a valid Developer ID
  Application identity.
- `MACKAN_NOTARY_KEYCHAIN_PROFILE` validates with `xcrun notarytool`.
- `release-dmg.sh` signs the app and DMG with hardened runtime.
- Notarization is accepted and stapling succeeds.
- DMG launch smoke and clean-install smoke both pass.
- `verify-release-artifact.sh --require-public-release` passes against the DMG,
  provenance, raw notary JSON, checksum manifest, and release summary.

## Milestone 4: Public Release

Public release upload requires:

- Signed and notarized DMG.
- SHA-256 checksum manifest.
- Provenance JSON.
- Raw notary JSON.
- Machine-readable release summary.
- Release log.
- A short human-readable release note that states preview limitations and points
  users back to CKAN upstream support where appropriate.

## Known Preview Limitations

- In-app updating is check-and-manual-install for preview; signed automatic
  update installation is post-preview release engineering.
- Raw release evidence packets are local audit artifacts, not public docs.
- Public binary release remains blocked until Apple signing/notarization
  credentials are available and verified.

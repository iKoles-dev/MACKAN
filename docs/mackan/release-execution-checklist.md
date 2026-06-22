# MACKAN Release Execution Checklist

This checklist defines the public release gates for MACKAN. It is intentionally
short; detailed logs should stay local unless summarized for public release
notes.

## Source Preview Gate

- [ ] Root README presents MACKAN first and clearly marks the project as a
  native macOS CKAN GUI preview.
- [ ] `NOTICE.md`, `LICENSE.md`, `SECURITY.md`, and `CONTRIBUTING.md` are
  present.
- [ ] CKAN upstream attribution is clear.
- [ ] KSP/Kerbal Space Program affiliation disclaimer is present.
- [ ] Upstream CKAN deploy/release workflows are guarded to upstream repository
  only.
- [ ] Generated icon variants and raw local evidence snapshots are excluded from
  public commits.
- [ ] Secret/privacy scan is clean for committed public files.

## Local Engineering Gate

Run:

```bash
macosx/MACKAN/scripts/release-check.sh --skip-launch
```

Expected coverage:

- Swift package tests for the native app.
- MACKAN-focused .NET tests.
- NuGet vulnerability audit.
- Packaging helper tests.
- Universal DMG packaging.
- Bundle verification.

When GUI access is available, also run:

```bash
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 \
    "$HOME/Library/Caches/MACKAN/build/MACKAN.app"
```

## Public Binary Gate

Before uploading a downloadable DMG:

- [ ] Developer ID Application identity is available.
- [ ] Notary keychain profile is valid.
- [ ] Hardened runtime signing is enabled.
- [ ] App notarization is accepted.
- [ ] DMG is stapled.
- [ ] DMG launch smoke passes.
- [ ] Clean-install launch smoke passes.
- [ ] Checksum, provenance, notary JSON, release summary, and release log are
  generated.
- [ ] `verify-public-release-handoff.sh` passes for the full artifact set.
- [ ] GitHub release tag, app version, archive name, checksum name, and forum
  topic title all use the same MACKAN version.

Unsigned local builds may be shared only as explicit development previews, not
as production release artifacts.

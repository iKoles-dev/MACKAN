# MACKAN v1 Release Runbook

This runbook is for producing a public MACKAN v1 release from a clean source
tree.

## 1. Prepare Source

1. Confirm the public docs are current:
   - `README.md`
   - `docs/mackan/README.md`
   - `docs/mackan/architecture.md`
   - `docs/mackan/product-spec.md`
   - `docs/mackan/parity-matrix.md`
   - `docs/mackan/release-roadmap.md`
   - `docs/mackan/release-execution-checklist.md`
2. Confirm no raw local evidence, generated design variants, temporary logs, or
   private paths are part of the public commit.
3. Confirm the working tree is clean except for intended release changes.

## 2. Run Local Gate

```bash
macosx/MACKAN/scripts/release-check.sh --skip-launch
```

On a GUI-capable macOS host:

```bash
macosx/MACKAN/scripts/verify-app-launch.sh --timeout 25 \
    "$HOME/Library/Caches/MACKAN/build/MACKAN.app"
```

## 3. Build Unsigned DMG For Engineering Review

```bash
DMG_PATH="$(macosx/MACKAN/scripts/package-dmg.sh --universal)"
hdiutil verify "$DMG_PATH"
```

## 4. Prepare Signing Credentials

Required environment:

- `MACKAN_DEVELOPER_ID_APPLICATION`
- `MACKAN_NOTARY_KEYCHAIN_PROFILE`
- Apple notary credentials stored in the configured keychain profile.

Validate credentials before release promotion:

```bash
macosx/MACKAN/scripts/release-readiness.sh \
    --strict \
    --require-release-credentials \
    --json
```

## 5. Produce Public DMG

```bash
MACKAN_NOTARIZE=true \
MACKAN_STAPLE=true \
MACKAN_RELEASE_DMG_SMOKE=true \
MACKAN_RELEASE_DMG_CLEAN_SMOKE=true \
macosx/MACKAN/scripts/release-dmg.sh --smoke
```

## 6. Verify Handoff

Run the verifier printed by the release summary, or call the handoff verifier
directly with the DMG, provenance, notary JSON, checksum manifest, and summary.

The release is not ready for upload unless the handoff verifier passes.

## 7. Publish

Upload:

- signed and notarized DMG
- checksum manifest
- provenance JSON
- raw notary JSON
- release summary
- release log

The release note should clearly state whether the build is a preview, which
macOS versions were tested, and where users should report CKAN upstream issues
versus MACKAN native macOS issues.

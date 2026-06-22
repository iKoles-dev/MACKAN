# Install MACKAN Preview

MACKAN preview builds are published as a zipped macOS app on GitHub Releases.
They are intended for testers who are comfortable opening an ad-hoc signed app.

## Download

1. Open the [MACKAN Preview release](https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview).
2. Download `MACKAN-preview-macOS.app.zip`.
3. Download `MACKAN-preview-macOS.app.zip.sha256` from the same release.

## Verify The Download

From the folder containing both downloaded files:

```bash
shasum -a 256 -c MACKAN-preview-macOS.app.zip.sha256
```

Expected result:

```text
MACKAN-preview-macOS.app.zip: OK
```

If the checksum does not match, delete the zip and download it again.

## Open The App

1. Unzip `MACKAN-preview-macOS.app.zip`.
2. Move `MACKAN.app` wherever you want to test it.
3. Open `MACKAN.app`.
4. If macOS blocks a normal double-click, use Finder right-click, then Open.
   On newer macOS versions you may need to approve the blocked app in
   System Settings -> Privacy & Security -> Open Anyway.

The current preview is ad-hoc signed but not Developer ID signed or notarized
yet. A signed and notarized DMG remains a release gate.

## First Launch Checklist

- Confirm the app opens without Terminal.
- Confirm MACKAN finds or lets you add a Kerbal Space Program instance.
- Confirm repository refresh on launch populates the catalog, or run
  Mods -> Refresh Repositories if the network was unavailable on first launch.
- Browse the catalog and open a module detail view.
- Try a low-risk install/remove/upgrade preview before applying real changes.
- Export or back up any important CKAN state before broad testing.

## If Something Fails

Start with [Troubleshooting](docs/mackan/troubleshooting.md). When reporting a
problem, include:

- MACKAN build, release tag, or workflow run.
- macOS version and whether the Mac is Apple Silicon or Intel.
- KSP install source and path shape, without private personal paths.
- Whether this is a fresh MACKAN run or existing CKAN data.
- Exact steps, expected result, actual result, and visible error text.

Review [Diagnostics and privacy](docs/mackan/diagnostics-privacy.md) before
posting logs or diagnostics bundles publicly.

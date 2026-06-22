# MACKAN Preview Release Versioning

MACKAN preview builds use an app-specific SemVer prerelease version that is
separate from the bundled CKAN Core version.

## Current Public Preview

Current forum-ready preview:

```text
v0.1.0-preview.1
```

Release page:

```text
https://github.com/iKoles-dev/MACKAN/releases/tag/v0.1.0-preview.1
```

Moving latest-preview channel:

```text
https://github.com/iKoles-dev/MACKAN/releases/tag/mackan-preview
```

## Naming Rules

- App version, stored in `Info.plist`: `0.1.0-preview.1`
- Git tag and GitHub release: `v0.1.0-preview.1`
- Archive asset: `MACKAN-0.1.0-preview.1-macOS.app.zip`
- Checksum asset: `MACKAN-0.1.0-preview.1-macOS.app.zip.sha256`
- Forum title: `[Mac] MACKAN v0.1.0-preview.1 - native macOS CKAN mod manager`

Use the exact versioned tag in forum posts, release notes, and bug reports.
Keep `mackan-preview` only as a moving compatibility link for the latest preview
channel.

## Version Bumps

- `preview.N`: new build with fixes in the same small preview scope.
- `0.x.0-preview.1`: broader preview milestone or meaningful workflow expansion.
- `1.0.0`: signed/notarized production release after release gates pass.

The bundled CKAN Core version should be mentioned separately when useful, for
example:

```text
MACKAN preview: v0.1.0-preview.1
Bundled CKAN Core: v1.36.5.x
```

## Publishing

Run the `Publish MACKAN preview app` workflow manually with:

```text
app_version: 0.1.0-preview.1
tag_name: v0.1.0-preview.1
update_preview_channel: true
preview_channel_tag: mackan-preview
```

This creates or updates the versioned prerelease and refreshes the moving
`mackan-preview` channel to the same commit and archive.

# Assets

This folder contains both upstream CKAN assets and MACKAN-specific preview
branding assets.

## Upstream CKAN Assets

The original CKAN logo assets are kept for upstream compatibility:

- `ckan.ico`
- `ckan.icns`
- `ckan-*.png`

The CKAN logo is MIT licensed by Felger. The historical KSP rocket branding note
from upstream CKAN is preserved for those original assets.

To rebuild the upstream CKAN `.ico` file from its PNG inputs:

```bash
icotool -c -o ckan.ico ckan-*.png
```

## MACKAN Assets

The active MACKAN app icon assets are:

- `mackan.png`
- `mackan.ico`
- `mackan.icns`

The `.NET` application icon references use `mackan.ico`. The native macOS
bundle generator copies `mackan.icns` into `Contents/Resources/MACKAN.icns`.

The MACKAN icon is a generated raster concept selected for the MACKAN preview
branding. It intentionally avoids official Kerbal Space Program logos or text.

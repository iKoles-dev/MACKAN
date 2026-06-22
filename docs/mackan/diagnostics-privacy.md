# Diagnostics And Privacy

MACKAN diagnostics are meant to make preview bugs reproducible without exposing
private user data.

## Before Posting Publicly

Review diagnostics, logs, screenshots, and exported files before attaching them
to a public GitHub issue or forum post.

Remove or shorten:

- Full personal paths, especially paths containing usernames.
- Auth tokens, API keys, cookies, or session values.
- Private mod archives or manually downloaded files.
- Email addresses or account identifiers.
- Local machine names, if you do not want them public.
- Large logs unrelated to the failure.

## Usually Useful To Keep

Keep enough context to reproduce the issue:

- MACKAN build, release tag, commit, or workflow run.
- macOS version and CPU architecture.
- KSP version and install source.
- Sanitized path shape, such as `~/Games/KSP` or `/Volumes/External/KSP`.
- Module identifiers and repository names.
- Visible error text.
- A short relevant log excerpt around the failure.

## Screenshots

Screenshots are useful when they show:

- Gatekeeper messages.
- The selected instance.
- Repository refresh state.
- Module detail or change preview state.
- The exact visible error.

Avoid screenshots that reveal unrelated apps, private folders, credentials,
desktop notifications, personal files, or full local paths.

## Diagnostics Bundles

If MACKAN offers a diagnostics bundle, treat it as potentially sensitive until
reviewed. Prefer sharing a redacted excerpt publicly and keep full bundles for a
trusted private channel.

When in doubt, post the build, macOS version, short reproduction steps, and
visible error text first. Maintainers can ask for narrower diagnostics if needed.

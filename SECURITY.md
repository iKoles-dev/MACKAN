# Security Policy

MACKAN is currently a public-preview fork direction. Please do not use GitHub
issues for sensitive vulnerability details.

## Reporting Security Issues

If the issue affects upstream CKAN behavior, report it through the upstream CKAN
project's preferred private security channel when available:

https://github.com/KSP-CKAN/CKAN

If the issue is specific to MACKAN native macOS code, sidecar contracts,
packaging, Keychain token handling, or release artifacts, contact the repository
maintainer privately before publishing details. Do not include secrets,
authentication tokens, private KSP install paths, or personal diagnostics in a
public issue.

## Current Security Scope

Security-sensitive MACKAN areas include:

- macOS Keychain-backed auth-token handling.
- JSON-RPC sidecar request/response contracts.
- File import/export workflows.
- Registry lock recovery and stale lock removal.
- Signed/notarized release artifact generation and provenance.

Unsigned local development builds are not considered production release
artifacts.

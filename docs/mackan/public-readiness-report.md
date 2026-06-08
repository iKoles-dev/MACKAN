# MACKAN Public Readiness Report

Generated on 2026-06-07 for the public-preview repository cleanup.

## Status

MACKAN is in a source-preview state, not a finished public binary release.
The public tree now has:

- MACKAN-first root README positioning.
- Public docs for architecture, product scope, parity, roadmap, release
  checklist, and release runbook.
- MACKAN icon assets in PNG, ICO, and ICNS formats.
- Legal and community basics: NOTICE, CONTRIBUTING, SECURITY, and asset
  attribution notes.
- Guards on upstream-only CKAN release/deploy/signing workflows so the fork
  does not accidentally publish upstream CKAN artifacts.
- A separate MACKAN release workflow for signed, notarized DMG handoff once
  Apple Developer ID and notary secrets are configured.
- `.gitignore` rules for local evidence packets, sprint notes, generated icon
  explorations, superpowers planning snapshots, and macOS metadata.

## Verification Commands

These commands are the current public-readiness gate. Run them from the
repository root before publishing or creating a public-preview PR.

```sh
git status --short
git ls-files --others --exclude-standard | sort
find . -name '.DS_Store' -not -path './.git/*' -exec rm -f {} +
find . -name '.DS_Store' -not -path './.git/*' -print
rg -n --hidden -S -g '!.git/**' -g '!_build/**' -g '!bin/**' -g '!build/**' -g '!docs/superpowers/**' -g '!docs/mackan/public-readiness-report.md' '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|sk-[A-Za-z0-9_-]{20,}|BEGIN [A-Z ]*PRIVATE KEY|OPENAI_API_KEY|AWS_SECRET_ACCESS_KEY|NUGET_API_KEY|DEBIAN_PRIVATE_KEY|SIGNPATH_API_TOKEN)' || true
LOCAL_USER="$(id -un)"
TMP_ROOT='/private/'tmp
PUBLIC_DOCS=(
  README.md
  CONTRIBUTING.md
  SECURITY.md
  NOTICE.md
  assets/README.md
  docs/mackan/README.md
  docs/mackan/architecture.md
  docs/mackan/parity-matrix.md
  docs/mackan/product-spec.md
  docs/mackan/release-execution-checklist.md
  docs/mackan/release-roadmap.md
  docs/mackan/v1-release-execution-runbook.md
  docs/mackan/public-readiness-report.md
)
rg -n --hidden -S "(/Users/${LOCAL_USER}|${TMP_ROOT})" "${PUBLIC_DOCS[@]}" .github/workflows/*.yml || true
git ls-files --others --exclude-standard | rg '^(assets/icon-variants|docs/mackan/(release-readiness-evidence|full-ui-function-audit|brainstorming|sprint-|implementation-candidate-backlog|next-iteration-plan|parity-focus-initial)|docs/superpowers/(plans|specs)/.*mackan)' || true
rg -n "github.repository == 'KSP-CKAN/CKAN'" .github/workflows/bounce.yml .github/workflows/deploy.yml .github/workflows/release.yml .github/workflows/sign.yml .github/workflows/smoke.yml
test -f assets/mackan.png && test -f assets/mackan.ico && test -f assets/mackan.icns
```

Expected result:

- `git status --short` still shows implementation work unless a dedicated
  public-preview commit has been staged or committed.
- Untracked public candidates should be limited to MACKAN docs, community files,
  icon assets, the MACKAN release workflow, and current implementation files.
- `.DS_Store` output should be empty.
- Secret scan findings should be limited to GitHub Actions secret placeholders,
  not literal credentials or private keys.
- Private-path scan should not report local machine paths in public docs.
- Local evidence and sprint files should not appear as unignored public
  candidates.
- Upstream-only workflows should contain `github.repository == 'KSP-CKAN/CKAN'`
  guards.
- MACKAN icon assets should exist.

## Commit Grouping

For a clean public-preview history, split the current work into at least these
groups:

- Public repository hygiene: README, NOTICE, CONTRIBUTING, SECURITY, assets
  README, MACKAN icons, `.gitignore`, and `docs/mackan/*`.
- Workflow safety: upstream-only workflow guards and the MACKAN release workflow.
- MACKAN application implementation: SwiftUI app, MACKANKit, sidecar service,
  tests, packaging scripts, and related project files.
- CKAN Core integration changes: any Core, GUI, Cmdline, ConsoleUI, Netkan,
  AutoUpdate, and test-project changes needed by the native app.

Do not mix local evidence packets, generated screenshots, sprint notes,
machine-specific logs, or design sandbox files into the public-preview commit.

## Remaining Public Release Gates

Before advertising a binary release, prove:

- Developer ID signing works on a clean macOS runner.
- Hardened runtime is enabled for the app bundle.
- Notarization succeeds and the DMG is stapled.
- `spctl`, `codesign`, checksum, provenance, launch-smoke, and clean-install
  checks pass against the final DMG.
- The release notes clearly state preview limitations and supported CKAN/KSP
  workflows.

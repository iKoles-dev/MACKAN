# MACKAN Product Spec

## Goal

MACKAN is a native macOS GUI for CKAN with feature parity equal to or greater
than the Windows CKAN GUI, while preserving CKAN Core behavior and metadata
compatibility. Users should be able to install, update, remove, inspect, repair,
export, import, and maintain KSP and KSP2 modded instances without opening
Terminal.

## Product Principles

- Native first: SwiftUI/AppKit controls, native menus, sheets, toolbar,
  sidebars, Finder integration, notifications, accessibility, dark mode, and
  keyboard shortcuts.
- CKAN Core remains authoritative: no reimplementation of dependency solving,
  registry transactions, metadata validation, module installation, cache logic,
  or repository semantics in Swift.
- Parity is a gate: a release cannot be called 1.0 if a Windows GUI workflow has
  no equivalent or intentional better replacement in MACKAN.
- Safe operations: every install/remove/upgrade is previewed as a change set,
  destructive operations are explicit, registry lock handling is visible, and
  failed operations leave recoverable state.
- Power-user friendly: all advanced CKAN workflows are reachable from menus,
  command palette, or contextual actions, not hidden behind a simplified UI.

## Main Window

MACKAN uses a three-pane macOS layout:

- Sidebar: game instances, saved searches, labels, update state, cache status,
  and maintenance shortcuts.
- Content pane: searchable/sortable mod table with configurable visible columns
  and status badges for installed, upgradable, incompatible, replaceable,
  cached, auto-installed, held, and manually detected modules.
- Inspector: selected mod details with tabs for Overview, Relationships,
  Versions, Contents, Resources, and History.

The toolbar contains Refresh, Apply Changes, Upgrade All, Install from File,
Import Downloads, Launch Game, Open Game Folder, and Settings. Menu commands
mirror the Windows GUI File, Settings, and Help menus using native macOS menu
placement.

## Required Workflows

1. First launch detects existing CKAN configuration and known game instances,
   including Steam installs on macOS.
2. User can add, clone, rename, remove, fake, and select default game instances.
3. User can refresh repositories and inspect update summaries.
4. User can search, filter, sort, and inspect the full module catalog.
5. User can build a change set by installing, removing, replacing, upgrading,
   marking, and holding modules.
6. User sees dependency, recommendation, suggestion, provider, and conflict
   choices before applying changes.
7. User can apply changes with download/install progress, cancellation,
   resumable downloads, and clear error recovery.
8. User can manage repositories, compatible game versions, stability tolerance,
   preferred hosts, install filters, auth tokens, cache path, language, and
   update preferences.
9. User can import manually downloaded archives, install `.ckan` files, export
   mod lists and modpacks, view install history, view unmanaged files, view
   play time, view download statistics, repair registry/cache state, clean cache,
   and deduplicate installed files.
10. User can access CKAN help, game support links, issue reporting links, and
    about/update information without leaving app context unexpectedly.

## Release Criteria

MACKAN reaches release state only when all of these are true:

- Feature parity matrix has no missing Windows GUI workflows.
- Core bridge tests, Swift model tests, UI smoke tests, and packaging tests pass.
- Universal macOS app bundle is self-contained for arm64 and x86_64. Local
  universal DMG generation exists for engineering checks; release acceptance
  still requires Developer ID signing and notarization evidence.
- App is code-signed, notarized, and distributed as DMG or ZIP with a clean
  first-run experience. Local DMG generation is available for engineering
  checks, but it is not a public-release substitute until Developer ID signing,
  notarization, and stapling are wired and verified.
- The app does not open Terminal for normal GUI use.
- Existing CKAN user data migrates without data loss.
- Registry lock conflicts, permission failures, network failures, and failed
  installs have tested recovery paths.
- Known critical/high dependency vulnerabilities are either remediated or
  explicitly risk-accepted with compensating controls before public release.
  Current net10 MACKAN verification has no vulnerable NuGet packages according
  to `dotnet list package --vulnerable`; this check remains a release gate.

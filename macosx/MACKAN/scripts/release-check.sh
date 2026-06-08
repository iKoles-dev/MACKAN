#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$HOME/Library/Caches/MACKAN/build}"
APP_NAME="${APP_NAME:-MACKAN}"
APP_VERSION="${APP_VERSION:-}"
APP_PATH="${APP_PATH:-$BUILD_ROOT/$APP_NAME.app}"
DMG_PATH="${DMG_PATH:-}"
DRY_RUN=false
SKIP_PACKAGE="${MACKAN_RELEASE_CHECK_SKIP_PACKAGE:-false}"
SKIP_LAUNCH="${MACKAN_RELEASE_CHECK_SKIP_LAUNCH:-false}"
CLEAN_SMOKE="${MACKAN_RELEASE_CHECK_CLEAN_SMOKE:-false}"
REQUIRE_STRICT_READINESS="${MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS:-false}"
REQUIRE_RELEASE_CREDENTIALS="${MACKAN_RELEASE_CHECK_REQUIRE_RELEASE_CREDENTIALS:-false}"
TEST_DOTNET_RETRY="${MACKAN_RELEASE_CHECK_TEST_DOTNET_RETRY:-false}"

usage() {
    cat <<USAGE
Usage: release-check.sh [--dry-run] [--skip-package] [--skip-launch]

Runs the local MACKAN release gate that does not require Developer ID
credentials. This verifies Swift tests, .NET MACKAN tests, NuGet vulnerability
audits, packaging helper scripts, universal DMG packaging, bundle validation,
and optional launch smoke coverage (app launch + DMG mount launch when a DMG is
produced).

Environment:
  APP_NAME                           App bundle name. Default: MACKAN
  APP_VERSION                        Bundle version. If set, reused for path and smoke checks.
                                   If unset, version is inferred from APP_PATH's Info.plist or 0.1.0.
  APP_PATH                           App bundle path. Default: BUILD_ROOT/APP_NAME.app
  BUILD_ROOT                         Build output root. Default: ~/Library/Caches/MACKAN/build
  DMG_PATH                           DMG path. Default: BUILD_ROOT/APP_NAME-<APP_VERSION>-universal.dmg
  MACKAN_RELEASE_CHECK_SKIP_PACKAGE  true/false; skip universal package build.
  MACKAN_RELEASE_CHECK_SKIP_LAUNCH   true/false; skip launch smoke checks.
  MACKAN_RELEASE_CHECK_CLEAN_SMOKE  true/false; run clean-install launch smoke from generated DMG.
  MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS true/false; enforce strict parity/doc readiness gate.
  MACKAN_RELEASE_CHECK_REQUIRE_RELEASE_CREDENTIALS true/false; enforce Developer ID/notary credential readiness.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-package)
            SKIP_PACKAGE=true
            shift
            ;;
        --skip-launch)
            SKIP_LAUNCH=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$SKIP_PACKAGE" in
    true|false) ;;
    *)
        echo "MACKAN_RELEASE_CHECK_SKIP_PACKAGE must be true or false." >&2
        exit 2
        ;;
esac

case "$SKIP_LAUNCH" in
    true|false) ;;
    *)
        echo "MACKAN_RELEASE_CHECK_SKIP_LAUNCH must be true or false." >&2
        exit 2
        ;;
esac

case "$CLEAN_SMOKE" in
    true|false) ;;
    *)
        echo "MACKAN_RELEASE_CHECK_CLEAN_SMOKE must be true or false." >&2
        exit 2
        ;;
esac

case "$REQUIRE_STRICT_READINESS" in
    true|false) ;;
    *)
        echo "MACKAN_RELEASE_CHECK_REQUIRE_STRICT_READINESS must be true or false." >&2
        exit 2
        ;;
esac

case "$REQUIRE_RELEASE_CREDENTIALS" in
    true|false) ;;
    *)
        echo "MACKAN_RELEASE_CHECK_REQUIRE_RELEASE_CREDENTIALS must be true or false." >&2
        exit 2
        ;;
esac

if [[ "$REQUIRE_RELEASE_CREDENTIALS" == "true" ]]; then
    REQUIRE_STRICT_READINESS=true
fi

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

resolve_app_version() {
    local info_plist="$APP_PATH/Contents/Info.plist"
    local short_version=""
    local bundle_version=""

    if [[ -z "$APP_VERSION" && -f "$info_plist" ]]; then
        short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist" 2>/dev/null || true)"
        bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist" 2>/dev/null || true)"
        APP_VERSION="${short_version:-$bundle_version}"
    fi

    APP_VERSION="${APP_VERSION:-0.1.0}"
    DMG_PATH="${DMG_PATH:-$BUILD_ROOT/$APP_NAME-$APP_VERSION-universal.dmg}"
}

resolve_app_version

run_command() {
    printf '+ '
    quote_command "$@"

    if [[ "$DRY_RUN" == "false" ]]; then
        "$@"
    fi
}

run_dotnet_with_retry() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '+ run_dotnet_with_retry '
        quote_command "$@"
        printf '+ '
        quote_command env DOTNET_ROLL_FORWARD=Major dotnet "$@"
        return
    fi

    printf '+ '
    quote_command env DOTNET_ROLL_FORWARD=Major dotnet "$@"
    set +e
    env DOTNET_ROLL_FORWARD=Major dotnet "$@"
    exit_code=$?
    set -e
    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    fi

    if [[ "$exit_code" -ne 139 ]]; then
        return "$exit_code"
    fi

    echo "dotnet exited with 139 (SIGSEGV); retrying once: dotnet $*" >&2
    printf '+ '
    quote_command env DOTNET_ROLL_FORWARD=Major dotnet "$@"
    env DOTNET_ROLL_FORWARD=Major dotnet "$@"
}

if [[ "$TEST_DOTNET_RETRY" == "true" ]]; then
    run_dotnet_with_retry --version
    exit $?
fi

cd "$REPO_ROOT"

run_command swift test --package-path "$PACKAGE_DIR"

run_dotnet_with_retry list Tests/Tests.csproj package --vulnerable --include-transitive
run_dotnet_with_retry list MACKAN.Service/MACKAN.Service.csproj package --vulnerable --include-transitive
run_dotnet_with_retry list Core/CKAN-core.csproj package --vulnerable --include-transitive -f net10.0
run_dotnet_with_retry test Tests/Tests.csproj -f net10.0 --filter FullyQualifiedName~Tests.MACKAN

run_command "$SCRIPT_DIR/test-app-icon.sh"
run_command "$SCRIPT_DIR/test-verify-app-bundle.sh"
run_command "$SCRIPT_DIR/test-package-dmg.sh"
run_command "$SCRIPT_DIR/test-build-workflow.sh"
run_command env APP_VERSION="$APP_VERSION" "$SCRIPT_DIR/test-release-dmg.sh"
run_command "$SCRIPT_DIR/test-generate-release-provenance.sh"
run_command "$SCRIPT_DIR/test-verify-release-artifact.sh"
run_command "$SCRIPT_DIR/test-verify-release-checksums.sh"
run_command "$SCRIPT_DIR/test-generate-release-summary.sh"
run_command "$SCRIPT_DIR/test-verify-release-summary.sh"
run_command "$SCRIPT_DIR/test-verify-public-release-handoff.sh"
run_command "$SCRIPT_DIR/test-verify-release-log.sh"
run_command "$SCRIPT_DIR/test-verify-app-launch.sh"
run_command "$SCRIPT_DIR/test-run-ui-ux-audit.sh"
run_command "$SCRIPT_DIR/test-verify-ui-ux-audit-evidence.sh"
run_command git diff --check
if [[ "$REQUIRE_STRICT_READINESS" == "true" || "$REQUIRE_RELEASE_CREDENTIALS" == "true" ]]; then
    readiness_args=("$SCRIPT_DIR/release-readiness.sh")
    if [[ "$REQUIRE_STRICT_READINESS" == "true" ]]; then
        readiness_args+=(--strict)
    fi
    if [[ "$REQUIRE_RELEASE_CREDENTIALS" == "true" ]]; then
        readiness_args+=(--require-release-credentials)
    fi
    run_command "${readiness_args[@]}"
else
    run_command "$SCRIPT_DIR/test-release-readiness.sh"
fi
run_command "$SCRIPT_DIR/test-accessibility-smoke.sh"

if [[ "$SKIP_PACKAGE" == "false" ]]; then
    run_command env APP_VERSION="$APP_VERSION" APP_PATH="$APP_PATH" "$SCRIPT_DIR/package-dmg.sh" --universal
    run_command "$SCRIPT_DIR/verify-app-bundle.sh" --mode universal --require-icon --require-version "$APP_VERSION" "$APP_PATH"
    run_command hdiutil verify "$DMG_PATH"
    run_command env APP_VERSION="$APP_VERSION" "$SCRIPT_DIR/generate-release-provenance.sh" --app "$APP_PATH" --dmg "$DMG_PATH"
    run_command "$SCRIPT_DIR/verify-release-artifact.sh" --app "$APP_PATH" --dmg "$DMG_PATH" --require-version "$APP_VERSION"
fi

if [[ "$SKIP_LAUNCH" == "false" ]]; then
    run_command "$SCRIPT_DIR/verify-app-launch.sh" --timeout 25 "$APP_PATH"
    if [[ "$SKIP_PACKAGE" == "false" ]]; then
        run_command "$SCRIPT_DIR/test-dmg-launch-smoke.sh" --timeout 25 --app-name "$APP_NAME" --require-version "$APP_VERSION" "$DMG_PATH"
        if [[ "$CLEAN_SMOKE" == "true" ]]; then
            run_command "$SCRIPT_DIR/test-clean-install-smoke.sh" --timeout 25 --app-name "$APP_NAME" --require-version "$APP_VERSION" "$DMG_PATH"
        fi
    fi
fi

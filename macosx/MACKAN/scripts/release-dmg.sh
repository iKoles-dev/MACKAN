#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_APP_SCRIPT="$SCRIPT_DIR/build-dev-app.sh"
PACKAGE_DMG_SCRIPT="$SCRIPT_DIR/package-dmg.sh"
VERIFY_APP_SCRIPT="$SCRIPT_DIR/verify-app-bundle.sh"
PROVENANCE_SCRIPT="$SCRIPT_DIR/generate-release-provenance.sh"
VERIFY_ARTIFACT_SCRIPT="$SCRIPT_DIR/verify-release-artifact.sh"
SUMMARY_SCRIPT="$SCRIPT_DIR/generate-release-summary.sh"
VERIFY_HANDOFF_SCRIPT="$SCRIPT_DIR/verify-public-release-handoff.sh"

APP_NAME="${APP_NAME:-MACKAN}"
APP_VERSION="${APP_VERSION:-}"
DEFAULT_BUILD_ROOT="${HOME}/Library/Caches/MACKAN/build"
BUILD_ROOT="${BUILD_ROOT:-$DEFAULT_BUILD_ROOT}"
APP_PATH="${APP_PATH:-$BUILD_ROOT/$APP_NAME.app}"
DMG_PATH="${DMG_PATH:-}"
BUILD_APP="${MACKAN_BUILD_APP:-true}"
UNIVERSAL="${MACKAN_UNIVERSAL:-true}"
IDENTITY="${MACKAN_DEVELOPER_ID_APPLICATION:-}"
KEYCHAIN_PROFILE="${MACKAN_NOTARY_KEYCHAIN_PROFILE:-}"
SIGNING_KEYCHAIN_PATH="${MACKAN_SIGNING_KEYCHAIN_PATH:-}"
NOTARIZE="${MACKAN_NOTARIZE:-true}"
STAPLE="${MACKAN_STAPLE:-true}"
NOTARY_TIMEOUT="${MACKAN_NOTARY_TIMEOUT:-30m}"
RUN_SMOKE="${MACKAN_RELEASE_DMG_SMOKE:-true}"
CLEAN_SMOKE="${MACKAN_RELEASE_DMG_CLEAN_SMOKE:-true}"
GENERATE_PROVENANCE="${MACKAN_RELEASE_PROVENANCE:-true}"
PROVENANCE_PATH="${MACKAN_RELEASE_PROVENANCE_PATH:-}"
DRY_RUN=false

usage() {
    cat <<USAGE
Usage: release-dmg.sh [--app PATH] [--dmg PATH] [--identity NAME] [--keychain-profile NAME] [--notary-timeout DURATION] [--no-build] [--single-arch] [--no-notarize] [--no-staple] [--smoke] [--no-smoke] [--clean-smoke] [--no-clean-smoke] [--provenance PATH] [--no-provenance] [--dry-run]

Builds, Developer ID signs, packages, notarizes, and staples a MACKAN DMG.

Environment:
  APP_NAME                         App bundle name. Default: MACKAN
  APP_VERSION                      Bundle/DMG version. If set, reused for bundle checks and default DMG naming.
                                   If unset, version is inferred from APP_PATH Info.plist or falls back to 0.1.0.
                                   Must be SemVer-like, for example 1.0.0 or 1.0.0-rc.1.
  BUILD_ROOT                       Build output root. Default: ~/Library/Caches/MACKAN/build
  MACKAN_BUILD_APP                 true/false; run build-dev-app.sh before signing. Default: true
  MACKAN_UNIVERSAL                 true/false; build and verify universal layout. Default: true
  MACKAN_DEVELOPER_ID_APPLICATION  Developer ID Application signing identity.
  MACKAN_NOTARY_KEYCHAIN_PROFILE   notarytool keychain profile name.
  MACKAN_SIGNING_KEYCHAIN_PATH      Optional keychain path for notarytool credential lookup.
  MACKAN_NOTARY_TIMEOUT            notarytool wait timeout. Default: 30m
  MACKAN_NOTARIZE                  true/false; submit to Apple notary service. Default: true
  MACKAN_STAPLE                    true/false; staple and validate notary ticket. Default: true
  MACKAN_RELEASE_DMG_SMOKE         true/false; run launch smoke checks against generated DMG. Default: true
  MACKAN_RELEASE_DMG_CLEAN_SMOKE  true/false; run clean-install smoke for launch checks from DMG. Default: true
  MACKAN_RELEASE_PROVENANCE        true/false; write a release provenance JSON manifest next to the DMG. Default: true
  MACKAN_RELEASE_PROVENANCE_PATH   Optional explicit provenance manifest output path.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

format_arg() {
    local previous="$1"
    local value="$2"

    case "$value" in
        --*)
            printf '%s' "$value"
            ;;
        *)
            case "$previous" in
                --timeout)
                    printf '%s' "$value"
                    ;;
                *)
                    if [[ "$value" == /* || "$previous" == "--keychain-profile" || "$value" == *" "* ]]; then
                        shell_quote "$value"
                    else
                        printf '%s' "$value"
                    fi
                    ;;
            esac
            ;;
    esac
}

display_command() {
    local first=true
    local previous=""

    for arg in "$@"; do
        if [[ "$first" == "true" ]]; then
            printf '%s' "$arg"
            first=false
        else
            printf ' '
            format_arg "$previous" "$arg"
        fi
        previous="$arg"
    done
    printf '\n'
}

run_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        display_command "$@"
    else
        "$@"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$2"
            shift 2
            ;;
        --dmg|--output)
            DMG_PATH="$2"
            shift 2
            ;;
        --identity)
            IDENTITY="$2"
            shift 2
            ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        --notary-timeout)
            NOTARY_TIMEOUT="$2"
            shift 2
            ;;
        --no-build)
            BUILD_APP=false
            shift
            ;;
        --single-arch)
            UNIVERSAL=false
            shift
            ;;
        --universal)
            UNIVERSAL=true
            shift
            ;;
        --no-notarize)
            NOTARIZE=false
            STAPLE=false
            shift
            ;;
        --no-staple)
            STAPLE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --smoke)
            RUN_SMOKE=true
            shift
            ;;
        --no-smoke)
            RUN_SMOKE=false
            shift
            ;;
        --clean-smoke)
            CLEAN_SMOKE=true
            shift
            ;;
        --no-clean-smoke)
            CLEAN_SMOKE=false
            shift
            ;;
        --provenance)
            GENERATE_PROVENANCE=true
            PROVENANCE_PATH="$2"
            shift 2
            ;;
        --no-provenance)
            GENERATE_PROVENANCE=false
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
    if [[ -z "$DMG_PATH" ]]; then
        DMG_PATH="$BUILD_ROOT/$APP_NAME-$APP_VERSION-release.dmg"
    fi
}

validate_app_version() {
    if [[ -z "$APP_VERSION" || ! "$APP_VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
        fail "APP_VERSION must be a non-empty SemVer-like version such as 1.0.0 or 1.0.0-rc.1."
    fi
}

validate_notary_timeout() {
    if [[ -z "$NOTARY_TIMEOUT" || ! "$NOTARY_TIMEOUT" =~ ^[1-9][0-9]*[smh]$ ]]; then
        fail "MACKAN_NOTARY_TIMEOUT must be a notarytool duration such as 30m, 120s, or 1h."
    fi
}

validate_release_credentials() {
    local identities_output=""
    local identity_args=(find-identity -v -p codesigning)

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if [[ -n "${MACKAN_RELEASE_SECURITY_IDENTITIES_OUTPUT:-}" ]]; then
        identities_output="$MACKAN_RELEASE_SECURITY_IDENTITIES_OUTPUT"
    else
        if [[ -n "$SIGNING_KEYCHAIN_PATH" ]]; then
            identity_args+=("$SIGNING_KEYCHAIN_PATH")
        fi
        identities_output="$(security "${identity_args[@]}" 2>/dev/null || true)"
    fi

    if ! printf '%s\n' "$identities_output" | grep -F -- "$IDENTITY" >/dev/null 2>&1; then
        fail "Developer ID Application identity not found: $IDENTITY"
    fi

    if [[ "$NOTARIZE" == "true" ]]; then
        case "${MACKAN_RELEASE_NOTARY_PROFILE_VALIDATED:-}" in
            true)
                ;;
            false)
                fail "notarytool keychain profile did not validate: $KEYCHAIN_PROFILE"
                ;;
            *)
                notary_history_args=(notarytool history --keychain-profile "$KEYCHAIN_PROFILE")
                if [[ -n "$SIGNING_KEYCHAIN_PATH" ]]; then
                    notary_history_args+=(--keychain "$SIGNING_KEYCHAIN_PATH")
                fi
                notary_history_args+=(--output-format json --no-progress)
                if ! xcrun "${notary_history_args[@]}" >/dev/null 2>&1; then
                    fail "notarytool keychain profile did not validate: $KEYCHAIN_PROFILE"
                fi
                ;;
        esac
    fi
}

case "$BUILD_APP" in
    true|false)
        ;;
    *)
        fail "MACKAN_BUILD_APP must be true or false."
        ;;
esac

case "$UNIVERSAL" in
    true|false)
        ;;
    *)
        fail "MACKAN_UNIVERSAL must be true or false."
        ;;
esac

case "$NOTARIZE" in
    true|false)
        ;;
    *)
        fail "MACKAN_NOTARIZE must be true or false."
        ;;
esac

case "$STAPLE" in
    true|false)
        ;;
    *)
        fail "MACKAN_STAPLE must be true or false."
        ;;
esac

case "$RUN_SMOKE" in
    true|false)
        ;;
    *)
        fail "MACKAN_RELEASE_DMG_SMOKE must be true or false."
        ;;
esac

case "$CLEAN_SMOKE" in
    true|false)
        ;;
    *)
        fail "MACKAN_RELEASE_DMG_CLEAN_SMOKE must be true or false."
        ;;
esac

case "$GENERATE_PROVENANCE" in
    true|false)
        ;;
    *)
        fail "MACKAN_RELEASE_PROVENANCE must be true or false."
        ;;
esac

if [[ "$GENERATE_PROVENANCE" == "true" && ( "$NOTARIZE" != "true" || "$STAPLE" != "true" ) ]]; then
    fail "Public release provenance requires notarization and stapling. Use --no-provenance for local unsigned-notary release experiments."
fi

if [[ "$GENERATE_PROVENANCE" == "true" && ( "$RUN_SMOKE" != "true" || "$CLEAN_SMOKE" != "true" ) ]]; then
    fail "Public release provenance requires DMG launch smoke and clean-install smoke. Use --no-provenance for local smoke-skipping experiments."
fi

[[ -n "$IDENTITY" ]] || fail "Developer ID Application identity is required. Set MACKAN_DEVELOPER_ID_APPLICATION or pass --identity."

if [[ "$NOTARIZE" == "true" ]]; then
    [[ -n "$KEYCHAIN_PROFILE" ]] || fail "notarytool keychain profile is required. Set MACKAN_NOTARY_KEYCHAIN_PROFILE or pass --keychain-profile."
    validate_notary_timeout
fi

validate_release_credentials

if [[ "$BUILD_APP" == "true" ]]; then
    build_args=("$BUILD_APP_SCRIPT")
    if [[ "$UNIVERSAL" == "true" ]]; then
        build_args+=(--universal)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        run_command "${build_args[@]}"
    else
        APP_PATH="$("${build_args[@]}")"
    fi
else
    [[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
    [[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"
fi

resolve_app_version
validate_app_version

run_command codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_PATH"

verify_mode="single"
package_args=("$PACKAGE_DMG_SCRIPT" --app "$APP_PATH" --output "$DMG_PATH" --no-build)
if [[ "$UNIVERSAL" == "true" ]]; then
    verify_mode="universal"
    package_args+=(--universal)
fi

run_command "$VERIFY_APP_SCRIPT" --mode "$verify_mode" --require-icon --require-version "$APP_VERSION" "$APP_PATH"
run_command "${package_args[@]}"
run_command codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
run_command codesign --verify --strict "$DMG_PATH"

notary_status=""
notary_id=""
notary_json_path="$DMG_PATH.notary.json"

if [[ "$NOTARIZE" == "true" ]]; then
    notary_submit_args=(notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE")
    if [[ -n "$SIGNING_KEYCHAIN_PATH" ]]; then
        notary_submit_args+=(--keychain "$SIGNING_KEYCHAIN_PATH")
    fi
    notary_submit_args+=(--wait --timeout "$NOTARY_TIMEOUT" --output-format json)

    if [[ "$DRY_RUN" == "true" ]]; then
        run_command xcrun "${notary_submit_args[@]}"
    else
        xcrun "${notary_submit_args[@]}" > "$notary_json_path"

        notary_status="$(/usr/bin/python3 - "$notary_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload.get("status", ""))
PY
)"
        notary_id="$(/usr/bin/python3 - "$notary_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload.get("id", ""))
PY
)"

        [[ "$notary_status" == "Accepted" ]] || fail "notarytool submit did not return Accepted status: $notary_status"
    fi
fi

if [[ "$STAPLE" == "true" ]]; then
    run_command xcrun stapler staple "$DMG_PATH"
    run_command xcrun stapler validate "$DMG_PATH"
fi

if [[ "$RUN_SMOKE" == "true" ]]; then
    run_command "$SCRIPT_DIR/test-dmg-launch-smoke.sh" --timeout 25 --app-name "$APP_NAME" --require-version "$APP_VERSION" "$DMG_PATH"

    if [[ "$CLEAN_SMOKE" == "true" ]]; then
        run_command "$SCRIPT_DIR/test-clean-install-smoke.sh" --timeout 25 --app-name "$APP_NAME" --require-version "$APP_VERSION" "$DMG_PATH"
    fi
fi

if [[ "$GENERATE_PROVENANCE" == "true" ]]; then
    resolved_provenance_path="${PROVENANCE_PATH:-$DMG_PATH.provenance.json}"
    checksums_path="$DMG_PATH.sha256"
    summary_path="$DMG_PATH.release-summary.json"
    provenance_args=("$PROVENANCE_SCRIPT" --app "$APP_PATH" --dmg "$DMG_PATH")
    if [[ -n "$PROVENANCE_PATH" ]]; then
        provenance_args+=(--output "$PROVENANCE_PATH")
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        run_command "${provenance_args[@]}"
    else
        MACKAN_RELEASE_NOTARIZATION_STATUS="$notary_status" \
            MACKAN_RELEASE_NOTARIZATION_ID="$notary_id" \
            MACKAN_RELEASE_NOTARY_JSON_PATH="$notary_json_path" \
            "${provenance_args[@]}"
    fi

    verify_artifact_args=("$VERIFY_ARTIFACT_SCRIPT" --app "$APP_PATH" --dmg "$DMG_PATH" --require-version "$APP_VERSION" --require-public-release)
    if [[ -n "$PROVENANCE_PATH" ]]; then
        verify_artifact_args+=(--provenance "$PROVENANCE_PATH")
    fi
    run_command "${verify_artifact_args[@]}"

    if [[ "$DRY_RUN" == "true" ]]; then
        run_command shasum -a 256 "$DMG_PATH" "$resolved_provenance_path" "$notary_json_path"
    else
        shasum -a 256 "$DMG_PATH" "$resolved_provenance_path" "$notary_json_path" > "$checksums_path"
    fi

    summary_args=(
        "$SUMMARY_SCRIPT"
        --output "$summary_path"
        --version "$APP_VERSION"
        --app "$APP_PATH"
        --dmg "$DMG_PATH"
        --provenance "$resolved_provenance_path"
        --notary-json "$notary_json_path"
        --checksums "$checksums_path"
    )
    run_command "${summary_args[@]}"

    handoff_args=(
        "$VERIFY_HANDOFF_SCRIPT"
        --app "$APP_PATH"
        --dmg "$DMG_PATH"
        --provenance "$resolved_provenance_path"
        --notary-json "$notary_json_path"
        --checksums "$checksums_path"
        --summary "$summary_path"
        --require-version "$APP_VERSION"
    )
    run_command "${handoff_args[@]}"
fi

echo "$DMG_PATH"

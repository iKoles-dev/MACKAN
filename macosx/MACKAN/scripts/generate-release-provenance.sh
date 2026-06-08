#!/usr/bin/env bash
set -euo pipefail

APP_PATH=""
DMG_PATH=""
OUTPUT_PATH=""
APP_NAME="${APP_NAME:-MACKAN}"
APP_VERSION="${APP_VERSION:-}"

usage() {
    cat <<USAGE
Usage: generate-release-provenance.sh --app PATH --dmg PATH [--output PATH]

Writes a machine-readable release provenance manifest for a MACKAN app bundle
and DMG artifact.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

json_string() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '"%s"' "$value"
}

json_bool() {
    if [[ "$1" == "true" ]]; then
        printf 'true'
    else
        printf 'false'
    fi
}

file_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
    stat -f '%z' "$1"
}

plist_value() {
    local key="$1"
    local plist="$APP_PATH/Contents/Info.plist"

    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

codesign_details_for() {
    local path="$1"
    codesign -d --verbose=4 "$path" 2>&1 || true
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$2"
            shift 2
            ;;
        --dmg)
            DMG_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="$2"
            shift 2
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

[[ -n "$APP_PATH" ]] || fail "App bundle path is required."
[[ -n "$DMG_PATH" ]] || fail "DMG path is required."
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ -f "$DMG_PATH" ]] || fail "DMG artifact not found: $DMG_PATH"
[[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"

APP_VERSION="${APP_VERSION:-$(plist_value CFBundleShortVersionString)}"
APP_VERSION="${APP_VERSION:-$(plist_value CFBundleVersion)}"
APP_VERSION="${APP_VERSION:-0.1.0}"
bundle_identifier="$(plist_value CFBundleIdentifier)"
bundle_executable="$(plist_value CFBundleExecutable)"
OUTPUT_PATH="${OUTPUT_PATH:-${DMG_PATH}.provenance.json}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

build_time_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
git_revision="$(git rev-parse HEAD 2>/dev/null || true)"
git_dirty="false"
if ! git diff --quiet --ignore-submodules -- 2>/dev/null || ! git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
    git_dirty="true"
fi

codesign_valid="false"
if codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
    codesign_valid="true"
fi
app_codesign_details="$(codesign_details_for "$APP_PATH")"
app_codesign_authority="$(printf '%s\n' "$app_codesign_details" | awk -F= '/^Authority=/ { print $2; exit }')"
app_team_identifier="$(printf '%s\n' "$app_codesign_details" | awk -F= '/^TeamIdentifier=/ { print $2; exit }')"
app_hardened_runtime="false"
if printf '%s\n' "$app_codesign_details" | grep -E '^Runtime Version=' >/dev/null 2>&1; then
    app_hardened_runtime="true"
fi

dmg_codesign_valid="false"
if codesign --verify --strict "$DMG_PATH" >/dev/null 2>&1; then
    dmg_codesign_valid="true"
fi
dmg_codesign_details="$(codesign_details_for "$DMG_PATH")"
dmg_codesign_authority="$(printf '%s\n' "$dmg_codesign_details" | awk -F= '/^Authority=/ { print $2; exit }')"
dmg_notarization_status="${MACKAN_RELEASE_NOTARIZATION_STATUS:-}"
dmg_notarization_id="${MACKAN_RELEASE_NOTARIZATION_ID:-}"
notary_json_path="${MACKAN_RELEASE_NOTARY_JSON_PATH:-${DMG_PATH}.notary.json}"
notary_json_sha256=""
notary_json_size="0"
if [[ -f "$notary_json_path" ]]; then
    notary_json_sha256="$(file_sha256 "$notary_json_path")"
    notary_json_size="$(file_size "$notary_json_path")"
fi

hdiutil_valid="false"
if hdiutil verify "$DMG_PATH" >/dev/null 2>&1; then
    hdiutil_valid="true"
fi

spctl_accepted="false"
if spctl --assess --type open "$DMG_PATH" >/dev/null 2>&1; then
    spctl_accepted="true"
fi

stapler_valid="false"
if xcrun stapler validate "$DMG_PATH" >/dev/null 2>&1; then
    stapler_valid="true"
fi

app_size="$(du -sk "$APP_PATH" | awk '{print $1}')"
dmg_size="$(file_size "$DMG_PATH")"
dmg_sha256="$(file_sha256 "$DMG_PATH")"

{
    printf '{\n'
    printf '  "schemaVersion": 1,\n'
    printf '  "generatedAtUtc": %s,\n' "$(json_string "$build_time_utc")"
    printf '  "app": {\n'
    printf '    "name": %s,\n' "$(json_string "$APP_NAME")"
    printf '    "version": %s,\n' "$(json_string "$APP_VERSION")"
    printf '    "bundleIdentifier": %s,\n' "$(json_string "$bundle_identifier")"
    printf '    "bundleExecutable": %s,\n' "$(json_string "$bundle_executable")"
    printf '    "path": %s,\n' "$(json_string "$APP_PATH")"
    printf '    "sizeKiB": %s\n' "$app_size"
    printf '  },\n'
    printf '  "dmg": {\n'
    printf '    "path": %s,\n' "$(json_string "$DMG_PATH")"
    printf '    "sha256": %s,\n' "$(json_string "$dmg_sha256")"
    printf '    "sizeBytes": %s\n' "$dmg_size"
    printf '  },\n'
    printf '  "source": {\n'
    printf '    "gitRevision": %s,\n' "$(json_string "$git_revision")"
    printf '    "gitDirty": %s\n' "$(json_bool "$git_dirty")"
    printf '  },\n'
    printf '  "verification": {\n'
    printf '    "appCodesignValid": %s,\n' "$(json_bool "$codesign_valid")"
    printf '    "appCodesignAuthority": %s,\n' "$(json_string "$app_codesign_authority")"
    printf '    "appTeamIdentifier": %s,\n' "$(json_string "$app_team_identifier")"
    printf '    "appHardenedRuntime": %s,\n' "$(json_bool "$app_hardened_runtime")"
    printf '    "dmgCodesignValid": %s,\n' "$(json_bool "$dmg_codesign_valid")"
    printf '    "dmgCodesignAuthority": %s,\n' "$(json_string "$dmg_codesign_authority")"
    printf '    "dmgNotarizationStatus": %s,\n' "$(json_string "$dmg_notarization_status")"
    printf '    "dmgNotarizationId": %s,\n' "$(json_string "$dmg_notarization_id")"
    printf '    "dmgNotaryJsonSha256": %s,\n' "$(json_string "$notary_json_sha256")"
    printf '    "dmgNotaryJsonSizeBytes": %s,\n' "$notary_json_size"
    printf '    "dmgHdiutilValid": %s,\n' "$(json_bool "$hdiutil_valid")"
    printf '    "dmgSpctlAccepted": %s,\n' "$(json_bool "$spctl_accepted")"
    printf '    "dmgStaplerValid": %s\n' "$(json_bool "$stapler_valid")"
    printf '  }\n'
    printf '}\n'
} > "$OUTPUT_PATH"

echo "$OUTPUT_PATH"

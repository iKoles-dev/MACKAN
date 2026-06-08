#!/usr/bin/env bash
set -euo pipefail

APP_PATH=""
DMG_PATH=""
PROVENANCE_PATH=""
NOTARY_JSON_PATH=""
REQUIRE_VERSION=""
REQUIRE_PUBLIC_RELEASE=false

usage() {
    cat <<USAGE
Usage: verify-release-artifact.sh --app PATH --dmg PATH [--provenance PATH] [--notary-json PATH] [--require-version VERSION] [--require-public-release]

Verifies that a MACKAN DMG and its provenance manifest match the current
artifact bytes and expected release validation state.
USAGE
}

fail() {
    echo "$1" >&2
    exit 1
}

json_value() {
    local path="$1"
    /usr/bin/python3 - "$PROVENANCE_PATH" "$path" <<'PY'
import json
import sys

path = sys.argv[2].split(".")
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)
for key in path:
    value = value[key]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

json_value_optional() {
    local path="$1"
    /usr/bin/python3 - "$PROVENANCE_PATH" "$path" <<'PY'
import json
import sys

path = sys.argv[2].split(".")
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)
for key in path:
    if not isinstance(value, dict) or key not in value:
        sys.exit(0)
    value = value[key]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

json_file_value_optional() {
    local file="$1"
    local path="$2"
    /usr/bin/python3 - "$file" "$path" <<'PY'
import json
import sys

path = sys.argv[2].split(".")
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    value = json.load(handle)
for key in path:
    if not isinstance(value, dict) or key not in value:
        sys.exit(0)
    value = value[key]
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

file_sha256() {
    shasum -a 256 "$1" | awk '{print $1}'
}

file_size() {
    stat -f '%z' "$1"
}

plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
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
        --provenance)
            PROVENANCE_PATH="$2"
            shift 2
            ;;
        --notary-json)
            NOTARY_JSON_PATH="$2"
            shift 2
            ;;
        --require-version)
            REQUIRE_VERSION="$2"
            shift 2
            ;;
        --require-public-release)
            REQUIRE_PUBLIC_RELEASE=true
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

[[ -n "$APP_PATH" ]] || fail "App bundle path is required."
[[ -n "$DMG_PATH" ]] || fail "DMG path is required."
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ -f "$DMG_PATH" ]] || fail "DMG artifact not found: $DMG_PATH"
[[ "$APP_PATH" == *.app ]] || fail "App path must point to a .app bundle: $APP_PATH"

PROVENANCE_PATH="${PROVENANCE_PATH:-${DMG_PATH}.provenance.json}"
NOTARY_JSON_PATH="${NOTARY_JSON_PATH:-${DMG_PATH}.notary.json}"
[[ -f "$PROVENANCE_PATH" ]] || fail "Provenance manifest not found: $PROVENANCE_PATH"

/usr/bin/python3 -m json.tool "$PROVENANCE_PATH" >/dev/null

manifest_schema="$(json_value schemaVersion)"
[[ "$manifest_schema" == "1" ]] || fail "Unsupported provenance schemaVersion: $manifest_schema"

manifest_app_path="$(json_value app.path)"
manifest_dmg_path="$(json_value dmg.path)"
manifest_version="$(json_value app.version)"
manifest_sha="$(json_value dmg.sha256)"
manifest_size="$(json_value dmg.sizeBytes)"
manifest_git_revision="$(json_value source.gitRevision)"
manifest_git_dirty="$(json_value source.gitDirty)"
actual_sha="$(file_sha256 "$DMG_PATH")"
actual_size="$(file_size "$DMG_PATH")"
plist_version="$(plist_value CFBundleShortVersionString)"
plist_build="$(plist_value CFBundleVersion)"

[[ "$manifest_app_path" == "$APP_PATH" ]] || fail "Provenance app.path does not match app path: $manifest_app_path"
[[ "$manifest_dmg_path" == "$DMG_PATH" ]] || fail "Provenance dmg.path does not match DMG path: $manifest_dmg_path"
[[ "$manifest_sha" == "$actual_sha" ]] || fail "DMG SHA-256 mismatch: manifest $manifest_sha, actual $actual_sha"
[[ "$manifest_size" == "$actual_size" ]] || fail "DMG size mismatch: manifest $manifest_size, actual $actual_size"

if [[ -n "$REQUIRE_VERSION" ]]; then
    [[ "$manifest_version" == "$REQUIRE_VERSION" ]] || fail "Provenance app.version '$manifest_version' does not match required version '$REQUIRE_VERSION'."
    [[ "$plist_version" == "$REQUIRE_VERSION" ]] || fail "CFBundleShortVersionString '$plist_version' does not match required version '$REQUIRE_VERSION'."
    [[ "$plist_build" == "$REQUIRE_VERSION" ]] || fail "CFBundleVersion '$plist_build' does not match required version '$REQUIRE_VERSION'."
fi

hdiutil verify "$DMG_PATH" >/dev/null

app_codesign_valid="$(json_value verification.appCodesignValid)"
app_codesign_authority="$(json_value verification.appCodesignAuthority)"
app_hardened_runtime="$(json_value verification.appHardenedRuntime)"
dmg_codesign_valid="$(json_value verification.dmgCodesignValid)"
dmg_codesign_authority="$(json_value verification.dmgCodesignAuthority)"
dmg_hdiutil_valid="$(json_value verification.dmgHdiutilValid)"
dmg_spctl_accepted="$(json_value verification.dmgSpctlAccepted)"
dmg_stapler_valid="$(json_value verification.dmgStaplerValid)"

[[ "$dmg_hdiutil_valid" == "true" ]] || fail "dmgHdiutilValid must be true."

if [[ "$app_codesign_valid" == "true" ]]; then
    codesign --verify --deep --strict "$APP_PATH" >/dev/null
fi

if [[ "$REQUIRE_PUBLIC_RELEASE" == "true" ]]; then
    [[ -n "$manifest_git_revision" ]] || fail "source.gitRevision must be set for public release."
    [[ "$manifest_git_dirty" == "false" ]] || fail "source.gitDirty must be false for public release."
    [[ "$app_codesign_valid" == "true" ]] || fail "appCodesignValid must be true for public release."
    [[ "$app_codesign_authority" == Developer\ ID\ Application:* ]] || fail "appCodesignAuthority must start with Developer ID Application for public release."
    [[ "$app_hardened_runtime" == "true" ]] || fail "appHardenedRuntime must be true for public release."
    [[ "$dmg_codesign_valid" == "true" ]] || fail "dmgCodesignValid must be true for public release."
    [[ "$dmg_codesign_authority" == Developer\ ID\ Application:* ]] || fail "dmgCodesignAuthority must start with Developer ID Application for public release."
    dmg_notarization_status="$(json_value_optional verification.dmgNotarizationStatus)"
    [[ "$dmg_notarization_status" == "Accepted" ]] || fail "dmgNotarizationStatus must be Accepted for public release."
    dmg_notarization_id="$(json_value_optional verification.dmgNotarizationId)"
    [[ -n "$dmg_notarization_id" ]] || fail "dmgNotarizationId must be set for public release."
    [[ -f "$NOTARY_JSON_PATH" ]] || fail "Notary JSON not found: $NOTARY_JSON_PATH"
    /usr/bin/python3 -m json.tool "$NOTARY_JSON_PATH" >/dev/null
    notary_json_status="$(json_file_value_optional "$NOTARY_JSON_PATH" status)"
    notary_json_id="$(json_file_value_optional "$NOTARY_JSON_PATH" id)"
    [[ "$notary_json_status" == "$dmg_notarization_status" ]] || fail "Notary JSON status does not match provenance."
    [[ "$notary_json_id" == "$dmg_notarization_id" ]] || fail "Notary JSON id does not match provenance."
    dmg_notary_json_sha256="$(json_value_optional verification.dmgNotaryJsonSha256)"
    [[ -n "$dmg_notary_json_sha256" ]] || fail "dmgNotaryJsonSha256 must be set for public release."
    notary_json_sha256="$(file_sha256 "$NOTARY_JSON_PATH")"
    [[ "$notary_json_sha256" == "$dmg_notary_json_sha256" ]] || fail "Notary JSON SHA-256 mismatch: manifest $dmg_notary_json_sha256, actual $notary_json_sha256"
    dmg_notary_json_size="$(json_value_optional verification.dmgNotaryJsonSizeBytes)"
    [[ -n "$dmg_notary_json_size" ]] || fail "dmgNotaryJsonSizeBytes must be set for public release."
    notary_json_size="$(file_size "$NOTARY_JSON_PATH")"
    [[ "$notary_json_size" == "$dmg_notary_json_size" ]] || fail "Notary JSON size mismatch: manifest $dmg_notary_json_size, actual $notary_json_size"
    [[ "$dmg_spctl_accepted" == "true" ]] || fail "dmgSpctlAccepted must be true for public release."
    [[ "$dmg_stapler_valid" == "true" ]] || fail "dmgStaplerValid must be true for public release."

    codesign --verify --strict "$DMG_PATH" >/dev/null
    spctl --assess --type open "$DMG_PATH" >/dev/null
    xcrun stapler validate "$DMG_PATH" >/dev/null
fi

echo "Verified release artifact: $DMG_PATH"

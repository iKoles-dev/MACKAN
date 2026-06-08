#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs/mackan"

STRICT=false
OUTPUT_JSON=false
REQUIRE_RELEASE_CREDENTIALS=false

usage() {
    cat <<USAGE
Usage: release-readiness.sh [--strict] [--json] [--require-release-credentials]

Checks release readiness evidence from project-local docs and packaging scripts.

Flags:
  --strict   Exit non-zero when required matrix cells are not complete.
  --json     Emit a machine-readable JSON summary.
  --require-release-credentials
             Exit non-zero unless Developer ID and notary credential settings
             needed by release-dmg.sh are configured and discoverable.
  --help     Show this message.
USAGE
}

trim() {
    local value="$1"
    printf '%s' "$value" | awk '{$1=$1; print $0}'
}

normalize_status() {
    local value="$1"
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -d '\r'
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)
            STRICT=true
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --require-release-credentials)
            REQUIRE_RELEASE_CREDENTIALS=true
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

FAIL=0
required_docs=(
    "$DOCS_DIR/product-spec.md"
    "$DOCS_DIR/architecture.md"
    "$DOCS_DIR/parity-matrix.md"
    "$DOCS_DIR/release-roadmap.md"
    "$DOCS_DIR/release-execution-checklist.md"
    "$DOCS_DIR/brainstorming.md"
    "$DOCS_DIR/next-iteration-plan.md"
    "$DOCS_DIR/README.md"
)

missing_docs=()
for doc in "${required_docs[@]}"; do
    if [[ ! -f "$doc" ]]; then
        missing_docs+=("$doc")
    fi
done

required_scripts=(
    "$SCRIPT_DIR/release-check.sh"
    "$SCRIPT_DIR/test-release-check.sh"
    "$SCRIPT_DIR/test-accessibility-smoke.sh"
    "$SCRIPT_DIR/package-dmg.sh"
    "$SCRIPT_DIR/verify-app-bundle.sh"
    "$SCRIPT_DIR/verify-app-launch.sh"
    "$SCRIPT_DIR/run-ui-ux-audit.sh"
    "$SCRIPT_DIR/verify-ui-ux-audit-evidence.sh"
    "$SCRIPT_DIR/test-dmg-launch-smoke.sh"
    "$SCRIPT_DIR/test-clean-install-smoke.sh"
    "$SCRIPT_DIR/test-run-ui-ux-audit.sh"
    "$SCRIPT_DIR/test-verify-ui-ux-audit-evidence.sh"
    "$SCRIPT_DIR/test-release-dmg.sh"
    "$SCRIPT_DIR/release-dmg.sh"
    "$SCRIPT_DIR/generate-release-provenance.sh"
    "$SCRIPT_DIR/verify-release-artifact.sh"
    "$SCRIPT_DIR/verify-release-checksums.sh"
    "$SCRIPT_DIR/test-verify-release-checksums.sh"
    "$SCRIPT_DIR/generate-release-summary.sh"
    "$SCRIPT_DIR/test-generate-release-summary.sh"
    "$SCRIPT_DIR/verify-release-summary.sh"
    "$SCRIPT_DIR/test-verify-release-summary.sh"
    "$SCRIPT_DIR/verify-public-release-handoff.sh"
    "$SCRIPT_DIR/test-verify-public-release-handoff.sh"
    "$SCRIPT_DIR/verify-release-log.sh"
    "$SCRIPT_DIR/test-verify-release-log.sh"
)

missing_scripts=()
for script in "${required_scripts[@]}"; do
    if [[ ! -f "$script" ]]; then
        missing_scripts+=("$script")
    fi
done

developer_id_application="${MACKAN_DEVELOPER_ID_APPLICATION:-}"
notary_keychain_profile="${MACKAN_NOTARY_KEYCHAIN_PROFILE:-}"
signing_keychain_path="${MACKAN_SIGNING_KEYCHAIN_PATH:-}"
developer_id_application_configured=false
developer_id_application_found=false
notary_keychain_profile_configured=false
notary_keychain_profile_validated=false

if [[ -n "$developer_id_application" ]]; then
    developer_id_application_configured=true
fi
if [[ -n "$notary_keychain_profile" ]]; then
    notary_keychain_profile_configured=true
fi

if [[ -n "${MACKAN_READINESS_SECURITY_IDENTITIES_OUTPUT+x}" ]]; then
    codesigning_identities="$MACKAN_READINESS_SECURITY_IDENTITIES_OUTPUT"
else
    security_args=(find-identity -v -p codesigning)
    if [[ -n "$signing_keychain_path" ]]; then
        security_args+=("$signing_keychain_path")
    fi
    codesigning_identities="$(security "${security_args[@]}" 2>/dev/null || true)"
fi

if [[ "$developer_id_application_configured" == true ]] \
    && printf '%s\n' "$codesigning_identities" | grep -F -- "$developer_id_application" >/dev/null 2>&1; then
    developer_id_application_found=true
fi

if [[ "$notary_keychain_profile_configured" == true ]]; then
    if [[ -n "${MACKAN_READINESS_NOTARY_PROFILE_VALIDATED+x}" ]]; then
        case "$MACKAN_READINESS_NOTARY_PROFILE_VALIDATED" in
            true)
                notary_keychain_profile_validated=true
                ;;
            false)
                notary_keychain_profile_validated=false
                ;;
            *)
                echo "MACKAN_READINESS_NOTARY_PROFILE_VALIDATED must be true or false when set." >&2
                exit 2
                ;;
        esac
    else
        notarytool_args=(notarytool history --keychain-profile "$notary_keychain_profile")
        if [[ -n "$signing_keychain_path" ]]; then
            notarytool_args+=(--keychain "$signing_keychain_path")
        fi
        notarytool_args+=(--output-format json --no-progress)
        if xcrun "${notarytool_args[@]}" >/dev/null 2>&1; then
            notary_keychain_profile_validated=true
        fi
    fi
fi

release_credentials_ready=false
if [[ "$developer_id_application_configured" == true \
    && "$developer_id_application_found" == true \
    && "$notary_keychain_profile_configured" == true \
    && "$notary_keychain_profile_validated" == true ]]; then
    release_credentials_ready=true
fi

parity_file="$DOCS_DIR/parity-matrix.md"
is_required_marker() {
    local status_value="$1"
    [[ "$status_value" == "required" ]]
}

is_scope_marker() {
    local status_value="$1"
    [[ "$status_value" == "required" || "$status_value" == "blocked" ]]
}

is_complete_status() {
    local status_value="$1"
    case "$status_value" in
        completed | done | complete | better-native)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_pending_status() {
    local status_value="$1"
    case "$status_value" in
        in\ progress | pending | blocked | "not started" | not_started | required)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_known_status() {
    local status_value="$1"
    case "$status_value" in
        completed | done | complete | better-native | in\ progress | blocked | pending | "not started" | not_started | required)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

required_total=0
required_pending=0
required_completed=0
required_unknown=0
required_rows=()
required_parse_failures=0
required_parse_failure_rows=()
non_required_pending_rows=()
explicit_scope_markers=false
strict_scope_mode="fallback-all-rows"

if [[ -f "$parity_file" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" != *"|"* ]] && continue

        IFS='|' read -r -a raw_cells <<< "$line"
        cells=()
        for cell in "${raw_cells[@]}"; do
            cell="$(trim "$cell")"
            [[ -z "$cell" ]] && continue
            cells+=("$cell")
        done

        if [[ "${#cells[@]}" -lt 4 ]]; then
            required_parse_failures=$((required_parse_failures + 1))
            required_parse_failure_rows+=("$line")
            continue
        fi

        area="${cells[0]}"
        capability="${cells[1]}"
        requirement="$(normalize_status "${cells[2]}")"
        status="$(normalize_status "${cells[3]}")"

        # Skip table header/separator lines.
        if [[ "$area" == "Area" || "$area" == "---" || "$capability" == "---" ]]; then
            continue
        fi
        if [[ -z "$area" || -z "$capability" || -z "$requirement" ]]; then
            required_parse_failures=$((required_parse_failures + 1))
            required_parse_failure_rows+=("$line")
            continue
        fi
        if is_scope_marker "$requirement" || is_scope_marker "$status"; then
            explicit_scope_markers=true
        fi

        if ! is_known_status "$status"; then
            required_unknown=$((required_unknown + 1))
            required_parse_failure_rows+=("$line")
            continue
        fi

        is_scoped=false
        if is_scope_marker "$requirement" || is_scope_marker "$status"; then
            is_scoped=true
        fi

        if [[ "$explicit_scope_markers" == true && "$is_scoped" == false ]]; then
            if is_pending_status "$status"; then
                non_required_pending_rows+=("$area :: $capability (status=$status)")
            fi
            continue
        fi

        # Fallback mode: parity matrix does not use explicit requirement markers.
        # Treat all parsed rows as required parity debt unless status is explicitly complete.
        if [[ "$explicit_scope_markers" == false ]]; then
            strict_scope_mode="fallback-all-rows"
            required_total=$((required_total + 1))
            if is_complete_status "$status"; then
                required_completed=$((required_completed + 1))
            else
                required_pending=$((required_pending + 1))
                required_rows+=("$area :: $capability (status=$status)")
            fi
            continue
        fi

        # Explicit marker mode: rows marked as required/blocked in either requirement
        # or status columns participate in the required parity gate.
        strict_scope_mode="explicit-requirement-markers"
        if is_scope_marker "$requirement" || is_required_marker "$status" || is_scope_marker "$status"; then
            required_total=$((required_total + 1))
            if is_complete_status "$status"; then
                required_completed=$((required_completed + 1))
            else
                required_pending=$((required_pending + 1))
                required_rows+=("$area :: $capability (status=$status)")
            fi
        else
            if is_pending_status "$status"; then
                non_required_pending_rows+=("$area :: $capability (status=$status)")
            fi
        fi
    done < "$parity_file"
fi

if (( ${#missing_docs[@]} > 0 )); then
    FAIL=1
fi
if (( ${#missing_scripts[@]} > 0 )); then
    FAIL=1
fi
if (( required_parse_failures > 0 )); then
    FAIL=1
fi
if [[ "$STRICT" == "true" && "$required_pending" -gt 0 ]]; then
    FAIL=1
fi
if [[ "$STRICT" == "true" && "$required_unknown" -gt 0 ]]; then
    FAIL=1
fi
if [[ "$REQUIRE_RELEASE_CREDENTIALS" == "true" && "$release_credentials_ready" != "true" ]]; then
    FAIL=1
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
    printf '{'
    printf '"missingDocs":%s,' "$(printf '%s\n' "${#missing_docs[@]}")"
    printf '"missingScripts":%s,' "$(printf '%s\n' "${#missing_scripts[@]}")"
    printf '"strictScopeMode":"%s",' "$(json_escape "$strict_scope_mode")"
    printf '"requiredParityTotal":%s,' "$required_total"
    printf '"requiredParityPending":%s,' "$required_pending"
    printf '"requiredParityCompleted":%s,' "$required_completed"
    printf '"requiredParityUnknown":%s,' "$required_unknown"
    printf '"requiredParityParseFailures":%s,' "$required_parse_failures"
    printf '"requiredParityRows":['
    first=true
    for row in "${required_rows[@]+"${required_rows[@]}"}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            printf ','
        fi
        printf '"%s"' "$(json_escape "$row")"
    done
    printf '],'
    printf '"requiredParityParseFailureRows":['
    if (( required_parse_failures > 0 )); then
        first=true
        for row in "${required_parse_failure_rows[@]+"${required_parse_failure_rows[@]}"}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                printf ','
            fi
            printf '"%s"' "$(json_escape "$row")"
        done
    fi
    printf '],'
    printf '"releaseCredentialsRequired":%s,' "$REQUIRE_RELEASE_CREDENTIALS"
    printf '"developerIdApplicationConfigured":%s,' "$developer_id_application_configured"
    printf '"developerIdApplicationFound":%s,' "$developer_id_application_found"
    printf '"notaryKeychainProfileConfigured":%s,' "$notary_keychain_profile_configured"
    printf '"notaryKeychainProfileValidated":%s,' "$notary_keychain_profile_validated"
    printf '"releaseCredentialsReady":%s,' "$release_credentials_ready"
    printf '"strict":%s' "$STRICT"
    printf '}\n'
else
    echo "MACKAN release readiness check"
    echo "--------------------------------"
    echo "Docs checked: ${#required_docs[@]}"
    if (( ${#missing_docs[@]} > 0 )); then
        echo "Missing docs:"
        for doc in "${missing_docs[@]}"; do
            echo "  - $doc"
        done
    else
        echo "Docs: OK"
    fi

    echo "Scripts checked: ${#required_scripts[@]}"
    if (( ${#missing_scripts[@]} > 0 )); then
        echo "Missing scripts:"
        for script in "${missing_scripts[@]}"; do
            echo "  - $script"
        done
    else
        echo "Scripts: OK"
    fi

    echo "Parity matrix required rows:"
    if [[ "$explicit_scope_markers" == true ]]; then
        echo "  total required markers: $required_total"
    else
        echo "  total strict rows: $required_total"
    fi
    echo "  strict scope mode: $strict_scope_mode"
    echo "  required rows still pending: $required_pending"
    echo "  required rows unknown status: $required_unknown"
    echo "  parity parse failures: $required_parse_failures"
    if (( required_pending > 0 )); then
        echo "  pending required rows:"
        for row in "${required_rows[@]}"; do
            echo "  - $row"
        done
    else
        echo "  pending required rows: none"
    fi

    if (( ${#non_required_pending_rows[@]} > 0 )); then
        echo "  in-progress/non-complete rows not marked required:"
        for row in "${non_required_pending_rows[@]}"; do
            echo "  - $row"
        done
    fi

    if (( required_parse_failures > 0 )); then
        echo "  parse-failed rows:"
        for row in "${required_parse_failure_rows[@]+"${required_parse_failure_rows[@]}"}"; do
            echo "  - $row"
        done
    fi

    echo "Mode: $(if [[ "$STRICT" == true ]]; then echo strict; else echo report-only; fi)"
    echo "Release credentials:"
    echo "  require release credentials: $REQUIRE_RELEASE_CREDENTIALS"
    echo "  Developer ID Application configured: $developer_id_application_configured"
    echo "  Developer ID Application found: $developer_id_application_found"
    echo "  notarytool keychain profile configured: $notary_keychain_profile_configured"
    echo "  notarytool keychain profile validated: $notary_keychain_profile_validated"
    echo "  release credentials ready: $release_credentials_ready"
fi

if [[ "$FAIL" -eq 1 ]]; then
    exit 1
fi

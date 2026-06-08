#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
SOURCE_DIR="$PACKAGE_DIR/Sources/MACKAN"
MAIN_WINDOW="$SOURCE_DIR/MainWindowView.swift"
CATALOG_VIEW="$SOURCE_DIR/CatalogViews.swift"
INSPECTOR_VIEW="$SOURCE_DIR/InspectorViews.swift"
APP_ENTRY="$SOURCE_DIR/MACKANApp.swift"
SOURCE_FILES=("$SOURCE_DIR"/*.swift)

assert_contains() {
    local file="$1"
    local needle="$2"
    local message="$3"

    if ! grep -qF -- "$needle" "$file"; then
        echo "Accessibility smoke failed: $message" >&2
        echo "Expected to find: $needle" >&2
        echo "In file: $file" >&2
        exit 1
    fi
}

assert_count_at_least() {
    local file="$1"
    local pattern="$2"
    local minimum="$3"
    local label="$4"

    local count
    count="$(grep -cE -- "$pattern" "$file" || true)"
    if (( count < minimum )); then
        echo "Accessibility smoke failed: $label (found ${count}, expected at least ${minimum})." >&2
        exit 1
    fi
}

assert_count_at_least_in_files() {
    local pattern="$1"
    local minimum="$2"
    local label="$3"
    shift 3

    local count=0
    local file_count
    for file in "$@"; do
        file_count="$(grep -cE -- "$pattern" "$file" || true)"
        count=$((count + file_count))
    done
    if (( count < minimum )); then
        echo "Accessibility smoke failed: $label (found ${count}, expected at least ${minimum})." >&2
        exit 1
    fi
}

assert_contains_in_files() {
    local needle="$1"
    local message="$2"
    shift 2

    for file in "$@"; do
        if grep -qF -- "$needle" "$file"; then
            return 0
        fi
    done

    echo "Accessibility smoke failed: $message" >&2
    echo "Expected to find: $needle" >&2
    echo "In source files under: $SOURCE_DIR" >&2
    exit 1
}

assert_contains_any() {
    local file="$1"
    local message="$2"
    shift 2
    local patterns=("$@")

    for pattern in "${patterns[@]}"; do
        if grep -qF -- "$pattern" "$file"; then
            return 0
        fi
    done

    echo "Accessibility smoke failed: $message" >&2
    echo "Expected one of: ${patterns[*]}" >&2
    echo "In file: $file" >&2
    exit 1
}

[[ -f "$MAIN_WINDOW" ]] || { echo "Missing file: $MAIN_WINDOW" >&2; exit 1; }
[[ -f "$CATALOG_VIEW" ]] || { echo "Missing file: $CATALOG_VIEW" >&2; exit 1; }
[[ -f "$INSPECTOR_VIEW" ]] || { echo "Missing file: $INSPECTOR_VIEW" >&2; exit 1; }
[[ -f "$APP_ENTRY" ]] || { echo "Missing file: $APP_ENTRY" >&2; exit 1; }

assert_count_at_least_in_files "\\.accessibilityLabel" 25 "SwiftUI surfaces should expose key VoiceOver labels" "${SOURCE_FILES[@]}"
assert_count_at_least_in_files "\\.keyboardShortcut" 45 "SwiftUI surfaces should expose keyboard actions" "${SOURCE_FILES[@]}"
assert_count_at_least "$APP_ENTRY" "\\.keyboardShortcut" 8 "Main app menus should expose keyboard accelerators"

for label in \
    "Refresh Repositories" \
    "Module action menu" \
    "Preview Changes" \
    "Apply Changes" \
    "Open Game Folder" \
    "Search mods" \
    "Module filter" \
    "Manage module labels" \
    "Saved searches" \
    "Table columns" \
    "Primary sort" \
    "Secondary sorts" \
    "Module details tabs"
do
    assert_contains_in_files ".accessibilityLabel(\"$label\")" "Missing accessibility label: $label" "${SOURCE_FILES[@]}"
done

assert_contains_any "$MAIN_WINDOW" "Missing launch label" \
    '.accessibilityLabel("Launch Game")' \
    '.accessibilityLabel("Launching Game")' \
    '.accessibilityLabel(model.isLaunchingGame ? "Launching Game" : "Launch Game")'
assert_contains_in_files '.accessibilityLabel(model.isLaunchingGame ? "Launching Game" : "Launch Game")' "Missing launch label" "${SOURCE_FILES[@]}"

assert_contains "$CATALOG_VIEW" '.keyboardShortcut("p", modifiers: [.command])' "Preview strip shortcut missing"
assert_contains "$CATALOG_VIEW" '.keyboardShortcut(.delete, modifiers: [.command])' "Clear strip shortcut missing"
assert_contains "$CATALOG_VIEW" '.keyboardShortcut(.return, modifiers: [.command])' "Apply strip shortcut missing"

assert_contains "$APP_ENTRY" ".keyboardShortcut(\"i\", modifiers: [.command, .shift])" "Instance manager missing keyboard shortcut"
assert_contains "$APP_ENTRY" ".keyboardShortcut(\"n\", modifiers: [.command, .shift])" "Add-instance shortcut missing"
assert_contains "$APP_ENTRY" ".keyboardShortcut(\"r\", modifiers: [.command])" "Launch command shortcut missing"
assert_contains "$APP_ENTRY" ".keyboardShortcut(\"r\", modifiers: [.command, .shift])" "Repository refresh shortcut missing"
assert_contains "$APP_ENTRY" ".keyboardShortcut(.return, modifiers: [.command])" "Apply shortcut missing"
assert_contains_in_files ".keyboardShortcut(.defaultAction)" "Default action shortcut missing" "${SOURCE_FILES[@]}"
assert_contains_in_files ".keyboardShortcut(.cancelAction)" "Cancel action shortcut missing" "${SOURCE_FILES[@]}"

assert_contains "$APP_ENTRY" ".dynamicTypeSize(" "App root should opt in to Dynamic Type"

echo "Accessibility smoke passed: VoiceOver labels, keyboard shortcuts, and dynamic type hooks detected."

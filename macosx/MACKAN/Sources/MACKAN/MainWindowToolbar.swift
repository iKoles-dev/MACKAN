import SwiftUI

import MACKANKit

struct MainWindowToolbar: ToolbarContent {
    let state: MainWindowToolbarState
    let selectedModuleActionPresentation: ModuleActionPresentationState
    let onRefresh: () -> Void
    let onStageSelectedModule: () -> Void
    let onStageSelectedModuleAction: (StagedModAction) -> Void
    let onPreview: () -> Void
    let onApply: () -> Void
    let onUpgradeAll: () -> Void
    let onInstallFromFile: () -> Void
    let onImportDownloads: () -> Void
    let onClear: () -> Void
    let onLaunch: () -> Void
    let onOpenFolder: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: onRefresh) {
                Label("Refresh Repositories", systemImage: "arrow.clockwise")
            }
            .disabled(!state.canClickRefresh)
            .accessibilityLabel("Refresh Repositories")
            .accessibilityHint("Reloads repositories and refreshes catalog data.")
            .help("Refresh repositories and reload catalog data")

            moduleAction

            Button(action: onPreview) {
                Label("Preview Changes", systemImage: "list.bullet.rectangle")
            }
            .disabled(!state.canClickPreview)
            .accessibilityLabel("Preview Changes")
            .accessibilityHint("Open staged module change preview.")
            .help("Preview staged module changes")

            Button(action: onApply) {
                Label("Apply Changes", systemImage: "checkmark.circle")
            }
            .disabled(!state.canClickApply)
            .accessibilityLabel("Apply Changes")
            .accessibilityHint("Apply pending catalog changes to selected game instance.")
            .help("Apply pending changes")
        }

        ToolbarItemGroup {
            Button(action: onUpgradeAll) {
                Label("Upgrade All", systemImage: "square.and.arrow.down")
            }
            .disabled(!state.canClickUpgradeAll)
            .accessibilityLabel("Upgrade All")
            .help("Stage all available upgrades")

            Button(action: onInstallFromFile) {
                Label("Install from File", systemImage: "doc.badge.plus")
            }
            .disabled(!state.canClickInstallFromFile)
            .accessibilityLabel("Install from File")
            .accessibilityHint("Open file picker to install CKAN files.")
            .help("Install mods from local .ckan files")

            Button(action: onImportDownloads) {
                Label("Import Downloads", systemImage: "tray.and.arrow.down")
            }
            .disabled(!state.canClickImportDownloads)
            .accessibilityLabel("Import Downloads")
            .accessibilityHint("Open file picker for local downloads import.")
            .help("Import local downloaded mod archives")

            Button(action: onClear) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .disabled(!state.canClickClear)
            .accessibilityLabel("Clear pending changes")
            .help("Clear staged changes")
        }

        ToolbarItemGroup {
            Button(action: onLaunch) {
                Label(state.isLaunchingGame ? "Launching Game" : "Launch Game", systemImage: "play.fill")
            }
            .disabled(!state.canClickLaunch)
            .accessibilityLabel(state.isLaunchingGame ? "Launching Game" : "Launch Game")
            .accessibilityHint("Start the selected game instance.")
            .help(state.isLaunchingGame ? "Launching game..." : "Launch selected game")

            Button(action: onOpenFolder) {
                Label("Open Game Folder", systemImage: "folder")
            }
            .disabled(!state.canClickOpenFolder)
            .accessibilityLabel("Open Game Folder")
            .accessibilityHint("Reveal selected game directory in Finder.")
            .help("Open selected game folder in Finder")

            MackanSettingsButton {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityLabel("Open Settings")
            .help("Open MACKAN settings")
        }
    }

    @ViewBuilder
    private var moduleAction: some View {
        if selectedModuleActionPresentation.usesMenu {
            Menu {
                ForEach(selectedModuleActionPresentation.availableActions, id: \.rawValue) { action in
                    Button {
                        onStageSelectedModuleAction(action)
                    } label: {
                        Label(action.title, systemImage: action.symbolName)
                    }
                }
            } label: {
                Label(
                    selectedModuleActionPresentation.accessibilityLabel,
                    systemImage: selectedModuleActionPresentation.symbolName)
            }
            .disabled(selectedModuleActionPresentation.title == nil)
            .accessibilityLabel("Module action menu")
            .help(selectedModuleActionPresentation.help)
        } else {
            Button(action: onStageSelectedModule) {
                Label(
                    selectedModuleActionPresentation.accessibilityLabel,
                    systemImage: selectedModuleActionPresentation.symbolName)
            }
            .disabled(selectedModuleActionPresentation.title == nil)
            .accessibilityLabel(selectedModuleActionPresentation.accessibilityLabel)
            .help(selectedModuleActionPresentation.help)
        }
    }
}

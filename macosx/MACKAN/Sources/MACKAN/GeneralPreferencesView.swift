import AppKit
import SwiftUI

import MACKANKit

struct GeneralPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var checkForUpdatesOnLaunch = false
    @State private var useDevBuilds = false
    @State private var refreshRepositoriesOnLaunch = true
    @State private var autoSortByUpdate = true
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
        PreferencesPaneScrollView {
            VStack(alignment: .leading, spacing: 14) {
            if model.generalSettings != nil {
                Form {
                    Section("Updates") {
                        Toggle("Check for CKAN updates on launch", isOn: $checkForUpdatesOnLaunch)
                            .disabled(isBusy)
                        Toggle("Use CKAN dev builds", isOn: $useDevBuilds)
                            .disabled(isBusy)
                    }

                    Section("Repositories") {
                        Toggle("Update repositories on launch", isOn: $refreshRepositoriesOnLaunch)
                            .disabled(isBusy)
                    }

                    Section("Catalog") {
                        Toggle("Auto-sort by update after staging upgrades", isOn: $autoSortByUpdate)
                            .disabled(isBusy)
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        reloadSettings()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)

                    Spacer()

                    Button("Save") {
                        saveSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy)
                }
            } else {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        }
        .task {
            if model.generalSettings == nil {
                await loadSettings()
            }
        }
        .onAppear {
            sync(from: model.generalSettings)
        }
        .onChange(of: model.generalSettings) { settings in
            sync(from: settings)
        }
        .alert("General settings update failed", isPresented: settingsErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearSettingsError()
            }
        } message: {
            Text(model.settingsError ?? "")
        }
    }

    private var settingsErrorIsPresented: Binding<Bool> {
        Binding {
            model.settingsError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearSettingsError()
            }
        }
    }

    private func loadSettings() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadGeneralSettings()
            statusMessage = nil
        } catch {
            // AppModel stores the settings error for this pane.
        }
    }

    private func reloadSettings() {
        Task {
            await loadSettings()
        }
    }

    private func saveSettings() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateGeneralSettings(
                    checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
                    useDevBuilds: useDevBuilds,
                    refreshRepositoriesOnLaunch: refreshRepositoriesOnLaunch,
                    autoSortByUpdate: autoSortByUpdate)
                statusMessage = "General settings saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func sync(from settings: GeneralSettingsResult?) {
        guard let settings else {
            return
        }
        checkForUpdatesOnLaunch = settings.checkForUpdatesOnLaunch
        useDevBuilds = settings.useDevBuilds
        refreshRepositoriesOnLaunch = settings.refreshRepositoriesOnLaunch
        autoSortByUpdate = settings.autoSortByUpdate
    }
}


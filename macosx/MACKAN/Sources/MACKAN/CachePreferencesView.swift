import AppKit
import SwiftUI

import MACKANKit

struct CachePreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var downloadCacheDir = ""
    @State private var cacheLimitMebibytes = ""
    @State private var isUnlimited = true
    @State private var cacheMigrationChoice: CacheMigrationChoice = .keep
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
        PreferencesPaneScrollView {
            VStack(alignment: .leading, spacing: 14) {
            if let settings = model.settings {
                Form {
                    TextField("Download cache folder", text: $downloadCacheDir)

                    HStack {
                        Button {
                            chooseCacheFolder()
                        } label: {
                            Label("Choose", systemImage: "folder")
                        }
                        .disabled(isBusy)

                        Button {
                            downloadCacheDir = settings.defaultDownloadCacheDir
                        } label: {
                            Label("Use Default", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(isBusy || downloadCacheDir == settings.defaultDownloadCacheDir)
                    }

                    Toggle("Unlimited cache size", isOn: $isUnlimited)

                    TextField("Maximum cache size (MiB)", text: $cacheLimitMebibytes)
                        .disabled(isBusy || isUnlimited)

                    if cacheFolderChanged(from: settings) {
                        Picker("Existing cache files", selection: $cacheMigrationChoice) {
                            ForEach(CacheMigrationChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .disabled(isBusy)
                    }

                    LabeledContent("Current limit", value: settings.cacheSizeLimitDisplay)
                    LabeledContent("Default folder", value: settings.defaultDownloadCacheDir)
                }

                if !isUnlimited && parsedCacheLimitBytes == nil {
                    Label("Enter a whole number of MiB.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                    .disabled(isBusy || !canSave)
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
            if model.settings == nil {
                await loadSettings()
            }
        }
        .onAppear {
            sync(from: model.settings)
        }
        .onChange(of: model.settings) { settings in
            sync(from: settings)
        }
        .alert("Settings update failed", isPresented: settingsErrorIsPresented) {
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

    private var parsedCacheLimitBytes: Int64? {
        guard !isUnlimited else {
            return nil
        }
        let trimmed = cacheLimitMebibytes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mebibytes = Int64(trimmed),
              mebibytes >= 0,
              mebibytes <= Int64.max / 1_048_576 else {
            return nil
        }
        return mebibytes * 1_048_576
    }

    private var canSave: Bool {
        !downloadCacheDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (isUnlimited || parsedCacheLimitBytes != nil)
    }

    private func loadSettings() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadSettings()
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
                try await model.updateSettings(
                    downloadCacheDir: downloadCacheDir,
                    cacheSizeLimitBytes: parsedCacheLimitBytes,
                    cacheMigrationChoice: cacheMigrationChoice)
                statusMessage = "Cache settings saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func chooseCacheFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            downloadCacheDir = url.path
        }
    }

    private func sync(from settings: SettingsResult?) {
        guard let settings else {
            return
        }
        downloadCacheDir = settings.downloadCacheDir
        cacheMigrationChoice = .keep
        if let bytes = settings.cacheSizeLimitBytes {
            isUnlimited = false
            cacheLimitMebibytes = String(bytes / 1_048_576)
        } else {
            isUnlimited = true
            cacheLimitMebibytes = ""
        }
    }

    private func cacheFolderChanged(from settings: SettingsResult) -> Bool {
        downloadCacheDir.trimmingCharacters(in: .whitespacesAndNewlines) != settings.downloadCacheDir
    }
}


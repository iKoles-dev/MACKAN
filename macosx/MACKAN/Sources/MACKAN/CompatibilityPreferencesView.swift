import AppKit
import SwiftUI

import MACKANKit

struct CompatibilityPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var selectedVersions: Set<String> = []
    @State private var customVersion = ""
    @State private var isBusy = false
    @State private var statusMessage: String?

    var body: some View {
        PreferencesPaneScrollView {
            VStack(alignment: .leading, spacing: 12) {
            if let instance = model.selectedInstance {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instance.name)
                            .font(.headline)
                        Text(instance.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Button {
                        reloadVersions()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)
                }

                if let result = model.compatibleGameVersions {
                    Form {
                        LabeledContent("Game", value: result.game)
                        LabeledContent("Current game version", value: result.actualGameVersion ?? "Unknown")
                        LabeledContent("Saved for game version", value: result.gameVersionWhenWritten ?? "Default set")
                        LabeledContent("Known versions", value: result.knownVersions.count.formatted())
                    }

                    if result.compatibleVersionsAreFromDifferentGameVersion {
                        Label("Saved compatibility was created for a different game version.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    List(displayVersions, id: \.self) { version in
                        Toggle(isOn: versionBinding(version)) {
                            HStack(spacing: 8) {
                                Text(version)
                                    .monospacedDigit()
                                if result.knownVersions.contains(version) {
                                    Text("known")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)

                    HStack {
                        TextField("Custom game version", text: $customVersion)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isBusy)
                            .onSubmit(addCustomVersion)

                        Button {
                            addCustomVersion()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(isBusy || !canAddCustomVersion)
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button(role: .destructive) {
                            selectedVersions.removeAll()
                        } label: {
                            Label("Clear Selection", systemImage: "xmark.circle")
                        }
                        .disabled(isBusy || selectedVersions.isEmpty)

                        Spacer()

                        Button {
                            saveVersions()
                        } label: {
                            Label("Save", systemImage: "checkmark")
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
            } else {
                Spacer()
                Label("No game instance selected.", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        }
        .task {
            await loadVersions()
        }
        .onChange(of: model.selectedInstanceID) { _ in
            Task {
                await loadVersions()
            }
        }
        .onChange(of: model.compatibleGameVersions) { result in
            sync(from: result)
        }
        .alert("Compatibility update failed", isPresented: settingsErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearSettingsError()
            }
        } message: {
            Text(model.settingsError ?? "")
        }
    }

    private var displayVersions: [String] {
        guard let result = model.compatibleGameVersions else {
            return selectedVersions.sorted()
        }
        let availableSet = Set(result.availableVersions)
        let customSelections = selectedVersions
            .filter { !availableSet.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return result.availableVersions + customSelections
    }

    private var canAddCustomVersion: Bool {
        let version = cleanedCustomVersion
        return !version.isEmpty
            && version.localizedCaseInsensitiveCompare("any") != .orderedSame
            && !selectedVersions.contains(version)
    }

    private var cleanedCustomVersion: String {
        customVersion.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func versionBinding(_ version: String) -> Binding<Bool> {
        Binding {
            selectedVersions.contains(version)
        } set: { isSelected in
            if isSelected {
                selectedVersions.insert(version)
            } else {
                selectedVersions.remove(version)
            }
        }
    }

    private func loadVersions() async {
        guard model.selectedInstance != nil else {
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await model.loadCompatibleGameVersions()
            statusMessage = nil
        } catch {
            statusMessage = nil
        }
    }

    private func reloadVersions() {
        Task {
            await loadVersions()
        }
    }

    private func saveVersions() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.updateCompatibleGameVersions(
                    selectedVersions.sorted { $0.localizedStandardCompare($1) == .orderedDescending })
                statusMessage = "Compatibility settings saved."
            } catch {
                statusMessage = nil
            }
        }
    }

    private func addCustomVersion() {
        guard canAddCustomVersion else {
            return
        }
        selectedVersions.insert(cleanedCustomVersion)
        customVersion = ""
    }

    private func sync(from result: CompatibleGameVersionsResult?) {
        guard let result else {
            selectedVersions = []
            return
        }
        selectedVersions = Set(result.compatibleVersions)
    }
}


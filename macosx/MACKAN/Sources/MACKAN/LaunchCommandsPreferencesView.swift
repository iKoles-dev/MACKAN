import AppKit
import SwiftUI

import MACKANKit

struct LaunchCommandsPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var commandLines: [String] = []
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
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
                        reloadCommands()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(isBusy)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Command lines")
                        .font(.headline)
                    List {
                        ForEach(commandLines.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("Command line", text: Binding(
                                    get: { commandLines.indices.contains(index) ? commandLines[index] : "" },
                                    set: { value in
                                        if commandLines.indices.contains(index) {
                                            commandLines[index] = value
                                            statusMessage = nil
                                            errorMessage = nil
                                        }
                                    }))
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    removeCommandLine(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isBusy || commandLines.count <= 1)
                                .help("Remove command line")
                            }
                        }
                    }
                    .frame(minHeight: 275)
                }

                if !model.defaultLaunchCommands.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Defaults")
                            .font(.headline)
                        ForEach(model.defaultLaunchCommands, id: \.self) { commandLine in
                            Text(commandLine)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button {
                        addCommandLine()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(isBusy)

                    Button(role: .destructive) {
                        resetCommandsToDefaults()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isBusy || !canResetToDefaults)

                    Spacer()

                    Button {
                        saveCommands()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBusy || cleanedCommandLines.isEmpty || cleanedCommandLines == model.launchCommands)
                }
            } else {
                Spacer()
                Label("No game instance selected.", systemImage: "shippingbox")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .task {
            syncFromModel()
        }
        .onChange(of: model.selectedInstanceID) { _ in
            syncFromModel()
        }
        .onChange(of: model.launchCommands) { _ in
            syncFromModel()
        }
    }

    private var cleanedCommandLines: [String] {
        commandLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canResetToDefaults: Bool {
        !model.defaultLaunchCommands.isEmpty && cleanedCommandLines != model.defaultLaunchCommands
    }

    private func syncFromModel() {
        let source = model.launchCommands.isEmpty ? model.defaultLaunchCommands : model.launchCommands
        commandLines = source.isEmpty ? [""] : source
        statusMessage = nil
        errorMessage = nil
    }

    private func addCommandLine() {
        commandLines.append("")
        statusMessage = nil
        errorMessage = nil
    }

    private func removeCommandLine(at index: Int) {
        guard commandLines.count > 1, commandLines.indices.contains(index) else {
            return
        }
        commandLines.remove(at: index)
        statusMessage = nil
        errorMessage = nil
    }

    private func reloadCommands() {
        Task {
            isBusy = true
            defer { isBusy = false }
            await model.selectInstance(model.selectedInstanceID)
            syncFromModel()
        }
    }

    private func resetCommandsToDefaults() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.resetLaunchCommandsToDefaults()
                statusMessage = "Default command lines saved."
                errorMessage = nil
            } catch {
                errorMessage = model.launchError ?? error.localizedDescription
                statusMessage = nil
            }
        }
    }

    private func saveCommands() {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                try await model.saveLaunchCommands(commandLines)
                statusMessage = "Command lines saved."
                errorMessage = nil
            } catch {
                errorMessage = model.launchError ?? error.localizedDescription
                statusMessage = nil
            }
        }
    }
}


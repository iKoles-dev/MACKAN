import AppKit
import SwiftUI

import MACKANKit

struct LaunchCommandLinesSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var commandLines: [String] = []
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Game Command Lines")
                .font(.headline)

            List {
                ForEach(commandLines.indices, id: \.self) { index in
                    HStack {
                        TextField("Command line", text: Binding(
                            get: { commandLines.indices.contains(index) ? commandLines[index] : "" },
                            set: { value in
                                if commandLines.indices.contains(index) {
                                    commandLines[index] = value
                                }
                            }))
                        Button {
                            removeCommandLine(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(commandLines.count <= 1)
                        .help("Remove command line")
                    }
                }
            }
            .frame(minHeight: 180)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button {
                    commandLines.append("")
                } label: {
                    Label("Add", systemImage: "plus")
                }
                Button("Reset to Defaults") {
                    commandLines = model.defaultLaunchCommands
                }
                .disabled(model.defaultLaunchCommands.isEmpty || cleanedCommandLines == model.defaultLaunchCommands)
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || cleanedCommandLines.isEmpty)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .onAppear {
            commandLines = model.launchCommands.isEmpty ? model.defaultLaunchCommands : model.launchCommands
        }
    }

    private var cleanedCommandLines: [String] {
        commandLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func removeCommandLine(at index: Int) {
        guard commandLines.count > 1, commandLines.indices.contains(index) else {
            return
        }
        commandLines.remove(at: index)
    }

    private func save() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await model.saveLaunchCommands(commandLines)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AddInstanceSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var path = ""
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Game Instance")
                .font(.headline)

            Form {
                HStack {
                    TextField("Game folder", text: $path)
                    Button {
                        chooseGameFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .disabled(isAdding)
                }

                TextField("Instance name", text: $name)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Add") {
                    addInstance()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isAdding || !canAdd)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }

    private var canAdd: Bool {
        !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func chooseGameFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = url.lastPathComponent
            }
            // Persist a security-scoped bookmark so MACKAN can regain access
            // to this directory on future launches without a file picker dialog.
            model.storeInstanceBookmark(for: url)
        }
    }

    private func addInstance() {
        Task {
            isAdding = true
            defer { isAdding = false }
            do {
                try await model.addInstance(path: path, name: name)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CloneInstanceSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var sourceInstanceId = ""
    @State private var newName = ""
    @State private var newPath = ""
    @State private var shareStock = false
    @State private var leaveEmptyPaths: [String] = []
    @State private var selectedLeaveEmptyPaths = Set<String>()
    @State private var loadedCloneOptionsSourceId: String?
    @State private var cloneOptionsError: String?
    @State private var errorMessage: String?
    @State private var isLoadingCloneOptions = false
    @State private var isCloning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Clone Game Instance")
                .font(.headline)

            Form {
                Picker("Source instance", selection: $sourceInstanceId) {
                    ForEach(sourceInstances) { instance in
                        Text(instance.name).tag(instance.id)
                    }
                }
                .disabled(isCloning || sourceInstances.isEmpty)

                TextField("New instance name", text: $newName)
                    .disabled(isCloning)

                HStack {
                    TextField("Destination folder", text: $newPath)
                    Button {
                        chooseDestinationFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .disabled(isCloning)
                }

                Toggle("Share stock folders with symlinks", isOn: $shareStock)
                    .disabled(isCloning)

                Section("Leave Empty") {
                    if isLoadingCloneOptions {
                        ProgressView("Loading")
                    }

                    ForEach(leaveEmptyPaths, id: \.self) { path in
                        Toggle(path, isOn: leaveEmptyBinding(for: path))
                            .disabled(isCloning || isLoadingCloneOptions)
                    }

                    if let cloneOptionsError {
                        Text(cloneOptionsError)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Clone") {
                    cloneInstance()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isCloning || isLoadingCloneOptions || !canClone)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .onAppear {
            initializeSourceAndDefaults()
            loadCloneOptions()
        }
        .onChange(of: sourceInstanceId) { _ in
            seedDefaultsIfBlank()
            loadCloneOptions()
        }
    }

    private var sourceInstances: [GameInstanceSummary] {
        model.instances.filter(\.isValid)
    }

    private var sourceInstance: GameInstanceSummary? {
        sourceInstances.first { $0.id == sourceInstanceId }
    }

    private var canClone: Bool {
        sourceInstance != nil
            && !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !newPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var leaveEmptyPathsForClone: [String]? {
        guard loadedCloneOptionsSourceId == sourceInstanceId else {
            return nil
        }
        return leaveEmptyPaths.filter { selectedLeaveEmptyPaths.contains($0) }
    }

    private func initializeSourceAndDefaults() {
        if sourceInstanceId.isEmpty {
            sourceInstanceId = model.selectedInstanceID
                .flatMap { selectedID in sourceInstances.first { $0.id == selectedID }?.id }
                ?? sourceInstances.first?.id
                ?? ""
        }
        seedDefaultsIfBlank()
    }

    private func seedDefaultsIfBlank() {
        guard let sourceInstance else {
            return
        }
        if newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newName = "\(sourceInstance.name) Clone"
        }
        if newPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sourceURL = URL(fileURLWithPath: sourceInstance.path, isDirectory: true)
            let parent = sourceURL.deletingLastPathComponent()
            let proposedName = "\(sourceURL.lastPathComponent) Clone"
            newPath = parent.appendingPathComponent(proposedName, isDirectory: true).path
        }
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            newPath = url.path
            // Persist a security-scoped bookmark for the chosen destination.
            model.storeInstanceBookmark(for: url)
        }
    }

    private func leaveEmptyBinding(for path: String) -> Binding<Bool> {
        Binding(
            get: {
                selectedLeaveEmptyPaths.contains(path)
            },
            set: { isSelected in
                if isSelected {
                    selectedLeaveEmptyPaths.insert(path)
                } else {
                    selectedLeaveEmptyPaths.remove(path)
                }
            })
    }

    private func loadCloneOptions() {
        let requestedSourceId = sourceInstanceId
        guard !requestedSourceId.isEmpty else {
            leaveEmptyPaths = []
            selectedLeaveEmptyPaths.removeAll()
            loadedCloneOptionsSourceId = nil
            cloneOptionsError = nil
            isLoadingCloneOptions = false
            return
        }

        leaveEmptyPaths = []
        selectedLeaveEmptyPaths.removeAll()
        loadedCloneOptionsSourceId = nil
        cloneOptionsError = nil
        isLoadingCloneOptions = true

        Task { @MainActor in
            do {
                let options = try await model.loadCloneOptions(sourceInstanceId: requestedSourceId)
                guard sourceInstanceId == requestedSourceId else {
                    return
                }
                leaveEmptyPaths = options.leaveEmptyPaths
                selectedLeaveEmptyPaths = Set(options.leaveEmptyPaths)
                loadedCloneOptionsSourceId = requestedSourceId
            } catch {
                guard sourceInstanceId == requestedSourceId else {
                    return
                }
                cloneOptionsError = error.localizedDescription
            }
            isLoadingCloneOptions = false
        }
    }

    private func cloneInstance() {
        Task {
            isCloning = true
            defer { isCloning = false }
            do {
                try await model.cloneInstance(
                    sourceInstanceId: sourceInstanceId,
                    newName: newName,
                    newPath: newPath,
                    shareStock: shareStock,
                    leaveEmptyPaths: leaveEmptyPathsForClone)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct FakeInstanceSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var path = ""
    @State private var version = ""
    @State private var gameId = "KSP"
    @State private var makingHistoryVersion = ""
    @State private var breakingGroundVersion = ""
    @State private var setDefault = false
    @State private var errorMessage: String?
    @State private var isFaking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fake Game Instance")
                .font(.headline)

            Form {
                Picker("Game", selection: $gameId) {
                    Text("KSP").tag("KSP")
                    Text("KSP2").tag("KSP2")
                }
                .pickerStyle(.segmented)
                .disabled(isFaking)

                TextField("Instance name", text: $name)
                    .disabled(isFaking)

                HStack {
                    TextField("Destination folder", text: $path)
                    Button {
                        chooseDestinationFolder()
                    } label: {
                        Label("Choose", systemImage: "folder")
                    }
                    .disabled(isFaking)
                }

                TextField("Game version", text: $version)
                    .disabled(isFaking)

                TextField("Making History DLC version", text: $makingHistoryVersion)
                    .disabled(isFaking || gameId != "KSP")

                TextField("Breaking Ground DLC version", text: $breakingGroundVersion)
                    .disabled(isFaking || gameId != "KSP")

                Toggle("Set as default instance", isOn: $setDefault)
                    .disabled(isFaking)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    fakeInstance()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isFaking || !canFake)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .onAppear {
            seedDefaults()
        }
        .onChange(of: gameId) { _ in
            if gameId != "KSP" {
                makingHistoryVersion = ""
                breakingGroundVersion = ""
            }
        }
    }

    private var canFake: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedInstance: GameInstanceSummary? {
        model.selectedInstanceID.flatMap { selectedID in
            model.instances.first { $0.id == selectedID }
        }
    }

    private func seedDefaults() {
        if let selectedInstance {
            gameId = selectedInstance.game
            version = selectedInstance.gameVersion
            name = "\(selectedInstance.game) Fake"
            let sourceURL = URL(fileURLWithPath: selectedInstance.path, isDirectory: true)
            let parent = sourceURL.deletingLastPathComponent()
            path = parent.appendingPathComponent("\(selectedInstance.game) Fake", isDirectory: true).path
        } else {
            name = "KSP Fake"
            path = ("~/Games/KSP-Fake" as NSString).expandingTildeInPath
        }
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func fakeInstance() {
        Task {
            isFaking = true
            defer { isFaking = false }
            do {
                try await model.fakeInstance(
                    name: name,
                    path: path,
                    version: version,
                    gameId: gameId,
                    makingHistoryVersion: makingHistoryVersion,
                    breakingGroundVersion: breakingGroundVersion,
                    setDefault: setDefault)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum ModpackRelationshipKind: String, CaseIterable, Identifiable {
    case depends
    case recommends
    case suggests
    case ignore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .depends:
            "Depends"
        case .recommends:
            "Recommends"
        case .suggests:
            "Suggests"
        case .ignore:
            "Ignore"
        }
    }
}


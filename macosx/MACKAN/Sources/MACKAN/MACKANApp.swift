import AppKit
import SwiftUI
import UniformTypeIdentifiers

import MACKANKit

@main
struct MACKANApp: App {
    @StateObject private var model: AppModel
    @State private var isScanningGameData = false
    @State private var isLoadingUnmanagedFiles = false
    @State private var isLoadingInstallationHistory = false
    @State private var isLoadingPlayTime = false
    @State private var isLoadingDownloadStatistics = false
    @State private var isLoadingCacheInfo = false
    @State private var isDeduplicatingFiles = false
    @State private var isRepairingRegistry = false
    @State private var isConfirmingDeduplicate = false
    @State private var isConfirmingRepairRegistry = false
    @State private var isShowingDiagnosticsCopyAlert = false
    @State private var diagnosticsCopyMessage = ""

    init() {
        _model = StateObject(wrappedValue: Self.makeAppModel())
        Self.installApplicationIcon()
    }

    private static func makeAppModel() -> AppModel {
        AppModel(
            sidecar: SidecarClient.defaultClient(),
            previewSidecar: SidecarClient.defaultClient(),
            catalogSnapshotStore: FileModuleCatalogSnapshotStore())
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(
                model: model,
                onCopyDiagnostics: copyDiagnosticsReport)
                .frame(
                    minWidth: CGFloat(MainWindowLayoutPolicy.minimumWindowWidth),
                    minHeight: CGFloat(MainWindowLayoutPolicy.minimumWindowHeight))
                .background(MainWindowPlacementGuard())
                .dynamicTypeSize(.xSmall ... .accessibility2)
                .accessibilityLabel("MACKAN main window")
                .sheet(item: $model.activeSheet) { sheet in
                    switch sheet {
                    case .editLaunchCommandLines:
                        LaunchCommandLinesSheet(model: model)
                    case .manageInstances:
                        InstanceManagementSheet(
                            model: model,
                            onAdd: { model.presentSheet(.addInstance) },
                            onClone: { model.presentSheet(.cloneInstance) },
                            onFake: { model.presentSheet(.fakeInstance) })
                    case .addInstance:
                        AddInstanceSheet(model: model)
                    case .cloneInstance:
                        CloneInstanceSheet(model: model)
                    case .fakeInstance:
                        FakeInstanceSheet(model: model)
                    case .exportModpack:
                        ExportModpackSheet(model: model)
                    case .about:
                        AboutMACKANSheet(info: model.aboutInfo())
                    case .updateCheck:
                        UpdateCheckSheet(
                            model: model,
                            onCheckStable: { checkForUpdates(useDevBuilds: false) },
                            onCheckDev: { checkForUpdates(useDevBuilds: true) })
                    }
                }
                .confirmationDialog(
                    "Deduplicate installed files?",
                    isPresented: $isConfirmingDeduplicate
                ) {
                    Button("Deduplicate Files", role: .destructive) {
                        deduplicateFiles()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("MACKAN will scan all game instances and replace duplicate installed files with hard links where CKAN Core allows it.")
                }
                .confirmationDialog(
                    "Repair selected CKAN registry?",
                    isPresented: $isConfirmingRepairRegistry
                ) {
                    Button("Repair Registry", role: .destructive) {
                        repairRegistry()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("MACKAN will rebuild CKAN's installed-file index for the selected game instance and save the repaired registry.")
                }
                .alert("Diagnostics Copied", isPresented: $isShowingDiagnosticsCopyAlert) {
                    Button("OK") {}
                } message: {
                    Text(diagnosticsCopyMessage)
                }
                .task {
                    await model.refreshHealth()
                    // Restore security-scoped access for all known game instance directories.
                    // This enables MACKAN to read/write instance folders on subsequent launches
                    // without showing a file picker dialog, even under Hardened Runtime restrictions.
                    model.restoreInstanceBookmarks()
                    if await model.checkForUpdatesOnLaunchIfNeeded() {
                        model.presentSheet(.updateCheck)
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .defaultSize(
            width: MainWindowLayoutPolicy.defaultWindowWidth,
            height: MainWindowLayoutPolicy.defaultWindowHeight)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MACKAN") {
                    model.presentSheet(.about)
                }
            }

            CommandMenu("Instance") {
                Button("Manage Instances...") {
                    model.presentSheet(.manageInstances)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Divider()
                Button("Add Instance") {
                    model.presentSheet(.addInstance)
                }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Clone Instance") {
                    model.presentSheet(.cloneInstance)
                }
                .disabled(!canCloneSelectedInstance)
                Button("Fake Instance") {
                    model.presentSheet(.fakeInstance)
                }
                Button("Set Selected as Default") {
                    Task {
                        do {
                            try await model.setSelectedInstanceAsDefault()
                        } catch {
                            model.healthState = .failed(error.localizedDescription)
                        }
                    }
                }
                .disabled(!model.canSetSelectedInstanceAsDefault)
                Button("Open Game Folder") {
                    do {
                        try model.openSelectedInstanceDirectory()
                    } catch {
                        model.healthState = .failed(error.localizedDescription)
                    }
                }
                .disabled(!model.canOpenSelectedInstanceDirectory)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Launch Game") {
                    launchGame(nil)
                }
                .disabled(!model.canLaunchSelectedGame)
                .keyboardShortcut("r", modifiers: [.command])
                Menu("Launch With Command Line") {
                    ForEach(model.launchCommands, id: \.self) { commandLine in
                        Button(commandLine) {
                            launchGame(commandLine)
                        }
                        .disabled(model.isLaunchingGame)
                    }
                    Divider()
                    Button("Edit Command Lines...") {
                        model.presentSheet(.editLaunchCommandLines)
                    }
                }
                .disabled(model.selectedInstance == nil)
            }

            CommandMenu("Mods") {
                Button("Refresh Repositories") {
                    refreshRepositories()
                }
                .disabled(!model.canRefreshRepositories)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Upgrade All") {
                    model.stageUpgradeAll()
                }
                .disabled(!model.canStageUpgradeAll)
                Button("Apply Changes") {
                    model.applyChangesTrigger = true
                }
                .disabled(!model.canApplyPendingChangeSet)
                .keyboardShortcut(.return, modifiers: [.command])
                Divider()
                Button("Install from File") {
                    model.installFromCkanFileTrigger = true
                }
                .disabled(!model.canRefreshRepositories)
                Button("Import Downloads") {
                    model.importDownloadsTrigger = true
                }
                .disabled(!model.canRefreshRepositories)
                Menu("Export Mod List") {
                    ForEach(ModListExportFormat.allCases) { format in
                        Button(format.title) {
                            exportModList(format)
                        }
                    }
                }
                .disabled(!model.canRefreshRepositories)
                Button("Export Modpack") {
                    model.presentSheet(.exportModpack)
                }
                .disabled(!model.canRefreshRepositories)
            }

            CommandMenu("Maintenance") {
                Button("Scan GameData") {
                    scanGameData()
                }
                .disabled(!model.canRefreshRepositories || isScanningGameData)
                Button("View Unmanaged Files") {
                    model.showMaintenancePane(.unmanagedFiles)
                }
                .disabled(!model.canRefreshRepositories || isLoadingUnmanagedFiles)
                Button("Installation History") {
                    model.showMaintenancePane(.history)
                }
                .disabled(!model.canRefreshRepositories || isLoadingInstallationHistory)
                Button("Play Time") {
                    model.showMaintenancePane(.playTime)
                }
                .disabled(isLoadingPlayTime)
                Button("Download Statistics") {
                    model.showMaintenancePane(.downloadStatistics)
                }
                .disabled(!model.canRefreshRepositories || isLoadingDownloadStatistics)
                Button("Deduplicate Files") {
                    isConfirmingDeduplicate = true
                }
                .disabled(isDeduplicatingFiles)
                Button("Repair Registry") {
                    isConfirmingRepairRegistry = true
                }
                .disabled(!model.canRefreshRepositories || isRepairingRegistry)
                Button("Clean Cache") {
                    model.showMaintenancePane(.cache)
                }
                .disabled(isLoadingCacheInfo)
            }

            CommandGroup(replacing: .help) {
                Button {
                    showUpdateCheck()
                } label: {
                    Label("Check for Updates", systemImage: "arrow.down.circle")
                }
                .disabled(model.isCheckingForUpdates)

                Divider()

                ForEach(MACKANHelpLink.coreLinks) { link in
                    helpLinkButton(link)
                }

                let gameSupportLinks = MACKANHelpLink.gameSupportLinks(for: model.selectedInstance?.game)
                if !gameSupportLinks.isEmpty {
                    Divider()
                    ForEach(gameSupportLinks) { link in
                        helpLinkButton(link)
                    }
                }

                Divider()
                ForEach(MACKANHelpLink.reportLinks(
                    for: model.selectedInstance?.game,
                    selectedModule: selectedModuleHelpContext
                )) { link in
                    helpLinkButton(link)
                }
            }
        }

        Settings {
            PreferencesView(model: model)
        }
    }

    private static func installApplicationIcon() {
        guard let iconURL = Bundle.main.url(forResource: "MACKAN", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }
        NSApplication.shared.applicationIconImage = icon
    }

    private var canCloneSelectedInstance: Bool {
        guard let selectedInstanceID = model.selectedInstanceID else {
            return false
        }
        return model.instances.contains { $0.id == selectedInstanceID && $0.isValid }
    }

    private var selectedModuleHelpContext: ModuleHelpContext? {
        guard let selectedModuleID = model.selectedModuleID else {
            return nil
        }
        let module = model.selectedModuleDetails?.module
            ?? model.modules.first { $0.id == selectedModuleID }
        return module.map { ModuleHelpContext(identifier: $0.identifier, name: $0.name) }
    }



    private func launchGame(_ commandLine: String?) {
        Task {
            do {
                try await model.launchSelectedGame(commandLine: commandLine)
            } catch {
                // AppModel stores launch error details for the launch failure alert.
            }
        }
    }

    private func refreshRepositories() {
        Task {
            do {
                try await model.refreshRepositories(force: true)
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }

    private func showUpdateCheck() {
        model.presentSheet(.updateCheck)
        checkForUpdates(useDevBuilds: nil)
    }

    private func checkForUpdates(useDevBuilds: Bool?) {
        Task {
            do {
                try await model.checkForUpdates(useDevBuilds: useDevBuilds)
            } catch {
                // AppModel stores the user-facing update check error for the sheet.
            }
        }
    }

    @MainActor
    private func scanGameData() {
        Task { @MainActor in
            isScanningGameData = true
            defer { isScanningGameData = false }
            do {
                try await model.scanGameData()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func loadUnmanagedFiles() {
        Task { @MainActor in
            isLoadingUnmanagedFiles = true
            defer { isLoadingUnmanagedFiles = false }
            do {
                try await model.loadUnmanagedFiles()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func loadInstallationHistory() {
        Task { @MainActor in
            isLoadingInstallationHistory = true
            defer { isLoadingInstallationHistory = false }
            do {
                try await model.loadInstallationHistory()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func loadPlayTime() {
        Task { @MainActor in
            isLoadingPlayTime = true
            defer { isLoadingPlayTime = false }
            do {
                try await model.loadPlayTime()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func loadDownloadStatistics() {
        Task { @MainActor in
            isLoadingDownloadStatistics = true
            defer { isLoadingDownloadStatistics = false }
            do {
                try await model.loadDownloadStatistics()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func loadCacheInfo() {
        Task { @MainActor in
            isLoadingCacheInfo = true
            defer { isLoadingCacheInfo = false }
            do {
                try await model.loadCacheInfo()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    private func helpLinkButton(_ link: MACKANHelpLink) -> some View {
        Button {
            openHelpLink(link)
        } label: {
            Label(link.title, systemImage: link.systemImage)
        }
    }

    private func openHelpLink(_ link: MACKANHelpLink) {
        if link.id == .reportClientIssue {
            copyDiagnosticsReport()
        }
        NSWorkspace.shared.open(link.url)
    }

    private func copyDiagnosticsReport() {
        let generatedAt = Date()
        let report = model.makeDiagnosticsReport(generatedAt: generatedAt)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)

        do {
            let bundle = try model.writeDiagnosticsBundle(generatedAt: generatedAt)
            diagnosticsCopyMessage = "A MACKAN diagnostic report was copied to the clipboard. An attachable diagnostics bundle was saved at \(bundle.archiveURL.path)."
        } catch {
            diagnosticsCopyMessage = "A MACKAN diagnostic report was copied to the clipboard, but the diagnostics bundle could not be created: \(error.localizedDescription)"
        }
        isShowingDiagnosticsCopyAlert = true
    }

    @MainActor
    private func deduplicateFiles() {
        Task { @MainActor in
            isDeduplicatingFiles = true
            defer { isDeduplicatingFiles = false }
            do {
                try await model.deduplicate()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func repairRegistry() {
        Task { @MainActor in
            isRepairingRegistry = true
            defer { isRepairingRegistry = false }
            do {
                try await model.repairRegistry()
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    @MainActor
    private func exportModList(_ format: ModListExportFormat) {
        Task { @MainActor in
            do {
                let result = try await model.exportModList(format: format)
                let configuration = ExportSavePanelConfiguration.modList(
                    suggestedFileName: result.suggestedFileName,
                    fileExtension: format.fileExtension,
                    defaultDirectoryURL: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
                let panel = NSSavePanel()
                panel.title = configuration.title
                panel.prompt = configuration.prompt
                panel.canCreateDirectories = configuration.canCreateDirectories
                panel.nameFieldStringValue = configuration.suggestedFileName
                panel.directoryURL = configuration.defaultDirectoryURL
                if let contentType = UTType(filenameExtension: configuration.allowedFileExtension) {
                    panel.allowedContentTypes = [contentType]
                }
                guard panel.runModal() == .OK, let url = panel.url else {
                    return
                }
                try result.contents.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }

    /// Handles incoming URLs opened by the system, including Spotlight deep-link results.
    ///
    /// Supported scheme: `mackan://mod/<identifier>`
    /// Selecting a Spotlight result for an installed mod opens MACKAN and selects that mod.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "mackan" else { return }
        if url.host?.lowercased() == "mod" {
            let identifier = url.lastPathComponent
            guard !identifier.isEmpty else { return }
            // If the mod is already in the loaded catalog, select it directly.
            if let match = model.modules.first(where: {
                $0.identifier.caseInsensitiveCompare(identifier) == .orderedSame
            }) {
                model.filter = .all
                model.searchText = ""
                model.selectedModuleID = match.id
            }
        }
    }
}


private struct AboutMACKANSheet: View {
    @Environment(\.dismiss) private var dismiss
    let info: AboutInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.title2.weight(.semibold))
                    Text(info.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(info.rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .trailing)
                        Text(row.value)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            HStack {
                Spacer()
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .mackanModalSheetFrame(.compact)
    }
}

private struct UpdateCheckSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onCheckStable: () -> Void
    let onCheckDev: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 34))
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MACKAN Updates")
                        .font(.title3.weight(.semibold))
                    Text(statusTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isCheckingForUpdates {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let result = model.updateCheckResult {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                    updateRow("Current", result.currentVersion)
                    updateRow("Latest", result.latestDisplayVersion ?? result.latestVersion ?? "Unavailable")
                    updateRow("Channel", result.useDevBuilds ? "Dev builds" : "Stable releases")
                    updateRow("Install", "Manual download required")
                }

                if !result.installMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(result.installMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !result.downloadUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Downloads")
                            .font(.headline)
                        ForEach(result.downloadUrls, id: \.self) { rawURL in
                            if let url = URL(string: rawURL) {
                                Link(rawURL, destination: url)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            } else {
                                Text(rawURL)
                                    .textSelection(.enabled)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }

                if let releaseNotes = result.releaseNotes,
                   !releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Release Notes")
                            .font(.headline)
                        ScrollView {
                            Text(releaseNotes)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(minHeight: 120, maxHeight: 220)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if let error = model.updateCheckError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Check Stable") {
                    onCheckStable()
                }
                .disabled(model.isCheckingForUpdates)

                Button("Check Dev Builds") {
                    onCheckDev()
                }
                .disabled(model.isCheckingForUpdates)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .mackanModalSheetFrame(.standard)
    }

    @ViewBuilder
    private func updateRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private var statusTitle: String {
        if model.isCheckingForUpdates {
            return "Checking..."
        }
        switch model.updateCheckResult?.status {
        case "available":
            return "Update available"
        case "current":
            return "MACKAN is current"
        case "failed":
            return "Update check failed"
        default:
            return "No check has run yet"
        }
    }

    private var statusSymbol: String {
        if model.isCheckingForUpdates {
            return "arrow.triangle.2.circlepath"
        }
        switch model.updateCheckResult?.status {
        case "available":
            return "arrow.down.circle.fill"
        case "current":
            return "checkmark.circle.fill"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "arrow.down.circle"
        }
    }

    private var statusColor: Color {
        if model.isCheckingForUpdates {
            return .accentColor
        }
        switch model.updateCheckResult?.status {
        case "available":
            return .accentColor
        case "current":
            return .green
        case "failed":
            return .red
        default:
            return .secondary
        }
    }
}

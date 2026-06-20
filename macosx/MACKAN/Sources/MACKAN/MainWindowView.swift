import AppKit
import SwiftUI
import UniformTypeIdentifiers

import MACKANKit

struct MackanSettingsButton<Label: View>: View {
    @ViewBuilder var label: () -> Label

    var body: some View {
        if #available(macOS 14.0, *) {
            MackanModernSettingsButton(label: label)
        } else {
            Button {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            } label: {
                label()
            }
        }
    }
}

@available(macOS 14.0, *)
struct MackanModernSettingsButton<Label: View>: View {
    @Environment(\.openSettings) private var openSettings
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            openSettings()
        } label: {
            label()
        }
    }
}

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @Binding var isInstallingFromCkanFile: Bool
    @Binding var isImportingDownloads: Bool
    @Binding var applyChangesRequestID: Int
    var onCopyDiagnostics: () -> Void = {}
    @State private var operationFlow = OperationFlowState()
    @State private var fileImports = FileImportFlowState()

    var body: some View {
        GeometryReader { geometry in
            let showSidebar = geometry.size.width >= CGFloat(MainWindowLayoutPolicy.sidebarVisibilityBreakpoint)
            let showInspector = MainWindowLayoutPolicy.shouldShowInspector(
                windowWidth: Double(geometry.size.width),
                hasSelectedModule: model.selectedModule != nil)

            HStack(spacing: 0) {
                if showSidebar {
                    SidebarView(model: model)
                        .frame(
                            minWidth: CGFloat(MainWindowLayoutPolicy.sidebarMinimumWidth),
                            idealWidth: 250,
                            maxWidth: 280)

                    Divider()
                }

                Group {
                    switch model.mainContentRoute {
                    case .catalog:
                        CatalogView(
                            model: model,
                            isResolvingChanges: operationFlow.isActive(.resolvingChanges),
                            isApplyingChanges: operationFlow.isActive(.applyingChanges),
                            onPreviewChanges: previewChanges,
                            onApplyChanges: {
                                applyChanges()
                            },
                            onClearChanges: {
                                model.clearAllStagedChanges()
                            })
                    case .maintenance(let pane):
                        MaintenanceCenterView(
                            model: model,
                            pane: pane,
                            onInstallHistoryModules: { modules, exactVersions in
                                installHistoryModules(modules, exactVersions: exactVersions)
                            },
                            onRevealUnmanagedFile: revealUnmanagedFile,
                            onUpdatePlayTime: { instanceId, hours in
                                await updatePlayTime(instanceId: instanceId, hours: hours)
                            },
                            onRefreshCache: {
                                await loadCacheInfo()
                            },
                            onPurgeCacheToLimit: {
                                await purgeCacheToLimit()
                            },
                            onPurgeAllCache: {
                                await clearCache()
                            })
                    }
                }
                .frame(
                    minWidth: CGFloat(MainWindowLayoutPolicy.contentMinimumWidth),
                    maxWidth: .infinity)

                if showInspector {
                    Divider()

                    InspectorView(
                        module: model.selectedModule,
                        details: model.selectedModuleDetails,
                        emptyState: model.inspectorEmptyState)
                        .frame(
                            minWidth: CGFloat(MainWindowLayoutPolicy.inspectorMinimumWidth),
                            idealWidth: 340,
                            maxWidth: 420)
                }
            }
        }
        .onChange(of: model.selectedModuleID) { _ in
            Task { await model.refreshSelectedModuleDetails() }
        }
        .onChange(of: applyChangesRequestID) { _ in
            guard model.canApplyPendingChangeSet else {
                return
            }
            applyChanges()
        }
        .onChange(of: isInstallingFromCkanFile) { isPresented in
            guard isPresented else {
                return
            }
            DispatchQueue.main.async {
                presentCkanFileOpenPanel()
            }
        }
        .onChange(of: isImportingDownloads) { isPresented in
            guard isPresented else {
                return
            }
            DispatchQueue.main.async {
                presentImportDownloadsOpenPanel()
            }
        }
        .task(id: repositoryRefreshPollingID) {
            guard model.repositoryRefreshSummary?.isActive == true else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                await refreshRepositoryRefreshStatus()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    refreshRepositories()
                } label: {
                    Label("Refresh Repositories", systemImage: "arrow.clockwise")
                }
                .disabled(!model.canRefreshRepositories || operationFlow.isActive(.refreshingRepositories))
                .accessibilityLabel("Refresh Repositories")
                .accessibilityHint("Reloads repositories and refreshes catalog data.")
                .help("Refresh repositories and reload catalog data")

                if selectedModuleActionPresentation.usesMenu {
                    Menu {
                        ForEach(selectedModuleActionPresentation.availableActions, id: \.rawValue) { action in
                            Button {
                                stageSelectedModule(action)
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
                    Button {
                        stageSelectedModule()
                    } label: {
                        Label(
                            selectedModuleActionPresentation.accessibilityLabel,
                            systemImage: selectedModuleActionPresentation.symbolName)
                    }
                    .disabled(selectedModuleActionPresentation.title == nil)
                    .accessibilityLabel(selectedModuleActionPresentation.accessibilityLabel)
                    .help(selectedModuleActionPresentation.help)
                }

                Button {
                    previewChanges()
                } label: {
                    Label("Preview Changes", systemImage: "list.bullet.rectangle")
                }
                .disabled(!model.hasPendingSelections || operationFlow.isActive(.resolvingChanges))
                .accessibilityLabel("Preview Changes")
                .accessibilityHint("Open staged module change preview.")
                .help("Preview staged module changes")

                Button {
                    applyChanges()
                } label: {
                    Label("Apply Changes", systemImage: "checkmark.circle")
                }
                .disabled(!model.canApplyPendingChangeSet || operationFlow.isActive(.applyingChanges))
                .accessibilityLabel("Apply Changes")
                .accessibilityHint("Apply pending catalog changes to selected game instance.")
                .help("Apply pending changes")

                Button {
                    model.stageUpgradeAll()
                } label: {
                    Label("Upgrade All", systemImage: "square.and.arrow.down")
                }
                .disabled(!model.canStageUpgradeAll)
                .accessibilityLabel("Upgrade All")
                .help("Stage all available upgrades")

                Button {
                    isInstallingFromCkanFile = true
                } label: {
                    Label("Install from File", systemImage: "doc.badge.plus")
                }
                .disabled(!model.canRefreshRepositories || operationFlow.isActive(.installingCkanFiles))
                .accessibilityLabel("Install from File")
                .accessibilityHint("Open file picker to install CKAN files.")
                .help("Install mods from local .ckan files")

                Button {
                    isImportingDownloads = true
                } label: {
                    Label("Import Downloads", systemImage: "tray.and.arrow.down")
                }
                .disabled(!model.canRefreshRepositories || operationFlow.isActive(.importingDownloadFiles))
                .accessibilityLabel("Import Downloads")
                .accessibilityHint("Open file picker for local downloads import.")
                .help("Import local downloaded mod archives")

                Button {
                    model.clearAllStagedChanges()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .disabled(!model.hasPendingSelections)
                .accessibilityLabel("Clear pending changes")
                .help("Clear staged changes")

                Button {
                    launchSelectedGame()
                } label: {
                    Label(model.isLaunchingGame ? "Launching Game" : "Launch Game", systemImage: "play.fill")
                }
                .disabled(!model.canLaunchSelectedGame)
                .accessibilityLabel(model.isLaunchingGame ? "Launching Game" : "Launch Game")
                .accessibilityHint("Start the selected game instance.")
                .help(model.isLaunchingGame ? "Launching game..." : "Launch selected game")

                Button {
                    openSelectedGameFolder()
                } label: {
                    Label("Open Game Folder", systemImage: "folder")
                }
                .disabled(!model.canOpenSelectedInstanceDirectory)
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
        .sheet(isPresented: operationSheetIsPresented(.changePreview)) {
            ChangeSetPreviewSheet(
                result: model.pendingChangeSet,
                conflictNotice: model.pendingChangeSetConflictNotice,
                dependencyChoiceNotice: model.pendingDependencyChoiceNotice,
                errorMessage: model.changeSetError,
                errorDetails: model.changeSetErrorDetails,
                isApplying: operationFlow.isActive(.applyingChanges),
                suppressRecommendations: model.pendingChangeSet?.suppressRecommendations
                    ?? model.recommendationSettings?.suppressRecommendations
                    ?? false,
                onClose: {
                    operationFlow.dismiss(.changePreview)
                },
                onClear: {
                    model.clearAllStagedChanges()
                    operationFlow.dismiss(.changePreview)
                },
                onStageProvider: { choice, option in
                    model.stageProviderOption(choice: choice, option: option)
                    previewChanges()
                },
                onStageRecommendation: { identifier in
                    model.stageRecommendationChoice(identifier)
                },
                onToggleSuppressRecommendations: { suppressRecommendations in
                    updateSuppressRecommendations(suppressRecommendations)
                },
                onRetry: {
                    previewChanges()
                },
                onRemoveLock: {
                    beginRegistryLockRemoval(details: model.changeSetErrorDetails, followUp: .preview)
                },
                onApply: {
                    applyChanges()
                })
        }
        .sheet(isPresented: operationSheetIsPresented(.operationResult)) {
            OperationResultSheet(
                result: model.lastOperationResult,
                errorMessage: model.operationError,
                errorDetails: model.operationErrorDetails,
                canSkipDownloadFailuresRetry: model.lastOperationSupportsSkipDownloadFailures,
                isRefreshing: operationFlow.isActive(.refreshingOperationStatus),
                isCancelling: operationFlow.isActive(.cancellingOperation),
                onRefresh: {
                    refreshOperationStatus()
                },
                onRetry: {
                    retryLastOperation()
                },
                onSkipDownloadFailuresRetry: {
                    retryLastOperation(skipDownloadFailures: true)
                },
                onRemoveLock: {
                    beginRegistryLockRemoval(details: model.operationErrorDetails, followUp: .apply)
                },
                onStageProvider: { choice, option in
                    selectCkanProvider(choice: choice, option: option)
                },
                onStageRecommendation: { choice in
                    selectCkanRecommendation(choice)
                },
                onSkipRecommendations: {
                    skipCkanRecommendations()
                },
                onAllowIncompatibleCkanFiles: {
                    allowIncompatibleCkanFiles()
                },
                onCopyDiagnostics: onCopyDiagnostics,
                onCancel: {
                    cancelOperation()
                },
                onClose: {
                    operationFlow.dismiss(.operationResult)
                })
        }
        .sheet(isPresented: $fileImports.isShowingImportDownloadsOptions) {
            ImportDownloadsOptionsSheet(
                fileCount: fileImports.pendingImportDownloadURLs.count,
                installImportedModules: $fileImports.importDownloadsDraft.installImportedModules,
                deleteImportedFiles: $fileImports.importDownloadsDraft.deleteImportedFiles,
                previewBeforeInstall: $fileImports.importDownloadsDraft.previewBeforeInstall,
                onCancel: {
                    fileImports.cancelImportDownloadsOptions()
                },
                onImport: {
                    let request = fileImports.confirmImportDownloadsOptions()
                    importDownloads(request.urls, options: request.options)
                })
        }
        .sheet(isPresented: pendingLaunchWarningIsPresented) {
            if let warning = model.pendingLaunchWarning {
                LaunchWarningSheet(
                    warning: warning,
                    isLaunching: model.isLaunchingGame,
                    onCancel: {
                        model.cancelPendingLaunchWarning()
                    },
                    onLaunch: { suppressFutureWarnings in
                        confirmLaunchWarning(suppressFutureWarnings: suppressFutureWarnings)
                    })
            }
        }
        .sheet(isPresented: maintenanceSheetIsPresented(for: .unmanagedFiles)) {
            UnmanagedFilesSheet(
                result: model.unmanagedFilesResult,
                onRevealFile: revealUnmanagedFile,
                onClose: {
                    model.clearMaintenanceResult(for: .unmanagedFiles)
                })
        }
        .sheet(isPresented: maintenanceSheetIsPresented(for: .history)) {
            InstallationHistorySheet(
                result: model.installationHistoryResult,
                onInstallMissing: { modules in
                    installHistoryModules(modules)
                },
                onRestoreExactVersions: { modules in
                    installHistoryModules(modules, exactVersions: true)
                },
                onClose: {
                    model.clearMaintenanceResult(for: .history)
                })
        }
        .sheet(isPresented: maintenanceSheetIsPresented(for: .playTime)) {
            PlayTimeSheet(
                result: model.playTimeResult,
                onSave: { instanceId, hours in
                    await updatePlayTime(instanceId: instanceId, hours: hours)
                },
                onClose: {
                    model.clearMaintenanceResult(for: .playTime)
                })
        }
        .sheet(isPresented: maintenanceSheetIsPresented(for: .downloadStatistics)) {
            DownloadStatisticsSheet(
                result: model.downloadStatisticsResult,
                onClose: {
                    model.clearMaintenanceResult(for: .downloadStatistics)
                })
        }
        .sheet(isPresented: maintenanceSheetIsPresented(for: .cache)) {
            CacheMaintenanceSheet(
                info: model.cacheInfoResult,
                purgeResult: model.lastCachePurgeResult,
                onRefresh: {
                    await loadCacheInfo()
                },
                onPurgeToLimit: {
                    await purgeCacheToLimit()
                },
                onPurgeAll: {
                    await clearCache()
                },
                onClose: {
                    model.clearMaintenanceResult(for: .cache)
                })
        }
        .sheet(isPresented: deduplicateResultIsPresented) {
            DeduplicateResultSheet(
                result: model.lastDeduplicateResult,
                onClose: {
                    model.clearDeduplicateResult()
                })
        }
        .sheet(isPresented: repairRegistryResultIsPresented) {
            RepairRegistryResultSheet(
                result: model.lastRepairRegistryResult,
                onClose: {
                    model.clearRepairRegistryResult()
                })
        }
        .alert("GameData scan complete", isPresented: maintenanceScanResultIsPresented) {
            Button("OK", role: .cancel) {
                model.clearMaintenanceScanResult()
            }
        } message: {
            Text(maintenanceScanSummary)
        }
        .alert("GameData scan failed", isPresented: maintenanceErrorIsPresented) {
            Button("OK", role: .cancel) {
                model.clearMaintenanceError()
            }
        } message: {
            Text(model.maintenanceError ?? "")
        }
        .alert(
            "Remove Registry Lock File?",
            isPresented: registryLockRemovalIsPresented,
            presenting: operationFlow.pendingRegistryLockRemoval
        ) { request in
            Button("Remove Lock File", role: .destructive) {
                removeRegistryLockAndRetry(request)
            }
            Button("Cancel", role: .cancel) {
                operationFlow.clearRegistryLockRemoval()
            }
        } message: { request in
            Text("Only remove this file if CKAN and MACKAN are not currently working on this instance.\n\n\(request.lockfilePath ?? "The lock file path is unavailable.")")
        }
        .alert(
            "Failed to launch game",
            isPresented: launchErrorIsPresented,
            presenting: model.launchError
        ) { _ in
            if launchErrorCanRetry {
                Button("Retry Launch") {
                    retryLaunchFromFailure()
                }
            }
            Button("OK", role: .cancel) {
                model.clearLaunchError()
            }
        } message: { message in
            Text(launchErrorMessageText(message))
        }
    }

    private func operationSheetIsPresented(_ sheet: OperationPresentationSheet) -> Binding<Bool> {
        Binding {
            operationFlow.isPresenting(sheet)
        } set: { isPresented in
            if isPresented {
                operationFlow.present(sheet)
            } else {
                operationFlow.dismiss(sheet)
            }
        }
    }

    private func maintenanceSheetIsPresented(for pane: MaintenancePane) -> Binding<Bool> {
        Binding {
            model.shouldPresentMaintenanceSheet(for: pane)
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceResult(for: pane)
            }
        }
    }

    private var repositoryRefreshPollingID: String {
        "\(model.repositoryRefreshSummary?.operationId ?? "-"):\(model.repositoryRefreshSummary?.operationStatus ?? "-")"
    }

    private var deduplicateResultIsPresented: Binding<Bool> {
        Binding {
            model.lastDeduplicateResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearDeduplicateResult()
            }
        }
    }

    private var repairRegistryResultIsPresented: Binding<Bool> {
        Binding {
            model.lastRepairRegistryResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearRepairRegistryResult()
            }
        }
    }

    private var maintenanceScanResultIsPresented: Binding<Bool> {
        Binding {
            model.lastMaintenanceScanResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceScanResult()
            }
        }
    }

    private var maintenanceErrorIsPresented: Binding<Bool> {
        Binding {
            model.maintenanceError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceError()
            }
        }
    }

    private var registryLockRemovalIsPresented: Binding<Bool> {
        Binding {
            operationFlow.pendingRegistryLockRemoval != nil
        } set: { isPresented in
            if !isPresented {
                operationFlow.clearRegistryLockRemoval()
            }
        }
    }

    private var maintenanceScanSummary: String {
        guard let result = model.lastMaintenanceScanResult else {
            return ""
        }
        let changeText = result.changed
            ? "Detected changes in manually installed modules or DLC."
            : "No registry changes were detected."
        return "\(changeText)\nDLLs: \(result.detectedDllCount.formatted())\nDLC: \(result.detectedDlcCount.formatted())"
    }

    private func presentCkanFileOpenPanel() {
        let urls = runOpenPanel(configuration: .ckanFileInstall)
        isInstallingFromCkanFile = false
        guard !urls.isEmpty else {
            return
        }

        fileImports.beginCkanFileSelection(urls)
        installCkanFiles(urls)
    }

    private func presentImportDownloadsOpenPanel() {
        let urls = runOpenPanel(configuration: .importDownloads)
        isImportingDownloads = false
        guard !urls.isEmpty else {
            return
        }

        fileImports.beginImportDownloadsSelection(urls)
    }

    private func runOpenPanel(configuration: FileImportPanelConfiguration) -> [URL] {
        let panel = NSOpenPanel()
        panel.title = configuration.title
        panel.prompt = configuration.prompt
        panel.allowsMultipleSelection = configuration.allowsMultipleSelection
        panel.canChooseFiles = configuration.canChooseFiles
        panel.canChooseDirectories = configuration.canChooseDirectories
        panel.canCreateDirectories = false
        panel.allowedContentTypes = configuration.allowedFileExtensions.compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK else {
            return []
        }

        return panel.urls
    }

    private func installCkanFiles(
        _ urls: [URL],
        draft: CkanFileInstallDraft = CkanFileInstallDraft(),
        skipDownloadFailures: Bool = false
    ) {
        Task {
            operationFlow.recordRetry(.ckanFiles)
            fileImports.recordCkanFileOperationURLs(urls)
            operationFlow.start(.installingCkanFiles)
            defer { operationFlow.finish(.installingCkanFiles) }
            let accessedUrls = urls.filter { $0.startAccessingSecurityScopedResource() }
            defer {
                accessedUrls.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            do {
                try await model.installCkanFiles(
                    urls.map(\.path),
                    providerSelections: draft.providerSelections,
                    recommendationSelections: draft.recommendationSelections,
                    skipRecommendations: draft.skipRecommendations,
                    allowIncompatibleCkanFiles: draft.allowIncompatibleCkanFiles,
                    skipDownloadFailures: skipDownloadFailures)
                fileImports.finishCkanFileInstallIfCompleted(status: model.lastOperationResult?.status)
            } catch {
                // AppModel stores a user-facing error for the operation sheet.
            }
            operationFlow.present(.operationResult)
        }
    }

    private func importDownloads(
        _ urls: [URL],
        options: ImportDownloadsOptions,
        skipDownloadFailures: Bool = false
    ) {
        Task {
            operationFlow.recordRetry(.importDownloads)
            fileImports.recordImportDownloadsOperationURLs(urls)
            operationFlow.start(.importingDownloadFiles)
            defer { operationFlow.finish(.importingDownloadFiles) }
            let accessedUrls = urls.filter { $0.startAccessingSecurityScopedResource() }
            defer {
                accessedUrls.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            do {
                try await model.importDownloads(
                    urls.map(\.path),
                    options: options,
                    skipDownloadFailures: skipDownloadFailures)
                fileImports.finishImportDownloadsIfCompleted(status: model.lastOperationResult?.status)
            } catch {
                // AppModel stores a user-facing error for the operation sheet.
            }
            operationFlow.presentImportDownloadsResult(
                previewBeforeInstall: options.previewBeforeInstall,
                hasPendingChangeSet: model.pendingChangeSet != nil)
        }
    }

    private func selectCkanProvider(choice: ProviderChoice, option: ProviderOption) {
        guard !fileImports.pendingCkanFileURLs.isEmpty else {
            return
        }
        fileImports.selectCkanProvider(choice: choice, option: option)
        installCkanFiles(
            fileImports.pendingCkanFileURLs,
            draft: fileImports.ckanFileDraft)
    }

    private func selectCkanRecommendation(_ choice: RecommendationChoice) {
        guard !fileImports.pendingCkanFileURLs.isEmpty else {
            return
        }
        fileImports.selectCkanRecommendation(choice)
        installCkanFiles(
            fileImports.pendingCkanFileURLs,
            draft: fileImports.ckanFileDraft)
    }

    private func skipCkanRecommendations() {
        guard !fileImports.pendingCkanFileURLs.isEmpty else {
            return
        }
        fileImports.skipCkanRecommendations()
        installCkanFiles(
            fileImports.pendingCkanFileURLs,
            draft: fileImports.ckanFileDraft)
    }

    private func allowIncompatibleCkanFiles() {
        guard !fileImports.pendingCkanFileURLs.isEmpty else {
            return
        }
        fileImports.allowIncompatibleCkanFiles()
        installCkanFiles(
            fileImports.pendingCkanFileURLs,
            draft: fileImports.ckanFileDraft)
    }

    private func retryLastOperation(skipDownloadFailures: Bool = false) {
        switch operationFlow.retryAction(skipDownloadFailures: skipDownloadFailures) {
        case .applyChanges(let skipDownloadFailures):
            applyChanges(skipDownloadFailures: skipDownloadFailures)
        case .installCkanFiles(let skipDownloadFailures):
            installCkanFiles(
                fileImports.pendingCkanFileURLs,
                draft: fileImports.ckanFileDraft,
                skipDownloadFailures: skipDownloadFailures)
        case .importDownloads(let skipDownloadFailures):
            importDownloads(
                fileImports.pendingImportDownloadURLs,
                options: fileImports.importDownloadsDraft.options,
                skipDownloadFailures: skipDownloadFailures)
        }
    }

    private var selectedModuleActionPresentation: ModuleActionPresentationState {
        guard let module = model.selectedModule else {
            return .empty
        }
        return ModuleActionPresentationState(
            stagedAction: model.stagedAction(for: module.identifier),
            preferredAction: model.preferredStagedAction(for: module),
            availableActions: model.availableStagedActions(for: module))
    }

    private func stageSelectedModule() {
        guard let module = model.selectedModule else {
            return
        }

        model.togglePreferredStagedAction(for: module)
    }

    private func stageSelectedModule(_ action: StagedModAction) {
        guard let module = model.selectedModule else {
            return
        }

        if model.stagedAction(for: module.identifier) != nil {
            model.clearStagedChange(module.identifier)
            return
        }

        switch action {
        case .install:
            model.stageInstall(module.identifier)
        case .remove:
            model.stageRemove(module.identifier)
        case .upgrade:
            model.stageUpgrade(module.identifier)
        case .replace:
            model.stageReplace(module.identifier)
        }
    }

    private func previewChanges() {
        Task {
            operationFlow.start(.resolvingChanges)
            defer { operationFlow.finish(.resolvingChanges) }
            do {
                try await model.resolveChanges()
            } catch {
                // AppModel stores a user-facing error for the preview sheet.
            }
            operationFlow.present(.changePreview)
        }
    }

    private func updateSuppressRecommendations(_ suppressRecommendations: Bool) {
        Task {
            do {
                try await model.updateSuppressRecommendations(suppressRecommendations)
            } catch {
                // AppModel stores the settings error for the active sheet/settings surfaces.
            }
        }
    }

    private func installHistoryModules(_ modules: [InstallationHistoryModule], exactVersions: Bool = false) {
        model.stageHistoryModules(modules, exactVersions: exactVersions)
        model.clearInstallationHistoryResult()
        previewChanges()
    }

    private func revealUnmanagedFile(_ file: UnmanagedFileSummary) {
        do {
            try model.openUnmanagedFile(file)
        } catch {
            model.reportMaintenanceError(error)
        }
    }

    private func updatePlayTime(instanceId: String, hours: Double) async {
        do {
            try await model.updatePlayTime(instanceId: instanceId, hours: hours)
        } catch {
            // AppModel stores the maintenance error for the main window alert.
        }
    }

    private func loadCacheInfo() async {
        do {
            try await model.loadCacheInfo()
        } catch {
            // AppModel stores the maintenance error for the main window alert.
        }
    }

    private func clearCache() async {
        do {
            try await model.clearCache()
        } catch {
            // AppModel stores the maintenance error for the main window alert.
        }
    }

    private func purgeCacheToLimit() async {
        do {
            try await model.purgeCacheToLimit()
        } catch {
            // AppModel stores the maintenance error for the main window alert.
        }
    }

    private func refreshRepositories() {
        Task {
            operationFlow.start(.refreshingRepositories)
            defer { operationFlow.finish(.refreshingRepositories) }
            do {
                try await model.refreshRepositories(force: true)
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }

    private func applyChanges(skipDownloadFailures: Bool = false) {
        Task {
            operationFlow.recordRetry(.applyChanges)
            operationFlow.start(.applyingChanges)
            defer { operationFlow.finish(.applyingChanges) }
            do {
                try await model.applyStagedChanges(skipDownloadFailures: skipDownloadFailures)
            } catch {
                // AppModel stores a user-facing error for the operation sheet.
            }
            operationFlow.present(.operationResult)
        }
    }

    private func beginRegistryLockRemoval(details: SidecarErrorDetails?, followUp: RegistryLockRemovalFollowUp) {
        operationFlow.beginRegistryLockRemoval(
            lockfilePath: details?.lockfilePath,
            followUp: followUp)
    }

    private func removeRegistryLockAndRetry(_ request: RegistryLockRemovalRequest) {
        Task {
            operationFlow.start(.removingRegistryLock)
            defer { operationFlow.finish(.removingRegistryLock) }
            do {
                try await model.removeRegistryLock()
                operationFlow.clearRegistryLockRemoval()
                switch request.followUp {
                case .preview:
                    previewChanges()
                case .apply:
                    retryLastOperation()
                }
            } catch {
                // AppModel stores the maintenance error for the main window alert.
            }
        }
    }

    private func launchSelectedGame() {
        Task {
            do {
                try await model.launchSelectedGame()
            } catch {
                // AppModel stores the launch error and launchErrorDetails.
            }
        }
    }

    private var launchErrorIsPresented: Binding<Bool> {
        Binding {
            model.launchError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearLaunchError()
            }
        }
    }

    private var launchErrorCanRetry: Bool {
        LaunchErrorPresentationState(message: "", details: model.launchErrorDetails).canRetry
    }

    private func launchErrorMessageText(_ message: String) -> String {
        LaunchErrorPresentationState(message: message, details: model.launchErrorDetails).messageText
    }

    private func retryLaunchFromFailure() {
        model.clearLaunchError()
        launchSelectedGame()
    }

    private var pendingLaunchWarningIsPresented: Binding<Bool> {
        Binding {
            model.pendingLaunchWarning != nil
        } set: { isPresented in
            if !isPresented {
                model.cancelPendingLaunchWarning()
            }
        }
    }

    private func confirmLaunchWarning(suppressFutureWarnings: Bool) {
        Task {
            do {
                try await model.confirmPendingLaunchWarning(suppressFutureWarnings: suppressFutureWarnings)
            } catch {
                // AppModel stores the launch error and launchErrorDetails.
            }
        }
    }

    private func openSelectedGameFolder() {
        do {
            try model.openSelectedInstanceDirectory()
        } catch {
            model.healthState = .failed(error.localizedDescription)
        }
    }

    private func refreshOperationStatus() {
        Task {
            operationFlow.start(.refreshingOperationStatus)
            defer { operationFlow.finish(.refreshingOperationStatus) }
            do {
                try await model.refreshLastOperationStatus()
            } catch {
                // AppModel stores a user-facing error for the operation sheet.
            }
        }
    }

    private func refreshRepositoryRefreshStatus() async {
        do {
            try await model.refreshRepositoryRefreshStatus()
        } catch {
            model.healthState = .failed(error.localizedDescription)
        }
    }

    private func cancelOperation() {
        Task {
            operationFlow.start(.cancellingOperation)
            defer { operationFlow.finish(.cancellingOperation) }
            do {
                try await model.cancelLastOperation()
            } catch {
                // AppModel stores a user-facing error for the operation sheet.
            }
        }
    }
}

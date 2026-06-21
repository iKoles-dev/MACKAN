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
    var onCopyDiagnostics: () -> Void = {}
    @State private var operationFlow = OperationFlowState()
    @State private var fileImports = FileImportFlowState()
    @State private var selectedModuleDetailsTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let isShowingMaintenanceRoute = model.mainContentRoute.isMaintenance
            let showSidebar = geometry.size.width >= CGFloat(MainWindowLayoutPolicy.sidebarVisibilityBreakpoint)
            let showInspector = !isShowingMaintenanceRoute
                && MainWindowLayoutPolicy.shouldShowInspector(
                    windowWidth: Double(geometry.size.width),
                    hasSelectedModule: model.selectedModule != nil)

            HStack(spacing: 0) {
                if showSidebar {
                    SidebarView(model: model)
                        .frame(
                            minWidth: CGFloat(MainWindowLayoutPolicy.sidebarMinimumWidth),
                            idealWidth: CGFloat(MainWindowLayoutPolicy.sidebarIdealWidth(forWindowWidth: Double(geometry.size.width))),
                            maxWidth: CGFloat(MainWindowLayoutPolicy.sidebarMaximumWidth(forWindowWidth: Double(geometry.size.width))))

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
                            showsPanePicker: !showSidebar,
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
                        stagedAction: model.selectedModule.map { model.stagedAction(for: $0.identifier) } ?? nil,
                        emptyState: model.inspectorEmptyState)
                        .frame(
                            minWidth: CGFloat(MainWindowLayoutPolicy.inspectorMinimumWidth),
                            idealWidth: 340,
                            maxWidth: 420)
                }
            }
        }
        .onAppear {
            handleAppCommandTriggers()
        }
        .onChange(of: model.installFromCkanFileTrigger) { _ in
            handleInstallFromCkanFileTrigger()
        }
        .onChange(of: model.importDownloadsTrigger) { _ in
            handleImportDownloadsTrigger()
        }
        .onChange(of: model.applyChangesTrigger) { _ in
            handleApplyChangesTrigger()
        }
        .onChange(of: model.selectedModuleID) { selectedModuleID in
            selectedModuleDetailsTask?.cancel()
            guard selectedModuleID != nil else {
                selectedModuleDetailsTask = nil
                return
            }
            selectedModuleDetailsTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else {
                    return
                }
                await model.refreshSelectedModuleDetails()
            }
        }
        .onDisappear {
            selectedModuleDetailsTask?.cancel()
            selectedModuleDetailsTask = nil
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
            MainWindowToolbar(
                state: toolbarState,
                selectedModuleActionPresentation: selectedModuleActionPresentation,
                onRefresh: refreshRepositories,
                onStageSelectedModule: stageSelectedModule,
                onStageSelectedModuleAction: stageSelectedModule,
                onPreview: previewChanges,
                onApply: { applyChanges() },
                onUpgradeAll: { model.stageUpgradeAll() },
                onInstallFromFile: presentCkanFileOpenPanel,
                onImportDownloads: presentImportDownloadsOpenPanel,
                onClear: { model.clearAllStagedChanges() },
                onLaunch: launchSelectedGame,
                onOpenFolder: openSelectedGameFolder)
        }
        .modifier(MainWindowSheets(
            model: model,
            fileImports: $fileImports,
            operationFlow: $operationFlow,
            actions: sheetActions))
    }

    private var repositoryRefreshPollingID: String {
        "\(model.repositoryRefreshSummary?.operationId ?? "-"):\(model.repositoryRefreshSummary?.operationStatus ?? "-")"
    }

    private func presentCkanFileOpenPanel() {
        let urls = runOpenPanel(configuration: .ckanFileInstall)
        guard !urls.isEmpty else {
            return
        }

        fileImports.beginCkanFileSelection(urls)
        installCkanFiles(urls)
    }

    private func presentImportDownloadsOpenPanel() {
        let urls = runOpenPanel(configuration: .importDownloads)
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

    private var toolbarState: MainWindowToolbarState {
        MainWindowToolbarState(
            canRefreshRepositories: model.canRefreshRepositories,
            canApplyPendingChangeSet: model.canApplyPendingChangeSet,
            hasPendingSelections: model.hasPendingSelections,
            canStageUpgradeAll: model.canStageUpgradeAll,
            canLaunchSelectedGame: model.canLaunchSelectedGame,
            canOpenSelectedInstanceDirectory: model.canOpenSelectedInstanceDirectory,
            isRefreshingRepositories: operationFlow.isActive(.refreshingRepositories),
            isResolvingChanges: operationFlow.isActive(.resolvingChanges),
            isApplyingChanges: operationFlow.isActive(.applyingChanges),
            isInstallingCkanFiles: operationFlow.isActive(.installingCkanFiles),
            isImportingDownloadFiles: operationFlow.isActive(.importingDownloadFiles),
            isLaunchingGame: model.isLaunchingGame)
    }

    private var sheetActions: MainWindowSheetActions {
        MainWindowSheetActions(
            clearChanges: {
                model.clearAllStagedChanges()
                operationFlow.dismiss(.changePreview)
            },
            stageProvider: { choice, option in
                model.stageProviderOption(choice: choice, option: option)
                previewChanges()
            },
            stageRecommendation: { identifier in
                model.stageRecommendationChoice(identifier)
            },
            toggleSuppressRecommendations: updateSuppressRecommendations,
            previewChanges: previewChanges,
            removePreviewLock: {
                beginRegistryLockRemoval(details: model.changeSetErrorDetails, followUp: .preview)
            },
            applyChanges: { applyChanges() },
            refreshOperationStatus: refreshOperationStatus,
            retryLastOperation: { retryLastOperation() },
            retryLastOperationSkippingDownloadFailures: {
                retryLastOperation(skipDownloadFailures: true)
            },
            removeOperationLock: {
                beginRegistryLockRemoval(details: model.operationErrorDetails, followUp: .apply)
            },
            selectCkanProvider: selectCkanProvider,
            selectCkanRecommendation: selectCkanRecommendation,
            skipCkanRecommendations: skipCkanRecommendations,
            allowIncompatibleCkanFiles: allowIncompatibleCkanFiles,
            copyDiagnostics: onCopyDiagnostics,
            cancelOperation: cancelOperation,
            importDownloads: { urls, options in
                importDownloads(urls, options: options)
            },
            confirmLaunchWarning: confirmLaunchWarning,
            revealUnmanagedFile: revealUnmanagedFile,
            installHistoryModules: installHistoryModules,
            updatePlayTime: updatePlayTime,
            loadCacheInfo: loadCacheInfo,
            purgeCacheToLimit: purgeCacheToLimit,
            clearCache: clearCache,
            removeRegistryLockAndRetry: removeRegistryLockAndRetry,
            retryLaunchFromFailure: retryLaunchFromFailure)
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

    private func handleAppCommandTriggers() {
        handleInstallFromCkanFileTrigger()
        handleImportDownloadsTrigger()
        handleApplyChangesTrigger()
    }

    private func handleInstallFromCkanFileTrigger() {
        guard model.installFromCkanFileTrigger else {
            return
        }
        model.installFromCkanFileTrigger = false
        DispatchQueue.main.async {
            presentCkanFileOpenPanel()
        }
    }

    private func handleImportDownloadsTrigger() {
        guard model.importDownloadsTrigger else {
            return
        }
        model.importDownloadsTrigger = false
        DispatchQueue.main.async {
            presentImportDownloadsOpenPanel()
        }
    }

    private func handleApplyChangesTrigger() {
        guard model.applyChangesTrigger else {
            return
        }
        model.applyChangesTrigger = false
        if model.canApplyPendingChangeSet {
            applyChanges()
        }
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
        if operationFlow.isActive(.resolvingChanges) {
            operationFlow.present(.changePreview)
            return
        }

        operationFlow.start(.resolvingChanges)
        operationFlow.present(.changePreview)

        Task { @MainActor in
            defer { operationFlow.finish(.resolvingChanges) }
            do {
                try await model.resolveChanges()
            } catch {
                // AppModel stores a user-facing error for the preview sheet.
            }
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

    private func retryLaunchFromFailure() {
        model.clearLaunchError()
        launchSelectedGame()
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

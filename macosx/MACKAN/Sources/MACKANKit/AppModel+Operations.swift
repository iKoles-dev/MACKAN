import Foundation

extension AppModel {
    public func stagedAction(for identifier: ModuleSummary.ID) -> StagedModAction? {
        if versionedInstallSelections.contains(where: {
            $0.identifier.localizedCaseInsensitiveCompare(identifier) == .orderedSame
        }) {
            return .install
        }
        return stagedActions[identifier]
    }

    public func availableStagedActions(for module: ModuleSummary) -> [StagedModAction] {
        switch module.status {
        case .available, .cached:
            return [.install]
        case .installed:
            return module.hasReplacement ? [.replace, .remove] : [.remove]
        case .upgradable:
            return module.hasReplacement ? [.upgrade, .replace] : [.upgrade]
        case .incompatible:
            return []
        }
    }

    public func preferredStagedAction(for module: ModuleSummary) -> StagedModAction? {
        availableStagedActions(for: module).first
    }

    public func togglePreferredStagedAction(for module: ModuleSummary) {
        if stagedAction(for: module.identifier) != nil {
            clearStagedChange(module.identifier)
            return
        }

        guard let action = preferredStagedAction(for: module) else {
            return
        }

        stage(action, for: module.identifier)
    }

    public func stageInstall(_ identifier: ModuleSummary.ID) {
        stage(.install, for: identifier)
    }

    public func stageRemove(_ identifier: ModuleSummary.ID) {
        stage(.remove, for: identifier)
    }

    public func stageUpgrade(_ identifier: ModuleSummary.ID) {
        stage(.upgrade, for: identifier)
    }

    public func stageReplace(_ identifier: ModuleSummary.ID) {
        stage(.replace, for: identifier)
    }

    public func stageProviderOption(choice: ProviderChoice, option: ProviderOption) {
        let selection = ProviderSelection(
            requested: choice.requested,
            requesterIdentifier: choice.requesterIdentifier,
            selectedIdentifier: option.identifier)
        providerSelections.removeAll { $0.id == selection.id }
        providerSelections.append(selection)
        providerSelections.sort {
            $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }
        invalidateResolvedChangePreview()
    }

    public func stageRecommendationChoice(_ identifier: ModuleSummary.ID) {
        stage(.install, for: identifier)
    }

    public func stageUpgradeAll() {
        modules
            .filter { $0.status == .upgradable }
            .forEach { stage(.upgrade, for: $0.identifier) }
    }

    public func clearStagedChange(_ identifier: ModuleSummary.ID) {
        stagedActions.removeValue(forKey: identifier)
        versionedInstallSelections.removeAll {
            $0.identifier.localizedCaseInsensitiveCompare(identifier) == .orderedSame
        }
        providerSelections.removeAll { $0.requesterIdentifier == identifier || $0.selectedIdentifier == identifier }
        invalidateResolvedChangePreview()
    }

    public func clearAllStagedChanges() {
        stagedActions = [:]
        providerSelections = []
        versionedInstallSelections = []
        invalidateResolvedChangePreview()
    }

    public func resolveChanges() async throws {
        let install = identifiers(for: .install)
        let remove = identifiers(for: .remove)
        let upgrade = identifiers(for: .upgrade)
        let replace = identifiers(for: .replace)
        let installVersions = versionedInstallSelections
        let providers = providerSelections
        let instanceID = selectedInstanceID
        let changeGeneration = stagedChangeGeneration
        guard !install.isEmpty || !versionedInstallSelections.isEmpty || !remove.isEmpty || !upgrade.isEmpty || !replace.isEmpty else {
            pendingChangeSet = nil
            changeSetError = nil
            changeSetErrorDetails = nil
            return
        }

        pendingChangeSet = nil
        changeSetError = nil
        changeSetErrorDetails = nil

        do {
            let result = try await previewSidecar.resolveChanges(
                instanceId: instanceID,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providers)
            guard isCurrentChangePreview(generation: changeGeneration, instanceID: instanceID) else {
                return
            }
            pendingChangeSet = result
            changeSetError = nil
            changeSetErrorDetails = nil
        } catch {
            guard isCurrentChangePreview(generation: changeGeneration, instanceID: instanceID) else {
                return
            }
            pendingChangeSet = nil
            changeSetError = userFacingMessage(for: error)
            changeSetErrorDetails = errorDetails(for: error)
            throw error
        }
    }

    public func applyStagedChanges(skipDownloadFailures: Bool = false) async throws {
        let install = identifiers(for: .install)
        let remove = identifiers(for: .remove)
        let upgrade = identifiers(for: .upgrade)
        let replace = identifiers(for: .replace)
        guard !install.isEmpty || !versionedInstallSelections.isEmpty || !remove.isEmpty || !upgrade.isEmpty || !replace.isEmpty else {
            lastOperationResult = nil
            operationError = nil
            operationErrorDetails = nil
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            return
        }

        do {
            lastOperationSupportsSkipDownloadFailures = true
            pendingOperationCompletionAction = .reloadInstanceState
            let result = try await sidecar.startApplyChanges(
                instanceId: selectedInstanceID,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: versionedInstallSelections,
                providerSelections: providerSelections,
                skipDownloadFailures: skipDownloadFailures)
            try await storeOperationResult(result)
        } catch {
            lastOperationResult = nil
            operationError = userFacingMessage(for: error)
            operationErrorDetails = errorDetails(for: error)
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            throw error
        }
    }

    public func cancelLastOperation() async throws {
        guard let operationId = lastOperationResult?.operationId else {
            operationError = nil
            operationErrorDetails = nil
            return
        }

        do {
            let result = try await sidecar.cancelOperation(operationId: operationId)
            lastOperationResult = result
            operationError = result.error
            operationErrorDetails = result.errorDetails
            if result.status != "running", result.status != "cancelling" {
                pendingOperationCompletionAction = nil
            }
        } catch {
            operationError = userFacingMessage(for: error)
            operationErrorDetails = errorDetails(for: error)
            throw error
        }
    }

    public func refreshLastOperationStatus() async throws {
        guard let operationId = lastOperationResult?.operationId else {
            operationError = nil
            operationErrorDetails = nil
            return
        }

        do {
            let result = try await sidecar.operationStatus(operationId: operationId)
            try await storeOperationResult(result)
        } catch {
            operationError = userFacingMessage(for: error)
            operationErrorDetails = errorDetails(for: error)
            throw error
        }
    }

    public func installCkanFiles(
        _ filePaths: [String],
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws {
        let cleanedPaths = filePaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedPaths.isEmpty else {
            lastOperationResult = nil
            operationError = CkanFileInstallError.noFiles.localizedDescription
            operationErrorDetails = nil
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            throw CkanFileInstallError.noFiles
        }

        do {
            lastOperationSupportsSkipDownloadFailures = true
            pendingOperationCompletionAction = .reloadInstanceState
            let result = try await sidecar.startInstallCkanFiles(
                instanceId: selectedInstanceID,
                filePaths: cleanedPaths,
                providerSelections: providerSelections,
                recommendationSelections: recommendationSelections,
                skipRecommendations: skipRecommendations,
                allowIncompatibleCkanFiles: allowIncompatibleCkanFiles,
                skipDownloadFailures: skipDownloadFailures)
            try await storeOperationResult(result)
        } catch {
            lastOperationResult = nil
            operationError = userFacingMessage(for: error)
            operationErrorDetails = errorDetails(for: error)
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            throw error
        }
    }

    public func importDownloads(
        _ paths: [String],
        installImportedModules: Bool = true,
        deleteImportedFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws {
        try await importDownloads(
            paths,
            options: ImportDownloadsOptions(
                installImportedModules: installImportedModules,
                deleteImportedFiles: deleteImportedFiles),
            skipDownloadFailures: skipDownloadFailures)
    }

    public func importDownloads(
        _ paths: [String],
        options: ImportDownloadsOptions,
        skipDownloadFailures: Bool = false
    ) async throws {
        let cleanedPaths = paths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedPaths.isEmpty else {
            lastOperationResult = nil
            operationError = CkanFileInstallError.noFiles.localizedDescription
            operationErrorDetails = nil
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            throw CkanFileInstallError.noFiles
        }

        do {
            let shouldPreviewInstall = options.installImportedModules && options.previewBeforeInstall
            lastOperationSupportsSkipDownloadFailures = options.installImportedModules && !shouldPreviewInstall
            pendingOperationCompletionAction = shouldPreviewInstall ? .previewImportedDownloads : .reloadInstanceState
            let result = try await sidecar.startImportDownloads(
                instanceId: selectedInstanceID,
                paths: cleanedPaths,
                installImportedModules: shouldPreviewInstall ? false : options.installImportedModules,
                deleteImportedFiles: options.deleteImportedFiles,
                previewBeforeInstall: shouldPreviewInstall,
                skipDownloadFailures: skipDownloadFailures)
            try await storeOperationResult(result)
        } catch {
            lastOperationResult = nil
            operationError = userFacingMessage(for: error)
            operationErrorDetails = errorDetails(for: error)
            lastOperationSupportsSkipDownloadFailures = false
            pendingOperationCompletionAction = nil
            throw error
        }
    }

    public func exportModList(format: ModListExportFormat) async throws -> ModListExportResult {
        try await sidecar.exportModList(instanceId: selectedInstanceID, format: format)
    }

    public func exportModpack(draft: ModpackExportDraft) async throws -> ModpackExportResult {
        try await sidecar.exportModpack(instanceId: selectedInstanceID, draft: draft)
    }

    private func storeOperationResult(_ result: OperationResult) async throws {
        lastOperationResult = result
        operationError = result.error
        operationErrorDetails = result.errorDetails

        switch result.status {
        case "completed":
            let completionAction = pendingOperationCompletionAction ?? .reloadInstanceState
            pendingOperationCompletionAction = nil
            clearAllStagedChanges()
            try await loadInstanceState(for: selectedInstanceID)
            if completionAction == .previewImportedDownloads {
                for identifier in importedInstallIdentifiers(from: result) {
                    stage(.install, for: identifier)
                }
                try await resolveChanges()
            }
        case "running", "cancelling":
            break
        default:
            pendingOperationCompletionAction = nil
        }
    }

    func stage(_ action: StagedModAction, for identifier: ModuleSummary.ID) {
        versionedInstallSelections.removeAll {
            $0.identifier.localizedCaseInsensitiveCompare(identifier) == .orderedSame
        }
        stagedActions[identifier] = action
        invalidateResolvedChangePreview()
    }

    func stageExactInstall(_ selection: VersionedModuleSelection) {
        stagedActions[selection.identifier] = .install
        versionedInstallSelections.removeAll {
            $0.identifier.localizedCaseInsensitiveCompare(selection.identifier) == .orderedSame
        }
        versionedInstallSelections.append(selection)
        versionedInstallSelections.sort {
            let identifierOrder = $0.identifier.localizedCaseInsensitiveCompare($1.identifier)
            if identifierOrder != .orderedSame {
                return identifierOrder == .orderedAscending
            }
            return $0.version.localizedCaseInsensitiveCompare($1.version) == .orderedAscending
        }
        invalidateResolvedChangePreview()
    }

    private func invalidateResolvedChangePreview() {
        stagedChangeGeneration += 1
        pendingChangeSet = nil
        changeSetError = nil
        changeSetErrorDetails = nil
    }

    private func isCurrentChangePreview(generation: Int, instanceID: GameInstanceSummary.ID?) -> Bool {
        stagedChangeGeneration == generation && selectedInstanceID == instanceID
    }

    private func identifiers(for action: StagedModAction) -> [String] {
        let exactInstallIdentifiers = Set(versionedInstallSelections.map { $0.identifier.lowercased() })
        return stagedActions
            .filter { _, stagedAction in stagedAction == action }
            .map(\.key)
            .filter { identifier in
                action != .install || !exactInstallIdentifiers.contains(identifier.lowercased())
            }
            .sorted()
    }

    private func importedInstallIdentifiers(from result: OperationResult) -> [String] {
        result.changes
            .filter { $0.action == StagedModAction.install.rawValue }
            .map(\.identifier)
            .uniquedCaseInsensitive()
            .sorted()
    }
}

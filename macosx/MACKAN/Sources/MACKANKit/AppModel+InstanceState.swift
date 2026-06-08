extension AppModel {
    func loadInstanceState(for instanceID: GameInstanceSummary.ID?) async throws {
        generalSettings = nil
        compatibleGameVersions = nil
        stabilityTolerance = nil
        preferredHosts = nil
        installFilters = nil
        catalogLoadProgress = nil
        guard let instanceID else {
            modules = []
            selectedModuleID = nil
            selectedModuleDetails = nil
            moduleLabels = []
            manageableModuleLabels = []
            repositories = []
            availableRepositories = []
            launchCommands = []
            defaultLaunchCommands = []
            incompatibleLaunchModules = []
            pendingLaunchWarning = nil
            repositoryRefreshSummary = nil
            clearAllStagedChanges()
            return
        }

        async let labelsResult = sidecar.listLabels(instanceId: instanceID)
        async let repositoryResult = sidecar.listRepositories(instanceId: instanceID)
        async let launchOptionsResult = sidecar.launchOptions(instanceId: instanceID)
        catalogLoadProgress = CatalogLoadProgress(
            detail: "Reading CKAN registry and module metadata for the selected instance.")
        let loadedModules = try await loadModulesWithProgress(instanceID: instanceID)
        let loadedLabels = try await labelsResult
        let loadedRepositories = try await repositoryResult
        let loadedLaunchOptions = try await launchOptionsResult
        moduleLabels = loadedLabels.labels
        manageableModuleLabels = sortedLabels(loadedLabels.manageableLabels)
        repositories = loadedRepositories.repositories
        launchCommands = loadedLaunchOptions.commandLines
        defaultLaunchCommands = loadedLaunchOptions.defaultCommandLines
        incompatibleLaunchModules = loadedLaunchOptions.incompatibleModules
        pendingLaunchWarning = nil
        await publishLoadedModules(loadedModules.modules)
        selectedModuleID = modules.first?.id
        clearAllStagedChanges()
        await refreshSelectedModuleDetails()
        catalogLoadProgress = nil
    }

    private func loadModulesWithProgress(instanceID: String) async throws -> SidecarModulesResult {
        var operation = try await sidecar.startListModules(instanceId: instanceID)
        updateCatalogLoadProgress(from: operation.events)
        while operation.status == "running" || operation.status == "cancelling" {
            try await Task.sleep(nanoseconds: 150_000_000)
            operation = try await sidecar.moduleListStatus(operationId: operation.operationId)
            updateCatalogLoadProgress(from: operation.events)
        }

        if operation.status == "failed" {
            throw SidecarClientError.rpcError(code: -32000, message: operation.error ?? "Catalog loading failed.")
        }
        if operation.status == "cancelled" {
            throw CancellationError()
        }

        return SidecarModulesResult(instanceId: operation.instanceId, modules: operation.modules)
    }

    private func updateCatalogLoadProgress(from events: [OperationEvent]) {
        guard let event = events.last(where: { $0.kind == "progress" || $0.kind == "message" }) else {
            return
        }

        catalogLoadProgress = CatalogLoadProgress(
            detail: event.message,
            loadedModuleCount: event.completedCount,
            totalModuleCount: event.totalCount,
            percent: event.percent)
    }

    private func publishLoadedModules(_ loadedModules: [ModuleSummary]) async {
        modules = loadedModules
    }
}

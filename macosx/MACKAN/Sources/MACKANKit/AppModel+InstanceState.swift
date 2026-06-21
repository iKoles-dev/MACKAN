import Foundation

extension AppModel {
    func loadInstanceState(for instanceID: GameInstanceSummary.ID?) async throws {
        instanceStateLoadGeneration += 1
        let loadGeneration = instanceStateLoadGeneration

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
        applyCachedCatalogSnapshot(for: instanceID)
        guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
            return
        }
        catalogLoadProgress = CatalogLoadProgress(
            detail: "Reading CKAN registry and module metadata for the selected instance.")
        do {
            let loadedModules = try await loadModulesWithProgress(
                instanceID: instanceID,
                loadGeneration: loadGeneration)
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                return
            }
            let loadedLabels = try await labelsResult
            let loadedRepositories = try await repositoryResult
            let loadedLaunchOptions = try await launchOptionsResult
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                return
            }
            moduleLabels = loadedLabels.labels
            manageableModuleLabels = sortedLabels(loadedLabels.manageableLabels)
            repositories = loadedRepositories.repositories
            launchCommands = loadedLaunchOptions.commandLines
            defaultLaunchCommands = loadedLaunchOptions.defaultCommandLines
            incompatibleLaunchModules = loadedLaunchOptions.incompatibleModules
            pendingLaunchWarning = nil
            await publishLoadedModules(loadedModules.modules)
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                return
            }
            catalogLoadProgress = nil
            selectFirstFilteredModule()
            await refreshSelectedModuleDetails(force: true)
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                return
            }
            saveCatalogSnapshot(for: instanceID)
            // Index all installed mods for this instance so users can find them via Spotlight.
            indexInstalledModsForSpotlight(instanceID: instanceID)
        } catch {
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                return
            }
            catalogLoadProgress = nil
            throw error
        }
    }

    private func loadModulesWithProgress(
        instanceID: String,
        loadGeneration: Int
    ) async throws -> SidecarModulesResult {
        var operation = try await sidecar.startListModules(instanceId: instanceID)
        guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
            await cancelModuleListIfActive(operation)
            throw CancellationError()
        }
        updateCatalogLoadProgress(
            from: operation.events,
            loadGeneration: loadGeneration,
            instanceID: instanceID)
        while operation.status == "running" || operation.status == "cancelling" {
            try await Task.sleep(nanoseconds: 150_000_000)
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                await cancelModuleListIfActive(operation)
                throw CancellationError()
            }
            operation = try await sidecar.moduleListStatus(operationId: operation.operationId)
            guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
                await cancelModuleListIfActive(operation)
                throw CancellationError()
            }
            updateCatalogLoadProgress(
                from: operation.events,
                loadGeneration: loadGeneration,
                instanceID: instanceID)
        }

        if operation.status == "failed" {
            throw SidecarClientError.rpcError(code: -32000, message: operation.error ?? "Catalog loading failed.")
        }
        if operation.status == "cancelled" {
            throw CancellationError()
        }

        return SidecarModulesResult(instanceId: operation.instanceId, modules: operation.modules)
    }

    private func updateCatalogLoadProgress(
        from events: [OperationEvent],
        loadGeneration: Int,
        instanceID: String
    ) {
        guard isCurrentInstanceStateLoad(generation: loadGeneration, instanceID: instanceID) else {
            return
        }
        guard let event = events.last(where: { $0.kind == "progress" || $0.kind == "message" }) else {
            return
        }

        catalogLoadProgress = CatalogLoadProgress(
            detail: event.message,
            loadedModuleCount: event.completedCount,
            totalModuleCount: event.totalCount,
            percent: event.percent)
    }

    private func cancelModuleListIfActive(_ operation: ModuleListOperationResult) async {
        guard operation.status == "running" || operation.status == "cancelling" else {
            return
        }
        _ = try? await sidecar.cancelModuleList(operationId: operation.operationId)
    }

    private func isCurrentInstanceStateLoad(
        generation: Int,
        instanceID: GameInstanceSummary.ID?
    ) -> Bool {
        instanceStateLoadGeneration == generation && selectedInstanceID == instanceID
    }

    private func publishLoadedModules(_ loadedModules: [ModuleSummary]) async {
        modules = loadedModules
    }

    private func applyCachedCatalogSnapshot(for instanceID: String) {
        guard let snapshot = catalogSnapshotStore.loadSnapshot(for: instanceID),
              !snapshot.modules.isEmpty
        else {
            return
        }

        modules = snapshot.modules
        moduleLabels = snapshot.moduleLabels
        manageableModuleLabels = sortedLabels(snapshot.manageableModuleLabels)
        repositories = snapshot.repositories
        launchCommands = snapshot.launchCommands
        defaultLaunchCommands = snapshot.defaultLaunchCommands
        incompatibleLaunchModules = snapshot.incompatibleLaunchModules
        pendingLaunchWarning = nil
        selectFirstFilteredModule()
        selectedModuleDetails = nil
    }

    private func saveCatalogSnapshot(for instanceID: String) {
        catalogSnapshotStore.saveSnapshot(ModuleCatalogSnapshot(
            instanceId: instanceID,
            modules: modules,
            moduleLabels: moduleLabels,
            manageableModuleLabels: manageableModuleLabels,
            repositories: repositories,
            launchCommands: launchCommands,
            defaultLaunchCommands: defaultLaunchCommands,
            incompatibleLaunchModules: incompatibleLaunchModules,
            savedAt: Date()))
    }
}

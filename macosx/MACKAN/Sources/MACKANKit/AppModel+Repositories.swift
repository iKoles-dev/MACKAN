import Foundation

extension AppModel {
    public func addRepository(name: String, url: String) async throws {
        let result = try await sidecar.addRepository(
            instanceId: selectedInstanceID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.trimmingCharacters(in: .whitespacesAndNewlines))
        repositories = result.repositories
    }

    public func removeRepository(name: String) async throws {
        let result = try await sidecar.removeRepository(
            instanceId: selectedInstanceID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        repositories = result.repositories
    }

    public func setRepositoryPriority(name: String, priority: Int) async throws {
        let result = try await sidecar.setRepositoryPriority(
            instanceId: selectedInstanceID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority)
        repositories = result.repositories
    }

    public func refreshRepositories(force: Bool = false) async throws {
        let previousModules = modules
        let result = try await sidecar.startRefreshRepositories(
            instanceId: selectedInstanceID,
            force: force)
        try await storeRepositoryRefreshResult(result, previousModules: previousModules)
    }

    public func refreshRepositoryRefreshStatus() async throws {
        guard let operationId = repositoryRefreshSummary?.operationId else {
            return
        }

        let previousModules = modules
        let result = try await sidecar.repositoryRefreshStatus(operationId: operationId)
        try await storeRepositoryRefreshResult(result, previousModules: previousModules)
    }

    public func cancelRepositoryRefresh() async throws {
        guard let operationId = repositoryRefreshSummary?.operationId else {
            return
        }

        repositoryRefreshSummary = try await sidecar.cancelRepositoryRefresh(operationId: operationId)
    }

    public func loadAvailableRepositories() async throws {
        let result = try await sidecar.listAvailableRepositories(instanceId: selectedInstanceID)
        availableRepositories = result.repositories
    }

    private func storeRepositoryRefreshResult(
        _ result: RepositoryRefreshResult,
        previousModules: [ModuleSummary]
    ) async throws {
        repositoryRefreshSummary = result
        guard result.operationStatus == "completed" else {
            return
        }

        repositories = result.repositories
        let moduleResult = try await sidecar.listModules(instanceId: selectedInstanceID)
        modules = markNewModules(moduleResult.modules, comparedTo: previousModules)
        selectFirstFilteredModule()
        await refreshSelectedModuleDetails(force: true)
    }

    private func markNewModules(
        _ refreshedModules: [ModuleSummary],
        comparedTo previousModules: [ModuleSummary]
    ) -> [ModuleSummary] {
        let previousByIdentifier = Dictionary(
            uniqueKeysWithValues: previousModules.map { ($0.identifier.lowercased(), $0) })
        return refreshedModules.map { module in
            let previous = previousByIdentifier[module.identifier.lowercased()]
            let newlyIndexed = previous == nil
            let newlyCompatible = previous?.isCompatible == false && module.isCompatible
            return module.withIsNew(module.isNew || newlyIndexed || newlyCompatible)
        }
    }
}

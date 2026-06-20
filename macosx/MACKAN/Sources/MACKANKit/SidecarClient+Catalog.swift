import Foundation

extension SidecarClient {
    public func listModules(instanceId: String?) async throws -> SidecarModulesResult {
        try await request(
            method: "mods.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func startListModules(instanceId: String?) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.startList",
            params: stringParams(["instanceId": instanceId]))
    }

    public func moduleListStatus(operationId: String) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.listStatus",
            params: ["operationId": .string(operationId)])
    }

    public func cancelModuleList(operationId: String) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.cancelList",
            params: ["operationId": .string(operationId)])
    }

    public func listLabels(instanceId: String?) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func toggleModuleLabel(
        instanceId: String?,
        labelName: String,
        identifier: String
    ) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.toggleModule",
            params: stringParams([
                "instanceId": instanceId,
                "labelName": labelName,
                "identifier": identifier,
            ]))
    }

    public func upsertModuleLabel(
        instanceId: String?,
        originalName: String?,
        originalInstanceName: String?,
        label: ModuleLabelEdit
    ) async throws -> SidecarLabelsResult {
        var params = stringParams([
            "instanceId": instanceId,
            "originalName": originalName,
            "originalInstanceName": originalInstanceName,
        ]) ?? [:]
        params["label"] = label.parameterValue
        return try await request(method: "labels.upsert", params: params)
    }

    public func deleteModuleLabel(
        instanceId: String?,
        name: String,
        instanceName: String?
    ) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.delete",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
                "instanceName": instanceName,
            ]))
    }

    public func setAutoInstalled(
        instanceId: String?,
        identifier: String,
        isAutoInstalled: Bool
    ) async throws -> SidecarModulesResult {
        var params = stringParams([
            "instanceId": instanceId,
            "identifier": identifier,
        ]) ?? [:]
        params["isAutoInstalled"] = .bool(isAutoInstalled)
        return try await request(method: "mods.setAutoInstalled", params: params)
    }

    public func moduleDetails(instanceId: String?, identifier: String) async throws -> ModuleDetails {
        let params = stringParams([
            "identifier": identifier,
            "instanceId": instanceId,
        ])
        return try await request(method: "mods.details", params: params)
    }

    public func listRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func listAvailableRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.available",
            params: stringParams(["instanceId": instanceId]))
    }

    public func addRepository(instanceId: String?, name: String, url: String) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.add",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
                "url": url,
            ]))
    }

    public func removeRepository(instanceId: String?, name: String) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.remove",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
            ]))
    }

    public func setRepositoryPriority(instanceId: String?, name: String, priority: Int) async throws -> SidecarRepositoriesResult {
        var params = stringParams([
            "instanceId": instanceId,
            "name": name,
        ]) ?? [:]
        params["priority"] = .int(priority)
        return try await request(method: "repositories.setPriority", params: params)
    }

    public func refreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["force"] = .bool(force)
        return try await request(method: "repositories.refresh", params: params)
    }

    public func startRefreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["force"] = .bool(force)
        return try await request(method: "repositories.startRefresh", params: params)
    }

    public func repositoryRefreshStatus(operationId: String) async throws -> RepositoryRefreshResult {
        return try await request(
            method: "repositories.refreshStatus",
            params: ["operationId": .string(operationId)])
    }

    public func cancelRepositoryRefresh(operationId: String) async throws -> RepositoryRefreshResult {
        return try await request(
            method: "repositories.cancelRefresh",
            params: ["operationId": .string(operationId)])
    }

}

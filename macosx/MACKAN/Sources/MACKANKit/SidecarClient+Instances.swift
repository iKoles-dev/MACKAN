import Foundation

extension SidecarClient {
    public func listInstances() async throws -> SidecarInstancesResult {
        try await request(method: "instances.list")
    }

    public func addInstance(path: String, name: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.add",
            params: stringParams([
                "path": path,
                "name": name,
            ]))
    }

    public func cloneOptions(sourceInstanceId: String) async throws -> CloneOptionsResult {
        try await request(
            method: "instances.cloneOptions",
            params: stringParams(["sourceInstanceId": sourceInstanceId]))
    }

    public func cloneInstance(
        sourceInstanceId: String,
        newName: String,
        newPath: String,
        shareStock: Bool,
        leaveEmptyPaths: [String]? = nil
    ) async throws -> SidecarInstancesResult {
        var params = stringParams([
            "sourceInstanceId": sourceInstanceId,
            "newName": newName,
            "newPath": newPath,
        ]) ?? [:]
        params["shareStock"] = .bool(shareStock)
        if let leaveEmptyPaths {
            params["leaveEmptyPaths"] = .strings(leaveEmptyPaths)
        }
        return try await request(method: "instances.clone", params: params)
    }

    public func fakeInstance(
        name: String,
        path: String,
        version: String,
        gameId: String,
        makingHistoryVersion: String?,
        breakingGroundVersion: String?,
        setDefault: Bool
    ) async throws -> SidecarInstancesResult {
        var params = stringParams([
            "name": name,
            "path": path,
            "version": version,
            "gameId": gameId,
            "makingHistoryVersion": makingHistoryVersion,
            "breakingGroundVersion": breakingGroundVersion,
        ]) ?? [:]
        params["setDefault"] = .bool(setDefault)
        return try await request(method: "instances.fake", params: params)
    }

    public func setDefaultInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.setDefault",
            params: stringParams(["instanceId": instanceId]))
    }

    public func removeInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.remove",
            params: stringParams(["instanceId": instanceId]))
    }

    public func renameInstance(_ instanceId: String, to newName: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.rename",
            params: stringParams([
                "instanceId": instanceId,
                "newName": newName,
            ]))
    }

    public func launchOptions(instanceId: String?) async throws -> LaunchOptionsResult {
        try await request(
            method: "instances.launchOptions",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateLaunchOptions(instanceId: String?, commandLines: [String]) async throws -> LaunchOptionsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["commandLines"] = .strings(commandLines)
        return try await request(method: "instances.updateLaunchOptions", params: params)
    }

    public func launchGame(
        instanceId: String?,
        commandLine: String?,
        suppressIncompatibleWarnings: Bool = false
    ) async throws -> LaunchGameResult {
        var params = stringParams([
            "instanceId": instanceId,
            "commandLine": commandLine,
        ]) ?? [:]
        params["suppressIncompatibleWarnings"] = .bool(suppressIncompatibleWarnings)
        return try await request(
            method: "instances.launch",
            params: params)
    }

}

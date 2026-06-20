import Foundation

extension SidecarClient {
    public func getSettings() async throws -> SettingsResult {
        try await request(method: "settings.get")
    }

    public func updateSettings(
        downloadCacheDir: String,
        cacheSizeLimitBytes: Int64?,
        cacheMigrationChoice: CacheMigrationChoice
    ) async throws -> SettingsResult {
        try await request(
            method: "settings.update",
            params: [
                "downloadCacheDir": .string(downloadCacheDir),
                "cacheSizeLimitBytes": .int64(cacheSizeLimitBytes ?? -1),
                "cacheMigrationChoice": .string(cacheMigrationChoice.rawValue),
            ])
    }

    public func generalSettings(instanceId: String?) async throws -> GeneralSettingsResult {
        try await request(
            method: "settings.general",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateGeneralSettings(
        instanceId: String?,
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) async throws -> GeneralSettingsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["checkForUpdatesOnLaunch"] = .bool(checkForUpdatesOnLaunch)
        params["useDevBuilds"] = .bool(useDevBuilds)
        params["refreshRepositoriesOnLaunch"] = .bool(refreshRepositoriesOnLaunch)
        params["autoSortByUpdate"] = .bool(autoSortByUpdate)
        return try await request(method: "settings.updateGeneral", params: params)
    }

    public func compatibleGameVersions(instanceId: String?) async throws -> CompatibleGameVersionsResult {
        try await request(
            method: "settings.compatibleVersions",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateCompatibleGameVersions(
        instanceId: String?,
        versions: [String]
    ) async throws -> CompatibleGameVersionsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["versions"] = .strings(versions)
        return try await request(
            method: "settings.updateCompatibleVersions",
            params: params)
    }

    public func stabilityTolerance(instanceId: String?) async throws -> StabilityToleranceResult {
        try await request(
            method: "settings.stabilityTolerance",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateStabilityTolerance(
        instanceId: String?,
        stabilityTolerance: String
    ) async throws -> StabilityToleranceResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["stabilityTolerance"] = .string(stabilityTolerance)
        return try await request(
            method: "settings.updateStabilityTolerance",
            params: params)
    }

    public func updateModuleStabilityTolerance(
        instanceId: String?,
        identifier: String,
        stabilityTolerance: String?
    ) async throws -> StabilityToleranceResult {
        var params = stringParams(["instanceId": instanceId, "stabilityTolerance": stabilityTolerance]) ?? [:]
        params["identifier"] = .string(identifier)
        return try await request(
            method: "settings.updateModuleStabilityTolerance",
            params: params)
    }

    public func preferredHosts(instanceId: String?) async throws -> PreferredHostsResult {
        try await request(
            method: "settings.preferredHosts",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updatePreferredHosts(
        instanceId: String?,
        preferredHosts: [String?]
    ) async throws -> PreferredHostsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["preferredHosts"] = .optionalStrings(preferredHosts)
        return try await request(
            method: "settings.updatePreferredHosts",
            params: params)
    }

    public func installFilters(instanceId: String?) async throws -> InstallFiltersResult {
        try await request(
            method: "settings.installFilters",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateInstallFilters(
        instanceId: String?,
        globalFilters: [String],
        instanceFilters: [String]
    ) async throws -> InstallFiltersResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["globalFilters"] = .strings(globalFilters)
        params["instanceFilters"] = .strings(instanceFilters)
        return try await request(
            method: "settings.updateInstallFilters",
            params: params)
    }

    public func recommendationSettings(instanceId: String?) async throws -> RecommendationSettingsResult {
        try await request(
            method: "settings.recommendations",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateRecommendationSettings(
        instanceId: String?,
        suppressRecommendations: Bool
    ) async throws -> RecommendationSettingsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["suppressRecommendations"] = .bool(suppressRecommendations)
        return try await request(
            method: "settings.updateRecommendations",
            params: params)
    }

    public func authTokens() async throws -> AuthTokensResult {
        try await request(method: "settings.authTokens")
    }

    public func addAuthToken(host: String, token: String) async throws -> AuthTokensResult {
        try await request(
            method: "settings.addAuthToken",
            params: stringParams(["host": host, "token": token]))
    }

    public func removeAuthToken(host: String) async throws -> AuthTokensResult {
        try await request(
            method: "settings.removeAuthToken",
            params: stringParams(["host": host]))
    }

}

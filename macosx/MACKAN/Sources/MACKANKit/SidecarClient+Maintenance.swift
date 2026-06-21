import Foundation

extension SidecarClient {
    public func scanGameData(instanceId: String?) async throws -> MaintenanceScanResult {
        try await request(
            method: "maintenance.scan",
            params: stringParams(["instanceId": instanceId]))
    }

    public func listUnmanagedFiles(instanceId: String?) async throws -> UnmanagedFilesResult {
        try await request(
            method: "maintenance.unmanagedFiles",
            params: stringParams(["instanceId": instanceId]))
    }

    public func listInstallationHistory(instanceId: String?) async throws -> InstallationHistoryResult {
        try await request(
            method: "maintenance.history",
            params: stringParams(["instanceId": instanceId]))
    }

    public func loadInstallationHistoryEntry(
        instanceId: String?,
        fileName: String
    ) async throws -> InstallationHistoryEntry {
        try await request(
            method: "maintenance.historyEntry",
            params: stringParams([
                "instanceId": instanceId,
                "fileName": fileName,
            ]))
    }

    public func listPlayTime() async throws -> PlayTimeResult {
        try await request(method: "maintenance.playTime")
    }

    public func updatePlayTime(instanceId: String, hours: Double) async throws -> PlayTimeResult {
        try await request(
            method: "maintenance.updatePlayTime",
            params: [
                "instanceId": .string(instanceId),
                "hours": .double(hours),
            ])
    }

    public func downloadStatistics(instanceId: String?) async throws -> DownloadStatisticsResult {
        try await request(
            method: "maintenance.downloadStatistics",
            params: stringParams(["instanceId": instanceId]))
    }

    public func cacheInfo() async throws -> CacheInfoResult {
        try await request(method: "maintenance.cacheInfo")
    }

    public func clearCache() async throws -> CachePurgeResult {
        try await request(method: "maintenance.clearCache")
    }

    public func purgeCacheToLimit(instanceId: String?) async throws -> CachePurgeResult {
        try await request(
            method: "maintenance.purgeCacheToLimit",
            params: stringParams(["instanceId": instanceId]))
    }

    public func deduplicate() async throws -> DeduplicateResult {
        try await request(method: "maintenance.deduplicate")
    }

    public func repairRegistry(instanceId: String?) async throws -> RepairRegistryResult {
        try await request(
            method: "maintenance.repairRegistry",
            params: stringParams(["instanceId": instanceId]))
    }

    public func removeRegistryLock(instanceId: String?) async throws -> RegistryLockRemovalResult {
        try await request(
            method: "maintenance.removeRegistryLock",
            params: stringParams(["instanceId": instanceId]))
    }

}

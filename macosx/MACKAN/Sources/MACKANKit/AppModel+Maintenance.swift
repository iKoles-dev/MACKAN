import Foundation

extension AppModel {
    public func showCatalog() {
        mainContentRoute = .catalog
    }

    public var isShowingMaintenancePane: Bool {
        if case .maintenance = mainContentRoute {
            return true
        }
        return false
    }

    public func showMaintenancePane(_ pane: MaintenancePane) {
        if mainContentRoute != .maintenance(pane) {
            clearMaintenancePaneResults()
        }
        mainContentRoute = .maintenance(pane)
    }

    public func closeMaintenancePane() {
        clearMaintenancePaneResults()
        showCatalog()
    }

    public func shouldPresentMaintenanceSheet(for pane: MaintenancePane) -> Bool {
        !isShowingMaintenancePane && hasMaintenanceResult(for: pane)
    }

    public func clearMaintenanceResult(for pane: MaintenancePane) {
        switch pane {
        case .history:
            clearInstallationHistoryResult()
        case .unmanagedFiles:
            clearUnmanagedFilesResult()
        case .playTime:
            clearPlayTimeResult()
        case .downloadStatistics:
            clearDownloadStatisticsResult()
        case .cache:
            clearCacheInfoResult()
        }
    }

    public func clearMaintenancePaneResults() {
        for pane in MaintenancePane.allCases {
            clearMaintenanceResult(for: pane)
        }
    }

    public func scanGameData() async throws {
        do {
            let result = try await sidecar.scanGameData(instanceId: selectedInstanceID)
            lastMaintenanceScanResult = result
            maintenanceError = nil
            try await loadInstanceState(for: selectedInstanceID)
        } catch {
            lastMaintenanceScanResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func loadUnmanagedFiles() async throws {
        do {
            let result = try await sidecar.listUnmanagedFiles(instanceId: selectedInstanceID)
            unmanagedFilesResult = result
            maintenanceError = nil
            try await loadInstanceState(for: selectedInstanceID)
        } catch {
            unmanagedFilesResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func loadInstallationHistory() async throws {
        do {
            installationHistoryResult = try await sidecar.listInstallationHistory(instanceId: selectedInstanceID)
            maintenanceError = nil
        } catch {
            installationHistoryResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func stageHistoryModules(_ modules: [InstallationHistoryModule], exactVersions: Bool = false) {
        modules
            .filter { !$0.isInstalled && $0.isAvailable }
            .forEach { module in
                if exactVersions,
                   let version = module.version?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !version.isEmpty
                {
                    stageExactInstall(VersionedModuleSelection(identifier: module.identifier, version: version))
                } else {
                    stage(.install, for: module.identifier)
                }
            }
    }

    public func loadPlayTime() async throws {
        do {
            playTimeResult = try await sidecar.listPlayTime()
            maintenanceError = nil
        } catch {
            playTimeResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func updatePlayTime(instanceId: String, hours: Double) async throws {
        do {
            playTimeResult = try await sidecar.updatePlayTime(instanceId: instanceId, hours: hours)
            maintenanceError = nil
        } catch {
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func loadDownloadStatistics() async throws {
        do {
            downloadStatisticsResult = try await sidecar.downloadStatistics(instanceId: selectedInstanceID)
            maintenanceError = nil
        } catch {
            downloadStatisticsResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func loadCacheInfo() async throws {
        do {
            cacheInfoResult = try await sidecar.cacheInfo()
            lastCachePurgeResult = nil
            maintenanceError = nil
        } catch {
            cacheInfoResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func loadMaintenancePane(_ pane: MaintenancePane) async throws {
        switch pane {
        case .history:
            try await loadInstallationHistory()
        case .unmanagedFiles:
            try await loadUnmanagedFiles()
        case .playTime:
            try await loadPlayTime()
        case .downloadStatistics:
            try await loadDownloadStatistics()
        case .cache:
            try await loadCacheInfo()
        }
    }

    public func clearCache() async throws {
        do {
            let result = try await sidecar.clearCache()
            lastCachePurgeResult = result
            cacheInfoResult = result.cache
            maintenanceError = nil
        } catch {
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func purgeCacheToLimit() async throws {
        do {
            let result = try await sidecar.purgeCacheToLimit(instanceId: selectedInstanceID)
            lastCachePurgeResult = result
            cacheInfoResult = result.cache
            maintenanceError = nil
        } catch {
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func deduplicate() async throws {
        do {
            let result = try await sidecar.deduplicate()
            lastDeduplicateResult = result
            maintenanceError = nil
        } catch {
            lastDeduplicateResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func repairRegistry() async throws {
        do {
            let result = try await sidecar.repairRegistry(instanceId: selectedInstanceID)
            lastRepairRegistryResult = result
            maintenanceError = nil
            if result.status == "completed" {
                try await loadInstanceState(for: selectedInstanceID)
            }
        } catch {
            lastRepairRegistryResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func removeRegistryLock() async throws {
        do {
            let result = try await sidecar.removeRegistryLock(instanceId: selectedInstanceID)
            lastRegistryLockRemovalResult = result
            maintenanceError = nil
            changeSetError = nil
            changeSetErrorDetails = nil
            operationError = nil
            operationErrorDetails = nil
            if result.removed {
                try await loadInstanceState(for: selectedInstanceID)
            }
        } catch {
            lastRegistryLockRemovalResult = nil
            maintenanceError = error.localizedDescription
            throw error
        }
    }

    public func clearMaintenanceScanResult() {
        lastMaintenanceScanResult = nil
    }

    public func clearUnmanagedFilesResult() {
        unmanagedFilesResult = nil
    }

    public func clearInstallationHistoryResult() {
        installationHistoryResult = nil
    }

    public func clearPlayTimeResult() {
        playTimeResult = nil
    }

    public func clearDownloadStatisticsResult() {
        downloadStatisticsResult = nil
    }

    public func clearCacheInfoResult() {
        cacheInfoResult = nil
        lastCachePurgeResult = nil
    }

    public func clearDeduplicateResult() {
        lastDeduplicateResult = nil
    }

    public func clearRepairRegistryResult() {
        lastRepairRegistryResult = nil
    }

    public func clearRegistryLockRemovalResult() {
        lastRegistryLockRemovalResult = nil
    }

    public func clearMaintenanceError() {
        maintenanceError = nil
    }

    public func reportMaintenanceError(_ error: Error) {
        maintenanceError = error.localizedDescription
    }

    private func hasMaintenanceResult(for pane: MaintenancePane) -> Bool {
        switch pane {
        case .history:
            return installationHistoryResult != nil
        case .unmanagedFiles:
            return unmanagedFilesResult != nil
        case .playTime:
            return playTimeResult != nil
        case .downloadStatistics:
            return downloadStatisticsResult != nil
        case .cache:
            return cacheInfoResult != nil
        }
    }
}

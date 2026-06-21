import Foundation

extension AppModel {
    public func showCatalog() {
        if isShowingMaintenancePane {
            clearMaintenancePaneResults()
        }
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
            clearMaintenanceError()
            try await loadInstanceState(for: selectedInstanceID)
        } catch {
            lastMaintenanceScanResult = nil
            reportMaintenanceError(error, title: "GameData scan failed")
            throw error
        }
    }

    public func loadUnmanagedFiles() async throws {
        do {
            let result = try await sidecar.listUnmanagedFiles(instanceId: selectedInstanceID)
            unmanagedFilesResult = result
            clearMaintenanceError()
        } catch {
            unmanagedFilesResult = nil
            reportMaintenanceError(error, title: "Unmanaged Files failed")
            throw error
        }
    }

    public func loadInstallationHistory() async throws {
        do {
            installationHistoryResult = try await sidecar.listInstallationHistory(instanceId: selectedInstanceID)
            selectedInstallationHistoryEntry = nil
            clearMaintenanceError()
        } catch {
            installationHistoryResult = nil
            selectedInstallationHistoryEntry = nil
            reportMaintenanceError(error, title: "History failed")
            throw error
        }
    }

    public func loadInstallationHistoryEntry(fileName: String) async throws {
        installationHistoryEntryLoadGeneration += 1
        let loadGeneration = installationHistoryEntryLoadGeneration
        do {
            let entry = try await sidecar.loadInstallationHistoryEntry(
                instanceId: selectedInstanceID,
                fileName: fileName)
            guard loadGeneration == installationHistoryEntryLoadGeneration else {
                return
            }
            selectedInstallationHistoryEntry = entry
            clearMaintenanceError()
        } catch {
            guard loadGeneration == installationHistoryEntryLoadGeneration else {
                return
            }
            selectedInstallationHistoryEntry = nil
            reportMaintenanceError(error, title: "History failed")
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
            clearMaintenanceError()
        } catch {
            playTimeResult = nil
            reportMaintenanceError(error, title: "Play Time failed")
            throw error
        }
    }

    public func updatePlayTime(instanceId: String, hours: Double) async throws {
        do {
            playTimeResult = try await sidecar.updatePlayTime(instanceId: instanceId, hours: hours)
            clearMaintenanceError()
        } catch {
            reportMaintenanceError(error, title: "Play Time failed")
            throw error
        }
    }

    public func loadDownloadStatistics() async throws {
        do {
            downloadStatisticsResult = try await sidecar.downloadStatistics(instanceId: selectedInstanceID)
            clearMaintenanceError()
        } catch {
            downloadStatisticsResult = nil
            reportMaintenanceError(error, title: "Download Statistics failed")
            throw error
        }
    }

    public func loadCacheInfo() async throws {
        do {
            cacheInfoResult = try await sidecar.cacheInfo()
            lastCachePurgeResult = nil
            clearMaintenanceError()
        } catch {
            cacheInfoResult = nil
            reportMaintenanceError(error, title: "Cache failed")
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
            clearMaintenanceError()
        } catch {
            reportMaintenanceError(error, title: "Cache failed")
            throw error
        }
    }

    public func purgeCacheToLimit() async throws {
        do {
            let result = try await sidecar.purgeCacheToLimit(instanceId: selectedInstanceID)
            lastCachePurgeResult = result
            cacheInfoResult = result.cache
            clearMaintenanceError()
        } catch {
            reportMaintenanceError(error, title: "Cache failed")
            throw error
        }
    }

    public func deduplicate() async throws {
        do {
            let result = try await sidecar.deduplicate()
            lastDeduplicateResult = result
            clearMaintenanceError()
        } catch {
            lastDeduplicateResult = nil
            reportMaintenanceError(error, title: "Deduplicate failed")
            throw error
        }
    }

    public func repairRegistry() async throws {
        do {
            let result = try await sidecar.repairRegistry(instanceId: selectedInstanceID)
            lastRepairRegistryResult = result
            clearMaintenanceError()
            if result.status == "completed" {
                try await loadInstanceState(for: selectedInstanceID)
            }
        } catch {
            lastRepairRegistryResult = nil
            reportMaintenanceError(error, title: "Repair Registry failed")
            throw error
        }
    }

    public func removeRegistryLock() async throws {
        do {
            let result = try await sidecar.removeRegistryLock(instanceId: selectedInstanceID)
            lastRegistryLockRemovalResult = result
            clearMaintenanceError()
            changeSetError = nil
            changeSetErrorDetails = nil
            operationError = nil
            operationErrorDetails = nil
            if result.removed {
                try await loadInstanceState(for: selectedInstanceID)
            }
        } catch {
            lastRegistryLockRemovalResult = nil
            reportMaintenanceError(error, title: "Remove Registry Lock failed")
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
        installationHistoryEntryLoadGeneration += 1
        installationHistoryResult = nil
        selectedInstallationHistoryEntry = nil
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
        maintenanceErrorTitle = "Maintenance failed"
    }

    public func reportMaintenanceError(_ error: Error) {
        reportMaintenanceError(error, title: "Maintenance failed")
    }

    public func reportMaintenanceError(_ error: Error, title: String) {
        maintenanceErrorTitle = title
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

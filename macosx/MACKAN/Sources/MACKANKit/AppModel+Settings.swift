import Foundation

extension AppModel {
    public func loadSettings() async throws {
        do {
            settings = try await sidecar.getSettings()
            settingsError = nil
        } catch {
            settings = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateSettings(
        downloadCacheDir: String,
        cacheSizeLimitBytes: Int64?,
        cacheMigrationChoice: CacheMigrationChoice = .keep
    ) async throws {
        do {
            settings = try await sidecar.updateSettings(
                downloadCacheDir: downloadCacheDir.trimmingCharacters(in: .whitespacesAndNewlines),
                cacheSizeLimitBytes: cacheSizeLimitBytes,
                cacheMigrationChoice: cacheMigrationChoice)
            cacheInfoResult = try await sidecar.cacheInfo()
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadGeneralSettings() async throws {
        do {
            generalSettings = try await sidecar.generalSettings(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            generalSettings = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateGeneralSettings(
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) async throws {
        do {
            generalSettings = try await sidecar.updateGeneralSettings(
                instanceId: selectedInstanceID,
                checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
                useDevBuilds: useDevBuilds,
                refreshRepositoriesOnLaunch: refreshRepositoriesOnLaunch,
                autoSortByUpdate: autoSortByUpdate)
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadRecommendationSettings() async throws {
        do {
            recommendationSettings = try await sidecar.recommendationSettings(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            recommendationSettings = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateSuppressRecommendations(_ suppressRecommendations: Bool) async throws {
        do {
            recommendationSettings = try await sidecar.updateRecommendationSettings(
                instanceId: selectedInstanceID,
                suppressRecommendations: suppressRecommendations)
            settingsError = nil
            if hasPendingSelections {
                try await resolveChanges()
            }
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadCompatibleGameVersions() async throws {
        do {
            compatibleGameVersions = try await sidecar.compatibleGameVersions(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            compatibleGameVersions = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateCompatibleGameVersions(_ versions: [String]) async throws {
        let cleanedVersions = versions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            let result = try await sidecar.updateCompatibleGameVersions(
                instanceId: selectedInstanceID,
                versions: cleanedVersions)
            try await loadInstanceState(for: selectedInstanceID)
            compatibleGameVersions = result
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadStabilityTolerance() async throws {
        do {
            stabilityTolerance = try await sidecar.stabilityTolerance(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            stabilityTolerance = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateStabilityTolerance(_ stabilityTolerance: String) async throws {
        let cleanedTolerance = stabilityTolerance.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await sidecar.updateStabilityTolerance(
                instanceId: selectedInstanceID,
                stabilityTolerance: cleanedTolerance)
            try await loadInstanceState(for: selectedInstanceID)
            self.stabilityTolerance = result
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateModuleStabilityTolerance(
        identifier: String,
        stabilityTolerance: String?
    ) async throws {
        let cleanedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTolerance = stabilityTolerance?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await sidecar.updateModuleStabilityTolerance(
                instanceId: selectedInstanceID,
                identifier: cleanedIdentifier,
                stabilityTolerance: cleanedTolerance?.isEmpty == true ? nil : cleanedTolerance)
            try await loadInstanceState(for: selectedInstanceID)
            self.stabilityTolerance = result
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadPreferredHosts() async throws {
        do {
            preferredHosts = try await sidecar.preferredHosts(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            preferredHosts = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updatePreferredHosts(_ preferredHosts: [String?]) async throws {
        let cleanedHosts = preferredHosts.compactMap { host -> String?? in
            guard let host else {
                return .some(nil)
            }
            let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedHost.isEmpty ? nil : .some(cleanedHost)
        }
        do {
            self.preferredHosts = try await sidecar.updatePreferredHosts(
                instanceId: selectedInstanceID,
                preferredHosts: cleanedHosts)
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadInstallFilters() async throws {
        do {
            installFilters = try await sidecar.installFilters(instanceId: selectedInstanceID)
            settingsError = nil
        } catch {
            installFilters = nil
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func updateInstallFilters(globalFilters: [String], instanceFilters: [String]) async throws {
        let cleanedGlobalFilters = normalizeInstallFilters(globalFilters)
        let cleanedInstanceFilters = normalizeInstallFilters(instanceFilters)
        do {
            installFilters = try await sidecar.updateInstallFilters(
                instanceId: selectedInstanceID,
                globalFilters: cleanedGlobalFilters,
                instanceFilters: cleanedInstanceFilters)
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func loadAuthTokens() async throws {
        do {
            authTokens = try await sidecar.authTokens().authTokens
            settingsError = nil
        } catch {
            authTokens = []
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func addAuthToken(host: String, token: String) async throws {
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            authTokens = try await sidecar.addAuthToken(
                host: cleanedHost,
                token: cleanedToken).authTokens
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func removeAuthToken(host: String) async throws {
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            authTokens = try await sidecar.removeAuthToken(host: cleanedHost).authTokens
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
            throw error
        }
    }

    public func clearSettingsError() {
        settingsError = nil
    }

    private func normalizeInstallFilters(_ filters: [String]) -> [String] {
        filters
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniquedCaseInsensitive()
    }
}

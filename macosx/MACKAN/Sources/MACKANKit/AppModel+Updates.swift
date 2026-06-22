import Foundation

extension AppModel {
    public func checkForUpdates(useDevBuilds: Bool? = nil) async throws {
        isCheckingForUpdates = true
        updateCheckError = nil
        defer { isCheckingForUpdates = false }

        do {
            let result = try await sidecar.checkForUpdates(useDevBuilds: useDevBuilds)
            updateCheckResult = result
            if result.status == "failed" {
                updateCheckError = userFacingUpdateCheckError(result.error)
            }
        } catch {
            updateCheckError = userFacingUpdateCheckError(error.localizedDescription)
            throw error
        }
    }

    public func checkForUpdatesOnLaunchIfNeeded() async -> Bool {
        do {
            let settings = try await sidecar.generalSettings(instanceId: selectedInstanceID)
            generalSettings = settings
            settingsError = nil
            await refreshRepositoriesOnLaunchIfNeeded(settings)
            guard settings.checkForUpdatesOnLaunch else {
                return false
            }

            try await checkForUpdates(useDevBuilds: settings.useDevBuilds)
            return updateCheckResult?.status == "available"
                || updateCheckResult?.status == "failed"
        } catch {
            settingsError = error.localizedDescription
            return false
        }
    }

    private func refreshRepositoriesOnLaunchIfNeeded(_ settings: GeneralSettingsResult) async {
        guard settings.refreshRepositoriesOnLaunch,
              selectedInstanceID != nil
        else {
            return
        }

        do {
            try await refreshRepositories(force: false)
            settingsError = nil
        } catch {
            settingsError = error.localizedDescription
        }
    }

    private func userFacingUpdateCheckError(_ message: String?) -> String {
        let cleanedMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleanedMessage.isEmpty else {
            return "Update check failed. Install the signed MACKAN DMG manually from the release page."
        }

        if cleanedMessage.localizedCaseInsensitiveCompare("Sequence contains no matching element") == .orderedSame {
            return "Update metadata could not be read. Try again later or install the signed MACKAN DMG manually from the release page."
        }

        return cleanedMessage
    }
}

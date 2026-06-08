import Foundation

extension AppModel {
    public func launchSelectedGame(commandLine: String? = nil) async throws {
        try await launchSelectedGame(
            commandLine: commandLine,
            allowIncompatible: false,
            suppressIncompatibleWarning: false)
    }

    public func confirmPendingLaunchWarning(suppressFutureWarnings: Bool) async throws {
        guard let pendingLaunchWarning else {
            return
        }

        try await launchSelectedGame(
            commandLine: pendingLaunchWarning.commandLine,
            allowIncompatible: true,
            suppressIncompatibleWarning: suppressFutureWarnings)
    }

    public func cancelPendingLaunchWarning() {
        pendingLaunchWarning = nil
        launchError = nil
        launchErrorDetails = nil
    }

    public func clearLaunchError() {
        launchError = nil
        launchErrorDetails = nil
    }

    public func saveLaunchCommands(_ commandLines: [String]) async throws {
        let cleanedCommandLines = commandLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedCommandLines.isEmpty else {
            launchError = "At least one launch command is required."
            throw InstanceDirectoryOpenError.emptyPath
        }

        do {
            let result = try await sidecar.updateLaunchOptions(
                instanceId: selectedInstanceID,
                commandLines: cleanedCommandLines)
            launchCommands = result.commandLines
            defaultLaunchCommands = result.defaultCommandLines
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            throw error
        }
    }

    public func resetLaunchCommandsToDefaults() async throws {
        try await saveLaunchCommands(defaultLaunchCommands)
    }

    private func launchSelectedGame(
        commandLine: String? = nil,
        allowIncompatible: Bool,
        suppressIncompatibleWarning: Bool
    ) async throws {
        guard let selectedInstanceID else {
            throw InstanceDirectoryOpenError.missingInstance
        }

        let command = commandLine
            ?? launchCommands.first
        guard let command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            launchError = "The selected game instance does not have a launch command."
            throw InstanceDirectoryOpenError.emptyPath
        }
        if !allowIncompatible && !incompatibleLaunchModules.isEmpty {
            pendingLaunchWarning = PendingLaunchWarning(
                commandLine: command,
                modules: incompatibleLaunchModules)
            launchError = nil
            launchErrorDetails = nil
            return
        }

        isLaunchingGame = true
        defer { isLaunchingGame = false }
        do {
            let result = try await sidecar.launchGame(
                instanceId: selectedInstanceID,
                commandLine: command,
                suppressIncompatibleWarnings: suppressIncompatibleWarning)
            lastLaunchResult = result
            pendingLaunchWarning = nil
            if suppressIncompatibleWarning {
                incompatibleLaunchModules = []
            }
            launchError = nil
            launchErrorDetails = nil
        } catch {
            lastLaunchResult = nil
            launchError = userFacingMessage(for: error)
            launchErrorDetails = errorDetails(for: error)
            throw error
        }
    }
}

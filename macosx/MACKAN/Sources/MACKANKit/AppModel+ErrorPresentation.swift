extension AppModel {
    func userFacingMessage(for error: Error) -> String {
        if case let SidecarClientError.registryLocked(message, _) = error {
            return message
        }
        if case let SidecarClientError.operationError(message, _) = error {
            return message
        }
        if case let SidecarClientError.launchFailure(message, command, _) = error {
            if let command {
                return "\(message) (command: \(command))"
            }
            return message
        }
        return error.localizedDescription
    }

    func errorDetails(for error: Error) -> SidecarErrorDetails? {
        if case let SidecarClientError.registryLocked(_, lockfilePath) = error {
            return .registryLock(lockfilePath)
        }
        if case let SidecarClientError.launchFailure(_, command, suggestedAction) = error {
            return .launchFailure(command: command, suggestedAction: suggestedAction)
        }
        if case let SidecarClientError.operationError(_, details) = error {
            return details
        }
        return nil
    }
}

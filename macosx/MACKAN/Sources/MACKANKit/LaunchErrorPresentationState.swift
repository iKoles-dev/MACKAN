public struct LaunchErrorPresentationState: Equatable, Sendable {
    public let message: String
    public let details: SidecarErrorDetails?

    public init(message: String, details: SidecarErrorDetails?) {
        self.message = message
        self.details = details
    }

    public var canRetry: Bool {
        details?.kind == "launchFailure"
    }

    public var messageText: String {
        guard let details, details.kind == "launchFailure" else {
            return message
        }

        var lines = [message]
        if let command = details.command, !command.isEmpty {
            lines.append("Command: \(command)")
        }
        if let suggestedAction = details.suggestedAction, !suggestedAction.isEmpty {
            lines.append("Suggested action: \(suggestedAction)")
        }
        return lines.joined(separator: "\n")
    }
}

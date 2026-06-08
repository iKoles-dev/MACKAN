public struct PendingLaunchWarning: Equatable, Sendable {
    public let commandLine: String
    public let modules: [LaunchWarningModule]

    public init(commandLine: String, modules: [LaunchWarningModule]) {
        self.commandLine = commandLine
        self.modules = modules
    }
}

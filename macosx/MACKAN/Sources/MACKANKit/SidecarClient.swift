import Foundation

public protocol SidecarProviding: Sendable {
    func health() async throws -> SidecarHealth
    func version() async throws -> SidecarVersion
    func checkForUpdates(useDevBuilds: Bool?) async throws -> UpdateCheckResult
    func listInstances() async throws -> SidecarInstancesResult
    func addInstance(path: String, name: String) async throws -> SidecarInstancesResult
    func cloneOptions(sourceInstanceId: String) async throws -> CloneOptionsResult
    func cloneInstance(
        sourceInstanceId: String,
        newName: String,
        newPath: String,
        shareStock: Bool,
        leaveEmptyPaths: [String]?
    ) async throws -> SidecarInstancesResult
    func fakeInstance(
        name: String,
        path: String,
        version: String,
        gameId: String,
        makingHistoryVersion: String?,
        breakingGroundVersion: String?,
        setDefault: Bool
    ) async throws -> SidecarInstancesResult
    func setDefaultInstance(_ instanceId: String) async throws -> SidecarInstancesResult
    func removeInstance(_ instanceId: String) async throws -> SidecarInstancesResult
    func renameInstance(_ instanceId: String, to newName: String) async throws -> SidecarInstancesResult
    func launchOptions(instanceId: String?) async throws -> LaunchOptionsResult
    func updateLaunchOptions(instanceId: String?, commandLines: [String]) async throws -> LaunchOptionsResult
    func launchGame(
        instanceId: String?,
        commandLine: String?,
        suppressIncompatibleWarnings: Bool
    ) async throws -> LaunchGameResult
    func listModules(instanceId: String?) async throws -> SidecarModulesResult
    func startListModules(instanceId: String?) async throws -> ModuleListOperationResult
    func moduleListStatus(operationId: String) async throws -> ModuleListOperationResult
    func cancelModuleList(operationId: String) async throws -> ModuleListOperationResult
    func listLabels(instanceId: String?) async throws -> SidecarLabelsResult
    func toggleModuleLabel(instanceId: String?, labelName: String, identifier: String) async throws -> SidecarLabelsResult
    func upsertModuleLabel(
        instanceId: String?,
        originalName: String?,
        originalInstanceName: String?,
        label: ModuleLabelEdit
    ) async throws -> SidecarLabelsResult
    func deleteModuleLabel(instanceId: String?, name: String, instanceName: String?) async throws -> SidecarLabelsResult
    func setAutoInstalled(instanceId: String?, identifier: String, isAutoInstalled: Bool) async throws -> SidecarModulesResult
    func moduleDetails(instanceId: String?, identifier: String) async throws -> ModuleDetails
    func listRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult
    func listAvailableRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult
    func addRepository(instanceId: String?, name: String, url: String) async throws -> SidecarRepositoriesResult
    func removeRepository(instanceId: String?, name: String) async throws -> SidecarRepositoriesResult
    func setRepositoryPriority(instanceId: String?, name: String, priority: Int) async throws -> SidecarRepositoriesResult
    func refreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult
    func startRefreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult
    func repositoryRefreshStatus(operationId: String) async throws -> RepositoryRefreshResult
    func cancelRepositoryRefresh(operationId: String) async throws -> RepositoryRefreshResult
    func resolveChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection]
    ) async throws -> ChangeSetResult
    func applyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func startApplyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func installCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection],
        recommendationSelections: [String],
        skipRecommendations: Bool,
        allowIncompatibleCkanFiles: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func startInstallCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection],
        recommendationSelections: [String],
        skipRecommendations: Bool,
        allowIncompatibleCkanFiles: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func importDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func startImportDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult
    func exportModList(instanceId: String?, format: ModListExportFormat) async throws -> ModListExportResult
    func exportModpack(instanceId: String?, draft: ModpackExportDraft) async throws -> ModpackExportResult
    func scanGameData(instanceId: String?) async throws -> MaintenanceScanResult
    func listUnmanagedFiles(instanceId: String?) async throws -> UnmanagedFilesResult
    func listInstallationHistory(instanceId: String?) async throws -> InstallationHistoryResult
    func loadInstallationHistoryEntry(instanceId: String?, fileName: String) async throws -> InstallationHistoryEntry
    func listPlayTime() async throws -> PlayTimeResult
    func updatePlayTime(instanceId: String, hours: Double) async throws -> PlayTimeResult
    func downloadStatistics(instanceId: String?) async throws -> DownloadStatisticsResult
    func cacheInfo() async throws -> CacheInfoResult
    func clearCache() async throws -> CachePurgeResult
    func purgeCacheToLimit(instanceId: String?) async throws -> CachePurgeResult
    func deduplicate() async throws -> DeduplicateResult
    func repairRegistry(instanceId: String?) async throws -> RepairRegistryResult
    func removeRegistryLock(instanceId: String?) async throws -> RegistryLockRemovalResult
    func getSettings() async throws -> SettingsResult
    func updateSettings(
        downloadCacheDir: String,
        cacheSizeLimitBytes: Int64?,
        cacheMigrationChoice: CacheMigrationChoice
    ) async throws -> SettingsResult
    func generalSettings(instanceId: String?) async throws -> GeneralSettingsResult
    func updateGeneralSettings(
        instanceId: String?,
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) async throws -> GeneralSettingsResult
    func compatibleGameVersions(instanceId: String?) async throws -> CompatibleGameVersionsResult
    func updateCompatibleGameVersions(instanceId: String?, versions: [String]) async throws -> CompatibleGameVersionsResult
    func stabilityTolerance(instanceId: String?) async throws -> StabilityToleranceResult
    func updateStabilityTolerance(instanceId: String?, stabilityTolerance: String) async throws -> StabilityToleranceResult
    func updateModuleStabilityTolerance(
        instanceId: String?,
        identifier: String,
        stabilityTolerance: String?
    ) async throws -> StabilityToleranceResult
    func preferredHosts(instanceId: String?) async throws -> PreferredHostsResult
    func updatePreferredHosts(instanceId: String?, preferredHosts: [String?]) async throws -> PreferredHostsResult
    func installFilters(instanceId: String?) async throws -> InstallFiltersResult
    func updateInstallFilters(
        instanceId: String?,
        globalFilters: [String],
        instanceFilters: [String]
    ) async throws -> InstallFiltersResult
    func recommendationSettings(instanceId: String?) async throws -> RecommendationSettingsResult
    func updateRecommendationSettings(
        instanceId: String?,
        suppressRecommendations: Bool
    ) async throws -> RecommendationSettingsResult
    func authTokens() async throws -> AuthTokensResult
    func addAuthToken(host: String, token: String) async throws -> AuthTokensResult
    func removeAuthToken(host: String) async throws -> AuthTokensResult
    func operationStatus(operationId: String) async throws -> OperationResult
    func cancelOperation(operationId: String) async throws -> OperationResult
}

public typealias SidecarHealthProviding = SidecarProviding

protocol SidecarTransport: Sendable {
    func request(_ requestLine: String) async throws -> String
}

public enum SidecarClientError: Error, LocalizedError, Equatable {
    case serviceProjectNotFound
    case invalidResponse
    case rpcError(code: Int, message: String)
    case registryLocked(message: String, lockfilePath: String?)
    case launchFailure(message: String, command: String?, suggestedAction: String?)
    case operationError(message: String, details: SidecarErrorDetails)
    case processFailed(Int32, String)

    public var errorDescription: String? {
        switch self {
        case .serviceProjectNotFound:
            return "MACKAN.Service project was not found."
        case .invalidResponse:
            return "MACKAN.Service returned an invalid response."
        case .rpcError(_, let message):
            return message
        case .registryLocked(let message, let lockfilePath):
            if let lockfilePath {
                return "\(message) (\(lockfilePath))"
            }
            return message
        case .launchFailure(let message, let command, _):
            if let command {
                return "\(message) (command: \(command))"
            }
            return message
        case .operationError(let message, let details):
            if let suggestedAction = details.suggestedAction, !suggestedAction.isEmpty {
                return "\(message) (suggested action: \(suggestedAction))"
            }
            return message
        case .processFailed(let status, let stderr):
            return "MACKAN.Service exited with status \(status): \(stderr)"
        }
    }
}

public final class SidecarClient: SidecarProviding {
    public struct Command: Sendable {
        public let executableURL: URL
        public let arguments: [String]
        public let workingDirectory: URL?

        public init(executableURL: URL, arguments: [String], workingDirectory: URL? = nil) {
            self.executableURL = executableURL
            self.arguments = arguments
            self.workingDirectory = workingDirectory
        }
    }

    public static func defaultClient() -> SidecarClient {
        SidecarClient(command: defaultCommand())
    }

    static func defaultCommand(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> Command? {
        if let executable = environment["MACKAN_SERVICE_EXECUTABLE"] {
            return Command(executableURL: URL(fileURLWithPath: executable), arguments: ["--stdio"])
        }

        if let project = environment["MACKAN_SERVICE_PROJECT"] {
            return dotnetStdioCommand(projectPath: project)
        }

        if let command = bundledSidecarCommand(resourceURL: bundleResourceURL) {
            return command
        }

        if let discovered = discoverServiceProject(currentDirectoryPath: currentDirectoryPath) {
            return dotnetStdioCommand(projectPath: discovered.path)
        }

        return nil
    }

    public init(command: Command?) {
        self.transport = command.map { StdioSidecarTransport(command: $0) }
    }

    init(transport: any SidecarTransport) {
        self.transport = transport
    }

    public static func decodeHealthResponse(from output: String) throws -> SidecarHealth {
        try decodeResponse(from: output)
    }

    public static func decodeInstancesResponse(from output: String) throws -> SidecarInstancesResult {
        try decodeResponse(from: output)
    }

    public static func decodeModulesResponse(from output: String) throws -> SidecarModulesResult {
        try decodeResponse(from: output)
    }

    public static func decodeLabelsResponse(from output: String) throws -> SidecarLabelsResult {
        try decodeResponse(from: output)
    }

    public static func decodeLaunchOptionsResponse(from output: String) throws -> LaunchOptionsResult {
        try decodeResponse(from: output)
    }

    public static func decodeLaunchGameResponse(from output: String) throws -> LaunchGameResult {
        try decodeResponse(from: output)
    }

    public static func decodeModuleDetailsResponse(from output: String) throws -> ModuleDetails {
        try decodeResponse(from: output)
    }

    public static func decodeRepositoriesResponse(from output: String) throws -> SidecarRepositoriesResult {
        try decodeResponse(from: output)
    }

    public static func decodeRepositoryRefreshResponse(from output: String) throws -> RepositoryRefreshResult {
        try decodeResponse(from: output)
    }

    public static func decodeChangeSetResponse(from output: String) throws -> ChangeSetResult {
        try decodeResponse(from: output)
    }

    public static func decodeOperationResultResponse(from output: String) throws -> OperationResult {
        try decodeResponse(from: output)
    }

    private let transport: (any SidecarTransport)?

    func request<Result: Decodable>(
        method: String,
        params: [String: JSONRPCParameterValue]? = nil
    ) async throws -> Result {
        guard let transport else {
            throw SidecarClientError.serviceProjectNotFound
        }
        let data = try JSONEncoder().encode(JSONRPCRequest(jsonrpc: "2.0", id: 1, method: method, params: params))
        guard let requestLine = String(data: data, encoding: .utf8) else {
            throw SidecarClientError.invalidResponse
        }
        let output = try await transport.request(requestLine + "\n")
        return try Self.decodeResponse(from: output)
    }

    func stringParams(_ params: [String: String?]) -> [String: JSONRPCParameterValue]? {
        let encoded = params.compactMapValues { value -> JSONRPCParameterValue? in
            value.map(JSONRPCParameterValue.string)
        }
        return encoded.isEmpty ? nil : encoded
    }

    func changeSetParams(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool = false
    ) -> [String: JSONRPCParameterValue]? {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        if !install.isEmpty {
            params["install"] = .strings(install)
        }
        if !remove.isEmpty {
            params["remove"] = .strings(remove)
        }
        if !upgrade.isEmpty {
            params["upgrade"] = .strings(upgrade)
        }
        if !replace.isEmpty {
            params["replace"] = .strings(replace)
        }
        if !installVersions.isEmpty {
            params["installVersions"] = .objects(installVersions.map(\.parameterObject))
        }
        if !providerSelections.isEmpty {
            params["providerSelections"] = .objects(providerSelections.map(\.parameterObject))
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return params.isEmpty ? nil : params
    }

    private static func decodeResponse<Result: Decodable>(from output: String) throws -> Result {
        guard let jsonLine = output
            .split(whereSeparator: \.isNewline)
            .last(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") })
        else {
            throw SidecarClientError.invalidResponse
        }

        let data = Data(String(jsonLine).utf8)
        let envelope = try JSONDecoder().decode(JSONRPCEnvelope<Result>.self, from: data)
        if let error = envelope.error {
            if let details = error.data {
                switch details.kind {
                case "launchFailure":
                    throw SidecarClientError.launchFailure(
                        message: error.message,
                        command: details.command,
                        suggestedAction: details.suggestedAction)
                case "registryLock":
                    throw SidecarClientError.registryLocked(
                        message: error.message,
                        lockfilePath: details.lockfilePath)
                default:
                    throw SidecarClientError.operationError(message: error.message, details: details)
                }
            }
            throw SidecarClientError.rpcError(code: error.code, message: error.message)
        }
        guard let result = envelope.result else {
            throw SidecarClientError.invalidResponse
        }
        return result
    }

    private static func dotnetStdioCommand(projectPath: String) -> Command {
        Command(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["dotnet", "run", "--project", projectPath, "--", "--stdio"]
        )
    }

    private static func bundledSidecarCommand(resourceURL: URL?) -> Command? {
        guard let resourceURL else {
            return nil
        }

        let serviceDirectory = resourceURL.appendingPathComponent("MACKAN.Service", isDirectory: true)
        if let architectureDirectory = currentRuntimeIdentifier.map({
            serviceDirectory.appendingPathComponent($0, isDirectory: true)
        }),
           let command = bundledSidecarCommand(in: architectureDirectory) {
            return command
        }

        return bundledSidecarCommand(in: serviceDirectory)
    }

    private static func bundledSidecarCommand(in serviceDirectory: URL) -> Command? {
        let executable = serviceDirectory.appendingPathComponent("MACKAN.Service")
        if FileManager.default.fileExists(atPath: executable.path) {
            return Command(
                executableURL: executable,
                arguments: ["--stdio"],
                workingDirectory: serviceDirectory
            )
        }

        let frameworkDependentAssembly = serviceDirectory.appendingPathComponent("MACKAN.Service.dll")
        if FileManager.default.fileExists(atPath: frameworkDependentAssembly.path) {
            return Command(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["dotnet", frameworkDependentAssembly.path, "--stdio"],
                workingDirectory: serviceDirectory
            )
        }

        return nil
    }

    private static var currentRuntimeIdentifier: String? {
#if arch(arm64)
        return "osx-arm64"
#elseif arch(x86_64)
        return "osx-x64"
#else
        return nil
#endif
    }

    private static func discoverServiceProject(currentDirectoryPath: String) -> URL? {
        let fileManager = FileManager.default
        var current = URL(fileURLWithPath: currentDirectoryPath)

        for _ in 0..<8 {
            let candidate = current
                .appendingPathComponent("MACKAN.Service")
                .appendingPathComponent("MACKAN.Service.csproj")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            current.deleteLastPathComponent()
        }
        return nil
    }

}

actor StdioSidecarTransport: SidecarTransport {
    private let command: SidecarClient.Command
    private var process: Process?
    private var stdout: Pipe?
    private var stderr: Pipe?
    private var stdin: Pipe?

    init(command: SidecarClient.Command) {
        self.command = command
    }

    deinit {
        try? stdin?.fileHandleForWriting.close()
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    func request(_ requestLine: String) async throws -> String {
        try startIfNeeded()
        guard
            let process,
            let stdout,
            let stdin
        else {
            throw SidecarClientError.invalidResponse
        }

        stdin.fileHandleForWriting.write(Data(requestLine.utf8))
        let output = try readResponse(from: stdout.fileHandleForReading)
        guard process.isRunning || process.terminationStatus == 0 else {
            throw SidecarClientError.processFailed(process.terminationStatus, stderrText())
        }
        return output
    }

    private func startIfNeeded() throws {
        if let process {
            if process.isRunning {
                return
            }
            throw SidecarClientError.processFailed(process.terminationStatus, stderrText())
        }

        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.currentDirectoryURL = command.workingDirectory

        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin

        try process.run()
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
        self.stdin = stdin
    }

    private func readResponse(from handle: FileHandle) throws -> String {
        var lines: [String] = []
        while true {
            guard let line = Self.readLine(from: handle) else {
                if let process, !process.isRunning {
                    throw SidecarClientError.processFailed(process.terminationStatus, stderrText())
                }
                throw SidecarClientError.invalidResponse
            }
            lines.append(line)
            if Self.isJSONRPCResponseLine(line) {
                return lines.joined(separator: "\n")
            }
        }
    }

    private static func isJSONRPCResponseLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }
        return object.keys.contains("id")
    }

    private static func readLine(from handle: FileHandle) -> String? {
        var data = Data()
        while true {
            let nextByte = handle.readData(ofLength: 1)
            if nextByte.isEmpty {
                return data.isEmpty ? nil : String(data: data, encoding: .utf8)
            }
            if nextByte[0] == 0x0A {
                return String(data: data, encoding: .utf8) ?? ""
            }
            data.append(nextByte)
        }
    }

    private func stderrText() -> String {
        guard let stderr else {
            return ""
        }
        let data = stderr.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct JSONRPCRequest: Encodable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: [String: JSONRPCParameterValue]?
}

enum JSONRPCParameterValue: Encodable {
    case string(String)
    case int(Int)
    case int64(Int64)
    case double(Double)
    case bool(Bool)
    case strings([String])
    case optionalStrings([String?])
    case object([String: JSONRPCParameterValue])
    case objects([[String: JSONRPCParameterValue]])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .int64(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .strings(let value):
            try container.encode(value)
        case .optionalStrings(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .objects(let value):
            try container.encode(value)
        }
    }
}

extension ProviderSelection {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "requested": .string(requested),
            "requesterIdentifier": .string(requesterIdentifier),
            "selectedIdentifier": .string(selectedIdentifier),
        ]
    }
}

extension VersionedModuleSelection {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "identifier": .string(identifier),
            "version": .string(version),
        ]
    }
}

extension ModpackRelationshipAssignment {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "identifier": .string(identifier),
            "kind": .string(kind),
        ]
    }
}

extension ModuleLabelEdit {
    var parameterValue: JSONRPCParameterValue {
        var values: [String: JSONRPCParameterValue] = [
            "name": .string(name),
            "hide": .bool(hide),
            "notifyOnChange": .bool(notifyOnChange),
            "removeOnChange": .bool(removeOnChange),
            "alertOnInstall": .bool(alertOnInstall),
            "removeOnInstall": .bool(removeOnInstall),
            "holdVersion": .bool(holdVersion),
            "ignoreMissingFiles": .bool(ignoreMissingFiles),
        ]
        if let instanceName {
            values["instanceName"] = .string(instanceName)
        }
        if let colorHex {
            values["colorHex"] = .string(colorHex)
        }
        return .object(values)
    }
}

private struct JSONRPCEnvelope<Result: Decodable>: Decodable {
    let result: Result?
    let error: JSONRPCError?
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
    let data: SidecarErrorDetails?
}

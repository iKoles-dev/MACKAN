import Foundation

public struct SidecarHealth: Codable, Equatable, Sendable {
    public let status: String
    public let protocolVersion: String
    public let ckanVersion: String
}

public struct SidecarVersion: Codable, Equatable, Sendable {
    public let appName: String
    public let serviceVersion: String
    public let ckanVersion: String
    public let protocolVersion: String
    public let dotnetVersion: String
    public let operatingSystem: String
    public let processArchitecture: String
}

public struct UpdateCheckResult: Codable, Equatable, Sendable {
    public let status: String
    public let currentVersion: String
    public let latestVersion: String?
    public let latestDisplayVersion: String?
    public let releaseNotes: String?
    public let source: String
    public let useDevBuilds: Bool
    public let canAutoInstall: Bool
    public let installMessage: String
    public let downloadUrls: [String]
    public let error: String?

    public init(
        status: String,
        currentVersion: String,
        latestVersion: String?,
        latestDisplayVersion: String?,
        releaseNotes: String?,
        source: String,
        useDevBuilds: Bool,
        canAutoInstall: Bool,
        installMessage: String,
        downloadUrls: [String],
        error: String?
    ) {
        self.status = status
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.latestDisplayVersion = latestDisplayVersion
        self.releaseNotes = releaseNotes
        self.source = source
        self.useDevBuilds = useDevBuilds
        self.canAutoInstall = canAutoInstall
        self.installMessage = installMessage
        self.downloadUrls = downloadUrls
        self.error = error
    }
}

public struct SidecarInstancesResult: Codable, Equatable, Sendable {
    public let defaultInstanceId: String?
    public let instances: [GameInstanceSummary]

    public init(defaultInstanceId: String?, instances: [GameInstanceSummary]) {
        self.defaultInstanceId = defaultInstanceId
        self.instances = instances
    }
}

public struct CloneOptionsResult: Codable, Equatable, Sendable {
    public let sourceInstanceId: String
    public let leaveEmptyPaths: [String]

    public init(sourceInstanceId: String, leaveEmptyPaths: [String]) {
        self.sourceInstanceId = sourceInstanceId
        self.leaveEmptyPaths = leaveEmptyPaths
    }
}

public struct SidecarModulesResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let modules: [ModuleSummary]

    public init(instanceId: String?, modules: [ModuleSummary]) {
        self.instanceId = instanceId
        self.modules = modules
    }
}

public struct SidecarLabelsResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let labels: [ModuleLabelSummary]
    public let manageableLabels: [ModuleLabelSummary]

    public init(
        instanceId: String?,
        labels: [ModuleLabelSummary],
        manageableLabels: [ModuleLabelSummary]? = nil
    ) {
        self.instanceId = instanceId
        self.labels = labels
        self.manageableLabels = manageableLabels ?? labels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceId = try container.decodeIfPresent(String.self, forKey: .instanceId)
        labels = try container.decodeIfPresent([ModuleLabelSummary].self, forKey: .labels) ?? []
        manageableLabels = try container.decodeIfPresent([ModuleLabelSummary].self, forKey: .manageableLabels) ?? labels
    }
}

public struct ModuleLabelSummary: Identifiable, Codable, Equatable, Sendable {
    public let name: String
    public let instanceName: String?
    public let colorHex: String?
    public let hide: Bool
    public let notifyOnChange: Bool
    public let removeOnChange: Bool
    public let alertOnInstall: Bool
    public let removeOnInstall: Bool
    public let holdVersion: Bool
    public let ignoreMissingFiles: Bool
    public let identifiers: [String]

    public var id: String {
        "\(instanceName ?? "global"):\(name)"
    }

    public init(
        name: String,
        instanceName: String?,
        colorHex: String?,
        hide: Bool,
        notifyOnChange: Bool = false,
        removeOnChange: Bool = false,
        alertOnInstall: Bool = false,
        removeOnInstall: Bool = false,
        holdVersion: Bool,
        ignoreMissingFiles: Bool,
        identifiers: [String]
    ) {
        self.name = name
        self.instanceName = instanceName
        self.colorHex = colorHex
        self.hide = hide
        self.notifyOnChange = notifyOnChange
        self.removeOnChange = removeOnChange
        self.alertOnInstall = alertOnInstall
        self.removeOnInstall = removeOnInstall
        self.holdVersion = holdVersion
        self.ignoreMissingFiles = ignoreMissingFiles
        self.identifiers = identifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        instanceName = try container.decodeIfPresent(String.self, forKey: .instanceName)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        hide = try container.decodeIfPresent(Bool.self, forKey: .hide) ?? false
        notifyOnChange = try container.decodeIfPresent(Bool.self, forKey: .notifyOnChange) ?? false
        removeOnChange = try container.decodeIfPresent(Bool.self, forKey: .removeOnChange) ?? false
        alertOnInstall = try container.decodeIfPresent(Bool.self, forKey: .alertOnInstall) ?? false
        removeOnInstall = try container.decodeIfPresent(Bool.self, forKey: .removeOnInstall) ?? false
        holdVersion = try container.decodeIfPresent(Bool.self, forKey: .holdVersion) ?? false
        ignoreMissingFiles = try container.decodeIfPresent(Bool.self, forKey: .ignoreMissingFiles) ?? false
        identifiers = try container.decodeIfPresent([String].self, forKey: .identifiers) ?? []
    }

    public func contains(identifier: String) -> Bool {
        identifiers.contains { $0.localizedCaseInsensitiveCompare(identifier) == .orderedSame }
    }
}

public struct ModuleLabelEdit: Codable, Equatable, Sendable {
    public var name: String
    public var instanceName: String?
    public var colorHex: String?
    public var hide: Bool
    public var notifyOnChange: Bool
    public var removeOnChange: Bool
    public var alertOnInstall: Bool
    public var removeOnInstall: Bool
    public var holdVersion: Bool
    public var ignoreMissingFiles: Bool

    public init(
        name: String,
        instanceName: String?,
        colorHex: String?,
        hide: Bool,
        notifyOnChange: Bool,
        removeOnChange: Bool,
        alertOnInstall: Bool,
        removeOnInstall: Bool,
        holdVersion: Bool,
        ignoreMissingFiles: Bool
    ) {
        self.name = name
        self.instanceName = instanceName
        self.colorHex = colorHex
        self.hide = hide
        self.notifyOnChange = notifyOnChange
        self.removeOnChange = removeOnChange
        self.alertOnInstall = alertOnInstall
        self.removeOnInstall = removeOnInstall
        self.holdVersion = holdVersion
        self.ignoreMissingFiles = ignoreMissingFiles
    }

    public init(summary: ModuleLabelSummary) {
        self.init(
            name: summary.name,
            instanceName: summary.instanceName,
            colorHex: summary.colorHex,
            hide: summary.hide,
            notifyOnChange: summary.notifyOnChange,
            removeOnChange: summary.removeOnChange,
            alertOnInstall: summary.alertOnInstall,
            removeOnInstall: summary.removeOnInstall,
            holdVersion: summary.holdVersion,
            ignoreMissingFiles: summary.ignoreMissingFiles)
    }
}

public struct LaunchOptionsResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let commandLines: [String]
    public let defaultCommandLines: [String]
    public let incompatibleModules: [LaunchWarningModule]

    public init(
        instanceId: String?,
        commandLines: [String],
        defaultCommandLines: [String],
        incompatibleModules: [LaunchWarningModule] = []
    ) {
        self.instanceId = instanceId
        self.commandLines = commandLines
        self.defaultCommandLines = defaultCommandLines
        self.incompatibleModules = incompatibleModules
    }

    enum CodingKeys: String, CodingKey {
        case instanceId
        case commandLines
        case defaultCommandLines
        case incompatibleModules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceId = try container.decodeIfPresent(String.self, forKey: .instanceId)
        commandLines = try container.decode([String].self, forKey: .commandLines)
        defaultCommandLines = try container.decode([String].self, forKey: .defaultCommandLines)
        incompatibleModules = try container.decodeIfPresent([LaunchWarningModule].self, forKey: .incompatibleModules) ?? []
    }
}

public struct LaunchWarningModule: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let compatibleGameVersions: String

    public var id: String { identifier }

    public init(identifier: String, name: String, version: String, compatibleGameVersions: String) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.compatibleGameVersions = compatibleGameVersions
    }
}

public struct LaunchGameResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let commandLine: String
    public let status: String
    public let processId: Int64?

    public init(instanceId: String?, commandLine: String, status: String, processId: Int64? = nil) {
        self.instanceId = instanceId
        self.commandLine = commandLine
        self.status = status
        self.processId = processId
    }
}

public struct SidecarRepositoriesResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let repositories: [RepositorySummary]

    public init(instanceId: String?, repositories: [RepositorySummary]) {
        self.instanceId = instanceId
        self.repositories = repositories
    }
}

public struct RepositoryRefreshResult: Codable, Equatable, Sendable {
    public let operationId: String?
    public let operationStatus: String
    public let instanceId: String?
    public let status: String
    public let compatibleModuleCount: Int
    public let repositories: [RepositorySummary]
    public let events: [OperationEvent]
    public let error: String?
    public let errorDetails: SidecarErrorDetails?

    public init(
        instanceId: String?,
        status: String,
        compatibleModuleCount: Int,
        repositories: [RepositorySummary],
        events: [OperationEvent] = [],
        operationId: String? = nil,
        operationStatus: String = "completed",
        error: String? = nil,
        errorDetails: SidecarErrorDetails? = nil
    ) {
        self.operationId = operationId
        self.operationStatus = operationStatus
        self.instanceId = instanceId
        self.status = status
        self.compatibleModuleCount = compatibleModuleCount
        self.repositories = repositories
        self.events = events
        self.error = error
        self.errorDetails = errorDetails
    }

    private enum CodingKeys: String, CodingKey {
        case operationId
        case operationStatus
        case instanceId
        case status
        case compatibleModuleCount
        case repositories
        case events
        case error
        case errorDetails
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operationId = try container.decodeIfPresent(String.self, forKey: .operationId)
        operationStatus = try container.decodeIfPresent(String.self, forKey: .operationStatus) ?? "completed"
        instanceId = try container.decodeIfPresent(String.self, forKey: .instanceId)
        status = try container.decode(String.self, forKey: .status)
        compatibleModuleCount = try container.decode(Int.self, forKey: .compatibleModuleCount)
        repositories = try container.decode([RepositorySummary].self, forKey: .repositories)
        events = try container.decodeIfPresent([OperationEvent].self, forKey: .events) ?? []
        error = try container.decodeIfPresent(String.self, forKey: .error)
        errorDetails = try container.decodeIfPresent(SidecarErrorDetails.self, forKey: .errorDetails)
    }
}

public struct ModuleListOperationResult: Codable, Equatable, Sendable {
    public let operationId: String
    public let instanceId: String?
    public let status: String
    public let modules: [ModuleSummary]
    public let events: [OperationEvent]
    public let error: String?

    public init(
        operationId: String,
        instanceId: String?,
        status: String,
        modules: [ModuleSummary],
        events: [OperationEvent] = [],
        error: String? = nil
    ) {
        self.operationId = operationId
        self.instanceId = instanceId
        self.status = status
        self.modules = modules
        self.events = events
        self.error = error
    }
}

public struct MaintenanceScanResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let changed: Bool
    public let detectedDllCount: Int
    public let detectedDlcCount: Int

    public init(
        instanceId: String?,
        changed: Bool,
        detectedDllCount: Int,
        detectedDlcCount: Int
    ) {
        self.instanceId = instanceId
        self.changed = changed
        self.detectedDllCount = detectedDllCount
        self.detectedDlcCount = detectedDlcCount
    }
}

public struct UnmanagedFileSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let kind: String
    public let version: String?
    public let path: String?

    public var id: String {
        "\(kind):\(identifier):\(path ?? "-")"
    }

    public init(
        identifier: String,
        kind: String,
        version: String?,
        path: String?
    ) {
        self.identifier = identifier
        self.kind = kind
        self.version = version
        self.path = path
    }
}

public struct UnmanagedFilesResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let changed: Bool
    public let files: [UnmanagedFileSummary]

    public init(
        instanceId: String?,
        changed: Bool,
        files: [UnmanagedFileSummary]
    ) {
        self.instanceId = instanceId
        self.changed = changed
        self.files = files
    }
}

public struct InstallationHistoryModule: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String?
    public let author: String?
    public let abstract: String?
    public let isInstalled: Bool
    public let isAvailable: Bool

    public var id: String {
        "\(identifier):\(version ?? "-")"
    }

    public init(
        identifier: String,
        name: String,
        version: String?,
        author: String?,
        abstract: String?,
        isInstalled: Bool,
        isAvailable: Bool
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.author = author
        self.abstract = abstract
        self.isInstalled = isInstalled
        self.isAvailable = isAvailable
    }
}

public struct InstallationHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public let fileName: String
    public let savedAt: String
    public let modules: [InstallationHistoryModule]

    public var id: String {
        fileName
    }

    public init(
        fileName: String,
        savedAt: String,
        modules: [InstallationHistoryModule]
    ) {
        self.fileName = fileName
        self.savedAt = savedAt
        self.modules = modules
    }
}

public struct InstallationHistoryResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let entries: [InstallationHistoryEntry]

    public init(
        instanceId: String?,
        entries: [InstallationHistoryEntry]
    ) {
        self.instanceId = instanceId
        self.entries = entries
    }
}

public struct PlayTimeEntry: Identifiable, Codable, Equatable, Sendable {
    public let instanceId: String
    public let name: String
    public let path: String
    public let hours: Double
    public let display: String

    public var id: String {
        instanceId
    }

    public init(
        instanceId: String,
        name: String,
        path: String,
        hours: Double,
        display: String
    ) {
        self.instanceId = instanceId
        self.name = name
        self.path = path
        self.hours = hours
        self.display = display
    }
}

public struct PlayTimeResult: Codable, Equatable, Sendable {
    public let entries: [PlayTimeEntry]
    public let totalHours: Double
    public let totalDisplay: String

    public init(
        entries: [PlayTimeEntry],
        totalHours: Double,
        totalDisplay: String
    ) {
        self.entries = entries
        self.totalHours = totalHours
        self.totalDisplay = totalDisplay
    }
}

public struct DownloadStatisticsHost: Identifiable, Codable, Equatable, Sendable {
    public let host: String
    public let bytes: Int64
    public let display: String

    public var id: String {
        host
    }

    public var donationURL: URL? {
        switch host {
        case "spacedock.info":
            return URL(string: "https://www.patreon.com/spacedock")
        case "archive.org":
            return URL(string: "https://archive.org/donate")
        default:
            return nil
        }
    }

    public init(host: String, bytes: Int64, display: String) {
        self.host = host
        self.bytes = bytes
        self.display = display
    }
}

public struct DownloadStatisticsResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let hosts: [DownloadStatisticsHost]
    public let totalBytes: Int64
    public let totalDisplay: String

    public init(
        instanceId: String?,
        hosts: [DownloadStatisticsHost],
        totalBytes: Int64,
        totalDisplay: String
    ) {
        self.instanceId = instanceId
        self.hosts = hosts
        self.totalBytes = totalBytes
        self.totalDisplay = totalDisplay
    }
}

public struct CacheInfoResult: Codable, Equatable, Sendable {
    public let path: String
    public let fileCount: Int
    public let bytes: Int64
    public let display: String
    public let freeBytes: Int64?
    public let freeDisplay: String?
    public let limitBytes: Int64?
    public let limitDisplay: String?
    public let isOverLimit: Bool

    public init(
        path: String,
        fileCount: Int,
        bytes: Int64,
        display: String,
        freeBytes: Int64?,
        freeDisplay: String?,
        limitBytes: Int64?,
        limitDisplay: String?,
        isOverLimit: Bool
    ) {
        self.path = path
        self.fileCount = fileCount
        self.bytes = bytes
        self.display = display
        self.freeBytes = freeBytes
        self.freeDisplay = freeDisplay
        self.limitBytes = limitBytes
        self.limitDisplay = limitDisplay
        self.isOverLimit = isOverLimit
    }
}

public struct CachePurgeResult: Codable, Equatable, Sendable {
    public let mode: String
    public let purgedFileCount: Int
    public let purgedBytes: Int64
    public let purgedDisplay: String
    public let cache: CacheInfoResult

    public init(
        mode: String,
        purgedFileCount: Int,
        purgedBytes: Int64,
        purgedDisplay: String,
        cache: CacheInfoResult
    ) {
        self.mode = mode
        self.purgedFileCount = purgedFileCount
        self.purgedBytes = purgedBytes
        self.purgedDisplay = purgedDisplay
        self.cache = cache
    }
}

public struct SettingsResult: Codable, Equatable, Sendable {
    public let downloadCacheDir: String
    public let defaultDownloadCacheDir: String
    public let isDefaultDownloadCacheDir: Bool
    public let cacheSizeLimitBytes: Int64?
    public let cacheSizeLimitDisplay: String

    public init(
        downloadCacheDir: String,
        defaultDownloadCacheDir: String,
        isDefaultDownloadCacheDir: Bool,
        cacheSizeLimitBytes: Int64?,
        cacheSizeLimitDisplay: String
    ) {
        self.downloadCacheDir = downloadCacheDir
        self.defaultDownloadCacheDir = defaultDownloadCacheDir
        self.isDefaultDownloadCacheDir = isDefaultDownloadCacheDir
        self.cacheSizeLimitBytes = cacheSizeLimitBytes
        self.cacheSizeLimitDisplay = cacheSizeLimitDisplay
    }
}

public enum CacheMigrationChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case move
    case delete
    case open
    case keep
    case revert

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .move:
            return "Move files"
        case .delete:
            return "Delete old files"
        case .open:
            return "Reveal both folders"
        case .keep:
            return "Keep old files"
        case .revert:
            return "Cancel path change"
        }
    }
}

public struct GeneralSettingsResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let checkForUpdatesOnLaunch: Bool
    public let useDevBuilds: Bool
    public let refreshRepositoriesOnLaunch: Bool
    public let autoSortByUpdate: Bool

    public init(
        instanceId: String,
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) {
        self.instanceId = instanceId
        self.checkForUpdatesOnLaunch = checkForUpdatesOnLaunch
        self.useDevBuilds = useDevBuilds
        self.refreshRepositoriesOnLaunch = refreshRepositoriesOnLaunch
        self.autoSortByUpdate = autoSortByUpdate
    }
}

public struct RecommendationSettingsResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let suppressRecommendations: Bool

    public init(instanceId: String, suppressRecommendations: Bool) {
        self.instanceId = instanceId
        self.suppressRecommendations = suppressRecommendations
    }
}

public struct CompatibleGameVersionsResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let game: String
    public let actualGameVersion: String?
    public let gameVersionWhenWritten: String?
    public let compatibleVersionsAreFromDifferentGameVersion: Bool
    public let compatibleVersions: [String]
    public let knownVersions: [String]
    public let availableVersions: [String]

    public init(
        instanceId: String,
        game: String,
        actualGameVersion: String?,
        gameVersionWhenWritten: String?,
        compatibleVersionsAreFromDifferentGameVersion: Bool,
        compatibleVersions: [String],
        knownVersions: [String],
        availableVersions: [String]
    ) {
        self.instanceId = instanceId
        self.game = game
        self.actualGameVersion = actualGameVersion
        self.gameVersionWhenWritten = gameVersionWhenWritten
        self.compatibleVersionsAreFromDifferentGameVersion = compatibleVersionsAreFromDifferentGameVersion
        self.compatibleVersions = compatibleVersions
        self.knownVersions = knownVersions
        self.availableVersions = availableVersions
    }
}

public struct StabilityToleranceResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let game: String
    public let overallStabilityTolerance: String
    public let availableStabilityTolerances: [String]
    public let moduleStabilityTolerances: [ModuleStabilityTolerance]

    public init(
        instanceId: String,
        game: String,
        overallStabilityTolerance: String,
        availableStabilityTolerances: [String],
        moduleStabilityTolerances: [ModuleStabilityTolerance]
    ) {
        self.instanceId = instanceId
        self.game = game
        self.overallStabilityTolerance = overallStabilityTolerance
        self.availableStabilityTolerances = availableStabilityTolerances
        self.moduleStabilityTolerances = moduleStabilityTolerances
    }
}

public struct ModuleStabilityTolerance: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let stabilityTolerance: String

    public var id: String { identifier }

    public init(identifier: String, stabilityTolerance: String) {
        self.identifier = identifier
        self.stabilityTolerance = stabilityTolerance
    }
}

public struct PreferredHostsResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let availableHosts: [String]
    public let preferredHosts: [String?]
    public let placeholderLabel: String

    public init(
        instanceId: String,
        availableHosts: [String],
        preferredHosts: [String?],
        placeholderLabel: String
    ) {
        self.instanceId = instanceId
        self.availableHosts = availableHosts
        self.preferredHosts = preferredHosts
        self.placeholderLabel = placeholderLabel
    }
}

public struct InstallFiltersResult: Codable, Equatable, Sendable {
    public let instanceId: String
    public let game: String
    public let globalFilters: [String]
    public let instanceFilters: [String]
    public let presets: [InstallFilterPreset]

    public init(
        instanceId: String,
        game: String,
        globalFilters: [String],
        instanceFilters: [String],
        presets: [InstallFilterPreset]
    ) {
        self.instanceId = instanceId
        self.game = game
        self.globalFilters = globalFilters
        self.instanceFilters = instanceFilters
        self.presets = presets
    }
}

public struct InstallFilterPreset: Identifiable, Codable, Equatable, Sendable {
    public let name: String
    public let filters: [String]

    public var id: String { name }

    public init(name: String, filters: [String]) {
        self.name = name
        self.filters = filters
    }
}

public struct AuthTokensResult: Codable, Equatable, Sendable {
    public let authTokens: [AuthTokenSummary]

    public init(authTokens: [AuthTokenSummary]) {
        self.authTokens = authTokens
    }
}

public struct AuthTokenSummary: Identifiable, Codable, Equatable, Sendable {
    public let host: String
    public let tokenPreview: String

    public var id: String { host }

    public init(host: String, tokenPreview: String) {
        self.host = host
        self.tokenPreview = tokenPreview
    }
}

public struct DeduplicateResult: Codable, Equatable, Sendable {
    public let status: String
    public let events: [OperationEvent]
    public let error: String?

    public init(status: String, events: [OperationEvent], error: String?) {
        self.status = status
        self.events = events
        self.error = error
    }
}

public struct RepairRegistryResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let status: String
    public let events: [OperationEvent]
    public let error: String?

    public init(instanceId: String?, status: String, events: [OperationEvent], error: String?) {
        self.instanceId = instanceId
        self.status = status
        self.events = events
        self.error = error
    }
}

public struct RegistryLockRemovalResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let lockfilePath: String
    public let status: String
    public let removed: Bool

    public init(instanceId: String?, lockfilePath: String, status: String, removed: Bool) {
        self.instanceId = instanceId
        self.lockfilePath = lockfilePath
        self.status = status
        self.removed = removed
    }
}

public struct ChangeSetResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let changes: [ChangeSummary]
    public let conflicts: [ConflictSummary]
    public let conflictDescriptions: [String]
    public let providerChoices: [ProviderChoice]
    public let recommendationChoices: [RecommendationChoice]
    public let suppressRecommendations: Bool

    public init(
        instanceId: String?,
        changes: [ChangeSummary],
        conflicts: [ConflictSummary],
        conflictDescriptions: [String],
        providerChoices: [ProviderChoice] = [],
        recommendationChoices: [RecommendationChoice] = [],
        suppressRecommendations: Bool = false
    ) {
        self.instanceId = instanceId
        self.changes = changes
        self.conflicts = conflicts
        self.conflictDescriptions = conflictDescriptions
        self.providerChoices = providerChoices
        self.recommendationChoices = recommendationChoices
        self.suppressRecommendations = suppressRecommendations
    }

    private enum CodingKeys: String, CodingKey {
        case instanceId
        case changes
        case conflicts
        case conflictDescriptions
        case providerChoices
        case recommendationChoices
        case suppressRecommendations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceId = try container.decodeIfPresent(String.self, forKey: .instanceId)
        changes = try container.decode([ChangeSummary].self, forKey: .changes)
        conflicts = try container.decode([ConflictSummary].self, forKey: .conflicts)
        conflictDescriptions = try container.decode([String].self, forKey: .conflictDescriptions)
        providerChoices = try container.decodeIfPresent([ProviderChoice].self, forKey: .providerChoices) ?? []
        recommendationChoices = try container.decodeIfPresent([RecommendationChoice].self, forKey: .recommendationChoices) ?? []
        suppressRecommendations = try container.decodeIfPresent(Bool.self, forKey: .suppressRecommendations) ?? false
    }
}

public struct ProviderChoice: Identifiable, Codable, Equatable, Sendable {
    public let requested: String
    public let message: String
    public let requesterIdentifier: String
    public let requesterName: String
    public let options: [ProviderOption]

    public var id: String { "\(requesterIdentifier):\(requested)" }

    public init(
        requested: String,
        message: String,
        requesterIdentifier: String,
        requesterName: String,
        options: [ProviderOption]
    ) {
        self.requested = requested
        self.message = message
        self.requesterIdentifier = requesterIdentifier
        self.requesterName = requesterName
        self.options = options
    }
}

public struct ProviderSelection: Identifiable, Codable, Equatable, Sendable {
    public let requested: String
    public let requesterIdentifier: String
    public let selectedIdentifier: String

    public var id: String { "\(requesterIdentifier):\(requested)" }

    public init(
        requested: String,
        requesterIdentifier: String,
        selectedIdentifier: String
    ) {
        self.requested = requested
        self.requesterIdentifier = requesterIdentifier
        self.selectedIdentifier = selectedIdentifier
    }
}

public struct VersionedModuleSelection: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let version: String

    public var id: String { "\(identifier):\(version)" }

    public init(identifier: String, version: String) {
        self.identifier = identifier
        self.version = version
    }
}

public struct ProviderOption: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let abstract: String

    public var id: String { identifier }

    public init(identifier: String, name: String, version: String, abstract: String) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.abstract = abstract
    }
}

public struct RecommendationChoice: Identifiable, Codable, Equatable, Sendable {
    public let kind: String
    public let identifier: String
    public let name: String
    public let version: String
    public let abstract: String
    public let dependents: [String]
    public let isRecommendedDefault: Bool

    public var id: String { "\(kind):\(identifier)" }

    public init(
        kind: String,
        identifier: String,
        name: String,
        version: String,
        abstract: String,
        dependents: [String],
        isRecommendedDefault: Bool
    ) {
        self.kind = kind
        self.identifier = identifier
        self.name = name
        self.version = version
        self.abstract = abstract
        self.dependents = dependents
        self.isRecommendedDefault = isRecommendedDefault
    }
}

public struct ChangeSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let action: String
    public let fromVersion: String?
    public let toVersion: String?
    public let reasons: [String]
    public let isUserRequested: Bool
    public let isAuto: Bool

    public var id: String { "\(action):\(identifier)" }

    public init(
        identifier: String,
        name: String,
        action: String,
        fromVersion: String?,
        toVersion: String?,
        reasons: [String],
        isUserRequested: Bool,
        isAuto: Bool
    ) {
        self.identifier = identifier
        self.name = name
        self.action = action
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.reasons = reasons
        self.isUserRequested = isUserRequested
        self.isAuto = isAuto
    }
}

public struct ConflictSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let description: String

    public var id: String { identifier }

    public init(identifier: String, name: String, description: String) {
        self.identifier = identifier
        self.name = name
        self.description = description
    }
}

public struct OperationResult: Codable, Equatable, Sendable {
    public let operationId: String
    public let instanceId: String?
    public let status: String
    public let changes: [ChangeSummary]
    public let events: [OperationEvent]
    public let error: String?
    public let errorDetails: SidecarErrorDetails?

    public init(
        operationId: String,
        instanceId: String?,
        status: String,
        changes: [ChangeSummary],
        events: [OperationEvent],
        error: String?,
        errorDetails: SidecarErrorDetails? = nil
    ) {
        self.operationId = operationId
        self.instanceId = instanceId
        self.status = status
        self.changes = changes
        self.events = events
        self.error = error
        self.errorDetails = errorDetails
    }
}

public struct SidecarErrorDetails: Codable, Equatable, Sendable {
    public let kind: String
    public let lockfilePath: String?
    public let suggestedAction: String?
    public let command: String?
    public let downloadFailures: [DownloadFailureSummary]?
    public let providerChoices: [ProviderChoice]?
    public let recommendationChoices: [RecommendationChoice]?
    public let incompatibleCkanFiles: [IncompatibleCkanFileSummary]?

    public init(
        kind: String,
        lockfilePath: String?,
        suggestedAction: String?,
        command: String? = nil,
        downloadFailures: [DownloadFailureSummary]? = nil,
        providerChoices: [ProviderChoice]? = nil,
        recommendationChoices: [RecommendationChoice]? = nil,
        incompatibleCkanFiles: [IncompatibleCkanFileSummary]? = nil
    ) {
        self.kind = kind
        self.lockfilePath = lockfilePath
        self.suggestedAction = suggestedAction
        self.command = command
        self.downloadFailures = downloadFailures
        self.providerChoices = providerChoices
        self.recommendationChoices = recommendationChoices
        self.incompatibleCkanFiles = incompatibleCkanFiles
    }

    public static func registryLock(_ lockfilePath: String?) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "registryLock",
            lockfilePath: lockfilePath,
            suggestedAction: "waitRetry")
    }

    public static func launchFailure(
        command: String?,
        suggestedAction: String? = "retryOrCheckCommand"
    ) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "launchFailure",
            lockfilePath: nil,
            suggestedAction: suggestedAction,
            command: command)
    }

    public static func downloadFailures(_ failures: [DownloadFailureSummary]) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "downloadFailures",
            lockfilePath: nil,
            suggestedAction: "skipOrAbort",
            downloadFailures: failures)
    }

    public static func providerChoices(_ choices: [ProviderChoice]) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "providerChoices",
            lockfilePath: nil,
            suggestedAction: "chooseProvider",
            providerChoices: choices)
    }

    public static func recommendationChoices(_ choices: [RecommendationChoice]) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "recommendationChoices",
            lockfilePath: nil,
            suggestedAction: "chooseRecommendations",
            recommendationChoices: choices)
    }

    public static func incompatibleCkanFiles(_ files: [IncompatibleCkanFileSummary]) -> SidecarErrorDetails {
        SidecarErrorDetails(
            kind: "incompatibleCkanFiles",
            lockfilePath: nil,
            suggestedAction: "confirmIncompatible",
            incompatibleCkanFiles: files)
    }
}

public struct IncompatibleCkanFileSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let compatibleGameVersions: String

    public var id: String { identifier }

    public init(
        identifier: String,
        name: String,
        version: String,
        compatibleGameVersions: String
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.compatibleGameVersions = compatibleGameVersions
    }
}

public struct DownloadFailureSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let message: String
    public let urls: [String]

    public var id: String { identifier }

    public init(
        identifier: String,
        name: String,
        version: String,
        message: String,
        urls: [String]
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.message = message
        self.urls = urls
    }
}

public struct OperationEvent: Identifiable, Codable, Equatable, Sendable {
    public let kind: String
    public let message: String
    public let percent: Int?
    public let identifier: String?
    public let remainingBytes: Int64?
    public let totalBytes: Int64?
    public let completedCount: Int?
    public let totalCount: Int?

    public var id: String {
        "\(kind):\(identifier ?? "-"):\(message):\(percent?.formatted() ?? "-")"
    }

    public var progressFraction: Double? {
        guard let percent else {
            return nil
        }
        return min(1, max(0, Double(percent) / 100))
    }

    public var byteProgressDisplay: String? {
        guard let remainingBytes, let totalBytes, totalBytes > 0 else {
            return nil
        }
        let completedBytes = max(0, totalBytes - max(0, remainingBytes))
        return "\(Self.byteDisplay(completedBytes)) of \(Self.byteDisplay(totalBytes))"
    }

    public init(
        kind: String,
        message: String,
        percent: Int?,
        identifier: String?,
        remainingBytes: Int64?,
        totalBytes: Int64?,
        completedCount: Int? = nil,
        totalCount: Int? = nil
    ) {
        self.kind = kind
        self.message = message
        self.percent = percent
        self.identifier = identifier
        self.remainingBytes = remainingBytes
        self.totalBytes = totalBytes
        self.completedCount = completedCount
        self.totalCount = totalCount
    }

    private static func byteDisplay(_ bytes: Int64) -> String {
        if bytes < 1_000 {
            return "\(bytes) bytes"
        }

        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1_000
        var unitIndex = 0
        while value >= 1_000, unitIndex < units.count - 1 {
            value /= 1_000
            unitIndex += 1
        }
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return "\(Int(rounded)) \(units[unitIndex])"
        }
        return "\(rounded.formatted(.number.precision(.fractionLength(1)))) \(units[unitIndex])"
    }
}

public enum ModListExportFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case plainText
    case markdown
    case bbcode
    case csv
    case tsv

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .markdown:
            return "Markdown"
        case .bbcode:
            return "BBCode"
        case .csv:
            return "CSV"
        case .tsv:
            return "TSV"
        }
    }

    public var fileExtension: String {
        switch self {
        case .plainText, .bbcode:
            return "txt"
        case .markdown:
            return "md"
        case .csv:
            return "csv"
        case .tsv:
            return "tsv"
        }
    }
}

public struct ModListExportResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let format: ModListExportFormat
    public let suggestedFileName: String
    public let contentType: String
    public let contents: String

    public init(
        instanceId: String?,
        format: ModListExportFormat,
        suggestedFileName: String,
        contentType: String,
        contents: String
    ) {
        self.instanceId = instanceId
        self.format = format
        self.suggestedFileName = suggestedFileName
        self.contentType = contentType
        self.contents = contents
    }
}

public struct ModpackRelationshipAssignment: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let kind: String

    public var id: String { identifier }

    public init(identifier: String, kind: String) {
        self.identifier = identifier
        self.kind = kind
    }
}

public struct ModpackExportDraft: Equatable, Sendable {
    public var identifier: String
    public var name: String
    public var abstract: String
    public var author: String
    public var version: String
    public var license: String
    public var gameVersionMin: String?
    public var gameVersionMax: String?
    public var includeVersions: Bool
    public var includeOptionalRelationships: Bool
    public var relationshipAssignments: [ModpackRelationshipAssignment]

    public init(
        identifier: String,
        name: String,
        abstract: String,
        author: String,
        version: String,
        license: String,
        gameVersionMin: String?,
        gameVersionMax: String?,
        includeVersions: Bool,
        includeOptionalRelationships: Bool,
        relationshipAssignments: [ModpackRelationshipAssignment] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.abstract = abstract
        self.author = author
        self.version = version
        self.license = license
        self.gameVersionMin = gameVersionMin
        self.gameVersionMax = gameVersionMax
        self.includeVersions = includeVersions
        self.includeOptionalRelationships = includeOptionalRelationships
        self.relationshipAssignments = relationshipAssignments
    }
}

public struct ModpackExportResult: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let identifier: String
    public let suggestedFileName: String
    public let contentType: String
    public let contents: String

    public init(
        instanceId: String?,
        identifier: String,
        suggestedFileName: String,
        contentType: String,
        contents: String
    ) {
        self.instanceId = instanceId
        self.identifier = identifier
        self.suggestedFileName = suggestedFileName
        self.contentType = contentType
        self.contents = contents
    }
}

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

    public func health() async throws -> SidecarHealth {
        try await request(method: "app.health")
    }

    public func version() async throws -> SidecarVersion {
        try await request(method: "app.version")
    }

    public func checkForUpdates(useDevBuilds: Bool? = nil) async throws -> UpdateCheckResult {
        var params: [String: JSONRPCParameterValue] = [:]
        if let useDevBuilds {
            params["useDevBuilds"] = .bool(useDevBuilds)
        }
        return try await request(
            method: "app.checkForUpdates",
            params: params.isEmpty ? nil : params)
    }

    public func listInstances() async throws -> SidecarInstancesResult {
        try await request(method: "instances.list")
    }

    public func addInstance(path: String, name: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.add",
            params: stringParams([
                "path": path,
                "name": name,
            ]))
    }

    public func cloneOptions(sourceInstanceId: String) async throws -> CloneOptionsResult {
        try await request(
            method: "instances.cloneOptions",
            params: stringParams(["sourceInstanceId": sourceInstanceId]))
    }

    public func cloneInstance(
        sourceInstanceId: String,
        newName: String,
        newPath: String,
        shareStock: Bool,
        leaveEmptyPaths: [String]? = nil
    ) async throws -> SidecarInstancesResult {
        var params = stringParams([
            "sourceInstanceId": sourceInstanceId,
            "newName": newName,
            "newPath": newPath,
        ]) ?? [:]
        params["shareStock"] = .bool(shareStock)
        if let leaveEmptyPaths {
            params["leaveEmptyPaths"] = .strings(leaveEmptyPaths)
        }
        return try await request(method: "instances.clone", params: params)
    }

    public func fakeInstance(
        name: String,
        path: String,
        version: String,
        gameId: String,
        makingHistoryVersion: String?,
        breakingGroundVersion: String?,
        setDefault: Bool
    ) async throws -> SidecarInstancesResult {
        var params = stringParams([
            "name": name,
            "path": path,
            "version": version,
            "gameId": gameId,
            "makingHistoryVersion": makingHistoryVersion,
            "breakingGroundVersion": breakingGroundVersion,
        ]) ?? [:]
        params["setDefault"] = .bool(setDefault)
        return try await request(method: "instances.fake", params: params)
    }

    public func setDefaultInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.setDefault",
            params: stringParams(["instanceId": instanceId]))
    }

    public func removeInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.remove",
            params: stringParams(["instanceId": instanceId]))
    }

    public func renameInstance(_ instanceId: String, to newName: String) async throws -> SidecarInstancesResult {
        try await request(
            method: "instances.rename",
            params: stringParams([
                "instanceId": instanceId,
                "newName": newName,
            ]))
    }

    public func launchOptions(instanceId: String?) async throws -> LaunchOptionsResult {
        try await request(
            method: "instances.launchOptions",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateLaunchOptions(instanceId: String?, commandLines: [String]) async throws -> LaunchOptionsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["commandLines"] = .strings(commandLines)
        return try await request(method: "instances.updateLaunchOptions", params: params)
    }

    public func launchGame(
        instanceId: String?,
        commandLine: String?,
        suppressIncompatibleWarnings: Bool = false
    ) async throws -> LaunchGameResult {
        var params = stringParams([
            "instanceId": instanceId,
            "commandLine": commandLine,
        ]) ?? [:]
        params["suppressIncompatibleWarnings"] = .bool(suppressIncompatibleWarnings)
        return try await request(
            method: "instances.launch",
            params: params)
    }

    public func listModules(instanceId: String?) async throws -> SidecarModulesResult {
        try await request(
            method: "mods.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func startListModules(instanceId: String?) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.startList",
            params: stringParams(["instanceId": instanceId]))
    }

    public func moduleListStatus(operationId: String) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.listStatus",
            params: ["operationId": .string(operationId)])
    }

    public func cancelModuleList(operationId: String) async throws -> ModuleListOperationResult {
        try await request(
            method: "mods.cancelList",
            params: ["operationId": .string(operationId)])
    }

    public func listLabels(instanceId: String?) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func toggleModuleLabel(
        instanceId: String?,
        labelName: String,
        identifier: String
    ) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.toggleModule",
            params: stringParams([
                "instanceId": instanceId,
                "labelName": labelName,
                "identifier": identifier,
            ]))
    }

    public func upsertModuleLabel(
        instanceId: String?,
        originalName: String?,
        originalInstanceName: String?,
        label: ModuleLabelEdit
    ) async throws -> SidecarLabelsResult {
        var params = stringParams([
            "instanceId": instanceId,
            "originalName": originalName,
            "originalInstanceName": originalInstanceName,
        ]) ?? [:]
        params["label"] = label.parameterValue
        return try await request(method: "labels.upsert", params: params)
    }

    public func deleteModuleLabel(
        instanceId: String?,
        name: String,
        instanceName: String?
    ) async throws -> SidecarLabelsResult {
        try await request(
            method: "labels.delete",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
                "instanceName": instanceName,
            ]))
    }

    public func setAutoInstalled(
        instanceId: String?,
        identifier: String,
        isAutoInstalled: Bool
    ) async throws -> SidecarModulesResult {
        var params = stringParams([
            "instanceId": instanceId,
            "identifier": identifier,
        ]) ?? [:]
        params["isAutoInstalled"] = .bool(isAutoInstalled)
        return try await request(method: "mods.setAutoInstalled", params: params)
    }

    public func moduleDetails(instanceId: String?, identifier: String) async throws -> ModuleDetails {
        let params = stringParams([
            "identifier": identifier,
            "instanceId": instanceId,
        ])
        return try await request(method: "mods.details", params: params)
    }

    public func listRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.list",
            params: stringParams(["instanceId": instanceId]))
    }

    public func listAvailableRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.available",
            params: stringParams(["instanceId": instanceId]))
    }

    public func addRepository(instanceId: String?, name: String, url: String) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.add",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
                "url": url,
            ]))
    }

    public func removeRepository(instanceId: String?, name: String) async throws -> SidecarRepositoriesResult {
        try await request(
            method: "repositories.remove",
            params: stringParams([
                "instanceId": instanceId,
                "name": name,
            ]))
    }

    public func setRepositoryPriority(instanceId: String?, name: String, priority: Int) async throws -> SidecarRepositoriesResult {
        var params = stringParams([
            "instanceId": instanceId,
            "name": name,
        ]) ?? [:]
        params["priority"] = .int(priority)
        return try await request(method: "repositories.setPriority", params: params)
    }

    public func refreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["force"] = .bool(force)
        return try await request(method: "repositories.refresh", params: params)
    }

    public func startRefreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["force"] = .bool(force)
        return try await request(method: "repositories.startRefresh", params: params)
    }

    public func repositoryRefreshStatus(operationId: String) async throws -> RepositoryRefreshResult {
        return try await request(
            method: "repositories.refreshStatus",
            params: ["operationId": .string(operationId)])
    }

    public func cancelRepositoryRefresh(operationId: String) async throws -> RepositoryRefreshResult {
        return try await request(
            method: "repositories.cancelRefresh",
            params: ["operationId": .string(operationId)])
    }

    public func resolveChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = []
    ) async throws -> ChangeSetResult {
        return try await request(
            method: "mods.resolveChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections))
    }

    public func applyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = [],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try await request(
            method: "operations.applyChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections,
                skipDownloadFailures: skipDownloadFailures))
    }

    public func startApplyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = [],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try await request(
            method: "operations.startApplyChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections,
                skipDownloadFailures: skipDownloadFailures))
    }

    public func installCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["filePaths"] = .strings(filePaths)
        if !providerSelections.isEmpty {
            params["providerSelections"] = .objects(providerSelections.map(\.parameterObject))
        }
        if !recommendationSelections.isEmpty {
            params["recommendationSelections"] = .strings(recommendationSelections)
        }
        if skipRecommendations {
            params["skipRecommendations"] = .bool(skipRecommendations)
        }
        if allowIncompatibleCkanFiles {
            params["allowIncompatibleCkanFiles"] = .bool(allowIncompatibleCkanFiles)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.installCkanFiles",
            params: params)
    }

    public func startInstallCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["filePaths"] = .strings(filePaths)
        if !providerSelections.isEmpty {
            params["providerSelections"] = .objects(providerSelections.map(\.parameterObject))
        }
        if !recommendationSelections.isEmpty {
            params["recommendationSelections"] = .strings(recommendationSelections)
        }
        if skipRecommendations {
            params["skipRecommendations"] = .bool(skipRecommendations)
        }
        if allowIncompatibleCkanFiles {
            params["allowIncompatibleCkanFiles"] = .bool(allowIncompatibleCkanFiles)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.startInstallCkanFiles",
            params: params)
    }

    public func importDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["paths"] = .strings(paths)
        params["installImportedModules"] = .bool(installImportedModules)
        params["deleteImportedFiles"] = .bool(deleteImportedFiles)
        if previewBeforeInstall {
            params["previewBeforeInstall"] = .bool(previewBeforeInstall)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.importDownloads",
            params: params)
    }

    public func startImportDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["paths"] = .strings(paths)
        params["installImportedModules"] = .bool(installImportedModules)
        params["deleteImportedFiles"] = .bool(deleteImportedFiles)
        if previewBeforeInstall {
            params["previewBeforeInstall"] = .bool(previewBeforeInstall)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.startImportDownloads",
            params: params)
    }

    public func exportModList(instanceId: String?, format: ModListExportFormat) async throws -> ModListExportResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["format"] = .string(format.rawValue)
        return try await request(
            method: "exports.modList",
            params: params)
    }

    public func exportModpack(instanceId: String?, draft: ModpackExportDraft) async throws -> ModpackExportResult {
        var params = stringParams([
            "instanceId": instanceId,
            "identifier": draft.identifier,
            "name": draft.name,
            "abstract": draft.abstract,
            "author": draft.author,
            "version": draft.version,
            "license": draft.license,
            "gameVersionMin": draft.gameVersionMin,
            "gameVersionMax": draft.gameVersionMax,
        ]) ?? [:]
        params["includeVersions"] = .bool(draft.includeVersions)
        params["includeOptionalRelationships"] = .bool(draft.includeOptionalRelationships)
        if !draft.relationshipAssignments.isEmpty {
            params["relationshipAssignments"] = .objects(draft.relationshipAssignments.map(\.parameterObject))
        }
        return try await request(
            method: "exports.modpack",
            params: params)
    }

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

    public func getSettings() async throws -> SettingsResult {
        try await request(method: "settings.get")
    }

    public func updateSettings(
        downloadCacheDir: String,
        cacheSizeLimitBytes: Int64?,
        cacheMigrationChoice: CacheMigrationChoice
    ) async throws -> SettingsResult {
        try await request(
            method: "settings.update",
            params: [
                "downloadCacheDir": .string(downloadCacheDir),
                "cacheSizeLimitBytes": .int64(cacheSizeLimitBytes ?? -1),
                "cacheMigrationChoice": .string(cacheMigrationChoice.rawValue),
            ])
    }

    public func generalSettings(instanceId: String?) async throws -> GeneralSettingsResult {
        try await request(
            method: "settings.general",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateGeneralSettings(
        instanceId: String?,
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) async throws -> GeneralSettingsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["checkForUpdatesOnLaunch"] = .bool(checkForUpdatesOnLaunch)
        params["useDevBuilds"] = .bool(useDevBuilds)
        params["refreshRepositoriesOnLaunch"] = .bool(refreshRepositoriesOnLaunch)
        params["autoSortByUpdate"] = .bool(autoSortByUpdate)
        return try await request(method: "settings.updateGeneral", params: params)
    }

    public func compatibleGameVersions(instanceId: String?) async throws -> CompatibleGameVersionsResult {
        try await request(
            method: "settings.compatibleVersions",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateCompatibleGameVersions(
        instanceId: String?,
        versions: [String]
    ) async throws -> CompatibleGameVersionsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["versions"] = .strings(versions)
        return try await request(
            method: "settings.updateCompatibleVersions",
            params: params)
    }

    public func stabilityTolerance(instanceId: String?) async throws -> StabilityToleranceResult {
        try await request(
            method: "settings.stabilityTolerance",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateStabilityTolerance(
        instanceId: String?,
        stabilityTolerance: String
    ) async throws -> StabilityToleranceResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["stabilityTolerance"] = .string(stabilityTolerance)
        return try await request(
            method: "settings.updateStabilityTolerance",
            params: params)
    }

    public func updateModuleStabilityTolerance(
        instanceId: String?,
        identifier: String,
        stabilityTolerance: String?
    ) async throws -> StabilityToleranceResult {
        var params = stringParams(["instanceId": instanceId, "stabilityTolerance": stabilityTolerance]) ?? [:]
        params["identifier"] = .string(identifier)
        return try await request(
            method: "settings.updateModuleStabilityTolerance",
            params: params)
    }

    public func preferredHosts(instanceId: String?) async throws -> PreferredHostsResult {
        try await request(
            method: "settings.preferredHosts",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updatePreferredHosts(
        instanceId: String?,
        preferredHosts: [String?]
    ) async throws -> PreferredHostsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["preferredHosts"] = .optionalStrings(preferredHosts)
        return try await request(
            method: "settings.updatePreferredHosts",
            params: params)
    }

    public func installFilters(instanceId: String?) async throws -> InstallFiltersResult {
        try await request(
            method: "settings.installFilters",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateInstallFilters(
        instanceId: String?,
        globalFilters: [String],
        instanceFilters: [String]
    ) async throws -> InstallFiltersResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["globalFilters"] = .strings(globalFilters)
        params["instanceFilters"] = .strings(instanceFilters)
        return try await request(
            method: "settings.updateInstallFilters",
            params: params)
    }

    public func recommendationSettings(instanceId: String?) async throws -> RecommendationSettingsResult {
        try await request(
            method: "settings.recommendations",
            params: stringParams(["instanceId": instanceId]))
    }

    public func updateRecommendationSettings(
        instanceId: String?,
        suppressRecommendations: Bool
    ) async throws -> RecommendationSettingsResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["suppressRecommendations"] = .bool(suppressRecommendations)
        return try await request(
            method: "settings.updateRecommendations",
            params: params)
    }

    public func authTokens() async throws -> AuthTokensResult {
        try await request(method: "settings.authTokens")
    }

    public func addAuthToken(host: String, token: String) async throws -> AuthTokensResult {
        try await request(
            method: "settings.addAuthToken",
            params: stringParams(["host": host, "token": token]))
    }

    public func removeAuthToken(host: String) async throws -> AuthTokensResult {
        try await request(
            method: "settings.removeAuthToken",
            params: stringParams(["host": host]))
    }

    public func operationStatus(operationId: String) async throws -> OperationResult {
        try await request(
            method: "operations.status",
            params: stringParams(["operationId": operationId]))
    }

    public func cancelOperation(operationId: String) async throws -> OperationResult {
        try await request(
            method: "operations.cancel",
            params: stringParams(["operationId": operationId]))
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

    private func request<Result: Decodable>(
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

    private func stringParams(_ params: [String: String?]) -> [String: JSONRPCParameterValue]? {
        let encoded = params.compactMapValues { value -> JSONRPCParameterValue? in
            value.map(JSONRPCParameterValue.string)
        }
        return encoded.isEmpty ? nil : encoded
    }

    private func changeSetParams(
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
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                return lines.joined(separator: "\n")
            }
        }
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

private enum JSONRPCParameterValue: Encodable {
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

private extension ProviderSelection {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "requested": .string(requested),
            "requesterIdentifier": .string(requesterIdentifier),
            "selectedIdentifier": .string(selectedIdentifier),
        ]
    }
}

private extension VersionedModuleSelection {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "identifier": .string(identifier),
            "version": .string(version),
        ]
    }
}

private extension ModpackRelationshipAssignment {
    var parameterObject: [String: JSONRPCParameterValue] {
        [
            "identifier": .string(identifier),
            "kind": .string(kind),
        ]
    }
}

private extension ModuleLabelEdit {
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

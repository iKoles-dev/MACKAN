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

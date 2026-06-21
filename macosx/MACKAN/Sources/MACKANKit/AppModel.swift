import Foundation

enum PendingOperationCompletionAction {
    case reloadInstanceState
    case previewImportedDownloads
}

@MainActor
public final class AppModel: ObservableObject {
    public enum HealthState: Equatable {
        case idle
        case loading
        case ready(SidecarHealth)
        case failed(String)
    }

    public struct CatalogLoadProgress: Equatable, Sendable {
        public let detail: String
        public let loadedModuleCount: Int?
        public let totalModuleCount: Int?
        public let percent: Int?

        public init(
            detail: String,
            loadedModuleCount: Int? = nil,
            totalModuleCount: Int? = nil,
            percent: Int? = nil
        ) {
            self.detail = detail
            self.loadedModuleCount = loadedModuleCount
            self.totalModuleCount = totalModuleCount
            self.percent = percent
        }

        public var fractionCompleted: Double? {
            if let loadedModuleCount, let totalModuleCount, totalModuleCount > 0 {
                return min(max(Double(loadedModuleCount) / Double(totalModuleCount), 0), 1)
            }
            if let percent {
                return min(max(Double(percent) / 100, 0), 1)
            }
            return nil
        }

        public var moduleCountSummary: String? {
            guard let loadedModuleCount, let totalModuleCount else {
                return nil
            }
            return "Preparing \(loadedModuleCount) of \(totalModuleCount) mods"
        }

        public var accessibilitySummary: String {
            if let moduleCountSummary {
                return "Loading catalog. \(moduleCountSummary). \(detail)"
            }
            return "Loading catalog. \(detail)"
        }
    }

    @Published public var healthState: HealthState = .idle
    @Published public internal(set) var catalogLoadProgress: CatalogLoadProgress?
    @Published public internal(set) var sidecarVersion: SidecarVersion?
    @Published public internal(set) var updateCheckResult: UpdateCheckResult?
    @Published public internal(set) var updateCheckError: String?
    @Published public internal(set) var isCheckingForUpdates = false
    @Published public internal(set) var mainContentRoute: MainContentRoute = .catalog
    @Published public var activeSheet: AppSheet? = nil
    internal var sheetPresentationTask: Task<Void, Never>? = nil
    internal var lastDismissalTime: TimeInterval = 0
    @Published public var installFromCkanFileTrigger = false
    @Published public var importDownloadsTrigger = false
    @Published public var applyChangesTrigger = false
    @Published public var selectedInstanceID: GameInstanceSummary.ID?
    @Published public var selectedModuleID: ModuleSummary.ID?
    @Published public var searchText = "" {
        didSet {
            persistCatalogState()
            recomputeFilteredModules()
        }
    }
    @Published public var filter = ModuleFilter.available {
        didSet {
            let selectionNeedsSync = oldValue != filter
            persistCatalogState()
            recomputeFilteredModules()
            if selectionNeedsSync {
                selectFirstFilteredModuleIfCurrentSelectionIsHidden()
            }
        }
    }
    @Published public var tagFilter: String? {
        didSet {
            persistCatalogState()
            recomputeFilteredModules()
        }
    }
    @Published public var moduleSort = ModuleSort.name {
        didSet {
            secondaryModuleSortCriteria = normalizedSecondarySortCriteria(secondaryModuleSortCriteria)
            persistCatalogState()
            recomputeFilteredModules()
        }
    }
    @Published public var moduleSortAscending = true {
        didSet {
            persistCatalogState()
            recomputeFilteredModules()
        }
    }
    @Published public internal(set) var secondaryModuleSortCriteria: [ModuleSortCriterion] = [] {
        didSet {
            persistCatalogState()
            recomputeFilteredModules()
        }
    }

    @Published public internal(set) var instances: [GameInstanceSummary]
    @Published public internal(set) var modules: [ModuleSummary] {
        didSet { recomputeFilteredModules() }
    }
    @Published public internal(set) var filteredModules: [ModuleSummary] = []
    @Published public internal(set) var selectedModuleDetails: ModuleDetails?
    var moduleDetailsCache: [ModuleDetailsCacheKey: ModuleDetails] = [:]
    @Published public internal(set) var moduleLabels: [ModuleLabelSummary] = [] {
        didSet { recomputeFilteredModules() }
    }
    @Published public internal(set) var manageableModuleLabels: [ModuleLabelSummary] = []
    @Published public internal(set) var repositories: [RepositorySummary] = []
    @Published public internal(set) var availableRepositories: [RepositorySummary] = []
    @Published public internal(set) var launchCommands: [String] = []
    @Published public internal(set) var defaultLaunchCommands: [String] = []
    @Published public internal(set) var incompatibleLaunchModules: [LaunchWarningModule] = []
    @Published public internal(set) var pendingLaunchWarning: PendingLaunchWarning?
    @Published public internal(set) var repositoryRefreshSummary: RepositoryRefreshResult?
    @Published public internal(set) var stagedActions: [ModuleSummary.ID: StagedModAction] = [:]
    @Published public internal(set) var providerSelections: [ProviderSelection] = []
    @Published public internal(set) var versionedInstallSelections: [VersionedModuleSelection] = []
    @Published public internal(set) var pendingChangeSet: ChangeSetResult?
    @Published public internal(set) var changeSetError: String?
    @Published public internal(set) var changeSetErrorDetails: SidecarErrorDetails?
    @Published public internal(set) var lastOperationResult: OperationResult?
    @Published public internal(set) var operationError: String?
    @Published public internal(set) var operationErrorDetails: SidecarErrorDetails?
    @Published public internal(set) var lastOperationSupportsSkipDownloadFailures = false
    @Published public internal(set) var lastMaintenanceScanResult: MaintenanceScanResult?
    @Published public internal(set) var unmanagedFilesResult: UnmanagedFilesResult?
    @Published public internal(set) var installationHistoryResult: InstallationHistoryResult?
    @Published public internal(set) var selectedInstallationHistoryEntry: InstallationHistoryEntry?
    @Published public internal(set) var playTimeResult: PlayTimeResult?
    @Published public internal(set) var downloadStatisticsResult: DownloadStatisticsResult?
    @Published public internal(set) var cacheInfoResult: CacheInfoResult?
    @Published public internal(set) var lastCachePurgeResult: CachePurgeResult?
    @Published public internal(set) var lastDeduplicateResult: DeduplicateResult?
    @Published public internal(set) var lastRepairRegistryResult: RepairRegistryResult?
    @Published public internal(set) var lastRegistryLockRemovalResult: RegistryLockRemovalResult?
    @Published public internal(set) var maintenanceError: String?
    @Published public internal(set) var maintenanceErrorTitle = "Maintenance failed"
    @Published public internal(set) var settings: SettingsResult?
    @Published public internal(set) var generalSettings: GeneralSettingsResult?
    @Published public internal(set) var compatibleGameVersions: CompatibleGameVersionsResult?
    @Published public internal(set) var stabilityTolerance: StabilityToleranceResult?
    @Published public internal(set) var preferredHosts: PreferredHostsResult?
    @Published public internal(set) var installFilters: InstallFiltersResult?
    @Published public internal(set) var recommendationSettings: RecommendationSettingsResult?
    @Published public internal(set) var authTokens: [AuthTokenSummary] = []
    @Published public internal(set) var settingsError: String?
    @Published public internal(set) var lastLaunchResult: LaunchGameResult?
    @Published public internal(set) var launchError: String?
    @Published public internal(set) var launchErrorDetails: SidecarErrorDetails?
    @Published public internal(set) var isLaunchingGame = false
    @Published public internal(set) var savedSearches: [SavedModuleSearch]
    @Published public internal(set) var visibleModuleColumns: [ModuleTableColumn]

    let sidecar: SidecarProviding
    let previewSidecar: SidecarProviding
    let directoryOpener: InstanceDirectoryOpening
    let savedSearchStore: SavedModuleSearchStoring
    let moduleColumnStore: ModuleTableColumnStoring
    let catalogStateStore: ModuleCatalogStateStoring
    let catalogSnapshotStore: ModuleCatalogSnapshotStoring
    var pendingOperationCompletionAction: PendingOperationCompletionAction?
    var instanceStateLoadGeneration = 0
    var stagedChangeGeneration = 0
    var installationHistoryEntryLoadGeneration = 0

    public init(
        sidecar: SidecarProviding,
        previewSidecar: SidecarProviding? = nil,
        directoryOpener: InstanceDirectoryOpening = WorkspaceInstanceDirectoryOpener(),
        savedSearchStore: SavedModuleSearchStoring = UserDefaultsSavedModuleSearchStore(),
        moduleColumnStore: ModuleTableColumnStoring = UserDefaultsModuleTableColumnStore(),
        catalogStateStore: ModuleCatalogStateStoring = UserDefaultsModuleCatalogStateStore(),
        catalogSnapshotStore: ModuleCatalogSnapshotStoring = DisabledModuleCatalogSnapshotStore(),
        instances: [GameInstanceSummary] = [],
        modules: [ModuleSummary] = []
    ) {
        self.sidecar = sidecar
        self.previewSidecar = previewSidecar ?? sidecar
        self.directoryOpener = directoryOpener
        self.savedSearchStore = savedSearchStore
        self.moduleColumnStore = moduleColumnStore
        self.catalogStateStore = catalogStateStore
        self.catalogSnapshotStore = catalogSnapshotStore
        self.instances = instances
        self.modules = modules
        self.savedSearches = savedSearchStore.loadSavedSearches()
        let storedModuleColumns = moduleColumnStore.loadVisibleModuleColumns()
        self.visibleModuleColumns = Self.normalizedModuleColumns(storedModuleColumns)
        if let catalogState = catalogStateStore.loadCatalogState() {
            self.moduleSort = catalogState.moduleSort
            self.moduleSortAscending = catalogState.moduleSortAscending
            self.secondaryModuleSortCriteria = normalizedSecondarySortCriteria(
                catalogState.secondaryModuleSortCriteria)
        }
        self.selectedInstanceID = instances.first(where: \.isDefault)?.id ?? instances.first?.id
        recomputeFilteredModules()
        self.selectedModuleID = firstFilteredModuleID()
        if storedModuleColumns != visibleModuleColumns {
            moduleColumnStore.saveVisibleModuleColumns(visibleModuleColumns)
        }
    }

}

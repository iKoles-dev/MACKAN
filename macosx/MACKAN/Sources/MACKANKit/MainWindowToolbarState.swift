import Foundation

public struct MainWindowToolbarState: Equatable, Sendable {
    public let canRefreshRepositories: Bool
    public let canApplyPendingChangeSet: Bool
    public let hasPendingSelections: Bool
    public let canStageUpgradeAll: Bool
    public let canLaunchSelectedGame: Bool
    public let canOpenSelectedInstanceDirectory: Bool
    public let isRefreshingRepositories: Bool
    public let isResolvingChanges: Bool
    public let isApplyingChanges: Bool
    public let isInstallingCkanFiles: Bool
    public let isImportingDownloadFiles: Bool
    public let isLaunchingGame: Bool

    public init(
        canRefreshRepositories: Bool,
        canApplyPendingChangeSet: Bool,
        hasPendingSelections: Bool,
        canStageUpgradeAll: Bool,
        canLaunchSelectedGame: Bool,
        canOpenSelectedInstanceDirectory: Bool,
        isRefreshingRepositories: Bool,
        isResolvingChanges: Bool,
        isApplyingChanges: Bool,
        isInstallingCkanFiles: Bool,
        isImportingDownloadFiles: Bool,
        isLaunchingGame: Bool
    ) {
        self.canRefreshRepositories = canRefreshRepositories
        self.canApplyPendingChangeSet = canApplyPendingChangeSet
        self.hasPendingSelections = hasPendingSelections
        self.canStageUpgradeAll = canStageUpgradeAll
        self.canLaunchSelectedGame = canLaunchSelectedGame
        self.canOpenSelectedInstanceDirectory = canOpenSelectedInstanceDirectory
        self.isRefreshingRepositories = isRefreshingRepositories
        self.isResolvingChanges = isResolvingChanges
        self.isApplyingChanges = isApplyingChanges
        self.isInstallingCkanFiles = isInstallingCkanFiles
        self.isImportingDownloadFiles = isImportingDownloadFiles
        self.isLaunchingGame = isLaunchingGame
    }

    public var canClickRefresh: Bool { canRefreshRepositories && !isRefreshingRepositories }
    public var canClickPreview: Bool { hasPendingSelections && !isResolvingChanges }
    public var canClickApply: Bool { canApplyPendingChangeSet && !isApplyingChanges }
    public var canClickUpgradeAll: Bool { canStageUpgradeAll }
    public var canClickInstallFromFile: Bool { canRefreshRepositories && !isInstallingCkanFiles }
    public var canClickImportDownloads: Bool { canRefreshRepositories && !isImportingDownloadFiles }
    public var canClickClear: Bool { hasPendingSelections }
    public var canClickLaunch: Bool { canLaunchSelectedGame && !isLaunchingGame }
    public var canClickOpenFolder: Bool { canOpenSelectedInstanceDirectory }
}

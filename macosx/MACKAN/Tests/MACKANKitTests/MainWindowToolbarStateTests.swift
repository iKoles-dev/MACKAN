import XCTest
@testable import MACKANKit

final class MainWindowToolbarStateTests: XCTestCase {
    func testPrimaryActionsDisableDuringOperation() {
        let state = MainWindowToolbarState(
            canRefreshRepositories: true,
            canApplyPendingChangeSet: true,
            hasPendingSelections: true,
            canStageUpgradeAll: true,
            canLaunchSelectedGame: true,
            canOpenSelectedInstanceDirectory: true,
            isRefreshingRepositories: true,
            isResolvingChanges: false,
            isApplyingChanges: false,
            isInstallingCkanFiles: false,
            isImportingDownloadFiles: false,
            isLaunchingGame: false)

        XCTAssertFalse(state.canClickRefresh)
        XCTAssertTrue(state.canClickPreview)
        XCTAssertTrue(state.canClickApply)
    }

    func testFileActionsDisableDuringFileOperations() {
        let state = MainWindowToolbarState(
            canRefreshRepositories: true,
            canApplyPendingChangeSet: false,
            hasPendingSelections: false,
            canStageUpgradeAll: false,
            canLaunchSelectedGame: false,
            canOpenSelectedInstanceDirectory: false,
            isRefreshingRepositories: false,
            isResolvingChanges: false,
            isApplyingChanges: false,
            isInstallingCkanFiles: true,
            isImportingDownloadFiles: false,
            isLaunchingGame: false)

        XCTAssertFalse(state.canClickInstallFromFile)
        XCTAssertTrue(state.canClickImportDownloads)
    }
}

import XCTest

@testable import MACKANKit

final class OperationFlowStateTests: XCTestCase {
    func testActivityPresentationAndRetryStartIdle() {
        let state = OperationFlowState()

        XCTAssertTrue(state.activity.isIdle)
        XCTAssertEqual(state.presentation.presentedSheet, .none)
        XCTAssertEqual(state.retry.source, .none)
        XCTAssertNil(state.pendingRegistryLockRemoval)
    }

    func testActivityMutationsDelegateToActivityState() {
        var state = OperationFlowState()

        state.start(.applyingChanges)
        state.start(.refreshingOperationStatus)

        XCTAssertTrue(state.isActive(.applyingChanges))
        XCTAssertTrue(state.isActive(.refreshingOperationStatus))

        XCTAssertTrue(state.finish(.applyingChanges))

        XCTAssertFalse(state.isActive(.applyingChanges))
        XCTAssertTrue(state.isActive(.refreshingOperationStatus))
    }

    func testPresentationKeepsSheetsMutuallyExclusive() {
        var state = OperationFlowState()

        state.present(.changePreview)
        state.present(.operationResult)

        XCTAssertFalse(state.isPresenting(.changePreview))
        XCTAssertTrue(state.isPresenting(.operationResult))

        state.dismiss(.operationResult)

        XCTAssertEqual(state.presentation.presentedSheet, .none)
    }

    func testImportDownloadsResultPresentationDependsOnPreviewAndChangeSet() {
        var state = OperationFlowState()

        state.presentImportDownloadsResult(previewBeforeInstall: true, hasPendingChangeSet: true)
        XCTAssertTrue(state.isPresenting(.changePreview))

        state.presentImportDownloadsResult(previewBeforeInstall: true, hasPendingChangeSet: false)
        XCTAssertTrue(state.isPresenting(.operationResult))

        state.presentImportDownloadsResult(previewBeforeInstall: false, hasPendingChangeSet: true)
        XCTAssertTrue(state.isPresenting(.operationResult))
    }

    func testRetryRecordingExposesResolvedAction() {
        var state = OperationFlowState()

        state.recordRetry(.importDownloads)

        XCTAssertEqual(state.retry.source, .importDownloads)
        XCTAssertEqual(
            state.retryAction(skipDownloadFailures: true),
            .importDownloads(skipDownloadFailures: true))
    }

    func testRegistryLockRemovalRequestIsExplicitAndClearable() {
        var state = OperationFlowState()

        state.beginRegistryLockRemoval(lockfilePath: "/tmp/registry.locked", followUp: .apply)

        XCTAssertEqual(state.pendingRegistryLockRemoval?.lockfilePath, "/tmp/registry.locked")
        XCTAssertEqual(state.pendingRegistryLockRemoval?.followUp, .apply)

        state.clearRegistryLockRemoval()

        XCTAssertNil(state.pendingRegistryLockRemoval)
    }
}

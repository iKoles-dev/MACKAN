import XCTest

@testable import MACKANKit

final class OperationRetryStateTests: XCTestCase {
    func testDefaultRetryFallsBackToApplyChangesWithoutSkipDownloadFailures() {
        let state = OperationRetryState()

        XCTAssertEqual(state.source, .none)
        XCTAssertEqual(state.action(skipDownloadFailures: true), .applyChanges(skipDownloadFailures: false))
    }

    func testRecordedApplyChangesRetryPreservesSkipDownloadFailures() {
        var state = OperationRetryState()

        state.record(.applyChanges)

        XCTAssertEqual(state.source, .applyChanges)
        XCTAssertEqual(state.action(skipDownloadFailures: true), .applyChanges(skipDownloadFailures: true))
    }

    func testRecordedCkanFilesRetryMapsToInstallCkanFilesAction() {
        var state = OperationRetryState()

        state.record(.ckanFiles)

        XCTAssertEqual(state.source, .ckanFiles)
        XCTAssertEqual(state.action(), .installCkanFiles(skipDownloadFailures: false))
        XCTAssertEqual(state.action(skipDownloadFailures: true), .installCkanFiles(skipDownloadFailures: true))
    }

    func testRecordedImportDownloadsRetryMapsToImportDownloadsAction() {
        var state = OperationRetryState()

        state.record(.importDownloads)

        XCTAssertEqual(state.source, .importDownloads)
        XCTAssertEqual(state.action(), .importDownloads(skipDownloadFailures: false))
        XCTAssertEqual(state.action(skipDownloadFailures: true), .importDownloads(skipDownloadFailures: true))
    }
}

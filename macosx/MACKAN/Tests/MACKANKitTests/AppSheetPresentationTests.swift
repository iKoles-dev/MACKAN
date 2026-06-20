import XCTest
@testable import MACKANKit

@MainActor
final class AppSheetPresentationTests: XCTestCase {
    func testLatestPresentationWinsAfterRapidRequests() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        model.presentSheet(.about)
        model.presentSheet(.addInstance)
        model.presentSheet(.cloneInstance)
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(model.activeSheet, .cloneInstance)
    }

    func testDismissCancelsPendingPresentation() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        model.presentSheet(.about)
        model.presentSheet(.addInstance)
        model.dismissSheet()
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertNil(model.activeSheet)
    }
}

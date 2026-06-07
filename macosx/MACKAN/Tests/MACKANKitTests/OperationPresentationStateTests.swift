import XCTest

@testable import MACKANKit

final class OperationPresentationStateTests: XCTestCase {
    func testPresentingOneSheetExcludesTheOther() {
        var state = OperationPresentationState()

        state.present(.changePreview)

        XCTAssertTrue(state.isPresenting(.changePreview))
        XCTAssertFalse(state.isPresenting(.operationResult))

        state.present(.operationResult)

        XCTAssertFalse(state.isPresenting(.changePreview))
        XCTAssertTrue(state.isPresenting(.operationResult))
    }

    func testDismissOnlyClearsMatchingSheet() {
        var state = OperationPresentationState(presentedSheet: .operationResult)

        state.dismiss(.changePreview)

        XCTAssertEqual(state.presentedSheet, .operationResult)

        state.dismiss(.operationResult)

        XCTAssertEqual(state.presentedSheet, .none)
    }

    func testClearRemovesAnyPresentedSheet() {
        var state = OperationPresentationState(presentedSheet: .changePreview)

        state.clear()

        XCTAssertEqual(state.presentedSheet, .none)
        XCTAssertFalse(state.isPresenting(.changePreview))
        XCTAssertFalse(state.isPresenting(.operationResult))
    }

    func testCompletedOperationTimelineHidesSupersededZeroProgressEvents() {
        let result = OperationResult(
            operationId: "op-1",
            instanceId: "primary",
            status: "completed",
            changes: [],
            events: [
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Downloading Module Manager",
                    percent: 0,
                    identifier: "ModuleManager",
                    remainingBytes: 1024,
                    totalBytes: 1024),
                OperationEvent(
                    kind: "progress",
                    message: "1 KiB left - 0%",
                    percent: 0,
                    identifier: nil,
                    remainingBytes: 1024,
                    totalBytes: 1024),
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Downloading Module Manager",
                    percent: 80,
                    identifier: "ModuleManager",
                    remainingBytes: 204,
                    totalBytes: 1024),
                OperationEvent(
                    kind: "complete",
                    message: "Module Manager",
                    percent: 100,
                    identifier: "ModuleManager",
                    remainingBytes: 0,
                    totalBytes: 1024),
            ],
            error: nil)

        XCTAssertEqual(
            OperationTimelinePresentationState(result: result).events.map(\.percent),
            [80, 100])
    }

    func testRunningOperationTimelineKeepsInitialZeroProgressEvents() {
        let result = OperationResult(
            operationId: "op-1",
            instanceId: "primary",
            status: "running",
            changes: [],
            events: [
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Downloading Module Manager",
                    percent: 0,
                    identifier: "ModuleManager",
                    remainingBytes: 1024,
                    totalBytes: 1024),
            ],
            error: nil)

        XCTAssertEqual(
            OperationTimelinePresentationState(result: result).events.map(\.percent),
            [0])
    }
}

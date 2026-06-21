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

    func testOperationProgressAggregatesEventsIntoOneRowPerChangedModule() {
        let result = OperationResult(
            operationId: "op-1",
            instanceId: "primary",
            status: "running",
            changes: [
                ChangeSummary(
                    identifier: "FirespitterCore",
                    name: "Firespitter Core",
                    action: "install",
                    fromVersion: nil,
                    toVersion: "v7.17",
                    reasons: ["Dependency of USI-Core"],
                    isUserRequested: false,
                    isAuto: true),
                ChangeSummary(
                    identifier: "USI-Core",
                    name: "USI Core",
                    action: "install",
                    fromVersion: nil,
                    toVersion: "v112.0.1",
                    reasons: ["Dependency of USI-NuclearRockets"],
                    isUserRequested: false,
                    isAuto: true),
            ],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Operation queued",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Firespitter Core",
                    percent: 20,
                    identifier: "FirespitterCore",
                    remainingBytes: 800,
                    totalBytes: 1_000),
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Firespitter Core",
                    percent: 70,
                    identifier: "FirespitterCore",
                    remainingBytes: 300,
                    totalBytes: 1_000),
                OperationEvent(
                    kind: "installProgress",
                    message: "USI Core",
                    percent: 40,
                    identifier: "USI-Core",
                    remainingBytes: 600,
                    totalBytes: 1_000),
            ],
            error: nil)

        let state = OperationProgressPresentationState(result: result)

        XCTAssertEqual(state.rows.map(\.id), ["FirespitterCore", "USI-Core"])
        XCTAssertEqual(state.rows.map(\.title), ["Firespitter Core", "USI Core"])
        XCTAssertEqual(state.rows.map(\.phase), [.downloading, .installing])
        XCTAssertEqual(state.rows.map(\.progressFraction), [0.7, 0.4])
        XCTAssertEqual(state.rows.first?.byteProgressDisplay, "700 bytes of 1 KB")
        XCTAssertEqual(state.currentActivity, "USI Core")
    }

    func testOperationProgressUsesChangeRowsBeforePerModuleEventsArrive() {
        let result = OperationResult(
            operationId: "op-1",
            instanceId: "primary",
            status: "running",
            changes: [
                ChangeSummary(
                    identifier: "USITools",
                    name: "USI Tools",
                    action: "install",
                    fromVersion: nil,
                    toVersion: "v112.0.1",
                    reasons: ["Dependency of USI-Core"],
                    isUserRequested: false,
                    isAuto: true),
            ],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "About to install:",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)

        let state = OperationProgressPresentationState(result: result)

        XCTAssertEqual(state.rows.count, 1)
        XCTAssertEqual(state.rows[0].id, "USITools")
        XCTAssertEqual(state.rows[0].phase, .queued)
        XCTAssertEqual(state.rows[0].subtitle, "Install v112.0.1")
        XCTAssertNil(state.rows[0].progressFraction)
        XCTAssertEqual(state.currentActivity, "About to install:")
    }
}

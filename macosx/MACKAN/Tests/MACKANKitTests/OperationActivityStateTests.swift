import XCTest

@testable import MACKANKit

final class OperationActivityStateTests: XCTestCase {
    func testDefaultStateIsIdle() {
        let state = OperationActivityState()

        XCTAssertTrue(state.isIdle)
        XCTAssertTrue(state.activeActivities.isEmpty)
        XCTAssertFalse(state.isActive(.applyingChanges))
    }

    func testStartAndFinishActivity() {
        var state = OperationActivityState()

        state.start(.applyingChanges)

        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isActive(.applyingChanges))

        XCTAssertTrue(state.finish(.applyingChanges))

        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isActive(.applyingChanges))
    }

    func testActivitiesAreIndependent() {
        var state = OperationActivityState()

        state.start(.applyingChanges)
        state.start(.refreshingOperationStatus)
        state.start(.applyingChanges)

        XCTAssertEqual(state.activeActivities, [.applyingChanges, .refreshingOperationStatus])

        XCTAssertTrue(state.finish(.applyingChanges))

        XCTAssertFalse(state.isActive(.applyingChanges))
        XCTAssertTrue(state.isActive(.refreshingOperationStatus))
    }

    func testFinishingInactiveActivityDoesNotMutateState() {
        var state = OperationActivityState(activeActivities: [.installingCkanFiles])

        XCTAssertFalse(state.finish(.cancellingOperation))

        XCTAssertEqual(state.activeActivities, [.installingCkanFiles])
    }

    func testClearRemovesAllActivities() {
        var state = OperationActivityState(activeActivities: [
            .importingDownloadFiles,
            .removingRegistryLock,
            .resolvingChanges
        ])

        state.clear()

        XCTAssertTrue(state.isIdle)
    }
}

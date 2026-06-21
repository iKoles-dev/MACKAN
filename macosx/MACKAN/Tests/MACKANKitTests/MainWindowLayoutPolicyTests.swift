import CoreGraphics
import XCTest
@testable import MACKANKit

final class MainWindowLayoutPolicyTests: XCTestCase {
    func testWindowCanAdaptBelowThreeColumnWidth() {
        let threeColumnMinimum = MainWindowLayoutPolicy.sidebarMinimumWidth
            + MainWindowLayoutPolicy.contentMinimumWidth
            + MainWindowLayoutPolicy.inspectorMinimumWidth

        XCTAssertLessThan(MainWindowLayoutPolicy.minimumWindowWidth, threeColumnMinimum)
        XCTAssertGreaterThan(MainWindowLayoutPolicy.sidebarVisibilityBreakpoint, MainWindowLayoutPolicy.minimumWindowWidth)
        XCTAssertGreaterThan(MainWindowLayoutPolicy.inspectorVisibilityBreakpoint, MainWindowLayoutPolicy.sidebarVisibilityBreakpoint)
    }

    func testDefaultWindowStartsInThreeColumnLayout() {
        XCTAssertGreaterThanOrEqual(MainWindowLayoutPolicy.defaultWindowWidth, MainWindowLayoutPolicy.inspectorVisibilityBreakpoint)
        XCTAssertGreaterThan(MainWindowLayoutPolicy.defaultWindowHeight, MainWindowLayoutPolicy.minimumWindowHeight)
    }

    func testInspectorHiddenWhenNoModuleIsSelectedBelowWideWorkspace() {
        XCTAssertFalse(MainWindowLayoutPolicy.shouldShowInspector(windowWidth: 1120, hasSelectedModule: false))
        XCTAssertFalse(MainWindowLayoutPolicy.shouldShowInspector(windowWidth: 1360, hasSelectedModule: false))
        XCTAssertTrue(MainWindowLayoutPolicy.shouldShowInspector(windowWidth: 1440, hasSelectedModule: false))
    }

    func testInspectorShownForSelectedModuleWhenEnoughSpaceExists() {
        XCTAssertFalse(MainWindowLayoutPolicy.shouldShowInspector(windowWidth: 900, hasSelectedModule: true))
        XCTAssertTrue(MainWindowLayoutPolicy.shouldShowInspector(windowWidth: 1120, hasSelectedModule: true))
    }

    func testSidebarWidthsLeaveCatalogRoom() {
        XCTAssertEqual(MainWindowLayoutPolicy.sidebarIdealWidth(forWindowWidth: 1120), 240)
        XCTAssertEqual(MainWindowLayoutPolicy.sidebarIdealWidth(forWindowWidth: 1440), 260)
        XCTAssertLessThanOrEqual(MainWindowLayoutPolicy.sidebarMaximumWidth(forWindowWidth: 1120), 260)
    }

    func testStartupFrameMovesOffscreenFrameIntoVisibleArea() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let proposedFrame = CGRect(x: -260, y: 120, width: 1200, height: 720)

        let constrainedFrame = MainWindowLayoutPolicy.constrainedStartupFrame(
            proposedFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(constrainedFrame.origin.x, visibleFrame.minX, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.origin.y, proposedFrame.origin.y, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.width, proposedFrame.width, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.height, proposedFrame.height, accuracy: 0.001)
    }

    func testStartupFrameShrinksOversizedRestoredFrameToVisibleArea() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1024, height: 700)
        let proposedFrame = CGRect(x: -180, y: -40, width: 1600, height: 900)

        let constrainedFrame = MainWindowLayoutPolicy.constrainedStartupFrame(
            proposedFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(constrainedFrame.origin.x, visibleFrame.minX, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.origin.y, visibleFrame.minY, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.width, visibleFrame.width, accuracy: 0.001)
        XCTAssertEqual(constrainedFrame.height, visibleFrame.height, accuracy: 0.001)
    }

    func testStartupFramePreservesVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let proposedFrame = CGRect(x: 80, y: 100, width: 1200, height: 720)

        let constrainedFrame = MainWindowLayoutPolicy.constrainedStartupFrame(
            proposedFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(constrainedFrame, proposedFrame)
    }
}

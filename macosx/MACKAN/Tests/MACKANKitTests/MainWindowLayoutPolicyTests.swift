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
}

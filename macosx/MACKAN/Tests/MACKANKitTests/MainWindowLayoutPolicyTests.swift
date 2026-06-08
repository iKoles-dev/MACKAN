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
}

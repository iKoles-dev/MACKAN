import XCTest
@testable import MACKANKit

final class CatalogToolbarLayoutPolicyTests: XCTestCase {
    func testMinimumContentWidthPreventsCatalogToolbarControlOverlap() {
        XCTAssertGreaterThanOrEqual(CatalogToolbarLayoutPolicy.searchMinimumWidth, 260)
        XCTAssertGreaterThanOrEqual(CatalogToolbarLayoutPolicy.controlsMinimumWidth, CatalogToolbarLayoutPolicy.calculatedControlsMinimumWidth)
        XCTAssertLessThan(CatalogToolbarLayoutPolicy.minimumContentWidth, 760)
    }
}

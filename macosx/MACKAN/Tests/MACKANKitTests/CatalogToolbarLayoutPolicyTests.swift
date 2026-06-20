import XCTest
@testable import MACKANKit

final class CatalogToolbarLayoutPolicyTests: XCTestCase {
    func testMinimumContentWidthPreventsCatalogToolbarControlOverlap() {
        XCTAssertGreaterThanOrEqual(CatalogToolbarLayoutPolicy.searchMinimumWidth, 260)
        XCTAssertGreaterThanOrEqual(CatalogToolbarLayoutPolicy.controlsMinimumWidth, CatalogToolbarLayoutPolicy.calculatedControlsMinimumWidth)
        XCTAssertLessThan(CatalogToolbarLayoutPolicy.minimumContentWidth, 760)
    }

    func testWideToolbarUsesSingleRowWhenSearchAndControlsFit() {
        XCTAssertFalse(CatalogToolbarLayoutPolicy.shouldUseSingleRow(forWidth: 960))
        XCTAssertTrue(CatalogToolbarLayoutPolicy.shouldUseSingleRow(forWidth: 1120))
    }
}

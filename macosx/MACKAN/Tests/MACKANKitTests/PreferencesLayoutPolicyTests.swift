import XCTest
@testable import MACKANKit

final class PreferencesLayoutPolicyTests: XCTestCase {
    func testPreferencesWindowUsesResizableBoundsInsteadOfFixedSize() {
        XCTAssertLessThan(PreferencesLayoutPolicy.minimumWidth, PreferencesLayoutPolicy.idealWidth)
        XCTAssertLessThan(PreferencesLayoutPolicy.idealWidth, PreferencesLayoutPolicy.maximumWidth)
        XCTAssertLessThan(PreferencesLayoutPolicy.minimumHeight, PreferencesLayoutPolicy.idealHeight)
    }

    func testPreferencesWindowHasEnoughRoomForTenIconTabs() {
        XCTAssertGreaterThanOrEqual(
            PreferencesLayoutPolicy.idealWidth,
            PreferencesLayoutPolicy.estimatedTabBarWidth(tabCount: 10))
    }
}

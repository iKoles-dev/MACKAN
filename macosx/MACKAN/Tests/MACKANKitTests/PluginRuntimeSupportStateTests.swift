import XCTest

@testable import MACKANKit

final class PluginRuntimeSupportStateTests: XCTestCase {
    func testNativeMacOSPluginsAreExplicitlyUnsupportedUntilCoreHostExists() {
        let state = PluginRuntimeSupportState.nativeMacOS

        XCTAssertFalse(state.isSupported)
        XCTAssertEqual(state.title, "Not supported on native macOS yet")
        XCTAssertTrue(state.explanation.contains("macOS-native plugin runtime"))
        XCTAssertTrue(state.plannedPath.contains("cross-platform plugin host contract"))
        XCTAssertEqual(state.links.map(\.title), ["Open CKAN repository", "Track CKAN plugin work"])
        XCTAssertEqual(state.links.map(\.url.absoluteString), [
            "https://github.com/KSP-CKAN/CKAN",
            "https://github.com/KSP-CKAN/CKAN/issues",
        ])
    }
}

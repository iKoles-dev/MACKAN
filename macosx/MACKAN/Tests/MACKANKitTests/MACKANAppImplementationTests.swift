import XCTest

final class MACKANAppImplementationTests: XCTestCase {
    func testAppModelStateObjectUsesExplicitInitializerForCompilerStability() throws {
        let source = try mackanAppSource()

        XCTAssertFalse(
            source.contains("@StateObject private var model = AppModel("),
            "MACKANApp should not build AppModel directly in the @StateObject property initializer because Swift 6.1.2 can crash in release SILGen on that expression.")
        XCTAssertTrue(
            source.contains("@StateObject private var model: AppModel"),
            "MACKANApp should keep the StateObject property declaration simple.")
        XCTAssertTrue(
            source.contains("_model = StateObject(wrappedValue: Self.makeAppModel())"),
            "MACKANApp should initialize the StateObject explicitly from init().")
    }

    private func mackanAppSource() throws -> String {
        try String(contentsOf: mackanAppSourceURL(), encoding: .utf8)
    }

    private func mackanAppSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("MACKANApp.swift")
    }
}

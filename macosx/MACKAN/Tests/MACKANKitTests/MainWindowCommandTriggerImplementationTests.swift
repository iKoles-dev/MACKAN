import XCTest

final class MainWindowCommandTriggerImplementationTests: XCTestCase {
    func testMainWindowRespondsToAppCommandTriggersAfterAppear() throws {
        let source = try mainWindowViewSource()

        XCTAssertTrue(
            source.contains(".onChange(of: model.installFromCkanFileTrigger)"),
            "MainWindowView must handle Install from File commands after the window has already appeared.")
        XCTAssertTrue(
            source.contains(".onChange(of: model.importDownloadsTrigger)"),
            "MainWindowView must handle Import Downloads commands after the window has already appeared.")
        XCTAssertTrue(
            source.contains(".onChange(of: model.applyChangesTrigger)"),
            "MainWindowView must handle Apply Changes commands after the window has already appeared.")
    }

    private func mainWindowViewSource() throws -> String {
        try String(contentsOf: mainWindowViewSourceURL(), encoding: .utf8)
    }

    private func mainWindowViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("MainWindowView.swift")
    }
}

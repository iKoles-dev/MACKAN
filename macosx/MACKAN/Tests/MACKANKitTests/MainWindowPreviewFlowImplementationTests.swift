import XCTest

final class MainWindowPreviewFlowImplementationTests: XCTestCase {
    func testPreviewSheetIsPresentedBeforeResolvingChanges() throws {
        let source = try mainWindowViewSource()
        let previewFunction = try XCTUnwrap(source.range(of: "private func previewChanges()"))
        let body = source[previewFunction.lowerBound...]

        let presentRange = try XCTUnwrap(body.range(of: "operationFlow.present(.changePreview)"))
        let resolveRange = try XCTUnwrap(body.range(of: "try await model.resolveChanges()"))

        XCTAssertLessThan(
            presentRange.lowerBound,
            resolveRange.lowerBound,
            "Preview should open immediately and show a resolving state while CKAN resolves dependencies.")
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

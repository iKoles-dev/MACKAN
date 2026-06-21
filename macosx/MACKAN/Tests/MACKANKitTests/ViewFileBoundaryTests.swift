import XCTest

final class ViewFileBoundaryTests: XCTestCase {
    func testOperationSheetsAreSplitBySheetResponsibility() throws {
        let sources = sourceDirectory()
        let aggregate = try source(named: "OperationSheets.swift")

        XCTAssertFalse(
            aggregate.contains("struct ChangeSetPreviewSheet"),
            "Change set preview UI belongs in ChangeSetPreviewSheet.swift, not the aggregate operation file.")
        XCTAssertFalse(
            aggregate.contains("struct OperationResultSheet"),
            "Operation result UI belongs in OperationResultSheet.swift, not the aggregate operation file.")
        XCTAssertTrue(
            fileExists("ChangeSetPreviewSheet.swift", in: sources),
            "The change preview sheet should have a dedicated file.")
        XCTAssertTrue(
            fileExists("OperationResultSheet.swift", in: sources),
            "The operation result sheet should have a dedicated file.")
        XCTAssertTrue(
            fileExists("OperationNotices.swift", in: sources),
            "Reusable operation notices should have a dedicated file.")
        XCTAssertLessThanOrEqual(
            lineCount(of: aggregate),
            220,
            "OperationSheets.swift should stay as a small entry-point file after the split.")
    }

    func testInspectorViewsAreSplitBySectionResponsibility() throws {
        let sources = sourceDirectory()
        let aggregate = try source(named: "InspectorViews.swift")

        XCTAssertFalse(
            aggregate.contains("struct ModuleOverviewPage"),
            "Overview content belongs in ModuleOverviewPage.swift, not the aggregate inspector file.")
        XCTAssertFalse(
            aggregate.contains("struct RelationshipGraphView"),
            "Relationship graph rendering belongs in ModuleRelationshipGraphView.swift.")
        XCTAssertTrue(fileExists("ModuleDetailHeader.swift", in: sources))
        XCTAssertTrue(fileExists("ModuleOverviewPage.swift", in: sources))
        XCTAssertTrue(fileExists("ModuleDetailSections.swift", in: sources))
        XCTAssertTrue(fileExists("ModuleRelationshipGraphView.swift", in: sources))
        XCTAssertLessThanOrEqual(
            lineCount(of: aggregate),
            260,
            "InspectorViews.swift should keep root composition only after the split.")
    }

    private func source(named filename: String) throws -> String {
        try String(contentsOf: sourceDirectory().appendingPathComponent(filename), encoding: .utf8)
    }

    private func fileExists(_ filename: String, in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(filename).path)
    }

    private func lineCount(of source: String) -> Int {
        source.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func sourceDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
    }
}

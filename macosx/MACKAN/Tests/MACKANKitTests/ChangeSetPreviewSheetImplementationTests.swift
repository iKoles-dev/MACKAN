import XCTest

final class ChangeSetPreviewSheetImplementationTests: XCTestCase {
    func testChangePreviewUsesAdaptiveListInsteadOfHorizontalTable() throws {
        let source = try operationSheetsSource()

        XCTAssertFalse(
            source.contains("Table(result.changes)"),
            "The change preview should not use Table for resolved changes because long reasons force horizontal scrolling.")
        XCTAssertTrue(
            source.contains("ChangeSetPreviewList(changes: result.changes)"),
            "Resolved changes should render through a custom list that can wrap reason text.")
        XCTAssertTrue(source.contains("ScrollView"))
        XCTAssertTrue(source.contains("LazyVStack"))
        XCTAssertTrue(source.contains("ChangeSetPreviewRow(change: change)"))
        XCTAssertTrue(
            source.contains(".mackanModalSheetFrame(.wide)"),
            "The preview sheet should use the wide modal size so dependency reasons have room to breathe.")
    }

    func testChangePreviewRowsExposeActionVersionAndWrappedReasons() throws {
        let source = try operationSheetsSource()

        XCTAssertTrue(source.contains("Label(change.actionTitle, systemImage: change.actionSymbolName)"))
        XCTAssertTrue(source.contains("change.actionTint"))
        XCTAssertTrue(source.contains("Text(change.versionText)"))
        XCTAssertTrue(
            source.contains("ForEach(change.displayReasons, id: \\.self)"),
            "Each reason should be rendered separately instead of joined into one truncating string.")
        XCTAssertTrue(
            source.contains(".fixedSize(horizontal: false, vertical: true)"),
            "Long dependency reasons should wrap vertically instead of being clipped.")
    }

    func testChangePreviewSummarizesActionsAboveTheList() throws {
        let source = try operationSheetsSource()

        XCTAssertTrue(source.contains("ChangeSetActionSummaryStrip(changes: result.changes)"))
        XCTAssertTrue(source.contains("ChangeSetActionCountPill("))
        XCTAssertTrue(source.contains("Dictionary(grouping: changes, by: \\.action)"))
        XCTAssertTrue(source.contains("ChangeSummary.actionSortRank"))
    }

    func testChangePreviewHasResolvingStateInsteadOfEmptyPlaceholder() throws {
        let source = try operationSheetsSource()

        XCTAssertTrue(source.contains("let isResolving: Bool"))
        XCTAssertTrue(source.contains("if isResolving {\n                resolvingPreviewState"))
        XCTAssertTrue(source.contains("private var resolvingPreviewState: some View"))
        XCTAssertTrue(source.contains("Text(\"Resolving Preview\")"))
        XCTAssertTrue(source.contains("ProgressView()"))
        XCTAssertTrue(source.contains(".disabled(isResolving || (result == nil && errorMessage == nil))"))
        XCTAssertTrue(source.contains(".disabled(!canApply || isApplying || isResolving)"))
    }

    func testOperationResultUsesPlainDetailsToggleInsteadOfFocusedDisclosureGroup() throws {
        let source = try operationSheetsSource()

        XCTAssertFalse(
            source.contains("DisclosureGroup(isExpanded: $showsDetails)"),
            "The operation details expander should not use DisclosureGroup because it can receive the sheet focus highlight.")
        XCTAssertTrue(source.contains("OperationDetailsToggle(isExpanded: $showsDetails)"))
        XCTAssertTrue(source.contains(".buttonStyle(.plain)"))
        XCTAssertTrue(source.contains(".focusable(false)"))
    }

    func testOperationResultOnlyShowsStatusRefreshSpinnerForActiveOperations() throws {
        let source = try operationSheetsSource()

        XCTAssertTrue(
            source.contains("private var showsStatusRefreshActivity: Bool"),
            "The sheet should distinguish operation-status polling from post-completion catalog refresh.")
        XCTAssertTrue(
            source.contains("isRefreshing && result?.isActive == true"),
            "A completed operation must not keep the Refresh Status spinner visible.")
        XCTAssertTrue(
            source.contains("if showsStatusRefreshActivity"),
            "The status spinner should be gated by the active-operation presentation state.")
    }

    private func operationSheetsSource() throws -> String {
        try [
            "ChangeSetPreviewSheet.swift",
            "OperationResultSheet.swift",
            "OperationNotices.swift",
        ]
        .map { try String(contentsOf: operationSourceURL($0), encoding: .utf8) }
        .joined(separator: "\n")
    }

    private func operationSourceURL(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent(filename)
    }
}

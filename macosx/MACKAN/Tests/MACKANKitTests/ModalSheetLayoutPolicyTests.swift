import XCTest
@testable import MACKANKit

final class ModalSheetLayoutPolicyTests: XCTestCase {
    func testLargeSheetsUseResizableBoundsWithinMainWindowLimits() {
        XCTAssertLessThanOrEqual(ModalSheetLayoutPolicy.standardMinimumWidth, MainWindowLayoutPolicy.minimumWindowWidth)
        XCTAssertLessThan(ModalSheetLayoutPolicy.standardMinimumWidth, ModalSheetLayoutPolicy.standardIdealWidth)
        XCTAssertLessThanOrEqual(ModalSheetLayoutPolicy.standardMinimumHeight, MainWindowLayoutPolicy.minimumWindowHeight)
        XCTAssertLessThan(ModalSheetLayoutPolicy.standardMinimumHeight, ModalSheetLayoutPolicy.standardIdealHeight)
    }

    func testCompactSheetsStayUsableWithoutHardFixedWidth() {
        XCTAssertGreaterThanOrEqual(ModalSheetLayoutPolicy.compactMinimumWidth, 320)
        XCTAssertLessThan(ModalSheetLayoutPolicy.compactMinimumWidth, ModalSheetLayoutPolicy.compactIdealWidth)
        XCTAssertLessThanOrEqual(ModalSheetLayoutPolicy.compactIdealWidth, ModalSheetLayoutPolicy.standardIdealWidth)
    }

    func testWideSheetsRemainBoundedForResizableContent() {
        XCTAssertLessThan(ModalSheetLayoutPolicy.wideMinimumWidth, ModalSheetLayoutPolicy.wideIdealWidth)
        XCTAssertLessThan(ModalSheetLayoutPolicy.wideIdealWidth, ModalSheetLayoutPolicy.wideMaximumWidth)
        XCTAssertGreaterThanOrEqual(ModalSheetLayoutPolicy.wideMinimumWidth, ModalSheetLayoutPolicy.standardMinimumWidth)
    }

    func testAddRepositorySheetUsesStandardHeightForKnownSourcesAndFooter() {
        XCTAssertGreaterThan(
            AddRepositorySheetPresentationPolicy.minimumSheetHeight,
            ModalSheetLayoutPolicy.compactIdealHeight)
        XCTAssertLessThanOrEqual(
            AddRepositorySheetPresentationPolicy.minimumSheetHeight,
            ModalSheetLayoutPolicy.standardIdealHeight)
    }

    func testAddRepositoryKnownSourceSelectionSuppliesFields() {
        let repositories = [
            RepositorySummary(
                name: "KSP-backup",
                url: "https://example.invalid/backup.tar.gz",
                priority: 0,
                isMirror: false,
                comment: ""),
            RepositorySummary(
                name: "Sol",
                url: "https://example.invalid/sol.tar.gz",
                priority: 1,
                isMirror: false,
                comment: ""),
        ]

        let fields = AddRepositorySheetPresentationPolicy.fields(
            for: "Sol",
            in: repositories)

        XCTAssertEqual(fields?.name, "Sol")
        XCTAssertEqual(fields?.url, "https://example.invalid/sol.tar.gz")
        XCTAssertNil(AddRepositorySheetPresentationPolicy.fields(for: "missing", in: repositories))
    }

    func testExportModpackRelationshipListLeavesRoomForMetadataAndFooter() {
        XCTAssertGreaterThanOrEqual(ModalSheetLayoutPolicy.exportModpackRelationshipListMinimumHeight, 160)
        XCTAssertLessThanOrEqual(
            ModalSheetLayoutPolicy.exportModpackRelationshipListMaximumHeight,
            ModalSheetLayoutPolicy.standardIdealHeight / 2)

        let reservedMetadataAndFooterHeight = 420.0
        XCTAssertLessThanOrEqual(
            ModalSheetLayoutPolicy.exportModpackRelationshipListMaximumHeight + reservedMetadataAndFooterHeight,
            ModalSheetLayoutPolicy.standardMaximumHeight)
    }
}

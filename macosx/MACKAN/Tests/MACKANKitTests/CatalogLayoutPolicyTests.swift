import XCTest
@testable import MACKANKit

final class CatalogLayoutPolicyTests: XCTestCase {
    func testCompactPresetKeepsActionableColumnsVisible() {
        let columns = CatalogLayoutPolicy.visibleColumns(
            forWidth: 760,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(columns, [.status, .name, .latestVersion])
    }

    func testDefaultPresetKeepsInstalledCatalogReadable() {
        let columns = CatalogLayoutPolicy.visibleColumns(
            forWidth: 1120,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(columns, [.status, .pending, .name, .latestVersion, .author])
        XCTAssertFalse(columns.contains(.installedVersion))
    }

    func testWidePresetRespectsUserColumnsWithoutDroppingName() {
        let stored: [ModuleTableColumn] = [
            .status,
            .pending,
            .autoInstalled,
            .name,
            .installedVersion,
            .latestVersion,
            .author,
        ]
        let columns = CatalogLayoutPolicy.visibleColumns(forWidth: 1440, storedColumns: stored)

        XCTAssertEqual(columns, stored)
    }

    func testColumnWidthsFitWithinReadableViewport() {
        let compact = CatalogLayoutPolicy.layout(
            forWidth: 760,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(compact.totalWidth, 760)
        XCTAssertGreaterThanOrEqual(compact.width(for: .name), 260)
        XCTAssertLessThanOrEqual(compact.width(for: .status), 72)
    }

    func testTableFillsWideViewportWhenColumnsWouldOtherwiseLeaveDeadSpace() {
        let layout = CatalogLayoutPolicy.layout(
            forWidth: 1440,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(layout.totalWidth, 1440)
        XCTAssertGreaterThan(layout.width(for: .name), CatalogLayoutPolicy.responsiveWidth(for: .name, viewportWidth: 1440))
        XCTAssertGreaterThan(layout.width(for: .author), CatalogLayoutPolicy.responsiveWidth(for: .author, viewportWidth: 1440))
    }

    func testTableContentWidthReservesTrailingScrollIndicatorGutter() {
        XCTAssertEqual(CatalogLayoutPolicy.contentWidth(forViewportWidth: 760), 748)
        XCTAssertEqual(CatalogLayoutPolicy.contentWidth(forViewportWidth: 8), 0)
    }

    func testCompactLatestColumnExpandsToReadableTrailingColumn() {
        let contentWidth = CatalogLayoutPolicy.contentWidth(forViewportWidth: 760)
        let layout = CatalogLayoutPolicy.layout(
            forWidth: contentWidth,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(layout.totalWidth, contentWidth)
        XCTAssertEqual(layout.columns, [.status, .name, .latestVersion])
        XCTAssertGreaterThan(layout.width(for: .latestVersion), CatalogLayoutPolicy.responsiveWidth(for: .latestVersion, viewportWidth: contentWidth))
    }

    func testWideUserColumnSetFitsViewportInsteadOfRequiringHorizontalScroll() {
        let layout = CatalogLayoutPolicy.layout(
            forWidth: 1440,
            storedColumns: ModuleTableColumn.allCases)

        XCTAssertEqual(layout.totalWidth, 1440)
        XCTAssertLessThan(layout.columns.count, ModuleTableColumn.allCases.count)
    }

    func testRowMetricsAreStableAcrossBreakpoints() {
        XCTAssertEqual(CatalogLayoutPolicy.rowHeight(forWidth: 760), 30)
        XCTAssertEqual(CatalogLayoutPolicy.rowHeight(forWidth: 1120), 30)
        XCTAssertEqual(CatalogLayoutPolicy.rowHeight(forWidth: 1440), 28)
    }

    func testSelectionScrollBottomInsetKeepsSelectedRowAboveScrollBoundary() {
        XCTAssertEqual(CatalogLayoutPolicy.selectionScrollBottomInset(forRowHeight: 30), 38)
        XCTAssertEqual(CatalogLayoutPolicy.selectionScrollBottomInset(forRowHeight: 28), 36)
    }

    func testStatusColumnUsesCompactWidthInSmallWindows() {
        XCTAssertEqual(CatalogLayoutPolicy.responsiveWidth(for: .status, viewportWidth: 760), 56)
        XCTAssertEqual(CatalogLayoutPolicy.responsiveWidth(for: .status, viewportWidth: 1360), 56)
    }
}

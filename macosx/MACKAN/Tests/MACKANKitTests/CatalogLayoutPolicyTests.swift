import XCTest
@testable import MACKANKit

final class CatalogLayoutPolicyTests: XCTestCase {
    func testCompactPresetKeepsActionableColumnsVisible() {
        let columns = CatalogLayoutPolicy.visibleColumns(
            forWidth: 760,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(columns, [.status, .name, .installedVersion, .latestVersion])
    }

    func testDefaultPresetKeepsInstalledCatalogReadable() {
        let columns = CatalogLayoutPolicy.visibleColumns(
            forWidth: 1120,
            storedColumns: ModuleTableColumn.defaultVisible)

        XCTAssertEqual(columns, [.status, .pending, .name, .installedVersion, .latestVersion, .author])
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

        XCTAssertLessThanOrEqual(compact.totalWidth, 980)
        XCTAssertGreaterThanOrEqual(compact.width(for: .name), 260)
        XCTAssertLessThanOrEqual(compact.width(for: .status), 72)
    }
}

import XCTest

final class CatalogTableLayoutImplementationTests: XCTestCase {
    func testCatalogTableUsesActualScrollViewportForColumnLayout() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(
            source.contains("CatalogLayoutPolicy.contentWidth(forViewportWidth: viewportProxy.size.width)"),
            "Catalog columns must be sized from the table's actual GeometryReader viewport; an outer width can drift from the rendered scroll container inside the split layout.")
        XCTAssertFalse(
            source.contains("CatalogLayoutPolicy.contentWidth(forViewportWidth: viewportWidth)"),
            "Using the externally supplied viewport width leaves blank space when the split layout gives the scroll container a different final width.")
    }

    func testCatalogHeaderUsesOneContinuousBackgroundInsteadOfPerColumnBackgrounds() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(source.contains(".frame(width: layout.totalWidth, alignment: .topLeading)"))
        XCTAssertTrue(source.contains(".background(Color(nsColor: .controlBackgroundColor))"))
        XCTAssertTrue(
            source.contains("""
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
"""),
            "The header row needs one continuous background so the right edge of the last visible column does not look like an unfinished extra column.")
        XCTAssertFalse(
            source.contains(".frame(width: layout.width(for: column), height: 28, alignment: .leading)\n        .background(Color(nsColor: .controlBackgroundColor))"),
            "Per-column header backgrounds expose a vertical seam after the last visible column when the row extends to the scroll gutter.")
        XCTAssertFalse(
            source.contains(".frame(width: layout.width(for: column), height: 28, alignment: .leading)\n        .overlay(alignment: .bottom)"),
            "Per-column bottom dividers expose seams between header cells; the divider should be drawn once across the whole header row.")
    }

    func testStatusColumnUsesIconOnlyStatusView() throws {
        let tableSource = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)
        let badgesSource = try String(
            contentsOf: catalogBadgesSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(
            tableSource.contains("StatusIcon(status: module.status, stagedAction: model.stagedAction(for: module.identifier))"),
            "The catalog table status column should render a compact icon-only status view instead of a text badge.")
        XCTAssertFalse(
            tableSource.contains("case .status:\n            StatusBadge(status: module.status)"),
            "The table status column should not spend horizontal space on status text.")
        XCTAssertTrue(
            badgesSource.contains("struct StatusIcon: View"),
            "The icon-only status view should stay separate from the text badge used in inspector-style surfaces.")
        XCTAssertTrue(
            badgesSource.contains(".help(stagedAction?.title ?? status.title)"),
            "The icon-only status view still needs a tooltip because the visible status text is gone.")
        XCTAssertTrue(
            badgesSource.contains(".accessibilityLabel(stagedAction?.title ?? status.title)"),
            "The icon-only status view still needs an accessibility label because the visible status text is gone.")
    }

    private func catalogTableViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("CatalogTableView.swift")
    }

    private func catalogBadgesSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("CatalogBadges.swift")
    }
}

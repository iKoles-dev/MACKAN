import XCTest

final class CatalogSearchFieldImplementationTests: XCTestCase {
    func testCatalogToolbarSearchFieldHandlesArrowKeysBeforeAppKitFieldEditorCanBeep() throws {
        let toolbarSource = try String(
            contentsOf: catalogToolbarSourceURL(),
            encoding: .utf8)
        let searchFieldSource = try String(
            contentsOf: catalogSearchFieldSourceURL(),
            encoding: .utf8)

        XCTAssertFalse(
            toolbarSource.contains(#"TextField("Search mods", text: $model.searchText)"#),
            "Catalog search must not use SwiftUI TextField because AppKit's field editor can beep on Up/Down.")
        XCTAssertTrue(toolbarSource.contains("CatalogSearchField("))
        XCTAssertTrue(searchFieldSource.contains("override func keyDown(with event: NSEvent)"))
        XCTAssertTrue(searchFieldSource.contains("case 126:"))
        XCTAssertTrue(searchFieldSource.contains("case 125:"))
        XCTAssertFalse(searchFieldSource.contains("case 126:\n                super.keyDown"))
        XCTAssertFalse(searchFieldSource.contains("case 125:\n                super.keyDown"))
    }

    private func catalogToolbarSourceURL() -> URL {
        sourceURL(named: "CatalogToolbarView.swift")
    }

    private func catalogSearchFieldSourceURL() -> URL {
        sourceURL(named: "CatalogSearchField.swift")
    }

    private func sourceURL(named filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent(filename)
    }
}

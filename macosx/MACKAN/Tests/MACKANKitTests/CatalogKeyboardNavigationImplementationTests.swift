import XCTest

final class CatalogKeyboardNavigationImplementationTests: XCTestCase {
    func testCatalogKeyboardNavigationConsumesArrowKeysEvenWhenSearchFieldHasFocus() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertFalse(
            source.contains("!isEditingText(window.firstResponder)"),
            "Up/Down must be consumed by catalog navigation even when the search field is first responder; otherwise AppKit emits the invalid-key sound.")
    }

    func testCatalogKeyboardNavigationDoesNotReemitConsumedArrowKeyEvents() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertFalse(
            source.contains("self?.handle(event) ?? event"),
            "The monitor must not use optional chaining with nil coalescing because handle(event) returns nil to consume Up/Down.")
        XCTAssertTrue(
            source.contains("guard let self else"),
            "The monitor should only fall back to returning the event when the monitor view has already gone away.")
    }

    func testSelectionVisibilityCorrectionOnlyRunsAfterSelectionChanges() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(
            source.contains("@State private var pendingSelectionVisibilityCheckID"),
            "Selection visibility correction must be gated so normal manual scroll does not snap back to the selected row.")
        XCTAssertTrue(
            source.contains("pendingSelectionVisibilityCheckID = selectedModuleID"),
            "Selection changes should arm exactly one visibility correction pass.")
        XCTAssertTrue(
            source.contains("pendingSelectionVisibilityCheckID == selectedModuleID"),
            "Frame updates from manual scrolling must not trigger visibility correction unless a selection change armed it.")
        XCTAssertTrue(
            source.contains("pendingSelectionVisibilityCheckID = nil"),
            "The visibility correction gate must clear after handling a selection change.")
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
}

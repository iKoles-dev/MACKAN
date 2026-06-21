import XCTest

final class CatalogClickOverlayImplementationTests: XCTestCase {
    func testCatalogCellClickOverlayUsesPureSwiftUIGesturesInsteadOfAppKitClickBridge() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertFalse(
            source.contains("CatalogCellClickOverlay: NSViewRepresentable"),
            "Catalog cell clicks must not go through an AppKit click bridge because it can route through native control/responder feedback.")
        XCTAssertFalse(source.contains("override func mouseDown(with event: NSEvent)"))
        XCTAssertTrue(source.contains("CatalogCellTapOverlay"))
        XCTAssertTrue(source.contains("TapGesture(count: 2)"))
        XCTAssertTrue(source.contains(".exclusively(before: TapGesture(count: 1))"))
    }

    func testCatalogDoubleClickIsAWholeRowActionAndDoesNotReplayTwoSingleClicks() throws {
        let source = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(
            source.contains("var recognizesRowDoubleClick: Bool { true }"),
            "Double-click staging should be available from any row cell, including status, pending, and auto-installed cells.")
        XCTAssertTrue(
            source.contains("case .first(_):"),
            "The click overlay should route a recognized double-click through the double-click handler.")
        XCTAssertTrue(
            source.contains("case .second(_):"),
            "The click overlay should route a recognized single-click through the single-click handler.")
        XCTAssertFalse(
            source.contains(".onTapGesture(count: 1, perform: onClick)\n            .onTapGesture(count: 2)"),
            "Stacking independent single and double tap handlers can replay the status click twice during a double-click.")
    }

    func testCatalogDoubleClickStagesThePreferredModuleAction() throws {
        let source = try String(
            contentsOf: catalogViewSourceURL(),
            encoding: .utf8)

        guard let handlerRange = source.range(of: "private func handleModuleDoubleClick(_ module: ModuleSummary)") else {
            return XCTFail("CatalogView should keep a dedicated double-click handler for module rows.")
        }
        let handlerSource = String(source[handlerRange.lowerBound...])
            .components(separatedBy: "\n    private func ")
            .first ?? ""

        XCTAssertTrue(
            handlerSource.contains("model.selectedModuleID = module.identifier"),
            "Double-clicking a row should still select that module before staging its action.")
        XCTAssertTrue(
            handlerSource.contains("model.togglePreferredStagedAction(for: module)"),
            "Double-clicking a row should stage or unstage the same preferred action as clicking the status icon.")
    }

    func testCatalogStatusCellReflectsQueuedModuleAction() throws {
        let tableSource = try String(
            contentsOf: catalogTableViewSourceURL(),
            encoding: .utf8)
        let badgesSource = try String(
            contentsOf: catalogBadgesSourceURL(),
            encoding: .utf8)

        XCTAssertTrue(
            tableSource.contains("StatusIcon(status: module.status, stagedAction: model.stagedAction(for: module.identifier))"),
            "The status column should switch to the queued install/remove/upgrade/replace icon as soon as a module is staged.")
        XCTAssertTrue(
            badgesSource.contains("let stagedAction: StagedModAction?"),
            "StatusIcon needs the staged action in addition to the catalog status.")
        XCTAssertTrue(
            badgesSource.contains("stagedAction?.symbolName ?? status.symbolName"),
            "A queued action should override the passive status glyph.")
        XCTAssertTrue(
            badgesSource.contains("stagedAction?.title ?? status.title"),
            "The status icon tooltip and accessibility label should describe the queued action when one exists.")
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

    private func catalogViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("CatalogViews.swift")
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

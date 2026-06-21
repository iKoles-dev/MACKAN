import XCTest

final class MaintenanceCenterViewImplementationTests: XCTestCase {
    func testMaintenanceRouteKeepsCatalogSidebarButHidesInspector() throws {
        let source = try String(contentsOf: mainWindowViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("let isShowingMaintenanceRoute = model.mainContentRoute.isMaintenance"),
            "The root window should identify maintenance routes before deciding column visibility.")
        XCTAssertTrue(
            source.contains("let showSidebar = geometry.size.width >= CGFloat(MainWindowLayoutPolicy.sidebarVisibilityBreakpoint)"),
            "Maintenance panes should keep the normal catalog sidebar when the window is wide enough.")
        XCTAssertFalse(
            source.contains("let showSidebar = !isShowingMaintenanceRoute"),
            "Maintenance routes should not force-hide the catalog sidebar.")
        XCTAssertTrue(
            source.contains("let showInspector = !isShowingMaintenanceRoute"),
            "The module inspector is unrelated to maintenance pages and should be hidden there.")
    }

    func testMaintenanceHeaderProvidesPanePickerOnlyWhenSidebarIsHidden() throws {
        let mainWindowSource = try String(contentsOf: mainWindowViewSourceURL(), encoding: .utf8)
        let sidebarSource = try String(contentsOf: sidebarViewsSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            mainWindowSource.contains("showsPanePicker: !showSidebar"),
            "The pane picker should be a fallback for narrow layouts where the catalog sidebar is hidden.")
        XCTAssertTrue(
            sidebarSource.contains("if showsPanePicker {"),
            "The maintenance header should not duplicate sidebar navigation when the sidebar is visible.")
        XCTAssertTrue(
            sidebarSource.contains("MaintenancePanePicker("),
            "Hiding the catalog sidebar must not remove direct navigation between maintenance panes.")
        XCTAssertTrue(
            sidebarSource.contains("model.showMaintenancePane(selectedPane)"),
            "The pane picker should route through AppModel so normal cleanup and loading behavior still apply.")
    }

    func testInitialMaintenanceLoadingStateDoesNotRenderEmptySheetChrome() throws {
        let source = try String(contentsOf: sidebarViewsSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("private var shouldShowInitialLoadingState: Bool"),
            "Maintenance panes need an explicit initial-loading branch instead of mounting empty sheet content.")
        XCTAssertTrue(
            source.contains("isLoading && !hasLoadedPaneResult"),
            "The loading placeholder should be used only before the pane has real data to show.")
        XCTAssertTrue(
            source.contains("MaintenancePaneLoadingView(pane: pane"),
            "Initial loading should render a full-pane placeholder, not the sheet header and Close button.")
        XCTAssertTrue(
            source.contains("private var hasLoadedPaneResult: Bool"),
            "The view should decide loading presentation from the currently selected pane's result.")
        XCTAssertFalse(
            source.contains("""
            ZStack {
                paneBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isLoading {
            """),
            "Overlaying the loader on an empty sheet leaves duplicate titles and floating Close buttons visible.")
    }

    func testHistoryPaneLoadsSnapshotSummariesThenSelectedEntryDetails() throws {
        let sidebarSource = try String(contentsOf: sidebarViewsSourceURL(), encoding: .utf8)
        let maintenanceSource = try String(contentsOf: maintenanceSheetsSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            sidebarSource.contains("@State private var isLoadingHistoryEntry = false"),
            "History entry loading should be independent from the quick snapshot list loading state.")
        XCTAssertTrue(
            sidebarSource.contains("loadInstallationHistoryEntry(fileName:"),
            "Selecting a snapshot should fetch only that snapshot's detailed modules.")
        XCTAssertTrue(
            sidebarSource.contains("selectedEntry: model.selectedInstallationHistoryEntry"),
            "The embedded history pane should render the lazily loaded selected entry from AppModel.")
        XCTAssertTrue(
            maintenanceSource.contains("let selectedEntry: InstallationHistoryEntry?"),
            "The history view should separate summary rows from selected-entry details.")
        XCTAssertTrue(
            maintenanceSource.contains("let isLoadingSelectedEntry: Bool"),
            "The module table area should have its own loading state.")
        XCTAssertTrue(
            sidebarSource.contains("showsChrome: false"),
            "The embedded maintenance page should not show modal sheet title/Close chrome.")
    }

    private func sidebarViewsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("SidebarViews.swift")
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

    private func maintenanceSheetsSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent("MaintenanceSheets.swift")
    }
}

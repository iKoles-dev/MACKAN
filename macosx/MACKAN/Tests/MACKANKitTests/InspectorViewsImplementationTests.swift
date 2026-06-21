import XCTest

final class InspectorViewsImplementationTests: XCTestCase {
    func testInspectorHeaderPromotesPrimaryResourceActionsAndCopyIdentifier() throws {
        let source = try inspectorSource()

        XCTAssertTrue(
            source.contains("HeaderQuickActionRow("),
            "The module header should promote primary resource actions so users do not have to open the Links tab for common destinations.")
        XCTAssertTrue(
            source.contains("ModuleHeaderAction.primaryActions"),
            "Header actions should be derived from ModuleDetails.resources rather than hard-coded per module.")
        XCTAssertTrue(
            source.contains("copyModuleIdentifier"),
            "The header should expose a Copy ID action for identifiers that users frequently need outside the app.")
        XCTAssertTrue(
            source.contains("NSPasteboard.general"),
            "Copy ID should use the macOS pasteboard instead of only displaying selectable text.")
    }

    func testOverviewPrioritizesDecisionContentOverRawMetadata() throws {
        let source = try inspectorSource()

        XCTAssertTrue(source.contains("ModuleAtAGlanceCard("))
        XCTAssertTrue(source.contains("ModuleRelationshipSummaryCard("))
        XCTAssertTrue(source.contains("ModuleTechnicalDetailsCard("))
        XCTAssertTrue(
            source.contains("descriptionText") && source.range(of: "ModuleDescriptionCard(") != nil,
            "The overview should put the human description above raw metadata.")
        XCTAssertFalse(
            source.contains("ModuleDetailCard(title: \"Metadata\""),
            "Raw metadata should not be the primary overview block.")
    }

    func testTechnicalDetailsAreCollapsibleAndDatesAreFormatted() throws {
        let source = try inspectorSource()

        XCTAssertTrue(
            source.contains("DisclosureGroup"),
            "Technical metadata should be hidden behind a disclosure so the overview stays scannable.")
        XCTAssertTrue(
            source.contains("ModuleDetailDateFormatter.displayDate"),
            "Release and install dates should be formatted for humans instead of showing raw ISO timestamps.")
        XCTAssertTrue(
            source.contains("(\"Release Date\", formattedDate(details?.releaseDate ?? module.releaseDate))"),
            "The technical detail release date should use the shared human date formatter.")
        XCTAssertTrue(
            source.contains("(\"Install Date\", formattedDate(module.installDate))"),
            "The install date should use the shared human date formatter.")
    }

    func testOverviewTreatsDashPlaceholderVersionsAsMissing() throws {
        let source = try inspectorSource()

        XCTAssertTrue(
            source.contains("cleanVersion(_ value: String)"),
            "The overview should treat CKAN's '-' placeholder as a missing version instead of rendering '- -> latest'.")
        XCTAssertTrue(
            source.contains("let installed = cleanVersion(module.installedVersion)"),
            "Version summary should normalize the installed version placeholder before comparing versions.")
        XCTAssertTrue(
            source.contains("let latest = cleanVersion(module.latestVersion)"),
            "Version summary should normalize the latest version placeholder before comparing versions.")
    }

    func testResourcesTabUsesSharedResourcePresentation() throws {
        let source = try inspectorSource()

        XCTAssertTrue(source.contains("ModuleResourceRow(resource: resource)"))
        XCTAssertTrue(
            source.contains("ModuleHeaderAction.action(for: resource)"),
            "The Links tab and header quick actions should share icon and label mapping.")
        XCTAssertTrue(
            source.contains("\"Bug Tracker\"") && source.contains("\"Repository\"") && source.contains("\"Homepage\""),
            "Common CKAN resource labels should have first-class presentation.")
    }

    private func inspectorSource() throws -> String {
        try [
            "InspectorViews.swift",
            "ModuleDetailHeader.swift",
            "ModuleOverviewPage.swift",
            "ModuleDetailSections.swift",
            "ModuleRelationshipGraphView.swift",
        ]
        .map { try String(contentsOf: inspectorSourceURL($0), encoding: .utf8) }
        .joined(separator: "\n")
    }

    private func inspectorSourceURL(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("MACKAN")
            .appendingPathComponent(filename)
    }
}

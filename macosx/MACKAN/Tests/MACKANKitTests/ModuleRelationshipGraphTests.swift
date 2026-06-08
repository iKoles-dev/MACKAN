import XCTest

@testable import MACKANKit

final class ModuleRelationshipGraphTests: XCTestCase {
    func testBuildsCenterNodesAndEdgesFromModuleRelationships() {
        let module = ModuleSummary(
            identifier: "Scatterer",
            name: "Scatterer",
            author: "blackrack",
            status: .installed,
            installedVersion: "0.0838",
            latestVersion: "0.0878",
            license: "GPL-3.0",
            relationships: [
                ModuleRelationship(kind: "Depends", value: "ModuleManager"),
                ModuleRelationship(kind: "Recommends", value: "EnvironmentalVisualEnhancements"),
                ModuleRelationship(kind: "Conflicts", value: "JNSQ"),
                ModuleRelationship(kind: "Depends", value: "ModuleManager"),
            ],
            versions: [],
            contents: [])

        let graph = ModuleRelationshipGraph(module: module)

        XCTAssertEqual(graph.center.id, "module:Scatterer")
        XCTAssertEqual(graph.center.title, "Scatterer")
        XCTAssertEqual(graph.relatedNodes.map(\.title), [
            "ModuleManager",
            "EnvironmentalVisualEnhancements",
            "JNSQ",
        ])
        XCTAssertEqual(graph.edges.map(\.kind), ["Depends", "Recommends", "Conflicts"])
        XCTAssertEqual(graph.edges.map(\.sourceID), [
            "module:Scatterer",
            "module:Scatterer",
            "module:Scatterer",
        ])
        XCTAssertEqual(graph.edges.map(\.targetID), [
            "relationship:modulemanager",
            "relationship:environmentalvisualenhancements",
            "relationship:jnsq",
        ])
        XCTAssertFalse(graph.isEmpty)
    }

    func testGraphIsEmptyWhenModuleHasNoRelationships() {
        let module = ModuleSummary(
            identifier: "ModuleManager",
            name: "Module Manager",
            author: "sarbian",
            status: .installed,
            installedVersion: "4.2.3",
            latestVersion: "4.2.3",
            license: "CC-BY-SA",
            relationships: [],
            versions: [],
            contents: [])

        let graph = ModuleRelationshipGraph(module: module)

        XCTAssertTrue(graph.relatedNodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
        XCTAssertTrue(graph.isEmpty)
    }
}

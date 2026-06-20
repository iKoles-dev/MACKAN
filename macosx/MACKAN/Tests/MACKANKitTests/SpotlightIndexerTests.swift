import XCTest
@testable import MACKANKit

final class SpotlightIndexerTests: XCTestCase {
    func testInstalledModulesAreSelectedForIndexing() {
        let installed = module(identifier: "InstalledMod", name: "Installed Mod", isInstalled: true)
        let available = module(identifier: "AvailableMod", name: "Available Mod", isInstalled: false)

        let items = SpotlightIndexer.indexableModules([installed, available], instanceID: "inst")

        XCTAssertEqual(items.map(\.identifier), ["inst:InstalledMod"])
        XCTAssertEqual(items.first?.title, "Installed Mod")
        XCTAssertEqual(items.first?.description, "Installed description")
    }

    private func module(identifier: String, name: String, isInstalled: Bool) -> ModuleSummary {
        ModuleSummary(
            identifier: identifier,
            name: name,
            author: "Test Author",
            status: isInstalled ? .installed : .available,
            installedVersion: isInstalled ? "1.0.0" : "",
            latestVersion: "1.0.0",
            license: "MIT",
            relationships: [],
            versions: ["1.0.0"],
            contents: [],
            isInstalled: isInstalled,
            tags: ["utility"],
            abstract: "\(isInstalled ? "Installed" : "Available") description")
    }
}

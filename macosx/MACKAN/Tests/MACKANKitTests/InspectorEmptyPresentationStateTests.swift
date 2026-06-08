import XCTest

@testable import MACKANKit

final class InspectorEmptyPresentationStateTests: XCTestCase {
    func testNoInstanceStatePromptsInstanceSelection() {
        let state = InspectorEmptyPresentationState(
            selectedInstance: nil,
            moduleCount: 0,
            catalogLoadProgress: nil)

        XCTAssertEqual(state.systemImage, "shippingbox")
        XCTAssertEqual(state.title, "No Instance Selected")
        XCTAssertEqual(state.detail, "Add or select a game instance to inspect mods.")
    }

    func testLoadingStateExplainsWhereDetailsWillAppear() {
        let state = InspectorEmptyPresentationState(
            selectedInstance: GameInstanceSummary(
                id: "primary",
                name: "Primary KSP",
                game: "KSP",
                gameVersion: "1.12.5",
                path: "/Games/KSP",
                isDefault: true,
                isValid: true),
            moduleCount: 0,
            catalogLoadProgress: AppModel.CatalogLoadProgress(detail: "Classifying module compatibility"))

        XCTAssertEqual(state.systemImage, "hourglass")
        XCTAssertEqual(state.title, "Catalog Loading")
        XCTAssertEqual(state.detail, "Module details will appear here after the catalog finishes loading.")
    }

    func testLoadedCatalogStatePromptsModuleSelection() {
        let state = InspectorEmptyPresentationState(
            selectedInstance: GameInstanceSummary(
                id: "primary",
                name: "Primary KSP",
                game: "KSP",
                gameVersion: "1.12.5",
                path: "/Games/KSP",
                isDefault: true,
                isValid: true),
            moduleCount: 350,
            catalogLoadProgress: nil)

        XCTAssertEqual(state.systemImage, "shippingbox")
        XCTAssertEqual(state.title, "No Mod Selected")
        XCTAssertEqual(state.detail, "Select a module in the catalog to inspect metadata, relationships, versions, contents, and resources.")
    }
}

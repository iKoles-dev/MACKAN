import XCTest

@testable import MACKANKit

final class ModuleActionPresentationStateTests: XCTestCase {
    func testEmptyStateDisablesActionWithFallbackPresentation() {
        let state = ModuleActionPresentationState.empty

        XCTAssertNil(state.title)
        XCTAssertEqual(state.symbolName, "circle")
        XCTAssertEqual(state.accessibilityLabel, "No Action")
        XCTAssertEqual(state.help, "No module action available")
        XCTAssertFalse(state.usesMenu)
    }

    func testPreferredActionProvidesButtonPresentation() {
        let state = ModuleActionPresentationState(
            preferredAction: .install,
            availableActions: [.install])

        XCTAssertEqual(state.title, "Install")
        XCTAssertEqual(state.symbolName, "plus.circle")
        XCTAssertEqual(state.accessibilityLabel, "Install")
        XCTAssertEqual(state.help, "Install")
        XCTAssertFalse(state.usesMenu)
    }

    func testMultipleAvailableActionsUseMenuWhenNothingIsStaged() {
        let state = ModuleActionPresentationState(
            preferredAction: .replace,
            availableActions: [.replace, .remove])

        XCTAssertEqual(state.title, "Replace")
        XCTAssertEqual(state.symbolName, "arrow.triangle.2.circlepath")
        XCTAssertTrue(state.usesMenu)
    }

    func testStagedActionOverridesPreferredActionAndSuppressesMenu() {
        let state = ModuleActionPresentationState(
            stagedAction: .remove,
            preferredAction: .replace,
            availableActions: [.replace, .remove])

        XCTAssertEqual(state.title, "Unstage")
        XCTAssertEqual(state.symbolName, "xmark.circle")
        XCTAssertEqual(state.accessibilityLabel, "Unstage")
        XCTAssertEqual(state.help, "Unstage")
        XCTAssertFalse(state.usesMenu)
    }
}

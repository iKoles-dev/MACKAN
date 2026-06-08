import XCTest

@testable import MACKANKit

final class CatalogReadinessPresentationStateTests: XCTestCase {
    func testActionSummaryGuidesUserWhenNothingIsStaged() {
        let state = CatalogActionSummaryPresentationState(
            stagedActionCount: 0,
            versionedInstallCount: 0,
            pendingChangeSet: nil,
            changeSetError: nil)

        XCTAssertEqual(state.kind, .idle)
        XCTAssertEqual(state.title, "No changes staged")
        XCTAssertEqual(state.detail, "Select a module, then use Install, Remove, Upgrade, or Replace.")
        XCTAssertFalse(state.canPreview)
        XCTAssertFalse(state.canApply)
    }

    func testActionSummaryCountsStagedChangesAndPromptsPreview() {
        let state = CatalogActionSummaryPresentationState(
            stagedActionCount: 2,
            versionedInstallCount: 1,
            pendingChangeSet: nil,
            changeSetError: nil)

        XCTAssertEqual(state.kind, .needsPreview)
        XCTAssertEqual(state.title, "3 changes staged")
        XCTAssertEqual(state.detail, "Preview changes to resolve dependencies before applying.")
        XCTAssertTrue(state.canPreview)
        XCTAssertFalse(state.canApply)
    }

    func testActionSummaryShowsResolvedPreviewReadyForApply() {
        let state = CatalogActionSummaryPresentationState(
            stagedActionCount: 1,
            versionedInstallCount: 0,
            pendingChangeSet: ChangeSetResult(
                instanceId: "primary",
                changes: [
                    change(identifier: "SelectedMod", action: "install", isAuto: false),
                    change(identifier: "DependencyMod", action: "install", isAuto: true),
                ],
                conflicts: [],
                conflictDescriptions: []),
            changeSetError: nil)

        XCTAssertEqual(state.kind, .readyToApply)
        XCTAssertEqual(state.title, "2 changes ready")
        XCTAssertEqual(state.detail, "Review the resolved change set, then apply.")
        XCTAssertTrue(state.canPreview)
        XCTAssertTrue(state.canApply)
    }

    func testCatalogLoadPresentationReassuresLongInitialLoadsWithoutCount() {
        let state = CatalogLoadPresentationState(
            progress: AppModel.CatalogLoadProgress(detail: "Classifying module compatibility"))

        XCTAssertEqual(state.title, "Loading catalog")
        XCTAssertEqual(state.detail, "Classifying module compatibility")
        XCTAssertEqual(state.secondaryDetail, "Large KSP instances can take a minute. MACKAN is still working.")
        XCTAssertNil(state.fractionCompleted)
    }

    func testCatalogLoadPresentationSummarizesCountedProgress() {
        let state = CatalogLoadPresentationState(
            progress: AppModel.CatalogLoadProgress(
                detail: "Reading registry",
                loadedModuleCount: 100,
                totalModuleCount: 350,
                percent: 40))

        XCTAssertEqual(state.detail, "Preparing 100 of 350 mods")
        XCTAssertEqual(state.secondaryDetail, "Reading registry")
        XCTAssertEqual(state.fractionCompleted, 100.0 / 350.0)
    }

    private func change(
        identifier: String,
        action: String,
        isAuto: Bool
    ) -> ChangeSummary {
        ChangeSummary(
            identifier: identifier,
            name: identifier,
            action: action,
            fromVersion: nil,
            toVersion: "1.0.0",
            reasons: ["Test"],
            isUserRequested: !isAuto,
            isAuto: isAuto)
    }
}

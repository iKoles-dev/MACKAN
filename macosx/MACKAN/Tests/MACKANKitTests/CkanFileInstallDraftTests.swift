import XCTest

@testable import MACKANKit

final class CkanFileInstallDraftTests: XCTestCase {
    func testSelectProviderReplacesSameRequestedDependencyAndSortsSelections() {
        let firstChoice = ProviderChoice(
            requested: "ModuleManager",
            message: "Choose a provider",
            requesterIdentifier: "BRequester",
            requesterName: "B Requester",
            options: [
                ProviderOption(identifier: "OldProvider", name: "Old", version: "1.0", abstract: ""),
                ProviderOption(identifier: "NewProvider", name: "New", version: "2.0", abstract: "")
            ])
        let secondChoice = ProviderChoice(
            requested: "Toolbar",
            message: "Choose a provider",
            requesterIdentifier: "ARequester",
            requesterName: "A Requester",
            options: [
                ProviderOption(identifier: "ToolbarProvider", name: "Toolbar", version: "1.0", abstract: "")
            ])

        var draft = CkanFileInstallDraft()

        draft.selectProvider(choice: firstChoice, option: firstChoice.options[0])
        draft.selectProvider(choice: secondChoice, option: secondChoice.options[0])
        draft.selectProvider(choice: firstChoice, option: firstChoice.options[1])

        XCTAssertEqual(draft.providerSelections.map(\.id), ["ARequester:Toolbar", "BRequester:ModuleManager"])
        XCTAssertEqual(draft.providerSelections.map(\.selectedIdentifier), ["ToolbarProvider", "NewProvider"])
    }

    func testSelectRecommendationDeduplicatesCaseInsensitivelySortsAndClearsSkipFlag() {
        let recommendedVisual = RecommendationChoice(
            kind: "recommended",
            identifier: "VisualPack",
            name: "Visual Pack",
            version: "1.0",
            abstract: "",
            dependents: [],
            isRecommendedDefault: true)
        let recommendedAudio = RecommendationChoice(
            kind: "recommended",
            identifier: "audioPack",
            name: "Audio Pack",
            version: "1.0",
            abstract: "",
            dependents: [],
            isRecommendedDefault: true)
        let duplicateVisual = RecommendationChoice(
            kind: "recommended",
            identifier: "visualpack",
            name: "Visual Pack",
            version: "1.0",
            abstract: "",
            dependents: [],
            isRecommendedDefault: true)

        var draft = CkanFileInstallDraft(skipRecommendations: true)

        draft.selectRecommendation(recommendedVisual)
        draft.selectRecommendation(recommendedAudio)
        draft.selectRecommendation(duplicateVisual)

        XCTAssertEqual(draft.recommendationSelections, ["audioPack", "VisualPack"])
        XCTAssertFalse(draft.skipRecommendations)
    }

    func testSkipAllowAndResetKeepRetryStateExplicit() {
        var draft = CkanFileInstallDraft(
            providerSelections: [
                ProviderSelection(
                    requested: "ModuleManager",
                    requesterIdentifier: "Requester",
                    selectedIdentifier: "Provider")
            ],
            recommendationSelections: ["VisualPack"])

        draft.skipAllRecommendations()
        draft.allowIncompatibleFiles()

        XCTAssertTrue(draft.skipRecommendations)
        XCTAssertTrue(draft.allowIncompatibleCkanFiles)

        draft.reset()

        XCTAssertTrue(draft.providerSelections.isEmpty)
        XCTAssertTrue(draft.recommendationSelections.isEmpty)
        XCTAssertFalse(draft.skipRecommendations)
        XCTAssertFalse(draft.allowIncompatibleCkanFiles)
    }
}

public struct CkanFileInstallDraft: Equatable, Sendable {
    public private(set) var providerSelections: [ProviderSelection]
    public private(set) var recommendationSelections: [String]
    public private(set) var skipRecommendations: Bool
    public private(set) var allowIncompatibleCkanFiles: Bool

    public init(
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false
    ) {
        self.providerSelections = providerSelections.sortedByStableID()
        self.recommendationSelections = recommendationSelections.sortedCaseInsensitively()
        self.skipRecommendations = skipRecommendations
        self.allowIncompatibleCkanFiles = allowIncompatibleCkanFiles
    }

    public mutating func selectProvider(choice: ProviderChoice, option: ProviderOption) {
        let selection = ProviderSelection(
            requested: choice.requested,
            requesterIdentifier: choice.requesterIdentifier,
            selectedIdentifier: option.identifier)
        providerSelections.removeAll { $0.id == selection.id }
        providerSelections.append(selection)
        providerSelections = providerSelections.sortedByStableID()
    }

    public mutating func selectRecommendation(_ choice: RecommendationChoice) {
        if !recommendationSelections.containsCaseInsensitive(choice.identifier) {
            recommendationSelections.append(choice.identifier)
            recommendationSelections = recommendationSelections.sortedCaseInsensitively()
        }
        skipRecommendations = false
    }

    public mutating func skipAllRecommendations() {
        skipRecommendations = true
    }

    public mutating func allowIncompatibleFiles() {
        allowIncompatibleCkanFiles = true
    }

    public mutating func reset() {
        providerSelections = []
        recommendationSelections = []
        skipRecommendations = false
        allowIncompatibleCkanFiles = false
    }
}

private extension Array where Element == ProviderSelection {
    func sortedByStableID() -> [ProviderSelection] {
        sorted {
            $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }
    }
}

private extension Array where Element == String {
    func sortedCaseInsensitively() -> [String] {
        sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func containsCaseInsensitive(_ value: String) -> Bool {
        contains {
            $0.caseInsensitiveCompare(value) == .orderedSame
        }
    }
}

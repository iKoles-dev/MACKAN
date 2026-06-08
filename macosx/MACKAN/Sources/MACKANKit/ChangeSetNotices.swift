public struct ChangeSetConflictNotice: Equatable, Sendable {
    public let title: String
    public let message: String
    public let conflicts: [ConflictSummary]
    public let descriptions: [String]
    public let blocksApply: Bool

    public init(conflicts: [ConflictSummary], descriptions: [String]) {
        self.title = "Resolve conflicts before applying"
        self.message = "CKAN Core reported conflicts in this change set. Remove or change the selected mods, then preview again."
        self.conflicts = conflicts
        self.descriptions = descriptions
        self.blocksApply = true
    }
}

public struct DependencyChoiceNotice: Equatable, Sendable {
    public let title: String
    public let message: String
    public let choices: [ProviderChoice]
    public let blocksApply: Bool

    public init(choices: [ProviderChoice]) {
        self.title = "Choose dependency providers"
        self.message = "CKAN Core found multiple mods that can satisfy the same dependency. Select one provider for each dependency, then preview again."
        self.choices = choices
        self.blocksApply = !choices.isEmpty
    }
}

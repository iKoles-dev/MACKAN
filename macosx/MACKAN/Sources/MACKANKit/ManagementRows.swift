public struct InstanceManagementRow: Identifiable, Equatable, Sendable {
    public let instance: GameInstanceSummary
    public let isSelected: Bool
    public let canSetDefault: Bool
    public let canReveal: Bool
    public let canRename: Bool
    public let canForget: Bool

    public var id: GameInstanceSummary.ID { instance.id }
    public var name: String { instance.name }
    public var game: String { instance.game }
    public var gameVersion: String { instance.gameVersion }
    public var path: String { instance.path }
    public var isDefault: Bool { instance.isDefault }
    public var isValid: Bool { instance.isValid }
}

public struct RepositoryManagementRow: Identifiable, Equatable, Sendable {
    public let repository: RepositorySummary
    public let canMoveUp: Bool
    public let canMoveDown: Bool
    public let canRemove: Bool

    public var id: RepositorySummary.ID { repository.id }
    public var name: String { repository.name }
    public var url: String { repository.url }
    public var priority: Int { repository.priority }
    public var isMirror: Bool { repository.isMirror }
    public var comment: String { repository.comment }
}

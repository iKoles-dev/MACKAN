public struct ModuleActionPresentationState: Equatable, Sendable {
    public let stagedAction: StagedModAction?
    public let preferredAction: StagedModAction?
    public let availableActions: [StagedModAction]

    public init(
        stagedAction: StagedModAction? = nil,
        preferredAction: StagedModAction? = nil,
        availableActions: [StagedModAction] = []
    ) {
        self.stagedAction = stagedAction
        self.preferredAction = preferredAction
        self.availableActions = availableActions
    }

    public static let empty = ModuleActionPresentationState()

    public var title: String? {
        if stagedAction != nil {
            return "Unstage"
        }
        return preferredAction?.title
    }

    public var symbolName: String {
        if stagedAction != nil {
            return "xmark.circle"
        }
        return preferredAction?.symbolName ?? "circle"
    }

    public var accessibilityLabel: String {
        title ?? "No Action"
    }

    public var help: String {
        title ?? "No module action available"
    }

    public var usesMenu: Bool {
        availableActions.count > 1 && title != "Unstage"
    }
}

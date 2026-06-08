public enum StagedModAction: String, Equatable, Sendable {
    case install
    case remove
    case upgrade
    case replace

    public var title: String {
        switch self {
        case .install:
            return "Install"
        case .remove:
            return "Remove"
        case .upgrade:
            return "Upgrade"
        case .replace:
            return "Replace"
        }
    }

    public var symbolName: String {
        switch self {
        case .install:
            return "plus.circle"
        case .remove:
            return "minus.circle"
        case .upgrade:
            return "arrow.up.circle"
        case .replace:
            return "arrow.triangle.2.circlepath"
        }
    }
}

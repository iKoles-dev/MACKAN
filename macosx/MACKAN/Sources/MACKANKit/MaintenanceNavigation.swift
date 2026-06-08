public enum MaintenancePane: String, CaseIterable, Identifiable, Equatable, Sendable {
    case history
    case unmanagedFiles
    case playTime
    case downloadStatistics
    case cache

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .history:
            return "History"
        case .unmanagedFiles:
            return "Unmanaged Files"
        case .playTime:
            return "Play Time"
        case .downloadStatistics:
            return "Download Statistics"
        case .cache:
            return "Cache"
        }
    }

    public var symbolName: String {
        switch self {
        case .history:
            return "clock.arrow.circlepath"
        case .unmanagedFiles:
            return "folder.badge.questionmark"
        case .playTime:
            return "timer"
        case .downloadStatistics:
            return "chart.pie"
        case .cache:
            return "archivebox"
        }
    }

    public var showsSelectedInstanceSubtitle: Bool {
        switch self {
        case .history, .unmanagedFiles, .downloadStatistics:
            return true
        case .playTime, .cache:
            return false
        }
    }
}

public enum MainContentRoute: Equatable, Sendable {
    case catalog
    case maintenance(MaintenancePane)
}

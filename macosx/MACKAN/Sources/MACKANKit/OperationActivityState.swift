public enum OperationActivity: Hashable, Sendable {
    case resolvingChanges
    case applyingChanges
    case installingCkanFiles
    case importingDownloadFiles
    case refreshingRepositories
    case refreshingOperationStatus
    case cancellingOperation
    case removingRegistryLock
}

public struct OperationActivityState: Equatable, Sendable {
    public private(set) var activeActivities: Set<OperationActivity>

    public init(activeActivities: Set<OperationActivity> = []) {
        self.activeActivities = activeActivities
    }

    public var isIdle: Bool {
        activeActivities.isEmpty
    }

    public func isActive(_ activity: OperationActivity) -> Bool {
        activeActivities.contains(activity)
    }

    public mutating func start(_ activity: OperationActivity) {
        activeActivities.insert(activity)
    }

    @discardableResult
    public mutating func finish(_ activity: OperationActivity) -> Bool {
        activeActivities.remove(activity) != nil
    }

    public mutating func clear() {
        activeActivities.removeAll()
    }
}

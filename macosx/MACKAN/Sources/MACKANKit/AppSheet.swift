import Foundation

public enum AppSheet: Identifiable, Hashable, Sendable {
    case about
    case addInstance
    case cloneInstance
    case editLaunchCommandLines
    case exportModpack
    case fakeInstance
    case manageInstances
    case updateCheck

    public var id: Self { self }
}

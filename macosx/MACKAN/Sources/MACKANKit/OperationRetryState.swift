public enum OperationRetryAction: Equatable, Sendable {
    case applyChanges(skipDownloadFailures: Bool)
    case installCkanFiles(skipDownloadFailures: Bool)
    case importDownloads(skipDownloadFailures: Bool)
}

public struct OperationRetryState: Equatable, Sendable {
    public private(set) var source: OperationRetrySource

    public init(source: OperationRetrySource = .none) {
        self.source = source
    }

    public mutating func record(_ source: OperationRetrySource) {
        self.source = source
    }

    public func action(skipDownloadFailures: Bool = false) -> OperationRetryAction {
        switch source {
        case .applyChanges:
            return .applyChanges(skipDownloadFailures: skipDownloadFailures)
        case .ckanFiles:
            return .installCkanFiles(skipDownloadFailures: skipDownloadFailures)
        case .importDownloads:
            return .importDownloads(skipDownloadFailures: skipDownloadFailures)
        case .none:
            return .applyChanges(skipDownloadFailures: false)
        }
    }
}

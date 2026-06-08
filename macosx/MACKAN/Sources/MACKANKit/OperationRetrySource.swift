public enum OperationRetrySource: Equatable, Sendable {
    case none
    case applyChanges
    case ckanFiles
    case importDownloads
}

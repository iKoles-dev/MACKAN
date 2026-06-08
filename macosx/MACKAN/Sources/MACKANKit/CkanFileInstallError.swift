import Foundation

public enum CkanFileInstallError: Error, LocalizedError, Equatable {
    case noFiles

    public var errorDescription: String? {
        switch self {
        case .noFiles:
            return "Select at least one .ckan file."
        }
    }
}

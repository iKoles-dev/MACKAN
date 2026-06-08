import Foundation

#if canImport(AppKit)
import AppKit
#endif

@MainActor
public protocol InstanceDirectoryOpening {
    func revealDirectory(at url: URL) throws
}

public enum InstanceDirectoryOpenError: LocalizedError, Equatable {
    case missingInstance
    case emptyPath
    case missingFilePath

    public var errorDescription: String? {
        switch self {
        case .missingInstance:
            return "No game instance is selected."
        case .emptyPath:
            return "The selected game instance does not have a folder path."
        case .missingFilePath:
            return "The selected file does not have a path."
        }
    }
}

public struct WorkspaceInstanceDirectoryOpener: InstanceDirectoryOpening {
    public init() {}

    public func revealDirectory(at url: URL) throws {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}

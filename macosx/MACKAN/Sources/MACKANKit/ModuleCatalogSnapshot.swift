import Foundation

public struct ModuleCatalogSnapshot: Codable, Equatable, Sendable {
    public let instanceId: String
    public let modules: [ModuleSummary]
    public let moduleLabels: [ModuleLabelSummary]
    public let manageableModuleLabels: [ModuleLabelSummary]
    public let repositories: [RepositorySummary]
    public let launchCommands: [String]
    public let defaultLaunchCommands: [String]
    public let incompatibleLaunchModules: [LaunchWarningModule]
    public let savedAt: Date

    public init(
        instanceId: String,
        modules: [ModuleSummary],
        moduleLabels: [ModuleLabelSummary],
        manageableModuleLabels: [ModuleLabelSummary],
        repositories: [RepositorySummary],
        launchCommands: [String],
        defaultLaunchCommands: [String],
        incompatibleLaunchModules: [LaunchWarningModule],
        savedAt: Date
    ) {
        self.instanceId = instanceId
        self.modules = modules
        self.moduleLabels = moduleLabels
        self.manageableModuleLabels = manageableModuleLabels
        self.repositories = repositories
        self.launchCommands = launchCommands
        self.defaultLaunchCommands = defaultLaunchCommands
        self.incompatibleLaunchModules = incompatibleLaunchModules
        self.savedAt = savedAt
    }
}

public protocol ModuleCatalogSnapshotStoring {
    func loadSnapshot(for instanceID: String) -> ModuleCatalogSnapshot?
    func saveSnapshot(_ snapshot: ModuleCatalogSnapshot)
}

public final class DisabledModuleCatalogSnapshotStore: ModuleCatalogSnapshotStoring {
    public init() {}

    public func loadSnapshot(for instanceID: String) -> ModuleCatalogSnapshot? {
        nil
    }

    public func saveSnapshot(_ snapshot: ModuleCatalogSnapshot) {}
}

public final class FileModuleCatalogSnapshotStore: ModuleCatalogSnapshotStoring {
    private let directory: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory ?? Self.defaultDirectory(fileManager: fileManager)
    }

    public func loadSnapshot(for instanceID: String) -> ModuleCatalogSnapshot? {
        let url = snapshotURL(for: instanceID)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(ModuleCatalogSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: ModuleCatalogSnapshot) {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL(for: snapshot.instanceId), options: .atomic)
        } catch {
            // Catalog snapshots are an acceleration cache. Failure must not affect app behavior.
        }
    }

    private func snapshotURL(for instanceID: String) -> URL {
        directory.appendingPathComponent(Self.fileName(for: instanceID), isDirectory: false)
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("MACKAN", isDirectory: true)
            .appendingPathComponent("CatalogSnapshots", isDirectory: true)
    }

    private static func fileName(for instanceID: String) -> String {
        let hex = instanceID.utf8.map { String(format: "%02x", $0) }.joined()
        return "\(hex).json"
    }
}

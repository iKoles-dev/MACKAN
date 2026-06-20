import Foundation

public enum ModuleTableColumn: String, CaseIterable, Codable, Identifiable, Sendable {
    case status
    case pending
    case autoInstalled
    case name
    case identifier
    case installedVersion
    case latestVersion
    case author
    case gameCompatibility
    case downloadSize
    case installSize
    case releaseDate
    case installDate
    case downloadCount
    case license
    case tags
    case description

    public static let defaultVisible: [ModuleTableColumn] = [
        .status,
        .pending,
        .name,
        .installedVersion,
        .latestVersion,
        .author,
    ]

    public static func normalized(_ columns: [ModuleTableColumn]) -> [ModuleTableColumn] {
        let unique = Set(columns)
        guard !unique.isEmpty else {
            return defaultVisible
        }
        return allCases.filter(unique.contains)
    }

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .status:
            return "Status"
        case .pending:
            return "Pending"
        case .autoInstalled:
            return "Auto"
        case .name:
            return "Name"
        case .identifier:
            return "Identifier"
        case .installedVersion:
            return "Installed"
        case .latestVersion:
            return "Latest"
        case .author:
            return "Author"
        case .gameCompatibility:
            return "Compatibility"
        case .downloadSize:
            return "Download Size"
        case .installSize:
            return "Install Size"
        case .releaseDate:
            return "Release Date"
        case .installDate:
            return "Install Date"
        case .downloadCount:
            return "Downloads"
        case .license:
            return "License"
        case .tags:
            return "Tags"
        case .description:
            return "Description"
        }
    }

    public var sort: ModuleSort? {
        switch self {
        case .status:
            return .status
        case .name:
            return .name
        case .identifier:
            return .identifier
        case .installedVersion:
            return .installedVersion
        case .latestVersion:
            return .latestVersion
        case .author:
            return .author
        case .gameCompatibility:
            return .gameCompatibility
        case .downloadSize:
            return .downloadSize
        case .installSize:
            return .installSize
        case .releaseDate:
            return .releaseDate
        case .installDate:
            return .installDate
        case .downloadCount:
            return .downloadCount
        case .pending, .autoInstalled, .license, .tags, .description:
            return nil
        }
    }
}

public protocol ModuleTableColumnStoring {
    func loadVisibleModuleColumns() -> [ModuleTableColumn]
    func saveVisibleModuleColumns(_ columns: [ModuleTableColumn])
}

public final class UserDefaultsModuleTableColumnStore: ModuleTableColumnStoring {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "mackan.visibleModuleColumns"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadVisibleModuleColumns() -> [ModuleTableColumn] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([ModuleTableColumn].self, from: data)) ?? []
    }

    public func saveVisibleModuleColumns(_ columns: [ModuleTableColumn]) {
        guard let data = try? JSONEncoder().encode(columns) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

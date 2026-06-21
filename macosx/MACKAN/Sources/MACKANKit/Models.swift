import Foundation

public enum ModuleFilter: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case compatible
    case incompatible
    case installed
    case notInstalled
    case upgradable
    case available
    case cached
    case uncached
    case new
    case replaceable

    public var id: String { rawValue }

    public static let builtInSavedSearches: [ModuleFilter] = [
        .available,
        .upgradable,
        .installed,
        .cached,
        .incompatible,
    ]

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .compatible:
            return "Compatible"
        case .incompatible:
            return "Incompatible"
        case .installed:
            return "Installed"
        case .notInstalled:
            return "Not Installed"
        case .upgradable:
            return "Upgradable"
        case .available:
            return "Available"
        case .cached:
            return "Cached"
        case .uncached:
            return "Uncached"
        case .new:
            return "New"
        case .replaceable:
            return "Replaceable"
        }
    }

    public var builtInSavedSearchSystemImage: String {
        switch self {
        case .available:
            return "circle"
        case .upgradable:
            return "arrow.up.circle"
        case .installed:
            return "checkmark.circle"
        case .cached:
            return "externaldrive"
        case .incompatible:
            return "exclamationmark.triangle"
        default:
            return "line.3.horizontal.decrease.circle"
        }
    }

    public func includes(_ module: ModuleSummary) -> Bool {
        switch self {
        case .all:
            return true
        case .compatible:
            return module.isCompatible
        case .incompatible:
            return !module.isCompatible
        case .installed:
            return module.isInstalled
        case .notInstalled:
            return !module.isInstalled
        case .upgradable:
            return module.hasUpdate
        case .available:
            return !module.isInstalled && module.isCompatible
        case .cached:
            return module.isCached
        case .uncached:
            return !module.isCached
        case .new:
            return module.isNew
        case .replaceable:
            return module.isInstalled && module.hasReplacement
        }
    }
}

public enum ModuleSort: String, CaseIterable, Codable, Identifiable, Sendable {
    case name
    case identifier
    case status
    case installedVersion
    case latestVersion
    case author
    case gameCompatibility
    case downloadSize
    case installSize
    case releaseDate
    case installDate
    case downloadCount

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .name:
            return "Name"
        case .identifier:
            return "Identifier"
        case .status:
            return "Status"
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
        }
    }
}

public enum ModuleStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case installed
    case upgradable
    case available
    case incompatible
    case cached

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .installed:
            return "Installed"
        case .upgradable:
            return "Upgrade"
        case .available:
            return "Available"
        case .incompatible:
            return "Blocked"
        case .cached:
            return "Cached"
        }
    }

    public var symbolName: String {
        switch self {
        case .installed:
            return "checkmark.circle.fill"
        case .upgradable:
            return "arrow.up.circle.fill"
        case .available:
            return "circle"
        case .incompatible:
            return "exclamationmark.triangle.fill"
        case .cached:
            return "externaldrive.fill"
        }
    }
}

public struct GameInstanceSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let game: String
    public let gameVersion: String
    public let path: String
    public let isDefault: Bool
    public let isValid: Bool
    public let isMaybeLocked: Bool

    public init(
        id: String? = nil,
        name: String,
        game: String,
        gameVersion: String,
        path: String,
        isDefault: Bool,
        isValid: Bool = true,
        isMaybeLocked: Bool = false
    ) {
        self.id = id ?? name
        self.name = name
        self.game = game
        self.gameVersion = gameVersion
        self.path = path
        self.isDefault = isDefault
        self.isValid = isValid
        self.isMaybeLocked = isMaybeLocked
    }
}

public struct ModuleRelationship: Codable, Equatable, Sendable {
    public let kind: String
    public let value: String

    public init(kind: String, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct ModuleSummary: Identifiable, Codable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let author: String
    public let status: ModuleStatus
    public let installedVersion: String
    public let latestVersion: String
    public let license: String
    public let relationships: [ModuleRelationship]
    public let versions: [String]
    public let contents: [String]
    public let isInstalled: Bool
    public let isCompatible: Bool
    public let isCached: Bool
    public let isNew: Bool
    public let hasUpdate: Bool
    public let hasReplacement: Bool
    public let tags: [String]
    public let abstract: String
    public let description: String
    public let localizations: [String]
    public let gameCompatibility: String
    public let downloadSize: Int64
    public let downloadSizeDisplay: String
    public let installSize: Int64
    public let installSizeDisplay: String
    public let releaseDate: String
    public let installDate: String
    public let downloadCount: Int?
    public let isAutoInstalled: Bool
    public let isAutodetected: Bool

    public var id: String { identifier }

    public init(
        identifier: String,
        name: String,
        author: String,
        status: ModuleStatus,
        installedVersion: String,
        latestVersion: String,
        license: String,
        relationships: [ModuleRelationship],
        versions: [String],
        contents: [String],
        isInstalled: Bool? = nil,
        isCompatible: Bool? = nil,
        isCached: Bool? = nil,
        isNew: Bool = false,
        hasUpdate: Bool? = nil,
        hasReplacement: Bool = false,
        tags: [String] = [],
        abstract: String = "",
        description: String = "",
        localizations: [String] = [],
        gameCompatibility: String = "",
        downloadSize: Int64 = 0,
        downloadSizeDisplay: String = "",
        installSize: Int64 = 0,
        installSizeDisplay: String = "",
        releaseDate: String = "",
        installDate: String = "",
        downloadCount: Int? = nil,
        isAutoInstalled: Bool = false,
        isAutodetected: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.author = author
        self.status = status
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.license = license
        self.relationships = relationships
        self.versions = versions
        self.contents = contents
        self.isInstalled = isInstalled ?? Self.defaultIsInstalled(for: status)
        self.isCompatible = isCompatible ?? Self.defaultIsCompatible(for: status)
        self.isCached = isCached ?? (status == .cached)
        self.isNew = isNew
        self.hasUpdate = hasUpdate ?? (status == .upgradable)
        self.hasReplacement = hasReplacement
        self.tags = tags
        self.abstract = abstract
        self.description = description
        self.localizations = localizations
        self.gameCompatibility = gameCompatibility
        self.downloadSize = downloadSize
        self.downloadSizeDisplay = downloadSizeDisplay
        self.installSize = installSize
        self.installSizeDisplay = installSizeDisplay
        self.releaseDate = releaseDate
        self.installDate = installDate
        self.downloadCount = downloadCount
        self.isAutoInstalled = isAutoInstalled
        self.isAutodetected = isAutodetected
    }

    public func withIsNew(_ value: Bool) -> ModuleSummary {
        ModuleSummary(
            identifier: identifier,
            name: name,
            author: author,
            status: status,
            installedVersion: installedVersion,
            latestVersion: latestVersion,
            license: license,
            relationships: relationships,
            versions: versions,
            contents: contents,
            isInstalled: isInstalled,
            isCompatible: isCompatible,
            isCached: isCached,
            isNew: value,
            hasUpdate: hasUpdate,
            hasReplacement: hasReplacement,
            tags: tags,
            abstract: abstract,
            description: description,
            localizations: localizations,
            gameCompatibility: gameCompatibility,
            downloadSize: downloadSize,
            downloadSizeDisplay: downloadSizeDisplay,
            installSize: installSize,
            installSizeDisplay: installSizeDisplay,
            releaseDate: releaseDate,
            installDate: installDate,
            downloadCount: downloadCount,
            isAutoInstalled: isAutoInstalled,
            isAutodetected: isAutodetected)
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case author
        case status
        case installedVersion
        case latestVersion
        case license
        case relationships
        case versions
        case contents
        case isInstalled
        case isCompatible
        case isCached
        case isNew
        case hasUpdate
        case hasReplacement
        case tags
        case abstract
        case description
        case localizations
        case gameCompatibility
        case downloadSize
        case downloadSizeDisplay
        case installSize
        case installSizeDisplay
        case releaseDate
        case installDate
        case downloadCount
        case isAutoInstalled
        case isAutodetected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(ModuleStatus.self, forKey: .status)
        self.init(
            identifier: try container.decode(String.self, forKey: .identifier),
            name: try container.decode(String.self, forKey: .name),
            author: try container.decode(String.self, forKey: .author),
            status: status,
            installedVersion: try container.decode(String.self, forKey: .installedVersion),
            latestVersion: try container.decode(String.self, forKey: .latestVersion),
            license: try container.decode(String.self, forKey: .license),
            relationships: try container.decode([ModuleRelationship].self, forKey: .relationships),
            versions: try container.decode([String].self, forKey: .versions),
            contents: try container.decode([String].self, forKey: .contents),
            isInstalled: try container.decodeIfPresent(Bool.self, forKey: .isInstalled),
            isCompatible: try container.decodeIfPresent(Bool.self, forKey: .isCompatible),
            isCached: try container.decodeIfPresent(Bool.self, forKey: .isCached),
            isNew: try container.decodeIfPresent(Bool.self, forKey: .isNew) ?? false,
            hasUpdate: try container.decodeIfPresent(Bool.self, forKey: .hasUpdate),
            hasReplacement: try container.decodeIfPresent(Bool.self, forKey: .hasReplacement) ?? false,
            tags: try container.decodeIfPresent([String].self, forKey: .tags) ?? [],
            abstract: try container.decodeIfPresent(String.self, forKey: .abstract) ?? "",
            description: try container.decodeIfPresent(String.self, forKey: .description) ?? "",
            localizations: try container.decodeIfPresent([String].self, forKey: .localizations) ?? [],
            gameCompatibility: try container.decodeIfPresent(String.self, forKey: .gameCompatibility) ?? "",
            downloadSize: try container.decodeIfPresent(Int64.self, forKey: .downloadSize) ?? 0,
            downloadSizeDisplay: try container.decodeIfPresent(String.self, forKey: .downloadSizeDisplay) ?? "",
            installSize: try container.decodeIfPresent(Int64.self, forKey: .installSize) ?? 0,
            installSizeDisplay: try container.decodeIfPresent(String.self, forKey: .installSizeDisplay) ?? "",
            releaseDate: try container.decodeIfPresent(String.self, forKey: .releaseDate) ?? "",
            installDate: try container.decodeIfPresent(String.self, forKey: .installDate) ?? "",
            downloadCount: try container.decodeIfPresent(Int.self, forKey: .downloadCount),
            isAutoInstalled: try container.decodeIfPresent(Bool.self, forKey: .isAutoInstalled) ?? false,
            isAutodetected: try container.decodeIfPresent(Bool.self, forKey: .isAutodetected) ?? false)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(status, forKey: .status)
        try container.encode(installedVersion, forKey: .installedVersion)
        try container.encode(latestVersion, forKey: .latestVersion)
        try container.encode(license, forKey: .license)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(versions, forKey: .versions)
        try container.encode(contents, forKey: .contents)
        try container.encode(isInstalled, forKey: .isInstalled)
        try container.encode(isCompatible, forKey: .isCompatible)
        try container.encode(isCached, forKey: .isCached)
        try container.encode(isNew, forKey: .isNew)
        try container.encode(hasUpdate, forKey: .hasUpdate)
        try container.encode(hasReplacement, forKey: .hasReplacement)
        try container.encode(tags, forKey: .tags)
        try container.encode(abstract, forKey: .abstract)
        try container.encode(description, forKey: .description)
        try container.encode(localizations, forKey: .localizations)
        try container.encode(gameCompatibility, forKey: .gameCompatibility)
        try container.encode(downloadSize, forKey: .downloadSize)
        try container.encode(downloadSizeDisplay, forKey: .downloadSizeDisplay)
        try container.encode(installSize, forKey: .installSize)
        try container.encode(installSizeDisplay, forKey: .installSizeDisplay)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encode(installDate, forKey: .installDate)
        try container.encode(downloadCount, forKey: .downloadCount)
        try container.encode(isAutoInstalled, forKey: .isAutoInstalled)
        try container.encode(isAutodetected, forKey: .isAutodetected)
    }

    private static func defaultIsInstalled(for status: ModuleStatus) -> Bool {
        switch status {
        case .installed, .upgradable:
            return true
        case .available, .incompatible, .cached:
            return false
        }
    }

    private static func defaultIsCompatible(for status: ModuleStatus) -> Bool {
        status != .incompatible
    }
}

public struct ModuleResource: Codable, Equatable, Sendable {
    public let label: String
    public let url: String

    public init(label: String, url: String) {
        self.label = label
        self.url = url
    }
}

public struct ModuleDetails: Codable, Equatable, Sendable {
    public let instanceId: String?
    public let module: ModuleSummary
    public let abstract: String
    public let description: String
    public let releaseStatus: String
    public let kind: String
    public let releaseDate: String
    public let downloadSize: Int64
    public let installSize: Int64
    public let resources: [ModuleResource]
    public let tags: [String]

    public init(
        instanceId: String?,
        module: ModuleSummary,
        abstract: String,
        description: String,
        releaseStatus: String,
        kind: String,
        releaseDate: String,
        downloadSize: Int64,
        installSize: Int64,
        resources: [ModuleResource],
        tags: [String]
    ) {
        self.instanceId = instanceId
        self.module = module
        self.abstract = abstract
        self.description = description
        self.releaseStatus = releaseStatus
        self.kind = kind
        self.releaseDate = releaseDate
        self.downloadSize = downloadSize
        self.installSize = installSize
        self.resources = resources
        self.tags = tags
    }
}

public struct RepositorySummary: Identifiable, Codable, Equatable, Sendable {
    public let name: String
    public let url: String
    public let priority: Int
    public let isMirror: Bool
    public let comment: String

    public var id: String { name }

    public init(
        name: String,
        url: String,
        priority: Int,
        isMirror: Bool,
        comment: String
    ) {
        self.name = name
        self.url = url
        self.priority = priority
        self.isMirror = isMirror
        self.comment = comment
    }
}

public enum SampleData {
    public static let instances = [
        GameInstanceSummary(
            name: "Kerbal Space Program",
            game: "KSP",
            gameVersion: "1.12.5",
            path: "~/Library/Application Support/Steam/steamapps/common/Kerbal Space Program",
            isDefault: true
        ),
        GameInstanceSummary(
            name: "KSP2 Test",
            game: "KSP2",
            gameVersion: "0.2.2",
            path: "~/Games/KSP2 Test",
            isDefault: false
        ),
    ]

    public static let modules = [
        ModuleSummary(
            identifier: "ModuleManager",
            name: "Module Manager",
            author: "sarbian",
            status: .installed,
            installedVersion: "4.2.3",
            latestVersion: "4.2.3",
            license: "CC-BY-SA",
            relationships: [
                ModuleRelationship(kind: "Depends", value: "Kerbal Space Program"),
            ],
            versions: ["4.2.3", "4.2.2", "4.2.1"],
            contents: ["GameData/ModuleManager.4.2.3.dll"]
        ),
        ModuleSummary(
            identifier: "Scatterer",
            name: "Scatterer",
            author: "blackrack",
            status: .upgradable,
            installedVersion: "0.0838",
            latestVersion: "0.0878",
            license: "GPL-3.0",
            relationships: [
                ModuleRelationship(kind: "Recommends", value: "EnvironmentalVisualEnhancements"),
            ],
            versions: ["0.0878", "0.0838", "0.0772"],
            contents: ["GameData/scatterer"]
        ),
        ModuleSummary(
            identifier: "KerbalEngineerRedux",
            name: "Kerbal Engineer Redux",
            author: "CYBUTEK",
            status: .available,
            installedVersion: "-",
            latestVersion: "1.1.9.5",
            license: "GPL-3.0",
            relationships: [],
            versions: ["1.1.9.5", "1.1.9.0"],
            contents: ["GameData/KerbalEngineer"]
        ),
        ModuleSummary(
            identifier: "OldPlanetPack",
            name: "Old Planet Pack",
            author: "Example Author",
            status: .incompatible,
            installedVersion: "-",
            latestVersion: "0.9.0",
            license: "MIT",
            relationships: [
                ModuleRelationship(kind: "Conflicts", value: "KSP 1.12.5"),
            ],
            versions: ["0.9.0"],
            contents: ["GameData/OldPlanetPack"]
        ),
    ]
}

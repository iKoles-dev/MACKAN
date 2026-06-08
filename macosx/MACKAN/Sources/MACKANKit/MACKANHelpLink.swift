import Foundation

public struct GameHelpProfile: Equatable, Sendable {
    public let gameID: String
    public let displayName: String
    public let discordURL: URL
    public let modSupportURL: URL
    public let metadataBugtrackerURL: URL
    public let metadataIssueURL: URL

    public init?(gameID: String?) {
        guard let gameID else {
            return nil
        }

        switch gameID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "KSP":
            self = .ksp
        case "KSP2":
            self = .ksp2
        default:
            return nil
        }
    }

    public static let ksp = GameHelpProfile(
        gameID: "KSP",
        displayName: "KSP",
        discordURL: URL(string: "https://discord.gg/65hp7G7")!,
        modSupportURL: URL(string: "https://forum.kerbalspaceprogram.com/forum/70-ksp1-technical-support-pc-modded-installs/")!,
        metadataBugtrackerURL: URL(string: "https://github.com/KSP-CKAN/NetKAN/issues/new/choose")!,
        metadataIssueURL: URL(string: "https://github.com/KSP-CKAN/NetKAN/issues/new")!)

    public static let ksp2 = GameHelpProfile(
        gameID: "KSP2",
        displayName: "KSP2",
        discordURL: URL(string: "https://discord.gg/ZbMp7RjVhU")!,
        modSupportURL: URL(string: "https://forum.kerbalspaceprogram.com/forum/137-ksp2-technical-support-pc-modded-installs/")!,
        metadataBugtrackerURL: URL(string: "https://github.com/KSP-CKAN/KSP2-NetKAN/issues/new/choose")!,
        metadataIssueURL: URL(string: "https://github.com/KSP-CKAN/KSP2-NetKAN/issues/new")!)

    private init(
        gameID: String,
        displayName: String,
        discordURL: URL,
        modSupportURL: URL,
        metadataBugtrackerURL: URL,
        metadataIssueURL: URL
    ) {
        self.gameID = gameID
        self.displayName = displayName
        self.discordURL = discordURL
        self.modSupportURL = modSupportURL
        self.metadataBugtrackerURL = metadataBugtrackerURL
        self.metadataIssueURL = metadataIssueURL
    }
}

public struct ModuleHelpContext: Equatable, Sendable {
    public let identifier: String
    public let name: String

    public init(identifier: String, name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public struct MACKANHelpLink: Identifiable, Equatable, Sendable {
    public enum ID: String, Sendable {
        case userGuide
        case ckanDiscord
        case gameDiscord
        case modSupport
        case reportClientIssue
        case reportMetadataIssue
    }

    public let id: ID
    public let title: String
    public let url: URL
    public let systemImage: String

    public static let userGuide = MACKANHelpLink(
        id: .userGuide,
        title: "User Guide",
        url: URL(string: "https://github.com/KSP-CKAN/CKAN/wiki/User-guide")!,
        systemImage: "book")

    public static let ckanDiscord = MACKANHelpLink(
        id: .ckanDiscord,
        title: "CKAN Discord",
        url: URL(string: "https://discord.gg/Mb4nXQD")!,
        systemImage: "bubble.left.and.bubble.right")

    public static let reportClientIssue = MACKANHelpLink(
        id: .reportClientIssue,
        title: "Report Client Issue",
        url: URL(string: "https://github.com/KSP-CKAN/CKAN/issues/new/choose")!,
        systemImage: "ladybug")

    public static let coreLinks: [MACKANHelpLink] = [
        .userGuide,
        .ckanDiscord,
    ]

    public static func gameSupportLinks(for gameID: String?) -> [MACKANHelpLink] {
        guard let profile = GameHelpProfile(gameID: gameID) else {
            return []
        }
        return [
            gameDiscord(profile),
            modSupport(profile),
        ]
    }

    public static func reportLinks(
        for gameID: String?,
        selectedModule: ModuleHelpContext? = nil
    ) -> [MACKANHelpLink] {
        guard let profile = GameHelpProfile(gameID: gameID) else {
            return [
                .reportClientIssue,
            ]
        }
        return [
            .reportClientIssue,
            reportMetadataIssue(profile, selectedModule: selectedModule),
        ]
    }

    public static func gameDiscord(_ profile: GameHelpProfile) -> MACKANHelpLink {
        MACKANHelpLink(
            id: .gameDiscord,
            title: "\(profile.displayName) Discord",
            url: profile.discordURL,
            systemImage: "gamecontroller")
    }

    public static func modSupport(_ profile: GameHelpProfile) -> MACKANHelpLink {
        MACKANHelpLink(
            id: .modSupport,
            title: "\(profile.displayName) Mod Support",
            url: profile.modSupportURL,
            systemImage: "wrench.and.screwdriver")
    }

    public static func reportMetadataIssue(
        _ profile: GameHelpProfile,
        selectedModule: ModuleHelpContext? = nil
    ) -> MACKANHelpLink {
        MACKANHelpLink(
            id: .reportMetadataIssue,
            title: "Report \(profile.displayName) Metadata Issue",
            url: metadataIssueURL(for: profile, selectedModule: selectedModule),
            systemImage: "doc.badge.gearshape")
    }

    private static func metadataIssueURL(
        for profile: GameHelpProfile,
        selectedModule: ModuleHelpContext?
    ) -> URL {
        guard let selectedModule else {
            return profile.metadataBugtrackerURL
        }

        var components = URLComponents(url: profile.metadataIssueURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "title", value: "\(selectedModule.name) metadata issue"),
            URLQueryItem(name: "body", value: metadataIssueBody(for: profile, selectedModule: selectedModule)),
        ]
        return components.url!
    }

    private static func metadataIssueBody(
        for profile: GameHelpProfile,
        selectedModule: ModuleHelpContext
    ) -> String {
        """
        Metadata issue reported from MACKAN.

        Game: \(profile.displayName)
        Identifier: \(selectedModule.identifier)
        Name: \(selectedModule.name)

        Describe the metadata problem:
        """
    }
}

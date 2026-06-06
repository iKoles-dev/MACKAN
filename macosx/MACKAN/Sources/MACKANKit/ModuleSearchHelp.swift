import Foundation

public struct ModuleSearchHelpSection: Identifiable, Equatable, Sendable {
    public let title: String
    public let examples: [ModuleSearchHelpExample]

    public var id: String { title }

    public init(title: String, examples: [ModuleSearchHelpExample]) {
        self.title = title
        self.examples = examples
    }

    public static let all: [ModuleSearchHelpSection] = [
        ModuleSearchHelpSection(
            title: "Text",
            examples: [
                ModuleSearchHelpExample(
                    query: "scatterer @blackrack",
                    explanation: "Match text fields and author prefixes."),
                ModuleSearchHelpExample(
                    query: "identifier:ModuleManager",
                    explanation: "Match module identifiers by prefix."),
            ]),
        ModuleSearchHelpSection(
            title: "Metadata",
            examples: [
                ModuleSearchHelpExample(
                    query: "desc:VisualEnhancements lang:ru",
                    explanation: "Match descriptions and localizations."),
                ModuleSearchHelpExample(
                    query: "lic:GPL tag:visual label:Favourites",
                    explanation: "Match license, metadata tags, and CKAN labels."),
            ]),
        ModuleSearchHelpSection(
            title: "Relationships",
            examples: [
                ModuleSearchHelpExample(
                    query: "dep:Kerbal rec:Environmental sug:Toolbar",
                    explanation: "Match dependency, recommendation, and suggestion relationships."),
                ModuleSearchHelpExample(
                    query: "conf:JNSQ sup:OuterPlanets",
                    explanation: "Match conflict and support relationships."),
            ]),
        ModuleSearchHelpSection(
            title: "State",
            examples: [
                ModuleSearchHelpExample(
                    query: "is:installed not:cached is:replaceable",
                    explanation: "Match installed, cached, upgrade, compatibility, and replacement states."),
                ModuleSearchHelpExample(
                    query: "-tag:visual -@sarbian",
                    explanation: "Negate plain, scoped, and author tokens with a leading minus."),
            ]),
        ModuleSearchHelpSection(
            title: "Saved Searches",
            examples: [
                ModuleSearchHelpExample(
                    query: "is:upgradeable tag:visual",
                    explanation: "Compose a query, filter, or tag selection and save it from the bookmark menu."),
            ]),
    ]
}

public struct ModuleSearchHelpExample: Identifiable, Equatable, Sendable {
    public let query: String
    public let explanation: String

    public var id: String { query }

    public init(query: String, explanation: String) {
        self.query = query
        self.explanation = explanation
    }
}

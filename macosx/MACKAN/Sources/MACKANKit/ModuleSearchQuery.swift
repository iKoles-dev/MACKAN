import Foundation

public struct ModuleSearchQuery: Equatable, Sendable {
    private let terms: [Term]

    public init(_ rawValue: String) {
        self.terms = rawValue
            .split(whereSeparator: \.isWhitespace)
            .compactMap { Term.parse(String($0)) }
    }

    public var isEmpty: Bool {
        terms.isEmpty
    }

    public func matches(_ module: ModuleSummary, labels: [String] = []) -> Bool {
        terms.allSatisfy { $0.matches(module, labels: labels) }
    }
}

private enum Term: Equatable, Sendable {
    case plain(SearchText)
    case identifier(SearchText)
    case author(SearchText)
    case description(SearchText)
    case license(SearchText)
    case localization(SearchText)
    case tag(SearchText)
    case label(SearchText)
    case relationship(RelationshipKind, SearchText)
    case state(ModuleState, expected: Bool)

    static func parse(_ token: String) -> Term? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if let value = SearchText(trimmed, prefix: "@") {
            return .author(value)
        }
        if let value = SearchText(trimmed, prefix: "identifier:") {
            return .identifier(value)
        }
        if let value = SearchText(trimmed, prefix: "id:") {
            return .identifier(value)
        }
        if let value = SearchText(trimmed, prefix: "desc:") {
            return .description(value)
        }
        if let value = SearchText(trimmed, prefix: "lic:") {
            return .license(value)
        }
        if let value = SearchText(trimmed, prefix: "lang:") {
            return .localization(value)
        }
        if let value = SearchText(trimmed, prefix: "tag:") {
            return .tag(value)
        }
        if let value = SearchText(trimmed, prefix: "label:") {
            return .label(value)
        }
        for relationship in RelationshipKind.allCases {
            if let value = SearchText(trimmed, prefix: relationship.queryPrefix) {
                return .relationship(relationship, value)
            }
        }
        if let state = ModuleState(trimmed, prefix: "is:") {
            return .state(state, expected: true)
        }
        if let state = ModuleState(trimmed, prefix: "not:") {
            return .state(state, expected: false)
        }
        return .plain(SearchText.plain(trimmed))
    }

    func matches(_ module: ModuleSummary, labels: [String]) -> Bool {
        switch self {
        case .plain(let text):
            return text.matches {
                module.searchableValues.contains { value in
                    value.caseInsensitiveContains(text.value)
                }
            }
        case .identifier(let text):
            return text.matches {
                module.identifier.caseInsensitiveHasPrefix(text.value)
            }
        case .author(let text):
            return text.matches {
                module.authorSearchValues.contains { author in
                    author.caseInsensitiveHasPrefix(text.value)
                }
            }
        case .description(let text):
            return text.matches {
                let normalizedNeedle = text.value.normalizedScopedSearch()
                guard !normalizedNeedle.isEmpty else {
                    return true
                }
                return module.descriptionSearchValues.contains { value in
                    value.caseInsensitiveContains(normalizedNeedle)
                }
            }
        case .license(let text):
            return text.matches {
                module.licenseSearchValues.contains { license in
                    license.caseInsensitiveHasPrefix(text.value)
                }
            }
        case .localization(let text):
            return text.matches {
                module.localizations.contains { localization in
                    localization.caseInsensitiveHasPrefix(text.value)
                }
            }
        case .tag(let text):
            return text.matches {
                if text.value.isEmpty {
                    return module.tags.isEmpty
                }
                return module.tags.contains { tag in
                    tag.caseInsensitiveEquals(text.value)
                }
            }
        case .label(let text):
            return text.matches {
                if text.value.isEmpty {
                    return labels.isEmpty
                }
                return labels.contains { label in
                    label.removingSearchSpaces().caseInsensitiveEquals(text.value.removingSearchSpaces())
                }
            }
        case .relationship(let kind, let text):
            return text.matches {
                module.relationships.contains { relationship in
                    relationship.kind.caseInsensitiveEquals(kind.rawValue)
                        && relationship.value.caseInsensitiveHasPrefix(text.value)
                }
            }
        case .state(let state, let expected):
            return state.matches(module) == expected
        }
    }
}

private struct SearchText: Equatable, Sendable {
    let value: String
    let isNegated: Bool

    init?(_ token: String, prefix: String) {
        if token.hasPrefix(prefix) {
            self.value = String(token.dropFirst(prefix.count))
            self.isNegated = false
        } else if token.hasPrefix("-\(prefix)") {
            self.value = String(token.dropFirst(prefix.count + 1))
            self.isNegated = true
        } else {
            return nil
        }
    }

    static func plain(_ token: String) -> SearchText {
        if token.hasPrefix("-"), token.count > 1 {
            return SearchText(value: String(token.dropFirst()), isNegated: true)
        }
        return SearchText(value: token, isNegated: false)
    }

    private init(value: String, isNegated: Bool) {
        self.value = value
        self.isNegated = isNegated
    }

    func matches(_ predicate: () -> Bool) -> Bool {
        let result = predicate()
        return isNegated ? !result : result
    }
}

private enum RelationshipKind: String, CaseIterable, Sendable {
    case depends = "Depends"
    case recommends = "Recommends"
    case suggests = "Suggests"
    case conflicts = "Conflicts"
    case supports = "Supports"

    var queryPrefix: String {
        switch self {
        case .depends:
            return "dep:"
        case .recommends:
            return "rec:"
        case .suggests:
            return "sug:"
        case .conflicts:
            return "conf:"
        case .supports:
            return "sup:"
        }
    }
}

private enum ModuleState: String, Sendable {
    case compatible
    case installed
    case cached
    case newlyCompatible
    case upgradeable
    case replaceable

    init?(_ token: String, prefix: String) {
        guard token.hasPrefix(prefix) else {
            return nil
        }
        let value = String(token.dropFirst(prefix.count))
        switch value {
        case "compatible":
            self = .compatible
        case "installed":
            self = .installed
        case "cached":
            self = .cached
        case "newly-compatible":
            self = .newlyCompatible
        case "upgradeable", "upgradable":
            self = .upgradeable
        case "replaceable":
            self = .replaceable
        default:
            return nil
        }
    }

    func matches(_ module: ModuleSummary) -> Bool {
        switch self {
        case .compatible:
            return module.isCompatible
        case .installed:
            return module.isInstalled
        case .cached:
            return module.isCached
        case .newlyCompatible:
            return module.isNew
        case .upgradeable:
            return module.hasUpdate
        case .replaceable:
            return module.isInstalled && module.hasReplacement
        }
    }
}

private extension ModuleSummary {
    var searchableValues: [String] {
        [
            identifier,
            name,
            author,
            status.title,
            installedVersion,
            latestVersion,
            license,
        ]
        + versions
        + contents
        + tags
        + relationships.flatMap { relationship in
            [relationship.kind, relationship.value]
        }
    }

    var authorSearchValues: [String] {
        splitSearchValues(author)
    }

    var licenseSearchValues: [String] {
        splitSearchValues(license)
    }

    var descriptionSearchValues: [String] {
        [
            abstract.normalizedScopedSearch(),
            description.normalizedScopedSearch(),
        ]
    }

    private func splitSearchValues(_ value: String) -> [String] {
        let pieces = value
            .split { character in
                character == "," || character == ";"
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? [value] : pieces + [value]
    }
}

extension String {
    func caseInsensitiveContains(_ other: String) -> Bool {
        guard !other.isEmpty else {
            return true
        }
        return range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    func caseInsensitiveHasPrefix(_ other: String) -> Bool {
        guard !other.isEmpty else {
            return true
        }
        guard let range = range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return false
        }
        return range.lowerBound == startIndex
    }

    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    func removingSearchSpaces() -> String {
        filter { !$0.isWhitespace }
    }

    func normalizedScopedSearch() -> String {
        filter { $0.isLetter || $0.isNumber }
    }
}

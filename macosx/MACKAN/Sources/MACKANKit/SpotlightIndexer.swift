import CoreSpotlight
import Foundation

#if canImport(MobileCoreServices)
import MobileCoreServices
#endif

public struct SpotlightIndexItem: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let description: String
    public let author: String
    public let keywords: [String]
    public let deepLinkURL: URL?

    public init(
        identifier: String,
        title: String,
        description: String,
        author: String = "",
        keywords: [String] = [],
        deepLinkURL: URL? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.author = author
        self.keywords = keywords
        self.deepLinkURL = deepLinkURL
    }
}

/// Indexes installed KSP mods in macOS Spotlight via CoreSpotlight.
///
/// When a mod is installed, its name, identifier, author, abstract, version, and tags
/// are indexed so users can find it with Cmd+Space. Selecting a Spotlight result opens
/// MACKAN and (where supported) highlights the mod in the catalog.
///
/// Indexing is scoped to installed mods only. When a mod is uninstalled the item is
/// deleted from the index. A full re-index for an instance is cheap because CoreSpotlight
/// ignores items whose content has not changed since the last index.
///
/// ## URL scheme
/// Spotlight results use the custom URL scheme `mackan://mod/<identifier>`. Register
/// this scheme in `Info.plist` (or let MACKAN handle any `mackan://` URL) so the OS
/// knows to open MACKAN when the user clicks a result.
public final class SpotlightIndexer: Sendable {
    public static let shared = SpotlightIndexer()

    /// CoreSpotlight domain grouping all MACKAN mod items.
    private static let domainIdentifier = "io.github.mackan.mods"

    /// Custom URL scheme used to deep-link into MACKAN from Spotlight.
    private static let urlScheme = "mackan"

    // CSSearchableIndex is not Sendable, but is safe to use from any thread
    // per CoreSpotlight's own documentation (all mutations go through its delegate queue).
    nonisolated(unsafe) private let index: CSSearchableIndex

    public init(index: CSSearchableIndex = .default()) {
        self.index = index
    }

    // MARK: - Public API

    /// Indexes the given list of installed modules for the specified game instance.
    ///
    /// Only modules where `isInstalled == true` are indexed; others are silently skipped.
    /// Any items that were previously indexed for this instance but are no longer installed
    /// are removed automatically via ``removeAll(forInstanceID:)``.
    ///
    /// - Parameters:
    ///   - modules: The full module catalog for the instance (installed and uninstalled).
    ///   - instanceID: A stable identifier for the game instance used to scope the index domain.
    public func indexInstalledMods(_ modules: [ModuleSummary], forInstanceID instanceID: String) {
        let items = Self.indexableModules(modules, instanceID: instanceID)
            .map { searchableItem(for: $0, instanceID: instanceID) }
        index.indexSearchableItems(items) { error in
            if let error {
                // Indexing errors are non-fatal; log but do not propagate.
                print("[SpotlightIndexer] Indexing error for instance \(instanceID): \(error.localizedDescription)")
            }
        }
    }

    /// Updates the Spotlight entry for a single module (e.g., after install or upgrade).
    ///
    /// - Parameters:
    ///   - module: The module whose Spotlight entry should be created or refreshed.
    ///   - instanceID: A stable identifier for the game instance.
    public func indexMod(_ module: ModuleSummary, forInstanceID instanceID: String) {
        guard module.isInstalled else {
            removeMod(identifier: module.identifier, forInstanceID: instanceID)
            return
        }
        let item = searchableItem(for: module, instanceID: instanceID)
        index.indexSearchableItems([item]) { error in
            if let error {
                print("[SpotlightIndexer] Indexing error for \(module.identifier): \(error.localizedDescription)")
            }
        }
    }

    /// Removes the Spotlight entry for a single mod (e.g., after uninstall).
    public func removeMod(identifier: String, forInstanceID instanceID: String) {
        let uniqueID = spotlightID(for: identifier, instanceID: instanceID)
        index.deleteSearchableItems(withIdentifiers: [uniqueID]) { error in
            if let error {
                print("[SpotlightIndexer] Deletion error for \(identifier): \(error.localizedDescription)")
            }
        }
    }

    /// Removes all Spotlight entries for a given game instance.
    ///
    /// Call this when an instance is removed from MACKAN.
    public func removeAll(forInstanceID instanceID: String) {
        let domain = spotlightDomain(for: instanceID)
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { error in
            if let error {
                print("[SpotlightIndexer] Domain deletion error for \(instanceID): \(error.localizedDescription)")
            }
        }
    }

    /// Removes all MACKAN Spotlight entries across all instances.
    public func removeAll() {
        index.deleteAllSearchableItems { error in
            if let error {
                print("[SpotlightIndexer] Delete-all error: \(error.localizedDescription)")
            }
        }
    }

    public static func indexableModules(_ modules: [ModuleSummary], instanceID: String) -> [SpotlightIndexItem] {
        modules
            .filter(\.isInstalled)
            .map { module in
                let description = [module.abstract, module.description]
                    .filter { !$0.isEmpty }
                    .first ?? ""
                var keywords = module.tags
                if !module.installedVersion.isEmpty {
                    keywords.append("v\(module.installedVersion)")
                }
                keywords.append(module.identifier)
                return SpotlightIndexItem(
                    identifier: "\(instanceID):\(module.identifier)",
                    title: module.name,
                    description: description,
                    author: module.author,
                    keywords: keywords,
                    deepLinkURL: deepLinkURL(for: module.identifier))
            }
    }

    // MARK: - Private helpers

    private func searchableItem(for module: ModuleSummary, instanceID: String) -> CSSearchableItem {
        let item = Self.indexableModules([module], instanceID: instanceID).first ?? SpotlightIndexItem(
            identifier: "\(instanceID):\(module.identifier)",
            title: module.name,
            description: module.abstract,
            author: module.author,
            keywords: module.tags,
            deepLinkURL: Self.deepLinkURL(for: module.identifier))
        return searchableItem(for: item, instanceID: instanceID)
    }

    private func searchableItem(for item: SpotlightIndexItem, instanceID: String) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = item.title
        attributes.contentDescription = item.description.isEmpty ? nil : item.description

        if !item.author.isEmpty {
            attributes.authorNames = [item.author]
        }

        attributes.keywords = item.keywords

        attributes.url = item.deepLinkURL

        let domain = spotlightDomain(for: instanceID)
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: item.identifier,
            domainIdentifier: domain,
            attributeSet: attributes)

        // Items do not expire by default so the index stays fresh until explicit removal.
        searchableItem.expirationDate = .distantFuture
        return searchableItem
    }

    private func spotlightID(for identifier: String, instanceID: String) -> String {
        "\(instanceID):\(identifier)"
    }

    private func spotlightDomain(for instanceID: String) -> String {
        "\(Self.domainIdentifier).\(instanceID)"
    }

    private static func deepLinkURL(for identifier: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "mod"
        components.path = "/\(identifier)"
        return components.url
    }
}

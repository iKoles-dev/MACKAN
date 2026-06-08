import Foundation

public struct SavedModuleSearch: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let searchText: String
    public let filter: ModuleFilter
    public let tagFilter: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        searchText: String,
        filter: ModuleFilter,
        tagFilter: String?
    ) {
        self.id = id
        self.name = name
        self.searchText = searchText
        self.filter = filter
        self.tagFilter = tagFilter
    }
}

public protocol SavedModuleSearchStoring {
    func loadSavedSearches() -> [SavedModuleSearch]
    func saveSavedSearches(_ savedSearches: [SavedModuleSearch])
}

public final class UserDefaultsSavedModuleSearchStore: SavedModuleSearchStoring {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "mackan.savedModuleSearches"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadSavedSearches() -> [SavedModuleSearch] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([SavedModuleSearch].self, from: data)) ?? []
    }

    public func saveSavedSearches(_ savedSearches: [SavedModuleSearch]) {
        guard let data = try? JSONEncoder().encode(savedSearches) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

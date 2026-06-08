import Foundation

public struct ModuleSortCriterion: Codable, Equatable, Hashable, Sendable {
    public let sort: ModuleSort
    public let ascending: Bool

    public init(sort: ModuleSort, ascending: Bool) {
        self.sort = sort
        self.ascending = ascending
    }
}

public struct ModuleCatalogState: Codable, Equatable, Sendable {
    public let searchText: String
    public let filter: ModuleFilter
    public let tagFilter: String?
    public let moduleSort: ModuleSort
    public let moduleSortAscending: Bool
    public let secondaryModuleSortCriteria: [ModuleSortCriterion]

    public init(
        searchText: String,
        filter: ModuleFilter,
        tagFilter: String?,
        moduleSort: ModuleSort,
        moduleSortAscending: Bool,
        secondaryModuleSortCriteria: [ModuleSortCriterion] = []
    ) {
        self.searchText = searchText
        self.filter = filter
        self.tagFilter = tagFilter
        self.moduleSort = moduleSort
        self.moduleSortAscending = moduleSortAscending
        self.secondaryModuleSortCriteria = Self.normalizedSecondaryCriteria(
            secondaryModuleSortCriteria,
            primarySort: moduleSort)
    }

    private enum CodingKeys: String, CodingKey {
        case searchText
        case filter
        case tagFilter
        case moduleSort
        case moduleSortAscending
        case secondaryModuleSortCriteria
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let searchText = try container.decode(String.self, forKey: .searchText)
        let filter = try container.decode(ModuleFilter.self, forKey: .filter)
        let tagFilter = try container.decodeIfPresent(String.self, forKey: .tagFilter)
        let moduleSort = try container.decode(ModuleSort.self, forKey: .moduleSort)
        let moduleSortAscending = try container.decode(Bool.self, forKey: .moduleSortAscending)
        let secondaryModuleSortCriteria = try container.decodeIfPresent(
            [ModuleSortCriterion].self,
            forKey: .secondaryModuleSortCriteria) ?? []

        self.init(
            searchText: searchText,
            filter: filter,
            tagFilter: tagFilter,
            moduleSort: moduleSort,
            moduleSortAscending: moduleSortAscending,
            secondaryModuleSortCriteria: secondaryModuleSortCriteria)
    }

    private static func normalizedSecondaryCriteria(
        _ criteria: [ModuleSortCriterion],
        primarySort: ModuleSort
    ) -> [ModuleSortCriterion] {
        var seen = Set([primarySort])
        return criteria.filter { criterion in
            seen.insert(criterion.sort).inserted
        }
    }
}

public protocol ModuleCatalogStateStoring {
    func loadCatalogState() -> ModuleCatalogState?
    func saveCatalogState(_ catalogState: ModuleCatalogState)
}

public final class UserDefaultsModuleCatalogStateStore: ModuleCatalogStateStoring {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "mackan.moduleCatalogState"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadCatalogState() -> ModuleCatalogState? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(ModuleCatalogState.self, from: data)
    }

    public func saveCatalogState(_ catalogState: ModuleCatalogState) {
        guard let data = try? JSONEncoder().encode(catalogState) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}

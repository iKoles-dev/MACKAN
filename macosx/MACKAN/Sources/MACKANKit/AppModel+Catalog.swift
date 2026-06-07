import Foundation

extension AppModel {
    public var filteredModules: [ModuleSummary] {
        let query = ModuleSearchQuery(searchText)
        let filtered = modules.filter { module in
            filter.includes(module)
                && tagIncludes(module)
                && query.matches(module, labels: labels(for: module.identifier).map(\.name))
        }
        return sorted(filtered)
    }

    public var availableModuleTags: [String] {
        modules
            .flatMap(\.tags)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniquedCaseInsensitive()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public var canSaveCurrentSearch: Bool {
        !currentSearchStateIsEmpty
    }

    public var availableModuleLabels: [ModuleLabelSummary] {
        sortedLabels(moduleLabels)
    }

    public var currentSearchNameSuggestion: String {
        let cleanedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedSearchText.isEmpty {
            return cleanedSearchText
        }
        if let cleanedTagFilter {
            return "Tag: \(cleanedTagFilter)"
        }
        return filter.title
    }

    public func saveCurrentSearch(named name: String) -> SavedModuleSearch? {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty, canSaveCurrentSearch else {
            return nil
        }

        let existingIndex = savedSearches.firstIndex { saved in
            saved.name.localizedCaseInsensitiveCompare(cleanedName) == .orderedSame
        }
        let id = existingIndex.map { savedSearches[$0].id } ?? UUID().uuidString
        let saved = SavedModuleSearch(
            id: id,
            name: cleanedName,
            searchText: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            filter: filter,
            tagFilter: cleanedTagFilter)

        if let existingIndex {
            savedSearches[existingIndex] = saved
        } else {
            savedSearches.append(saved)
        }
        persistSavedSearches()
        return saved
    }

    public func applySavedSearch(_ id: SavedModuleSearch.ID) {
        guard let saved = savedSearches.first(where: { $0.id == id }) else {
            return
        }
        searchText = saved.searchText
        filter = saved.filter
        tagFilter = saved.tagFilter
    }

    public func deleteSavedSearch(_ id: SavedModuleSearch.ID) {
        let deletedSearch = savedSearches.first { $0.id == id }
        let originalCount = savedSearches.count
        savedSearches.removeAll { $0.id == id }
        if savedSearches.count != originalCount {
            persistSavedSearches()
            if let deletedSearch, currentSearchState(matches: deletedSearch) {
                searchText = ""
                filter = .all
                tagFilter = nil
            }
        }
    }

    public func isModuleColumnVisible(_ column: ModuleTableColumn) -> Bool {
        visibleModuleColumns.contains(column)
    }

    public func toggleModuleColumn(_ column: ModuleTableColumn) {
        if visibleModuleColumns.contains(column) {
            guard visibleModuleColumns.count > 1 else {
                return
            }
            visibleModuleColumns.removeAll { $0 == column }
        } else {
            visibleModuleColumns.append(column)
            visibleModuleColumns = Self.normalizedModuleColumns(visibleModuleColumns)
        }
        persistModuleColumns()
    }

    public func resetModuleColumns() {
        visibleModuleColumns = ModuleTableColumn.defaultVisible
        persistModuleColumns()
    }

    public func showAllModuleColumns() {
        visibleModuleColumns = ModuleTableColumn.allCases
        persistModuleColumns()
    }

    public func sortByHeader(_ column: ModuleTableColumn) {
        guard let sort = column.sort else {
            return
        }

        if moduleSort == sort {
            moduleSortAscending.toggle()
        } else {
            moduleSort = sort
            moduleSortAscending = true
        }
        clearSecondaryModuleSorts()
    }

    public func addSecondaryModuleSort(_ sort: ModuleSort, ascending: Bool = true) {
        guard sort != moduleSort else {
            moduleSortAscending = ascending
            return
        }

        let criterion = ModuleSortCriterion(sort: sort, ascending: ascending)
        secondaryModuleSortCriteria = normalizedSecondarySortCriteria(
            secondaryModuleSortCriteria.filter { $0.sort != sort } + [criterion])
    }

    public func toggleSecondaryModuleSortDirection(_ sort: ModuleSort) {
        guard let index = secondaryModuleSortCriteria.firstIndex(where: { $0.sort == sort }) else {
            addSecondaryModuleSort(sort)
            return
        }

        var criteria = secondaryModuleSortCriteria
        let criterion = criteria[index]
        criteria[index] = ModuleSortCriterion(sort: criterion.sort, ascending: !criterion.ascending)
        secondaryModuleSortCriteria = normalizedSecondarySortCriteria(criteria)
    }

    public func removeSecondaryModuleSort(_ sort: ModuleSort) {
        secondaryModuleSortCriteria = secondaryModuleSortCriteria.filter { $0.sort != sort }
    }

    public func clearSecondaryModuleSorts() {
        secondaryModuleSortCriteria = []
    }

    public func secondarySortCriterion(for sort: ModuleSort) -> ModuleSortCriterion? {
        secondaryModuleSortCriteria.first { $0.sort == sort }
    }

    public func applyLabelFilter(_ label: ModuleLabelSummary) {
        showCatalog()
        searchText = "label:\(label.name.removingSearchSpaces())"
        tagFilter = nil
    }

    public func applyBuiltInSavedSearch(_ filter: ModuleFilter) {
        showCatalog()
        self.filter = filter
        searchText = ""
        tagFilter = nil
    }

    public func labels(for identifier: ModuleSummary.ID) -> [ModuleLabelSummary] {
        moduleLabels.filter { $0.contains(identifier: identifier) }
    }

    func sortedLabels(_ labels: [ModuleLabelSummary]) -> [ModuleLabelSummary] {
        labels.sorted { first, second in
            if first.instanceName != second.instanceName {
                switch (first.instanceName, second.instanceName) {
                case (nil, nil):
                    break
                case (nil, _):
                    return true
                case (_, nil):
                    return false
                case let (firstInstance?, secondInstance?):
                    let comparison = firstInstance.localizedCaseInsensitiveCompare(secondInstance)
                    if comparison != .orderedSame {
                        return comparison == .orderedAscending
                    }
                }
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
    }

    func persistCatalogState() {
        catalogStateStore.saveCatalogState(ModuleCatalogState(
            searchText: searchText,
            filter: filter,
            tagFilter: tagFilter,
            moduleSort: moduleSort,
            moduleSortAscending: moduleSortAscending,
            secondaryModuleSortCriteria: secondaryModuleSortCriteria))
    }

    static func normalizedModuleColumns(_ columns: [ModuleTableColumn]) -> [ModuleTableColumn] {
        let unique = Set(columns)
        guard !unique.isEmpty else {
            return ModuleTableColumn.defaultVisible
        }
        return ModuleTableColumn.allCases.filter(unique.contains)
    }

    func normalizedSecondarySortCriteria(
        _ criteria: [ModuleSortCriterion]
    ) -> [ModuleSortCriterion] {
        var seen = Set([moduleSort])
        return criteria.filter { criterion in
            seen.insert(criterion.sort).inserted
        }
    }

    private func tagIncludes(_ module: ModuleSummary) -> Bool {
        guard let tagFilter,
              !tagFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        return module.tags.contains { $0.localizedCaseInsensitiveCompare(tagFilter) == .orderedSame }
    }

    private var cleanedTagFilter: String? {
        guard let tagFilter else {
            return nil
        }
        let cleaned = tagFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private var currentSearchStateIsEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && filter == .all
            && cleanedTagFilter == nil
    }

    private func currentSearchState(matches savedSearch: SavedModuleSearch) -> Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines) == savedSearch.searchText
            && filter == savedSearch.filter
            && cleanedTagFilter == savedSearch.tagFilter
    }

    private func persistSavedSearches() {
        savedSearchStore.saveSavedSearches(savedSearches)
    }

    private func persistModuleColumns() {
        moduleColumnStore.saveVisibleModuleColumns(visibleModuleColumns)
    }

    private func sorted(_ modules: [ModuleSummary]) -> [ModuleSummary] {
        let sortCriteria = [ModuleSortCriterion(sort: moduleSort, ascending: moduleSortAscending)]
            + secondaryModuleSortCriteria

        return modules.sorted { first, second in
            for criterion in sortCriteria {
                let result = compare(first, second, by: criterion.sort)
                guard result != .orderedSame else {
                    continue
                }
                return criterion.ascending ? result == .orderedAscending : result == .orderedDescending
            }

            let tieBreaker = compare(first.identifier, second.identifier)
            guard tieBreaker != .orderedSame else {
                return false
            }

            return moduleSortAscending ? tieBreaker == .orderedAscending : tieBreaker == .orderedDescending
        }
    }

    private func compare(
        _ first: ModuleSummary,
        _ second: ModuleSummary,
        by sort: ModuleSort
    ) -> ComparisonResult {
        switch sort {
        case .name:
            return compare(first.name, second.name)
        case .identifier:
            return compare(first.identifier, second.identifier)
        case .status:
            return compare(first.status.title, second.status.title)
        case .installedVersion:
            return compare(first.installedVersion, second.installedVersion)
        case .latestVersion:
            return compare(first.latestVersion, second.latestVersion)
        case .author:
            return compare(first.author, second.author)
        case .gameCompatibility:
            return compare(first.gameCompatibility, second.gameCompatibility)
        case .downloadSize:
            return compare(first.downloadSize, second.downloadSize)
        case .installSize:
            return compare(first.installSize, second.installSize)
        case .releaseDate:
            return compare(first.releaseDate, second.releaseDate)
        case .installDate:
            return compare(first.installDate, second.installDate)
        case .downloadCount:
            return compare(first.downloadCount, second.downloadCount)
        }
    }

    private func compare(_ first: String, _ second: String) -> ComparisonResult {
        first.localizedStandardCompare(second)
    }

    private func compare(_ first: Int64, _ second: Int64) -> ComparisonResult {
        if first == second {
            return .orderedSame
        }
        return first < second ? .orderedAscending : .orderedDescending
    }

    private func compare(_ first: Int?, _ second: Int?) -> ComparisonResult {
        switch (first, second) {
        case let (first?, second?):
            if first == second {
                return .orderedSame
            }
            return first < second ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedAscending
        case (_, nil):
            return .orderedDescending
        }
    }
}

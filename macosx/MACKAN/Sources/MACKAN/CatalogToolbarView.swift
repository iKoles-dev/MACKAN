import SwiftUI

import MACKANKit

struct CatalogToolbarView: View {
    @ObservedObject var model: AppModel
    @Binding var isShowingSaveSearchSheet: Bool
    @Binding var isShowingLabelsManagerSheet: Bool
    @Binding var savedSearchName: String
    let onToggleLabel: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            Group {
                if CatalogToolbarLayoutPolicy.shouldUseSingleRow(forWidth: Double(geometry.size.width)) {
                    wideToolbar
                } else {
                    compactToolbar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 58)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wideToolbar: some View {
        HStack(spacing: CGFloat(CatalogToolbarLayoutPolicy.searchControlGap)) {
            searchRow
                .frame(
                    minWidth: CGFloat(CatalogToolbarLayoutPolicy.searchMinimumWidth),
                    idealWidth: CGFloat(CatalogToolbarLayoutPolicy.searchIdealWidth),
                    maxWidth: 420,
                    alignment: .leading)

            controlsStack
                .frame(
                    minWidth: CGFloat(CatalogToolbarLayoutPolicy.controlsMinimumWidth),
                    maxWidth: .infinity,
                    alignment: .leading)
        }
    }

    private var compactToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchRow
            controlsRow
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search mods", text: $model.searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: CGFloat(CatalogToolbarLayoutPolicy.searchMinimumWidth))
                .accessibilityLabel("Search mods")
                .accessibilityHint("Filter modules by text query and modifiers.")

            searchSyntaxMenu
        }
    }

    private var controlsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            controlsStack
            .frame(
                minWidth: CGFloat(CatalogToolbarLayoutPolicy.controlsMinimumWidth),
                alignment: .leading)
        }
    }

    private var controlsStack: some View {
        HStack(spacing: 8) {
            filterPicker
            tagPicker
            Divider().frame(height: 18)
            labelsMenu
            savedSearchesMenu
            Divider().frame(height: 18)
            columnsMenu
            Divider().frame(height: 18)
            sortPicker
            sortDirectionButton
            secondarySortMenu
        }
    }

    private var searchSyntaxMenu: some View {
        Menu {
            ForEach(ModuleSearchHelpSection.all) { section in
                Section(section.title) {
                    ForEach(section.examples) { example in
                        Button {
                            model.searchText = example.query
                            model.filter = .all
                            model.tagFilter = nil
                        } label: {
                            Label(example.query, systemImage: "magnifyingglass")
                        }
                        .help(example.explanation)
                    }
                }
            }
        } label: {
            Label("Search Syntax", systemImage: "questionmark.circle")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Search syntax")
        .help("Search Syntax")
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $model.filter) {
            ForEach(ModuleFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Module filter")
        .accessibilityHint("Choose module compatibility/filter state.")
        .frame(width: 150)
    }

    private var tagPicker: some View {
        Picker("Tag", selection: $model.tagFilter) {
            Text("All Tags").tag(String?.none)
            ForEach(model.availableModuleTags, id: \.self) { tag in
                Text(tag).tag(String?.some(tag))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 130)
        .disabled(model.availableModuleTags.isEmpty)
    }

    private var labelsMenu: some View {
        Menu {
            if model.availableModuleLabels.isEmpty {
                Text("No Labels")
            } else {
                ForEach(model.availableModuleLabels) { label in
                    Button {
                        onToggleLabel(label.name)
                    } label: {
                        Label(label.name, systemImage: labelIconName(label))
                    }
                    .disabled(model.selectedModuleID == nil)
                }
            }

            Divider()

            Button {
                isShowingLabelsManagerSheet = true
            } label: {
                Label("Manage Labels", systemImage: "tag.circle")
            }
        } label: {
            Label("Labels", systemImage: "tag")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Manage module labels")
        .help("Labels")
    }

    private var savedSearchesMenu: some View {
        Menu {
            if model.savedSearches.isEmpty {
                Text("No Saved Searches")
            } else {
                ForEach(model.savedSearches) { savedSearch in
                    Button {
                        model.applySavedSearch(savedSearch.id)
                    } label: {
                        Label(savedSearch.name, systemImage: "magnifyingglass")
                    }
                }

                Divider()

                Menu {
                    ForEach(model.savedSearches) { savedSearch in
                        Button(role: .destructive) {
                            model.deleteSavedSearch(savedSearch.id)
                        } label: {
                            Label(savedSearch.name, systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Delete Saved Search", systemImage: "trash")
                }
            }

            Divider()

            Button {
                savedSearchName = model.currentSearchNameSuggestion
                isShowingSaveSearchSheet = true
            } label: {
                Label("Save Current Search", systemImage: "bookmark")
            }
            .disabled(!model.canSaveCurrentSearch)
        } label: {
            Label("Saved Searches", systemImage: "bookmark")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Saved searches")
        .help("Saved Searches")
    }

    private var columnsMenu: some View {
        Menu {
            ForEach(ModuleTableColumn.allCases) { column in
                Button {
                    model.toggleModuleColumn(column)
                } label: {
                    if model.isModuleColumnVisible(column) {
                        Label(column.title, systemImage: "checkmark")
                    } else {
                        Text(column.title)
                    }
                }
                .disabled(model.visibleModuleColumns.count == 1 && model.isModuleColumnVisible(column))
            }

            Divider()

            Button {
                model.resetModuleColumns()
            } label: {
                Label("Default Columns", systemImage: "arrow.counterclockwise")
            }

            Button {
                model.showAllModuleColumns()
            } label: {
                Label("All Columns", systemImage: "tablecells")
            }
        } label: {
            Label("Columns", systemImage: "rectangle.split.3x1")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Table columns")
        .help("Columns")
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $model.moduleSort) {
            ForEach(ModuleSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Primary sort")
        .frame(width: 135)
    }

    private var sortDirectionButton: some View {
        Button {
            model.moduleSortAscending.toggle()
        } label: {
            Label(
                model.moduleSortAscending ? "Ascending" : "Descending",
                systemImage: model.moduleSortAscending ? "arrow.up" : "arrow.down")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Toggle sort direction")
        .help(model.moduleSortAscending ? "Ascending" : "Descending")
    }

    private var secondarySortMenu: some View {
        Menu {
            ForEach(ModuleSort.allCases) { sort in
                let existingCriterion = model.secondarySortCriterion(for: sort)
                Button {
                    if existingCriterion != nil {
                        model.toggleSecondaryModuleSortDirection(sort)
                    } else {
                        model.addSecondaryModuleSort(sort)
                    }
                } label: {
                    Label(
                        existingCriterion.map { criterion in
                            "\(sort.title) \(criterion.ascending ? "Ascending" : "Descending")"
                        } ?? sort.title,
                        systemImage: existingCriterion.map { criterion in
                            criterion.ascending ? "arrow.up" : "arrow.down"
                        } ?? "plus")
                }
                .disabled(sort == model.moduleSort)
            }

            if !model.secondaryModuleSortCriteria.isEmpty {
                Divider()

                ForEach(model.secondaryModuleSortCriteria, id: \.sort) { criterion in
                    Button {
                        model.removeSecondaryModuleSort(criterion.sort)
                    } label: {
                        Label(
                            "Remove \(criterion.sort.title)",
                            systemImage: "minus.circle")
                    }
                }

                Divider()

                Button {
                    model.clearSecondaryModuleSorts()
                } label: {
                    Label("Clear Secondary Sorts", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Then By", systemImage: "list.number")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Secondary sorts")
        .help("Secondary Sorts")
    }

    private func labelIconName(_ label: ModuleLabelSummary) -> String {
        guard let identifier = model.selectedModuleID,
              label.contains(identifier: identifier) else {
            return "tag"
        }
        return "tag.fill"
    }
}

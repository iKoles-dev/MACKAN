import AppKit
import SwiftUI

import MACKANKit

private struct CatalogHeaderGridCell: Identifiable {
    let column: ModuleTableColumn

    var id: String {
        CatalogGridIdentityPolicy.headerID(for: column)
    }
}

private struct CatalogModuleGridCell: Identifiable {
    let module: ModuleSummary
    let column: ModuleTableColumn

    var id: String {
        CatalogGridIdentityPolicy.moduleCellID(moduleIdentifier: module.identifier, column: column)
    }
}

private extension ModuleTableColumn {
    var recognizesRowDoubleClick: Bool {
        switch self {
        case .status, .pending, .autoInstalled:
            return false
        default:
            return true
        }
    }
}

private struct CatalogCellClickOverlay: NSViewRepresentable {
    let clickKey: String
    let recognizesDoubleClick: Bool
    let onClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ClickCatchingButton {
        let view = ClickCatchingButton()
        view.clickKey = clickKey
        view.recognizesDoubleClick = recognizesDoubleClick
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ClickCatchingButton, context: Context) {
        nsView.clickKey = clickKey
        nsView.recognizesDoubleClick = recognizesDoubleClick
        nsView.onClick = onClick
        nsView.onDoubleClick = onDoubleClick
    }

    final class ClickCatchingButton: NSButton {
        private static var lastClick: (key: String, timestamp: TimeInterval)?

        var clickKey = ""
        var recognizesDoubleClick = true
        var onClick: () -> Void = {}
        var onDoubleClick: () -> Void = {}

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            title = ""
            isBordered = false
            isTransparent = false
            focusRingType = .none
            setButtonType(.momentaryChange)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            self
        }

        override func mouseDown(with event: NSEvent) {
            if isDoubleClick(timestamp: event.timestamp, eventClickCount: event.clickCount) {
                Self.lastClick = nil
                onDoubleClick()
            } else {
                Self.lastClick = (clickKey, event.timestamp)
                onClick()
            }
        }

        override func accessibilityPerformPress() -> Bool {
            let timestamp = ProcessInfo.processInfo.systemUptime
            if isDoubleClick(timestamp: timestamp, eventClickCount: 1) {
                Self.lastClick = nil
                onDoubleClick()
            } else {
                Self.lastClick = (clickKey, timestamp)
                onClick()
            }
            return true
        }

        private func isDoubleClick(timestamp: TimeInterval, eventClickCount: Int) -> Bool {
            guard recognizesDoubleClick else {
                return false
            }

            if eventClickCount >= 2 {
                return true
            }

            guard let lastClick = Self.lastClick,
                  lastClick.key == clickKey
            else {
                return false
            }

            return timestamp - lastClick.timestamp <= NSEvent.doubleClickInterval
        }
    }
}

private struct CatalogLoadProgressView: View {
    let progress: AppModel.CatalogLoadProgress

    var body: some View {
        let state = CatalogLoadPresentationState(progress: progress)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .foregroundStyle(.secondary)
                Text(state.title)
                    .font(.headline)
            }

            Text(state.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let secondaryDetail = state.secondaryDetail {
                Text(secondaryDetail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            if let fractionCompleted = state.fractionCompleted {
                ProgressView(value: fractionCompleted)
                    .accessibilityLabel("Catalog load progress")
                    .accessibilityValue(state.detail)
            } else {
                ProgressView()
                    .accessibilityLabel("Catalog load progress")
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.accessibilitySummary)
    }
}

struct CatalogView: View {
    @ObservedObject var model: AppModel
    let isResolvingChanges: Bool
    let isApplyingChanges: Bool
    let onPreviewChanges: () -> Void
    let onApplyChanges: () -> Void
    let onClearChanges: () -> Void
    @State private var isShowingSaveSearchSheet = false
    @State private var isShowingLabelsManagerSheet = false
    @State private var savedSearchName = ""
    @State private var lastRowClick: (identifier: ModuleSummary.ID, timestamp: TimeInterval)?
    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search mods", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .frame(minWidth: CGFloat(CatalogToolbarLayoutPolicy.searchMinimumWidth))
                        .accessibilityLabel("Search mods")
                        .accessibilityHint("Filter modules by text query and modifiers.")

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

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 10) {

                Picker("Filter", selection: $model.filter) {
                    ForEach(ModuleFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Module filter")
                .accessibilityHint("Choose module compatibility/filter state.")
                .frame(width: 150)

                Picker("Tag", selection: $model.tagFilter) {
                    Text("All Tags").tag(String?.none)
                    ForEach(model.availableModuleTags, id: \.self) { tag in
                        Text(tag).tag(String?.some(tag))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
                .disabled(model.availableModuleTags.isEmpty)

                Menu {
                    if model.availableModuleLabels.isEmpty {
                        Text("No Labels")
                    } else {
                        ForEach(model.availableModuleLabels) { label in
                            Button {
                                toggleLabel(label.name)
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

                Picker("Sort", selection: $model.moduleSort) {
                    ForEach(ModuleSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Primary sort")
                .frame(width: 135)

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
                    .frame(
                        minWidth: CGFloat(CatalogToolbarLayoutPolicy.controlsMinimumWidth),
                        alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $isShowingSaveSearchSheet) {
                SaveSearchSheet(
                    name: $savedSearchName,
                    canSaveCurrentSearch: model.canSaveCurrentSearch,
                    onCancel: {
                        isShowingSaveSearchSheet = false
                    },
                    onSave: {
                        if let saved = model.saveCurrentSearch(named: savedSearchName) {
                            savedSearchName = saved.name
                            isShowingSaveSearchSheet = false
                        }
                    })
            }
            .sheet(isPresented: $isShowingLabelsManagerSheet) {
                LabelsManagerSheet(model: model)
            }

            Divider()

            ZStack {
                ScrollView([.horizontal, .vertical]) {
                    LazyVGrid(columns: gridColumns, spacing: 0) {
                        ForEach(headerGridCells) { cell in
                            headerCell(cell.column)
                        }

                        ForEach(moduleGridCells) { cell in
                            moduleCell(cell.column, cell.module)
                        }
                    }
                    .frame(minWidth: gridWidth, alignment: .topLeading)
                }

                if let progress = model.catalogLoadProgress, model.modules.isEmpty {
                    CatalogLoadProgressView(progress: progress)
                }
            }

            Divider()

            CatalogActionStatusStrip(
                summary: model.catalogActionSummary,
                isResolvingChanges: isResolvingChanges,
                isApplyingChanges: isApplyingChanges,
                onPreviewChanges: onPreviewChanges,
                onApplyChanges: onApplyChanges,
                onClearChanges: onClearChanges)
        }
    }

    private var headerGridCells: [CatalogHeaderGridCell] {
        model.visibleModuleColumns.map { CatalogHeaderGridCell(column: $0) }
    }

    private var moduleGridCells: [CatalogModuleGridCell] {
        model.filteredModules.flatMap { module in
            model.visibleModuleColumns.map { column in
                CatalogModuleGridCell(module: module, column: column)
            }
        }
    }

    private var gridColumns: [GridItem] {
        model.visibleModuleColumns.map { column in
            GridItem(.fixed(defaultColumnWidth(column)), spacing: 0)
        }
    }

    private var gridWidth: CGFloat {
        model.visibleModuleColumns.reduce(CGFloat(0)) { partial, column in
            partial + defaultColumnWidth(column)
        }
    }

    private func downloadCountDisplay(_ count: Int?) -> String {
        guard let count else {
            return ""
        }
        return Self.integerFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func headerCell(_ column: ModuleTableColumn) -> some View {
        Group {
            if column.sort != nil {
                Button {
                    model.sortByHeader(column)
                } label: {
                    headerContent(column)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(CatalogGridIdentityPolicy.headerID(for: column))
                .accessibilityLabel("\(column.title) column")
                .accessibilityHint(headerHelp(for: column))
                .help(headerHelp(for: column))
            } else {
                headerContent(column)
                    .accessibilityIdentifier(CatalogGridIdentityPolicy.headerID(for: column))
            }
        }
        .padding(.horizontal, 8)
        .frame(width: defaultColumnWidth(column), height: 28, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerContent(_ column: ModuleTableColumn) -> some View {
        HStack(spacing: 4) {
            Text(column.title)
                .lineLimit(1)

            if column.sort == model.moduleSort {
                Image(systemName: model.moduleSortAscending ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
            } else if let sort = column.sort,
                      let criterion = model.secondarySortCriterion(for: sort) {
                Image(systemName: criterion.ascending ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(column.sort == nil ? .secondary : .primary)
    }

    private func headerHelp(for column: ModuleTableColumn) -> String {
        if column.sort == model.moduleSort {
            return model.moduleSortAscending ? "Sort Descending" : "Sort Ascending"
        }
        if let sort = column.sort,
           let criterion = model.secondarySortCriterion(for: sort) {
            return criterion.ascending ? "Secondary Sort Descending" : "Secondary Sort Ascending"
        }
        return "Sort by \(column.title)"
    }

    private func moduleCell(_ column: ModuleTableColumn, _ module: ModuleSummary) -> some View {
        moduleColumnContent(column, module)
            .padding(.horizontal, 8)
            .frame(width: defaultColumnWidth(column), height: 28, alignment: .leading)
            .contentShape(Rectangle())
            .overlay {
                CatalogCellClickOverlay(
                    clickKey: module.identifier,
                    recognizesDoubleClick: column.recognizesRowDoubleClick,
                    onClick: {
                        handleModuleCellClick(column, module)
                    },
                    onDoubleClick: {
                        handleModuleDoubleClick(module)
                    })
            }
            .accessibilityIdentifier(CatalogGridIdentityPolicy.moduleCellID(
                moduleIdentifier: module.identifier,
                column: column))
        .background(rowBackground(for: module))
    }

    private func handleModuleCellClick(_ column: ModuleTableColumn, _ module: ModuleSummary) {
        if column.recognizesRowDoubleClick,
           shouldTreatAsRowDoubleClick(module) {
            model.selectedModuleID = module.identifier
            model.togglePreferredStagedAction(for: module)
            lastRowClick = nil
            return
        }

        recordRowClickIfNeeded(column, module)
        model.selectedModuleID = module.identifier
        if column == .status || column == .pending {
            model.togglePreferredStagedAction(for: module)
            return
        }

        guard column == .autoInstalled,
              module.isInstalled,
              !module.isAutodetected
        else {
            return
        }

        Task {
            do {
                try await model.setAutoInstalled(!module.isAutoInstalled, for: module.identifier)
            } catch {
                model.reportMaintenanceError(error)
            }
        }
    }

    private func handleModuleDoubleClick(_ module: ModuleSummary) {
        model.selectedModuleID = module.identifier
        model.togglePreferredStagedAction(for: module)
        lastRowClick = nil
    }

    private func shouldTreatAsRowDoubleClick(_ module: ModuleSummary) -> Bool {
        let timestamp = ProcessInfo.processInfo.systemUptime
        guard let lastRowClick,
              lastRowClick.identifier == module.identifier
        else {
            return false
        }
        return timestamp - lastRowClick.timestamp <= NSEvent.doubleClickInterval
    }

    private func recordRowClickIfNeeded(_ column: ModuleTableColumn, _ module: ModuleSummary) {
        if column.recognizesRowDoubleClick {
            lastRowClick = (module.identifier, ProcessInfo.processInfo.systemUptime)
        } else {
            lastRowClick = nil
        }
    }

    private func rowBackground(for module: ModuleSummary) -> Color {
        module.identifier == model.selectedModuleID
            ? Color.accentColor.opacity(0.16)
            : Color.clear
    }

    @ViewBuilder
    private func moduleColumnContent(_ column: ModuleTableColumn, _ module: ModuleSummary) -> some View {
        switch column {
        case .status:
            StatusBadge(status: module.status)
        case .pending:
            PendingActionBadge(action: model.stagedAction(for: module.identifier))
        case .autoInstalled:
            Image(systemName: module.isAutoInstalled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(module.isAutoInstalled ? .green : .secondary)
                .help(module.isInstalled && !module.isAutodetected ? "Toggle Auto Installed" : "Auto Installed")
        case .name:
            moduleColumnText(module.name)
        case .identifier:
            moduleColumnText(module.identifier)
        case .installedVersion:
            moduleColumnText(module.installedVersion)
        case .latestVersion:
            moduleColumnText(module.latestVersion)
        case .author:
            moduleColumnText(module.author)
        case .gameCompatibility:
            moduleColumnText(module.gameCompatibility)
        case .downloadSize:
            moduleColumnText(module.downloadSizeDisplay)
        case .installSize:
            moduleColumnText(module.installSizeDisplay)
        case .releaseDate:
            moduleColumnText(module.releaseDate)
        case .installDate:
            moduleColumnText(module.installDate)
        case .downloadCount:
            moduleColumnText(downloadCountDisplay(module.downloadCount))
        case .license:
            moduleColumnText(module.license)
        case .tags:
            moduleColumnText(module.tags.joined(separator: ", "))
        case .description:
            moduleColumnText(module.abstract)
        }
    }

    private func moduleColumnText(_ value: String) -> some View {
        Text(value)
            .lineLimit(1)
    }

    private func defaultColumnWidth(_ column: ModuleTableColumn) -> CGFloat {
        switch column {
        case .status:
            return 90
        case .pending:
            return 95
        case .autoInstalled:
            return 60
        case .name:
            return 220
        case .identifier:
            return 155
        case .installedVersion, .latestVersion, .license:
            return 110
        case .author:
            return 140
        case .gameCompatibility, .downloadSize:
            return 120
        case .installSize:
            return 110
        case .releaseDate, .installDate:
            return 170
        case .downloadCount:
            return 100
        case .tags:
            return 160
        case .description:
            return 260
        }
    }

    private func toggleLabel(_ labelName: String) {
        guard let identifier = model.selectedModuleID else {
            return
        }
        Task {
            try? await model.toggleLabel(labelName, for: identifier)
        }
    }

    private func labelIconName(_ label: ModuleLabelSummary) -> String {
        guard let identifier = model.selectedModuleID,
              label.contains(identifier: identifier) else {
            return "tag"
        }
        return "tag.fill"
    }
}

private struct CatalogActionStatusStrip: View {
    let summary: CatalogActionSummaryPresentationState
    let isResolvingChanges: Bool
    let isApplyingChanges: Bool
    let onPreviewChanges: () -> Void
    let onApplyChanges: () -> Void
    let onClearChanges: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button {
                onClearChanges()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(summary.kind == .idle)
            .help("Clear staged and previewed changes")

            Button {
                onPreviewChanges()
            } label: {
                Label(isResolvingChanges ? "Previewing" : "Preview", systemImage: "list.bullet.rectangle")
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!summary.canPreview || isResolvingChanges)
            .help("Preview staged changes")

            Button {
                onApplyChanges()
            } label: {
                Label(isApplyingChanges ? "Applying" : "Apply", systemImage: "checkmark.circle")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .disabled(!summary.canApply || isApplyingChanges)
            .help("Apply resolved changes")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }

    private var symbolName: String {
        switch summary.kind {
        case .idle:
            return "circle"
        case .needsPreview:
            return "list.bullet.rectangle"
        case .needsResolution:
            return "exclamationmark.triangle.fill"
        case .readyToApply:
            return "checkmark.circle.fill"
        case .previewError:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch summary.kind {
        case .idle:
            return .secondary
        case .needsPreview:
            return .accentColor
        case .needsResolution:
            return .orange
        case .readyToApply:
            return .green
        case .previewError:
            return .red
        }
    }
}

import AppKit
import SwiftUI

import MACKANKit

struct CatalogTableView: View {
    @ObservedObject var model: AppModel
    @Binding var hoveredModuleID: String?
    let onModuleClick: (ModuleTableColumn, ModuleSummary) -> Void
    let onModuleDoubleClick: (ModuleSummary) -> Void
    @State private var lastSelectedModuleID: String?
    @State private var selectedRowFrame: CGRect?
    @State private var pendingSelectionVisibilityCheckID: String?

    var body: some View {
        GeometryReader { viewportProxy in
            let contentWidth = CatalogLayoutPolicy.contentWidth(forViewportWidth: viewportProxy.size.width)
            let layout = CatalogLayoutPolicy.layout(
                forWidth: contentWidth,
                storedColumns: model.visibleModuleColumns)
            let rowHeight = CatalogLayoutPolicy.rowHeight(forWidth: contentWidth)
            let selectionScrollBottomInset = CatalogLayoutPolicy.selectionScrollBottomInset(forRowHeight: rowHeight)

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(Array(model.filteredModules.enumerated()), id: \.element.identifier) { index, module in
                                CatalogModuleRow(
                                    model: model,
                                    module: module,
                                    rowIndex: index,
                                    layout: layout,
                                    rowHeight: rowHeight,
                                    hoveredModuleID: $hoveredModuleID,
                                    onModuleClick: onModuleClick,
                                    onModuleDoubleClick: onModuleDoubleClick)
                                .id(module.identifier)
                            }
                        } header: {
                            CatalogHeaderRow(model: model, layout: layout)
                        }
                    }
                    .frame(width: layout.totalWidth, alignment: .topLeading)
                    .padding(.bottom, selectionScrollBottomInset)
                }
                .frame(width: contentWidth, alignment: .leading)
                .coordinateSpace(name: CatalogScrollCoordinateSpace.name)
                .background {
                    CatalogKeyboardNavigationMonitor(
                        onMoveUp: model.selectPreviousFilteredModule,
                        onMoveDown: model.selectNextFilteredModule)
                }
                .onAppear {
                    lastSelectedModuleID = model.selectedModuleID
                }
                .onChange(of: model.selectedModuleID) { selectedModuleID in
                    guard let selectedModuleID,
                          model.filteredModules.contains(where: { $0.id == selectedModuleID })
                    else {
                        lastSelectedModuleID = selectedModuleID
                        pendingSelectionVisibilityCheckID = nil
                        return
                    }
                    let anchor = scrollAnchorForSelectionChange(
                        previousModuleID: lastSelectedModuleID,
                        selectedModuleID: selectedModuleID,
                        previousRowFrame: selectedRowFrame,
                        viewportHeight: viewportProxy.size.height,
                        rowHeight: rowHeight)
                    lastSelectedModuleID = selectedModuleID
                    pendingSelectionVisibilityCheckID = selectedModuleID
                    scrollProxy.scrollTo(selectedModuleID, anchor: anchor)
                }
                .onPreferenceChange(SelectedCatalogRowFramePreferenceKey.self) { rowFrame in
                    selectedRowFrame = rowFrame
                    guard let selectedModuleID = model.selectedModuleID,
                          pendingSelectionVisibilityCheckID == selectedModuleID,
                          let rowFrame
                    else {
                        return
                    }
                    pendingSelectionVisibilityCheckID = nil
                    keepSelectedRowInsideVisibleBounds(
                        selectedModuleID: selectedModuleID,
                        rowFrame: rowFrame,
                        viewportHeight: viewportProxy.size.height,
                        rowHeight: rowHeight,
                        scrollProxy: scrollProxy)
                }
            }
        }
    }

    private func scrollAnchorForSelectionChange(
        previousModuleID: String?,
        selectedModuleID: String,
        previousRowFrame: CGRect?,
        viewportHeight: CGFloat,
        rowHeight: CGFloat
    ) -> UnitPoint? {
        guard let previousModuleID,
              let previousRowFrame,
              let previousIndex = model.filteredModules.firstIndex(where: { $0.id == previousModuleID }),
              let selectedIndex = model.filteredModules.firstIndex(where: { $0.id == selectedModuleID })
        else {
            return nil
        }

        let bottomBoundary = viewportHeight - CatalogLayoutPolicy.selectionScrollBottomInset(forRowHeight: rowHeight)
        if selectedIndex > previousIndex,
           previousRowFrame.maxY + rowHeight > bottomBoundary {
            return UnitPoint(x: 0.5, y: 0.76)
        }

        let topBoundary = rowHeight
        if selectedIndex < previousIndex,
           previousRowFrame.minY - rowHeight < topBoundary {
            return UnitPoint(x: 0.5, y: 0.24)
        }

        return nil
    }

    private func keepSelectedRowInsideVisibleBounds(
        selectedModuleID: String,
        rowFrame: CGRect,
        viewportHeight: CGFloat,
        rowHeight: CGFloat,
        scrollProxy: ScrollViewProxy
    ) {
        guard viewportHeight > rowHeight * 3,
              rowFrame.height > 0
        else {
            return
        }

        let topBoundary = rowHeight
        let bottomBoundary = viewportHeight - CatalogLayoutPolicy.selectionScrollBottomInset(forRowHeight: rowHeight)
        let anchor: UnitPoint?
        if rowFrame.maxY > bottomBoundary {
            anchor = UnitPoint(x: 0.5, y: 0.76)
        } else if rowFrame.minY < topBoundary {
            anchor = UnitPoint(x: 0.5, y: 0.24)
        } else {
            anchor = nil
        }

        guard let anchor else {
            return
        }

        DispatchQueue.main.async {
            scrollProxy.scrollTo(selectedModuleID, anchor: anchor)
        }
    }
}

private enum CatalogScrollCoordinateSpace {
    static let name = "CatalogTableScroll"
}

private struct SelectedCatalogRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = nextValue() ?? value
    }
}

private struct CatalogKeyboardNavigationMonitor: NSViewRepresentable {
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    func makeNSView(context: Context) -> KeyboardNavigationView {
        let view = KeyboardNavigationView()
        view.onMoveUp = onMoveUp
        view.onMoveDown = onMoveDown
        return view
    }

    func updateNSView(_ nsView: KeyboardNavigationView, context: Context) {
        nsView.onMoveUp = onMoveUp
        nsView.onMoveDown = onMoveDown
    }

    static func dismantleNSView(_ nsView: KeyboardNavigationView, coordinator: ()) {
        nsView.uninstallMonitor()
    }

    final class KeyboardNavigationView: NSView {
        var onMoveUp: () -> Void = {}
        var onMoveDown: () -> Void = {}

        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                uninstallMonitor()
            } else {
                installMonitor()
            }
        }

        private func installMonitor() {
            guard monitor == nil else {
                return
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }
                return self.handle(event)
            }
        }

        func uninstallMonitor() {
            guard let monitor else {
                return
            }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let window else {
                return event
            }
            guard NSApp.keyWindow == window else {
                return event
            }
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                return event
            }

            switch event.keyCode {
            case 126:
                onMoveUp()
                return nil
            case 125:
                onMoveDown()
                return nil
            default:
                return event
            }
        }
    }
}

private extension ModuleTableColumn {
    var catalogHeaderAlignment: Alignment {
        switch self {
        case .status:
            return .center
        default:
            return .leading
        }
    }

    var catalogCellAlignment: Alignment {
        switch self {
        case .status, .autoInstalled:
            return .center
        default:
            return .leading
        }
    }

    var recognizesRowDoubleClick: Bool { true }
}

private struct CatalogCellTapOverlay: View {
    let recognizesDoubleClick: Bool
    let onClick: () -> Void
    let onDoubleClick: () -> Void

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(clickGesture)
    }

    private var clickGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
                switch value {
                case .first(_):
                    if recognizesDoubleClick {
                        onDoubleClick()
                    } else {
                        onClick()
                    }
                case .second(_):
                    onClick()
                }
            }
    }
}

private struct CatalogHeaderRow: View {
    @ObservedObject var model: AppModel
    let layout: CatalogLayoutPolicy.Layout

    var body: some View {
        HStack(spacing: 0) {
            ForEach(layout.columns) { column in
                headerCell(column)
            }
        }
        .frame(width: layout.totalWidth, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func headerCell(_ column: ModuleTableColumn) -> some View {
        Group {
            if column.sort != nil {
                Button {
                    model.sortByHeader(column)
                } label: {
                    headerContent(column)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: column.catalogHeaderAlignment)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(column.title) column")
                .accessibilityHint(headerHelp(for: column))
            } else {
                headerContent(column)
            }
        }
        .accessibilityIdentifier(CatalogGridIdentityPolicy.headerID(for: column))
        .help(headerHelp(for: column))
        .padding(.horizontal, 8)
        .frame(width: layout.width(for: column), height: 28, alignment: column.catalogHeaderAlignment)
    }

    private func headerContent(_ column: ModuleTableColumn) -> some View {
        HStack(spacing: 4) {
            Text(column.title)
                .lineLimit(1)
                .truncationMode(.tail)

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
        if column.sort == nil {
            switch column {
            case .pending:
                return "Shows install, remove, upgrade, or replace changes staged for this mod."
            case .autoInstalled:
                return "CKAN auto-installed flag. Checked mods were installed automatically as dependencies and may be removed when no longer needed."
            default:
                return column.title
            }
        }
        return "Sort by \(column.title)"
    }
}

private struct CatalogModuleRow: View {
    @ObservedObject var model: AppModel
    let module: ModuleSummary
    let rowIndex: Int
    let layout: CatalogLayoutPolicy.Layout
    let rowHeight: CGFloat
    @Binding var hoveredModuleID: String?
    let onModuleClick: (ModuleTableColumn, ModuleSummary) -> Void
    let onModuleDoubleClick: (ModuleSummary) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(layout.columns) { column in
                CatalogModuleCell(model: model, column: column, module: module)
                    .padding(.horizontal, 8)
                    .frame(width: layout.width(for: column), height: rowHeight, alignment: column.catalogCellAlignment)
                    .contentShape(Rectangle())
                    .overlay {
                        CatalogCellTapOverlay(
                            recognizesDoubleClick: column.recognizesRowDoubleClick,
                            onClick: {
                                onModuleClick(column, module)
                            },
                            onDoubleClick: {
                                onModuleDoubleClick(module)
                            })
                    }
                    .accessibilityIdentifier(CatalogGridIdentityPolicy.moduleCellID(
                        moduleIdentifier: module.identifier,
                        column: column))
            }
        }
        .background(rowBackground)
        .background {
            if module.identifier == model.selectedModuleID {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SelectedCatalogRowFramePreferenceKey.self,
                        value: proxy.frame(in: .named(CatalogScrollCoordinateSpace.name)))
                }
            }
        }
        .overlay(alignment: .leading) {
            if stagedAction != nil {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
        }
        .onHover { hovering in
            hoveredModuleID = hovering ? module.identifier : (hoveredModuleID == module.identifier ? nil : hoveredModuleID)
        }
    }

    private var stagedAction: StagedModAction? {
        model.stagedAction(for: module.identifier)
    }

    private var rowBackground: Color {
        if module.identifier == model.selectedModuleID {
            return Color.accentColor.opacity(0.16)
        }
        if stagedAction != nil {
            return Color.accentColor.opacity(0.08)
        }
        if module.identifier == hoveredModuleID {
            return Color.secondary.opacity(0.07)
        }
        return rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.028)
    }
}

private struct CatalogModuleCell: View {
    @ObservedObject var model: AppModel
    let column: ModuleTableColumn
    let module: ModuleSummary

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch column {
        case .status:
            StatusIcon(status: module.status, stagedAction: model.stagedAction(for: module.identifier))
        case .pending:
            PendingActionBadge(action: model.stagedAction(for: module.identifier))
        case .autoInstalled:
            Image(systemName: module.isAutoInstalled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(module.isAutoInstalled ? .green : .secondary)
                .help(module.isInstalled && !module.isAutodetected
                    ? "Toggle CKAN auto-installed flag"
                    : "CKAN auto-installed flag")
        case .name:
            cellText(module.name)
        case .identifier:
            cellText(module.identifier)
        case .installedVersion:
            cellText(module.installedVersion)
        case .latestVersion:
            cellText(module.latestVersion)
        case .author:
            cellText(module.author)
        case .gameCompatibility:
            cellText(module.gameCompatibility)
        case .downloadSize:
            cellText(module.downloadSizeDisplay)
        case .installSize:
            cellText(module.installSizeDisplay)
        case .releaseDate:
            cellText(module.releaseDate)
        case .installDate:
            cellText(module.installDate)
        case .downloadCount:
            cellText(downloadCountDisplay(module.downloadCount))
        case .license:
            cellText(module.license)
        case .tags:
            cellText(module.tags.joined(separator: ", "))
        case .description:
            cellText(module.abstract)
        }
    }

    private func cellText(_ value: String) -> some View {
        Text(value)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func downloadCountDisplay(_ count: Int?) -> String {
        guard let count else {
            return ""
        }
        return Self.integerFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

import AppKit
import SwiftUI

import MACKANKit

struct CatalogTableView: View {
    @ObservedObject var model: AppModel
    @Binding var hoveredModuleID: String?
    let viewportWidth: CGFloat
    let onModuleClick: (ModuleTableColumn, ModuleSummary) -> Void
    let onModuleDoubleClick: (ModuleSummary) -> Void

    var body: some View {
        let layout = CatalogLayoutPolicy.layout(
            forWidth: viewportWidth,
            storedColumns: model.visibleModuleColumns)
        let rowHeight = CatalogLayoutPolicy.rowHeight(forWidth: viewportWidth)

        ScrollView([.horizontal, .vertical]) {
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
                    }
                } header: {
                    CatalogHeaderRow(model: model, layout: layout)
                }
            }
            .frame(minWidth: layout.totalWidth, alignment: .topLeading)
        }
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

private struct CatalogHeaderRow: View {
    @ObservedObject var model: AppModel
    let layout: CatalogLayoutPolicy.Layout

    var body: some View {
        HStack(spacing: 0) {
            ForEach(layout.columns) { column in
                headerCell(column)
            }
        }
        .frame(minWidth: layout.totalWidth, alignment: .topLeading)
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
                .accessibilityLabel("\(column.title) column")
                .accessibilityHint(headerHelp(for: column))
            } else {
                headerContent(column)
            }
        }
        .accessibilityIdentifier(CatalogGridIdentityPolicy.headerID(for: column))
        .help(headerHelp(for: column))
        .padding(.horizontal, 8)
        .frame(width: layout.width(for: column), height: 28, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
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
                    .frame(width: layout.width(for: column), height: rowHeight, alignment: .leading)
                    .contentShape(Rectangle())
                    .overlay {
                        CatalogCellClickOverlay(
                            clickKey: module.identifier,
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
        .onHover { hovering in
            hoveredModuleID = hovering ? module.identifier : (hoveredModuleID == module.identifier ? nil : hoveredModuleID)
        }
    }

    private var rowBackground: Color {
        if module.identifier == model.selectedModuleID {
            return Color.accentColor.opacity(0.16)
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
            StatusBadge(status: module.status)
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

import SwiftUI

import MACKANKit

struct MaintenanceCenterView: View {
    @ObservedObject var model: AppModel
    let pane: MaintenancePane
    let onInstallHistoryModules: ([InstallationHistoryModule], Bool) -> Void
    let onRevealUnmanagedFile: (UnmanagedFileSummary) -> Void
    let onUpdatePlayTime: (String, Double) async -> Void
    let onRefreshCache: () async -> Void
    let onPurgeCacheToLimit: () async -> Void
    let onPurgeAllCache: () async -> Void
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: pane.symbolName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    if let selectedInstance = model.selectedInstance, pane.showsSelectedInstanceSubtitle {
                        Text(selectedInstance.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    Task { await reloadPane() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                Button {
                    closePane()
                } label: {
                    Label("Catalog", systemImage: "square.grid.2x2")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()

            ZStack {
                paneBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isLoading {
                    ProgressView("Loading")
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .task(id: pane) {
            await reloadPane()
        }
    }

    @ViewBuilder
    private var paneBody: some View {
        switch pane {
        case .history:
            InstallationHistorySheet(
                result: model.installationHistoryResult,
                onInstallMissing: { modules in
                    model.closeMaintenancePane()
                    onInstallHistoryModules(modules, false)
                },
                onRestoreExactVersions: { modules in
                    model.closeMaintenancePane()
                    onInstallHistoryModules(modules, true)
                },
                onClose: closePane)
        case .unmanagedFiles:
            UnmanagedFilesSheet(
                result: model.unmanagedFilesResult,
                onRevealFile: onRevealUnmanagedFile,
                onClose: closePane)
        case .playTime:
            PlayTimeSheet(
                result: model.playTimeResult,
                onSave: onUpdatePlayTime,
                onClose: closePane)
        case .downloadStatistics:
            DownloadStatisticsSheet(
                result: model.downloadStatisticsResult,
                onClose: closePane)
        case .cache:
            CacheMaintenanceSheet(
                info: model.cacheInfoResult,
                purgeResult: model.lastCachePurgeResult,
                onRefresh: onRefreshCache,
                onPurgeToLimit: onPurgeCacheToLimit,
                onPurgeAll: onPurgeAllCache,
                onClose: closePane)
        }
    }

    private func reloadPane() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await model.loadMaintenancePane(pane)
        } catch {
            // AppModel stores the user-facing maintenance error for the alert.
        }
    }

    private func closePane() {
        model.closeMaintenancePane()
    }
}

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @State private var instancePendingRemoval: GameInstanceSummary?
    @State private var instancePendingRename: GameInstanceSummary?
    @State private var renameInstanceName = ""
    @State private var isRenamingInstance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ServiceStatusView(
                state: model.healthState,
                catalogLoadProgress: model.catalogLoadProgress)
                .padding(.horizontal, 14)
                .padding(.top, 12)

            List(selection: instanceSelection) {
                Section("Instances") {
                    ForEach(model.instances) { instance in
                        Label {
                            VStack(alignment: .leading) {
                                Text(instance.name)
                                    .lineLimit(1)
                                Text(instance.gameVersion)
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        } icon: {
                            Image(systemName: instance.isDefault ? "star.fill" : "shippingbox")
                                .foregroundStyle(instance.isDefault ? .yellow : .secondary)
                        }
                        .tag(instance.id)
                        .accessibilityLabel("\(instance.name), \(instance.gameVersion)")
                        .accessibilityHint("Select game instance")
                        .contextMenu {
                            Button {
                                beginRename(instance)
                            } label: {
                                Label("Rename...", systemImage: "pencil")
                            }
                            Button {
                                setDefaultInstance(instance.id)
                            } label: {
                                Label("Set as Default", systemImage: "star")
                            }
                            .disabled(instance.isDefault || !instance.isValid)
                            Button {
                                openInstanceDirectory(instance.id)
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }
                            .disabled(instance.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Divider()
                            Button(role: .destructive) {
                                instancePendingRemoval = instance
                            } label: {
                                Label("Forget Instance...", systemImage: "trash")
                            }
                            .disabled(model.instances.count <= 1)
                        }
                    }
                }

                Section("Saved Searches") {
                    BuiltInSavedSearchButton(
                        title: "Upgradeable",
                        systemImage: "arrow.up.circle",
                        isSelected: model.mainContentRoute == .catalog && model.filter == .upgradable)
                    {
                        model.applyBuiltInSavedSearch(.upgradable)
                    }
                    BuiltInSavedSearchButton(
                        title: "Installed",
                        systemImage: "checkmark.circle",
                        isSelected: model.mainContentRoute == .catalog && model.filter == .installed)
                    {
                        model.applyBuiltInSavedSearch(.installed)
                    }
                    BuiltInSavedSearchButton(
                        title: "Cached",
                        systemImage: "externaldrive",
                        isSelected: model.mainContentRoute == .catalog && model.filter == .cached)
                    {
                        model.applyBuiltInSavedSearch(.cached)
                    }
                    BuiltInSavedSearchButton(
                        title: "Incompatible",
                        systemImage: "exclamationmark.triangle",
                        isSelected: model.mainContentRoute == .catalog && model.filter == .incompatible)
                    {
                        model.applyBuiltInSavedSearch(.incompatible)
                    }
                }

                Section("Labels") {
                    if model.availableModuleLabels.isEmpty {
                        Label("No Labels", systemImage: "tag")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.availableModuleLabels) { label in
                            Button {
                                model.applyLabelFilter(label)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(label.name)
                                            .lineLimit(1)
                                        Text("\(label.identifiers.count.formatted()) mods")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Circle()
                                        .fill(label.colorHex.flatMap { Color(mackanHex: $0) } ?? .secondary.opacity(0.35))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .accessibilityLabel("Label \(label.name)")
                            .accessibilityHint("Apply saved module label filter.")
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Maintenance") {
                    ForEach(MaintenancePane.allCases) { pane in
                        Button {
                            model.showMaintenancePane(pane)
                        } label: {
                            MaintenanceSidebarRow(
                                pane: pane,
                                isSelected: model.mainContentRoute == .maintenance(pane))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Maintenance pane \(pane.title)")
                    }
                }
            }
            .accessibilityLabel("Games and maintenance sections")
            .listStyle(.sidebar)
        }
        .confirmationDialog(
            "Forget Instance?",
            isPresented: isConfirmingInstanceRemoval,
            presenting: instancePendingRemoval
        ) { instance in
            Button("Forget \(instance.name)", role: .destructive) {
                forgetInstance(instance.id)
            }
        } message: { instance in
            Text("This removes \(instance.name) from CKAN's instance list. It does not delete the game folder.")
        }
        .sheet(isPresented: isShowingRenameSheet) {
            RenameInstanceSheet(
                originalName: instancePendingRename?.name ?? "",
                name: $renameInstanceName,
                isRenaming: isRenamingInstance,
                onCancel: {
                    instancePendingRename = nil
                    renameInstanceName = ""
                },
                onRename: {
                    renamePendingInstance()
                })
        }
    }

    private var instanceSelection: Binding<GameInstanceSummary.ID?> {
        Binding {
            model.selectedInstanceID
        } set: { instanceID in
            Task { await model.selectInstance(instanceID) }
        }
    }

    private func setDefaultInstance(_ instanceID: GameInstanceSummary.ID) {
        Task {
            do {
                try await model.setDefaultInstance(instanceID)
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }

    private func openInstanceDirectory(_ instanceID: GameInstanceSummary.ID) {
        do {
            try model.openInstanceDirectory(instanceID)
        } catch {
            model.healthState = .failed(error.localizedDescription)
        }
    }

    private var isShowingRenameSheet: Binding<Bool> {
        Binding {
            instancePendingRename != nil
        } set: { isPresented in
            if !isPresented {
                instancePendingRename = nil
                renameInstanceName = ""
            }
        }
    }

    private func beginRename(_ instance: GameInstanceSummary) {
        instancePendingRename = instance
        renameInstanceName = instance.name
    }

    private var isConfirmingInstanceRemoval: Binding<Bool> {
        Binding {
            instancePendingRemoval != nil
        } set: { isPresented in
            if !isPresented {
                instancePendingRemoval = nil
            }
        }
    }

    private func renamePendingInstance() {
        guard let instance = instancePendingRename else {
            return
        }

        Task {
            isRenamingInstance = true
            defer { isRenamingInstance = false }
            do {
                try await model.renameInstance(instance.id, to: renameInstanceName)
                instancePendingRename = nil
                renameInstanceName = ""
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }

    private func forgetInstance(_ instanceID: GameInstanceSummary.ID) {
        Task {
            defer { instancePendingRemoval = nil }
            do {
                try await model.forgetInstance(instanceID)
            } catch {
                model.healthState = .failed(error.localizedDescription)
            }
        }
    }
}

private struct BuiltInSavedSearchButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: systemImage)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .fontWeight(isSelected ? .semibold : .regular)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Apply built-in saved module search.")
    }
}

private struct MaintenanceSidebarRow: View {
    let pane: MaintenancePane
    let isSelected: Bool

    var body: some View {
        Label {
            Text(pane.title)
                .lineLimit(1)
        } icon: {
            Image(systemName: pane.symbolName)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .fontWeight(isSelected ? .semibold : .regular)
        .contentShape(Rectangle())
    }
}

private struct ServiceStatusView: View {
    let state: AppModel.HealthState
    let catalogLoadProgress: AppModel.CatalogLoadProgress?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var symbolName: String {
        if catalogLoadProgress != nil {
            return "arrow.triangle.2.circlepath"
        }
        switch state {
        case .idle, .loading:
            return "circle.dotted"
        case .ready:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var symbolColor: Color {
        if catalogLoadProgress != nil {
            return .accentColor
        }
        switch state {
        case .ready:
            return .green
        case .failed:
            return .orange
        case .idle, .loading:
            return .secondary
        }
    }

    private var title: String {
        if catalogLoadProgress != nil {
            return "Loading catalog"
        }
        switch state {
        case .idle:
            return "MACKAN"
        case .loading:
            return "Connecting"
        case .ready(let health):
            return health.ckanVersion
        case .failed:
            return "Service Offline"
        }
    }

    private var detail: String {
        if let catalogLoadProgress {
            return catalogLoadProgress.moduleCountSummary ?? catalogLoadProgress.detail
        }
        switch state {
        case .idle:
            return "Native macOS CKAN"
        case .loading:
            return "Checking service"
        case .ready(let health):
            return "Protocol \(health.protocolVersion)"
        case .failed(let message):
            return message
        }
    }
}

private struct RenameInstanceSheet: View {
    let originalName: String
    @Binding var name: String
    let isRenaming: Bool
    let onCancel: () -> Void
    let onRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Instance")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onRename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canRename)
            }
        }
        .padding()
        .mackanModalSheetFrame(.compact)
    }

    private var canRename: Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isRenaming
            && !cleanedName.isEmpty
            && cleanedName != originalName
    }
}


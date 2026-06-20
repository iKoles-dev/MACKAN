import SwiftUI

import MACKANKit

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
    @State private var hoveredModuleID: String?

    var body: some View {
        VStack(spacing: 0) {
            CatalogToolbarView(
                model: model,
                isShowingSaveSearchSheet: $isShowingSaveSearchSheet,
                isShowingLabelsManagerSheet: $isShowingLabelsManagerSheet,
                savedSearchName: $savedSearchName,
                onToggleLabel: toggleLabel)
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
                GeometryReader { geometry in
                    CatalogTableView(
                        model: model,
                        hoveredModuleID: $hoveredModuleID,
                        viewportWidth: geometry.size.width,
                        onModuleClick: handleModuleCellClick,
                        onModuleDoubleClick: handleModuleDoubleClick)
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

    private func handleModuleCellClick(_ column: ModuleTableColumn, _ module: ModuleSummary) {
        model.selectedModuleID = module.identifier
        if column == .status {
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
    }

    private func toggleLabel(_ labelName: String) {
        guard let identifier = model.selectedModuleID else {
            return
        }
        Task {
            try? await model.toggleLabel(labelName, for: identifier)
        }
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
        VStack(spacing: 0) {
            Rectangle()
                .fill(stateBorderColor)
                .frame(height: 2)

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
        }
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
    }

    private var stateBorderColor: Color {
        switch summary.kind {
        case .idle:
            return Color.secondary.opacity(0.15)
        case .needsPreview:
            return Color.accentColor.opacity(0.5)
        case .needsResolution:
            return Color.orange
        case .readyToApply:
            return Color.green
        case .previewError:
            return Color.red
        }
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

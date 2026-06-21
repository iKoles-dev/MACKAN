import SwiftUI

import MACKANKit

struct ChangeSetPreviewSheet: View {
    let result: ChangeSetResult?
    let conflictNotice: ChangeSetConflictNotice?
    let dependencyChoiceNotice: DependencyChoiceNotice?
    let errorMessage: String?
    let errorDetails: SidecarErrorDetails?
    let isResolving: Bool
    let isApplying: Bool
    let suppressRecommendations: Bool
    let onClose: () -> Void
    let onClear: () -> Void
    let onStageProvider: (ProviderChoice, ProviderOption) -> Void
    let onStageRecommendation: (String) -> Void
    let onToggleSuppressRecommendations: (Bool) -> Void
    let onRetry: () -> Void
    let onRemoveLock: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Change Preview")
                    .font(.headline)
                Spacer()
                if isResolving {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Resolving")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                } else if let result {
                    Text("\(result.changes.count.formatted()) changes")
                        .foregroundStyle(.secondary)
                }
            }

            if isResolving {
                resolvingPreviewState
            } else if errorDetails?.isRegistryLock == true {
                RegistryLockNotice(
                    message: errorMessage,
                    details: errorDetails,
                    retryTitle: "Retry Preview",
                    onRetry: onRetry,
                    onRemoveLock: onRemoveLock)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let result {
                if let conflictNotice {
                    ChangeSetConflictPanel(notice: conflictNotice)
                }

                if let dependencyChoiceNotice {
                    DependencyChoicePanel(
                        notice: dependencyChoiceNotice,
                        onStageProvider: onStageProvider)
                }

                if !result.recommendationChoices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Optional recommendations", systemImage: "sparkles")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("Always leave recommendations unchecked", isOn: Binding(
                                get: { suppressRecommendations },
                                set: { newValue in
                                    onToggleSuppressRecommendations(newValue)
                                }))
                            .toggleStyle(.checkbox)
                        }

                        ForEach(result.recommendationChoices) { choice in
                            HStack(spacing: 10) {
                                Image(systemName: choice.kindSymbolName)
                                    .foregroundStyle(choice.isRecommendedDefault ? Color.accentColor : Color.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(choice.name)
                                            .lineLimit(1)
                                        Text(choice.kindTitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(choice.detailText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if !choice.abstract.isEmpty {
                                        Text(choice.abstract)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Button {
                                    onStageRecommendation(choice.identifier)
                                } label: {
                                    Label("Stage", systemImage: "plus.circle")
                                }
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if !result.changes.isEmpty {
                    ChangeSetActionSummaryStrip(changes: result.changes)
                    ChangeSetPreviewList(changes: result.changes)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Pending Changes")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button("Clear", role: .destructive, action: onClear)
                    .disabled(isResolving || (result == nil && errorMessage == nil))
                Spacer()
                Button("Close", role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Apply Changes", action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canApply || isApplying || isResolving)
            }
        }
        .padding()
        .mackanModalSheetFrame(.wide)
    }

    private var canApply: Bool {
        guard let result else {
            return false
        }
        return errorMessage == nil
            && result.conflicts.isEmpty
            && result.conflictDescriptions.isEmpty
            && result.providerChoices.isEmpty
            && !result.changes.isEmpty
    }

    private var resolvingPreviewState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Resolving Preview")
                .font(.headline)
            Text("CKAN is checking dependencies and registry state.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ChangeSetActionSummaryStrip: View {
    let changes: [ChangeSummary]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(groupedActions, id: \.action) { group in
                ChangeSetActionCountPill(action: group.action, count: group.count)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var groupedActions: [(action: String, count: Int)] {
        Dictionary(grouping: changes, by: \.action)
            .map { (action: $0.key, count: $0.value.count) }
            .sorted {
                let firstRank = ChangeSummary.actionSortRank($0.action)
                let secondRank = ChangeSummary.actionSortRank($1.action)
                if firstRank == secondRank {
                    return $0.action.localizedCaseInsensitiveCompare($1.action) == .orderedAscending
                }
                return firstRank < secondRank
            }
    }
}

private struct ChangeSetActionCountPill: View {
    let action: String
    let count: Int

    var body: some View {
        Label {
            Text("\(count.formatted()) \(ChangeSummary.actionTitle(for: action))")
        } icon: {
            Image(systemName: ChangeSummary.actionSymbolName(for: action))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(ChangeSummary.actionTint(for: action))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ChangeSummary.actionTint(for: action).opacity(0.14), in: Capsule())
    }
}

private struct ChangeSetPreviewList: View {
    let changes: [ChangeSummary]

    var body: some View {
        VStack(spacing: 0) {
            ChangeSetPreviewListHeader()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                        ChangeSetPreviewRow(change: change)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.035))

                        if index != changes.count - 1 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 180, maxHeight: 360)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08))
        }
    }
}

private struct ChangeSetPreviewListHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("Action")
                .frame(width: 100, alignment: .leading)
            Text("Mod")
                .frame(width: 210, alignment: .leading)
            Text("Version")
                .frame(width: 100, alignment: .leading)
            Text("Reason")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct ChangeSetPreviewRow: View {
    let change: ChangeSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Label(change.actionTitle, systemImage: change.actionSymbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(change.actionTint)
                .frame(width: 100, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(change.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                Text(change.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .frame(width: 210, alignment: .leading)

            Text(change.versionText)
                .font(.callout.weight(.semibold))
                .frame(width: 100, alignment: .leading)
                .lineLimit(2)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(change.displayReasons, id: \.self) { reason in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(Color.secondary.opacity(0.65))
                            .frame(width: 4, height: 4)
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DependencyChoicePanel: View {
    let notice: DependencyChoiceNotice
    let onStageProvider: (ProviderChoice, ProviderOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.subheadline.weight(.semibold))
                    Text(notice.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(notice.choices) { choice in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(choice.requesterName) requires \(choice.requested)")
                                .font(.caption.weight(.semibold))
                                .textSelection(.enabled)
                            Text(choice.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        ForEach(choice.options) { option in
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(option.identifier) \(option.version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    if !option.abstract.isEmpty {
                                        Text(option.abstract)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 8)
                                Button {
                                    onStageProvider(choice, option)
                                } label: {
                                    Label("Choose", systemImage: "checkmark.circle")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if choice.id != notice.choices.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.leading, 30)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35))
        }
    }
}

private struct ChangeSetConflictPanel: View {
    let notice: ChangeSetConflictNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.subheadline.weight(.semibold))
                    Text(notice.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(notice.conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflict.name)
                            .font(.caption.weight(.semibold))
                        Text("\(conflict.identifier): \(conflict.description)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                ForEach(notice.descriptions, id: \.self) { description in
                    Label(description, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.leading, 30)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35))
        }
    }
}

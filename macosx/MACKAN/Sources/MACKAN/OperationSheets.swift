import SwiftUI

import MACKANKit

struct ImportDownloadsOptionsSheet: View {
    let fileCount: Int
    @Binding var installImportedModules: Bool
    @Binding var deleteImportedFiles: Bool
    @Binding var previewBeforeInstall: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Downloads")
                .font(.headline)

            Text(fileCount == 1 ? "Import 1 selected download." : "Import \(fileCount.formatted()) selected downloads.")
                .foregroundStyle(.secondary)

            Toggle("Install imported modules", isOn: $installImportedModules)
            Toggle("Preview install changes before applying", isOn: $previewBeforeInstall)
                .disabled(!installImportedModules)
            Toggle("Delete imported files after successful import", isOn: $deleteImportedFiles)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Import", action: onImport)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .mackanModalSheetFrame(.compact)
    }
}

struct ChangeSetPreviewSheet: View {
    let result: ChangeSetResult?
    let conflictNotice: ChangeSetConflictNotice?
    let dependencyChoiceNotice: DependencyChoiceNotice?
    let errorMessage: String?
    let errorDetails: SidecarErrorDetails?
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
                if let result {
                    Text("\(result.changes.count.formatted()) changes")
                        .foregroundStyle(.secondary)
                }
            }

            if errorDetails?.isRegistryLock == true {
                RegistryLockNotice(
                    message: errorMessage,
                    details: errorDetails,
                    retryTitle: "Retry Preview",
                    onRetry: onRetry,
                    onRemoveLock: onRemoveLock)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
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

                Table(result.changes) {
                    TableColumn("Action") { change in
                        Label(change.actionTitle, systemImage: change.actionSymbolName)
                    }
                    .width(100)

                    TableColumn("Mod") { change in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.name)
                                .lineLimit(1)
                            Text(change.identifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    TableColumn("Version") { change in
                        Text(change.versionText)
                            .lineLimit(1)
                    }
                    .width(140)

                    TableColumn("Reason") { change in
                        Text(change.reasonText)
                            .lineLimit(2)
                    }
                    .width(min: 180, ideal: 240)
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
                    .disabled(result == nil && errorMessage == nil)
                Spacer()
                Button("Close", role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Apply Changes", action: onApply)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canApply || isApplying)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
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

struct OperationResultSheet: View {
    let result: OperationResult?
    let errorMessage: String?
    let errorDetails: SidecarErrorDetails?
    let canSkipDownloadFailuresRetry: Bool
    let isRefreshing: Bool
    let isCancelling: Bool
    let onRefresh: () -> Void
    let onRetry: () -> Void
    let onSkipDownloadFailuresRetry: () -> Void
    let onRemoveLock: () -> Void
    let onStageProvider: (ProviderChoice, ProviderOption) -> Void
    let onStageRecommendation: (RecommendationChoice) -> Void
    let onSkipRecommendations: () -> Void
    let onAllowIncompatibleCkanFiles: () -> Void
    let onCopyDiagnostics: () -> Void
    let onCancel: () -> Void
    let onClose: () -> Void

    private var pollingID: String {
        "\(result?.operationId ?? "-"):\(result?.status ?? "-")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Operation Result")
                    .font(.headline)
                Spacer()
                if let result {
                    Label(result.statusTitle, systemImage: result.statusSymbolName)
                        .foregroundStyle(result.statusColor)
                }
            }

            if errorDetails?.isRegistryLock == true {
                RegistryLockNotice(
                    message: errorMessage,
                    details: errorDetails,
                    retryTitle: "Retry Operation",
                    onRetry: onRetry,
                    onRemoveLock: onRemoveLock)
            } else if errorDetails?.isDownloadFailure == true {
                DownloadFailureNotice(
                    message: errorMessage,
                    failures: errorDetails?.downloadFailures ?? [],
                    onRetry: onRetry,
                    canSkipDownloadFailuresRetry: canSkipDownloadFailuresRetry,
                    onSkipDownloadFailuresRetry: onSkipDownloadFailuresRetry)
            } else if errorDetails?.isProviderChoice == true {
                ProviderChoiceNotice(
                    message: errorMessage,
                    choices: errorDetails?.providerChoices ?? [],
                    onStageProvider: onStageProvider)
            } else if errorDetails?.isRecommendationChoice == true {
                RecommendationChoiceNotice(
                    message: errorMessage,
                    choices: errorDetails?.recommendationChoices ?? [],
                    onStageRecommendation: onStageRecommendation,
                    onSkipRecommendations: onSkipRecommendations)
            } else if errorDetails?.isIncompatibleCkanFiles == true {
                IncompatibleCkanFileNotice(
                    message: errorMessage,
                    files: errorDetails?.incompatibleCkanFiles ?? [],
                    onAllowIncompatibleCkanFiles: onAllowIncompatibleCkanFiles)
            } else if let errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let result {
                let timeline = OperationTimelinePresentationState(result: result)
                if timeline.events.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: result.statusSymbolName)
                            .font(.system(size: 34))
                            .foregroundStyle(result.statusColor)
                        Text(result.operationId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(Array(timeline.events.enumerated()), id: \.offset) { _, event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.kindTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let percent = event.percent {
                                    Text("\(percent)%")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            Text(event.message)
                                .textSelection(.enabled)
                            if let identifier = event.identifier {
                                Text(identifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            if let byteProgressDisplay = event.byteProgressDisplay {
                                Text(byteProgressDisplay)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .textSelection(.enabled)
                            }
                            if let progressFraction = event.progressFraction {
                                ProgressView(value: progressFraction)
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .listStyle(.inset)
                }
            } else if errorMessage == nil {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange)
                    Text("No Operation Result")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(action: onRefresh) {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }
                .disabled(result == nil || isRefreshing)
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
                if hasErrorContext {
                    Button(action: onCopyDiagnostics) {
                        Label("Copy Diagnostics", systemImage: "doc.on.doc")
                    }
                }
                Button(role: .destructive, action: onCancel) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .disabled(result?.isActive != true || isCancelling)
                Spacer()
                Button("Close", role: .cancel, action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
        .task(id: pollingID) {
            guard result?.isActive == true else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }
                onRefresh()
            }
        }
    }

    private var hasErrorContext: Bool {
        if let errorMessage, !errorMessage.isEmpty {
            return true
        }
        return result?.status == "failed"
    }
}

struct DownloadFailureNotice: View {
    let message: String?
    let failures: [DownloadFailureSummary]
    let onRetry: () -> Void
    let canSkipDownloadFailuresRetry: Bool
    let onSkipDownloadFailuresRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(messageText, systemImage: "icloud.slash")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)

            ForEach(failures) { failure in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(failure.name) \(failure.version)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(failure.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if let firstURL = failure.urls.first, !firstURL.isEmpty {
                        Text(firstURL)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button(action: onRetry) {
                    Label("Retry Operation", systemImage: "arrow.clockwise")
                }
                if canSkipDownloadFailuresRetry {
                    Button(action: onSkipDownloadFailuresRetry) {
                        Label("Skip Failed Downloads", systemImage: "arrow.clockwise.circle")
                    }
                }
                Spacer()
            }
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var messageText: String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "One or more downloads failed." : trimmed
    }
}

private struct ProviderChoiceNotice: View {
    let message: String?
    let choices: [ProviderChoice]
    let onStageProvider: (ProviderChoice, ProviderOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(messageText, systemImage: "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)

            ForEach(choices) { choice in
                VStack(alignment: .leading, spacing: 7) {
                    Text(choice.message)
                        .font(.caption)
                        .textSelection(.enabled)

                    ForEach(choice.options) { option in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.name)
                                    .lineLimit(1)
                                Text("\(option.identifier) \(option.version)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if !option.abstract.isEmpty {
                                    Text(option.abstract)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Button {
                                onStageProvider(choice, option)
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var messageText: String {
        guard let message, !message.isEmpty else {
            return "Choose a provider before installing these .ckan files."
        }
        return message
    }
}

private struct RecommendationChoiceNotice: View {
    let message: String?
    let choices: [RecommendationChoice]
    let onStageRecommendation: (RecommendationChoice) -> Void
    let onSkipRecommendations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(messageText, systemImage: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)

            ForEach(choices) { choice in
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
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Button {
                        onStageRecommendation(choice)
                    } label: {
                        Label("Include", systemImage: "plus.circle")
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button(action: onSkipRecommendations) {
                    Label("Install Without Optional", systemImage: "arrow.right.circle")
                }
                Spacer()
            }
        }
    }

    private var messageText: String {
        guard let message, !message.isEmpty else {
            return "Choose optional recommendations before installing these .ckan files."
        }
        return message
    }
}

private struct IncompatibleCkanFileNotice: View {
    let message: String?
    let files: [IncompatibleCkanFileSummary]
    let onAllowIncompatibleCkanFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(messageText, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)

            ForEach(files) { file in
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)
                            .lineLimit(1)
                        Text("\(file.identifier) \(file.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("Compatible with \(file.compatibleGameVersions)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button(action: onAllowIncompatibleCkanFiles) {
                    Label("Install Anyway", systemImage: "exclamationmark.triangle")
                }
                Spacer()
            }
        }
    }

    private var messageText: String {
        guard let message, !message.isEmpty else {
            return "Some .ckan files are not compatible with the selected game instance."
        }
        return message
    }
}

private struct RegistryLockNotice: View {
    let message: String?
    let details: SidecarErrorDetails?
    let retryTitle: String
    let onRetry: () -> Void
    let onRemoveLock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(messageText, systemImage: "lock.trianglebadge.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .textSelection(.enabled)

            if let detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Button(action: onRetry) {
                    Label(retryTitle, systemImage: "arrow.clockwise")
                }
                Button(role: .destructive, action: onRemoveLock) {
                    Label("Remove Lock File...", systemImage: "trash")
                }
                Spacer()
            }
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var messageText: String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "The CKAN registry is currently in use." : trimmed
    }

    private var detailText: String? {
        guard let lockfilePath = details?.lockfilePath, !lockfilePath.isEmpty else {
            return "Wait for the other CKAN process to finish, then retry."
        }
        return "Lock file: \(lockfilePath). Wait for the other CKAN process to finish, then retry."
    }
}

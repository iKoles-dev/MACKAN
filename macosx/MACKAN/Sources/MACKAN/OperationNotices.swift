import SwiftUI

import MACKANKit

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

struct ProviderChoiceNotice: View {
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

struct RecommendationChoiceNotice: View {
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

struct IncompatibleCkanFileNotice: View {
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

struct RegistryLockNotice: View {
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

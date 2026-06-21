import SwiftUI

import MACKANKit

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

    @State private var showsDetails = false

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
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let result {
                OperationProgressSummaryView(
                    result: result,
                    state: OperationProgressPresentationState(result: result),
                    showsDetails: $showsDetails)
            } else if errorMessage == nil {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Operation Result")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(action: onRefresh) {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }
                .disabled(!canRefreshOperationStatus)
                if showsStatusRefreshActivity {
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

    private var showsStatusRefreshActivity: Bool {
        isRefreshing && result?.isActive == true
    }

    private var canRefreshOperationStatus: Bool {
        result?.isActive == true && !showsStatusRefreshActivity
    }
}

private struct OperationProgressSummaryView: View {
    let result: OperationResult
    let state: OperationProgressPresentationState
    @Binding var showsDetails: Bool

    private var completedCount: Int {
        state.rows.filter { $0.phase == .completed }.count
    }

    private var summaryTitle: String {
        if state.rows.isEmpty {
            return result.statusTitle
        }

        let moduleText = state.rows.count == 1 ? "1 mod" : "\(state.rows.count.formatted()) mods"
        switch result.status {
        case "completed":
            return "Completed \(moduleText)"
        case "failed":
            return "Failed while processing \(moduleText)"
        case "cancelling":
            return "Cancelling \(moduleText)"
        case "cancelled":
            return "Cancelled \(moduleText)"
        default:
            return "Installing \(moduleText)"
        }
    }

    private var overallProgress: Double? {
        guard !state.rows.isEmpty else {
            return nil
        }

        let values = state.rows.map { row in
            if row.phase == .completed {
                return 1.0
            }
            return row.progressFraction ?? 0
        }
        let hasKnownProgress = state.rows.contains { $0.phase == .completed || $0.progressFraction != nil }
        guard hasKnownProgress else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summaryTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !state.rows.isEmpty {
                        Text("\(completedCount.formatted()) of \(state.rows.count.formatted()) done")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if let overallProgress {
                    ProgressView(value: overallProgress)
                        .controlSize(.small)
                } else if result.isActive {
                    ProgressView()
                        .controlSize(.small)
                }

                if let currentActivity = state.currentActivity {
                    Text(currentActivity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            if state.rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: result.statusSymbolName)
                        .font(.system(size: 34))
                        .foregroundStyle(result.statusColor)
                    Text(result.operationId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.rows) { row in
                            OperationProgressModuleRow(row: row)
                            if row.id != state.rows.last?.id {
                                Divider()
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
                .frame(minHeight: 220, maxHeight: 280)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            if !state.events.isEmpty {
                OperationDetailsToggle(isExpanded: $showsDetails)

                if showsDetails {
                    OperationEventLogView(events: state.events)
                        .padding(.top, 6)
                }
            }
        }
    }
}

private struct OperationDetailsToggle: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Details")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct OperationProgressModuleRow: View {
    let row: OperationProgressRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.phase.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(row.phase.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(row.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(row.phase.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(row.phase.color)
                        .lineLimit(1)
                }

                if let detail = row.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                HStack(spacing: 8) {
                    if let progressFraction = row.progressFraction {
                        ProgressView(value: progressFraction)
                            .controlSize(.small)
                    } else {
                        ProgressView(value: 0)
                            .controlSize(.small)
                            .opacity(0.45)
                    }

                    if let byteProgressDisplay = row.byteProgressDisplay {
                        Text(byteProgressDisplay)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct OperationEventLogView: View {
    let events: [OperationEvent]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(event.kindTitle)
                                .font(.caption.weight(.semibold))
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
                            .font(.caption)
                            .textSelection(.enabled)
                        if let identifier = event.identifier {
                            Text(identifier)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 150)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
}

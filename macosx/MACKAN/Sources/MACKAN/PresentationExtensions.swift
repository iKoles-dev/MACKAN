import SwiftUI

import MACKANKit

extension ModuleStatus {
    var color: Color {
        switch self {
        case .installed:
            return .green
        case .upgradable:
            return .blue
        case .available:
            return .secondary
        case .incompatible:
            return .red
        case .cached:
            return .purple
        }
    }
}

extension ChangeSummary {
    var actionTitle: String {
        Self.actionTitle(for: action)
    }

    static func actionTitle(for action: String) -> String {
        switch action {
        case "install":
            return "Install"
        case "remove":
            return "Remove"
        case "upgrade":
            return "Upgrade"
        case "replace":
            return "Replace"
        default:
            return action.capitalized
        }
    }

    var actionSymbolName: String {
        Self.actionSymbolName(for: action)
    }

    static func actionSymbolName(for action: String) -> String {
        switch action {
        case "install":
            return "plus.circle"
        case "remove":
            return "minus.circle"
        case "upgrade":
            return "arrow.up.circle"
        case "replace":
            return "arrow.triangle.2.circlepath"
        default:
            return "circle"
        }
    }

    var actionTint: Color {
        Self.actionTint(for: action)
    }

    static func actionTint(for action: String) -> Color {
        switch action {
        case "install":
            return .green
        case "remove":
            return .red
        case "upgrade":
            return .blue
        case "replace":
            return .orange
        default:
            return .secondary
        }
    }

    static func actionSortRank(_ action: String) -> Int {
        switch action {
        case "install":
            return 0
        case "upgrade":
            return 1
        case "replace":
            return 2
        case "remove":
            return 3
        default:
            return 99
        }
    }

    var versionText: String {
        switch (fromVersion, toVersion) {
        case (let from?, let to?) where from != to:
            return "\(from) -> \(to)"
        case (_, let to?):
            return to
        case (let from?, nil):
            return from
        default:
            return "-"
        }
    }

    var reasonText: String {
        reasons.isEmpty ? (isAuto ? "Automatic" : "User requested") : reasons.joined(separator: ", ")
    }

    var displayReasons: [String] {
        reasons.isEmpty ? [isAuto ? "Automatic" : "User requested"] : reasons
    }
}

extension RecommendationChoice {
    var kindTitle: String {
        switch kind {
        case "recommendation":
            return "Recommended"
        case "suggestion":
            return "Suggested"
        case "supporter":
            return "Supports"
        default:
            return kind.capitalized
        }
    }

    var kindSymbolName: String {
        switch kind {
        case "recommendation":
            return "checkmark.seal"
        case "suggestion":
            return "lightbulb"
        case "supporter":
            return "link.circle"
        default:
            return "plus.circle"
        }
    }

    var detailText: String {
        var parts = ["\(identifier) \(version)"]
        if !dependents.isEmpty {
            parts.append(dependents.joined(separator: ", "))
        }
        return parts.joined(separator: " - ")
    }
}

extension SidecarErrorDetails {
    var isRegistryLock: Bool {
        kind == "registryLock"
    }

    var isLaunchFailure: Bool {
        kind == "launchFailure"
    }

    var isDownloadFailure: Bool {
        kind == "downloadFailures"
    }

    var isProviderChoice: Bool {
        kind == "providerChoices"
    }

    var isRecommendationChoice: Bool {
        kind == "recommendationChoices"
    }

    var isIncompatibleCkanFiles: Bool {
        kind == "incompatibleCkanFiles"
    }
}

extension OperationResult {
    var statusTitle: String {
        switch status {
        case "completed":
            return "Completed"
        case "running":
            return "Running"
        case "cancelling":
            return "Cancelling"
        case "cancelled":
            return "Cancelled"
        case "failed":
            return "Failed"
        default:
            return status.capitalized
        }
    }

    var statusSymbolName: String {
        switch status {
        case "completed":
            return "checkmark.circle.fill"
        case "running":
            return "clock.arrow.circlepath"
        case "cancelling":
            return "xmark.circle"
        case "cancelled":
            return "xmark.circle.fill"
        case "failed":
            return "exclamationmark.triangle.fill"
        default:
            return "circle"
        }
    }

    var statusColor: Color {
        switch status {
        case "completed":
            return .green
        case "running":
            return .blue
        case "cancelling":
            return .orange
        case "cancelled":
            return .secondary
        case "failed":
            return .red
        default:
            return .secondary
        }
    }

    var isActive: Bool {
        status == "running" || status == "cancelling"
    }
}

extension RepositoryRefreshResult {
    var isActive: Bool {
        operationStatus == "running" || operationStatus == "cancelling"
    }
}

extension OperationEvent {
    var kindTitle: String {
        switch kind {
        case "installProgress":
            return "Install"
        case "removeProgress":
            return "Remove"
        case "downloadProgress":
            return "Download"
        case "storeProgress":
            return "Validate"
        default:
            return kind.capitalized
        }
    }
}

extension OperationProgressPhase {
    var title: String {
        switch self {
        case .queued:
            return "Queued"
        case .downloading:
            return "Downloading"
        case .validating:
            return "Validating"
        case .installing:
            return "Installing"
        case .removing:
            return "Removing"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .cancelling:
            return "Cancelling"
        case .cancelled:
            return "Cancelled"
        }
    }

    var symbolName: String {
        switch self {
        case .queued:
            return "clock"
        case .downloading:
            return "arrow.down.circle.fill"
        case .validating:
            return "checklist"
        case .installing:
            return "shippingbox.fill"
        case .removing:
            return "trash.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelling:
            return "xmark.circle"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .queued:
            return .secondary
        case .downloading, .validating, .installing, .removing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelling:
            return .orange
        case .cancelled:
            return .secondary
        }
    }
}

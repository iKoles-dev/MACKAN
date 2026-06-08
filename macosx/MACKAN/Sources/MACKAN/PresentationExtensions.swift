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
            return .orange
        case .cached:
            return .purple
        }
    }
}

extension ChangeSummary {
    var actionTitle: String {
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
            return .orange
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

import SwiftUI

import MACKANKit

struct StatusBadge: View {
    let status: ModuleStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .imageScale(.small)
            Text(status.title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(status.color)
        .lineLimit(1)
    }
}

struct StatusIcon: View {
    let status: ModuleStatus
    let stagedAction: StagedModAction?

    init(status: ModuleStatus, stagedAction: StagedModAction? = nil) {
        self.status = status
        self.stagedAction = stagedAction
    }

    var body: some View {
        Image(systemName: stagedAction?.symbolName ?? status.symbolName)
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(stagedAction == nil ? status.color : Color.accentColor)
            .frame(width: 18, height: 18)
            .help(stagedAction?.title ?? status.title)
            .accessibilityLabel(stagedAction?.title ?? status.title)
    }
}

struct PendingActionBadge: View {
    let action: StagedModAction?

    var body: some View {
        if let action {
            HStack(spacing: 5) {
                Image(systemName: action.symbolName)
                Text(action.title)
                    .font(.caption)
            }
            .foregroundStyle(Color.accentColor)
            .lineLimit(1)
        } else {
            EmptyView()
        }
    }
}

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

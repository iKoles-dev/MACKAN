import AppKit
import SwiftUI

import MACKANKit

struct ModuleDetailHeader: View {
    let module: ModuleSummary
    let details: ModuleDetails?
    let stagedAction: StagedModAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: headerIconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(headerTint)
                    .frame(width: 36, height: 36)
                    .background(headerTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(module.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Text(module.identifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if let stagedAction {
                        ModuleInfoBadge(item: .init(
                            title: stagedTitle(for: stagedAction),
                            systemImage: stagedAction.symbolName,
                            tint: .accentColor))
                    }
                    StatusBadge(status: module.status)
                    if !module.latestVersion.isEmpty {
                        Text(module.latestVersion)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if let summaryText {
                Text(summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            FlowBadgeRow(items: headerBadges)

            HeaderQuickActionRow(
                actions: ModuleHeaderAction.primaryActions(from: details?.resources ?? []),
                copyIdentifier: copyModuleIdentifier)
        }
        .padding(16)
    }

    private var summaryText: String? {
        firstNonEmpty(details?.abstract, module.abstract, details?.description, module.description)
    }

    private var headerBadges: [ModuleInfoBadge.Item] {
        var items: [ModuleInfoBadge.Item] = []

        if module.isInstalled {
            items.append(.init(title: "Installed", systemImage: "checkmark.circle.fill", tint: .green))
        }
        if module.hasUpdate {
            items.append(.init(title: "Update available", systemImage: "arrow.up.circle.fill", tint: .orange))
        }
        if module.isCompatible {
            items.append(.init(title: "Compatible", systemImage: "checkmark.shield.fill", tint: .blue))
        } else {
            items.append(.init(title: "Incompatible", systemImage: "xmark.shield.fill", tint: .red))
        }
        if module.isCached {
            items.append(.init(title: "Cached", systemImage: "externaldrive.fill", tint: .purple))
        }
        if module.isAutoInstalled {
            items.append(.init(title: "Dependency", systemImage: "link", tint: .secondary))
        }
        if module.isAutodetected {
            items.append(.init(title: "Autodetected", systemImage: "magnifyingglass", tint: .secondary))
        }
        if module.hasReplacement {
            items.append(.init(title: "Replacement", systemImage: "arrow.triangle.2.circlepath", tint: .orange))
        }

        return items
    }

    private var headerIconName: String {
        if module.hasUpdate {
            return "arrow.up.app.fill"
        }
        if module.isInstalled {
            return "shippingbox.fill"
        }
        if !module.isCompatible {
            return "exclamationmark.triangle.fill"
        }
        return "shippingbox"
    }

    private var headerTint: Color {
        if stagedAction != nil {
            return .accentColor
        }
        if !module.isCompatible {
            return .red
        }
        if module.hasUpdate {
            return .orange
        }
        if module.isInstalled {
            return .green
        }
        return .accentColor
    }

    private func copyModuleIdentifier() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(module.identifier, forType: .string)
    }
}

private struct HeaderQuickActionRow: View {
    let actions: [ModuleHeaderAction]
    let copyIdentifier: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(actions) { action in
                if let url = URL(string: action.url) {
                    Link(destination: url) {
                        Image(systemName: action.systemImage)
                            .font(.callout.weight(.semibold))
                            .frame(width: 26, height: 26)
                            .foregroundStyle(action.tint)
                            .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help(action.label)
                    .accessibilityLabel(action.label)
                }
            }

            Button(action: copyIdentifier) {
                Image(systemName: "doc.on.doc")
                    .font(.callout.weight(.semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            .help("Copy ID")
            .accessibilityLabel("Copy ID")
        }
    }
}

struct ModuleHeaderAction: Identifiable {
    let label: String
    let url: String
    let systemImage: String
    let tint: Color
    let priority: Int

    var id: String {
        "\(label)-\(url)"
    }

    static func primaryActions(from resources: [ModuleResource], limit: Int = 4) -> [ModuleHeaderAction] {
        resources
            .map(action(for:))
            .filter { URL(string: $0.url) != nil }
            .sorted {
                if $0.priority == $1.priority {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.priority < $1.priority
            }
            .prefix(limit)
            .map { $0 }
    }

    static func action(for resource: ModuleResource) -> ModuleHeaderAction {
        let label = resource.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayLabel = label.isEmpty ? "Resource" : label
        let normalized = displayLabel.lowercased()

        switch normalized {
        case "homepage":
            return .init(label: "Homepage", url: resource.url, systemImage: "safari", tint: .accentColor, priority: 0)
        case "repository":
            return .init(label: "Repository", url: resource.url, systemImage: "curlybraces.square", tint: .blue, priority: 1)
        case "bug tracker":
            return .init(label: "Bug Tracker", url: resource.url, systemImage: "ladybug", tint: .red, priority: 2)
        case "spacedock":
            return .init(label: "SpaceDock", url: resource.url, systemImage: "shippingbox", tint: .purple, priority: 3)
        case "curse":
            return .init(label: "Curse", url: resource.url, systemImage: "flame", tint: .orange, priority: 4)
        case "manual":
            return .init(label: "Manual", url: resource.url, systemImage: "book", tint: .secondary, priority: 5)
        case "license":
            return .init(label: "License", url: resource.url, systemImage: "doc.text", tint: .secondary, priority: 6)
        case "discussions":
            return .init(label: "Discussions", url: resource.url, systemImage: "bubble.left.and.bubble.right", tint: .green, priority: 7)
        case "ci":
            return .init(label: "CI", url: resource.url, systemImage: "hammer", tint: .secondary, priority: 8)
        case "store", "steam store", "gog store", "epic store":
            return .init(label: displayLabel, url: resource.url, systemImage: "cart", tint: .secondary, priority: 9)
        default:
            return .init(label: displayLabel, url: resource.url, systemImage: "arrow.up.right.square", tint: .accentColor, priority: 20)
        }
    }
}

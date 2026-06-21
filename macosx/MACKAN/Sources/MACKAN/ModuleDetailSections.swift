import AppKit
import SwiftUI

import MACKANKit

struct ModuleVersionsView: View {
    let module: ModuleSummary

    var body: some View {
        List(Array(module.versions.enumerated()), id: \.offset) { _, version in
            HStack(spacing: 8) {
                Text(version)
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)

                Spacer()

                if version == module.installedVersion {
                    ModuleInfoBadge(item: .init(title: "Installed", systemImage: "checkmark.circle.fill", tint: .green))
                }
                if version == module.latestVersion {
                    ModuleInfoBadge(item: .init(title: "Latest", systemImage: "star.circle.fill", tint: .accentColor))
                }
            }
            .padding(.vertical, 3)
        }
        .listStyle(.inset)
        .overlay {
            if module.versions.isEmpty {
                EmptyDetailState(systemImage: "clock.arrow.circlepath", title: "No versions reported", detail: "CKAN did not return version history for this module.")
            }
        }
    }
}

struct ModuleContentsView: View {
    let paths: [String]

    var body: some View {
        List(Array(paths.enumerated()), id: \.offset) { _, path in
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(path)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 3)
        }
        .listStyle(.inset)
        .overlay {
            if paths.isEmpty {
                EmptyDetailState(systemImage: "doc.questionmark", title: "No contents reported", detail: "Installed file paths are not available for this module.")
            }
        }
    }
}

struct ModuleResourcesView: View {
    let resources: [ModuleResource]

    var body: some View {
        List(Array(resources.enumerated()), id: \.offset) { _, resource in
            ModuleResourceRow(resource: resource)
        }
        .listStyle(.inset)
        .overlay {
            if resources.isEmpty {
                EmptyDetailState(systemImage: "link", title: "No resources reported", detail: "Homepage, source, forum, or download links are not available for this module.")
            }
        }
    }
}

private struct ModuleResourceRow: View {
    let resource: ModuleResource

    var body: some View {
        let action = ModuleHeaderAction.action(for: resource)
        if let url = URL(string: resource.url) {
            Link(destination: url) {
                resourceLabel(action: action)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        } else {
            resourceLabel(action: action)
                .padding(.vertical, 4)
        }
    }

    private func resourceLabel(action: ModuleHeaderAction) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: action.systemImage)
                .font(.callout.weight(.medium))
                .foregroundStyle(action.tint)
                .frame(width: 22, height: 22)
                .background(action.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(action.label)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(resource.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
}

struct ModuleDetailCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title.uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.3)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ModuleMetricTile: View {
    struct Item: Identifiable {
        let title: String
        let value: String
        let systemImage: String
        let tint: Color

        var id: String {
            "\(title)-\(value)-\(systemImage)"
        }
    }

    let item: Item

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 18, height: 18)
                .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.value)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
    }
}

struct FlowBadgeRow: View {
    let items: [ModuleInfoBadge.Item]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                ModuleInfoBadge(item: item)
            }
        }
    }
}

struct ModuleInfoBadge: View {
    struct Item: Identifiable {
        let title: String
        let systemImage: String
        let tint: Color

        var id: String {
            "\(title)-\(systemImage)"
        }
    }

    let item: Item

    var body: some View {
        Label(item.title, systemImage: item.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(item.tint)
            .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct EmptyDetailState: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum ModuleDetailDateFormatter {
    static func displayDate(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Not reported"
        }

        let isoWithFractions = ISO8601DateFormatter()
        isoWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoWithoutFractions = ISO8601DateFormatter()
        isoWithoutFractions.formatOptions = [.withInternetDateTime]

        if let date = isoWithFractions.date(from: trimmed) ?? isoWithoutFractions.date(from: trimmed) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return trimmed
    }
}

func firstNonEmpty(_ values: String?...) -> String? {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return nil
}

func stagedTitle(for action: StagedModAction) -> String {
    switch action {
    case .install:
        return "Queued to Install"
    case .remove:
        return "Queued to Remove"
    case .upgrade:
        return "Queued to Upgrade"
    case .replace:
        return "Queued to Replace"
    }
}

struct DetailList: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.0)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 112, alignment: .leading)
                    Text(row.1)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 7)

                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
    }
}

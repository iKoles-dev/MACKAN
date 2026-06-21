import AppKit
import SwiftUI

import MACKANKit

struct ModuleOverviewPage: View {
    let module: ModuleSummary
    let details: ModuleDetails?
    let stagedAction: StagedModAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ModuleAtAGlanceCard(metrics: overviewMetrics)

                if let descriptionText {
                    ModuleDescriptionCard(descriptionText: descriptionText)
                }

                let tagItems = detailTags.map {
                    ModuleInfoBadge.Item(title: $0, systemImage: "tag", tint: .secondary)
                }
                if !tagItems.isEmpty {
                    ModuleTagsCard(items: tagItems)
                }

                if !module.relationships.isEmpty {
                    ModuleRelationshipSummaryCard(relationships: module.relationships)
                }

                ModuleTechnicalDetailsCard(rows: technicalRows)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var overviewMetrics: [ModuleMetricTile.Item] {
        var metrics: [ModuleMetricTile.Item] = []
        if let stagedAction {
            metrics.append(.init(title: "Queued action", value: stagedTitle(for: stagedAction), systemImage: stagedAction.symbolName, tint: .accentColor))
        }
        metrics.append(.init(title: "Status", value: module.status.title, systemImage: module.status.symbolName, tint: module.status.color))
        metrics.append(.init(title: "Version", value: versionSummary, systemImage: "clock.arrow.circlepath", tint: .accentColor))
        metrics.append(.init(title: "Compatibility", value: displayValue(module.gameCompatibility), systemImage: module.isCompatible ? "checkmark.shield.fill" : "xmark.shield.fill", tint: module.isCompatible ? .blue : .red))
        metrics.append(.init(title: "License", value: displayValue(module.license), systemImage: "doc.text", tint: .secondary))
        metrics.append(.init(title: "Downloads", value: downloadCountText, systemImage: "arrow.down.circle", tint: .secondary))
        metrics.append(.init(title: "Released", value: formattedDate(details?.releaseDate ?? module.releaseDate), systemImage: "calendar", tint: .secondary))
        metrics.append(.init(title: "Size", value: sizeSummary, systemImage: "externaldrive", tint: .secondary))
        return metrics
    }

    private var technicalRows: [(String, String)] {
        var rows = [
            ("Identifier", module.identifier),
            ("Author", module.author),
            ("Status", module.status.title),
            ("Installed", module.installedVersion),
            ("Latest", module.latestVersion),
            ("License", module.license),
            ("Game Compatibility", module.gameCompatibility),
            ("Release Date", formattedDate(details?.releaseDate ?? module.releaseDate)),
            ("Install Date", formattedDate(module.installDate)),
            ("Download Count", downloadCountText),
        ]

        if let details {
            rows.append(contentsOf: [
                ("Release Status", details.releaseStatus),
                ("Kind", details.kind),
                ("Download Size", byteCount(details.downloadSize)),
                ("Install Size", byteCount(details.installSize)),
            ])
        }

        return rows.filter { !$0.1.isEmpty && $0.1 != "Not reported" }
    }

    private var versionSummary: String {
        let installed = cleanVersion(module.installedVersion)
        let latest = cleanVersion(module.latestVersion)

        switch (installed.isEmpty, latest.isEmpty) {
        case (true, true):
            return "Not reported"
        case (true, false):
            return latest
        case (false, true):
            return installed
        case (false, false) where installed == latest:
            return installed
        default:
            return "\(installed) -> \(latest)"
        }
    }

    private func cleanVersion(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "-" ? "" : trimmed
    }

    private var downloadCountText: String {
        guard let count = module.downloadCount else {
            return "Not reported"
        }
        return Self.integerFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private var sizeSummary: String {
        let download = sizeValue(details?.downloadSize, fallback: module.downloadSizeDisplay)
        let install = sizeValue(details?.installSize, fallback: module.installSizeDisplay)

        switch (download, install) {
        case ("Not reported", "Not reported"):
            return "Not reported"
        case (_, "Not reported"):
            return download
        case ("Not reported", _):
            return install
        default:
            return "\(download) download / \(install) installed"
        }
    }

    private var descriptionText: String? {
        firstNonEmpty(details?.description, module.description, details?.abstract, module.abstract)
    }

    private var detailTags: [String] {
        let combined = (details?.tags ?? []) + module.tags
        var seen = Set<String>()
        return combined.filter { tag in
            let key = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }

    private func displayValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not reported" : value
    }

    private func sizeValue(_ bytes: Int64?, fallback: String) -> String {
        if let bytes, bytes > 0 {
            return byteCount(bytes)
        }
        return fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not reported" : fallback
    }

    private func byteCount(_ bytes: Int64) -> String {
        guard bytes > 0 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func formattedDate(_ value: String) -> String {
        ModuleDetailDateFormatter.displayDate(value)
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

private struct ModuleAtAGlanceCard: View {
    let metrics: [ModuleMetricTile.Item]

    var body: some View {
        ModuleDetailCard(title: "At a glance", systemImage: "rectangle.grid.2x2") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 136), spacing: 10)], spacing: 10) {
                ForEach(metrics) { metric in
                    ModuleMetricTile(item: metric)
                }
            }
        }
    }
}

private struct ModuleDescriptionCard: View {
    let descriptionText: String

    var body: some View {
        ModuleDetailCard(title: "Description", systemImage: "text.alignleft") {
            Text(descriptionText)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ModuleTagsCard: View {
    let items: [ModuleInfoBadge.Item]

    var body: some View {
        ModuleDetailCard(title: "Tags", systemImage: "tag") {
            FlowBadgeRow(items: items)
        }
    }
}

private struct ModuleRelationshipSummaryCard: View {
    let relationships: [ModuleRelationship]

    var body: some View {
        ModuleDetailCard(title: "Relationship summary", systemImage: "point.3.connected.trianglepath.dotted") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(summaryGroups, id: \.kind) { group in
                    ModuleMetricTile(item: .init(
                        title: group.kind.capitalized,
                        value: "\(group.count)",
                        systemImage: relationshipIcon(for: group.kind),
                        tint: relationshipTint(for: group.kind)))
                }
            }
        }
    }

    private var summaryGroups: [(kind: String, count: Int)] {
        let grouped = Dictionary(grouping: relationships) { $0.kind.lowercased() }
        let preferredOrder = ["depends", "recommends", "suggests", "supports", "conflicts"]
        let ordered = preferredOrder.compactMap { kind -> (kind: String, count: Int)? in
            guard let count = grouped[kind]?.count else { return nil }
            return (kind, count)
        }
        let remaining = grouped
            .filter { !preferredOrder.contains($0.key) }
            .map { (kind: $0.key, count: $0.value.count) }
            .sorted { $0.kind < $1.kind }
        return ordered + remaining
    }

    private func relationshipIcon(for kind: String) -> String {
        switch kind.lowercased() {
        case "depends":
            return "link"
        case "recommends":
            return "checkmark.seal"
        case "suggests":
            return "lightbulb"
        case "supports":
            return "hand.thumbsup"
        case "conflicts":
            return "exclamationmark.triangle"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    private func relationshipTint(for kind: String) -> Color {
        switch kind.lowercased() {
        case "depends":
            return .blue
        case "recommends", "suggests", "supports":
            return .green
        case "conflicts":
            return .red
        default:
            return .secondary
        }
    }
}

private struct ModuleTechnicalDetailsCard: View {
    let rows: [(String, String)]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            DetailList(rows: rows)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Technical details".uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

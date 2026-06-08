import SwiftUI

import MACKANKit

struct LaunchWarningSheet: View {
    let warning: PendingLaunchWarning
    let isLaunching: Bool
    let onCancel: () -> Void
    let onLaunch: (Bool) -> Void
    @State private var suppressFutureWarnings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Incompatible Mods Installed")
                        .font(.headline)
                    Text("Launching now may make the game unstable.")
                        .foregroundStyle(.secondary)
                }
            }

            Table(warning.modules) {
                TableColumn("Mod") { module in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.name)
                            .lineLimit(1)
                        Text(module.identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                TableColumn("Installed", value: \.version)
                    .width(90)
                TableColumn("Compatible With", value: \.compatibleGameVersions)
                    .width(min: 150, ideal: 190)
            }

            Toggle("Don't show this again for these mods", isOn: $suppressFutureWarnings)

            HStack {
                Spacer()
                Button("Go Back", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    onLaunch(suppressFutureWarnings)
                } label: {
                    Label("Launch Anyway", systemImage: "play.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isLaunching)
            }
        }
        .padding()
        .mackanModalSheetFrame(.standard)
    }
}

struct InspectorView: View {
    let module: ModuleSummary?
    let details: ModuleDetails?
    let emptyState: InspectorEmptyPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let module {
                let displayModule = details?.module ?? module
                ModuleDetailHeader(module: displayModule, details: details)

                Divider()

                TabView {
                    ModuleOverviewPage(module: displayModule, details: details)
                        .tabItem { Text("Overview") }

                    RelationshipGraphView(graph: ModuleRelationshipGraph(module: displayModule))
                        .tabItem { Text("Relationships") }

                    ModuleVersionsView(module: displayModule)
                        .tabItem { Text("Versions") }

                    ModuleContentsView(paths: displayModule.contents)
                        .tabItem { Text("Contents") }

                    ModuleResourcesView(resources: details?.resources ?? [])
                        .tabItem { Text("Resources") }
                }
                .accessibilityLabel("Module details tabs")
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: emptyState.systemImage)
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(emptyState.title)
                        .font(.headline)
                    Text(emptyState.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ModuleDetailHeader: View {
    let module: ModuleSummary
    let details: ModuleDetails?

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
}

private struct ModuleOverviewPage: View {
    let module: ModuleSummary
    let details: ModuleDetails?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ModuleDetailCard(title: "Summary", systemImage: "info.circle") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ModuleMetricTile(title: "Installed", value: displayValue(module.installedVersion))
                        ModuleMetricTile(title: "Latest", value: displayValue(module.latestVersion))
                        ModuleMetricTile(title: "Compatibility", value: displayValue(module.gameCompatibility))
                        ModuleMetricTile(title: "License", value: displayValue(module.license))
                        ModuleMetricTile(title: "Download", value: sizeValue(details?.downloadSize, fallback: module.downloadSizeDisplay))
                        ModuleMetricTile(title: "Install size", value: sizeValue(details?.installSize, fallback: module.installSizeDisplay))
                    }
                }

                ModuleDetailCard(title: "Metadata", systemImage: "list.bullet.rectangle") {
                    DetailList(rows: overviewRows)
                        .frame(minHeight: 220)
                }

                if let descriptionText {
                    ModuleDetailCard(title: "Description", systemImage: "text.alignleft") {
                        Text(descriptionText)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                let tagItems = detailTags.map {
                    ModuleInfoBadge.Item(title: $0, systemImage: "tag", tint: .secondary)
                }
                if !tagItems.isEmpty {
                    ModuleDetailCard(title: "Tags", systemImage: "tag") {
                        FlowBadgeRow(items: tagItems)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var overviewRows: [(String, String)] {
        var rows = [
            ("Identifier", module.identifier),
            ("Author", module.author),
            ("Status", "\(module.status)"),
            ("Installed", module.installedVersion),
            ("Latest", module.latestVersion),
            ("License", module.license),
            ("Game Compatibility", module.gameCompatibility),
            ("Release Date", details?.releaseDate ?? module.releaseDate),
            ("Install Date", module.installDate),
            ("Download Count", module.downloadCount.map { Self.integerFormatter.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""),
        ]

        if let details {
            rows.append(contentsOf: [
                ("Release Status", details.releaseStatus),
                ("Kind", details.kind),
                ("Download Size", byteCount(details.downloadSize)),
                ("Install Size", byteCount(details.installSize)),
            ])
        }

        return rows.filter { !$0.1.isEmpty }
    }

    private var descriptionText: String? {
        firstNonEmpty(details?.description, module.description)
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
        value.isEmpty ? "Not reported" : value
    }

    private func sizeValue(_ bytes: Int64?, fallback: String) -> String {
        if let bytes, bytes > 0 {
            return byteCount(bytes)
        }
        return fallback.isEmpty ? "Not reported" : fallback
    }

    private func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

private struct ModuleVersionsView: View {
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

private struct ModuleContentsView: View {
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

private struct ModuleResourcesView: View {
    let resources: [ModuleResource]

    var body: some View {
        List(Array(resources.enumerated()), id: \.offset) { _, resource in
            if let url = URL(string: resource.url) {
                Link(destination: url) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(resource.label.isEmpty ? resource.url : resource.label)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(resource.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(resource.label.isEmpty ? "Resource" : resource.label)
                        .font(.callout.weight(.medium))
                    Text(resource.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.inset)
        .overlay {
            if resources.isEmpty {
                EmptyDetailState(systemImage: "link", title: "No resources reported", detail: "Homepage, source, forum, or download links are not available for this module.")
            }
        }
    }
}

private struct ModuleDetailCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ModuleMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FlowBadgeRow: View {
    let items: [ModuleInfoBadge.Item]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                ModuleInfoBadge(item: item)
            }
        }
    }
}

private struct ModuleInfoBadge: View {
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

private struct EmptyDetailState: View {
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

private func firstNonEmpty(_ values: String?...) -> String? {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return nil
}

private struct DetailList: View {
    let rows: [(String, String)]

    var body: some View {
        List(Array(rows.enumerated()), id: \.offset) { _, row in
            VStack(alignment: .leading, spacing: 4) {
                Text(row.0)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.1)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 3)
        }
        .listStyle(.inset)
    }
}

private struct RelationshipGraphView: View {
    let graph: ModuleRelationshipGraph

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RelationshipGraphNodeView(
                    title: graph.center.title,
                    subtitle: graph.center.subtitle,
                    systemImage: "shippingbox.fill",
                    tint: .accentColor)

                if graph.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        Text("No relationships")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(graph.edges) { edge in
                            if let node = relatedNode(for: edge.targetID) {
                                HStack(alignment: .center, spacing: 10) {
                                    RelationshipKindBadge(kind: edge.kind)
                                        .frame(width: 92, alignment: .leading)

                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)

                                    RelationshipGraphNodeView(
                                        title: node.title,
                                        subtitle: edge.title,
                                        systemImage: "shippingbox",
                                        tint: tint(for: edge.kind))
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(graph.center.title) \(edge.kind) \(node.title)")
                            }
                        }
                    }
                    .padding(.leading, 12)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func relatedNode(for id: ModuleRelationshipGraphNode.ID) -> ModuleRelationshipGraphNode? {
        graph.relatedNodes.first { $0.id == id }
    }

    private func tint(for kind: String) -> Color {
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

private struct RelationshipGraphNodeView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct RelationshipKindBadge: View {
    let kind: String

    var body: some View {
        Text(kind)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var foreground: Color {
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

    private var background: Color {
        foreground.opacity(0.12)
    }
}

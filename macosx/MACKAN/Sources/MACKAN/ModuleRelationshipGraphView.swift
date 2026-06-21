import AppKit
import SwiftUI

import MACKANKit

struct RelationshipGraphView: View {
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
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedEdges, id: \.kind) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 5) {
                                    RelationshipKindBadge(kind: group.kind)
                                    Text("\(group.edges.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(group.edges) { edge in
                                        if let node = relatedNode(for: edge.targetID) {
                                            HStack(alignment: .center, spacing: 8) {
                                                Image(systemName: "arrow.turn.down.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                                    .accessibilityHidden(true)

                                                RelationshipGraphNodeView(
                                                    title: node.title,
                                                    subtitle: node.subtitle,
                                                    systemImage: "shippingbox",
                                                    tint: tint(for: group.kind))
                                            }
                                            .accessibilityElement(children: .combine)
                                            .accessibilityLabel("\(graph.center.title) \(group.kind) \(node.title)")
                                        }
                                    }
                                }
                                .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var groupedEdges: [(kind: String, edges: [ModuleRelationshipGraphEdge])] {
        let preferredOrder = ["depends", "recommends", "suggests", "supports", "conflicts"]
        var grouped: [String: [ModuleRelationshipGraphEdge]] = [:]
        for edge in graph.edges {
            grouped[edge.kind.lowercased(), default: []].append(edge)
        }
        let ordered = preferredOrder.compactMap { kind -> (kind: String, edges: [ModuleRelationshipGraphEdge])? in
            guard let edges = grouped[kind], !edges.isEmpty else { return nil }
            return (kind: kind, edges: edges)
        }
        let remaining = grouped
            .filter { !preferredOrder.contains($0.key) }
            .map { (kind: $0.key, edges: $0.value) }
            .sorted { $0.kind < $1.kind }
        return ordered + remaining
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

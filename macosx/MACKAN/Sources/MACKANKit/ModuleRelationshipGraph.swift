import Foundation

public struct ModuleRelationshipGraphNode: Identifiable, Equatable, Sendable {
    public enum Role: String, Equatable, Sendable {
        case center
        case related
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let role: Role

    public init(id: String, title: String, subtitle: String, role: Role) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.role = role
    }
}

public struct ModuleRelationshipGraphEdge: Identifiable, Equatable, Sendable {
    public let id: String
    public let sourceID: String
    public let targetID: String
    public let kind: String
    public let title: String

    public init(id: String, sourceID: String, targetID: String, kind: String, title: String) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.kind = kind
        self.title = title
    }
}

public struct ModuleRelationshipGraph: Equatable, Sendable {
    public let center: ModuleRelationshipGraphNode
    public let relatedNodes: [ModuleRelationshipGraphNode]
    public let edges: [ModuleRelationshipGraphEdge]

    public init(module: ModuleSummary) {
        let sourceID = "module:\(module.identifier)"
        center = ModuleRelationshipGraphNode(
            id: sourceID,
            title: module.name,
            subtitle: module.identifier,
            role: .center)

        var seenNodeIDs = Set<String>()
        var seenEdgeIDs = Set<String>()
        var nodes: [ModuleRelationshipGraphNode] = []
        var graphEdges: [ModuleRelationshipGraphEdge] = []

        for relationship in module.relationships {
            let target = relationship.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = relationship.kind.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty, !kind.isEmpty else {
                continue
            }

            let targetID = "relationship:\(Self.normalizedIDComponent(target))"
            if seenNodeIDs.insert(targetID).inserted {
                nodes.append(ModuleRelationshipGraphNode(
                    id: targetID,
                    title: target,
                    subtitle: "Related module",
                    role: .related))
            }

            let edgeID = "\(sourceID)->\(targetID):\(Self.normalizedIDComponent(kind))"
            guard seenEdgeIDs.insert(edgeID).inserted else {
                continue
            }

            graphEdges.append(ModuleRelationshipGraphEdge(
                id: edgeID,
                sourceID: sourceID,
                targetID: targetID,
                kind: kind,
                title: "\(kind) \(target)"))
        }

        relatedNodes = nodes
        edges = graphEdges
    }

    public var isEmpty: Bool {
        edges.isEmpty
    }

    private static func normalizedIDComponent(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

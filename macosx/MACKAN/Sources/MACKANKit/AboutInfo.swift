public struct AboutInfoRow: Equatable, Identifiable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var id: String {
        label
    }
}

public struct AboutInfo: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let rows: [AboutInfoRow]

    public init(title: String, subtitle: String, rows: [AboutInfoRow]) {
        self.title = title
        self.subtitle = subtitle
        self.rows = rows
    }
}

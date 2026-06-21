public struct OperationTimelinePresentationState: Equatable, Sendable {
    public let events: [OperationEvent]

    public init(result: OperationResult) {
        if Self.isActive(status: result.status) {
            events = result.events
        } else {
            events = Self.pruningSupersededZeroProgressEvents(from: result.events)
        }
    }

    private static func isActive(status: String) -> Bool {
        status == "running" || status == "cancelling"
    }

    private static func pruningSupersededZeroProgressEvents(from events: [OperationEvent]) -> [OperationEvent] {
        let meaningfulKeys = Set(events.compactMap { event -> EventKey? in
            guard event.hasMeaningfulProgress else {
                return nil
            }
            return EventKey(event)
        })
        let hasMeaningfulProgress = events.contains { $0.hasMeaningfulProgress }

        return events.filter { event in
            guard event.isZeroProgressEvent else {
                return true
            }
            guard hasMeaningfulProgress else {
                return true
            }
            guard event.identifier != nil else {
                return false
            }
            return !meaningfulKeys.contains(EventKey(event))
        }
    }
}

public struct OperationProgressPresentationState: Equatable, Sendable {
    public let rows: [OperationProgressRow]
    public let currentActivity: String?
    public let events: [OperationEvent]

    public init(result: OperationResult) {
        events = OperationTimelinePresentationState(result: result).events
        currentActivity = result.events
            .last(where: { !$0.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .message

        let latestEventsByIdentifier = Self.latestEventsByIdentifier(from: result.events)
        var seenIdentifiers = Set<String>()

        var rows = result.changes.map { change in
            seenIdentifiers.insert(Self.normalized(change.identifier))
            return OperationProgressRow(
                change: change,
                event: latestEventsByIdentifier[Self.normalized(change.identifier)],
                operationStatus: result.status)
        }

        for event in result.events {
            guard let identifier = event.identifier, !identifier.isEmpty else {
                continue
            }
            let normalizedIdentifier = Self.normalized(identifier)
            guard !seenIdentifiers.contains(normalizedIdentifier) else {
                continue
            }
            rows.append(OperationProgressRow(
                identifier: identifier,
                title: event.message.isEmpty ? identifier : event.message,
                subtitle: identifier,
                event: latestEventsByIdentifier[normalizedIdentifier],
                operationStatus: result.status))
            seenIdentifiers.insert(normalizedIdentifier)
        }

        self.rows = rows
    }

    private static func latestEventsByIdentifier(from events: [OperationEvent]) -> [String: OperationEvent] {
        events.reduce(into: [:]) { partialResult, event in
            guard let identifier = event.identifier, !identifier.isEmpty else {
                return
            }
            partialResult[normalized(identifier)] = event
        }
    }

    private static func normalized(_ identifier: String) -> String {
        identifier.lowercased()
    }
}

public struct OperationProgressRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let phase: OperationProgressPhase
    public let progressFraction: Double?
    public let byteProgressDisplay: String?
    public let detail: String?

    init(change: ChangeSummary, event: OperationEvent?, operationStatus: String) {
        id = change.identifier
        title = change.name
        subtitle = Self.subtitle(for: change)
        phase = OperationProgressPhase(event: event, operationStatus: operationStatus, action: change.action)
        progressFraction = Self.progressFraction(event: event, phase: phase)
        byteProgressDisplay = event?.byteProgressDisplay
        detail = Self.detail(from: event, title: change.name)
    }

    init(
        identifier: String,
        title: String,
        subtitle: String,
        event: OperationEvent?,
        operationStatus: String
    ) {
        id = identifier
        self.title = title
        self.subtitle = subtitle
        phase = OperationProgressPhase(event: event, operationStatus: operationStatus, action: nil)
        progressFraction = Self.progressFraction(event: event, phase: phase)
        byteProgressDisplay = event?.byteProgressDisplay
        detail = Self.detail(from: event, title: title)
    }

    private static func subtitle(for change: ChangeSummary) -> String {
        let action = change.action.capitalized
        switch change.action {
        case "install":
            return [action, change.toVersion].compactMap(\.self).joined(separator: " ")
        case "upgrade":
            if let fromVersion = change.fromVersion, let toVersion = change.toVersion {
                return "\(action) \(fromVersion) to \(toVersion)"
            }
            return [action, change.toVersion].compactMap(\.self).joined(separator: " ")
        case "replace":
            return [action, change.toVersion].compactMap(\.self).joined(separator: " ")
        case "remove":
            return [action, change.fromVersion].compactMap(\.self).joined(separator: " ")
        default:
            return [action, change.toVersion ?? change.fromVersion].compactMap(\.self).joined(separator: " ")
        }
    }

    private static func progressFraction(event: OperationEvent?, phase: OperationProgressPhase) -> Double? {
        if phase == .completed {
            return 1
        }
        return event?.progressFraction
    }

    private static func detail(from event: OperationEvent?, title: String) -> String? {
        guard let message = event?.message.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty,
              message.localizedCaseInsensitiveCompare(title) != .orderedSame
        else {
            return nil
        }
        return message
    }
}

public enum OperationProgressPhase: Equatable, Sendable {
    case queued
    case downloading
    case validating
    case installing
    case removing
    case completed
    case failed
    case cancelling
    case cancelled

    init(event: OperationEvent?, operationStatus: String, action: String?) {
        switch operationStatus {
        case "completed":
            self = .completed
            return
        case "failed":
            self = .failed
            return
        case "cancelling":
            self = .cancelling
            return
        case "cancelled":
            self = .cancelled
            return
        default:
            break
        }

        switch event?.kind {
        case "downloadProgress":
            self = .downloading
        case "storeProgress":
            self = .validating
        case "installProgress":
            self = .installing
        case "removeProgress":
            self = .removing
        case "complete":
            self = .completed
        case "error":
            self = .failed
        default:
            if action == "remove" {
                self = .removing
            } else {
                self = .queued
            }
        }
    }
}

private struct EventKey: Hashable {
    let kind: String
    let identifier: String?

    init(_ event: OperationEvent) {
        kind = event.kind
        identifier = event.identifier
    }
}

private extension OperationEvent {
    var isZeroProgressEvent: Bool {
        percent == 0 && completedBytes == 0
    }

    var hasMeaningfulProgress: Bool {
        if kind == "complete" {
            return true
        }
        if let percent, percent > 0 {
            return true
        }
        if let completedBytes, completedBytes > 0 {
            return true
        }
        return false
    }

    var completedBytes: Int64? {
        guard let remainingBytes, let totalBytes, totalBytes > 0 else {
            return nil
        }
        return max(0, totalBytes - max(0, remainingBytes))
    }
}

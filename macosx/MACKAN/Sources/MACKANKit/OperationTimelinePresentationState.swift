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

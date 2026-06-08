import Foundation

public struct DownloadStatisticsChartSegment: Identifiable, Equatable, Sendable {
    public let host: String
    public let bytes: Int64
    public let display: String
    public let fraction: Double

    public var id: String { host }

    public init(host: String, bytes: Int64, display: String, fraction: Double) {
        self.host = host
        self.bytes = bytes
        self.display = display
        self.fraction = fraction
    }

    public static func segments(for result: DownloadStatisticsResult) -> [DownloadStatisticsChartSegment] {
        let positiveHosts = result.hosts
            .filter { $0.bytes > 0 }
            .sorted {
                if $0.bytes == $1.bytes {
                    return $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending
                }
                return $0.bytes > $1.bytes
            }

        let positiveTotal = positiveHosts.reduce(Int64(0)) { $0 + $1.bytes }
        let denominator = max(result.totalBytes, positiveTotal)
        guard denominator > 0 else {
            return []
        }

        return positiveHosts.map { host in
            DownloadStatisticsChartSegment(
                host: host.host,
                bytes: host.bytes,
                display: host.display,
                fraction: min(1, max(0, Double(host.bytes) / Double(denominator))))
        }
    }
}

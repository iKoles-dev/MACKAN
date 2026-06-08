import XCTest

@testable import MACKANKit

final class DownloadStatisticsChartTests: XCTestCase {
    func testChartSegmentsSortHostsByCachedBytesAndIgnoreEmptyHosts() {
        let result = DownloadStatisticsResult(
            instanceId: "primary",
            hosts: [
                DownloadStatisticsHost(host: "archive.org", bytes: 512, display: "512 bytes"),
                DownloadStatisticsHost(host: "empty.example", bytes: 0, display: "0 bytes"),
                DownloadStatisticsHost(host: "spacedock.info", bytes: 1536, display: "1.5 KiB"),
            ],
            totalBytes: 2048,
            totalDisplay: "2 KiB")

        let segments = DownloadStatisticsChartSegment.segments(for: result)

        XCTAssertEqual(segments.map(\.host), ["spacedock.info", "archive.org"])
        XCTAssertEqual(segments.map(\.bytes), [1536, 512])
        XCTAssertEqual(segments.map(\.display), ["1.5 KiB", "512 bytes"])
        XCTAssertEqual(segments.map(\.fraction), [0.75, 0.25])
    }

    func testChartSegmentsFallBackToPositiveHostTotalWhenReportedTotalIsMissing() {
        let result = DownloadStatisticsResult(
            instanceId: nil,
            hosts: [
                DownloadStatisticsHost(host: "first.example", bytes: 30, display: "30 bytes"),
                DownloadStatisticsHost(host: "second.example", bytes: 70, display: "70 bytes"),
            ],
            totalBytes: 0,
            totalDisplay: "0 bytes")

        let segments = DownloadStatisticsChartSegment.segments(for: result)

        XCTAssertEqual(segments.map(\.host), ["second.example", "first.example"])
        XCTAssertEqual(segments.map(\.fraction), [0.7, 0.3])
    }

    func testChartSegmentsUseHostTotalWhenReportedTotalIsSmallerThanHosts() {
        let result = DownloadStatisticsResult(
            instanceId: nil,
            hosts: [
                DownloadStatisticsHost(host: "first.example", bytes: 40, display: "40 bytes"),
                DownloadStatisticsHost(host: "second.example", bytes: 60, display: "60 bytes"),
            ],
            totalBytes: 50,
            totalDisplay: "50 bytes")

        let segments = DownloadStatisticsChartSegment.segments(for: result)

        XCTAssertEqual(segments.map(\.fraction), [0.6, 0.4])
        XCTAssertEqual(segments.reduce(0) { $0 + $1.fraction }, 1, accuracy: 0.0001)
    }

    func testKnownDonationHostsExposeSupportLinks() {
        XCTAssertEqual(
            DownloadStatisticsHost(host: "spacedock.info", bytes: 1, display: "1 byte").donationURL?.absoluteString,
            "https://www.patreon.com/spacedock")
        XCTAssertEqual(
            DownloadStatisticsHost(host: "archive.org", bytes: 1, display: "1 byte").donationURL?.absoluteString,
            "https://archive.org/donate")
        XCTAssertNil(DownloadStatisticsHost(host: "example.invalid", bytes: 1, display: "1 byte").donationURL)
    }
}

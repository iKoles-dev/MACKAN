import XCTest

@testable import MACKANKit

@MainActor
final class DiagnosticsBundleTests: XCTestCase {
    func testDiagnosticsBundleWritesReportSnapshotAndArchive() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MACKAN-DiagnosticsBundleTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let model = AppModel(sidecar: FakeSidecar())
        await model.refresh()
        model.searchText = "Sidecar"
        var archivedDirectoryURL: URL?
        var archivedOutputURL: URL?

        let result = try model.writeDiagnosticsBundle(
            to: rootURL,
            generatedAt: Date(timeIntervalSince1970: 0),
            operatingSystemVersion: "macOS test",
            appVersion: "1.0-test",
            archive: { directoryURL, outputURL in
                archivedDirectoryURL = directoryURL
                archivedOutputURL = outputURL
                try "archive placeholder".write(to: outputURL, atomically: true, encoding: .utf8)
            })

        XCTAssertEqual(result.directoryURL.lastPathComponent, "MACKAN-Diagnostics-19700101T000000Z")
        XCTAssertEqual(result.archiveURL.lastPathComponent, "MACKAN-Diagnostics-19700101T000000Z.zip")
        XCTAssertEqual(archivedDirectoryURL, result.directoryURL)
        XCTAssertEqual(archivedOutputURL, result.archiveURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.archiveURL.path))

        let report = try String(contentsOf: result.reportURL, encoding: .utf8)
        XCTAssertTrue(report.contains("MACKAN App: 1.0-test"))
        XCTAssertTrue(report.contains("Search: Sidecar"))

        let snapshotData = try Data(contentsOf: result.snapshotURL)
        let snapshot = try JSONDecoder().decode(DiagnosticsSnapshot.self, from: snapshotData)
        XCTAssertEqual(snapshot.appVersion, "1.0-test")
        XCTAssertEqual(snapshot.operatingSystemVersion, "macOS test")
        XCTAssertEqual(snapshot.selectedInstance?.name, "Primary KSP")
        XCTAssertEqual(snapshot.selectedModuleID, "SidecarOnlyMod")
        XCTAssertEqual(snapshot.repositories.map(\.name), ["default"])
        XCTAssertEqual(snapshot.sidecarHealth?.ckanVersion, "v1.36.5-test")
        XCTAssertEqual(snapshot.sidecarVersion?.serviceVersion, "1.36.5-test")
        XCTAssertEqual(snapshot.sidecarVersion?.dotnetVersion, "10.0-test")
    }
}

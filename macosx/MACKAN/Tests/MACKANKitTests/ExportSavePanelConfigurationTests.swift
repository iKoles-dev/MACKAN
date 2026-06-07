import XCTest

@testable import MACKANKit

final class ExportSavePanelConfigurationTests: XCTestCase {
    func testModListExportUsesDownloadsAsDefaultDirectory() {
        let downloadsURL = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)

        let configuration = ExportSavePanelConfiguration.modList(
            suggestedFileName: "Instance-mods.txt",
            fileExtension: "txt",
            defaultDirectoryURL: downloadsURL)

        XCTAssertEqual(configuration.title, "Export Mod List")
        XCTAssertEqual(configuration.prompt, "Export")
        XCTAssertEqual(configuration.suggestedFileName, "Instance-mods.txt")
        XCTAssertEqual(configuration.allowedFileExtension, "txt")
        XCTAssertEqual(configuration.defaultDirectoryURL, downloadsURL)
        XCTAssertTrue(configuration.canCreateDirectories)
    }
}

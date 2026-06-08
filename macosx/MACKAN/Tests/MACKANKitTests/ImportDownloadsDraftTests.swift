import XCTest

@testable import MACKANKit

final class ImportDownloadsDraftTests: XCTestCase {
    func testDefaultsMatchImportDownloadsPreviewFlow() {
        let draft = ImportDownloadsDraft()

        XCTAssertTrue(draft.installImportedModules)
        XCTAssertFalse(draft.deleteImportedFiles)
        XCTAssertTrue(draft.previewBeforeInstall)
        XCTAssertEqual(draft.options, ImportDownloadsOptions(
            installImportedModules: true,
            deleteImportedFiles: false,
            previewBeforeInstall: true))
    }

    func testOptionsDisablePreviewWhenInstallIsDisabled() {
        let draft = ImportDownloadsDraft(
            installImportedModules: false,
            deleteImportedFiles: true,
            previewBeforeInstall: true)

        XCTAssertEqual(draft.options, ImportDownloadsOptions(
            installImportedModules: false,
            deleteImportedFiles: true,
            previewBeforeInstall: false))
    }

    func testResetRestoresInteractiveImportDefaults() {
        var draft = ImportDownloadsDraft(
            installImportedModules: false,
            deleteImportedFiles: true,
            previewBeforeInstall: false)

        draft.reset()

        XCTAssertEqual(draft, ImportDownloadsDraft())
    }
}

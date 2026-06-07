import XCTest

@testable import MACKANKit

final class FileImportFlowStateTests: XCTestCase {
    func testCkanFilePanelConfigurationLimitsSelectionToCkanFiles() {
        let configuration = FileImportPanelConfiguration.ckanFileInstall

        XCTAssertEqual(configuration.title, "Install from CKAN File")
        XCTAssertEqual(configuration.prompt, "Install")
        XCTAssertEqual(configuration.allowedFileExtensions, ["ckan"])
        XCTAssertTrue(configuration.allowsMultipleSelection)
        XCTAssertTrue(configuration.canChooseFiles)
        XCTAssertFalse(configuration.canChooseDirectories)
    }

    func testImportDownloadsPanelConfigurationAllowsArchivesAndFolders() {
        let configuration = FileImportPanelConfiguration.importDownloads

        XCTAssertEqual(configuration.title, "Import Downloads")
        XCTAssertEqual(configuration.prompt, "Import")
        XCTAssertEqual(configuration.allowedFileExtensions, ["zip"])
        XCTAssertTrue(configuration.allowsMultipleSelection)
        XCTAssertTrue(configuration.canChooseFiles)
        XCTAssertTrue(configuration.canChooseDirectories)
    }

    func testCkanSelectionResetsDraftAndCompletedInstallClearsRetryState() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.ckan")
        let secondURL = URL(fileURLWithPath: "/tmp/second.ckan")
        var state = FileImportFlowState(
            pendingCkanFileURLs: [firstURL],
            ckanFileDraft: CkanFileInstallDraft(
                recommendationSelections: ["VisualPack"],
                skipRecommendations: true,
                allowIncompatibleCkanFiles: true))

        state.beginCkanFileSelection([secondURL])

        XCTAssertEqual(state.pendingCkanFileURLs, [secondURL])
        XCTAssertEqual(state.ckanFileDraft, CkanFileInstallDraft())

        state.recordCkanFileOperationURLs([])
        XCTAssertEqual(state.pendingCkanFileURLs, [secondURL])

        state.finishCkanFileInstallIfCompleted(status: "failed")
        XCTAssertEqual(state.pendingCkanFileURLs, [secondURL])

        state.finishCkanFileInstallIfCompleted(status: "completed")
        XCTAssertTrue(state.pendingCkanFileURLs.isEmpty)
        XCTAssertEqual(state.ckanFileDraft, CkanFileInstallDraft())
    }

    func testImportDownloadsOptionsLifecycleReturnsStableRequestAndSupportsCancel() {
        let downloadURL = URL(fileURLWithPath: "/tmp/download.zip")
        var state = FileImportFlowState(
            pendingImportDownloadURLs: [URL(fileURLWithPath: "/tmp/old.zip")],
            importDownloadsDraft: ImportDownloadsDraft(
                installImportedModules: false,
                deleteImportedFiles: true,
                previewBeforeInstall: false))

        state.beginImportDownloadsSelection([downloadURL])

        XCTAssertEqual(state.pendingImportDownloadURLs, [downloadURL])
        XCTAssertEqual(state.importDownloadsDraft, ImportDownloadsDraft())
        XCTAssertTrue(state.isShowingImportDownloadsOptions)

        state.importDownloadsDraft.installImportedModules = false
        state.importDownloadsDraft.deleteImportedFiles = true

        let request = state.confirmImportDownloadsOptions()

        XCTAssertEqual(request.urls, [downloadURL])
        XCTAssertEqual(request.options, ImportDownloadsOptions(
            installImportedModules: false,
            deleteImportedFiles: true,
            previewBeforeInstall: false))
        XCTAssertFalse(state.isShowingImportDownloadsOptions)

        state.cancelImportDownloadsOptions()

        XCTAssertTrue(state.pendingImportDownloadURLs.isEmpty)
        XCTAssertFalse(state.isShowingImportDownloadsOptions)
    }

    func testCompletedImportClearsPendingDownloadsButIncompleteImportPreservesRetryState() {
        let downloadURL = URL(fileURLWithPath: "/tmp/download.zip")
        var state = FileImportFlowState(pendingImportDownloadURLs: [downloadURL])

        state.recordImportDownloadsOperationURLs([])
        XCTAssertEqual(state.pendingImportDownloadURLs, [downloadURL])

        state.finishImportDownloadsIfCompleted(status: "failed")
        XCTAssertEqual(state.pendingImportDownloadURLs, [downloadURL])

        state.finishImportDownloadsIfCompleted(status: "completed")
        XCTAssertTrue(state.pendingImportDownloadURLs.isEmpty)
    }
}

import Foundation

public struct FileImportFlowState: Equatable, Sendable {
    public private(set) var pendingCkanFileURLs: [URL]
    public var ckanFileDraft: CkanFileInstallDraft
    public private(set) var pendingImportDownloadURLs: [URL]
    public var importDownloadsDraft: ImportDownloadsDraft
    public var isShowingImportDownloadsOptions: Bool

    public init(
        pendingCkanFileURLs: [URL] = [],
        ckanFileDraft: CkanFileInstallDraft = CkanFileInstallDraft(),
        pendingImportDownloadURLs: [URL] = [],
        importDownloadsDraft: ImportDownloadsDraft = ImportDownloadsDraft(),
        isShowingImportDownloadsOptions: Bool = false
    ) {
        self.pendingCkanFileURLs = pendingCkanFileURLs
        self.ckanFileDraft = ckanFileDraft
        self.pendingImportDownloadURLs = pendingImportDownloadURLs
        self.importDownloadsDraft = importDownloadsDraft
        self.isShowingImportDownloadsOptions = isShowingImportDownloadsOptions
    }

    public mutating func beginCkanFileSelection(_ urls: [URL]) {
        pendingCkanFileURLs = urls
        ckanFileDraft.reset()
    }

    public mutating func recordCkanFileOperationURLs(_ urls: [URL]) {
        if !urls.isEmpty {
            pendingCkanFileURLs = urls
        }
    }

    public mutating func finishCkanFileInstallIfCompleted(status: String?) {
        guard status == "completed" else {
            return
        }
        pendingCkanFileURLs = []
        ckanFileDraft.reset()
    }

    public mutating func selectCkanProvider(choice: ProviderChoice, option: ProviderOption) {
        ckanFileDraft.selectProvider(choice: choice, option: option)
    }

    public mutating func selectCkanRecommendation(_ choice: RecommendationChoice) {
        ckanFileDraft.selectRecommendation(choice)
    }

    public mutating func skipCkanRecommendations() {
        ckanFileDraft.skipAllRecommendations()
    }

    public mutating func allowIncompatibleCkanFiles() {
        ckanFileDraft.allowIncompatibleFiles()
    }

    public mutating func beginImportDownloadsSelection(_ urls: [URL]) {
        pendingImportDownloadURLs = urls
        importDownloadsDraft.reset()
        isShowingImportDownloadsOptions = true
    }

    public mutating func cancelImportDownloadsOptions() {
        pendingImportDownloadURLs = []
        isShowingImportDownloadsOptions = false
    }

    public mutating func confirmImportDownloadsOptions() -> (urls: [URL], options: ImportDownloadsOptions) {
        isShowingImportDownloadsOptions = false
        return (pendingImportDownloadURLs, importDownloadsDraft.options)
    }

    public mutating func recordImportDownloadsOperationURLs(_ urls: [URL]) {
        if !urls.isEmpty {
            pendingImportDownloadURLs = urls
        }
    }

    public mutating func finishImportDownloadsIfCompleted(status: String?) {
        guard status == "completed" else {
            return
        }
        pendingImportDownloadURLs = []
    }
}

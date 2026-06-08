public struct ImportDownloadsDraft: Equatable, Sendable {
    public var installImportedModules: Bool
    public var deleteImportedFiles: Bool
    public var previewBeforeInstall: Bool

    public init(
        installImportedModules: Bool = true,
        deleteImportedFiles: Bool = false,
        previewBeforeInstall: Bool = true
    ) {
        self.installImportedModules = installImportedModules
        self.deleteImportedFiles = deleteImportedFiles
        self.previewBeforeInstall = previewBeforeInstall
    }

    public var options: ImportDownloadsOptions {
        ImportDownloadsOptions(
            installImportedModules: installImportedModules,
            deleteImportedFiles: deleteImportedFiles,
            previewBeforeInstall: installImportedModules && previewBeforeInstall)
    }

    public mutating func reset() {
        installImportedModules = true
        deleteImportedFiles = false
        previewBeforeInstall = true
    }
}

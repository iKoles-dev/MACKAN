public struct ImportDownloadsOptions: Equatable, Sendable {
    public let installImportedModules: Bool
    public let deleteImportedFiles: Bool
    public let previewBeforeInstall: Bool

    public init(
        installImportedModules: Bool = true,
        deleteImportedFiles: Bool = false,
        previewBeforeInstall: Bool = false
    ) {
        self.installImportedModules = installImportedModules
        self.deleteImportedFiles = deleteImportedFiles
        self.previewBeforeInstall = previewBeforeInstall
    }
}

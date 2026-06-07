import Foundation

public struct ExportSavePanelConfiguration: Equatable, Sendable {
    public let title: String
    public let prompt: String
    public let suggestedFileName: String
    public let allowedFileExtension: String
    public let defaultDirectoryURL: URL?
    public let canCreateDirectories: Bool

    public init(
        title: String,
        prompt: String,
        suggestedFileName: String,
        allowedFileExtension: String,
        defaultDirectoryURL: URL?,
        canCreateDirectories: Bool
    ) {
        self.title = title
        self.prompt = prompt
        self.suggestedFileName = suggestedFileName
        self.allowedFileExtension = allowedFileExtension
        self.defaultDirectoryURL = defaultDirectoryURL
        self.canCreateDirectories = canCreateDirectories
    }

    public static func modList(
        suggestedFileName: String,
        fileExtension: String,
        defaultDirectoryURL: URL?
    ) -> ExportSavePanelConfiguration {
        ExportSavePanelConfiguration(
            title: "Export Mod List",
            prompt: "Export",
            suggestedFileName: suggestedFileName,
            allowedFileExtension: fileExtension,
            defaultDirectoryURL: defaultDirectoryURL,
            canCreateDirectories: true)
    }
}

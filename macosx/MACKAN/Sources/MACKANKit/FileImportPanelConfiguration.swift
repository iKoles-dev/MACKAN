public struct FileImportPanelConfiguration: Equatable, Sendable {
    public let title: String
    public let prompt: String
    public let allowedFileExtensions: [String]
    public let allowsMultipleSelection: Bool
    public let canChooseFiles: Bool
    public let canChooseDirectories: Bool

    public init(
        title: String,
        prompt: String,
        allowedFileExtensions: [String],
        allowsMultipleSelection: Bool,
        canChooseFiles: Bool,
        canChooseDirectories: Bool
    ) {
        self.title = title
        self.prompt = prompt
        self.allowedFileExtensions = allowedFileExtensions
        self.allowsMultipleSelection = allowsMultipleSelection
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
    }

    public static let ckanFileInstall = FileImportPanelConfiguration(
        title: "Install from CKAN File",
        prompt: "Install",
        allowedFileExtensions: ["ckan"],
        allowsMultipleSelection: true,
        canChooseFiles: true,
        canChooseDirectories: false)

    public static let importDownloads = FileImportPanelConfiguration(
        title: "Import Downloads",
        prompt: "Import",
        allowedFileExtensions: ["zip"],
        allowsMultipleSelection: true,
        canChooseFiles: true,
        canChooseDirectories: true)
}

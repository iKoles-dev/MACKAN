import Foundation

public typealias DiagnosticsArchiveAction = (_ directoryURL: URL, _ outputURL: URL) throws -> Void

public struct DiagnosticsBundleResult: Equatable {
    public let directoryURL: URL
    public let reportURL: URL
    public let snapshotURL: URL
    public let archiveURL: URL
}

public struct DiagnosticsSnapshot: Codable, Equatable {
    public let generatedAt: String
    public let appVersion: String
    public let operatingSystemVersion: String
    public let sidecarHealth: SidecarHealth?
    public let sidecarVersion: SidecarVersion?
    public let selectedInstance: GameInstanceSummary?
    public let selectedModuleID: String?
    public let instancesCount: Int
    public let modulesCount: Int
    public let repositories: [RepositorySummary]
    public let searchText: String
    public let filter: String
    public let tagFilter: String?
    public let sort: String
    public let sortAscending: Bool
    public let secondarySorts: [ModuleSortCriterion]
    public let changeSetError: String?
    public let operationError: String?
    public let operationErrorDetails: SidecarErrorDetails?
    public let lastOperationResult: OperationResult?
    public let maintenanceError: String?
    public let settingsError: String?
}

public enum DiagnosticsBundleError: LocalizedError, Equatable {
    case archiveFailed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .archiveFailed(let status, let message):
            return "Diagnostics archive failed with exit code \(status): \(message)"
        }
    }
}

public enum DiagnosticsBundleArchiver {
    public static func archiveWithDitto(directoryURL: URL, outputURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            directoryURL.path,
            outputURL.path,
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Unknown ditto failure"
            throw DiagnosticsBundleError.archiveFailed(
                status: process.terminationStatus,
                message: message.isEmpty ? "Unknown ditto failure" : message)
        }
    }
}

@MainActor
public extension AppModel {
    func makeDiagnosticsReport(
        generatedAt: Date = Date(),
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    ) -> String {
        var lines: [String] = [
            "# MACKAN Diagnostics",
            "",
            "Generated: \(Self.diagnosticsTimestamp(generatedAt))",
            "MACKAN App: \(appVersion)",
            "macOS: \(operatingSystemVersion)",
            "Sidecar: \(diagnosticsHealthSummary)",
            "Sidecar Runtime: \(diagnosticsVersionSummary)",
            "",
            "## Selection",
        ]

        if let selectedInstance {
            lines.append("Selected Instance: \(selectedInstance.name) (\(selectedInstance.game) \(selectedInstance.gameVersion))")
            lines.append("Instance Path: \(selectedInstance.path)")
            lines.append("Instance Valid: \(selectedInstance.isValid)")
            lines.append("Instance Maybe Locked: \(selectedInstance.isMaybeLocked)")
        } else {
            lines.append("Selected Instance: -")
        }

        lines += [
            "Selected Module: \(selectedModuleID ?? "-")",
            "",
            "## Catalog",
            "Instances: \(instances.count)",
            "Repositories: \(repositories.map { $0.name }.joined(separator: ", ").nilIfEmpty ?? "-")",
            "Modules Loaded: \(modules.count)",
            "Search: \(searchText.nilIfEmpty ?? "-")",
            "Filter: \(filter.title)",
            "Tag Filter: \(tagFilter ?? "-")",
            "Sort: \(moduleSort.title) \(moduleSortAscending ? "ascending" : "descending")",
            "Secondary Sorts: \(diagnosticsSecondarySortSummary)",
            "",
            "## Recent Errors",
            "Change Set Error: \(changeSetError ?? "-")",
            "Operation Error: \(operationError ?? "-")",
            "Operation Error Details: \(diagnosticsErrorDetailsSummary(operationErrorDetails))",
            "Maintenance Error: \(maintenanceError ?? "-")",
            "Settings Error: \(settingsError ?? "-")",
        ]

        if let operation = lastOperationResult {
            lines += [
                "",
                "## Last Operation",
                "Operation ID: \(operation.operationId)",
                "Operation Instance: \(operation.instanceId ?? "-")",
                "Operation Status: \(operation.status)",
                "Operation Changes: \(operation.changes.map { "\($0.identifier):\($0.action)" }.joined(separator: ", ").nilIfEmpty ?? "-")",
            ]
            lines += operation.events.map(diagnosticsOperationEventLine)
            lines += diagnosticsDownloadFailureLines(operation.errorDetails)
        }

        return lines.joined(separator: "\n")
    }

    func makeDiagnosticsSnapshot(
        generatedAt: Date = Date(),
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    ) -> DiagnosticsSnapshot {
        DiagnosticsSnapshot(
            generatedAt: Self.diagnosticsTimestamp(generatedAt),
            appVersion: appVersion,
            operatingSystemVersion: operatingSystemVersion,
            sidecarHealth: diagnosticsHealth,
            sidecarVersion: sidecarVersion,
            selectedInstance: selectedInstance,
            selectedModuleID: selectedModuleID,
            instancesCount: instances.count,
            modulesCount: modules.count,
            repositories: repositories,
            searchText: searchText,
            filter: filter.rawValue,
            tagFilter: tagFilter,
            sort: moduleSort.rawValue,
            sortAscending: moduleSortAscending,
            secondarySorts: secondaryModuleSortCriteria,
            changeSetError: changeSetError,
            operationError: operationError,
            operationErrorDetails: operationErrorDetails,
            lastOperationResult: lastOperationResult,
            maintenanceError: maintenanceError,
            settingsError: settingsError)
    }

    func writeDiagnosticsBundle(
        to parentDirectory: URL = FileManager.default.temporaryDirectory,
        generatedAt: Date = Date(),
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
        archive: DiagnosticsArchiveAction = DiagnosticsBundleArchiver.archiveWithDitto
    ) throws -> DiagnosticsBundleResult {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

        let baseName = "MACKAN-Diagnostics-\(Self.diagnosticsFileTimestamp(generatedAt))"
        let directoryURL = Self.uniqueURL(
            under: parentDirectory,
            baseName: baseName,
            pathExtension: nil,
            fileManager: fileManager)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: false)

        let reportURL = directoryURL.appendingPathComponent("diagnostics.txt", isDirectory: false)
        let snapshotURL = directoryURL.appendingPathComponent("snapshot.json", isDirectory: false)
        let archiveURL = Self.uniqueURL(
            under: parentDirectory,
            baseName: directoryURL.lastPathComponent,
            pathExtension: "zip",
            fileManager: fileManager)

        let report = makeDiagnosticsReport(
            generatedAt: generatedAt,
            operatingSystemVersion: operatingSystemVersion,
            appVersion: appVersion)
        try report.write(to: reportURL, atomically: true, encoding: .utf8)

        let snapshot = makeDiagnosticsSnapshot(
            generatedAt: generatedAt,
            operatingSystemVersion: operatingSystemVersion,
            appVersion: appVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
        ]
        try encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)

        try archive(directoryURL, archiveURL)

        return DiagnosticsBundleResult(
            directoryURL: directoryURL,
            reportURL: reportURL,
            snapshotURL: snapshotURL,
            archiveURL: archiveURL)
    }

    private static func diagnosticsTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [
            .withInternetDateTime,
        ]
        return formatter.string(from: date)
    }

    private static func diagnosticsFileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func uniqueURL(
        under parentDirectory: URL,
        baseName: String,
        pathExtension: String?,
        fileManager: FileManager
    ) -> URL {
        func candidate(for name: String) -> URL {
            let url = parentDirectory.appendingPathComponent(name, isDirectory: pathExtension == nil)
            guard let pathExtension else {
                return url
            }
            return url.appendingPathExtension(pathExtension)
        }

        var url = candidate(for: baseName)
        var suffix = 2
        while fileManager.fileExists(atPath: url.path) {
            url = candidate(for: "\(baseName)-\(suffix)")
            suffix += 1
        }
        return url
    }

    private var diagnosticsHealthSummary: String {
        switch healthState {
        case .idle:
            return "idle"
        case .loading:
            return "loading"
        case .ready(let health):
            return "\(health.status); protocol=\(health.protocolVersion); ckan=\(health.ckanVersion)"
        case .failed(let message):
            return "failed; \(message)"
        }
    }

    private var diagnosticsHealth: SidecarHealth? {
        guard case .ready(let health) = healthState else {
            return nil
        }
        return health
    }

    private var diagnosticsVersionSummary: String {
        guard let sidecarVersion else {
            return "-"
        }
        return "\(sidecarVersion.appName) \(sidecarVersion.serviceVersion); CKAN \(sidecarVersion.ckanVersion); protocol \(sidecarVersion.protocolVersion); \(sidecarVersion.dotnetVersion); \(sidecarVersion.operatingSystem); \(sidecarVersion.processArchitecture)"
    }

    private var diagnosticsSecondarySortSummary: String {
        secondaryModuleSortCriteria
            .map { criterion in
                "\(criterion.sort.title) \(criterion.ascending ? "ascending" : "descending")"
            }
            .joined(separator: ", ")
            .nilIfEmpty ?? "-"
    }

    private func diagnosticsErrorDetailsSummary(_ details: SidecarErrorDetails?) -> String {
        guard let details else {
            return "-"
        }

        var parts = [details.kind]
        if let suggestedAction = details.suggestedAction {
            parts.append("suggestedAction=\(suggestedAction)")
        }
        if let lockfilePath = details.lockfilePath {
            parts.append("lockfilePath=\(lockfilePath)")
        }
        if let command = details.command {
            parts.append("command=\(command)")
        }
        return parts.joined(separator: "; ")
    }

    private func diagnosticsOperationEventLine(_ event: OperationEvent) -> String {
        var parts = [event.kind]
        if let percent = event.percent {
            parts.append("\(percent)%")
        }
        parts.append(event.message)
        if let identifier = event.identifier {
            parts.append("identifier=\(identifier)")
        }
        if let remainingBytes = event.remainingBytes {
            parts.append("remaining=\(remainingBytes)")
        }
        if let totalBytes = event.totalBytes {
            parts.append("total=\(totalBytes)")
        }
        return "Operation Event: \(parts.joined(separator: "; "))"
    }

    private func diagnosticsDownloadFailureLines(_ details: SidecarErrorDetails?) -> [String] {
        details?.downloadFailures?.map { failure in
            let urls = failure.urls.joined(separator: ", ").nilIfEmpty ?? "-"
            return "Download Failure: \(failure.identifier) \(failure.version); \(failure.message); \(urls)"
        } ?? []
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

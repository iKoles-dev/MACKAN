import Foundation

extension SidecarClient {
    public func resolveChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = []
    ) async throws -> ChangeSetResult {
        return try await request(
            method: "mods.resolveChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections))
    }

    public func applyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = [],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try await request(
            method: "operations.applyChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections,
                skipDownloadFailures: skipDownloadFailures))
    }

    public func startApplyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection] = [],
        providerSelections: [ProviderSelection] = [],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try await request(
            method: "operations.startApplyChanges",
            params: changeSetParams(
                instanceId: instanceId,
                install: install,
                remove: remove,
                upgrade: upgrade,
                replace: replace,
                installVersions: installVersions,
                providerSelections: providerSelections,
                skipDownloadFailures: skipDownloadFailures))
    }

    public func installCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["filePaths"] = .strings(filePaths)
        if !providerSelections.isEmpty {
            params["providerSelections"] = .objects(providerSelections.map(\.parameterObject))
        }
        if !recommendationSelections.isEmpty {
            params["recommendationSelections"] = .strings(recommendationSelections)
        }
        if skipRecommendations {
            params["skipRecommendations"] = .bool(skipRecommendations)
        }
        if allowIncompatibleCkanFiles {
            params["allowIncompatibleCkanFiles"] = .bool(allowIncompatibleCkanFiles)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.installCkanFiles",
            params: params)
    }

    public func startInstallCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection] = [],
        recommendationSelections: [String] = [],
        skipRecommendations: Bool = false,
        allowIncompatibleCkanFiles: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["filePaths"] = .strings(filePaths)
        if !providerSelections.isEmpty {
            params["providerSelections"] = .objects(providerSelections.map(\.parameterObject))
        }
        if !recommendationSelections.isEmpty {
            params["recommendationSelections"] = .strings(recommendationSelections)
        }
        if skipRecommendations {
            params["skipRecommendations"] = .bool(skipRecommendations)
        }
        if allowIncompatibleCkanFiles {
            params["allowIncompatibleCkanFiles"] = .bool(allowIncompatibleCkanFiles)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.startInstallCkanFiles",
            params: params)
    }

    public func importDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["paths"] = .strings(paths)
        params["installImportedModules"] = .bool(installImportedModules)
        params["deleteImportedFiles"] = .bool(deleteImportedFiles)
        if previewBeforeInstall {
            params["previewBeforeInstall"] = .bool(previewBeforeInstall)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.importDownloads",
            params: params)
    }

    public func startImportDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool = false,
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["paths"] = .strings(paths)
        params["installImportedModules"] = .bool(installImportedModules)
        params["deleteImportedFiles"] = .bool(deleteImportedFiles)
        if previewBeforeInstall {
            params["previewBeforeInstall"] = .bool(previewBeforeInstall)
        }
        if skipDownloadFailures {
            params["skipDownloadFailures"] = .bool(skipDownloadFailures)
        }
        return try await request(
            method: "operations.startImportDownloads",
            params: params)
    }

    public func exportModList(instanceId: String?, format: ModListExportFormat) async throws -> ModListExportResult {
        var params = stringParams(["instanceId": instanceId]) ?? [:]
        params["format"] = .string(format.rawValue)
        return try await request(
            method: "exports.modList",
            params: params)
    }

    public func exportModpack(instanceId: String?, draft: ModpackExportDraft) async throws -> ModpackExportResult {
        var params = stringParams([
            "instanceId": instanceId,
            "identifier": draft.identifier,
            "name": draft.name,
            "abstract": draft.abstract,
            "author": draft.author,
            "version": draft.version,
            "license": draft.license,
            "gameVersionMin": draft.gameVersionMin,
            "gameVersionMax": draft.gameVersionMax,
        ]) ?? [:]
        params["includeVersions"] = .bool(draft.includeVersions)
        params["includeOptionalRelationships"] = .bool(draft.includeOptionalRelationships)
        if !draft.relationshipAssignments.isEmpty {
            params["relationshipAssignments"] = .objects(draft.relationshipAssignments.map(\.parameterObject))
        }
        return try await request(
            method: "exports.modpack",
            params: params)
    }

    public func operationStatus(operationId: String) async throws -> OperationResult {
        try await request(
            method: "operations.status",
            params: stringParams(["operationId": operationId]))
    }

    public func cancelOperation(operationId: String) async throws -> OperationResult {
        try await request(
            method: "operations.cancel",
            params: stringParams(["operationId": operationId]))
    }

}

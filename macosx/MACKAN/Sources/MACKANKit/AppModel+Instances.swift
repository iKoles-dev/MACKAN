import Foundation

extension AppModel {
    public func refresh() async {
        healthState = .loading
        do {
            async let health = sidecar.health()
            async let version = sidecar.version()
            async let loadedInstances = sidecar.listInstances()
            let healthResult = try await health
            let versionResult = try await version
            let instanceResult = try await loadedInstances
            instances = instanceResult.instances
            sidecarVersion = versionResult
            selectedInstanceID = instanceResult.defaultInstanceId
                ?? instances.first(where: \.isDefault)?.id
                ?? instances.first?.id
            healthState = .ready(healthResult)
            try await loadInstanceState(for: selectedInstanceID)
        } catch {
            sidecarVersion = nil
            healthState = .failed(error.localizedDescription)
        }
    }

    public func refreshHealth() async {
        await refresh()
    }

    public func selectInstance(_ instanceID: GameInstanceSummary.ID?) async {
        showCatalog()
        selectedInstanceID = instanceID
        do {
            try await loadInstanceState(for: instanceID)
        } catch {
            modules = []
            selectedModuleID = nil
            selectedModuleDetails = nil
            moduleLabels = []
            manageableModuleLabels = []
            repositories = []
            availableRepositories = []
            repositoryRefreshSummary = nil
            clearAllStagedChanges()
            healthState = .failed(error.localizedDescription)
        }
    }

    public func addInstance(path: String, name: String) async throws {
        let cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await sidecar.addInstance(path: cleanedPath, name: cleanedName)
        instances = result.instances
        selectedInstanceID = instances.first { $0.path == cleanedPath }?.id
            ?? instances.first { $0.name == cleanedName }?.id
            ?? result.defaultInstanceId
            ?? instances.first(where: \.isDefault)?.id
            ?? instances.first?.id
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func cloneInstance(
        sourceInstanceId: GameInstanceSummary.ID,
        newName: String,
        newPath: String,
        shareStock: Bool,
        leaveEmptyPaths: [String]? = nil
    ) async throws {
        let cleanedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPath = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await sidecar.cloneInstance(
            sourceInstanceId: sourceInstanceId,
            newName: cleanedName,
            newPath: cleanedPath,
            shareStock: shareStock,
            leaveEmptyPaths: cleanedLeaveEmptyPaths(leaveEmptyPaths))
        instances = result.instances
        selectedInstanceID = instances.first { $0.path == cleanedPath }?.id
            ?? instances.first { $0.name == cleanedName }?.id
            ?? result.defaultInstanceId
            ?? instances.first(where: \.isDefault)?.id
            ?? instances.first?.id
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func loadCloneOptions(sourceInstanceId: GameInstanceSummary.ID) async throws -> CloneOptionsResult {
        try await sidecar.cloneOptions(sourceInstanceId: sourceInstanceId)
    }

    public func fakeInstance(
        name: String,
        path: String,
        version: String,
        gameId: String,
        makingHistoryVersion: String?,
        breakingGroundVersion: String?,
        setDefault: Bool
    ) async throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await sidecar.fakeInstance(
            name: cleanedName,
            path: cleanedPath,
            version: version.trimmingCharacters(in: .whitespacesAndNewlines),
            gameId: gameId.trimmingCharacters(in: .whitespacesAndNewlines),
            makingHistoryVersion: cleanedOptionalVersion(makingHistoryVersion),
            breakingGroundVersion: cleanedOptionalVersion(breakingGroundVersion),
            setDefault: setDefault)
        instances = result.instances
        selectedInstanceID = instances.first { $0.path == cleanedPath }?.id
            ?? instances.first { $0.name == cleanedName }?.id
            ?? result.defaultInstanceId
            ?? instances.first(where: \.isDefault)?.id
            ?? instances.first?.id
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func setDefaultInstance(_ instanceID: GameInstanceSummary.ID) async throws {
        let result = try await sidecar.setDefaultInstance(instanceID)
        instances = result.instances
        selectedInstanceID = result.defaultInstanceId
            ?? instances.first(where: \.isDefault)?.id
            ?? instanceID
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func setSelectedInstanceAsDefault() async throws {
        guard let selectedInstanceID else {
            throw InstanceDirectoryOpenError.missingInstance
        }

        try await setDefaultInstance(selectedInstanceID)
    }

    public func forgetInstance(_ instanceID: GameInstanceSummary.ID) async throws {
        let result = try await sidecar.removeInstance(instanceID)
        instances = result.instances
        let selectedInstanceWasRemoved = selectedInstanceID == instanceID
        let selectedInstanceStillExists = selectedInstanceID
            .map { selectedID in instances.contains { $0.id == selectedID } }
            ?? false
        if selectedInstanceWasRemoved || !selectedInstanceStillExists {
            selectedInstanceID = result.defaultInstanceId
                ?? instances.first(where: \.isDefault)?.id
                ?? instances.first?.id
        }
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func renameInstance(_ instanceID: GameInstanceSummary.ID, to newName: String) async throws {
        let cleanedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await sidecar.renameInstance(instanceID, to: cleanedName)
        instances = result.instances
        if selectedInstanceID == instanceID {
            selectedInstanceID = instances.first { $0.id == cleanedName }?.id
                ?? instances.first { $0.name == cleanedName }?.id
                ?? result.defaultInstanceId
                ?? instances.first(where: \.isDefault)?.id
                ?? instances.first?.id
        } else {
            selectedInstanceID = result.defaultInstanceId
                ?? instances.first(where: \.isDefault)?.id
                ?? selectedInstanceID
        }
        try await loadInstanceState(for: selectedInstanceID)
    }

    public func openSelectedInstanceDirectory() throws {
        guard let selectedInstanceID else {
            throw InstanceDirectoryOpenError.missingInstance
        }

        try openInstanceDirectory(selectedInstanceID)
    }

    public func openInstanceDirectory(_ instanceID: GameInstanceSummary.ID) throws {
        guard let instance = instances.first(where: { $0.id == instanceID }) else {
            throw InstanceDirectoryOpenError.missingInstance
        }

        let path = instance.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw InstanceDirectoryOpenError.emptyPath
        }

        try directoryOpener.revealDirectory(
            at: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true))
    }

    public func openUnmanagedFile(_ file: UnmanagedFileSummary) throws {
        guard let selectedInstance else {
            throw InstanceDirectoryOpenError.missingInstance
        }

        let instancePath = selectedInstance.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instancePath.isEmpty else {
            throw InstanceDirectoryOpenError.emptyPath
        }

        guard let rawPath = file.path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawPath.isEmpty
        else {
            throw InstanceDirectoryOpenError.missingFilePath
        }

        let expandedRawPath = (rawPath as NSString).expandingTildeInPath
        let fileURL: URL
        if expandedRawPath.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: expandedRawPath, isDirectory: false)
        } else {
            let expandedInstancePath = (instancePath as NSString).expandingTildeInPath
            fileURL = URL(fileURLWithPath: expandedInstancePath, isDirectory: true)
                .appendingPathComponent(rawPath, isDirectory: false)
        }
        try directoryOpener.revealDirectory(at: fileURL)
    }

    private func cleanedOptionalVersion(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cleanedLeaveEmptyPaths(_ paths: [String]?) -> [String]? {
        paths?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

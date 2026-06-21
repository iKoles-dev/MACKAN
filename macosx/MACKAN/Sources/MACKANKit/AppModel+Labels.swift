struct ModuleDetailsCacheKey: Hashable {
    let instanceId: String?
    let identifier: String

    init(instanceId: String?, identifier: String) {
        self.instanceId = instanceId
        self.identifier = identifier.lowercased()
    }
}

extension AppModel {
    public func toggleLabel(_ labelName: String, for identifier: ModuleSummary.ID) async throws {
        let result = try await sidecar.toggleModuleLabel(
            instanceId: selectedInstanceID,
            labelName: labelName,
            identifier: identifier)
        moduleLabels = result.labels
        manageableModuleLabels = sortedLabels(result.manageableLabels)
    }

    public func setAutoInstalled(_ isAutoInstalled: Bool, for identifier: ModuleSummary.ID) async throws {
        let result = try await sidecar.setAutoInstalled(
            instanceId: selectedInstanceID,
            identifier: identifier,
            isAutoInstalled: isAutoInstalled)
        modules = result.modules
        pendingChangeSet = nil
        changeSetError = nil

        if selectedModuleID == nil || selectedModuleID == identifier {
            selectedModuleID = identifier
        }

        guard let selectedModuleID,
              let refreshedModule = modules.first(where: { $0.identifier == selectedModuleID })
        else {
            selectFirstFilteredModule()
            await refreshSelectedModuleDetails()
            return
        }

        await refreshSelectedModuleDetails(force: true)
        if let selectedModuleDetails,
           selectedModuleDetails.module.identifier == refreshedModule.identifier {
            self.selectedModuleDetails = selectedModuleDetails.replacingModule(refreshedModule)
        }
    }

    public func saveLabel(
        originalName: String?,
        originalInstanceName: String?,
        label: ModuleLabelEdit
    ) async throws {
        let result = try await sidecar.upsertModuleLabel(
            instanceId: selectedInstanceID,
            originalName: originalName,
            originalInstanceName: originalInstanceName,
            label: label)
        moduleLabels = result.labels
        manageableModuleLabels = sortedLabels(result.manageableLabels)
    }

    public func deleteLabel(name: String, instanceName: String?) async throws {
        let result = try await sidecar.deleteModuleLabel(
            instanceId: selectedInstanceID,
            name: name,
            instanceName: instanceName)
        moduleLabels = result.labels
        manageableModuleLabels = sortedLabels(result.manageableLabels)
    }

    public func refreshSelectedModuleDetails(force: Bool = false) async {
        guard let selectedModuleID else {
            selectedModuleDetails = nil
            return
        }
        guard force || catalogLoadProgress == nil else {
            return
        }

        let instanceID = selectedInstanceID
        let cacheKey = ModuleDetailsCacheKey(instanceId: instanceID, identifier: selectedModuleID)
        let selectedSummary = modules.first {
            $0.identifier.localizedCaseInsensitiveCompare(selectedModuleID) == .orderedSame
        }
        let summaryDetails = selectedSummary.map {
            ModuleDetails(summary: $0, instanceId: instanceID)
        }

        if selectedModuleDetails?.module.identifier.localizedCaseInsensitiveCompare(selectedModuleID) != .orderedSame {
            selectedModuleDetails = summaryDetails
        }

        if let cachedDetails = moduleDetailsCache[cacheKey] {
            let displayDetails = selectedSummary.map { cachedDetails.replacingModule($0) } ?? cachedDetails
            selectedModuleDetails = displayDetails
            moduleDetailsCache[cacheKey] = displayDetails
            if !force {
                return
            }
        }

        do {
            let details = try await sidecar.moduleDetails(
                instanceId: instanceID,
                identifier: selectedModuleID)
            guard selectedInstanceID == instanceID,
                  self.selectedModuleID == selectedModuleID
            else {
                return
            }
            let displayDetails = selectedSummary.map { details.replacingModule($0) } ?? details
            selectedModuleDetails = displayDetails
            moduleDetailsCache[cacheKey] = displayDetails
        } catch {
            if moduleDetailsCache[cacheKey] == nil,
               selectedModuleDetails?.module.identifier.localizedCaseInsensitiveCompare(selectedModuleID) != .orderedSame {
                selectedModuleDetails = nil
            }
        }
    }

    func removeCachedModuleDetails(for instanceID: GameInstanceSummary.ID?) {
        moduleDetailsCache = moduleDetailsCache.filter { key, _ in
            key.instanceId != instanceID
        }
    }
}

private extension ModuleDetails {
    init(summary module: ModuleSummary, instanceId: String?) {
        self.init(
            instanceId: instanceId,
            module: module,
            abstract: module.abstract,
            description: module.description,
            releaseStatus: "",
            kind: "",
            releaseDate: module.releaseDate,
            downloadSize: module.downloadSize,
            installSize: module.installSize,
            resources: [],
            tags: module.tags)
    }

    func replacingModule(_ module: ModuleSummary) -> ModuleDetails {
        ModuleDetails(
            instanceId: instanceId,
            module: module,
            abstract: abstract,
            description: description,
            releaseStatus: releaseStatus,
            kind: kind,
            releaseDate: releaseDate,
            downloadSize: downloadSize,
            installSize: installSize,
            resources: resources,
            tags: tags)
    }
}

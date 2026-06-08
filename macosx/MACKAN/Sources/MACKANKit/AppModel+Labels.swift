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
            selectedModuleID = modules.first?.id
            await refreshSelectedModuleDetails()
            return
        }

        await refreshSelectedModuleDetails()
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

    public func refreshSelectedModuleDetails() async {
        guard let selectedModuleID else {
            selectedModuleDetails = nil
            return
        }

        do {
            selectedModuleDetails = try await sidecar.moduleDetails(
                instanceId: selectedInstanceID,
                identifier: selectedModuleID)
        } catch {
            selectedModuleDetails = nil
        }
    }
}

private extension ModuleDetails {
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

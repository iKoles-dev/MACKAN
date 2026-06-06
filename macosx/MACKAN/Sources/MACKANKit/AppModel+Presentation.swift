import Foundation

extension AppModel {
    public var selectedModule: ModuleSummary? {
        filteredModules.first { $0.id == selectedModuleID }
    }

    public var selectedInstance: GameInstanceSummary? {
        selectedInstanceID.flatMap { selectedID in
            instances.first { $0.id == selectedID }
        }
    }

    public var instanceManagementRows: [InstanceManagementRow] {
        instances.map { instance in
            let path = instance.path.trimmingCharacters(in: .whitespacesAndNewlines)
            return InstanceManagementRow(
                instance: instance,
                isSelected: instance.id == selectedInstanceID,
                canSetDefault: !instance.isDefault && instance.isValid,
                canReveal: !path.isEmpty,
                canRename: true,
                canForget: instances.count > 1)
        }
    }

    public var repositoryManagementRows: [RepositoryManagementRow] {
        repositories.enumerated().map { index, repository in
            RepositoryManagementRow(
                repository: repository,
                canMoveUp: index > 0,
                canMoveDown: index < repositories.count - 1,
                canRemove: repositories.count > 1)
        }
    }

    public var canSetSelectedInstanceAsDefault: Bool {
        selectedInstance.map { !$0.isDefault && $0.isValid } ?? false
    }

    public var canOpenSelectedInstanceDirectory: Bool {
        selectedInstance
            .map { !$0.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            ?? false
    }

    public var canLaunchSelectedGame: Bool {
        selectedInstance != nil && !launchCommands.isEmpty && !isLaunchingGame
    }

    public var canRefreshRepositories: Bool {
        selectedInstance != nil
    }

    public var canStageUpgradeAll: Bool {
        modules.contains { $0.status == .upgradable }
    }

    public var hasPendingSelections: Bool {
        !stagedActions.isEmpty || !versionedInstallSelections.isEmpty
    }

    public var canApplyPendingChangeSet: Bool {
        guard let pendingChangeSet else {
            return false
        }
        return changeSetError == nil
            && !pendingChangeSet.changes.isEmpty
            && pendingChangeSet.conflicts.isEmpty
            && pendingChangeSet.conflictDescriptions.isEmpty
            && pendingChangeSet.providerChoices.isEmpty
    }

    public var pendingChangeSetConflictNotice: ChangeSetConflictNotice? {
        guard let pendingChangeSet,
              !pendingChangeSet.conflicts.isEmpty || !pendingChangeSet.conflictDescriptions.isEmpty
        else {
            return nil
        }
        return ChangeSetConflictNotice(
            conflicts: pendingChangeSet.conflicts,
            descriptions: pendingChangeSet.conflictDescriptions)
    }

    public var pendingDependencyChoiceNotice: DependencyChoiceNotice? {
        guard let pendingChangeSet,
              !pendingChangeSet.providerChoices.isEmpty
        else {
            return nil
        }
        return DependencyChoiceNotice(choices: pendingChangeSet.providerChoices)
    }

    public func aboutInfo(
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    ) -> AboutInfo {
        AboutInfo(
            title: "MACKAN",
            subtitle: "Native macOS CKAN for Kerbal Space Program",
            rows: [
                AboutInfoRow(label: "MACKAN App", value: appVersion),
                AboutInfoRow(label: "MACKAN Service", value: sidecarVersion?.serviceVersion ?? "Unavailable"),
                AboutInfoRow(label: "CKAN Core", value: sidecarVersion?.ckanVersion ?? healthCkanVersion ?? "Unavailable"),
                AboutInfoRow(label: "Protocol", value: sidecarVersion?.protocolVersion ?? healthProtocolVersion ?? "Unavailable"),
                AboutInfoRow(label: ".NET Runtime", value: sidecarVersion?.dotnetVersion ?? "Unavailable"),
                AboutInfoRow(label: "Operating System", value: sidecarVersion?.operatingSystem ?? "Unavailable"),
                AboutInfoRow(label: "Process Architecture", value: sidecarVersion?.processArchitecture ?? "Unavailable"),
            ])
    }

    private var healthCkanVersion: String? {
        guard case .ready(let health) = healthState else {
            return nil
        }
        return health.ckanVersion
    }

    private var healthProtocolVersion: String? {
        guard case .ready(let health) = healthState else {
            return nil
        }
        return health.protocolVersion
    }
}

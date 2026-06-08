import Foundation

public struct CatalogLoadPresentationState: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let secondaryDetail: String?
    public let fractionCompleted: Double?

    public init(progress: AppModel.CatalogLoadProgress) {
        title = "Loading catalog"
        detail = progress.moduleCountSummary ?? progress.detail
        fractionCompleted = progress.fractionCompleted
        if progress.moduleCountSummary == nil {
            secondaryDetail = "Large KSP instances can take a minute. MACKAN is still working."
        } else {
            secondaryDetail = progress.detail
        }
    }
}

public struct CatalogActionSummaryPresentationState: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case idle
        case needsPreview
        case needsResolution
        case readyToApply
        case previewError
    }

    public let kind: Kind
    public let title: String
    public let detail: String
    public let canPreview: Bool
    public let canApply: Bool

    public init(
        stagedActionCount: Int,
        versionedInstallCount: Int,
        pendingChangeSet: ChangeSetResult?,
        changeSetError: String?
    ) {
        let stagedChangeCount = stagedActionCount + versionedInstallCount
        canPreview = stagedChangeCount > 0

        if changeSetError != nil {
            kind = .previewError
            title = "Preview failed"
            detail = "Review the error, adjust selections, then preview again."
            canApply = false
            return
        }

        if let pendingChangeSet {
            if !pendingChangeSet.conflicts.isEmpty
                || !pendingChangeSet.conflictDescriptions.isEmpty
                || !pendingChangeSet.providerChoices.isEmpty {
                kind = .needsResolution
                title = "Action needed"
                detail = "Resolve conflicts or provider choices before applying."
                canApply = false
                return
            }

            if !pendingChangeSet.changes.isEmpty {
                kind = .readyToApply
                title = "\(pendingChangeSet.changes.count.formatted()) \(Self.changeWord(pendingChangeSet.changes.count)) ready"
                detail = "Review the resolved change set, then apply."
                canApply = true
                return
            }
        }

        if stagedChangeCount > 0 {
            kind = .needsPreview
            title = "\(stagedChangeCount.formatted()) \(Self.changeWord(stagedChangeCount)) staged"
            detail = "Preview changes to resolve dependencies before applying."
            canApply = false
            return
        }

        kind = .idle
        title = "No changes staged"
        detail = "Select a module, then use Install, Remove, Upgrade, or Replace."
        canApply = false
    }

    private static func changeWord(_ count: Int) -> String {
        count == 1 ? "change" : "changes"
    }
}

extension AppModel {
    public var catalogActionSummary: CatalogActionSummaryPresentationState {
        CatalogActionSummaryPresentationState(
            stagedActionCount: stagedActions.count,
            versionedInstallCount: versionedInstallSelections.count,
            pendingChangeSet: pendingChangeSet,
            changeSetError: changeSetError)
    }
}

public struct InspectorEmptyPresentationState: Equatable, Sendable {
    public let systemImage: String
    public let title: String
    public let detail: String

    public init(
        selectedInstance: GameInstanceSummary?,
        moduleCount: Int,
        catalogLoadProgress: AppModel.CatalogLoadProgress?
    ) {
        if catalogLoadProgress != nil {
            systemImage = "hourglass"
            title = "Catalog Loading"
            detail = "Module details will appear here after the catalog finishes loading."
            return
        }

        if selectedInstance == nil {
            systemImage = "shippingbox"
            title = "No Instance Selected"
            detail = "Add or select a game instance to inspect mods."
            return
        }

        if moduleCount == 0 {
            systemImage = "tray"
            title = "No Mods Loaded"
            detail = "Refresh repositories or change filters to populate the catalog."
            return
        }

        systemImage = "shippingbox"
        title = "No Mod Selected"
        detail = "Select a module in the catalog to inspect metadata, relationships, versions, contents, and resources."
    }
}

extension AppModel {
    public var inspectorEmptyState: InspectorEmptyPresentationState {
        InspectorEmptyPresentationState(
            selectedInstance: selectedInstance,
            moduleCount: modules.count,
            catalogLoadProgress: catalogLoadProgress)
    }
}

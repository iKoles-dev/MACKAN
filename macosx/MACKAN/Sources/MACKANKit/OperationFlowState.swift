import Foundation

public enum RegistryLockRemovalFollowUp: Equatable, Sendable {
    case preview
    case apply
}

public struct RegistryLockRemovalRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let lockfilePath: String?
    public let followUp: RegistryLockRemovalFollowUp

    public init(
        lockfilePath: String?,
        followUp: RegistryLockRemovalFollowUp,
        id: UUID = UUID()
    ) {
        self.id = id
        self.lockfilePath = lockfilePath
        self.followUp = followUp
    }
}

public struct OperationFlowState: Equatable, Sendable {
    public private(set) var activity: OperationActivityState
    public private(set) var presentation: OperationPresentationState
    public private(set) var retry: OperationRetryState
    public private(set) var pendingRegistryLockRemoval: RegistryLockRemovalRequest?

    public init(
        activity: OperationActivityState = OperationActivityState(),
        presentation: OperationPresentationState = OperationPresentationState(),
        retry: OperationRetryState = OperationRetryState(),
        pendingRegistryLockRemoval: RegistryLockRemovalRequest? = nil
    ) {
        self.activity = activity
        self.presentation = presentation
        self.retry = retry
        self.pendingRegistryLockRemoval = pendingRegistryLockRemoval
    }

    public func isActive(_ activity: OperationActivity) -> Bool {
        self.activity.isActive(activity)
    }

    public mutating func start(_ activity: OperationActivity) {
        self.activity.start(activity)
    }

    @discardableResult
    public mutating func finish(_ activity: OperationActivity) -> Bool {
        self.activity.finish(activity)
    }

    public func isPresenting(_ sheet: OperationPresentationSheet) -> Bool {
        presentation.isPresenting(sheet)
    }

    public mutating func present(_ sheet: OperationPresentationSheet) {
        presentation.present(sheet)
    }

    public mutating func presentImportDownloadsResult(previewBeforeInstall: Bool, hasPendingChangeSet: Bool) {
        present(previewBeforeInstall && hasPendingChangeSet ? .changePreview : .operationResult)
    }

    public mutating func dismiss(_ sheet: OperationPresentationSheet) {
        presentation.dismiss(sheet)
    }

    public mutating func recordRetry(_ source: OperationRetrySource) {
        retry.record(source)
    }

    public func retryAction(skipDownloadFailures: Bool = false) -> OperationRetryAction {
        retry.action(skipDownloadFailures: skipDownloadFailures)
    }

    public mutating func beginRegistryLockRemoval(lockfilePath: String?, followUp: RegistryLockRemovalFollowUp) {
        pendingRegistryLockRemoval = RegistryLockRemovalRequest(
            lockfilePath: lockfilePath,
            followUp: followUp)
    }

    public mutating func clearRegistryLockRemoval() {
        pendingRegistryLockRemoval = nil
    }
}

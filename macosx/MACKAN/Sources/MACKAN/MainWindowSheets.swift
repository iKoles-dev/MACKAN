import SwiftUI

import MACKANKit

struct MainWindowSheetActions {
    let clearChanges: () -> Void
    let stageProvider: (ProviderChoice, ProviderOption) -> Void
    let stageRecommendation: (String) -> Void
    let toggleSuppressRecommendations: (Bool) -> Void
    let previewChanges: () -> Void
    let removePreviewLock: () -> Void
    let applyChanges: () -> Void
    let refreshOperationStatus: () -> Void
    let retryLastOperation: () -> Void
    let retryLastOperationSkippingDownloadFailures: () -> Void
    let removeOperationLock: () -> Void
    let selectCkanProvider: (ProviderChoice, ProviderOption) -> Void
    let selectCkanRecommendation: (RecommendationChoice) -> Void
    let skipCkanRecommendations: () -> Void
    let allowIncompatibleCkanFiles: () -> Void
    let copyDiagnostics: () -> Void
    let cancelOperation: () -> Void
    let importDownloads: ([URL], ImportDownloadsOptions) -> Void
    let confirmLaunchWarning: (Bool) -> Void
    let revealUnmanagedFile: (UnmanagedFileSummary) -> Void
    let installHistoryModules: ([InstallationHistoryModule], Bool) -> Void
    let updatePlayTime: (String, Double) async -> Void
    let loadCacheInfo: () async -> Void
    let purgeCacheToLimit: () async -> Void
    let clearCache: () async -> Void
    let removeRegistryLockAndRetry: (RegistryLockRemovalRequest) -> Void
    let retryLaunchFromFailure: () -> Void
}

struct MainWindowSheets: ViewModifier {
    @ObservedObject var model: AppModel
    @Binding var fileImports: FileImportFlowState
    @Binding var operationFlow: OperationFlowState
    let actions: MainWindowSheetActions

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: operationSheetIsPresented(.changePreview)) {
                ChangeSetPreviewSheet(
                    result: model.pendingChangeSet,
                    conflictNotice: model.pendingChangeSetConflictNotice,
                    dependencyChoiceNotice: model.pendingDependencyChoiceNotice,
                    errorMessage: model.changeSetError,
                    errorDetails: model.changeSetErrorDetails,
                    isApplying: operationFlow.isActive(.applyingChanges),
                    suppressRecommendations: model.pendingChangeSet?.suppressRecommendations
                        ?? model.recommendationSettings?.suppressRecommendations
                        ?? false,
                    onClose: {
                        operationFlow.dismiss(.changePreview)
                    },
                    onClear: actions.clearChanges,
                    onStageProvider: actions.stageProvider,
                    onStageRecommendation: actions.stageRecommendation,
                    onToggleSuppressRecommendations: actions.toggleSuppressRecommendations,
                    onRetry: actions.previewChanges,
                    onRemoveLock: actions.removePreviewLock,
                    onApply: actions.applyChanges)
            }
            .sheet(isPresented: operationSheetIsPresented(.operationResult)) {
                OperationResultSheet(
                    result: model.lastOperationResult,
                    errorMessage: model.operationError,
                    errorDetails: model.operationErrorDetails,
                    canSkipDownloadFailuresRetry: model.lastOperationSupportsSkipDownloadFailures,
                    isRefreshing: operationFlow.isActive(.refreshingOperationStatus),
                    isCancelling: operationFlow.isActive(.cancellingOperation),
                    onRefresh: actions.refreshOperationStatus,
                    onRetry: actions.retryLastOperation,
                    onSkipDownloadFailuresRetry: actions.retryLastOperationSkippingDownloadFailures,
                    onRemoveLock: actions.removeOperationLock,
                    onStageProvider: actions.selectCkanProvider,
                    onStageRecommendation: actions.selectCkanRecommendation,
                    onSkipRecommendations: actions.skipCkanRecommendations,
                    onAllowIncompatibleCkanFiles: actions.allowIncompatibleCkanFiles,
                    onCopyDiagnostics: actions.copyDiagnostics,
                    onCancel: actions.cancelOperation,
                    onClose: {
                        operationFlow.dismiss(.operationResult)
                    })
            }
            .sheet(isPresented: $fileImports.isShowingImportDownloadsOptions) {
                ImportDownloadsOptionsSheet(
                    fileCount: fileImports.pendingImportDownloadURLs.count,
                    installImportedModules: $fileImports.importDownloadsDraft.installImportedModules,
                    deleteImportedFiles: $fileImports.importDownloadsDraft.deleteImportedFiles,
                    previewBeforeInstall: $fileImports.importDownloadsDraft.previewBeforeInstall,
                    onCancel: {
                        fileImports.cancelImportDownloadsOptions()
                    },
                    onImport: {
                        let request = fileImports.confirmImportDownloadsOptions()
                        actions.importDownloads(request.urls, request.options)
                    })
            }
            .sheet(isPresented: pendingLaunchWarningIsPresented) {
                if let warning = model.pendingLaunchWarning {
                    LaunchWarningSheet(
                        warning: warning,
                        isLaunching: model.isLaunchingGame,
                        onCancel: {
                            model.cancelPendingLaunchWarning()
                        },
                        onLaunch: actions.confirmLaunchWarning)
                }
            }
            .sheet(isPresented: maintenanceSheetIsPresented(for: .unmanagedFiles)) {
                UnmanagedFilesSheet(
                    result: model.unmanagedFilesResult,
                    onRevealFile: actions.revealUnmanagedFile,
                    onClose: {
                        model.clearMaintenanceResult(for: .unmanagedFiles)
                    })
            }
            .sheet(isPresented: maintenanceSheetIsPresented(for: .history)) {
                InstallationHistorySheet(
                    result: model.installationHistoryResult,
                    onInstallMissing: { modules in
                        actions.installHistoryModules(modules, false)
                    },
                    onRestoreExactVersions: { modules in
                        actions.installHistoryModules(modules, true)
                    },
                    onClose: {
                        model.clearMaintenanceResult(for: .history)
                    })
            }
            .sheet(isPresented: maintenanceSheetIsPresented(for: .playTime)) {
                PlayTimeSheet(
                    result: model.playTimeResult,
                    onSave: { instanceId, hours in
                        await actions.updatePlayTime(instanceId, hours)
                    },
                    onClose: {
                        model.clearMaintenanceResult(for: .playTime)
                    })
            }
            .sheet(isPresented: maintenanceSheetIsPresented(for: .downloadStatistics)) {
                DownloadStatisticsSheet(
                    result: model.downloadStatisticsResult,
                    onClose: {
                        model.clearMaintenanceResult(for: .downloadStatistics)
                    })
            }
            .sheet(isPresented: maintenanceSheetIsPresented(for: .cache)) {
                CacheMaintenanceSheet(
                    info: model.cacheInfoResult,
                    purgeResult: model.lastCachePurgeResult,
                    onRefresh: {
                        await actions.loadCacheInfo()
                    },
                    onPurgeToLimit: {
                        await actions.purgeCacheToLimit()
                    },
                    onPurgeAll: {
                        await actions.clearCache()
                    },
                    onClose: {
                        model.clearMaintenanceResult(for: .cache)
                    })
            }
            .sheet(isPresented: deduplicateResultIsPresented) {
                DeduplicateResultSheet(
                    result: model.lastDeduplicateResult,
                    onClose: {
                        model.clearDeduplicateResult()
                    })
            }
            .sheet(isPresented: repairRegistryResultIsPresented) {
                RepairRegistryResultSheet(
                    result: model.lastRepairRegistryResult,
                    onClose: {
                        model.clearRepairRegistryResult()
                    })
            }
            .alert("GameData scan complete", isPresented: maintenanceScanResultIsPresented) {
                Button("OK", role: .cancel) {
                    model.clearMaintenanceScanResult()
                }
            } message: {
                Text(maintenanceScanSummary)
            }
            .alert("GameData scan failed", isPresented: maintenanceErrorIsPresented) {
                Button("OK", role: .cancel) {
                    model.clearMaintenanceError()
                }
            } message: {
                Text(model.maintenanceError ?? "")
            }
            .alert(
                "Remove Registry Lock File?",
                isPresented: registryLockRemovalIsPresented,
                presenting: operationFlow.pendingRegistryLockRemoval
            ) { request in
                Button("Remove Lock File", role: .destructive) {
                    actions.removeRegistryLockAndRetry(request)
                }
                Button("Cancel", role: .cancel) {
                    operationFlow.clearRegistryLockRemoval()
                }
            } message: { request in
                Text("Only remove this file if CKAN and MACKAN are not currently working on this instance.\n\n\(request.lockfilePath ?? "The lock file path is unavailable.")")
            }
            .alert(
                "Failed to launch game",
                isPresented: launchErrorIsPresented,
                presenting: model.launchError
            ) { _ in
                if launchErrorCanRetry {
                    Button("Retry Launch") {
                        actions.retryLaunchFromFailure()
                    }
                }
                Button("OK", role: .cancel) { model.clearLaunchError() }
            } message: { message in
                Text(launchErrorMessageText(message))
            }
    }

    private func operationSheetIsPresented(_ sheet: OperationPresentationSheet) -> Binding<Bool> {
        Binding {
            operationFlow.isPresenting(sheet)
        } set: { isPresented in
            if isPresented {
                operationFlow.present(sheet)
            } else {
                operationFlow.dismiss(sheet)
            }
        }
    }

    private var pendingLaunchWarningIsPresented: Binding<Bool> {
        Binding {
            model.pendingLaunchWarning != nil
        } set: { isPresented in
            if !isPresented {
                model.cancelPendingLaunchWarning()
            }
        }
    }

    private func maintenanceSheetIsPresented(for pane: MaintenancePane) -> Binding<Bool> {
        Binding {
            model.shouldPresentMaintenanceSheet(for: pane)
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceResult(for: pane)
            }
        }
    }

    private var deduplicateResultIsPresented: Binding<Bool> {
        Binding {
            model.lastDeduplicateResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearDeduplicateResult()
            }
        }
    }

    private var repairRegistryResultIsPresented: Binding<Bool> {
        Binding {
            model.lastRepairRegistryResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearRepairRegistryResult()
            }
        }
    }

    private var maintenanceScanResultIsPresented: Binding<Bool> {
        Binding {
            model.lastMaintenanceScanResult != nil
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceScanResult()
            }
        }
    }

    private var maintenanceErrorIsPresented: Binding<Bool> {
        Binding {
            model.maintenanceError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearMaintenanceError()
            }
        }
    }

    private var registryLockRemovalIsPresented: Binding<Bool> {
        Binding {
            operationFlow.pendingRegistryLockRemoval != nil
        } set: { isPresented in
            if !isPresented {
                operationFlow.clearRegistryLockRemoval()
            }
        }
    }

    private var launchErrorIsPresented: Binding<Bool> {
        Binding {
            model.launchError != nil
        } set: { isPresented in
            if !isPresented {
                model.clearLaunchError()
            }
        }
    }

    private var maintenanceScanSummary: String {
        guard let result = model.lastMaintenanceScanResult else {
            return ""
        }
        let changeText = result.changed
            ? "Detected changes in manually installed modules or DLC."
            : "No registry changes were detected."
        return "\(changeText)\nDLLs: \(result.detectedDllCount.formatted())\nDLC: \(result.detectedDlcCount.formatted())"
    }

    private var launchErrorCanRetry: Bool {
        LaunchErrorPresentationState(message: "", details: model.launchErrorDetails).canRetry
    }

    private func launchErrorMessageText(_ message: String) -> String {
        LaunchErrorPresentationState(message: message, details: model.launchErrorDetails).messageText
    }
}

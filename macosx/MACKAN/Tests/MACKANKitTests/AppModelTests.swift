import XCTest
import Combine

@testable import MACKANKit

@MainActor
final class AppModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Self.clearMackanUserDefaults()
    }

    override func tearDown() {
        Self.clearMackanUserDefaults()
        super.tearDown()
    }

    func testInitialProductionStateDoesNotExposeSampleInstancesOrModules() {
        let model = AppModel(sidecar: FakeSidecar())

        XCTAssertTrue(model.instances.isEmpty)
        XCTAssertTrue(model.modules.isEmpty)
        XCTAssertNil(model.selectedInstanceID)
        XCTAssertNil(model.selectedModuleID)
        XCTAssertNil(model.selectedModuleDetails)
    }

    func testRefreshLoadsInstancesFromSidecar() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertEqual(model.instances.map(\.id), ["primary", "secondary"])
        XCTAssertEqual(model.instances.first?.name, "Primary KSP")
        XCTAssertEqual(model.selectedInstanceID, "primary")
        XCTAssertEqual(model.modules.map { $0.identifier }, ["SidecarOnlyMod"])
        XCTAssertEqual(model.selectedModuleID, "SidecarOnlyMod")
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SidecarOnlyMod")
        XCTAssertEqual(model.selectedModuleDetails?.abstract, "A real sidecar detail")
        XCTAssertEqual(model.selectedModuleDetails?.resources.first?.label, "Homepage")
        XCTAssertEqual(model.repositories.map(\.name), ["default"])
        XCTAssertEqual(model.repositories.first?.url, "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz")
        XCTAssertEqual(model.launchCommands, ["./KSP.app/Contents/MacOS/KSP", "steam://run/220200"])
        XCTAssertEqual(model.defaultLaunchCommands, ["./KSP.app/Contents/MacOS/KSP"])
        XCTAssertTrue(model.incompatibleLaunchModules.isEmpty)
        XCTAssertTrue(model.canLaunchSelectedGame)
        XCTAssertEqual(model.healthState, .ready(SidecarHealth(
            status: "ok",
            protocolVersion: "1",
            ckanVersion: "v1.36.5-test")))
        XCTAssertEqual(model.sidecarVersion, SidecarVersion(
            appName: "MACKAN",
            serviceVersion: "1.36.5-test",
            ckanVersion: "v1.36.5-test",
            protocolVersion: "1",
            dotnetVersion: "10.0-test",
            operatingSystem: "macOS test",
            processArchitecture: "Arm64"))
    }

    func testRefreshMarksServiceReadyBeforeInstanceCatalogFinishesLoading() async {
        let gate = ModuleListGate()
        var sidecar = FakeSidecar()
        sidecar.listModulesGate = gate
        let model = AppModel(sidecar: sidecar)

        let refreshTask = Task {
            await model.refresh()
        }
        await gate.waitUntilEntered()

        XCTAssertEqual(model.instances.map(\.id), ["primary", "secondary"])
        XCTAssertEqual(model.selectedInstanceID, "primary")
        XCTAssertEqual(model.healthState, .ready(SidecarHealth(
            status: "ok",
            protocolVersion: "1",
            ckanVersion: "v1.36.5-test")))
        XCTAssertEqual(model.catalogLoadProgress, AppModel.CatalogLoadProgress(
            detail: "Reading CKAN registry and module metadata for the selected instance."))
        XCTAssertNil(model.catalogLoadProgress?.loadedModuleCount)
        XCTAssertNil(model.catalogLoadProgress?.totalModuleCount)
        XCTAssertTrue(model.modules.isEmpty)

        await gate.release()
        await refreshTask.value
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.catalogLoadProgress)
    }

    func testRefreshHydratesCachedCatalogWhileFreshCatalogLoads() async {
        let gate = ModuleListGate()
        let cachedModule = module(identifier: "CachedMod", name: "Cached Mod")
        let freshModule = module(identifier: "FreshMod", name: "Fresh Mod")
        let snapshotStore = InMemoryModuleCatalogSnapshotStore(snapshots: [
            "primary": ModuleCatalogSnapshot(
                instanceId: "primary",
                modules: [cachedModule],
                moduleLabels: [
                    ModuleLabelSummary(
                        name: "Cached",
                        instanceName: "primary",
                        colorHex: "#88FF88",
                        hide: false,
                        holdVersion: false,
                        ignoreMissingFiles: false,
                        identifiers: ["CachedMod"]),
                ],
                manageableModuleLabels: [],
                repositories: [
                    RepositorySummary(
                        name: "cached-default",
                        url: "https://example.invalid/cached.tar.gz",
                        priority: 1,
                        isMirror: false,
                        comment: "Cached repository"),
                ],
                launchCommands: ["./cached-ksp"],
                defaultLaunchCommands: ["./cached-ksp"],
                incompatibleLaunchModules: [],
                savedAt: Date(timeIntervalSince1970: 1_000)),
        ])
        var sidecar = FakeSidecar(modulesByInstance: ["primary": [freshModule]])
        sidecar.listModulesGate = gate
        let model = AppModel(
            sidecar: sidecar,
            catalogSnapshotStore: snapshotStore)

        let refreshTask = Task {
            await model.refresh()
        }
        await gate.waitUntilEntered()

        XCTAssertEqual(model.modules.map(\.identifier), ["CachedMod"])
        XCTAssertEqual(model.selectedModuleID, "CachedMod")
        XCTAssertEqual(model.moduleLabels.map(\.name), ["Cached"])
        XCTAssertEqual(model.repositories.map(\.name), ["cached-default"])
        XCTAssertEqual(model.launchCommands, ["./cached-ksp"])
        XCTAssertEqual(model.catalogLoadProgress, AppModel.CatalogLoadProgress(
            detail: "Reading CKAN registry and module metadata for the selected instance."))

        await gate.release()
        await refreshTask.value

        XCTAssertEqual(model.modules.map(\.identifier), ["FreshMod"])
        XCTAssertEqual(model.selectedModuleID, "FreshMod")
        XCTAssertEqual(snapshotStore.snapshots["primary"]?.modules.map(\.identifier), ["FreshMod"])
        XCTAssertNil(model.catalogLoadProgress)
    }

    func testCatalogLoadProgressClearsBeforeSelectedModuleDetailsFinishLoading() async {
        let gate = ModuleDetailsGate()
        let module = module(identifier: "FreshMod", name: "Fresh Mod")
        var sidecar = FakeSidecar(modulesByInstance: ["primary": [module]])
        sidecar.moduleDetailsGate = gate
        let model = AppModel(sidecar: sidecar)

        let refreshTask = Task {
            await model.refresh()
        }
        await gate.waitUntilEntered()

        XCTAssertEqual(model.modules.map(\.identifier), ["FreshMod"])
        XCTAssertEqual(model.selectedModuleID, "FreshMod")
        XCTAssertNil(model.catalogLoadProgress)

        await gate.release()
        await refreshTask.value
    }

    func testDiagnosticsReportIncludesCurrentMackanContext() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.searchText = "label:utility"
        model.addSecondaryModuleSort(.author)
        let report = model.makeDiagnosticsReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            operatingSystemVersion: "macOS test",
            appVersion: "1.0-test")

        XCTAssertTrue(report.contains("Generated: 1970-01-01T00:00:00Z"))
        XCTAssertTrue(report.contains("MACKAN App: 1.0-test"))
        XCTAssertTrue(report.contains("macOS: macOS test"))
        XCTAssertTrue(report.contains("Sidecar: ok; protocol=1; ckan=v1.36.5-test"))
        XCTAssertTrue(report.contains("Sidecar Runtime: MACKAN 1.36.5-test; CKAN v1.36.5-test; protocol 1; 10.0-test; macOS test; Arm64"))
        XCTAssertTrue(report.contains("Selected Instance: Primary KSP (KSP 1.12.5)"))
        XCTAssertTrue(report.contains("Instance Path: /Games/KSP"))
        XCTAssertTrue(report.contains("Repositories: default"))
        XCTAssertTrue(report.contains("Selected Module: SidecarOnlyMod"))
        XCTAssertTrue(report.contains("Search: label:utility"))
        XCTAssertTrue(report.contains("Secondary Sorts: Author ascending"))
    }

    func testDiagnosticsReportIncludesOperationErrorDetailsAndLastOperation() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            applyStatus: "failed",
            applyErrorDetails: .downloadFailures([
                DownloadFailureSummary(
                    identifier: "ModuleManager",
                    name: "Module Manager",
                    version: "4.2.3",
                    message: "Host returned 500",
                    urls: ["https://example.invalid/ModuleManager.zip"]),
            ])))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        let report = model.makeDiagnosticsReport(
            generatedAt: Date(timeIntervalSince1970: 0),
            operatingSystemVersion: "macOS test",
            appVersion: "1.0-test")

        XCTAssertTrue(report.contains("Operation Error: Downloads failed"))
        XCTAssertTrue(report.contains("Operation Error Details: downloadFailures; suggestedAction=skipOrAbort"))
        XCTAssertTrue(report.contains("Download Failure: ModuleManager 4.2.3; Host returned 500; https://example.invalid/ModuleManager.zip"))
        XCTAssertTrue(report.contains("## Last Operation"))
        XCTAssertTrue(report.contains("Operation ID: op-1"))
        XCTAssertTrue(report.contains("Operation Status: failed"))
        XCTAssertTrue(report.contains("Operation Event: progress; 0%; Operation queued; remaining=2048; total=2048"))
    }

    func testAboutInfoIncludesAppAndSidecarVersionMetadata() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        let info = model.aboutInfo(appVersion: "0.1-test")

        XCTAssertEqual(info.title, "MACKAN")
        XCTAssertEqual(info.subtitle, "Native macOS CKAN for Kerbal Space Program")
        XCTAssertEqual(info.rows, [
            AboutInfoRow(label: "MACKAN App", value: "0.1-test"),
            AboutInfoRow(label: "MACKAN Service", value: "1.36.5-test"),
            AboutInfoRow(label: "CKAN Core", value: "v1.36.5-test"),
            AboutInfoRow(label: "Protocol", value: "1"),
            AboutInfoRow(label: ".NET Runtime", value: "10.0-test"),
            AboutInfoRow(label: "Operating System", value: "macOS test"),
            AboutInfoRow(label: "Process Architecture", value: "Arm64"),
        ])
    }

    func testCheckForUpdatesStoresAvailableStatus() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.checkForUpdates(useDevBuilds: false)

        XCTAssertEqual(model.updateCheckResult?.status, "available")
        XCTAssertEqual(model.updateCheckResult?.currentVersion, "v1.0.0-test")
        XCTAssertEqual(model.updateCheckResult?.latestVersion, "v1.1.0")
        XCTAssertEqual(model.updateCheckResult?.latestDisplayVersion, "v1.1.0 aka Mun")
        XCTAssertEqual(model.updateCheckResult?.source, "stable")
        XCTAssertEqual(model.updateCheckResult?.useDevBuilds, false)
        XCTAssertEqual(model.updateCheckResult?.canAutoInstall, false)
        XCTAssertEqual(model.updateCheckResult?.downloadUrls.last, "https://github.com/KSP-CKAN/CKAN/releases/download/v1.1.0/MACKAN.dmg")
        XCTAssertNil(model.updateCheckError)
        XCTAssertFalse(model.isCheckingForUpdates)
    }

    func testCheckForUpdatesSanitizesKnownCoreFailureForNativeUI() async throws {
        var sidecar = FakeSidecar()
        sidecar.updateCheckResult = UpdateCheckResult(
            status: "failed",
            currentVersion: "v1.0.0-test",
            latestVersion: nil,
            latestDisplayVersion: "Unavailable",
            releaseNotes: "",
            source: "stable",
            useDevBuilds: false,
            canAutoInstall: false,
            installMessage: "Install the signed MACKAN DMG from the release page.",
            downloadUrls: [],
            error: "Sequence contains no matching element")
        let model = AppModel(sidecar: sidecar)

        try await model.checkForUpdates(useDevBuilds: false)

        XCTAssertEqual(
            model.updateCheckError,
            "Update metadata could not be read. Try again later or install the signed MACKAN DMG manually from the release page.")
    }

    func testCheckForUpdatesOnLaunchRunsWhenPreferenceIsEnabled() async {
        var sidecar = FakeSidecar()
        sidecar.generalSettingsResult = GeneralSettingsResult(
            instanceId: "primary",
            checkForUpdatesOnLaunch: true,
            useDevBuilds: true,
            refreshRepositoriesOnLaunch: true,
            autoSortByUpdate: true)
        sidecar.expectedCheckForUpdatesUseDevBuilds = true
        sidecar.updateCheckResult = UpdateCheckResult(
            status: "available",
            currentVersion: "v1.0.0-test",
            latestVersion: "v1.1.0-dev",
            latestDisplayVersion: "v1.1.0-dev aka Mun",
            releaseNotes: "Dev build notes",
            source: "dev",
            useDevBuilds: true,
            canAutoInstall: false,
            installMessage: "Install the signed MACKAN DMG from the release page.",
            downloadUrls: [],
            error: nil)
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        let shouldPresent = await model.checkForUpdatesOnLaunchIfNeeded()

        XCTAssertTrue(shouldPresent)
        XCTAssertEqual(model.generalSettings?.checkForUpdatesOnLaunch, true)
        XCTAssertEqual(model.generalSettings?.useDevBuilds, true)
        XCTAssertEqual(model.updateCheckResult?.status, "available")
        XCTAssertEqual(model.updateCheckResult?.source, "dev")
        XCTAssertNil(model.updateCheckError)
    }

    func testCheckForUpdatesOnLaunchSkipsWhenPreferenceIsDisabled() async {
        var sidecar = FakeSidecar()
        sidecar.generalSettingsResult = GeneralSettingsResult(
            instanceId: "primary",
            checkForUpdatesOnLaunch: false,
            useDevBuilds: true,
            refreshRepositoriesOnLaunch: true,
            autoSortByUpdate: true)
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        let shouldPresent = await model.checkForUpdatesOnLaunchIfNeeded()

        XCTAssertFalse(shouldPresent)
        XCTAssertEqual(model.generalSettings?.checkForUpdatesOnLaunch, false)
        XCTAssertNil(model.updateCheckResult)
        XCTAssertNil(model.updateCheckError)
    }

    func testLaunchSettingsRefreshRepositoriesPopulateEmptyStartupCatalog() async {
        let recorder = RepositoryRefreshRecorder()
        let refreshed = module(identifier: "RepositoryLoadedMod", name: "Repository Loaded Mod")
        var sidecar = FakeSidecar(
            modulesByInstance: ["primary": []])
        sidecar.repositoryRefreshRecorder = recorder
        sidecar.modulesAfterRepositoryRefreshByInstance = ["primary": [refreshed]]
        sidecar.generalSettingsResult = GeneralSettingsResult(
            instanceId: "primary",
            checkForUpdatesOnLaunch: false,
            useDevBuilds: false,
            refreshRepositoriesOnLaunch: true,
            autoSortByUpdate: true)
        let model = AppModel(sidecar: sidecar)

        await model.refresh()

        XCTAssertTrue(model.modules.isEmpty)

        let shouldPresentUpdate = await model.checkForUpdatesOnLaunchIfNeeded()
        let refreshRecords = await recorder.records()

        XCTAssertFalse(shouldPresentUpdate)
        XCTAssertEqual(refreshRecords, [
            RepositoryRefreshRecorder.Record(instanceId: "primary", force: false),
        ])
        XCTAssertEqual(model.repositoryRefreshSummary?.operationStatus, "completed")
        XCTAssertEqual(model.modules.map(\.identifier), ["RepositoryLoadedMod"])
        XCTAssertEqual(model.selectedModuleID, "RepositoryLoadedMod")
    }

    func testSelectInstanceReloadsModulesAndSelectedModuleDetails() async {
        let model = AppModel(sidecar: FakeSidecar())
        model.filter = .all

        await model.refresh()
        await model.selectInstance("secondary")

        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnlyMod"])
        XCTAssertEqual(model.selectedModuleID, "SecondaryOnlyMod")
        XCTAssertEqual(model.selectedModuleDetails?.instanceId, "secondary")
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SecondaryOnlyMod")
        XCTAssertEqual(model.selectedModuleDetails?.abstract, "Secondary sidecar detail")
        XCTAssertEqual(model.repositories.map(\.name), ["secondary"])
        XCTAssertEqual(model.launchCommands, ["./KSP-Secondary.app/Contents/MacOS/KSP"])
    }

    func testSelectedModuleDetailsAreCachedAcrossRepeatedSelection() async {
        let recorder = ModuleDetailsCallRecorder()
        var sidecar = FakeSidecar()
        sidecar.moduleDetailsCallRecorder = recorder
        sidecar.modulesByInstance["primary"] = [
            module(identifier: "FirstMod", name: "First Mod"),
            module(identifier: "SecondMod", name: "Second Mod"),
        ]
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        var callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)

        model.selectedModuleID = "SecondMod"
        await model.refreshSelectedModuleDetails()
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SecondMod")
        callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 2)

        model.selectedModuleID = "FirstMod"
        await model.refreshSelectedModuleDetails()
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "FirstMod")
        callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 2)
    }

    func testSelectedModuleDetailsImmediatelyFollowSelectionWhileFullDetailsLoad() async {
        let gate = ModuleDetailsGate()
        let firstModule = module(
            identifier: "FirstMod",
            name: "First Mod",
            abstract: "First summary")
        let secondModule = module(
            identifier: "SecondMod",
            name: "Second Mod",
            latestVersion: "2.0.0",
            tags: ["parts"],
            abstract: "Second summary",
            description: "Second full summary",
            downloadSize: 54_600_000,
            installSize: 19_700_000)
        var sidecar = FakeSidecar(modulesByInstance: ["primary": [firstModule, secondModule]])
        sidecar.moduleDetailsGate = gate
        let model = AppModel(
            sidecar: sidecar,
            instances: primaryInstances(),
            modules: [firstModule, secondModule])
        model.selectedModuleDetails = ModuleDetails(
            instanceId: "primary",
            module: firstModule,
            abstract: "Loaded first details",
            description: "Full first details",
            releaseStatus: "stable",
            kind: "package",
            releaseDate: "2024-01-02T03:04:05.0000000Z",
            downloadSize: 1024,
            installSize: 2048,
            resources: [ModuleResource(label: "Homepage", url: "https://example.invalid/first")],
            tags: ["first"])

        model.selectedModuleID = "SecondMod"
        let refreshTask = Task {
            await model.refreshSelectedModuleDetails()
        }
        await gate.waitUntilEntered()

        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SecondMod")
        XCTAssertEqual(model.selectedModuleDetails?.module.name, "Second Mod")
        XCTAssertEqual(model.selectedModuleDetails?.abstract, "Second summary")
        XCTAssertEqual(model.selectedModuleDetails?.description, "Second full summary")
        XCTAssertEqual(model.selectedModuleDetails?.downloadSize, 54_600_000)
        XCTAssertEqual(model.selectedModuleDetails?.installSize, 19_700_000)
        XCTAssertEqual(model.selectedModuleDetails?.tags, ["parts"])

        await gate.release()
        await refreshTask.value

        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SecondMod")
        XCTAssertEqual(model.selectedModuleDetails?.abstract, "A real sidecar detail")
        XCTAssertEqual(model.selectedModuleDetails?.resources.first?.label, "Homepage")
    }

    func testForcedSelectedModuleDetailsRefreshBypassesCache() async {
        let recorder = ModuleDetailsCallRecorder()
        var sidecar = FakeSidecar()
        sidecar.moduleDetailsCallRecorder = recorder
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        var callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)

        await model.refreshSelectedModuleDetails()
        callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)

        await model.refreshSelectedModuleDetails(force: true)
        callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 2)
    }

    func testSetDefaultInstanceUpdatesInstancesAndSelection() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.setDefaultInstance("secondary")

        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.instances.first(where: { $0.id == "primary" })?.isDefault, false)
        XCTAssertEqual(model.instances.first(where: { $0.id == "secondary" })?.isDefault, true)
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnlyMod"])
    }

    func testSelectedInstanceCommandStateTracksSelectionAndDefault() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertFalse(model.canSetSelectedInstanceAsDefault)
        XCTAssertTrue(model.canOpenSelectedInstanceDirectory)
        XCTAssertTrue(model.canRefreshRepositories)

        await model.selectInstance("secondary")

        XCTAssertTrue(model.canSetSelectedInstanceAsDefault)
        XCTAssertTrue(model.canOpenSelectedInstanceDirectory)
        XCTAssertTrue(model.canRefreshRepositories)

        await model.selectInstance(nil)

        XCTAssertFalse(model.canSetSelectedInstanceAsDefault)
        XCTAssertFalse(model.canOpenSelectedInstanceDirectory)
        XCTAssertFalse(model.canRefreshRepositories)
    }

    func testInstanceManagementRowsExposeNativeActionState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertEqual(model.instanceManagementRows.map(\.id), ["primary", "secondary"])
        let primary = try XCTUnwrap(model.instanceManagementRows.first { $0.id == "primary" })
        XCTAssertTrue(primary.isSelected)
        XCTAssertTrue(primary.isDefault)
        XCTAssertFalse(primary.canSetDefault)
        XCTAssertTrue(primary.canReveal)
        XCTAssertTrue(primary.canRename)
        XCTAssertTrue(primary.canForget)

        await model.selectInstance("secondary")

        let secondary = try XCTUnwrap(model.instanceManagementRows.first { $0.id == "secondary" })
        XCTAssertTrue(secondary.isSelected)
        XCTAssertFalse(secondary.isDefault)
        XCTAssertTrue(secondary.canSetDefault)
        XCTAssertTrue(secondary.canReveal)
    }

    func testSetSelectedInstanceAsDefaultUpdatesInstancesAndSelection() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        await model.selectInstance("secondary")
        try await model.setSelectedInstanceAsDefault()

        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.instances.first(where: { $0.id == "secondary" })?.isDefault, true)
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnlyMod"])
    }

    func testForgetInstanceRemovesInstanceAndSelectsRemainingDefault() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        await model.selectInstance("secondary")
        try await model.forgetInstance("secondary")

        XCTAssertEqual(model.instances.map(\.id), ["primary"])
        XCTAssertEqual(model.selectedInstanceID, "primary")
        XCTAssertEqual(model.modules.map { $0.identifier }, ["SidecarOnlyMod"])
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "SidecarOnlyMod")
    }

    func testRenameInstanceUpdatesInstancesAndSelectedInstanceID() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        model.filter = .all

        await model.refresh()
        await model.selectInstance("secondary")
        try await model.renameInstance("secondary", to: "renamed")

        XCTAssertEqual(model.instances.map(\.id), ["primary", "renamed"])
        XCTAssertEqual(model.selectedInstanceID, "renamed")
        XCTAssertEqual(model.modules.map(\.identifier), ["RenamedOnlyMod"])
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "RenamedOnlyMod")
    }

    func testAddInstanceUpdatesInstancesAndSelectsAddedInstance() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        model.filter = .all

        await model.refresh()
        try await model.addInstance(path: "/Games/KSP-New", name: "New KSP")

        XCTAssertEqual(model.instances.map(\.id), ["primary", "New KSP"])
        XCTAssertEqual(model.selectedInstanceID, "New KSP")
        XCTAssertEqual(model.modules.map(\.identifier), ["NewOnlyMod"])
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "NewOnlyMod")
    }

    func testCloneInstanceUpdatesInstancesAndSelectsClone() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        model.filter = .all

        await model.refresh()
        try await model.cloneInstance(
            sourceInstanceId: "primary",
            newName: "Cloned KSP",
            newPath: "/Games/KSP-Clone",
            shareStock: false,
            leaveEmptyPaths: ["saves", "Screenshots"])

        XCTAssertEqual(model.instances.map(\.id), ["primary", "Cloned KSP"])
        XCTAssertEqual(model.selectedInstanceID, "Cloned KSP")
        XCTAssertEqual(model.modules.map(\.identifier), ["ClonedOnlyMod"])
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "ClonedOnlyMod")
    }

    func testLoadCloneOptionsReturnsLeaveEmptyPaths() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        let options = try await model.loadCloneOptions(sourceInstanceId: "primary")

        XCTAssertEqual(options.sourceInstanceId, "primary")
        XCTAssertEqual(options.leaveEmptyPaths, ["saves", "Screenshots", "CKAN/downloads"])
    }

    func testFakeInstanceUpdatesInstancesAndSelectsFakeInstance() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.fakeInstance(
            name: "Fake KSP",
            path: "/Games/KSP-Fake",
            version: "1.12.5",
            gameId: "KSP",
            makingHistoryVersion: "1.12.1",
            breakingGroundVersion: "1.7.1",
            setDefault: true)

        XCTAssertEqual(model.instances.map(\.id), ["Fake KSP"])
        XCTAssertEqual(model.selectedInstanceID, "Fake KSP")
        XCTAssertEqual(model.modules.map(\.identifier), ["FakeOnlyMod"])
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "FakeOnlyMod")
    }

    func testOpenSelectedInstanceDirectoryRevealsSelectedInstancePath() async throws {
        let opener = RecordingInstanceDirectoryOpener()
        let model = AppModel(sidecar: FakeSidecar(), directoryOpener: opener)

        await model.refresh()
        try model.openSelectedInstanceDirectory()
        await model.selectInstance("secondary")
        try model.openSelectedInstanceDirectory()

        XCTAssertEqual(opener.revealedURLs.map(\.path), ["/Games/KSP", "/Games/KSP-Secondary"])
    }

    func testLaunchSelectedGameUsesFirstLaunchCommand() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.launchSelectedGame()

        XCTAssertEqual(model.lastLaunchResult?.instanceId, "primary")
        XCTAssertEqual(model.lastLaunchResult?.commandLine, "./KSP.app/Contents/MacOS/KSP")
        XCTAssertEqual(model.lastLaunchResult?.status, "started")
        XCTAssertEqual(model.lastLaunchResult?.processId, 12345)
        XCTAssertNil(model.launchError)
    }

    func testLaunchSelectedGameStoresLaunchFailureErrorDetails() async throws {
        let sidecar = FakeSidecar(launchGameError: .launchFailure(
            message: "Failed to launch game with command 'missing-ksp-launch-binary'.",
            command: "missing-ksp-launch-binary",
            suggestedAction: "retryOrCheckCommand"))
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        do {
            try await model.launchSelectedGame()
            XCTFail("Expected launch failure")
        } catch {
            XCTAssertEqual(
                error as? SidecarClientError,
                .launchFailure(
                    message: "Failed to launch game with command 'missing-ksp-launch-binary'.",
                    command: "missing-ksp-launch-binary",
                    suggestedAction: "retryOrCheckCommand"))
        }

        XCTAssertEqual(
            model.launchError,
            "Failed to launch game with command 'missing-ksp-launch-binary'. (command: missing-ksp-launch-binary)")
        XCTAssertEqual(model.launchErrorDetails?.kind, "launchFailure")
        XCTAssertEqual(model.launchErrorDetails?.command, "missing-ksp-launch-binary")
        XCTAssertEqual(model.launchErrorDetails?.suggestedAction, "retryOrCheckCommand")
    }

    func testLaunchSelectedGameStoresWarningInsteadOfLaunchingWithIncompatibleModules() async throws {
        let sidecar = FakeSidecar(incompatibleLaunchModules: [
            LaunchWarningModule(
                identifier: "OldMod",
                name: "Old Mod",
                version: "0.9.0",
                compatibleGameVersions: "KSP 1.8"),
        ])
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.launchSelectedGame()

        XCTAssertEqual(model.pendingLaunchWarning?.commandLine, "./KSP.app/Contents/MacOS/KSP")
        XCTAssertEqual(model.pendingLaunchWarning?.modules.map(\.identifier), ["OldMod"])
        XCTAssertNil(model.lastLaunchResult)
        XCTAssertNil(model.launchError)
    }

    func testConfirmPendingLaunchWarningSuppressesAndLaunches() async throws {
        let sidecar = FakeSidecar(incompatibleLaunchModules: [
            LaunchWarningModule(
                identifier: "OldMod",
                name: "Old Mod",
                version: "0.9.0",
                compatibleGameVersions: "KSP 1.8"),
        ])
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.launchSelectedGame()
        try await model.confirmPendingLaunchWarning(suppressFutureWarnings: true)

        XCTAssertNil(model.pendingLaunchWarning)
        XCTAssertTrue(model.incompatibleLaunchModules.isEmpty)
        XCTAssertEqual(model.lastLaunchResult?.commandLine, "./KSP.app/Contents/MacOS/KSP")
        XCTAssertNil(model.launchError)
    }

    func testCancelPendingLaunchWarningClearsWarningWithoutLaunching() async throws {
        let model = AppModel(sidecar: FakeSidecar(incompatibleLaunchModules: [
            LaunchWarningModule(
                identifier: "OldMod",
                name: "Old Mod",
                version: "0.9.0",
                compatibleGameVersions: "KSP 1.8"),
        ]))

        await model.refresh()
        try await model.launchSelectedGame()
        model.cancelPendingLaunchWarning()

        XCTAssertNil(model.pendingLaunchWarning)
        XCTAssertNil(model.lastLaunchResult)
        XCTAssertNil(model.launchError)
    }

    func testSaveLaunchCommandsUpdatesLaunchMenuOptions() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.saveLaunchCommands(["./KSP.app/Contents/MacOS/KSP -popupwindow"])

        XCTAssertEqual(model.launchCommands, ["./KSP.app/Contents/MacOS/KSP -popupwindow"])
        XCTAssertEqual(model.defaultLaunchCommands, ["./KSP.app/Contents/MacOS/KSP"])
        XCTAssertNil(model.launchError)
    }

    func testResetLaunchCommandsToDefaultsSavesDefaultOptions() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.resetLaunchCommandsToDefaults()

        XCTAssertEqual(model.launchCommands, ["./KSP.app/Contents/MacOS/KSP"])
        XCTAssertEqual(model.defaultLaunchCommands, ["./KSP.app/Contents/MacOS/KSP"])
        XCTAssertNil(model.launchError)
    }

    func testAddRepositoryUpdatesRepositoryList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.addRepository(name: "newrepo", url: "https://example.invalid/newrepo.tar.gz")

        XCTAssertEqual(model.repositories.map(\.name), ["default", "newrepo"])
        XCTAssertEqual(model.repositories.map(\.priority), [0, 1])
    }

    func testRemoveRepositoryUpdatesRepositoryList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.removeRepository(name: "default")

        XCTAssertEqual(model.repositories.map(\.name), ["mirror"])
        XCTAssertEqual(model.repositories.map(\.priority), [0])
    }

    func testSetRepositoryPriorityUpdatesRepositoryList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.setRepositoryPriority(name: "mirror", priority: 0)

        XCTAssertEqual(model.repositories.map(\.name), ["mirror", "default"])
        XCTAssertEqual(model.repositories.map(\.priority), [0, 1])
    }

    func testRepositoryManagementRowsExposeNativeActionState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertEqual(model.repositoryManagementRows.map(\.id), ["default"])
        let onlyRepository = try XCTUnwrap(model.repositoryManagementRows.first)
        XCTAssertFalse(onlyRepository.canMoveUp)
        XCTAssertFalse(onlyRepository.canMoveDown)
        XCTAssertFalse(onlyRepository.canRemove)

        try await model.addRepository(name: "newrepo", url: "https://example.invalid/newrepo.tar.gz")

        XCTAssertEqual(model.repositoryManagementRows.map(\.id), ["default", "newrepo"])
        let defaultRepository = try XCTUnwrap(model.repositoryManagementRows.first { $0.id == "default" })
        XCTAssertFalse(defaultRepository.canMoveUp)
        XCTAssertTrue(defaultRepository.canMoveDown)
        XCTAssertTrue(defaultRepository.canRemove)

        let newRepository = try XCTUnwrap(model.repositoryManagementRows.first { $0.id == "newrepo" })
        XCTAssertTrue(newRepository.canMoveUp)
        XCTAssertFalse(newRepository.canMoveDown)
        XCTAssertTrue(newRepository.canRemove)
    }

    func testRefreshRepositoriesUpdatesSummaryAndList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.refreshRepositories(force: true)

        XCTAssertEqual(model.repositoryRefreshSummary?.operationStatus, "completed")
        XCTAssertEqual(model.repositoryRefreshSummary?.status, "updated")
        XCTAssertEqual(model.repositoryRefreshSummary?.compatibleModuleCount, 42)
        XCTAssertEqual(model.repositoryRefreshSummary?.events.last?.message, "Done")
        XCTAssertEqual(model.repositories.map(\.name), ["default"])
    }

    func testRefreshRepositoriesStoresRunningOperationForPolling() async throws {
        var sidecar = FakeSidecar()
        sidecar.repositoryStartOperationStatus = "running"
        sidecar.repositoryStartRefreshStatus = "running"
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.refreshRepositories(force: true)

        XCTAssertEqual(model.repositoryRefreshSummary?.operationId, "repo-op")
        XCTAssertEqual(model.repositoryRefreshSummary?.operationStatus, "running")
        XCTAssertEqual(model.repositoryRefreshSummary?.status, "running")
        XCTAssertEqual(model.repositoryRefreshSummary?.events.first?.message, "Repository refresh queued")
        XCTAssertEqual(model.repositories.map(\.name), ["default"])
    }

    func testRefreshRepositoryStatusReloadsModulesOnCompletion() async throws {
        var sidecar = FakeSidecar()
        sidecar.repositoryStartOperationStatus = "running"
        sidecar.repositoryStartRefreshStatus = "running"
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.refreshRepositories(force: true)
        try await model.refreshRepositoryRefreshStatus()

        XCTAssertEqual(model.repositoryRefreshSummary?.operationId, "repo-op")
        XCTAssertEqual(model.repositoryRefreshSummary?.operationStatus, "completed")
        XCTAssertEqual(model.repositoryRefreshSummary?.status, "updated")
        XCTAssertEqual(model.repositoryRefreshSummary?.compatibleModuleCount, 42)
        XCTAssertEqual(model.repositoryRefreshSummary?.events.last?.message, "Done")
        XCTAssertEqual(model.repositories.map(\.name), ["default"])
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
    }

    func testRefreshRepositoryStatusStoresFailureDetailsWithoutReloadingModules() async throws {
        var sidecar = FakeSidecar()
        sidecar.repositoryStartOperationStatus = "running"
        sidecar.repositoryStartRefreshStatus = "running"
        sidecar.repositoryStatusOperationStatus = "failed"
        sidecar.repositoryStatusRefreshStatus = "failed"
        sidecar.repositoryRefreshError = "Repository metadata download failed"
        sidecar.repositoryRefreshErrorDetails = SidecarErrorDetails(
            kind: "downloadFailures",
            lockfilePath: nil,
            suggestedAction: "retryOrEditRepository",
            downloadFailures: [
                DownloadFailureSummary(
                    identifier: "broken",
                    name: "broken",
                    version: "metadata",
                    message: "File not found",
                    urls: ["file:///tmp/missing-repository.tar.gz"]),
            ])
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        let modulesBeforeRefresh = model.modules
        try await model.refreshRepositories(force: true)
        try await model.refreshRepositoryRefreshStatus()

        XCTAssertEqual(model.repositoryRefreshSummary?.operationStatus, "failed")
        XCTAssertEqual(model.repositoryRefreshSummary?.status, "failed")
        XCTAssertEqual(model.repositoryRefreshSummary?.error, "Repository metadata download failed")
        XCTAssertEqual(model.repositoryRefreshSummary?.errorDetails?.kind, "downloadFailures")
        XCTAssertEqual(model.repositoryRefreshSummary?.errorDetails?.suggestedAction, "retryOrEditRepository")
        XCTAssertEqual(model.repositoryRefreshSummary?.errorDetails?.downloadFailures?.first?.identifier, "broken")
        XCTAssertEqual(model.modules, modulesBeforeRefresh)
    }

    func testMaintenancePaneSelectionUsesPersistentMainContentRouteUntilInstanceSelection() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        XCTAssertEqual(model.mainContentRoute, .catalog)

        model.showMaintenancePane(.unmanagedFiles)

        XCTAssertEqual(model.mainContentRoute, .maintenance(.unmanagedFiles))

        await model.selectInstance("secondary")

        XCTAssertEqual(model.mainContentRoute, .catalog)
    }

    func testSelectInstanceIgnoresUnknownSidebarSelectionIdentifiers() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.showMaintenancePane(.unmanagedFiles)
        await model.selectInstance("history")

        XCTAssertEqual(model.selectedInstanceID, "primary")
        XCTAssertEqual(model.mainContentRoute, .maintenance(.unmanagedFiles))
        XCTAssertEqual(model.healthState, .ready(SidecarHealth(
            status: "ok",
            protocolVersion: "1",
            ckanVersion: "v1.36.5-test")))
    }

    func testMaintenancePaneSheetPresentationIsSuppressedByPersistentPane() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadMaintenancePane(.unmanagedFiles)

        XCTAssertTrue(model.shouldPresentMaintenanceSheet(for: .unmanagedFiles))
        XCTAssertFalse(model.shouldPresentMaintenanceSheet(for: .history))

        model.showMaintenancePane(.unmanagedFiles)

        XCTAssertFalse(model.shouldPresentMaintenanceSheet(for: .unmanagedFiles))
        XCTAssertNil(model.unmanagedFilesResult)

        try await model.loadMaintenancePane(.unmanagedFiles)
        XCTAssertNotNil(model.unmanagedFilesResult)

        model.closeMaintenancePane()

        XCTAssertEqual(model.mainContentRoute, .catalog)
        XCTAssertNil(model.unmanagedFilesResult)
        XCTAssertFalse(model.shouldPresentMaintenanceSheet(for: .unmanagedFiles))
    }

    func testLeavingInlineMaintenancePaneClearsResultBeforeLegacySheetCanPresent() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.showMaintenancePane(.downloadStatistics)
        try await model.loadMaintenancePane(.downloadStatistics)

        XCTAssertNotNil(model.downloadStatisticsResult)
        XCTAssertFalse(model.shouldPresentMaintenanceSheet(for: .downloadStatistics))

        model.showCatalog()

        XCTAssertEqual(model.mainContentRoute, .catalog)
        XCTAssertNil(model.downloadStatisticsResult)
        XCTAssertFalse(model.shouldPresentMaintenanceSheet(for: .downloadStatistics))
    }

    func testMaintenancePaneLoaderDispatchesThroughSingleModelBoundary() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        try await model.loadMaintenancePane(.history)
        XCTAssertNotNil(model.installationHistoryResult)
        model.clearMaintenanceResult(for: .history)
        XCTAssertNil(model.installationHistoryResult)

        try await model.loadMaintenancePane(.playTime)
        XCTAssertNotNil(model.playTimeResult)
        model.clearMaintenanceResult(for: .playTime)
        XCTAssertNil(model.playTimeResult)

        try await model.loadMaintenancePane(.downloadStatistics)
        XCTAssertNotNil(model.downloadStatisticsResult)
        model.clearMaintenanceResult(for: .downloadStatistics)
        XCTAssertNil(model.downloadStatisticsResult)

        try await model.loadMaintenancePane(.cache)
        XCTAssertNotNil(model.cacheInfoResult)
        model.clearMaintenanceResult(for: .cache)
        XCTAssertNil(model.cacheInfoResult)
        XCTAssertNil(model.lastCachePurgeResult)
    }

    func testBuiltInSavedSearchAppliesCatalogFilterAndClearsAdHocSearch() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "AvailableMod", name: "Available Mod", status: .available),
                module(identifier: "UpgradeableMod", name: "Upgradeable Mod", status: .upgradable, isInstalled: true, hasUpdate: true),
            ])

        model.searchText = "label:utility"
        model.tagFilter = "visual"
        model.showMaintenancePane(.cache)

        model.applyBuiltInSavedSearch(.upgradable)

        XCTAssertEqual(model.mainContentRoute, .catalog)
        XCTAssertEqual(model.filter, .upgradable)
        XCTAssertEqual(model.searchText, "")
        XCTAssertNil(model.tagFilter)
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["UpgradeableMod"])
        XCTAssertEqual(model.selectedModuleID, "UpgradeableMod")
        XCTAssertNil(model.catalogLoadProgress)
    }

    func testScanGameDataStoresResultAndReloadsInstanceState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.scanGameData()

        XCTAssertEqual(model.lastMaintenanceScanResult?.instanceId, "primary")
        XCTAssertEqual(model.lastMaintenanceScanResult?.changed, true)
        XCTAssertEqual(model.lastMaintenanceScanResult?.detectedDllCount, 2)
        XCTAssertEqual(model.lastMaintenanceScanResult?.detectedDlcCount, 1)
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.maintenanceError)
    }

    func testLoadUnmanagedFilesStoresResultWithoutReloadingCatalog() async throws {
        let recorder = ModuleListOperationRecorder()
        var sidecar = FakeSidecar()
        sidecar.moduleListStartRecorder = recorder
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        let recordedCatalogLoadsBeforeUnmanagedFiles = await recorder.recordedOperationIDs()

        try await model.loadUnmanagedFiles()

        XCTAssertEqual(model.unmanagedFilesResult?.instanceId, "primary")
        XCTAssertEqual(model.unmanagedFilesResult?.changed, true)
        XCTAssertEqual(model.unmanagedFilesResult?.files.map(\.identifier), ["ManualPlugin", "MakingHistory-DLC"])
        XCTAssertEqual(model.unmanagedFilesResult?.files[0].path, "GameData/Manual/ManualPlugin.dll")
        XCTAssertEqual(model.unmanagedFilesResult?.files[1].version, "1.12.1 (unmanaged)")
        let recordedCatalogLoadsAfterUnmanagedFiles = await recorder.recordedOperationIDs()
        XCTAssertEqual(recordedCatalogLoadsAfterUnmanagedFiles, recordedCatalogLoadsBeforeUnmanagedFiles)
        XCTAssertNil(model.maintenanceError)
    }

    func testOpenUnmanagedFileRevealsFileUnderSelectedInstancePath() async throws {
        let opener = RecordingInstanceDirectoryOpener()
        let model = AppModel(sidecar: FakeSidecar(), directoryOpener: opener)

        await model.refresh()
        try await model.loadUnmanagedFiles()
        let file = try XCTUnwrap(model.unmanagedFilesResult?.files.first)

        try model.openUnmanagedFile(file)

        XCTAssertEqual(opener.revealedURLs.map(\.path), [
            "/Games/KSP/GameData/Manual/ManualPlugin.dll",
        ])
    }

    func testOpenUnmanagedFileRequiresFilePath() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        let file = UnmanagedFileSummary(
            identifier: "MakingHistory-DLC",
            kind: "dlc",
            version: "1.12.1 (unmanaged)",
            path: nil)

        await model.refresh()

        XCTAssertThrowsError(try model.openUnmanagedFile(file)) { error in
            XCTAssertEqual(error as? InstanceDirectoryOpenError, .missingFilePath)
        }
    }

    func testLoadInstallationHistoryStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadInstallationHistory()

        XCTAssertEqual(model.installationHistoryResult?.instanceId, "primary")
        XCTAssertEqual(model.installationHistoryResult?.entries.count, 1)
        XCTAssertEqual(model.installationHistoryResult?.entries[0].fileName, "installed-Primary_KSP-2026-05-31_10-00-00.ckan")
        XCTAssertEqual(model.installationHistoryResult?.entries[0].moduleCount, 1)
        XCTAssertNil(model.selectedInstallationHistoryEntry)
        XCTAssertNil(model.maintenanceError)
    }

    func testLoadInstallationHistoryEntryStoresSelectedEntry() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadInstallationHistory()
        try await model.loadInstallationHistoryEntry(fileName: "installed-Primary_KSP-2026-05-31_10-00-00.ckan")

        XCTAssertEqual(model.selectedInstallationHistoryEntry?.fileName, "installed-Primary_KSP-2026-05-31_10-00-00.ckan")
        XCTAssertEqual(model.selectedInstallationHistoryEntry?.modules.map(\.identifier), ["ModuleManager"])
        XCTAssertEqual(model.selectedInstallationHistoryEntry?.modules[0].version, "4.2.3")
        XCTAssertEqual(model.selectedInstallationHistoryEntry?.modules[0].isInstalled, false)
        XCTAssertEqual(model.selectedInstallationHistoryEntry?.modules[0].isAvailable, true)
        XCTAssertNil(model.maintenanceError)
    }

    func testStageHistoryModulesOnlyStagesMissingAvailableModules() {
        let model = AppModel(sidecar: FakeSidecar())

        model.stageHistoryModules([
            InstallationHistoryModule(
                identifier: "InstallableMod",
                name: "Installable Mod",
                version: "1.0.0",
                author: nil,
                abstract: nil,
                isInstalled: false,
                isAvailable: true),
            InstallationHistoryModule(
                identifier: "AlreadyInstalled",
                name: "Already Installed",
                version: "1.0.0",
                author: nil,
                abstract: nil,
                isInstalled: true,
                isAvailable: true),
            InstallationHistoryModule(
                identifier: "MissingMetadata",
                name: "Missing Metadata",
                version: "1.0.0",
                author: nil,
                abstract: nil,
                isInstalled: false,
                isAvailable: false),
        ])

        XCTAssertEqual(model.stagedAction(for: "InstallableMod"), .install)
        XCTAssertNil(model.stagedAction(for: "AlreadyInstalled"))
        XCTAssertNil(model.stagedAction(for: "MissingMetadata"))
    }

    func testStageHistoryModulesWithExactVersionsPassesSnapshotVersionsToResolver() async throws {
        let exactSelection = VersionedModuleSelection(identifier: "InstallableMod", version: "1.0.0")
        let model = AppModel(sidecar: FakeSidecar(
            expectedResolveInstall: [],
            expectedResolveInstallVersions: [exactSelection]))

        await model.refresh()
        model.stageHistoryModules([
            InstallationHistoryModule(
                identifier: "InstallableMod",
                name: "Installable Mod",
                version: "1.0.0",
                author: nil,
                abstract: nil,
                isInstalled: false,
                isAvailable: true),
            InstallationHistoryModule(
                identifier: "AlreadyInstalled",
                name: "Already Installed",
                version: "1.0.0",
                author: nil,
                abstract: nil,
                isInstalled: true,
                isAvailable: true),
        ], exactVersions: true)

        try await model.resolveChanges()

        XCTAssertEqual(model.versionedInstallSelections, [exactSelection])
        XCTAssertEqual(model.stagedAction(for: "InstallableMod"), .install)
        XCTAssertNil(model.stagedAction(for: "AlreadyInstalled"))
        XCTAssertEqual(model.pendingChangeSet?.changes.first?.identifier, "InstallableMod")
        XCTAssertEqual(model.pendingChangeSet?.changes.first?.toVersion, "1.0.0")
    }

    func testLoadPlayTimeStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.loadPlayTime()

        XCTAssertEqual(model.playTimeResult?.totalHours, 12.5)
        XCTAssertEqual(model.playTimeResult?.totalDisplay, "12.5")
        XCTAssertEqual(model.playTimeResult?.entries.map(\.instanceId), ["primary", "secondary"])
        XCTAssertEqual(model.playTimeResult?.entries[0].name, "Primary KSP")
        XCTAssertEqual(model.playTimeResult?.entries[0].path, "/Games/KSP")
        XCTAssertEqual(model.playTimeResult?.entries[0].hours, 12.5)
        XCTAssertNil(model.maintenanceError)
    }

    func testUpdatePlayTimeStoresUpdatedResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.updatePlayTime(instanceId: "primary", hours: 14.25)

        XCTAssertEqual(model.playTimeResult?.totalHours, 14.25)
        XCTAssertEqual(model.playTimeResult?.totalDisplay, "14.3")
        XCTAssertEqual(model.playTimeResult?.entries.map(\.instanceId), ["primary"])
        XCTAssertEqual(model.playTimeResult?.entries[0].hours, 14.25)
        XCTAssertNil(model.maintenanceError)
    }

    func testLoadDownloadStatisticsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadDownloadStatistics()

        XCTAssertEqual(model.downloadStatisticsResult?.instanceId, "primary")
        XCTAssertEqual(model.downloadStatisticsResult?.totalBytes, 2048)
        XCTAssertEqual(model.downloadStatisticsResult?.totalDisplay, "2 KiB")
        XCTAssertEqual(model.downloadStatisticsResult?.hosts.map(\.host), ["spacedock.info", "archive.org"])
        XCTAssertEqual(model.downloadStatisticsResult?.hosts[0].bytes, 1536)
        XCTAssertEqual(model.downloadStatisticsResult?.hosts[0].display, "1.5 KiB")
        XCTAssertNil(model.maintenanceError)
    }

    func testLoadDownloadStatisticsFailureUsesDownloadStatisticsErrorTitle() async {
        let model = AppModel(sidecar: FakeSidecar(
            downloadStatisticsError: .rpcError(
                code: -32000,
                message: "An item with the same key has already been added.")))

        await model.refresh()

        do {
            try await model.loadDownloadStatistics()
            XCTFail("Expected download statistics to fail")
        } catch {
            XCTAssertEqual(model.maintenanceError, "An item with the same key has already been added.")
            XCTAssertEqual(model.maintenanceErrorTitle, "Download Statistics failed")
            XCTAssertNil(model.downloadStatisticsResult)
        }
    }

    func testLoadCacheInfoStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.loadCacheInfo()

        XCTAssertEqual(model.cacheInfoResult?.path, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(model.cacheInfoResult?.fileCount, 7)
        XCTAssertEqual(model.cacheInfoResult?.bytes, 4096)
        XCTAssertEqual(model.cacheInfoResult?.display, "4 KiB")
        XCTAssertEqual(model.cacheInfoResult?.limitBytes, 2048)
        XCTAssertEqual(model.cacheInfoResult?.limitDisplay, "2 KiB")
        XCTAssertEqual(model.cacheInfoResult?.isOverLimit, true)
        XCTAssertNil(model.lastCachePurgeResult)
        XCTAssertNil(model.maintenanceError)
    }

    func testLoadSettingsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.loadSettings()

        XCTAssertEqual(model.settings?.downloadCacheDir, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(model.settings?.defaultDownloadCacheDir, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(model.settings?.isDefaultDownloadCacheDir, true)
        XCTAssertEqual(model.settings?.cacheSizeLimitBytes, 1_073_741_824)
        XCTAssertEqual(model.settings?.cacheSizeLimitDisplay, "1 GiB")
        XCTAssertNil(model.settingsError)
    }

    func testUpdateSettingsStoresResultAndRefreshesCacheInfo() async throws {
        let model = AppModel(sidecar: FakeSidecar(cacheInfoPath: "/Users/test/CKANCache"))

        try await model.updateSettings(
            downloadCacheDir: "/Users/test/CKANCache",
            cacheSizeLimitBytes: nil,
            cacheMigrationChoice: .move)

        XCTAssertEqual(model.settings?.downloadCacheDir, "/Users/test/CKANCache")
        XCTAssertFalse(model.settings?.isDefaultDownloadCacheDir ?? true)
        XCTAssertNil(model.settings?.cacheSizeLimitBytes)
        XCTAssertEqual(model.cacheInfoResult?.path, "/Users/test/CKANCache")
        XCTAssertNil(model.settingsError)
    }

    func testLoadGeneralSettingsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadGeneralSettings()

        XCTAssertEqual(model.generalSettings?.instanceId, "primary")
        XCTAssertEqual(model.generalSettings?.checkForUpdatesOnLaunch, true)
        XCTAssertEqual(model.generalSettings?.useDevBuilds, false)
        XCTAssertEqual(model.generalSettings?.refreshRepositoriesOnLaunch, true)
        XCTAssertEqual(model.generalSettings?.autoSortByUpdate, true)
        XCTAssertNil(model.settingsError)
    }

    func testUpdateGeneralSettingsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateGeneralSettings(
            checkForUpdatesOnLaunch: false,
            useDevBuilds: true,
            refreshRepositoriesOnLaunch: false,
            autoSortByUpdate: false)

        XCTAssertEqual(model.generalSettings?.instanceId, "primary")
        XCTAssertEqual(model.generalSettings?.checkForUpdatesOnLaunch, false)
        XCTAssertEqual(model.generalSettings?.useDevBuilds, true)
        XCTAssertEqual(model.generalSettings?.refreshRepositoriesOnLaunch, false)
        XCTAssertEqual(model.generalSettings?.autoSortByUpdate, false)
        XCTAssertNil(model.settingsError)
    }

    func testUpdateRecommendationSettingsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateSuppressRecommendations(true)

        XCTAssertEqual(model.recommendationSettings?.instanceId, "primary")
        XCTAssertEqual(model.recommendationSettings?.suppressRecommendations, true)
        XCTAssertNil(model.settingsError)
    }

    func testLoadCompatibleGameVersionsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadCompatibleGameVersions()

        XCTAssertEqual(model.compatibleGameVersions?.instanceId, "primary")
        XCTAssertEqual(model.compatibleGameVersions?.actualGameVersion, "1.12.5")
        XCTAssertEqual(model.compatibleGameVersions?.gameVersionWhenWritten, "1.12.4")
        XCTAssertEqual(model.compatibleGameVersions?.compatibleVersionsAreFromDifferentGameVersion, true)
        XCTAssertEqual(model.compatibleGameVersions?.compatibleVersions, ["1.12.4", "1.11.2"])
        XCTAssertEqual(model.compatibleGameVersions?.availableVersions, ["1.12.4", "1.12", "1.11.2", "1.11"])
        XCTAssertNil(model.settingsError)
    }

    func testUpdateCompatibleGameVersionsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateCompatibleGameVersions(["1.12.4", "1.11"])

        XCTAssertEqual(model.compatibleGameVersions?.compatibleVersions, ["1.12.4", "1.11"])
        XCTAssertFalse(model.compatibleGameVersions?.compatibleVersionsAreFromDifferentGameVersion ?? true)
        XCTAssertNil(model.settingsError)
    }

    func testLoadStabilityToleranceStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadStabilityTolerance()

        XCTAssertEqual(model.stabilityTolerance?.instanceId, "primary")
        XCTAssertEqual(model.stabilityTolerance?.overallStabilityTolerance, "testing")
        XCTAssertEqual(model.stabilityTolerance?.availableStabilityTolerances, ["stable", "testing", "development"])
        XCTAssertEqual(model.stabilityTolerance?.moduleStabilityTolerances.map(\.identifier), ["ModuleManager", "UnstableAddon"])
        XCTAssertNil(model.settingsError)
    }

    func testUpdateStabilityToleranceStoresResultAndRefreshesInstanceState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateStabilityTolerance("development")

        XCTAssertEqual(model.stabilityTolerance?.overallStabilityTolerance, "development")
        XCTAssertNil(model.settingsError)
    }

    func testUpdateModuleStabilityToleranceStoresResultAndCanClearOverride() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateModuleStabilityTolerance(identifier: "ModuleManager", stabilityTolerance: "testing")
        try await model.updateModuleStabilityTolerance(identifier: "ModuleManager", stabilityTolerance: nil)

        XCTAssertEqual(model.stabilityTolerance?.moduleStabilityTolerances, [])
        XCTAssertNil(model.settingsError)
    }

    func testLoadPreferredHostsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadPreferredHosts()

        XCTAssertEqual(model.preferredHosts?.instanceId, "primary")
        XCTAssertEqual(model.preferredHosts?.availableHosts, ["github.com", "spacedock.info", "archive.org"])
        XCTAssertEqual(model.preferredHosts?.preferredHosts, ["github.com", nil, "spacedock.info"])
        XCTAssertEqual(model.preferredHosts?.placeholderLabel, "<ALL OTHER HOSTS>")
        XCTAssertNil(model.settingsError)
    }

    func testUpdatePreferredHostsStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updatePreferredHosts(["github.com", nil, "spacedock.info"])

        XCTAssertEqual(model.preferredHosts?.preferredHosts, ["github.com", nil, "spacedock.info"])
        XCTAssertNil(model.settingsError)
    }

    func testLoadInstallFiltersStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadInstallFilters()

        XCTAssertEqual(model.installFilters?.instanceId, "primary")
        XCTAssertEqual(model.installFilters?.game, "KSP")
        XCTAssertEqual(model.installFilters?.globalFilters, ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(model.installFilters?.instanceFilters, ["GameData/TestMod/Extras"])
        XCTAssertEqual(model.installFilters?.presets.map(\.name), ["MiniAVC", "Craft files"])
        XCTAssertNil(model.settingsError)
    }

    func testUpdateInstallFiltersStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.updateInstallFilters(
            globalFilters: ["Ships", "MiniAVC.dll"],
            instanceFilters: ["GameData/TestMod/Extras"])

        XCTAssertEqual(model.installFilters?.globalFilters, ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(model.installFilters?.instanceFilters, ["GameData/TestMod/Extras"])
        XCTAssertNil(model.settingsError)
    }

    func testLoadAuthTokensStoresMaskedTokenList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.loadAuthTokens()

        XCTAssertEqual(model.authTokens.map(\.host), ["api.github.com", "github.com"])
        XCTAssertEqual(model.authTokens.map(\.tokenPreview), ["********7890", "********cdef"])
        XCTAssertNil(model.settingsError)
    }

    func testAddAndRemoveAuthTokenStoreUpdatedList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.addAuthToken(host: " github.com ", token: " abcdef ")
        XCTAssertEqual(model.authTokens.map(\.host), ["github.com"])
        XCTAssertEqual(model.authTokens.map(\.tokenPreview), ["********cdef"])

        try await model.removeAuthToken(host: "github.com")
        XCTAssertTrue(model.authTokens.isEmpty)
        XCTAssertNil(model.settingsError)
    }

    func testClearCacheStoresPurgeResultAndRefreshesInfo() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.clearCache()

        XCTAssertEqual(model.lastCachePurgeResult?.mode, "all")
        XCTAssertEqual(model.lastCachePurgeResult?.purgedFileCount, 7)
        XCTAssertEqual(model.lastCachePurgeResult?.purgedBytes, 4096)
        XCTAssertEqual(model.cacheInfoResult?.fileCount, 0)
        XCTAssertNil(model.maintenanceError)
    }

    func testPurgeCacheToLimitUsesSelectedInstanceAndStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.purgeCacheToLimit()

        XCTAssertEqual(model.lastCachePurgeResult?.mode, "limit")
        XCTAssertEqual(model.lastCachePurgeResult?.purgedFileCount, 2)
        XCTAssertEqual(model.lastCachePurgeResult?.purgedBytes, 2048)
        XCTAssertEqual(model.cacheInfoResult?.isOverLimit, false)
        XCTAssertNil(model.maintenanceError)
    }

    func testDeduplicateStoresResult() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.deduplicate()

        XCTAssertEqual(model.lastDeduplicateResult?.status, "completed")
        XCTAssertEqual(model.lastDeduplicateResult?.events.map(\.kind), ["message", "progress"])
        XCTAssertEqual(model.lastDeduplicateResult?.events.last?.percent, 100)
        XCTAssertNil(model.lastDeduplicateResult?.error)
        XCTAssertNil(model.maintenanceError)
    }

    func testRepairRegistryStoresResultAndRefreshesInstanceState() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(),
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true),
            ],
            modules: SampleData.modules)

        try await model.repairRegistry()

        XCTAssertEqual(model.lastRepairRegistryResult?.instanceId, "primary")
        XCTAssertEqual(model.lastRepairRegistryResult?.status, "completed")
        XCTAssertEqual(model.lastRepairRegistryResult?.events.map(\.message).last, "Registry repairs attempted. Hope it helped.")
        XCTAssertNil(model.lastRepairRegistryResult?.error)
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.maintenanceError)
    }

    func testRemoveRegistryLockStoresResultAndRefreshesInstanceState() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(),
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isMaybeLocked: true),
            ],
            modules: SampleData.modules)

        try await model.removeRegistryLock()

        XCTAssertEqual(model.lastRegistryLockRemovalResult?.instanceId, "primary")
        XCTAssertEqual(model.lastRegistryLockRemovalResult?.lockfilePath, "/Games/KSP/CKAN/registry.locked")
        XCTAssertEqual(model.lastRegistryLockRemovalResult?.status, "removed")
        XCTAssertTrue(model.lastRegistryLockRemovalResult?.removed == true)
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.maintenanceError)
    }

    func testUpgradeAllCommandStateTracksUpgradableModules() {
        let upgradable = ModuleSummary(
            identifier: "UpgradeableMod",
            name: "Upgradeable Mod",
            author: "Example",
            status: .upgradable,
            installedVersion: "1.0.0",
            latestVersion: "2.0.0",
            license: "MIT",
            relationships: [],
            versions: ["2.0.0", "1.0.0"],
            contents: ["GameData/UpgradeableMod"])
        let installed = ModuleSummary(
            identifier: "InstalledMod",
            name: "Installed Mod",
            author: "Example",
            status: .installed,
            installedVersion: "1.0.0",
            latestVersion: "1.0.0",
            license: "MIT",
            relationships: [],
            versions: ["1.0.0"],
            contents: ["GameData/InstalledMod"])
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                upgradable,
                installed,
            ])

        XCTAssertTrue(model.canStageUpgradeAll)

        model.stageUpgradeAll()

        XCTAssertEqual(model.stagedAction(for: "UpgradeableMod"), .upgrade)
        XCTAssertNil(model.stagedAction(for: "InstalledMod"))
    }

    func testUpgradeAllCommandStateIsDisabledWithoutUpgradableModules() async {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertFalse(model.canStageUpgradeAll)
    }

    func testPreferredModuleActionsMatchWindowsCatalogStatusActions() {
        let available = module(identifier: "AvailableMod", name: "Available Mod", status: .available)
        let cached = module(identifier: "CachedMod", name: "Cached Mod", status: .cached, isCached: true)
        let installed = module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true)
        let upgradable = module(identifier: "UpgradeableMod", name: "Upgradeable Mod", status: .upgradable, isInstalled: true, hasUpdate: true)
        let replaceable = module(identifier: "ReplaceableMod", name: "Replaceable Mod", status: .installed, isInstalled: true, hasReplacement: true)
        let incompatible = module(identifier: "OldMod", name: "Old Mod", status: .incompatible, isCompatible: false)
        let model = AppModel(sidecar: FakeSidecar(), modules: [
            available,
            cached,
            installed,
            upgradable,
            replaceable,
            incompatible,
        ])

        XCTAssertEqual(model.preferredStagedAction(for: available), .install)
        XCTAssertEqual(model.preferredStagedAction(for: cached), .install)
        XCTAssertEqual(model.preferredStagedAction(for: installed), .remove)
        XCTAssertEqual(model.preferredStagedAction(for: upgradable), .upgrade)
        XCTAssertEqual(model.preferredStagedAction(for: replaceable), .replace)
        XCTAssertNil(model.preferredStagedAction(for: incompatible))
    }

    func testTogglePreferredModuleActionStagesAndUnstagesCatalogRowAction() {
        let available = module(identifier: "AvailableMod", name: "Available Mod", status: .available)
        let model = AppModel(sidecar: FakeSidecar(), modules: [available])

        model.togglePreferredStagedAction(for: available)
        XCTAssertEqual(model.stagedAction(for: "AvailableMod"), .install)
        XCTAssertTrue(model.hasPendingSelections)

        model.togglePreferredStagedAction(for: available)
        XCTAssertNil(model.stagedAction(for: "AvailableMod"))
        XCTAssertFalse(model.hasPendingSelections)
    }

    func testTogglePreferredModuleActionIgnoresIncompatibleModules() {
        let incompatible = module(identifier: "OldMod", name: "Old Mod", status: .incompatible, isCompatible: false)
        let model = AppModel(sidecar: FakeSidecar(), modules: [incompatible])

        model.togglePreferredStagedAction(for: incompatible)

        XCTAssertNil(model.stagedAction(for: "OldMod"))
        XCTAssertFalse(model.hasPendingSelections)
    }

    func testSelectedModuleIgnoresHiddenFilteredSelectionForCatalogActions() {
        let hidden = module(identifier: "HiddenMod", name: "Hidden Mod", status: .available)
        let visible = module(identifier: "VisibleMod", name: "Visible Mod", status: .available)
        let model = AppModel(sidecar: FakeSidecar(), modules: [hidden, visible])

        model.selectedModuleID = hidden.identifier
        model.searchText = "Visible"

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["VisibleMod"])
        XCTAssertNil(model.selectedModule)
    }

    func testInitialCatalogStateShowsAvailableModulesAndSelectsFirstVisibleModule() {
        let installed = module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true)
        let blocked = module(identifier: "BlockedMod", name: "Blocked Mod", status: .incompatible, isCompatible: false)
        let available = module(identifier: "AvailableMod", name: "Available Mod", status: .available)
        let model = AppModel(sidecar: FakeSidecar(), modules: [installed, blocked, available])

        XCTAssertEqual(model.filter, .available)
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["AvailableMod"])
        XCTAssertEqual(model.selectedModuleID, "AvailableMod")
    }

    func testCatalogFiltersCoverWindowsSmartFilterStates() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true),
                module(identifier: "UpgradeableMod", name: "Upgradeable Mod", status: .upgradable, isInstalled: true, hasUpdate: true),
                module(identifier: "CachedMod", name: "Cached Mod", status: .available, isCached: true),
                module(identifier: "OldMod", name: "Old Mod", status: .incompatible, isCompatible: false),
                module(identifier: "ReplaceableMod", name: "Replaceable Mod", status: .installed, isInstalled: true, hasReplacement: true),
                module(identifier: "NewMod", name: "New Mod", status: .available, isNew: true),
            ])

        XCTAssertEqual(identifiers(in: model, filter: .compatible), ["CachedMod", "InstalledMod", "NewMod", "ReplaceableMod", "UpgradeableMod"])
        XCTAssertEqual(identifiers(in: model, filter: .incompatible), ["OldMod"])
        XCTAssertEqual(identifiers(in: model, filter: .installed), ["InstalledMod", "ReplaceableMod", "UpgradeableMod"])
        XCTAssertEqual(identifiers(in: model, filter: .notInstalled), ["CachedMod", "NewMod", "OldMod"])
        XCTAssertEqual(identifiers(in: model, filter: .upgradable), ["UpgradeableMod"])
        XCTAssertEqual(identifiers(in: model, filter: .available), ["CachedMod", "NewMod"])
        XCTAssertEqual(identifiers(in: model, filter: .cached), ["CachedMod"])
        XCTAssertEqual(identifiers(in: model, filter: .uncached), ["InstalledMod", "NewMod", "OldMod", "ReplaceableMod", "UpgradeableMod"])
        XCTAssertEqual(identifiers(in: model, filter: .new), ["NewMod"])
        XCTAssertEqual(identifiers(in: model, filter: .replaceable), ["ReplaceableMod"])
    }

    func testChangingCatalogFilterSelectsFirstVisibleModuleWhenCurrentSelectionIsHidden() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "AvailableMod", name: "Available Mod", status: .available),
                module(identifier: "CachedMod", name: "Cached Mod", status: .cached, isCached: true),
                module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true),
            ])

        XCTAssertEqual(model.selectedModuleID, "AvailableMod")

        model.filter = .installed

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["InstalledMod"])
        XCTAssertEqual(model.selectedModuleID, "InstalledMod")

        model.filter = .cached

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["CachedMod"])
        XCTAssertEqual(model.selectedModuleID, "CachedMod")
    }

    func testCatalogSearchMatchesMultipleTokensAcrossMetadata() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(
                    identifier: "Scatterer",
                    name: "Scatterer",
                    author: "blackrack",
                    status: .available,
                    license: "GPL-3.0",
                    relationships: [ModuleRelationship(kind: "Recommends", value: "EnvironmentalVisualEnhancements")],
                    contents: ["GameData/scatterer"]),
                module(
                    identifier: "ModuleManager",
                    name: "Module Manager",
                    author: "sarbian",
                    status: .installed,
                    license: "CC-BY-SA",
                    contents: ["GameData/ModuleManager.4.2.3.dll"],
                    isInstalled: true),
            ])
        model.filter = .all

        model.searchText = "GPL scatterer"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])

        model.searchText = "depends ksp"
        XCTAssertEqual(model.filteredModules.map(\.identifier), [])

        model.searchText = "CC-BY-SA ModuleManager"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])
    }

    func testCatalogSortingUsesSelectedColumnAndDirection() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "Bravo", name: "Bravo", author: "Zulu"),
                module(identifier: "Alpha", name: "Alpha", author: "Yankee"),
                module(identifier: "Charlie", name: "Charlie", author: "Xray"),
            ])

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Alpha", "Bravo", "Charlie"])

        model.moduleSort = .author
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Charlie", "Alpha", "Bravo"])

        model.moduleSortAscending = false
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Bravo", "Alpha", "Charlie"])
    }

    func testCatalogSortingUsesChainedSecondaryColumnsForTies() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "First", name: "Shared", author: "Team", downloadCount: 10),
                module(identifier: "Second", name: "Shared", author: "Team", downloadCount: 20),
                module(identifier: "Third", name: "Shared", author: "Another", downloadCount: 5),
            ])

        model.moduleSort = .name
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["First", "Second", "Third"])

        model.addSecondaryModuleSort(.author)
        model.addSecondaryModuleSort(.downloadCount, ascending: false)

        XCTAssertEqual(model.secondaryModuleSortCriteria, [
            ModuleSortCriterion(sort: .author, ascending: true),
            ModuleSortCriterion(sort: .downloadCount, ascending: false),
        ])
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Third", "Second", "First"])

        model.clearSecondaryModuleSorts()

        XCTAssertTrue(model.secondaryModuleSortCriteria.isEmpty)
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["First", "Second", "Third"])
    }

    func testCatalogHeaderSortSelectsMappedColumnAndTogglesDirection() {
        let model = AppModel(sidecar: FakeSidecar())
        model.moduleSort = .name
        model.moduleSortAscending = false

        model.sortByHeader(.author)

        XCTAssertEqual(model.moduleSort, .author)
        XCTAssertTrue(model.moduleSortAscending)

        model.sortByHeader(.author)

        XCTAssertEqual(model.moduleSort, .author)
        XCTAssertFalse(model.moduleSortAscending)

        model.sortByHeader(.license)

        XCTAssertEqual(model.moduleSort, .author)
        XCTAssertFalse(model.moduleSortAscending)
    }

    func testCatalogSortingSupportsWindowsRichColumns() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(
                    identifier: "SmallOld",
                    name: "Small Old",
                    author: "A",
                    status: .available,
                    gameCompatibility: "1.8.1",
                    downloadSize: 128,
                    installSize: 512,
                    releaseDate: "2022-01-01T00:00:00.0000000Z",
                    installDate: "",
                    downloadCount: 100),
                module(
                    identifier: "LargeNew",
                    name: "Large New",
                    author: "B",
                    status: .installed,
                    gameCompatibility: "1.12.5",
                    downloadSize: 4096,
                    installSize: 8192,
                    releaseDate: "2024-01-01T00:00:00.0000000Z",
                    installDate: "2024-02-01T00:00:00.0000000Z",
                    downloadCount: 20_000),
                module(
                    identifier: "Unknown",
                    name: "Unknown",
                    author: "C",
                    status: .incompatible,
                    gameCompatibility: "Unknown",
                    downloadSize: 0,
                    installSize: 0,
                    releaseDate: "",
                    installDate: "",
                    downloadCount: nil),
            ])

        model.moduleSort = .downloadSize
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Unknown", "SmallOld", "LargeNew"])

        model.moduleSort = .installSize
        model.moduleSortAscending = false
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["LargeNew", "SmallOld", "Unknown"])

        model.moduleSort = .releaseDate
        model.moduleSortAscending = true
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Unknown", "SmallOld", "LargeNew"])

        model.moduleSort = .downloadCount
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Unknown", "SmallOld", "LargeNew"])

        model.moduleSort = .gameCompatibility
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["SmallOld", "LargeNew", "Unknown"])
    }

    func testCatalogTagFilterUsesModuleSummaryTags() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "VisualPack", name: "Visual Pack", tags: ["graphics", "visual"]),
                module(identifier: "UtilityMod", name: "Utility Mod", tags: ["plugin"]),
                module(identifier: "UntaggedMod", name: "Untagged Mod"),
            ])

        XCTAssertEqual(model.availableModuleTags, ["graphics", "plugin", "visual"])

        model.tagFilter = "visual"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["VisualPack"])

        model.searchText = "graphics"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["VisualPack"])
    }

    func testCatalogAdvancedSearchMatchesScopedWindowsStyleTokens() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: advancedSearchModules())
        model.filter = .all

        model.searchText = "@black lic:GPL tag:visual rec:Environmental"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])

        model.searchText = "dep:Kerbal tag:plugin"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])

        model.searchText = "conf:JNSQ sup:Outer"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Kopernicus"])
    }

    func testCatalogAdvancedSearchMatchesIdentifierScopedTokens() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: advancedSearchModules())
        model.filter = .all

        model.searchText = "identifier:ModuleManager"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])

        model.searchText = "id:Scatter"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])
    }

    func testCatalogAdvancedSearchMatchesNegatedAndStateTokens() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: advancedSearchModules())
        model.filter = .all

        model.searchText = "is:installed not:cached"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ReplaceableMod", "Scatterer"])

        model.searchText = "not:compatible"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Kopernicus"])

        model.searchText = "is:upgradeable -@sarbian"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])

        model.searchText = "is:replaceable"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ReplaceableMod"])

        model.searchText = "-tag:visual -conf:JNSQ"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager", "ReplaceableMod"])
    }

    func testKeyboardSelectionNavigationUsesFilteredCatalogOrder() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true),
                module(identifier: "Charlie", name: "Charlie", status: .available),
                module(identifier: "Alpha", name: "Alpha", status: .available),
                module(identifier: "BlockedMod", name: "Blocked Mod", status: .incompatible, isCompatible: false),
            ])

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Alpha", "Charlie"])
        XCTAssertEqual(model.selectedModuleID, "Alpha")

        model.selectNextFilteredModule()
        XCTAssertEqual(model.selectedModuleID, "Charlie")

        model.selectNextFilteredModule()
        XCTAssertEqual(model.selectedModuleID, "Charlie")

        model.selectPreviousFilteredModule()
        XCTAssertEqual(model.selectedModuleID, "Alpha")

        model.selectedModuleID = "InstalledMod"
        model.selectNextFilteredModule()
        XCTAssertEqual(model.selectedModuleID, "Alpha")
    }

    func testFilteredModulesAreStoredStateUnaffectedBySelectionChanges() {
        let model = AppModel(
            sidecar: FakeSidecar(),
            modules: [
                module(identifier: "Charlie", name: "Charlie", status: .available),
                module(identifier: "Alpha", name: "Alpha", status: .available),
                module(identifier: "InstalledMod", name: "Installed Mod", status: .installed, isInstalled: true),
            ])
        var publishedModuleIDs: [[String]] = []
        let cancellable = model.$filteredModules
            .dropFirst()
            .sink { modules in
                publishedModuleIDs.append(modules.map(\.identifier))
            }

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Alpha", "Charlie"])

        model.selectedModuleID = "Charlie"

        XCTAssertTrue(publishedModuleIDs.isEmpty)

        model.searchText = "Alpha"

        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Alpha"])
        XCTAssertEqual(publishedModuleIDs, [["Alpha"]])
        withExtendedLifetime(cancellable) {}
    }

    func testBuiltInSavedSearchOrderStartsWithAvailable() {
        XCTAssertEqual(ModuleFilter.builtInSavedSearches, [
            .available,
            .upgradable,
            .installed,
            .cached,
            .incompatible,
        ])
    }

    func testSavedCatalogSearchLoadsSavesAndAppliesState() {
        let store = InMemorySavedModuleSearchStore()
        let model = AppModel(
            sidecar: FakeSidecar(),
            savedSearchStore: store,
            modules: advancedSearchModules())

        model.searchText = "@black tag:visual"
        model.filter = .installed
        model.tagFilter = "visual"

        XCTAssertTrue(model.canSaveCurrentSearch)

        let saved = model.saveCurrentSearch(named: "  Visual installed  ")

        XCTAssertEqual(saved?.name, "Visual installed")
        XCTAssertEqual(model.savedSearches.map(\.name), ["Visual installed"])
        XCTAssertEqual(store.savedSearches, model.savedSearches)

        model.searchText = ""
        model.filter = .all
        model.tagFilter = nil
        model.applySavedSearch(saved!.id)

        XCTAssertEqual(model.searchText, "@black tag:visual")
        XCTAssertEqual(model.filter, .installed)
        XCTAssertEqual(model.tagFilter, "visual")
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])
    }

    func testSavedCatalogSearchReplacesByNameAndDeletesPersistently() {
        let initial = SavedModuleSearch(
            id: "existing",
            name: "Installed",
            searchText: "is:installed",
            filter: .installed,
            tagFilter: nil)
        let store = InMemorySavedModuleSearchStore(savedSearches: [initial])
        let model = AppModel(sidecar: FakeSidecar(), savedSearchStore: store)

        XCTAssertEqual(model.savedSearches, [initial])

        model.searchText = "tag:visual"
        model.filter = .compatible
        model.tagFilter = "visual"

        let replacement = model.saveCurrentSearch(named: " Installed ")

        XCTAssertEqual(replacement?.id, "existing")
        XCTAssertEqual(model.savedSearches.count, 1)
        XCTAssertEqual(model.savedSearches.first?.searchText, "tag:visual")
        XCTAssertEqual(model.savedSearches.first?.filter, .compatible)
        XCTAssertEqual(model.savedSearches.first?.tagFilter, "visual")
        XCTAssertEqual(store.savedSearches, model.savedSearches)

        model.deleteSavedSearch("existing")

        XCTAssertTrue(model.savedSearches.isEmpty)
        XCTAssertTrue(store.savedSearches.isEmpty)
    }

    func testDeletingAppliedSavedCatalogSearchClearsPersistedCatalogFilter() {
        let savedSearchStore = InMemorySavedModuleSearchStore()
        let catalogStateStore = InMemoryModuleCatalogStateStore()
        let model = AppModel(
            sidecar: FakeSidecar(),
            savedSearchStore: savedSearchStore,
            catalogStateStore: catalogStateStore,
            modules: advancedSearchModules())

        model.searchText = "identifier:Eternal"
        model.filter = .compatible
        model.tagFilter = "graphics"
        let saved = model.saveCurrentSearch(named: "Eternal")
        XCTAssertNotNil(saved)

        model.searchText = ""
        model.filter = .all
        model.tagFilter = nil
        model.applySavedSearch(saved!.id)
        model.deleteSavedSearch(saved!.id)

        XCTAssertTrue(model.savedSearches.isEmpty)
        XCTAssertEqual(model.searchText, "")
        XCTAssertEqual(model.filter, .available)
        XCTAssertNil(model.tagFilter)
        XCTAssertEqual(catalogStateStore.catalogState?.searchText, "")
        XCTAssertEqual(catalogStateStore.catalogState?.filter, .available)
        XCTAssertNil(catalogStateStore.catalogState?.tagFilter)
    }

    func testCatalogStatePersistsSortsButLaunchesIntoAvailableSearch() {
        let store = InMemoryModuleCatalogStateStore()
        let firstModel = AppModel(sidecar: FakeSidecar(), catalogStateStore: store)

        firstModel.searchText = "tag:visual"
        firstModel.filter = .compatible
        firstModel.tagFilter = "visual"
        firstModel.moduleSort = .downloadCount
        firstModel.moduleSortAscending = false
        firstModel.addSecondaryModuleSort(.author)

        XCTAssertEqual(
            store.catalogState,
            ModuleCatalogState(
                searchText: "tag:visual",
                filter: .compatible,
                tagFilter: "visual",
                moduleSort: .downloadCount,
                moduleSortAscending: false,
                secondaryModuleSortCriteria: [
                    ModuleSortCriterion(sort: .author, ascending: true),
                ]))

        let relaunchedModel = AppModel(sidecar: FakeSidecar(), catalogStateStore: store)

        XCTAssertEqual(relaunchedModel.searchText, "")
        XCTAssertEqual(relaunchedModel.filter, .available)
        XCTAssertNil(relaunchedModel.tagFilter)
        XCTAssertEqual(relaunchedModel.moduleSort, .downloadCount)
        XCTAssertFalse(relaunchedModel.moduleSortAscending)
        XCTAssertEqual(relaunchedModel.secondaryModuleSortCriteria, [
            ModuleSortCriterion(sort: .author, ascending: true),
        ])
    }

    func testModuleTableColumnsLoadTogglePersistAndReset() {
        let store = InMemoryModuleTableColumnStore(visibleColumns: [.name, .author])
        let model = AppModel(sidecar: FakeSidecar(), moduleColumnStore: store)

        XCTAssertEqual(model.visibleModuleColumns, [.name, .author])
        XCTAssertTrue(model.isModuleColumnVisible(.name))
        XCTAssertFalse(model.isModuleColumnVisible(.latestVersion))

        model.toggleModuleColumn(.author)

        XCTAssertEqual(model.visibleModuleColumns, [.name])
        XCTAssertEqual(store.visibleColumns, [.name])

        model.toggleModuleColumn(.name)

        XCTAssertEqual(model.visibleModuleColumns, [.name])
        XCTAssertEqual(store.visibleColumns, [.name])

        model.toggleModuleColumn(.license)

        XCTAssertEqual(model.visibleModuleColumns, [.name, .license])
        XCTAssertEqual(store.visibleColumns, [.name, .license])

        model.resetModuleColumns()

        XCTAssertEqual(model.visibleModuleColumns, ModuleTableColumn.defaultVisible)
        XCTAssertEqual(store.visibleColumns, ModuleTableColumn.defaultVisible)
    }

    func testModuleTableColumnsDefaultWhenStoreIsEmptyOrMalformed() {
        let store = InMemoryModuleTableColumnStore(visibleColumns: [.author, .author])
        let model = AppModel(sidecar: FakeSidecar(), moduleColumnStore: store)

        XCTAssertEqual(model.visibleModuleColumns, [.author])

        model.toggleModuleColumn(.author)

        XCTAssertEqual(model.visibleModuleColumns, [.author])
        XCTAssertEqual(store.visibleColumns, [.author])

        let emptyStore = InMemoryModuleTableColumnStore(visibleColumns: [])
        let emptyModel = AppModel(sidecar: FakeSidecar(), moduleColumnStore: emptyStore)

        XCTAssertEqual(emptyModel.visibleModuleColumns, ModuleTableColumn.defaultVisible)
    }

    func testCatalogLabelSearchUsesCoreLabelsAndToggleRefreshesAssignments() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(
                modulesByInstance: ["primary": advancedSearchModules()],
                labelsByInstance: [
                    "primary": [
                        ModuleLabelSummary(
                            name: "Favourites",
                            instanceName: nil,
                            colorHex: "#98FB98",
                            hide: false,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["ModuleManager"]),
                    ],
                ],
                toggleLabelsResult: SidecarLabelsResult(
                    instanceId: "primary",
                    labels: [
                        ModuleLabelSummary(
                            name: "Favourites",
                            instanceName: nil,
                            colorHex: "#98FB98",
                            hide: false,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["ModuleManager", "Scatterer"]),
                    ])))

        await model.refresh()

        XCTAssertEqual(model.moduleLabels.map(\.name), ["Favourites"])
        XCTAssertEqual(model.labels(for: "ModuleManager").map(\.name), ["Favourites"])

        model.filter = .all
        model.searchText = "label:Favourites"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])

        try await model.toggleLabel("Favourites", for: "Scatterer")

        XCTAssertEqual(model.labels(for: "Scatterer").map(\.name), ["Favourites"])
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager", "Scatterer"])
    }

    func testCatalogAdvancedSearchMatchesDescriptionAndLocalizationTokens() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(modulesByInstance: ["primary": advancedSearchModules()]))

        await model.refresh()
        model.filter = .all

        model.searchText = "desc:VisualEnhancements"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Scatterer"])

        model.searchText = "lang:ru"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])

        model.searchText = "-lang:en-us"
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["Kopernicus", "ReplaceableMod"])
    }

    func testCatalogSearchHelpDocumentsAllSupportedAdvancedTokenFamilies() {
        let examples = ModuleSearchHelpSection.all.flatMap(\.examples).map(\.query)

        XCTAssertTrue(examples.contains("scatterer @blackrack"))
        XCTAssertTrue(examples.contains("identifier:ModuleManager"))
        XCTAssertTrue(examples.contains("desc:VisualEnhancements lang:ru"))
        XCTAssertTrue(examples.contains("lic:GPL tag:visual label:Favourites"))
        XCTAssertTrue(examples.contains("dep:Kerbal rec:Environmental sug:Toolbar"))
        XCTAssertTrue(examples.contains("conf:JNSQ sup:OuterPlanets"))
        XCTAssertTrue(examples.contains("is:installed not:cached is:replaceable"))
        XCTAssertTrue(examples.contains("-tag:visual -@sarbian"))
        XCTAssertEqual(ModuleSearchHelpSection.all.first?.title, "Text")
        XCTAssertEqual(ModuleSearchHelpSection.all.last?.title, "Saved Searches")
    }

    func testSetAutoInstalledRefreshesModulesAndDetails() async throws {
        let initial = module(
            identifier: "ModuleManager",
            name: "Module Manager",
            status: .installed,
            isInstalled: true,
            isAutoInstalled: false)
        let updated = module(
            identifier: "ModuleManager",
            name: "Module Manager",
            status: .installed,
            isInstalled: true,
            isAutoInstalled: true)
        let model = AppModel(
            sidecar: FakeSidecar(
                modulesByInstance: ["primary": [initial]],
                autoInstalledResult: SidecarModulesResult(instanceId: "primary", modules: [updated])),
            modules: [initial])
        model.selectedInstanceID = "primary"
        model.selectedModuleID = "ModuleManager"

        try await model.setAutoInstalled(true, for: "ModuleManager")

        XCTAssertEqual(model.modules.first?.identifier, "ModuleManager")
        XCTAssertEqual(model.modules.first?.isAutoInstalled, true)
        XCTAssertEqual(model.selectedModuleID, "ModuleManager")
        XCTAssertEqual(model.selectedModuleDetails?.module.identifier, "ModuleManager")
        XCTAssertEqual(model.selectedModuleDetails?.module.isAutoInstalled, true)
    }

    func testLabelManagementCreatesUpdatesAndDeletesLabels() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(
                labelsByInstance: ["primary": []],
                upsertLabelsResult: SidecarLabelsResult(
                    instanceId: "primary",
                    labels: [
                        ModuleLabelSummary(
                            name: "Watch",
                            instanceName: "primary",
                            colorHex: "#336699",
                            hide: true,
                            notifyOnChange: true,
                            removeOnChange: false,
                            alertOnInstall: true,
                            removeOnInstall: false,
                            holdVersion: true,
                            ignoreMissingFiles: true,
                            identifiers: ["ModuleManager"]),
                    ]),
                deleteLabelsResult: SidecarLabelsResult(instanceId: "primary", labels: [])))

        await model.refresh()

        try await model.saveLabel(
            originalName: nil,
            originalInstanceName: nil,
            label: ModuleLabelEdit(
                name: "Watch",
                instanceName: "primary",
                colorHex: "#336699",
                hide: true,
                notifyOnChange: true,
                removeOnChange: false,
                alertOnInstall: true,
                removeOnInstall: false,
                holdVersion: true,
                ignoreMissingFiles: true))

        XCTAssertEqual(model.moduleLabels.map(\.name), ["Watch"])
        XCTAssertEqual(model.labels(for: "ModuleManager").map(\.name), ["Watch"])

        try await model.deleteLabel(name: "Watch", instanceName: "primary")

        XCTAssertTrue(model.moduleLabels.isEmpty)
    }

    func testLabelManagerKeepsCrossInstanceLabelsSeparateFromCatalogLabels() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(
                labelsByInstance: [
                    "primary": [
                        ModuleLabelSummary(
                            name: "Global",
                            instanceName: nil,
                            colorHex: "#98FB98",
                            hide: false,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["ModuleManager"]),
                    ],
                ],
                manageableLabelsByInstance: [
                    "primary": [
                        ModuleLabelSummary(
                            name: "Global",
                            instanceName: nil,
                            colorHex: "#98FB98",
                            hide: false,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["ModuleManager"]),
                        ModuleLabelSummary(
                            name: "Secondary Only",
                            instanceName: "secondary",
                            colorHex: "#DB7093",
                            hide: true,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["Scatterer"]),
                    ],
                ]))

        await model.refresh()

        XCTAssertEqual(model.moduleLabels.map(\.name), ["Global"])
        XCTAssertEqual(model.availableModuleLabels.map(\.name), ["Global"])
        XCTAssertEqual(model.manageableModuleLabels.map(\.id), ["global:Global", "secondary:Secondary Only"])
    }

    func testApplyLabelFilterMatchesLabelNamesWithSpaces() async throws {
        let model = AppModel(
            sidecar: FakeSidecar(
                modulesByInstance: ["primary": advancedSearchModules()],
                labelsByInstance: [
                    "primary": [
                        ModuleLabelSummary(
                            name: "Needs Review",
                            instanceName: nil,
                            colorHex: "#5AC8FA",
                            hide: false,
                            holdVersion: false,
                            ignoreMissingFiles: false,
                            identifiers: ["ModuleManager"]),
                    ],
                ]))

        await model.refresh()
        model.applyLabelFilter(model.moduleLabels[0])

        XCTAssertEqual(model.searchText, "label:NeedsReview")
        XCTAssertEqual(model.filteredModules.map(\.identifier), ["ModuleManager"])
    }

    func testRefreshRepositoriesMarksNewAndNewlyCompatibleModules() async throws {
        let previous = [
            module(identifier: "ExistingMod", name: "Existing Mod", status: .available),
            module(identifier: "RecompatibleMod", name: "Recompatible Mod", status: .incompatible, isCompatible: false),
        ]
        let refreshed = [
            module(identifier: "ExistingMod", name: "Existing Mod", status: .available),
            module(identifier: "RecompatibleMod", name: "Recompatible Mod", status: .available),
            module(identifier: "BrandNewMod", name: "Brand New Mod", status: .incompatible, isCompatible: false),
        ]
        let model = AppModel(
            sidecar: FakeSidecar(modulesByInstance: ["primary": refreshed]),
            instances: primaryInstances(),
            modules: previous)

        try await model.refreshRepositories(force: true)

        XCTAssertEqual(model.modules.filter(\.isNew).map(\.identifier).sorted(), ["BrandNewMod", "RecompatibleMod"])
    }

    func testLoadAvailableRepositoriesUpdatesCanonicalList() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.loadAvailableRepositories()

        XCTAssertEqual(model.availableRepositories.map(\.name), ["stable"])
        XCTAssertEqual(model.availableRepositories.first?.comment, "canonical stable")
    }

    func testLoadAvailableRepositoriesUsesSelectedInstance() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            availableRepositoriesByInstance: [
                "primary": [
                    RepositorySummary(
                        name: "stable",
                        url: "https://example.invalid/stable.tar.gz",
                        priority: 0,
                        isMirror: false,
                        comment: "canonical stable"),
                ],
                "secondary": [
                    RepositorySummary(
                        name: "legacy",
                        url: "https://example.invalid/legacy.tar.gz",
                        priority: 1,
                        isMirror: true,
                        comment: "legacy mirror"),
                ],
            ]))

        await model.refresh()
        try await model.loadAvailableRepositories()

        XCTAssertEqual(model.availableRepositories.map(\.name), ["stable"])
        XCTAssertEqual(model.availableRepositories.first?.comment, "canonical stable")
        XCTAssertFalse(model.availableRepositories.first?.isMirror ?? true)

        await model.selectInstance("secondary")
        try await model.loadAvailableRepositories()

        XCTAssertEqual(model.availableRepositories.map(\.name), ["legacy"])
        XCTAssertEqual(model.availableRepositories.first?.url, "https://example.invalid/legacy.tar.gz")
        XCTAssertEqual(model.availableRepositories.first?.priority, 1)
        XCTAssertTrue(model.availableRepositories.first?.isMirror ?? false)
        XCTAssertEqual(model.availableRepositories.first?.comment, "legacy mirror")
    }

    func testResolveChangesLoadsPreviewForStagedInstall() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertTrue(model.hasPendingSelections)
        XCTAssertEqual(model.stagedAction(for: "SidecarOnlyMod"), .install)
        XCTAssertEqual(model.pendingChangeSet?.instanceId, "primary")
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.identifier), ["SidecarOnlyMod", "DependencyMod"])
        XCTAssertEqual(model.pendingChangeSet?.changes.first?.action, "install")
        XCTAssertEqual(model.pendingChangeSet?.changes.last?.reasons, ["Dependency of SidecarOnlyMod"])
    }

    func testCatalogRefreshCompletingAfterStagingPreservesPendingRemove() async throws {
        let gate = ModuleListGate()
        let installed = module(
            identifier: "InstalledMod",
            name: "Installed Mod",
            status: .installed,
            installedVersion: "1.0.0",
            isInstalled: true)
        let snapshotStore = InMemoryModuleCatalogSnapshotStore(snapshots: [
            "primary": ModuleCatalogSnapshot(
                instanceId: "primary",
                modules: [installed],
                moduleLabels: [],
                manageableModuleLabels: [],
                repositories: [],
                launchCommands: [],
                defaultLaunchCommands: [],
                incompatibleLaunchModules: [],
                savedAt: Date())
        ])
        let sidecar = FakeSidecar(
            modulesByInstance: ["primary": [installed]],
            listModulesGate: gate,
            expectedResolveInstall: [],
            expectedResolveRemove: ["InstalledMod"])
        let model = AppModel(sidecar: sidecar, catalogSnapshotStore: snapshotStore)

        let refreshTask = Task {
            await model.refresh()
        }
        await gate.waitUntilEntered()
        model.stageRemove("InstalledMod")

        await gate.release()
        await refreshTask.value
        try await model.resolveChanges()

        XCTAssertEqual(model.stagedAction(for: "InstalledMod"), .remove)
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.identifier), ["InstalledMod"])
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.action), ["remove"])
    }

    func testStaleInstanceStateLoadDoesNotOverwriteNewerSelection() async throws {
        let primaryGate = ModuleListGate()
        let primaryModule = module(identifier: "PrimaryOnly", name: "Primary Only")
        let secondaryModule = module(identifier: "SecondaryOnly", name: "Secondary Only")
        var sidecar = FakeSidecar(
            modulesByInstance: [
                "primary": [primaryModule],
                "secondary": [secondaryModule],
            ])
        sidecar.moduleListGatesByInstance = ["primary": primaryGate]
        let model = AppModel(sidecar: sidecar)

        let primarySelectionTask = Task {
            await model.selectInstance("primary")
        }
        await primaryGate.waitUntilEntered()

        await model.selectInstance("secondary")

        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnly"])
        XCTAssertEqual(model.selectedModuleID, "SecondaryOnly")

        await primaryGate.release()
        await primarySelectionTask.value

        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnly"])
        XCTAssertEqual(model.selectedModuleID, "SecondaryOnly")
    }

    func testStaleRunningModuleListOperationIsCancelled() async throws {
        let startRecorder = ModuleListOperationRecorder()
        let cancelRecorder = ModuleListOperationRecorder()
        let secondaryModule = module(identifier: "SecondaryOnly", name: "Secondary Only")
        var sidecar = FakeSidecar(
            modulesByInstance: [
                "primary": [module(identifier: "PrimaryOnly", name: "Primary Only")],
                "secondary": [secondaryModule],
            ])
        sidecar.moduleListStartStatusByInstance = ["primary": "running"]
        sidecar.moduleListStartRecorder = startRecorder
        sidecar.moduleListCancelRecorder = cancelRecorder
        let model = AppModel(sidecar: sidecar)

        let primarySelectionTask = Task {
            await model.selectInstance("primary")
        }
        await startRecorder.waitUntilRecorded()

        await model.selectInstance("secondary")
        await primarySelectionTask.value

        let cancelledOperationIDs = await cancelRecorder.recordedOperationIDs()
        XCTAssertEqual(cancelledOperationIDs, ["module-list-op-primary"])
        XCTAssertEqual(model.selectedInstanceID, "secondary")
        XCTAssertEqual(model.modules.map(\.identifier), ["SecondaryOnly"])
    }

    func testResolveChangesUsesForegroundPreviewSidecarWhenProvided() async throws {
        let backgroundSidecar = FakeSidecar(
            changeSetError: .rpcError(code: -32000, message: "Background sidecar is busy"))
        let previewSidecar = FakeSidecar()
        let model = AppModel(
            sidecar: backgroundSidecar,
            previewSidecar: previewSidecar)

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.identifier), ["SidecarOnlyMod", "DependencyMod"])
        XCTAssertNil(model.changeSetError)
    }

    func testStaleChangePreviewDoesNotOverwriteNewerStagedActions() async throws {
        let gate = ChangeSetGate()
        var previewSidecar = FakeSidecar()
        previewSidecar.changeSetGate = gate
        let model = AppModel(
            sidecar: FakeSidecar(),
            previewSidecar: previewSidecar)

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        let previewTask = Task {
            try await model.resolveChanges()
        }
        await gate.waitUntilEntered()

        model.clearStagedChange("SidecarOnlyMod")
        model.stageInstall("OtherMod")

        await gate.release()
        try await previewTask.value

        XCTAssertNil(model.pendingChangeSet)
        XCTAssertEqual(model.stagedAction(for: "OtherMod"), .install)
    }

    func testResolveChangesLoadsPreviewForStagedReplace() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageReplace("ReplaceableMod")
        try await model.resolveChanges()

        XCTAssertTrue(model.hasPendingSelections)
        XCTAssertEqual(model.stagedAction(for: "ReplaceableMod"), .replace)
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.identifier), ["ReplaceableMod", "ReplacementMod"])
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.action), ["replace", "install"])
        XCTAssertEqual(model.pendingChangeSet?.changes.first?.fromVersion, "1.0.0")
        XCTAssertEqual(model.pendingChangeSet?.changes.first?.toVersion, "2.0.0")
    }

    func testApplyReadinessRequiresResolvedConflictFreeChangeSet() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()

        XCTAssertFalse(model.canApplyPendingChangeSet)

        model.stageInstall("SidecarOnlyMod")
        XCTAssertFalse(model.canApplyPendingChangeSet)

        try await model.resolveChanges()
        XCTAssertTrue(model.canApplyPendingChangeSet)

        model.clearAllStagedChanges()
        XCTAssertFalse(model.canApplyPendingChangeSet)
    }

    func testApplyReadinessRejectsConflictedChangeSet() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasConflict: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertFalse(model.canApplyPendingChangeSet)
    }

    func testConflictNoticeSummarizesBlockingChangeSetConflicts() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasConflict: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        let notice = try XCTUnwrap(model.pendingChangeSetConflictNotice)
        XCTAssertEqual(notice.title, "Resolve conflicts before applying")
        XCTAssertTrue(notice.message.contains("Remove or change the selected mods"))
        XCTAssertEqual(notice.conflicts.first?.identifier, "ExistingConflict")
        XCTAssertEqual(notice.conflicts.first?.name, "Existing Conflict")
        XCTAssertEqual(notice.descriptions, ["ExistingConflict conflicts with SidecarOnlyMod"])
        XCTAssertTrue(notice.blocksApply)
    }

    func testConflictNoticeIsNilForConflictFreePreview() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertNil(model.pendingChangeSetConflictNotice)
        XCTAssertTrue(model.canApplyPendingChangeSet)
    }

    func testProviderChoicesBlockApplyUntilProviderIsStaged() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasProviderChoice: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertFalse(model.canApplyPendingChangeSet)
        XCTAssertEqual(model.pendingChangeSet?.providerChoices.first?.requested, "VirtualDependency")
    }

    func testDependencyChoiceNoticeSummarizesBlockingProviderChoices() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasProviderChoice: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        let notice = try XCTUnwrap(model.pendingDependencyChoiceNotice)
        XCTAssertEqual(notice.title, "Choose dependency providers")
        XCTAssertTrue(notice.message.contains("can satisfy the same dependency"))
        XCTAssertTrue(notice.blocksApply)
        XCTAssertEqual(notice.choices.first?.requested, "VirtualDependency")
        XCTAssertEqual(notice.choices.first?.requesterName, "Sidecar Only Mod")
        XCTAssertEqual(notice.choices.first?.options.map(\.identifier), ["ProviderA", "ProviderB"])
    }

    func testDependencyChoiceNoticeIsNilWhenNoProviderChoiceIsPending() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertNil(model.pendingDependencyChoiceNotice)
        XCTAssertTrue(model.canApplyPendingChangeSet)
    }

    func testProviderChoicePersistsAsSelectionWithoutStagingProviderInstall() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasProviderChoice: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        let choice = try XCTUnwrap(model.pendingChangeSet?.providerChoices.first)
        let option = try XCTUnwrap(choice.options.first)
        model.stageProviderOption(choice: choice, option: option)

        XCTAssertNil(model.stagedAction(for: "ProviderA"))
        XCTAssertEqual(model.providerSelections, [
            ProviderSelection(
                requested: "VirtualDependency",
                requesterIdentifier: "SidecarOnlyMod",
                selectedIdentifier: "ProviderA"),
        ])

        try await model.resolveChanges()

        XCTAssertTrue(model.pendingChangeSet?.providerChoices.isEmpty ?? false)
        XCTAssertTrue(model.canApplyPendingChangeSet)
    }

    func testApplyStagedChangesForwardsProviderSelectionsToSidecar() async throws {
        let selection = ProviderSelection(
            requested: "VirtualDependency",
            requesterIdentifier: "SidecarOnlyMod",
            selectedIdentifier: "ProviderA")
        let model = AppModel(sidecar: FakeSidecar(
            expectedApplyProviderSelections: [selection],
            changeSetHasProviderChoice: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        let choice = try XCTUnwrap(model.pendingChangeSet?.providerChoices.first)
        let option = try XCTUnwrap(choice.options.first)
        model.stageProviderOption(choice: choice, option: option)
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-1")
        XCTAssertFalse(model.hasPendingSelections)
    }

    func testRecommendationChoicesCanBeStagedWithoutBlockingApply() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetHasRecommendationChoice: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()

        XCTAssertTrue(model.canApplyPendingChangeSet)
        XCTAssertEqual(model.pendingChangeSet?.recommendationChoices.first?.identifier, "RecommendedMod")

        model.stageRecommendationChoice("RecommendedMod")

        XCTAssertEqual(model.stagedAction(for: "RecommendedMod"), .install)
        XCTAssertNil(model.pendingChangeSet)
    }

    func testResolveChangesStoresRegistryLockDetails() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetThrowsRegistryLock: true))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")

        do {
            try await model.resolveChanges()
            XCTFail("Expected registry lock error")
        } catch {
            XCTAssertEqual(
                error as? SidecarClientError,
                .registryLocked(message: "Registry is locked", lockfilePath: "/Games/KSP/CKAN/registry.locked"))
        }

        XCTAssertNil(model.pendingChangeSet)
        XCTAssertEqual(model.changeSetError, "Registry is locked")
        XCTAssertEqual(model.changeSetErrorDetails?.kind, "registryLock")
        XCTAssertEqual(model.changeSetErrorDetails?.lockfilePath, "/Games/KSP/CKAN/registry.locked")
    }

    func testResolveChangesStoresStructuredOperationErrorDetails() async throws {
        let model = AppModel(sidecar: FakeSidecar(changeSetError: .operationError(
            message: "Downloads failed",
            details: .downloadFailures([
                DownloadFailureSummary(
                    identifier: "ModuleManager",
                    name: "Module Manager",
                    version: "4.2.3",
                    message: "Host returned 500",
                    urls: ["https://example.invalid/ModuleManager.zip"]),
            ]))))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")

        do {
            try await model.resolveChanges()
            XCTFail("Expected structured operation error")
        } catch {
            guard let typedError = error as? SidecarClientError else {
                XCTFail("Expected SidecarClientError")
                return
            }
            guard case let .operationError(message, details) = typedError else {
                XCTFail("Expected operationError with details")
                return
            }
            XCTAssertEqual(message, "Downloads failed")
            XCTAssertEqual(details.kind, "downloadFailures")
            XCTAssertEqual(details.downloadFailures?.count, 1)
            XCTAssertEqual(details.downloadFailures?.first?.identifier, "ModuleManager")
        }

        XCTAssertNil(model.pendingChangeSet)
        XCTAssertEqual(model.changeSetError, "Downloads failed")
        XCTAssertEqual(model.changeSetErrorDetails?.kind, "downloadFailures")
        XCTAssertEqual(model.changeSetErrorDetails?.suggestedAction, "skipOrAbort")
        XCTAssertEqual(model.changeSetErrorDetails?.downloadFailures?.first?.identifier, "ModuleManager")
        XCTAssertEqual(model.changeSetErrorDetails?.downloadFailures?.first?.urls, ["https://example.invalid/ModuleManager.zip"])
    }

    func testApplyStagedChangesStoresCompletedOperationAndClearsSelection() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertFalse(model.hasPendingSelections)
        XCTAssertNil(model.pendingChangeSet)
        XCTAssertEqual(model.lastOperationResult?.operationId, "op-1")
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertEqual(model.lastOperationResult?.events.last?.message, "Done")
        XCTAssertNil(model.operationError)
    }

    func testApplyStagedChangesMarksSkipDownloadFailuresRetryAsSupported() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertTrue(model.lastOperationSupportsSkipDownloadFailures)
    }

    func testApplyStagedChangesStoresRegistryLockDetails() async throws {
        let model = AppModel(sidecar: FakeSidecar(applyStatus: "failed", applyErrorDetails: .registryLock("/Games/KSP/CKAN/registry.locked")))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertTrue(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.status, "failed")
        XCTAssertEqual(model.operationError, "Registry is locked")
        XCTAssertEqual(model.operationErrorDetails?.kind, "registryLock")
        XCTAssertEqual(model.operationErrorDetails?.lockfilePath, "/Games/KSP/CKAN/registry.locked")
    }

    func testApplyStagedChangesStoresDownloadFailureDetails() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            applyStatus: "failed",
            applyErrorDetails: .downloadFailures([
                DownloadFailureSummary(
                    identifier: "ModuleManager",
                    name: "Module Manager",
                    version: "4.2.3",
                    message: "Host returned 500",
                    urls: ["https://example.invalid/ModuleManager.zip"]),
            ])))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertTrue(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.status, "failed")
        XCTAssertEqual(model.operationError, "Downloads failed")
        XCTAssertEqual(model.operationErrorDetails?.kind, "downloadFailures")
        XCTAssertEqual(model.operationErrorDetails?.downloadFailures?.first?.identifier, "ModuleManager")
        XCTAssertEqual(model.operationErrorDetails?.downloadFailures?.first?.urls, ["https://example.invalid/ModuleManager.zip"])
    }

    func testApplyStagedChangesForwardsSkipDownloadFailuresToSidecar() async throws {
        var sidecar = FakeSidecar()
        sidecar.expectedApplySkipDownloadFailures = true
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges(skipDownloadFailures: true)

        XCTAssertFalse(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertNil(model.operationError)
    }

    func testInstallCkanFilesMarksSkipDownloadFailuresRetryAsSupported() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.installCkanFiles(["/Downloads/ModuleManager.ckan"])

        XCTAssertTrue(model.lastOperationSupportsSkipDownloadFailures)
    }

    func testImportDownloadsMarksSkipDownloadFailuresRetryAsSupportedWhenInstalling() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.importDownloads(["/Downloads/DogeCoinPlugin.zip"])

        XCTAssertTrue(model.lastOperationSupportsSkipDownloadFailures)
    }

    func testImportDownloadsMarksSkipDownloadFailuresRetryAsUnsupportedWhenPreviewingBeforeInstall() async throws {
        var sidecar = FakeSidecar()
        sidecar.expectedImportInstallImportedModules = false
        sidecar.expectedImportPreviewBeforeInstall = true
        sidecar.expectedResolveInstall = ["DogeCoinPlugin"]
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.importDownloads(
            ["/Downloads/DogeCoinPlugin.zip"],
            options: ImportDownloadsOptions(
                installImportedModules: true,
                deleteImportedFiles: false,
                previewBeforeInstall: true))

        XCTAssertFalse(model.lastOperationSupportsSkipDownloadFailures)
    }

    func testInstallCkanFilesForwardsSkipDownloadFailuresToSidecar() async throws {
        var sidecar = FakeSidecar()
        sidecar.expectedFileInstallSkipDownloadFailures = true
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.installCkanFiles(
            ["/Downloads/ModuleManager.ckan"],
            skipDownloadFailures: true)

        XCTAssertEqual(model.lastOperationResult?.status, "completed")
    }

    func testImportDownloadsForwardsSkipDownloadFailuresToSidecar() async throws {
        var sidecar = FakeSidecar()
        sidecar.expectedImportSkipDownloadFailures = true
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        try await model.importDownloads(
            ["/Downloads/DogeCoinPlugin.zip"],
            options: ImportDownloadsOptions(
                installImportedModules: true,
                deleteImportedFiles: false),
            skipDownloadFailures: true)

        XCTAssertEqual(model.lastOperationResult?.status, "completed")
    }

    func testApplyStagedReplacementUsesReplaceSelection() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        model.stageReplace("ReplaceableMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertFalse(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.changes.first?.action, "replace")
        XCTAssertNil(model.operationError)
    }

    func testInstallCkanFilesStoresCompletedOperationAndReloadsInstanceState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.installCkanFiles(["/Downloads/ModuleManager.ckan"])

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-file")
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertEqual(model.lastOperationResult?.changes.map(\.identifier), ["ModuleManager"])
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.operationError)
    }

    func testInstallCkanFilesStartsAsyncOperationForPolling() async throws {
        let model = AppModel(sidecar: FakeSidecar(fileInstallStatus: "running"))

        await model.refresh()
        try await model.installCkanFiles(["/Downloads/ModuleManager.ckan"])

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-file")
        XCTAssertEqual(model.lastOperationResult?.status, "running")
        XCTAssertEqual(model.lastOperationResult?.events.first?.message, "Operation queued")
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.operationError)
    }

    func testImportDownloadsStoresCompletedOperationAndReloadsInstanceState() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        try await model.importDownloads(
            ["/Downloads/DogeCoinPlugin.zip"],
            installImportedModules: true,
            deleteImportedFiles: false)

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-import")
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertEqual(model.lastOperationResult?.changes.map(\.identifier), ["DogeCoinPlugin"])
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.operationError)
    }

    func testImportDownloadsStartsAsyncOperationForPolling() async throws {
        let model = AppModel(sidecar: FakeSidecar(importStatus: "running"))

        await model.refresh()
        try await model.importDownloads(
            ["/Downloads/DogeCoinPlugin.zip"],
            installImportedModules: true,
            deleteImportedFiles: false)

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-import")
        XCTAssertEqual(model.lastOperationResult?.status, "running")
        XCTAssertEqual(model.lastOperationResult?.events.first?.message, "Operation queued")
        XCTAssertEqual(model.modules.map(\.identifier), ["SidecarOnlyMod"])
        XCTAssertNil(model.operationError)
    }

    func testImportDownloadsCanSkipInstallAndDeleteOriginalDownloads() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            expectedImportInstallImportedModules: false,
            expectedImportDeleteImportedFiles: true))

        await model.refresh()
        try await model.importDownloads(
            ["/Downloads/DogeCoinPlugin.zip"],
            installImportedModules: false,
            deleteImportedFiles: true)

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-import")
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertNil(model.operationError)
    }

    func testImportDownloadsOptionsOverloadUsesTypedOptions() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            expectedImportInstallImportedModules: false,
            expectedImportDeleteImportedFiles: true))
        let options = ImportDownloadsOptions(
            installImportedModules: false,
            deleteImportedFiles: true)

        await model.refresh()
        try await model.importDownloads(["/Downloads/DogeCoinPlugin.zip"], options: options)

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-import")
        XCTAssertEqual(ImportDownloadsOptions().installImportedModules, true)
        XCTAssertEqual(ImportDownloadsOptions().deleteImportedFiles, false)
        XCTAssertEqual(ImportDownloadsOptions().previewBeforeInstall, false)
    }

    func testImportDownloadsCanPreviewImportedModulesBeforeInstall() async throws {
        let model = AppModel(sidecar: FakeSidecar(
            expectedImportInstallImportedModules: false,
            expectedImportDeleteImportedFiles: false,
            expectedImportPreviewBeforeInstall: true,
            expectedResolveInstall: ["DogeCoinPlugin"]))
        let options = ImportDownloadsOptions(
            installImportedModules: true,
            deleteImportedFiles: false,
            previewBeforeInstall: true)

        await model.refresh()
        try await model.importDownloads(["/Downloads/DogeCoinPlugin.zip"], options: options)

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-import")
        XCTAssertEqual(model.stagedActions, ["DogeCoinPlugin": .install])
        XCTAssertEqual(model.pendingChangeSet?.changes.map(\.identifier), ["DogeCoinPlugin", "DependencyMod"])
        XCTAssertNil(model.operationError)
        XCTAssertNil(model.changeSetError)
    }

    func testExportModListReturnsExportedContents() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        let result = try await model.exportModList(format: .markdown)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.format, .markdown)
        XCTAssertEqual(result.suggestedFileName, "Primary KSP-mods.md")
        XCTAssertEqual(result.contentType, "text/markdown")
        XCTAssertTrue(result.contents.contains("Module Manager"))
    }

    func testExportModpackReturnsCkanContents() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        await model.refresh()
        let result = try await model.exportModpack(draft: ModpackExportDraft(
            identifier: "MyModpack",
            name: "My Modpack",
            abstract: "Essential mods",
            author: "Jeb Kerman",
            version: "v1",
            license: "MIT",
            gameVersionMin: "1.12",
            gameVersionMax: "1.12.5",
            includeVersions: false,
            includeOptionalRelationships: false,
            relationshipAssignments: [
                ModpackRelationshipAssignment(identifier: "ModuleManager", kind: "depends"),
                ModpackRelationshipAssignment(identifier: "Scatterer", kind: "recommends"),
                ModpackRelationshipAssignment(identifier: "UnusedVisualPack", kind: "ignore"),
            ]))

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.identifier, "MyModpack")
        XCTAssertEqual(result.suggestedFileName, "MyModpack.ckan")
        XCTAssertEqual(result.contentType, "application/json")
        XCTAssertTrue(result.contents.contains("ModuleManager"))
    }

    func testRefreshLastOperationStatusUpdatesRunningOperationAndClearsSelectionOnCompletion() async throws {
        let sidecar = FakeSidecar(applyStatus: "running")
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()

        XCTAssertTrue(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.status, "running")
        XCTAssertEqual(model.lastOperationResult?.events.last?.message, "Operation queued")

        try await model.refreshLastOperationStatus()

        XCTAssertFalse(model.hasPendingSelections)
        XCTAssertEqual(model.lastOperationResult?.status, "completed")
        XCTAssertEqual(model.lastOperationResult?.events.last?.message, "Done after status refresh")
        XCTAssertNil(model.operationError)
    }

    func testRefreshLastOperationStatusPreservesPerFileProgressEvents() async throws {
        let sidecar = FakeSidecar(
            applyStatus: "running",
            operationStatusEvents: [
                OperationEvent(
                    kind: "downloadProgress",
                    message: "Module Manager",
                    percent: 45,
                    identifier: "ModuleManager",
                    remainingBytes: 5632,
                    totalBytes: 10240),
                OperationEvent(
                    kind: "installProgress",
                    message: "Module Manager",
                    percent: 100,
                    identifier: "ModuleManager",
                    remainingBytes: 0,
                    totalBytes: 10240),
            ])
        let model = AppModel(sidecar: sidecar)

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()
        try await model.refreshLastOperationStatus()
        let events = try XCTUnwrap(model.lastOperationResult?.events)

        XCTAssertEqual(events.map(\.kind), ["downloadProgress", "installProgress"])
        XCTAssertEqual(events.map(\.identifier), ["ModuleManager", "ModuleManager"])
        XCTAssertEqual(events.first?.byteProgressDisplay, "4.6 KB of 10.2 KB")
    }

    func testRefreshLastOperationStatusWithoutOperationIsNoOp() async throws {
        let model = AppModel(sidecar: FakeSidecar())

        try await model.refreshLastOperationStatus()

        XCTAssertNil(model.lastOperationResult)
        XCTAssertNil(model.operationError)
    }

    func testCancelLastOperationRequestsSidecarAndStoresCancellingStatus() async throws {
        let model = AppModel(sidecar: FakeSidecar(applyStatus: "running"))

        await model.refresh()
        model.stageInstall("SidecarOnlyMod")
        try await model.resolveChanges()
        try await model.applyStagedChanges()
        try await model.cancelLastOperation()

        XCTAssertEqual(model.lastOperationResult?.operationId, "op-1")
        XCTAssertEqual(model.lastOperationResult?.status, "cancelling")
        XCTAssertEqual(model.lastOperationResult?.events.last?.message, "Cancellation requested")
        XCTAssertNil(model.operationError)
    }

    private func identifiers(in model: AppModel, filter: ModuleFilter) -> [String] {
        model.filter = filter
        return model.filteredModules.map(\.identifier)
    }

    private func advancedSearchModules() -> [ModuleSummary] {
        [
            module(
                identifier: "ModuleManager",
                name: "Module Manager",
                author: "sarbian",
                status: .installed,
                license: "CC-BY-SA",
                relationships: [ModuleRelationship(kind: "Depends", value: "Kerbal Space Program")],
                isInstalled: true,
                isCached: true,
                tags: ["plugin", "library"],
                abstract: "Shared plugin loader",
                description: "Loads ModuleManager patches for KSP.",
                localizations: ["en-us", "ru"]),
            module(
                identifier: "Scatterer",
                name: "Scatterer",
                author: "blackrack",
                status: .upgradable,
                license: "GPL-3.0",
                relationships: [ModuleRelationship(kind: "Recommends", value: "EnvironmentalVisualEnhancements")],
                isInstalled: true,
                isCached: false,
                isNew: true,
                hasUpdate: true,
                tags: ["visual"],
                abstract: "Atmospheric scattering",
                description: "Adds Environmental Visual Enhancements support.",
                localizations: ["en-us"]),
            module(
                identifier: "Kopernicus",
                name: "Kopernicus Planetary System Modifier",
                author: "Kopernicus Team",
                status: .incompatible,
                license: "LGPL-3.0",
                relationships: [
                    ModuleRelationship(kind: "Conflicts", value: "JNSQ"),
                    ModuleRelationship(kind: "Supports", value: "OuterPlanetsMod"),
                ],
                isCompatible: false,
                tags: ["planet-pack"]),
            module(
                identifier: "ReplaceableMod",
                name: "Replaceable Mod",
                status: .installed,
                license: "MIT",
                isInstalled: true,
                hasReplacement: true,
                tags: ["utility"]),
        ]
    }

    private func primaryInstances() -> [GameInstanceSummary] {
        [
            GameInstanceSummary(
                id: "primary",
                name: "Primary KSP",
                game: "KSP",
                gameVersion: "1.12.5",
                path: "/Games/KSP",
                isDefault: true),
        ]
    }

    private func module(
        identifier: String,
        name: String,
        author: String = "Example",
        status: ModuleStatus = .available,
        installedVersion: String = "-",
        latestVersion: String = "1.0.0",
        license: String = "MIT",
        relationships: [ModuleRelationship] = [],
        versions: [String] = ["1.0.0"],
        contents: [String] = ["GameData/Example"],
        isInstalled: Bool = false,
        isCompatible: Bool = true,
        isCached: Bool = false,
        isNew: Bool = false,
        hasUpdate: Bool = false,
        hasReplacement: Bool = false,
        tags: [String] = [],
        abstract: String = "",
        description: String = "",
        localizations: [String] = [],
        gameCompatibility: String = "",
        downloadSize: Int64 = 0,
        downloadSizeDisplay: String = "",
        installSize: Int64 = 0,
        installSizeDisplay: String = "",
        releaseDate: String = "",
        installDate: String = "",
        downloadCount: Int? = nil,
        isAutoInstalled: Bool = false,
        isAutodetected: Bool = false
    ) -> ModuleSummary {
        ModuleSummary(
            identifier: identifier,
            name: name,
            author: author,
            status: status,
            installedVersion: installedVersion,
            latestVersion: latestVersion,
            license: license,
            relationships: relationships,
            versions: versions,
            contents: contents,
            isInstalled: isInstalled,
            isCompatible: isCompatible,
            isCached: isCached,
            isNew: isNew,
            hasUpdate: hasUpdate,
            hasReplacement: hasReplacement,
            tags: tags,
            abstract: abstract,
            description: description,
            localizations: localizations,
            gameCompatibility: gameCompatibility,
            downloadSize: downloadSize,
            downloadSizeDisplay: downloadSizeDisplay,
            installSize: installSize,
            installSizeDisplay: installSizeDisplay,
            releaseDate: releaseDate,
            installDate: installDate,
            downloadCount: downloadCount,
            isAutoInstalled: isAutoInstalled,
            isAutodetected: isAutodetected)
    }

    private nonisolated static func clearMackanUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "mackan.moduleCatalogState")
        UserDefaults.standard.removeObject(forKey: "mackan.savedModuleSearches")
        UserDefaults.standard.removeObject(forKey: "mackan.visibleModuleColumns")
    }
}

actor ModuleDetailsCallRecorder {
    private(set) var calls: [(instanceId: String, identifier: String)] = []

    func callCount() -> Int {
        calls.count
    }

    func record(instanceId: String, identifier: String) {
        calls.append((instanceId, identifier))
    }
}

@MainActor
private final class RecordingInstanceDirectoryOpener: InstanceDirectoryOpening {
    private(set) var revealedURLs: [URL] = []

    func revealDirectory(at url: URL) throws {
        revealedURLs.append(url)
    }
}

private final class InMemorySavedModuleSearchStore: SavedModuleSearchStoring {
    var savedSearches: [SavedModuleSearch]

    init(savedSearches: [SavedModuleSearch] = []) {
        self.savedSearches = savedSearches
    }

    func loadSavedSearches() -> [SavedModuleSearch] {
        savedSearches
    }

    func saveSavedSearches(_ savedSearches: [SavedModuleSearch]) {
        self.savedSearches = savedSearches
    }
}

private final class InMemoryModuleTableColumnStore: ModuleTableColumnStoring {
    var visibleColumns: [ModuleTableColumn]

    init(visibleColumns: [ModuleTableColumn] = []) {
        self.visibleColumns = visibleColumns
    }

    func loadVisibleModuleColumns() -> [ModuleTableColumn] {
        visibleColumns
    }

    func saveVisibleModuleColumns(_ columns: [ModuleTableColumn]) {
        visibleColumns = columns
    }
}

private final class InMemoryModuleCatalogStateStore: ModuleCatalogStateStoring {
    var catalogState: ModuleCatalogState?

    init(catalogState: ModuleCatalogState? = nil) {
        self.catalogState = catalogState
    }

    func loadCatalogState() -> ModuleCatalogState? {
        catalogState
    }

    func saveCatalogState(_ catalogState: ModuleCatalogState) {
        self.catalogState = catalogState
    }
}

private final class InMemoryModuleCatalogSnapshotStore: ModuleCatalogSnapshotStoring {
    var snapshots: [String: ModuleCatalogSnapshot]

    init(snapshots: [String: ModuleCatalogSnapshot] = [:]) {
        self.snapshots = snapshots
    }

    func loadSnapshot(for instanceID: String) -> ModuleCatalogSnapshot? {
        snapshots[instanceID]
    }

    func saveSnapshot(_ snapshot: ModuleCatalogSnapshot) {
        snapshots[snapshot.instanceId] = snapshot
    }
}

actor ModuleListGate {
    private var entered = false
    private var released = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilEntered() async {
        if entered {
            return
        }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func waitBeforeReturningModules() async {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

actor ChangeSetGate {
    private var entered = false
    private var released = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilEntered() async {
        if entered {
            return
        }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func waitBeforeResolvingChanges() async {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

actor ModuleListOperationRecorder {
    private var operationIDs: [String] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func record(operationID: String) {
        operationIDs.append(operationID)
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func waitUntilRecorded() async {
        if !operationIDs.isEmpty {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func recordedOperationIDs() -> [String] {
        operationIDs
    }
}

actor RepositoryRefreshRecorder {
    struct Record: Equatable {
        let instanceId: String?
        let force: Bool
    }

    private var recordedRefreshes: [Record] = []

    func record(instanceId: String?, force: Bool) {
        recordedRefreshes.append(Record(instanceId: instanceId, force: force))
    }

    func hasRefreshed(instanceId: String) -> Bool {
        recordedRefreshes.contains { $0.instanceId == instanceId }
    }

    func records() -> [Record] {
        recordedRefreshes
    }
}

actor ModuleDetailsGate {
    private var entered = false
    private var released = false
    private var enteredContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilEntered() async {
        if entered {
            return
        }
        await withCheckedContinuation { continuation in
            enteredContinuation = continuation
        }
    }

    func waitBeforeReturningDetails() async {
        entered = true
        enteredContinuation?.resume()
        enteredContinuation = nil
        if released {
            return
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

struct FakeSidecar: SidecarProviding {
    var applyStatus = "completed"
    var operationStatusEvents: [OperationEvent]?
    var expectedApplySkipDownloadFailures = false
    var expectedApplyProviderSelections: [ProviderSelection] = []
    var expectedFileInstallSkipDownloadFailures = false
    var expectedImportSkipDownloadFailures = false
    var changeSetHasConflict = false
    var changeSetHasProviderChoice = false
    var changeSetHasRecommendationChoice = false
    var changeSetError: SidecarClientError?
    var changeSetThrowsRegistryLock = false
    var applyErrorDetails: SidecarErrorDetails?
    var fileInstallStatus = "completed"
    var importStatus = "completed"
    var repositoryStartRefreshStatus = "updated"
    var repositoryStartOperationStatus = "completed"
    var repositoryStatusRefreshStatus = "updated"
    var repositoryStatusOperationStatus = "completed"
    var repositoryRefreshError: String?
    var repositoryRefreshErrorDetails: SidecarErrorDetails?
    var downloadStatisticsError: SidecarClientError?
    var incompatibleLaunchModules: [LaunchWarningModule] = []
    var cacheInfoPath = "/Users/test/Library/Caches/CKAN/downloads"
    var modulesByInstance: [String: [ModuleSummary]] = [:]
    var modulesAfterRepositoryRefreshByInstance: [String: [ModuleSummary]] = [:]
    var moduleDetailsCallRecorder: ModuleDetailsCallRecorder?
    var moduleDetailsGate: ModuleDetailsGate?
    var labelsByInstance: [String: [ModuleLabelSummary]] = [:]
    var manageableLabelsByInstance: [String: [ModuleLabelSummary]] = [:]
    var availableRepositoriesByInstance: [String: [RepositorySummary]] = [:]
    var repositoryRefreshRecorder: RepositoryRefreshRecorder?
    var listModulesGate: ModuleListGate?
    var moduleListGatesByInstance: [String: ModuleListGate] = [:]
    var moduleListStartStatusByInstance: [String: String] = [:]
    var moduleListStartRecorder: ModuleListOperationRecorder?
    var moduleListCancelRecorder: ModuleListOperationRecorder?
    var changeSetGate: ChangeSetGate?
    var toggleLabelsResult: SidecarLabelsResult?
    var upsertLabelsResult: SidecarLabelsResult?
    var deleteLabelsResult: SidecarLabelsResult?
    var autoInstalledResult: SidecarModulesResult?
    var expectedImportInstallImportedModules = true
    var expectedImportDeleteImportedFiles = false
    var expectedImportPreviewBeforeInstall = false
    var expectedResolveInstall = ["SidecarOnlyMod"]
    var expectedResolveRemove: [String] = []
    var expectedResolveInstallVersions: [VersionedModuleSelection] = []
    var changeSetSuppressRecommendations = false
    var launchGameError: SidecarClientError?
    var expectedCheckForUpdatesUseDevBuilds: Bool? = false
    var updateCheckResult = UpdateCheckResult(
        status: "available",
        currentVersion: "v1.0.0-test",
        latestVersion: "v1.1.0",
        latestDisplayVersion: "v1.1.0 aka Mun",
        releaseNotes: "Stable release notes",
        source: "stable",
        useDevBuilds: false,
        canAutoInstall: false,
        installMessage: "Install the signed MACKAN DMG from the release page.",
        downloadUrls: ["https://github.com/KSP-CKAN/CKAN/releases/download/v1.1.0/MACKAN.dmg"],
        error: nil)
    var generalSettingsResult = GeneralSettingsResult(
        instanceId: "primary",
        checkForUpdatesOnLaunch: true,
        useDevBuilds: false,
        refreshRepositoriesOnLaunch: true,
        autoSortByUpdate: true)

    func health() async throws -> SidecarHealth {
        SidecarHealth(status: "ok", protocolVersion: "1", ckanVersion: "v1.36.5-test")
    }

    func version() async throws -> SidecarVersion {
        SidecarVersion(
            appName: "MACKAN",
            serviceVersion: "1.36.5-test",
            ckanVersion: "v1.36.5-test",
            protocolVersion: "1",
            dotnetVersion: "10.0-test",
            operatingSystem: "macOS test",
            processArchitecture: "Arm64")
    }

    func checkForUpdates(useDevBuilds: Bool?) async throws -> UpdateCheckResult {
        XCTAssertEqual(useDevBuilds, expectedCheckForUpdatesUseDevBuilds)
        return updateCheckResult
    }

    func listInstances() async throws -> SidecarInstancesResult {
        SidecarInstancesResult(
            defaultInstanceId: "primary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
                GameInstanceSummary(
                    id: "secondary",
                    name: "Secondary KSP",
                    game: "KSP",
                    gameVersion: "1.11.2",
                    path: "/Games/KSP-Secondary",
                    isDefault: false,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func setDefaultInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        XCTAssertEqual(instanceId, "secondary")
        return SidecarInstancesResult(
            defaultInstanceId: "secondary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: false,
                    isValid: true,
                    isMaybeLocked: false),
                GameInstanceSummary(
                    id: "secondary",
                    name: "Secondary KSP",
                    game: "KSP",
                    gameVersion: "1.11.2",
                    path: "/Games/KSP-Secondary",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func addInstance(path: String, name: String) async throws -> SidecarInstancesResult {
        XCTAssertEqual(path, "/Games/KSP-New")
        XCTAssertEqual(name, "New KSP")
        return SidecarInstancesResult(
            defaultInstanceId: "primary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
                GameInstanceSummary(
                    id: "New KSP",
                    name: "New KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP-New",
                    isDefault: false,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func cloneInstance(
        sourceInstanceId: String,
        newName: String,
        newPath: String,
        shareStock: Bool,
        leaveEmptyPaths: [String]?
    ) async throws -> SidecarInstancesResult {
        XCTAssertEqual(sourceInstanceId, "primary")
        XCTAssertEqual(newName, "Cloned KSP")
        XCTAssertEqual(newPath, "/Games/KSP-Clone")
        XCTAssertFalse(shareStock)
        XCTAssertEqual(leaveEmptyPaths, ["saves", "Screenshots"])
        return SidecarInstancesResult(
            defaultInstanceId: "primary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
                GameInstanceSummary(
                    id: "Cloned KSP",
                    name: "Cloned KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP-Clone",
                    isDefault: false,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func cloneOptions(sourceInstanceId: String) async throws -> CloneOptionsResult {
        XCTAssertEqual(sourceInstanceId, "primary")
        return CloneOptionsResult(
            sourceInstanceId: sourceInstanceId,
            leaveEmptyPaths: ["saves", "Screenshots", "CKAN/downloads"])
    }

    func fakeInstance(
        name: String,
        path: String,
        version: String,
        gameId: String,
        makingHistoryVersion: String?,
        breakingGroundVersion: String?,
        setDefault: Bool
    ) async throws -> SidecarInstancesResult {
        XCTAssertEqual(name, "Fake KSP")
        XCTAssertEqual(path, "/Games/KSP-Fake")
        XCTAssertEqual(version, "1.12.5")
        XCTAssertEqual(gameId, "KSP")
        XCTAssertEqual(makingHistoryVersion, "1.12.1")
        XCTAssertEqual(breakingGroundVersion, "1.7.1")
        XCTAssertTrue(setDefault)
        return SidecarInstancesResult(
            defaultInstanceId: "Fake KSP",
            instances: [
                GameInstanceSummary(
                    id: "Fake KSP",
                    name: "Fake KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP-Fake",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func removeInstance(_ instanceId: String) async throws -> SidecarInstancesResult {
        XCTAssertEqual(instanceId, "secondary")
        return SidecarInstancesResult(
            defaultInstanceId: "primary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func renameInstance(_ instanceId: String, to newName: String) async throws -> SidecarInstancesResult {
        XCTAssertEqual(instanceId, "secondary")
        XCTAssertEqual(newName, "renamed")
        return SidecarInstancesResult(
            defaultInstanceId: "primary",
            instances: [
                GameInstanceSummary(
                    id: "primary",
                    name: "Primary KSP",
                    game: "KSP",
                    gameVersion: "1.12.5",
                    path: "/Games/KSP",
                    isDefault: true,
                    isValid: true,
                    isMaybeLocked: false),
                GameInstanceSummary(
                    id: "renamed",
                    name: "Renamed KSP",
                    game: "KSP",
                    gameVersion: "1.11.2",
                    path: "/Games/KSP-Secondary",
                    isDefault: false,
                    isValid: true,
                    isMaybeLocked: false),
            ])
    }

    func listModules(instanceId: String?) async throws -> SidecarModulesResult {
        let instanceId = instanceId ?? "primary"
        await moduleListGate(for: instanceId)?.waitBeforeReturningModules()
        return SidecarModulesResult(
            instanceId: instanceId,
            modules: await modules(for: instanceId))
    }

    func startListModules(instanceId: String?) async throws -> ModuleListOperationResult {
        let instanceId = instanceId ?? "primary"
        await moduleListGate(for: instanceId)?.waitBeforeReturningModules()
        let status = moduleListStartStatusByInstance[instanceId] ?? "completed"
        let operationId = moduleListStartStatusByInstance[instanceId] == nil
            ? "module-list-op"
            : "module-list-op-\(instanceId)"
        await moduleListStartRecorder?.record(operationID: operationId)
        return ModuleListOperationResult(
            operationId: operationId,
            instanceId: instanceId,
            status: status,
            modules: await modules(for: instanceId),
            events: [
                OperationEvent(
                    kind: "progress",
                    message: "Loaded 1 mods",
                    percent: 100,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil,
                    completedCount: 1,
                    totalCount: 1),
            ])
    }

    func moduleListStatus(operationId: String) async throws -> ModuleListOperationResult {
        XCTAssertEqual(operationId, "module-list-op")
        return ModuleListOperationResult(
            operationId: operationId,
            instanceId: "primary",
            status: "completed",
            modules: await modules(for: "primary"))
    }

    func cancelModuleList(operationId: String) async throws -> ModuleListOperationResult {
        if moduleListCancelRecorder == nil {
            XCTAssertEqual(operationId, "module-list-op")
        }
        await moduleListCancelRecorder?.record(operationID: operationId)
        return ModuleListOperationResult(
            operationId: operationId,
            instanceId: "primary",
            status: "cancelled",
            modules: [])
    }

    func listLabels(instanceId: String?) async throws -> SidecarLabelsResult {
        let instanceId = instanceId ?? "primary"
        return SidecarLabelsResult(
            instanceId: instanceId,
            labels: labelsByInstance[instanceId] ?? [],
            manageableLabels: manageableLabelsByInstance[instanceId] ?? labelsByInstance[instanceId] ?? [])
    }

    func toggleModuleLabel(instanceId: String?, labelName: String, identifier: String) async throws -> SidecarLabelsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(labelName, "Favourites")
        XCTAssertEqual(identifier, "Scatterer")
        return toggleLabelsResult ?? SidecarLabelsResult(instanceId: instanceId, labels: labelsByInstance[instanceId ?? "primary"] ?? [])
    }

    func upsertModuleLabel(
        instanceId: String?,
        originalName: String?,
        originalInstanceName: String?,
        label: ModuleLabelEdit
    ) async throws -> SidecarLabelsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertNil(originalName)
        XCTAssertNil(originalInstanceName)
        XCTAssertEqual(label.name, "Watch")
        XCTAssertEqual(label.instanceName, "primary")
        XCTAssertEqual(label.colorHex, "#336699")
        XCTAssertTrue(label.hide)
        XCTAssertTrue(label.notifyOnChange)
        XCTAssertTrue(label.alertOnInstall)
        XCTAssertTrue(label.holdVersion)
        XCTAssertTrue(label.ignoreMissingFiles)
        return upsertLabelsResult ?? SidecarLabelsResult(instanceId: instanceId, labels: labelsByInstance[instanceId ?? "primary"] ?? [])
    }

    func deleteModuleLabel(instanceId: String?, name: String, instanceName: String?) async throws -> SidecarLabelsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(name, "Watch")
        XCTAssertEqual(instanceName, "primary")
        return deleteLabelsResult ?? SidecarLabelsResult(instanceId: instanceId, labels: labelsByInstance[instanceId ?? "primary"] ?? [])
    }

    func setAutoInstalled(instanceId: String?, identifier: String, isAutoInstalled: Bool) async throws -> SidecarModulesResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(identifier, "ModuleManager")
        XCTAssertTrue(isAutoInstalled)
        return autoInstalledResult ?? SidecarModulesResult(instanceId: instanceId, modules: modulesByInstance[instanceId ?? "primary"] ?? [])
    }

    func moduleDetails(instanceId: String?, identifier: String) async throws -> ModuleDetails {
        let instanceId = instanceId ?? "primary"
        let module = await modules(for: instanceId).first { $0.identifier == identifier }
            ?? summary(for: instanceId)
        XCTAssertEqual(identifier, module.identifier)
        await moduleDetailsCallRecorder?.record(instanceId: instanceId, identifier: identifier)
        await moduleDetailsGate?.waitBeforeReturningDetails()
        return ModuleDetails(
            instanceId: instanceId,
            module: module,
            abstract: instanceId == "secondary" ? "Secondary sidecar detail" : "A real sidecar detail",
            description: "Detailed metadata loaded for the selected module.",
            releaseStatus: "stable",
            kind: "package",
            releaseDate: "2024-01-02T03:04:05.0000000Z",
            downloadSize: 1024,
            installSize: 2048,
            resources: [
                ModuleResource(label: "Homepage", url: "https://example.invalid/mod"),
            ],
            tags: ["plugin"])
    }

    func listRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        let instanceId = instanceId ?? "primary"
        return SidecarRepositoriesResult(
            instanceId: instanceId,
            repositories: [
                RepositorySummary(
                    name: instanceId == "secondary" ? "secondary" : "default",
                    url: instanceId == "secondary"
                        ? "https://example.invalid/secondary.tar.gz"
                        : "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                    priority: 0,
                    isMirror: false,
                    comment: ""),
            ])
    }

    func listAvailableRepositories(instanceId: String?) async throws -> SidecarRepositoriesResult {
        let instanceId = instanceId ?? "primary"
        let repositories = availableRepositoriesByInstance[instanceId] ?? [
            RepositorySummary(
                name: "stable",
                url: "https://example.invalid/stable.tar.gz",
                priority: 0,
                isMirror: false,
                comment: "canonical stable"),
        ]
        return SidecarRepositoriesResult(
            instanceId: instanceId,
            repositories: repositories)
    }

    func addRepository(instanceId: String?, name: String, url: String) async throws -> SidecarRepositoriesResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(name, "newrepo")
        XCTAssertEqual(url, "https://example.invalid/newrepo.tar.gz")
        return SidecarRepositoriesResult(
            instanceId: instanceId,
            repositories: [
                repository(name: "default", url: "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz", priority: 0),
                repository(name: "newrepo", url: "https://example.invalid/newrepo.tar.gz", priority: 1),
            ])
    }

    func removeRepository(instanceId: String?, name: String) async throws -> SidecarRepositoriesResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(name, "default")
        return SidecarRepositoriesResult(
            instanceId: instanceId,
            repositories: [
                repository(name: "mirror", url: "https://example.invalid/mirror.tar.gz", priority: 0, isMirror: true),
            ])
    }

    func setRepositoryPriority(instanceId: String?, name: String, priority: Int) async throws -> SidecarRepositoriesResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(name, "mirror")
        XCTAssertEqual(priority, 0)
        return SidecarRepositoriesResult(
            instanceId: instanceId,
            repositories: [
                repository(name: "mirror", url: "https://example.invalid/mirror.tar.gz", priority: 0, isMirror: true),
                repository(name: "default", url: "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz", priority: 1),
            ])
    }

    func refreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        XCTAssertEqual(instanceId, "primary")
        await repositoryRefreshRecorder?.record(instanceId: instanceId, force: force)
        return RepositoryRefreshResult(
            instanceId: instanceId,
            status: repositoryStartRefreshStatus,
            compatibleModuleCount: repositoryStartOperationStatus == "completed" ? 42 : 0,
            repositories: repositoryStartOperationStatus == "completed"
                ? [repository(name: "default", url: "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz", priority: 0)]
                : [],
            events: repositoryStartOperationStatus == "completed"
                ? [
                    OperationEvent(
                        kind: "message",
                        message: "Updating repositories",
                        percent: nil,
                        identifier: nil,
                        remainingBytes: nil,
                        totalBytes: nil),
                    OperationEvent(
                        kind: "progress",
                        message: "Done",
                        percent: 100,
                        identifier: nil,
                        remainingBytes: 0,
                        totalBytes: 4096),
                ]
                : [
                    OperationEvent(
                        kind: "message",
                        message: "Repository refresh queued",
                        percent: nil,
                        identifier: nil,
                        remainingBytes: nil,
                        totalBytes: nil),
                ],
            operationId: "repo-op",
            operationStatus: repositoryStartOperationStatus)
    }

    func startRefreshRepositories(instanceId: String?, force: Bool) async throws -> RepositoryRefreshResult {
        try await refreshRepositories(instanceId: instanceId, force: force)
    }

    func repositoryRefreshStatus(operationId: String) async throws -> RepositoryRefreshResult {
        XCTAssertEqual(operationId, "repo-op")
        return RepositoryRefreshResult(
            instanceId: "primary",
            status: repositoryStatusRefreshStatus,
            compatibleModuleCount: repositoryStatusOperationStatus == "completed" ? 42 : 0,
            repositories: repositoryStatusOperationStatus == "completed"
                ? [
                    repository(name: "default", url: "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz", priority: 0),
                ]
                : [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Updating repositories",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
                OperationEvent(
                    kind: "progress",
                    message: "Done",
                    percent: 100,
                    identifier: nil,
                    remainingBytes: repositoryStatusOperationStatus == "completed" ? 0 : 2048,
                    totalBytes: 4096),
            ],
            operationId: operationId,
            operationStatus: repositoryStatusOperationStatus,
            error: repositoryRefreshError,
            errorDetails: repositoryRefreshErrorDetails)
    }

    func cancelRepositoryRefresh(operationId: String) async throws -> RepositoryRefreshResult {
        XCTAssertEqual(operationId, "repo-op")
        return RepositoryRefreshResult(
            instanceId: "primary",
            status: "running",
            compatibleModuleCount: 0,
            repositories: [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Cancellation requested",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            operationId: operationId,
            operationStatus: "cancelling")
    }

    func resolveChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection]
    ) async throws -> ChangeSetResult {
        if let changeSetError {
            throw changeSetError
        }
        if changeSetThrowsRegistryLock {
            throw SidecarClientError.registryLocked(
                message: "Registry is locked",
                lockfilePath: "/Games/KSP/CKAN/registry.locked")
        }
        await changeSetGate?.waitBeforeResolvingChanges()

        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(remove, expectedResolveRemove)
        XCTAssertTrue(upgrade.isEmpty)
        XCTAssertEqual(installVersions, expectedResolveInstallVersions)

        if !expectedResolveRemove.isEmpty {
            XCTAssertTrue(install.isEmpty)
            XCTAssertTrue(replace.isEmpty)
            return ChangeSetResult(
                instanceId: instanceId,
                changes: expectedResolveRemove.map { identifier in
                    ChangeSummary(
                        identifier: identifier,
                        name: "Installed Mod",
                        action: "remove",
                        fromVersion: "1.0.0",
                        toVersion: nil,
                        reasons: ["User requested"],
                        isUserRequested: true,
                        isAuto: false)
                },
                conflicts: [],
                conflictDescriptions: [])
        }

        if replace == ["ReplaceableMod"] {
            XCTAssertTrue(install.isEmpty)
            return ChangeSetResult(
                instanceId: instanceId,
                changes: [
                    ChangeSummary(
                        identifier: "ReplaceableMod",
                        name: "Replaceable Mod",
                        action: "replace",
                        fromVersion: "1.0.0",
                        toVersion: "2.0.0",
                        reasons: ["User requested"],
                        isUserRequested: true,
                        isAuto: false),
                    ChangeSummary(
                        identifier: "ReplacementMod",
                        name: "Replacement Mod",
                        action: "install",
                        fromVersion: nil,
                        toVersion: "2.0.0",
                        reasons: ["Replacing Replaceable Mod"],
                        isUserRequested: false,
                        isAuto: false),
                ],
                conflicts: [],
                conflictDescriptions: [])
        }

        if expectedResolveInstallVersions.isEmpty {
            XCTAssertEqual(install, expectedResolveInstall)
        } else {
            XCTAssertTrue(install.isEmpty)
        }
        XCTAssertTrue(replace.isEmpty)
        let expectedRequester = expectedResolveInstallVersions.first?.identifier
            ?? expectedResolveInstall.first
            ?? "SidecarOnlyMod"
        if !providerSelections.isEmpty {
            XCTAssertEqual(providerSelections, [
                ProviderSelection(
                    requested: "VirtualDependency",
                    requesterIdentifier: expectedRequester,
                    selectedIdentifier: "ProviderA"),
            ])
        }
        let requestedIdentifier = expectedRequester
        let requestedName = requestedIdentifier == "DogeCoinPlugin"
            ? "Dogecoin Core Plugin"
            : "Sidecar Only Mod"
        let requestedVersion = expectedResolveInstallVersions.first?.version ?? "1.0.0"
        return ChangeSetResult(
            instanceId: instanceId,
            changes: [
                ChangeSummary(
                    identifier: requestedIdentifier,
                        name: requestedName,
                        action: "install",
                        fromVersion: nil,
                        toVersion: requestedVersion,
                        reasons: ["User requested"],
                    isUserRequested: true,
                    isAuto: false),
                ChangeSummary(
                    identifier: "DependencyMod",
                    name: "Dependency Mod",
                    action: "install",
                    fromVersion: nil,
                    toVersion: "2.0.0",
                    reasons: ["Dependency of \(requestedIdentifier)"],
                    isUserRequested: false,
                    isAuto: true),
            ],
            conflicts: changeSetHasConflict
                ? [
                    ConflictSummary(
                        identifier: "ExistingConflict",
                        name: "Existing Conflict",
                        description: "Conflicts with Sidecar Only Mod"),
                ]
                : [],
            conflictDescriptions: changeSetHasConflict
                ? ["ExistingConflict conflicts with SidecarOnlyMod"]
                : [],
            providerChoices: changeSetHasProviderChoice && providerSelections.isEmpty
                ? [
                    ProviderChoice(
                        requested: "VirtualDependency",
                        message: "Choose a provider",
                        requesterIdentifier: "SidecarOnlyMod",
                        requesterName: "Sidecar Only Mod",
                        options: [
                            ProviderOption(
                                identifier: "ProviderA",
                                name: "Provider A",
                                version: "1.0.0",
                                abstract: "First provider"),
                            ProviderOption(
                                identifier: "ProviderB",
                                name: "Provider B",
                                version: "2.0.0",
                                abstract: "Second provider"),
                        ]),
                ]
                : [],
            recommendationChoices: changeSetHasRecommendationChoice
                ? [
                    RecommendationChoice(
                        kind: "recommendation",
                        identifier: "RecommendedMod",
                        name: "Recommended Mod",
                        version: "1.2.3",
                        abstract: "Useful companion",
                        dependents: ["SidecarOnlyMod"],
                        isRecommendedDefault: true),
                ]
                : [],
            suppressRecommendations: changeSetSuppressRecommendations)
    }

    private func moduleListGate(for instanceId: String) -> ModuleListGate? {
        moduleListGatesByInstance[instanceId] ?? listModulesGate
    }

    private func modules(for instanceId: String) async -> [ModuleSummary] {
        if let recorder = repositoryRefreshRecorder,
           await recorder.hasRefreshed(instanceId: instanceId),
           let refreshedModules = modulesAfterRepositoryRefreshByInstance[instanceId] {
            return refreshedModules
        }

        return modulesByInstance[instanceId] ?? [
            summary(for: instanceId),
        ]
    }

    func applyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try applyChangeAssertions(
            instanceId: instanceId,
            install: install,
            remove: remove,
            upgrade: upgrade,
            replace: replace,
            installVersions: installVersions,
            providerSelections: providerSelections,
            skipDownloadFailures: skipDownloadFailures)
        return operationResult(instanceId: instanceId, isReplacement: !replace.isEmpty)
    }

    func startApplyChanges(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool = false
    ) async throws -> OperationResult {
        try applyChangeAssertions(
            instanceId: instanceId,
            install: install,
            remove: remove,
            upgrade: upgrade,
            replace: replace,
            installVersions: installVersions,
            providerSelections: providerSelections,
            skipDownloadFailures: skipDownloadFailures)
        return operationResult(instanceId: instanceId, isReplacement: !replace.isEmpty)
    }

    private func applyChangeAssertions(
        instanceId: String?,
        install: [String],
        remove: [String],
        upgrade: [String],
        replace: [String],
        installVersions: [VersionedModuleSelection],
        providerSelections: [ProviderSelection],
        skipDownloadFailures: Bool
    ) throws {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertTrue(remove.isEmpty)
        XCTAssertTrue(upgrade.isEmpty)
        XCTAssertTrue(installVersions.isEmpty)
        XCTAssertEqual(providerSelections, expectedApplyProviderSelections)
        XCTAssertEqual(skipDownloadFailures, expectedApplySkipDownloadFailures)

        if replace == ["ReplaceableMod"] {
            XCTAssertTrue(install.isEmpty)
        } else {
            XCTAssertEqual(install, ["SidecarOnlyMod"])
            XCTAssertTrue(replace.isEmpty)
        }
    }

    private func operationResult(instanceId: String?, isReplacement: Bool = false) -> OperationResult {
        let finalMessage = applyStatus == "completed" ? "Done" : "Operation queued"
        return OperationResult(
            operationId: "op-1",
            instanceId: instanceId,
            status: applyStatus,
            changes: [
                isReplacement
                    ? ChangeSummary(
                        identifier: "ReplaceableMod",
                        name: "Replaceable Mod",
                        action: "replace",
                        fromVersion: "1.0.0",
                        toVersion: "2.0.0",
                        reasons: ["User requested"],
                        isUserRequested: true,
                        isAuto: false)
                    : ChangeSummary(
                        identifier: "SidecarOnlyMod",
                        name: "Sidecar Only Mod",
                        action: "install",
                        fromVersion: nil,
                        toVersion: "1.0.0",
                        reasons: ["User requested"],
                        isUserRequested: true,
                        isAuto: false),
            ],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Installing Sidecar Only Mod",
                    percent: nil,
                    identifier: "SidecarOnlyMod",
                    remainingBytes: nil,
                    totalBytes: nil),
                OperationEvent(
                    kind: "progress",
                    message: finalMessage,
                    percent: applyStatus == "completed" ? 100 : 0,
                    identifier: nil,
                    remainingBytes: applyStatus == "completed" ? 0 : 2048,
                    totalBytes: 2048),
            ],
            error: applyErrorMessage,
            errorDetails: applyErrorDetails)
    }

    private var applyErrorMessage: String? {
        switch applyErrorDetails?.kind {
        case "registryLock":
            return "Registry is locked"
        case "downloadFailures":
            return "Downloads failed"
        case .some:
            return "Operation failed"
        case .none:
            return nil
        }
    }

    func cancelOperation(operationId: String) async throws -> OperationResult {
        XCTAssertEqual(operationId, "op-1")
        return OperationResult(
            operationId: operationId,
            instanceId: "primary",
            status: "cancelling",
            changes: [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Cancellation requested",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)
    }

    func installCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection],
        recommendationSelections: [String],
        skipRecommendations: Bool,
        allowIncompatibleCkanFiles: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult {
        try assertFileInstallRequest(
            instanceId: instanceId,
            filePaths: filePaths,
            providerSelections: providerSelections,
            recommendationSelections: recommendationSelections,
            skipRecommendations: skipRecommendations,
            allowIncompatibleCkanFiles: allowIncompatibleCkanFiles,
            skipDownloadFailures: skipDownloadFailures)
        return fileInstallResult(instanceId: instanceId, status: "completed")
    }

    func startInstallCkanFiles(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection],
        recommendationSelections: [String],
        skipRecommendations: Bool,
        allowIncompatibleCkanFiles: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult {
        try assertFileInstallRequest(
            instanceId: instanceId,
            filePaths: filePaths,
            providerSelections: providerSelections,
            recommendationSelections: recommendationSelections,
            skipRecommendations: skipRecommendations,
            allowIncompatibleCkanFiles: allowIncompatibleCkanFiles,
            skipDownloadFailures: skipDownloadFailures)
        return fileInstallResult(instanceId: instanceId, status: fileInstallStatus)
    }

    private func assertFileInstallRequest(
        instanceId: String?,
        filePaths: [String],
        providerSelections: [ProviderSelection],
        recommendationSelections: [String],
        skipRecommendations: Bool,
        allowIncompatibleCkanFiles: Bool,
        skipDownloadFailures: Bool
    ) throws {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(filePaths, ["/Downloads/ModuleManager.ckan"])
        XCTAssertTrue(providerSelections.isEmpty)
        XCTAssertTrue(recommendationSelections.isEmpty)
        XCTAssertFalse(skipRecommendations)
        XCTAssertFalse(allowIncompatibleCkanFiles)
        XCTAssertEqual(skipDownloadFailures, expectedFileInstallSkipDownloadFailures)
    }

    private func fileInstallResult(instanceId: String?, status: String) -> OperationResult {
        return OperationResult(
            operationId: "op-file",
            instanceId: instanceId,
            status: status,
            changes: status == "completed"
                ? [
                    ChangeSummary(
                        identifier: "ModuleManager",
                        name: "Module Manager",
                        action: "install",
                        fromVersion: nil,
                        toVersion: "4.2.3",
                        reasons: ["User requested"],
                        isUserRequested: true,
                        isAuto: false),
                ]
                : [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: status == "completed" ? "Installing Module Manager" : "Operation queued",
                    percent: nil,
                    identifier: status == "completed" ? "ModuleManager" : nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)
    }

    func importDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult {
        try assertImportDownloadsRequest(
            instanceId: instanceId,
            paths: paths,
            installImportedModules: installImportedModules,
            deleteImportedFiles: deleteImportedFiles,
            previewBeforeInstall: previewBeforeInstall,
            skipDownloadFailures: skipDownloadFailures)
        return importDownloadsResult(instanceId: instanceId, status: "completed")
    }

    func startImportDownloads(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool,
        skipDownloadFailures: Bool
    ) async throws -> OperationResult {
        try assertImportDownloadsRequest(
            instanceId: instanceId,
            paths: paths,
            installImportedModules: installImportedModules,
            deleteImportedFiles: deleteImportedFiles,
            previewBeforeInstall: previewBeforeInstall,
            skipDownloadFailures: skipDownloadFailures)
        return importDownloadsResult(instanceId: instanceId, status: importStatus)
    }

    private func assertImportDownloadsRequest(
        instanceId: String?,
        paths: [String],
        installImportedModules: Bool,
        deleteImportedFiles: Bool,
        previewBeforeInstall: Bool,
        skipDownloadFailures: Bool
    ) throws {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(paths, ["/Downloads/DogeCoinPlugin.zip"])
        XCTAssertEqual(installImportedModules, expectedImportInstallImportedModules)
        XCTAssertEqual(deleteImportedFiles, expectedImportDeleteImportedFiles)
        XCTAssertEqual(previewBeforeInstall, expectedImportPreviewBeforeInstall)
        XCTAssertEqual(skipDownloadFailures, expectedImportSkipDownloadFailures)
    }

    private func importDownloadsResult(instanceId: String?, status: String) -> OperationResult {
        return OperationResult(
            operationId: "op-import",
            instanceId: instanceId,
            status: status,
            changes: status == "completed"
                ? [
                    ChangeSummary(
                        identifier: "DogeCoinPlugin",
                        name: "Dogecoin Core Plugin",
                        action: "install",
                        fromVersion: nil,
                        toVersion: "1.01",
                        reasons: ["Imported download"],
                        isUserRequested: true,
                        isAuto: false),
                ]
                : [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: status == "completed" ? "Importing DogeCoinPlugin.zip" : "Operation queued",
                    percent: nil,
                    identifier: status == "completed" ? "DogeCoinPlugin" : nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)
    }

    func exportModList(instanceId: String?, format: ModListExportFormat) async throws -> ModListExportResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(format, .markdown)
        return ModListExportResult(
            instanceId: instanceId,
            format: format,
            suggestedFileName: "Primary KSP-mods.md",
            contentType: "text/markdown",
            contents: "- **Module Manager** `ModuleManager 4.2.3`")
    }

    func exportModpack(instanceId: String?, draft: ModpackExportDraft) async throws -> ModpackExportResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(draft.identifier, "MyModpack")
        XCTAssertEqual(draft.name, "My Modpack")
        XCTAssertEqual(draft.abstract, "Essential mods")
        XCTAssertEqual(draft.author, "Jeb Kerman")
        XCTAssertEqual(draft.version, "v1")
        XCTAssertEqual(draft.license, "MIT")
        XCTAssertEqual(draft.gameVersionMin, "1.12")
        XCTAssertEqual(draft.gameVersionMax, "1.12.5")
        XCTAssertFalse(draft.includeVersions)
        XCTAssertFalse(draft.includeOptionalRelationships)
        XCTAssertEqual(draft.relationshipAssignments, [
            ModpackRelationshipAssignment(identifier: "ModuleManager", kind: "depends"),
            ModpackRelationshipAssignment(identifier: "Scatterer", kind: "recommends"),
            ModpackRelationshipAssignment(identifier: "UnusedVisualPack", kind: "ignore"),
        ])
        return ModpackExportResult(
            instanceId: instanceId,
            identifier: draft.identifier,
            suggestedFileName: "MyModpack.ckan",
            contentType: "application/json",
            contents: #"{"identifier":"MyModpack","depends":[{"name":"ModuleManager"}]}"#)
    }

    func scanGameData(instanceId: String?) async throws -> MaintenanceScanResult {
        XCTAssertEqual(instanceId, "primary")
        return MaintenanceScanResult(
            instanceId: instanceId,
            changed: true,
            detectedDllCount: 2,
            detectedDlcCount: 1)
    }

    func listUnmanagedFiles(instanceId: String?) async throws -> UnmanagedFilesResult {
        XCTAssertEqual(instanceId, "primary")
        return UnmanagedFilesResult(
            instanceId: instanceId,
            changed: true,
            files: [
                UnmanagedFileSummary(
                    identifier: "ManualPlugin",
                    kind: "dll",
                    version: nil,
                    path: "GameData/Manual/ManualPlugin.dll"),
                UnmanagedFileSummary(
                    identifier: "MakingHistory-DLC",
                    kind: "dlc",
                    version: "1.12.1 (unmanaged)",
                    path: nil),
            ])
    }

    func listInstallationHistory(instanceId: String?) async throws -> InstallationHistoryResult {
        XCTAssertEqual(instanceId, "primary")
        return InstallationHistoryResult(
            instanceId: instanceId,
            entries: [
                InstallationHistoryEntrySummary(
                    fileName: "installed-Primary_KSP-2026-05-31_10-00-00.ckan",
                    savedAt: "2026-05-31T10:00:00.0000000Z",
                    moduleCount: 1),
            ])
    }

    func loadInstallationHistoryEntry(instanceId: String?, fileName: String) async throws -> InstallationHistoryEntry {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(fileName, "installed-Primary_KSP-2026-05-31_10-00-00.ckan")
        return InstallationHistoryEntry(
            fileName: fileName,
            savedAt: "2026-05-31T10:00:00.0000000Z",
            modules: [
                InstallationHistoryModule(
                    identifier: "ModuleManager",
                    name: "Module Manager",
                    version: "4.2.3",
                    author: "sarbian",
                    abstract: "Core patch manager",
                    isInstalled: false,
                    isAvailable: true),
            ])
    }

    func listPlayTime() async throws -> PlayTimeResult {
        PlayTimeResult(
            entries: [
                PlayTimeEntry(
                    instanceId: "primary",
                    name: "Primary KSP",
                    path: "/Games/KSP",
                    hours: 12.5,
                    display: "12.5"),
                PlayTimeEntry(
                    instanceId: "secondary",
                    name: "Secondary KSP",
                    path: "/Games/KSP-Secondary",
                    hours: 0,
                    display: "0.0"),
            ],
            totalHours: 12.5,
            totalDisplay: "12.5")
    }

    func updatePlayTime(instanceId: String, hours: Double) async throws -> PlayTimeResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(hours, 14.25)
        return PlayTimeResult(
            entries: [
                PlayTimeEntry(
                    instanceId: instanceId,
                    name: "Primary KSP",
                    path: "/Games/KSP",
                    hours: hours,
                    display: "14.3"),
            ],
            totalHours: hours,
            totalDisplay: "14.3")
    }

    func downloadStatistics(instanceId: String?) async throws -> DownloadStatisticsResult {
        XCTAssertEqual(instanceId, "primary")
        if let downloadStatisticsError {
            throw downloadStatisticsError
        }
        return DownloadStatisticsResult(
            instanceId: instanceId,
            hosts: [
                DownloadStatisticsHost(
                    host: "spacedock.info",
                    bytes: 1536,
                    display: "1.5 KiB"),
                DownloadStatisticsHost(
                    host: "archive.org",
                    bytes: 512,
                    display: "512 bytes"),
            ],
            totalBytes: 2048,
            totalDisplay: "2 KiB")
    }

    func cacheInfo() async throws -> CacheInfoResult {
        CacheInfoResult(
            path: cacheInfoPath,
            fileCount: 7,
            bytes: 4096,
            display: "4 KiB",
            freeBytes: 8192,
            freeDisplay: "8 KiB",
            limitBytes: 2048,
            limitDisplay: "2 KiB",
            isOverLimit: true)
    }

    func getSettings() async throws -> SettingsResult {
        SettingsResult(
            downloadCacheDir: "/Users/test/Library/Caches/CKAN/downloads",
            defaultDownloadCacheDir: "/Users/test/Library/Caches/CKAN/downloads",
            isDefaultDownloadCacheDir: true,
            cacheSizeLimitBytes: 1_073_741_824,
            cacheSizeLimitDisplay: "1 GiB")
    }

    func updateSettings(
        downloadCacheDir: String,
        cacheSizeLimitBytes: Int64?,
        cacheMigrationChoice: CacheMigrationChoice
    ) async throws -> SettingsResult {
        XCTAssertEqual(downloadCacheDir, "/Users/test/CKANCache")
        XCTAssertNil(cacheSizeLimitBytes)
        XCTAssertEqual(cacheMigrationChoice, .move)
        return SettingsResult(
            downloadCacheDir: downloadCacheDir,
            defaultDownloadCacheDir: "/Users/test/Library/Caches/CKAN/downloads",
            isDefaultDownloadCacheDir: false,
            cacheSizeLimitBytes: nil,
            cacheSizeLimitDisplay: "Unlimited")
    }

    func generalSettings(instanceId: String?) async throws -> GeneralSettingsResult {
        XCTAssertEqual(instanceId, "primary")
        return generalSettingsResult
    }

    func updateGeneralSettings(
        instanceId: String?,
        checkForUpdatesOnLaunch: Bool,
        useDevBuilds: Bool,
        refreshRepositoriesOnLaunch: Bool,
        autoSortByUpdate: Bool
    ) async throws -> GeneralSettingsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertFalse(checkForUpdatesOnLaunch)
        XCTAssertTrue(useDevBuilds)
        XCTAssertFalse(refreshRepositoriesOnLaunch)
        XCTAssertFalse(autoSortByUpdate)
        return GeneralSettingsResult(
            instanceId: "primary",
            checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
            useDevBuilds: useDevBuilds,
            refreshRepositoriesOnLaunch: refreshRepositoriesOnLaunch,
            autoSortByUpdate: autoSortByUpdate)
    }

    func recommendationSettings(instanceId: String?) async throws -> RecommendationSettingsResult {
        XCTAssertEqual(instanceId, "primary")
        return RecommendationSettingsResult(instanceId: "primary", suppressRecommendations: false)
    }

    func updateRecommendationSettings(
        instanceId: String?,
        suppressRecommendations: Bool
    ) async throws -> RecommendationSettingsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertTrue(suppressRecommendations)
        return RecommendationSettingsResult(instanceId: "primary", suppressRecommendations: suppressRecommendations)
    }

    func compatibleGameVersions(instanceId: String?) async throws -> CompatibleGameVersionsResult {
        XCTAssertEqual(instanceId, "primary")
        return CompatibleGameVersionsResult(
            instanceId: "primary",
            game: "KSP",
            actualGameVersion: "1.12.5",
            gameVersionWhenWritten: "1.12.4",
            compatibleVersionsAreFromDifferentGameVersion: true,
            compatibleVersions: ["1.12.4", "1.11.2"],
            knownVersions: ["1.12.5", "1.12.4", "1.11.2"],
            availableVersions: ["1.12.4", "1.12", "1.11.2", "1.11"])
    }

    func updateCompatibleGameVersions(instanceId: String?, versions: [String]) async throws -> CompatibleGameVersionsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(versions, ["1.12.4", "1.11"])
        return CompatibleGameVersionsResult(
            instanceId: "primary",
            game: "KSP",
            actualGameVersion: "1.12.5",
            gameVersionWhenWritten: "1.12.5",
            compatibleVersionsAreFromDifferentGameVersion: false,
            compatibleVersions: versions,
            knownVersions: ["1.12.5", "1.12.4", "1.11.2"],
            availableVersions: ["1.12.4", "1.12", "1.11.2", "1.11"])
    }

    func stabilityTolerance(instanceId: String?) async throws -> StabilityToleranceResult {
        XCTAssertEqual(instanceId, "primary")
        return StabilityToleranceResult(
            instanceId: "primary",
            game: "KSP",
            overallStabilityTolerance: "testing",
            availableStabilityTolerances: ["stable", "testing", "development"],
            moduleStabilityTolerances: [
                ModuleStabilityTolerance(identifier: "ModuleManager", stabilityTolerance: "stable"),
                ModuleStabilityTolerance(identifier: "UnstableAddon", stabilityTolerance: "development"),
            ])
    }

    func updateStabilityTolerance(instanceId: String?, stabilityTolerance: String) async throws -> StabilityToleranceResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(stabilityTolerance, "development")
        return StabilityToleranceResult(
            instanceId: "primary",
            game: "KSP",
            overallStabilityTolerance: stabilityTolerance,
            availableStabilityTolerances: ["stable", "testing", "development"],
            moduleStabilityTolerances: [])
    }

    func updateModuleStabilityTolerance(
        instanceId: String?,
        identifier: String,
        stabilityTolerance: String?
    ) async throws -> StabilityToleranceResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(identifier, "ModuleManager")
        XCTAssertTrue(stabilityTolerance == "testing" || stabilityTolerance == nil)
        return StabilityToleranceResult(
            instanceId: "primary",
            game: "KSP",
            overallStabilityTolerance: "testing",
            availableStabilityTolerances: ["stable", "testing", "development"],
            moduleStabilityTolerances: stabilityTolerance.map {
                [ModuleStabilityTolerance(identifier: identifier, stabilityTolerance: $0)]
            } ?? [])
    }

    func preferredHosts(instanceId: String?) async throws -> PreferredHostsResult {
        XCTAssertEqual(instanceId, "primary")
        return PreferredHostsResult(
            instanceId: "primary",
            availableHosts: ["github.com", "spacedock.info", "archive.org"],
            preferredHosts: ["github.com", nil, "spacedock.info"],
            placeholderLabel: "<ALL OTHER HOSTS>")
    }

    func updatePreferredHosts(instanceId: String?, preferredHosts: [String?]) async throws -> PreferredHostsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(preferredHosts, ["github.com", nil, "spacedock.info"])
        return PreferredHostsResult(
            instanceId: "primary",
            availableHosts: ["github.com", "spacedock.info", "archive.org"],
            preferredHosts: preferredHosts,
            placeholderLabel: "<ALL OTHER HOSTS>")
    }

    func installFilters(instanceId: String?) async throws -> InstallFiltersResult {
        XCTAssertEqual(instanceId, "primary")
        return InstallFiltersResult(
            instanceId: "primary",
            game: "KSP",
            globalFilters: ["Ships", "MiniAVC.dll"],
            instanceFilters: ["GameData/TestMod/Extras"],
            presets: [
                InstallFilterPreset(name: "MiniAVC", filters: ["MiniAVC.dll", "MiniAVC.xml"]),
                InstallFilterPreset(name: "Craft files", filters: ["Ships", "SPH", "VAB"]),
            ])
    }

    func updateInstallFilters(
        instanceId: String?,
        globalFilters: [String],
        instanceFilters: [String]
    ) async throws -> InstallFiltersResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(globalFilters, ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(instanceFilters, ["GameData/TestMod/Extras"])
        return InstallFiltersResult(
            instanceId: "primary",
            game: "KSP",
            globalFilters: globalFilters,
            instanceFilters: instanceFilters,
            presets: [
                InstallFilterPreset(name: "MiniAVC", filters: ["MiniAVC.dll", "MiniAVC.xml"]),
            ])
    }

    func authTokens() async throws -> AuthTokensResult {
        AuthTokensResult(authTokens: [
            AuthTokenSummary(host: "api.github.com", tokenPreview: "********7890"),
            AuthTokenSummary(host: "github.com", tokenPreview: "********cdef"),
        ])
    }

    func addAuthToken(host: String, token: String) async throws -> AuthTokensResult {
        XCTAssertEqual(host, "github.com")
        XCTAssertEqual(token, "abcdef")
        return AuthTokensResult(authTokens: [
            AuthTokenSummary(host: host, tokenPreview: "********cdef"),
        ])
    }

    func removeAuthToken(host: String) async throws -> AuthTokensResult {
        XCTAssertEqual(host, "github.com")
        return AuthTokensResult(authTokens: [])
    }

    func clearCache() async throws -> CachePurgeResult {
        CachePurgeResult(
            mode: "all",
            purgedFileCount: 7,
            purgedBytes: 4096,
            purgedDisplay: "4 KiB",
            cache: CacheInfoResult(
                path: "/Users/test/Library/Caches/CKAN/downloads",
                fileCount: 0,
                bytes: 0,
                display: "0 bytes",
                freeBytes: 8192,
                freeDisplay: "8 KiB",
                limitBytes: 2048,
                limitDisplay: "2 KiB",
                isOverLimit: false))
    }

    func purgeCacheToLimit(instanceId: String?) async throws -> CachePurgeResult {
        XCTAssertEqual(instanceId, "primary")
        return CachePurgeResult(
            mode: "limit",
            purgedFileCount: 2,
            purgedBytes: 2048,
            purgedDisplay: "2 KiB",
            cache: CacheInfoResult(
                path: "/Users/test/Library/Caches/CKAN/downloads",
                fileCount: 5,
                bytes: 2048,
                display: "2 KiB",
                freeBytes: nil,
                freeDisplay: nil,
                limitBytes: 2048,
                limitDisplay: "2 KiB",
                isOverLimit: false))
    }

    func deduplicate() async throws -> DeduplicateResult {
        DeduplicateResult(
            status: "completed",
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Scanning for duplicate installed files...",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
                OperationEvent(
                    kind: "progress",
                    message: "Deduplicated 2 copies of GameData/Example/model.mu",
                    percent: 100,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)
    }

    func repairRegistry(instanceId: String?) async throws -> RepairRegistryResult {
        XCTAssertEqual(instanceId, "primary")
        return RepairRegistryResult(
            instanceId: instanceId,
            status: "completed",
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Repairing CKAN registry...",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
                OperationEvent(
                    kind: "message",
                    message: "Registry repairs attempted. Hope it helped.",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil),
            ],
            error: nil)
    }

    func removeRegistryLock(instanceId: String?) async throws -> RegistryLockRemovalResult {
        XCTAssertEqual(instanceId, "primary")
        return RegistryLockRemovalResult(
            instanceId: instanceId,
            lockfilePath: "/Games/KSP/CKAN/registry.locked",
            status: "removed",
            removed: true)
    }

    func operationStatus(operationId: String) async throws -> OperationResult {
        XCTAssertEqual(operationId, "op-1")
        return OperationResult(
            operationId: operationId,
            instanceId: "primary",
            status: "completed",
            changes: [],
            events: operationStatusEvents ?? [
                OperationEvent(
                    kind: "progress",
                    message: "Done after status refresh",
                    percent: 100,
                    identifier: nil,
                    remainingBytes: 0,
                    totalBytes: 2048),
            ],
            error: nil)
    }

    func launchOptions(instanceId: String?) async throws -> LaunchOptionsResult {
        let instanceId = instanceId ?? "primary"
        return LaunchOptionsResult(
            instanceId: instanceId,
            commandLines: instanceId == "secondary"
                ? ["./KSP-Secondary.app/Contents/MacOS/KSP"]
                : ["./KSP.app/Contents/MacOS/KSP", "steam://run/220200"],
            defaultCommandLines: instanceId == "secondary"
                ? ["./KSP-Secondary.app/Contents/MacOS/KSP"]
                : ["./KSP.app/Contents/MacOS/KSP"],
            incompatibleModules: instanceId == "primary" ? incompatibleLaunchModules : [])
    }

    func updateLaunchOptions(instanceId: String?, commandLines: [String]) async throws -> LaunchOptionsResult {
        XCTAssertEqual(instanceId, "primary")
        XCTAssertTrue(commandLines == ["./KSP.app/Contents/MacOS/KSP -popupwindow"]
            || commandLines == ["./KSP.app/Contents/MacOS/KSP"])
        return LaunchOptionsResult(
            instanceId: instanceId,
            commandLines: commandLines,
            defaultCommandLines: ["./KSP.app/Contents/MacOS/KSP"])
    }

    func launchGame(
        instanceId: String?,
        commandLine: String?,
        suppressIncompatibleWarnings: Bool
    ) async throws -> LaunchGameResult {
        if let launchGameError {
            throw launchGameError
        }
        XCTAssertEqual(instanceId, "primary")
        XCTAssertEqual(commandLine, "./KSP.app/Contents/MacOS/KSP")
        if !incompatibleLaunchModules.isEmpty {
            XCTAssertTrue(suppressIncompatibleWarnings)
        }
        return LaunchGameResult(
            instanceId: instanceId,
            commandLine: commandLine!,
            status: "started",
            processId: 12345)
    }

    private func summary(for instanceId: String) -> ModuleSummary {
        if instanceId == "Fake KSP" {
            return ModuleSummary(
                identifier: "FakeOnlyMod",
                name: "Fake Only Mod",
                author: "Example",
                status: .available,
                installedVersion: "-",
                latestVersion: "1.0.0",
                license: "MIT",
                relationships: [],
                versions: ["1.0.0"],
                contents: ["GameData/FakeOnlyMod"])
        }

        if instanceId == "Cloned KSP" {
            return ModuleSummary(
                identifier: "ClonedOnlyMod",
                name: "Cloned Only Mod",
                author: "Example",
                status: .installed,
                installedVersion: "1.0.0",
                latestVersion: "1.0.0",
                license: "MIT",
                relationships: [],
                versions: ["1.0.0"],
                contents: ["GameData/ClonedOnlyMod"])
        }

        if instanceId == "New KSP" {
            return ModuleSummary(
                identifier: "NewOnlyMod",
                name: "New Only Mod",
                author: "Example",
                status: .installed,
                installedVersion: "1.0.0",
                latestVersion: "1.0.0",
                license: "MIT",
                relationships: [],
                versions: ["1.0.0"],
                contents: ["GameData/NewOnlyMod"])
        }

        if instanceId == "renamed" {
            return ModuleSummary(
                identifier: "RenamedOnlyMod",
                name: "Renamed Only Mod",
                author: "Example",
                status: .installed,
                installedVersion: "3.0.0",
                latestVersion: "3.0.0",
                license: "MIT",
                relationships: [],
                versions: ["3.0.0"],
                contents: ["GameData/RenamedOnlyMod"])
        }

        if instanceId == "secondary" {
            return ModuleSummary(
                identifier: "SecondaryOnlyMod",
                name: "Secondary Only Mod",
                author: "Example",
                status: .installed,
                installedVersion: "2.0.0",
                latestVersion: "2.0.0",
                license: "MIT",
                relationships: [],
                versions: ["2.0.0"],
                contents: ["GameData/SecondaryOnlyMod"])
        }

        return ModuleSummary(
            identifier: "SidecarOnlyMod",
            name: "Sidecar Only Mod",
            author: "Example",
            status: .available,
            installedVersion: "-",
            latestVersion: "1.0.0",
            license: "MIT",
            relationships: [],
            versions: ["1.0.0"],
            contents: ["GameData/SidecarOnlyMod"])
    }

    private func repository(
        name: String,
        url: String,
        priority: Int,
        isMirror: Bool = false
    ) -> RepositorySummary {
        RepositorySummary(
            name: name,
            url: url,
            priority: priority,
            isMirror: isMirror,
            comment: "")
    }
}

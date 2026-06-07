import XCTest

@testable import MACKANKit

final class SidecarClientTests: XCTestCase {
    func testCommandClientKeepsStdioProcessForMultipleRequests() async throws {
        let script = """
        count=0
        while IFS= read -r line; do
          count=$((count + 1))
          if [ "$count" -eq 1 ]; then
            printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{"status":"ok","protocolVersion":"1","ckanVersion":"v1.36.5-test"}}'
          else
            printf '%s\\n' '{"jsonrpc":"2.0","id":1,"result":{"defaultInstanceId":"primary","instances":[{"id":"primary","name":"Primary KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP","isDefault":true,"isValid":true,"isMaybeLocked":false}]}}'
          fi
        done
        """
        let command = SidecarClient.Command(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script]
        )
        let client = SidecarClient(command: command)

        let health = try await client.health()
        let instances = try await client.listInstances()

        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(instances.defaultInstanceId, "primary")
        XCTAssertEqual(instances.instances.map(\.id), ["primary"])
    }

    func testOperationApplyAndStatusUseSameTransport() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-42","instanceId":"primary","status":"completed","changes":[],"events":[],"error":null}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-42","instanceId":"primary","status":"completed","changes":[],"events":[{"kind":"message","message":"Still available","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let apply = try await client.applyChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: ["DeprecatedMod"]
        )
        let status = try await client.operationStatus(operationId: apply.operationId)
        let requests = await transport.capturedRequests()

        XCTAssertEqual(apply.operationId, "op-42")
        XCTAssertEqual(status.events.first?.message, "Still available")
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].contains(#""method":"operations.applyChanges""#))
        XCTAssertTrue(requests[0].contains(#""install":["ModuleManager"]"#))
        XCTAssertTrue(requests[0].contains(#""replace":["DeprecatedMod"]"#))
        XCTAssertTrue(requests[1].contains(#""method":"operations.status""#))
        XCTAssertTrue(requests[1].contains(#""operationId":"op-42""#))
    }

    func testApplyChangesIncludesSkipDownloadFailuresWhenSet() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-42","instanceId":"primary","status":"completed","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.applyChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: ["DeprecatedMod"],
            skipDownloadFailures: true)

        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.applyChanges""#))
        XCTAssertEqual(params["skipDownloadFailures"] as? Bool, true)
    }

    func testAppVersionUsesExpectedMethodAndDecodesRuntimeMetadata() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"appName":"MACKAN","serviceVersion":"1.36.5.26146","ckanVersion":"v1.36.5-test","protocolVersion":"1","dotnetVersion":"10.0.0","operatingSystem":"macOS 15.5","processArchitecture":"Arm64"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let version = try await client.version()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(version.appName, "MACKAN")
        XCTAssertEqual(version.serviceVersion, "1.36.5.26146")
        XCTAssertEqual(version.ckanVersion, "v1.36.5-test")
        XCTAssertEqual(version.protocolVersion, "1")
        XCTAssertEqual(version.dotnetVersion, "10.0.0")
        XCTAssertEqual(version.operatingSystem, "macOS 15.5")
        XCTAssertEqual(version.processArchitecture, "Arm64")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"app.version""#))
    }

    func testCheckForUpdatesUsesExpectedMethodAndDecodesStatus() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"status":"available","currentVersion":"v1.0.0-test","latestVersion":"v1.1.0","latestDisplayVersion":"v1.1.0 aka Mun","releaseNotes":"Stable release notes","source":"stable","useDevBuilds":false,"canAutoInstall":false,"installMessage":"Install the signed MACKAN DMG from the release page.","downloadUrls":["https://github.com/KSP-CKAN/CKAN/releases/download/v1.1.0/MACKAN.dmg"],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.checkForUpdates(useDevBuilds: false)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.status, "available")
        XCTAssertEqual(result.currentVersion, "v1.0.0-test")
        XCTAssertEqual(result.latestVersion, "v1.1.0")
        XCTAssertEqual(result.latestDisplayVersion, "v1.1.0 aka Mun")
        XCTAssertEqual(result.releaseNotes, "Stable release notes")
        XCTAssertEqual(result.source, "stable")
        XCTAssertFalse(result.useDevBuilds)
        XCTAssertFalse(result.canAutoInstall)
        XCTAssertTrue(result.installMessage.contains("signed MACKAN DMG"))
        XCTAssertEqual(result.downloadUrls, ["https://github.com/KSP-CKAN/CKAN/releases/download/v1.1.0/MACKAN.dmg"])
        XCTAssertNil(result.error)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"app.checkForUpdates""#))
        XCTAssertEqual(params["useDevBuilds"] as? Bool, false)
    }

    func testListRepositoriesUsesExpectedMethodAndDecodesCanonicalList() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""},{"name":"mirror","url":"https://example.invalid/mirror.tar.gz","priority":1,"isMirror":true,"comment":"fallback mirror"}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.listRepositories(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.repositories.map(\.name), ["default", "mirror"])
        XCTAssertEqual(result.repositories.first?.url, "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz")
        XCTAssertEqual(result.repositories.first?.priority, 0)
        XCTAssertFalse(result.repositories[0].isMirror)
        XCTAssertTrue(result.repositories[1].isMirror)
        XCTAssertEqual(result.repositories[1].comment, "fallback mirror")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"repositories.list""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testListAvailableRepositoriesUsesExpectedMethodAndDecodesCanonicalList() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","repositories":[{"name":"stable","url":"https://example.invalid/stable.tar.gz","priority":0,"isMirror":false,"comment":"canonical stable"}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.listAvailableRepositories(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.repositories.map(\.name), ["stable"])
        XCTAssertEqual(result.repositories[0].url, "https://example.invalid/stable.tar.gz")
        XCTAssertEqual(result.repositories[0].priority, 0)
        XCTAssertFalse(result.repositories[0].isMirror)
        XCTAssertEqual(result.repositories[0].comment, "canonical stable")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"repositories.available""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testRepositoryMutationMethodsUseExpectedMethodsAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""},{"name":"newrepo","url":"https://example.invalid/newrepo.tar.gz","priority":1,"isMirror":false,"comment":""}]}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","repositories":[{"name":"newrepo","url":"https://example.invalid/newrepo.tar.gz","priority":0,"isMirror":false,"comment":""}]}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","repositories":[{"name":"newrepo","url":"https://example.invalid/newrepo.tar.gz","priority":0,"isMirror":false,"comment":""},{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":1,"isMirror":false,"comment":""}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let added = try await client.addRepository(
            instanceId: "primary",
            name: "newrepo",
            url: "https://example.invalid/newrepo.tar.gz")
        let removed = try await client.removeRepository(instanceId: "primary", name: "default")
        let reordered = try await client.setRepositoryPriority(instanceId: "primary", name: "newrepo", priority: 0)
        let requests = await transport.capturedRequests()
        let addParams = try requestParams(from: requests[0])
        let removeParams = try requestParams(from: requests[1])
        let reorderParams = try requestParams(from: requests[2])

        XCTAssertEqual(added.repositories.map(\.name), ["default", "newrepo"])
        XCTAssertEqual(removed.repositories.map(\.name), ["newrepo"])
        XCTAssertEqual(reordered.repositories.map(\.name), ["newrepo", "default"])
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests[0].contains(#""method":"repositories.add""#))
        XCTAssertEqual(addParams["instanceId"] as? String, "primary")
        XCTAssertEqual(addParams["name"] as? String, "newrepo")
        XCTAssertEqual(addParams["url"] as? String, "https://example.invalid/newrepo.tar.gz")
        XCTAssertTrue(requests[1].contains(#""method":"repositories.remove""#))
        XCTAssertEqual(removeParams["instanceId"] as? String, "primary")
        XCTAssertEqual(removeParams["name"] as? String, "default")
        XCTAssertTrue(requests[2].contains(#""method":"repositories.setPriority""#))
        XCTAssertEqual(reorderParams["instanceId"] as? String, "primary")
        XCTAssertEqual(reorderParams["name"] as? String, "newrepo")
        XCTAssertEqual(reorderParams["priority"] as? Int, 0)
    }

    func testStartRepositoryRefreshStatusAndCancelUseExpectedMethodsAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"repo-op-1","operationStatus":"running","instanceId":"primary","status":"running","compatibleModuleCount":0,"repositories":[],"events":[{"kind":"message","message":"Repository refresh queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}]}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"repo-op-1","operationStatus":"completed","instanceId":"primary","status":"updated","compatibleModuleCount":42,"repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""}],"events":[{"kind":"progress","message":"Done","percent":100,"identifier":null,"remainingBytes":0,"totalBytes":4096}]}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"repo-op-1","operationStatus":"cancelling","instanceId":"primary","status":"running","compatibleModuleCount":0,"repositories":[],"events":[{"kind":"message","message":"Cancellation requested","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let started = try await client.startRefreshRepositories(instanceId: "primary", force: true)
        let status = try await client.repositoryRefreshStatus(operationId: started.operationId!)
        let cancelled = try await client.cancelRepositoryRefresh(operationId: started.operationId!)
        let requests = await transport.capturedRequests()
        let startParams = try requestParams(from: requests[0])

        XCTAssertEqual(started.operationStatus, "running")
        XCTAssertEqual(started.events.first?.message, "Repository refresh queued")
        XCTAssertEqual(status.operationStatus, "completed")
        XCTAssertEqual(status.status, "updated")
        XCTAssertEqual(status.compatibleModuleCount, 42)
        XCTAssertEqual(cancelled.operationStatus, "cancelling")
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests[0].contains(#""method":"repositories.startRefresh""#))
        XCTAssertEqual(startParams["instanceId"] as? String, "primary")
        XCTAssertEqual(startParams["force"] as? Bool, true)
        XCTAssertTrue(requests[1].contains(#""method":"repositories.refreshStatus""#))
        XCTAssertTrue(requests[1].contains(#""operationId":"repo-op-1""#))
        XCTAssertTrue(requests[2].contains(#""method":"repositories.cancelRefresh""#))
        XCTAssertTrue(requests[2].contains(#""operationId":"repo-op-1""#))
    }

    func testSynchronousRepositoryRefreshUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"repo-op-1","operationStatus":"completed","instanceId":"primary","status":"updated","compatibleModuleCount":42,"repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""}],"events":[{"kind":"progress","message":"Done","percent":100,"identifier":null,"remainingBytes":0,"totalBytes":4096}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.refreshRepositories(instanceId: "primary", force: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.operationStatus, "completed")
        XCTAssertEqual(result.status, "updated")
        XCTAssertEqual(result.compatibleModuleCount, 42)
        XCTAssertEqual(result.repositories.map(\.name), ["default"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"repositories.refresh""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["force"] as? Bool, true)
    }

    func testStartModuleListStatusAndCancelUseExpectedMethodsAndProgressCounts() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"module-op-1","instanceId":"primary","status":"running","modules":[],"events":[{"kind":"progress","message":"Preparing 100 of 350 mods","percent":40,"identifier":"ModuleManager","remainingBytes":null,"totalBytes":null,"completedCount":100,"totalCount":350}],"error":null}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"module-op-1","instanceId":"primary","status":"completed","modules":[{"identifier":"ModuleManager","name":"Module Manager","author":"sarbian","status":"installed","installedVersion":"4.2.3","latestVersion":"4.2.3","license":"CC-BY-SA","relationships":[],"versions":["4.2.3"],"contents":[],"isInstalled":true,"isCompatible":true,"isCached":false,"isNew":false,"hasUpdate":false,"hasReplacement":false,"tags":[],"abstract":"","description":"","localizations":[],"gameCompatibility":"1.12.5","downloadSize":0,"downloadSizeDisplay":"","installSize":0,"installSizeDisplay":"","releaseDate":"","installDate":"","downloadCount":null,"isAutoInstalled":false,"isAutodetected":false}],"events":[{"kind":"progress","message":"Loaded 1 mods","percent":100,"identifier":null,"remainingBytes":null,"totalBytes":null,"completedCount":1,"totalCount":1}],"error":null}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"module-op-1","instanceId":"primary","status":"cancelled","modules":[],"events":[],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let started = try await client.startListModules(instanceId: "primary")
        let status = try await client.moduleListStatus(operationId: started.operationId)
        let cancelled = try await client.cancelModuleList(operationId: started.operationId)
        let requests = await transport.capturedRequests()

        XCTAssertEqual(started.status, "running")
        XCTAssertEqual(started.events.first?.completedCount, 100)
        XCTAssertEqual(started.events.first?.totalCount, 350)
        XCTAssertEqual(status.status, "completed")
        XCTAssertEqual(status.modules.map(\.identifier), ["ModuleManager"])
        XCTAssertEqual(cancelled.status, "cancelled")
        XCTAssertTrue(requests[0].contains(#""method":"mods.startList""#))
        XCTAssertTrue(requests[1].contains(#""method":"mods.listStatus""#))
        XCTAssertTrue(requests[2].contains(#""method":"mods.cancelList""#))
    }

    func testStartApplyChangesAndCancelUseExpectedMethodsAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-running","instanceId":"primary","status":"cancelling","changes":[],"events":[{"kind":"message","message":"Cancellation requested","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let started = try await client.startApplyChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: ["DeprecatedMod"])
        let cancelled = try await client.cancelOperation(operationId: started.operationId)
        let requests = await transport.capturedRequests()

        XCTAssertEqual(started.status, "running")
        XCTAssertEqual(cancelled.status, "cancelling")
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startApplyChanges""#))
        XCTAssertTrue(requests[0].contains(#""install":["ModuleManager"]"#))
        XCTAssertTrue(requests[0].contains(#""replace":["DeprecatedMod"]"#))
        XCTAssertTrue(requests[1].contains(#""method":"operations.cancel""#))
        XCTAssertTrue(requests[1].contains(#""operationId":"op-running""#))
    }

    func testStartApplyChangesIncludesSkipDownloadFailuresWhenSet() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.startApplyChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: ["DeprecatedMod"],
            skipDownloadFailures: true)

        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startApplyChanges""#))
        XCTAssertEqual(params["skipDownloadFailures"] as? Bool, true)
    }

    func testStartApplyChangesSendsProviderSelections() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.startApplyChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: [],
            providerSelections: [
                ProviderSelection(
                    requested: "VirtualDependency",
                    requesterIdentifier: "ModuleManager",
                    selectedIdentifier: "ProviderA"),
            ])

        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])
        let selections = try XCTUnwrap(params["providerSelections"] as? [[String: Any]])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startApplyChanges""#))
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0]["requested"] as? String, "VirtualDependency")
        XCTAssertEqual(selections[0]["requesterIdentifier"] as? String, "ModuleManager")
        XCTAssertEqual(selections[0]["selectedIdentifier"] as? String, "ProviderA")
    }

    func testInstallCkanFilesUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-file","instanceId":"primary","status":"completed","changes":[{"identifier":"ModuleManager","name":"Module Manager","action":"install","fromVersion":null,"toVersion":"4.2.3","reasons":["User requested"],"isUserRequested":true,"isAuto":false}],"events":[],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.installCkanFiles(
            instanceId: "primary",
            filePaths: ["/Downloads/ModuleManager.ckan", "/Downloads/Other.ckan"],
            providerSelections: [
                ProviderSelection(
                    requested: "VirtualDependency",
                    requesterIdentifier: "ModuleManager",
                    selectedIdentifier: "ProviderA"),
            ],
            recommendationSelections: ["RecommendedMod"],
            skipRecommendations: true,
            allowIncompatibleCkanFiles: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.operationId, "op-file")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.installCkanFiles""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["filePaths"] as? [String], ["/Downloads/ModuleManager.ckan", "/Downloads/Other.ckan"])
        let selections = try XCTUnwrap(params["providerSelections"] as? [[String: Any]])
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0]["requested"] as? String, "VirtualDependency")
        XCTAssertEqual(selections[0]["requesterIdentifier"] as? String, "ModuleManager")
        XCTAssertEqual(selections[0]["selectedIdentifier"] as? String, "ProviderA")
        XCTAssertEqual(params["recommendationSelections"] as? [String], ["RecommendedMod"])
        XCTAssertEqual(params["skipRecommendations"] as? Bool, true)
        XCTAssertEqual(params["allowIncompatibleCkanFiles"] as? Bool, true)
    }

    func testStartInstallCkanFilesUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-file-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.startInstallCkanFiles(
            instanceId: "primary",
            filePaths: ["/Downloads/ModuleManager.ckan", "/Downloads/Other.ckan"],
            providerSelections: [
                ProviderSelection(
                    requested: "VirtualDependency",
                    requesterIdentifier: "ModuleManager",
                    selectedIdentifier: "ProviderA"),
            ],
            recommendationSelections: ["RecommendedMod"],
            skipRecommendations: true,
            allowIncompatibleCkanFiles: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.operationId, "op-file-running")
        XCTAssertEqual(result.status, "running")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startInstallCkanFiles""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["filePaths"] as? [String], ["/Downloads/ModuleManager.ckan", "/Downloads/Other.ckan"])
        let selections = try XCTUnwrap(params["providerSelections"] as? [[String: Any]])
        XCTAssertEqual(selections[0]["selectedIdentifier"] as? String, "ProviderA")
        XCTAssertEqual(params["recommendationSelections"] as? [String], ["RecommendedMod"])
        XCTAssertEqual(params["skipRecommendations"] as? Bool, true)
        XCTAssertEqual(params["allowIncompatibleCkanFiles"] as? Bool, true)
    }

    func testStartInstallCkanFilesIncludesSkipDownloadFailuresWhenSet() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-file-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.startInstallCkanFiles(
            instanceId: "primary",
            filePaths: ["/Downloads/ModuleManager.ckan"],
            skipDownloadFailures: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startInstallCkanFiles""#))
        XCTAssertEqual(params["skipDownloadFailures"] as? Bool, true)
    }

    func testImportDownloadsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-import","instanceId":"primary","status":"completed","changes":[{"identifier":"DogeCoinPlugin","name":"Dogecoin Core Plugin","action":"install","fromVersion":null,"toVersion":"1.01","reasons":["Imported download"],"isUserRequested":true,"isAuto":false}],"events":[],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.importDownloads(
            instanceId: "primary",
            paths: ["/Downloads/DogeCoinPlugin.zip", "/Downloads/Other.zip"],
            installImportedModules: true,
            deleteImportedFiles: false,
            previewBeforeInstall: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.operationId, "op-import")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.importDownloads""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["paths"] as? [String], ["/Downloads/DogeCoinPlugin.zip", "/Downloads/Other.zip"])
        XCTAssertEqual(params["installImportedModules"] as? Bool, true)
        XCTAssertEqual(params["deleteImportedFiles"] as? Bool, false)
        XCTAssertEqual(params["previewBeforeInstall"] as? Bool, true)
    }

    func testStartImportDownloadsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-import-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.startImportDownloads(
            instanceId: "primary",
            paths: ["/Downloads/DogeCoinPlugin.zip", "/Downloads/Other.zip"],
            installImportedModules: true,
            deleteImportedFiles: false,
            previewBeforeInstall: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.operationId, "op-import-running")
        XCTAssertEqual(result.status, "running")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startImportDownloads""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["paths"] as? [String], ["/Downloads/DogeCoinPlugin.zip", "/Downloads/Other.zip"])
        XCTAssertEqual(params["installImportedModules"] as? Bool, true)
        XCTAssertEqual(params["deleteImportedFiles"] as? Bool, false)
        XCTAssertEqual(params["previewBeforeInstall"] as? Bool, true)
    }

    func testStartImportDownloadsIncludesSkipDownloadFailuresWhenSet() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"operationId":"op-import-running","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"message","message":"Operation queued","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.startImportDownloads(
            instanceId: "primary",
            paths: ["/Downloads/DogeCoinPlugin.zip"],
            installImportedModules: true,
            deleteImportedFiles: false,
            skipDownloadFailures: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"operations.startImportDownloads""#))
        XCTAssertEqual(params["skipDownloadFailures"] as? Bool, true)
    }

    func testExportModListUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","format":"markdown","suggestedFileName":"Primary KSP-mods.md","contentType":"text/markdown","contents":"- **Module Manager** `ModuleManager 4.2.3`"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.exportModList(instanceId: "primary", format: .markdown)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.format, .markdown)
        XCTAssertEqual(result.suggestedFileName, "Primary KSP-mods.md")
        XCTAssertEqual(result.contentType, "text/markdown")
        XCTAssertTrue(result.contents.contains("Module Manager"))
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"exports.modList""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["format"] as? String, "markdown")
    }

    func testExportModpackUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","identifier":"MyModpack","suggestedFileName":"MyModpack.ckan","contentType":"application/json","contents":"{\"identifier\":\"MyModpack\",\"depends\":[{\"name\":\"ModuleManager\"}]}"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.exportModpack(
            instanceId: "primary",
            draft: ModpackExportDraft(
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
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.identifier, "MyModpack")
        XCTAssertEqual(result.suggestedFileName, "MyModpack.ckan")
        XCTAssertEqual(result.contentType, "application/json")
        XCTAssertTrue(result.contents.contains("ModuleManager"))
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"exports.modpack""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["identifier"] as? String, "MyModpack")
        XCTAssertEqual(params["name"] as? String, "My Modpack")
        XCTAssertEqual(params["abstract"] as? String, "Essential mods")
        XCTAssertEqual(params["author"] as? String, "Jeb Kerman")
        XCTAssertEqual(params["version"] as? String, "v1")
        XCTAssertEqual(params["license"] as? String, "MIT")
        XCTAssertEqual(params["gameVersionMin"] as? String, "1.12")
        XCTAssertEqual(params["gameVersionMax"] as? String, "1.12.5")
        XCTAssertEqual(params["includeVersions"] as? Bool, false)
        XCTAssertEqual(params["includeOptionalRelationships"] as? Bool, false)
        let assignments = try XCTUnwrap(params["relationshipAssignments"] as? [[String: Any]])
        XCTAssertEqual(assignments.count, 3)
        XCTAssertEqual(assignments[0]["identifier"] as? String, "ModuleManager")
        XCTAssertEqual(assignments[0]["kind"] as? String, "depends")
        XCTAssertEqual(assignments[1]["identifier"] as? String, "Scatterer")
        XCTAssertEqual(assignments[1]["kind"] as? String, "recommends")
        XCTAssertEqual(assignments[2]["identifier"] as? String, "UnusedVisualPack")
        XCTAssertEqual(assignments[2]["kind"] as? String, "ignore")
    }

    func testScanGameDataUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","changed":true,"detectedDllCount":2,"detectedDlcCount":1}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.scanGameData(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.detectedDllCount, 2)
        XCTAssertEqual(result.detectedDlcCount, 1)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.scan""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testListUnmanagedFilesUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","changed":true,"files":[{"identifier":"ManualPlugin","kind":"dll","version":null,"path":"GameData/Manual/ManualPlugin.dll"},{"identifier":"MakingHistory-DLC","kind":"dlc","version":"1.12.1 (unmanaged)","path":null}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.listUnmanagedFiles(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.files.map(\.identifier), ["ManualPlugin", "MakingHistory-DLC"])
        XCTAssertEqual(result.files[0].kind, "dll")
        XCTAssertEqual(result.files[0].path, "GameData/Manual/ManualPlugin.dll")
        XCTAssertEqual(result.files[1].kind, "dlc")
        XCTAssertEqual(result.files[1].version, "1.12.1 (unmanaged)")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.unmanagedFiles""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testListInstallationHistoryUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","entries":[{"fileName":"installed-Primary_KSP-2026-05-31_10-00-00.ckan","savedAt":"2026-05-31T10:00:00.0000000Z","modules":[{"identifier":"ModuleManager","name":"Module Manager","version":"4.2.3","author":"sarbian","abstract":"Core patch manager","isInstalled":false,"isAvailable":true}]}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.listInstallationHistory(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].fileName, "installed-Primary_KSP-2026-05-31_10-00-00.ckan")
        XCTAssertEqual(result.entries[0].savedAt, "2026-05-31T10:00:00.0000000Z")
        XCTAssertEqual(result.entries[0].modules.map(\.identifier), ["ModuleManager"])
        XCTAssertEqual(result.entries[0].modules[0].version, "4.2.3")
        XCTAssertEqual(result.entries[0].modules[0].author, "sarbian")
        XCTAssertEqual(result.entries[0].modules[0].abstract, "Core patch manager")
        XCTAssertFalse(result.entries[0].modules[0].isInstalled)
        XCTAssertTrue(result.entries[0].modules[0].isAvailable)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.history""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testListPlayTimeUsesExpectedMethod() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"entries":[{"instanceId":"primary","name":"Primary KSP","path":"/Games/KSP","hours":12.5,"display":"12.5"},{"instanceId":"secondary","name":"Secondary KSP","path":"/Games/KSP-Secondary","hours":0,"display":"0.0"}],"totalHours":12.5,"totalDisplay":"12.5"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.listPlayTime()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.totalHours, 12.5)
        XCTAssertEqual(result.totalDisplay, "12.5")
        XCTAssertEqual(result.entries.map(\.instanceId), ["primary", "secondary"])
        XCTAssertEqual(result.entries[0].name, "Primary KSP")
        XCTAssertEqual(result.entries[0].path, "/Games/KSP")
        XCTAssertEqual(result.entries[0].hours, 12.5)
        XCTAssertEqual(result.entries[0].display, "12.5")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.playTime""#))
        XCTAssertFalse(requests[0].contains(#""params""#))
    }

    func testUpdatePlayTimeUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"entries":[{"instanceId":"primary","name":"Primary KSP","path":"/Games/KSP","hours":14.25,"display":"14.3"}],"totalHours":14.25,"totalDisplay":"14.3"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updatePlayTime(instanceId: "primary", hours: 14.25)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.totalHours, 14.25)
        XCTAssertEqual(result.entries.map(\.instanceId), ["primary"])
        XCTAssertEqual(result.entries[0].hours, 14.25)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.updatePlayTime""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["hours"] as? Double, 14.25)
    }

    func testDownloadStatisticsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","hosts":[{"host":"spacedock.info","bytes":1536,"display":"1.5 KiB"},{"host":"archive.org","bytes":512,"display":"512 bytes"}],"totalBytes":2048,"totalDisplay":"2 KiB"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.downloadStatistics(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.totalBytes, 2048)
        XCTAssertEqual(result.totalDisplay, "2 KiB")
        XCTAssertEqual(result.hosts.map(\.host), ["spacedock.info", "archive.org"])
        XCTAssertEqual(result.hosts[0].bytes, 1536)
        XCTAssertEqual(result.hosts[0].display, "1.5 KiB")
        XCTAssertEqual(result.hosts[1].bytes, 512)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.downloadStatistics""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testCacheInfoUsesExpectedMethod() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"path":"/Users/test/Library/Caches/CKAN/downloads","fileCount":7,"bytes":4096,"display":"4 KiB","freeBytes":8192,"freeDisplay":"8 KiB","limitBytes":2048,"limitDisplay":"2 KiB","isOverLimit":true}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.cacheInfo()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.path, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(result.fileCount, 7)
        XCTAssertEqual(result.bytes, 4096)
        XCTAssertEqual(result.display, "4 KiB")
        XCTAssertEqual(result.freeBytes, 8192)
        XCTAssertEqual(result.freeDisplay, "8 KiB")
        XCTAssertEqual(result.limitBytes, 2048)
        XCTAssertEqual(result.limitDisplay, "2 KiB")
        XCTAssertTrue(result.isOverLimit)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.cacheInfo""#))
    }

    func testSettingsGetUsesExpectedMethod() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"downloadCacheDir":"/Users/test/Library/Caches/CKAN/downloads","defaultDownloadCacheDir":"/Users/test/Library/Caches/CKAN/downloads","isDefaultDownloadCacheDir":true,"cacheSizeLimitBytes":1073741824,"cacheSizeLimitDisplay":"1 GiB"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.getSettings()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.downloadCacheDir, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(result.defaultDownloadCacheDir, "/Users/test/Library/Caches/CKAN/downloads")
        XCTAssertEqual(result.isDefaultDownloadCacheDir, true)
        XCTAssertEqual(result.cacheSizeLimitBytes, 1_073_741_824)
        XCTAssertEqual(result.cacheSizeLimitDisplay, "1 GiB")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.get""#))
    }

    func testSettingsUpdateUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"downloadCacheDir":"/Users/test/CKANCache","defaultDownloadCacheDir":"/Users/test/Library/Caches/CKAN/downloads","isDefaultDownloadCacheDir":false,"cacheSizeLimitBytes":null,"cacheSizeLimitDisplay":"Unlimited"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateSettings(
            downloadCacheDir: "/Users/test/CKANCache",
            cacheSizeLimitBytes: nil,
            cacheMigrationChoice: .delete)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.downloadCacheDir, "/Users/test/CKANCache")
        XCTAssertEqual(result.isDefaultDownloadCacheDir, false)
        XCTAssertNil(result.cacheSizeLimitBytes)
        XCTAssertEqual(result.cacheSizeLimitDisplay, "Unlimited")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.update""#))
        XCTAssertEqual(params["downloadCacheDir"] as? String, "/Users/test/CKANCache")
        XCTAssertEqual(params["cacheSizeLimitBytes"] as? Int, -1)
        XCTAssertEqual(params["cacheMigrationChoice"] as? String, "delete")
    }

    func testGeneralSettingsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","checkForUpdatesOnLaunch":true,"useDevBuilds":false,"refreshRepositoriesOnLaunch":true,"autoSortByUpdate":true}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.generalSettings(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertTrue(result.checkForUpdatesOnLaunch)
        XCTAssertFalse(result.useDevBuilds)
        XCTAssertTrue(result.refreshRepositoriesOnLaunch)
        XCTAssertTrue(result.autoSortByUpdate)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.general""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testUpdateGeneralSettingsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","checkForUpdatesOnLaunch":false,"useDevBuilds":true,"refreshRepositoriesOnLaunch":false,"autoSortByUpdate":false}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateGeneralSettings(
            instanceId: "primary",
            checkForUpdatesOnLaunch: false,
            useDevBuilds: true,
            refreshRepositoriesOnLaunch: false,
            autoSortByUpdate: false)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertFalse(result.checkForUpdatesOnLaunch)
        XCTAssertTrue(result.useDevBuilds)
        XCTAssertFalse(result.refreshRepositoriesOnLaunch)
        XCTAssertFalse(result.autoSortByUpdate)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updateGeneral""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["checkForUpdatesOnLaunch"] as? Bool, false)
        XCTAssertEqual(params["useDevBuilds"] as? Bool, true)
        XCTAssertEqual(params["refreshRepositoriesOnLaunch"] as? Bool, false)
        XCTAssertEqual(params["autoSortByUpdate"] as? Bool, false)
    }

    func testCompatibleGameVersionsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","actualGameVersion":"1.12.5","gameVersionWhenWritten":"1.12.4","compatibleVersionsAreFromDifferentGameVersion":true,"compatibleVersions":["1.12.4","1.11.2"],"knownVersions":["1.12.5","1.12.4","1.11.2"],"availableVersions":["1.12.4","1.12","1.11.2","1.11"]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.compatibleGameVersions(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.game, "KSP")
        XCTAssertEqual(result.actualGameVersion, "1.12.5")
        XCTAssertEqual(result.gameVersionWhenWritten, "1.12.4")
        XCTAssertTrue(result.compatibleVersionsAreFromDifferentGameVersion)
        XCTAssertEqual(result.compatibleVersions, ["1.12.4", "1.11.2"])
        XCTAssertEqual(result.knownVersions, ["1.12.5", "1.12.4", "1.11.2"])
        XCTAssertEqual(result.availableVersions, ["1.12.4", "1.12", "1.11.2", "1.11"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.compatibleVersions""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testUpdateCompatibleGameVersionsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","actualGameVersion":"1.12.5","gameVersionWhenWritten":"1.12.5","compatibleVersionsAreFromDifferentGameVersion":false,"compatibleVersions":["1.12.4","1.11"],"knownVersions":["1.12.5","1.12.4","1.11.2"],"availableVersions":["1.12.4","1.12","1.11.2","1.11"]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateCompatibleGameVersions(
            instanceId: "primary",
            versions: ["1.12.4", "1.11"])
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.compatibleVersions, ["1.12.4", "1.11"])
        XCTAssertFalse(result.compatibleVersionsAreFromDifferentGameVersion)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updateCompatibleVersions""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["versions"] as? [String], ["1.12.4", "1.11"])
    }

    func testStabilityToleranceUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","overallStabilityTolerance":"testing","availableStabilityTolerances":["stable","testing","development"],"moduleStabilityTolerances":[{"identifier":"ModuleManager","stabilityTolerance":"stable"},{"identifier":"UnstableAddon","stabilityTolerance":"development"}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.stabilityTolerance(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.game, "KSP")
        XCTAssertEqual(result.overallStabilityTolerance, "testing")
        XCTAssertEqual(result.availableStabilityTolerances, ["stable", "testing", "development"])
        XCTAssertEqual(result.moduleStabilityTolerances.map(\.identifier), ["ModuleManager", "UnstableAddon"])
        XCTAssertEqual(result.moduleStabilityTolerances.map(\.stabilityTolerance), ["stable", "development"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.stabilityTolerance""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testUpdateStabilityToleranceUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","overallStabilityTolerance":"development","availableStabilityTolerances":["stable","testing","development"],"moduleStabilityTolerances":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateStabilityTolerance(
            instanceId: "primary",
            stabilityTolerance: "development")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.overallStabilityTolerance, "development")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updateStabilityTolerance""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["stabilityTolerance"] as? String, "development")
    }

    func testUpdateModuleStabilityToleranceUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","overallStabilityTolerance":"testing","availableStabilityTolerances":["stable","testing","development"],"moduleStabilityTolerances":[{"identifier":"ModuleManager","stabilityTolerance":"testing"}]}}"#,
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","overallStabilityTolerance":"testing","availableStabilityTolerances":["stable","testing","development"],"moduleStabilityTolerances":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.updateModuleStabilityTolerance(
            instanceId: "primary",
            identifier: "ModuleManager",
            stabilityTolerance: "testing")
        _ = try await client.updateModuleStabilityTolerance(
            instanceId: "primary",
            identifier: "ModuleManager",
            stabilityTolerance: nil)
        let requests = await transport.capturedRequests()
        let updateParams = try requestParams(from: requests[0])
        let clearParams = try requestParams(from: requests[1])

        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updateModuleStabilityTolerance""#))
        XCTAssertEqual(updateParams["instanceId"] as? String, "primary")
        XCTAssertEqual(updateParams["identifier"] as? String, "ModuleManager")
        XCTAssertEqual(updateParams["stabilityTolerance"] as? String, "testing")
        XCTAssertEqual(clearParams["instanceId"] as? String, "primary")
        XCTAssertEqual(clearParams["identifier"] as? String, "ModuleManager")
        XCTAssertNil(clearParams["stabilityTolerance"])
    }

    func testPreferredHostsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","availableHosts":["github.com","spacedock.info","archive.org"],"preferredHosts":["github.com",null,"spacedock.info"],"placeholderLabel":"<ALL OTHER HOSTS>"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.preferredHosts(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.availableHosts, ["github.com", "spacedock.info", "archive.org"])
        XCTAssertEqual(result.preferredHosts, ["github.com", nil, "spacedock.info"])
        XCTAssertEqual(result.placeholderLabel, "<ALL OTHER HOSTS>")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.preferredHosts""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testUpdatePreferredHostsUsesExpectedMethodAndNullableParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","availableHosts":["github.com","spacedock.info","archive.org"],"preferredHosts":["github.com",null,"spacedock.info"],"placeholderLabel":"<ALL OTHER HOSTS>"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updatePreferredHosts(
            instanceId: "primary",
            preferredHosts: ["github.com", nil, "spacedock.info"])
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])
        let preferredHosts = try XCTUnwrap(params["preferredHosts"] as? [Any])

        XCTAssertEqual(result.preferredHosts, ["github.com", nil, "spacedock.info"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updatePreferredHosts""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(preferredHosts.count, 3)
        XCTAssertEqual(preferredHosts[0] as? String, "github.com")
        XCTAssertTrue(preferredHosts[1] is NSNull)
        XCTAssertEqual(preferredHosts[2] as? String, "spacedock.info")
    }

    func testInstallFiltersUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","globalFilters":["Ships","MiniAVC.dll"],"instanceFilters":["GameData/TestMod/Extras"],"presets":[{"name":"MiniAVC","filters":["MiniAVC.dll","MiniAVC.xml"]},{"name":"Craft files","filters":["Ships","SPH","VAB"]}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.installFilters(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.game, "KSP")
        XCTAssertEqual(result.globalFilters, ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(result.instanceFilters, ["GameData/TestMod/Extras"])
        XCTAssertEqual(result.presets.map(\.name), ["MiniAVC", "Craft files"])
        XCTAssertEqual(result.presets[1].filters, ["Ships", "SPH", "VAB"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.installFilters""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testUpdateInstallFiltersUsesExpectedMethodAndArrays() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","game":"KSP","globalFilters":["Ships","MiniAVC.dll"],"instanceFilters":["GameData/TestMod/Extras"],"presets":[{"name":"MiniAVC","filters":["MiniAVC.dll","MiniAVC.xml"]}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateInstallFilters(
            instanceId: "primary",
            globalFilters: ["Ships", "MiniAVC.dll"],
            instanceFilters: ["GameData/TestMod/Extras"])
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.globalFilters, ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(result.instanceFilters, ["GameData/TestMod/Extras"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.updateInstallFilters""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["globalFilters"] as? [String], ["Ships", "MiniAVC.dll"])
        XCTAssertEqual(params["instanceFilters"] as? [String], ["GameData/TestMod/Extras"])
    }

    func testAuthTokensUsesExpectedMethodAndDoesNotDecodeRawToken() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"authTokens":[{"host":"api.github.com","tokenPreview":"********7890"},{"host":"github.com","tokenPreview":"********cdef"}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.authTokens()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.authTokens.map(\.host), ["api.github.com", "github.com"])
        XCTAssertEqual(result.authTokens.map(\.tokenPreview), ["********7890", "********cdef"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"settings.authTokens""#))
    }

    func testAddAndRemoveAuthTokenUseExpectedMethodsAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"authTokens":[{"host":"github.com","tokenPreview":"********cdef"}]}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"authTokens":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let addResult = try await client.addAuthToken(host: "github.com", token: "abcdef")
        let removeResult = try await client.removeAuthToken(host: "github.com")
        let requests = await transport.capturedRequests()
        let addParams = try requestParams(from: requests[0])
        let removeParams = try requestParams(from: requests[1])

        XCTAssertEqual(addResult.authTokens.map(\.host), ["github.com"])
        XCTAssertTrue(removeResult.authTokens.isEmpty)
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].contains(#""method":"settings.addAuthToken""#))
        XCTAssertEqual(addParams["host"] as? String, "github.com")
        XCTAssertEqual(addParams["token"] as? String, "abcdef")
        XCTAssertTrue(requests[1].contains(#""method":"settings.removeAuthToken""#))
        XCTAssertEqual(removeParams["host"] as? String, "github.com")
    }

    func testClearCacheUsesExpectedMethod() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"mode":"all","purgedFileCount":7,"purgedBytes":4096,"purgedDisplay":"4 KiB","cache":{"path":"/Users/test/Library/Caches/CKAN/downloads","fileCount":0,"bytes":0,"display":"0 bytes","freeBytes":8192,"freeDisplay":"8 KiB","limitBytes":null,"limitDisplay":null,"isOverLimit":false}}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.clearCache()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.mode, "all")
        XCTAssertEqual(result.purgedFileCount, 7)
        XCTAssertEqual(result.purgedBytes, 4096)
        XCTAssertEqual(result.purgedDisplay, "4 KiB")
        XCTAssertEqual(result.cache.fileCount, 0)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.clearCache""#))
    }

    func testPurgeCacheToLimitUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"mode":"limit","purgedFileCount":2,"purgedBytes":2048,"purgedDisplay":"2 KiB","cache":{"path":"/Users/test/Library/Caches/CKAN/downloads","fileCount":5,"bytes":2048,"display":"2 KiB","freeBytes":null,"freeDisplay":null,"limitBytes":2048,"limitDisplay":"2 KiB","isOverLimit":false}}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.purgeCacheToLimit(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.mode, "limit")
        XCTAssertEqual(result.purgedFileCount, 2)
        XCTAssertEqual(result.cache.isOverLimit, false)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.purgeCacheToLimit""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testDeduplicateUsesExpectedMethod() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"status":"completed","events":[{"kind":"message","message":"Scanning for duplicate installed files...","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null},{"kind":"progress","message":"Deduplicated 2 copies of GameData/Example/model.mu","percent":100,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.deduplicate()
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].kind, "message")
        XCTAssertEqual(result.events[1].percent, 100)
        XCTAssertNil(result.error)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.deduplicate""#))
    }

    func testRepairRegistryUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","status":"completed","events":[{"kind":"message","message":"Repairing CKAN registry...","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null},{"kind":"message","message":"Registry repairs attempted. Hope it helped.","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":null}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.repairRegistry(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(result.events.count, 2)
        XCTAssertEqual(result.events[0].message, "Repairing CKAN registry...")
        XCTAssertEqual(result.events[1].message, "Registry repairs attempted. Hope it helped.")
        XCTAssertNil(result.error)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.repairRegistry""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testRemoveRegistryLockUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","lockfilePath":"/Games/KSP/CKAN/registry.locked","status":"removed","removed":true}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.removeRegistryLock(instanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.lockfilePath, "/Games/KSP/CKAN/registry.locked")
        XCTAssertEqual(result.status, "removed")
        XCTAssertTrue(result.removed)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"maintenance.removeRegistryLock""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
    }

    func testInstanceRenameUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"defaultInstanceId":"primary","instances":[{"id":"primary","name":"Primary KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP","isDefault":true,"isValid":true,"isMaybeLocked":false},{"id":"renamed","name":"Renamed KSP","game":"KSP","gameVersion":"1.11.2","path":"/Games/KSP-Secondary","isDefault":false,"isValid":true,"isMaybeLocked":false}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.renameInstance("secondary", to: "renamed")
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.instances.map(\.id), ["primary", "renamed"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.rename""#))
        XCTAssertTrue(requests[0].contains(#""instanceId":"secondary""#))
        XCTAssertTrue(requests[0].contains(#""newName":"renamed""#))
    }

    func testInstanceAddUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"defaultInstanceId":"New KSP","instances":[{"id":"New KSP","name":"New KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP-New","isDefault":true,"isValid":true,"isMaybeLocked":false}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.addInstance(path: "/Games/KSP-New", name: "New KSP")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.defaultInstanceId, "New KSP")
        XCTAssertEqual(result.instances.map(\.id), ["New KSP"])
        XCTAssertEqual(result.instances[0].path, "/Games/KSP-New")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.add""#))
        XCTAssertEqual(params["path"] as? String, "/Games/KSP-New")
        XCTAssertEqual(params["name"] as? String, "New KSP")
    }

    func testInstanceCloneUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"defaultInstanceId":"Cloned KSP","instances":[{"id":"primary","name":"Primary KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP","isDefault":false,"isValid":true,"isMaybeLocked":false},{"id":"Cloned KSP","name":"Cloned KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP-Clone","isDefault":true,"isValid":true,"isMaybeLocked":false}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.cloneInstance(
            sourceInstanceId: "primary",
            newName: "Cloned KSP",
            newPath: "/Games/KSP-Clone",
            shareStock: false,
            leaveEmptyPaths: ["saves", "Screenshots"])
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.defaultInstanceId, "Cloned KSP")
        XCTAssertEqual(result.instances.map(\.id), ["primary", "Cloned KSP"])
        XCTAssertEqual(result.instances[1].path, "/Games/KSP-Clone")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.clone""#))
        XCTAssertEqual(params["sourceInstanceId"] as? String, "primary")
        XCTAssertEqual(params["newName"] as? String, "Cloned KSP")
        XCTAssertEqual(params["newPath"] as? String, "/Games/KSP-Clone")
        XCTAssertEqual(params["shareStock"] as? Bool, false)
        XCTAssertEqual(params["leaveEmptyPaths"] as? [String], ["saves", "Screenshots"])
    }

    func testInstanceCloneOptionsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"sourceInstanceId":"primary","leaveEmptyPaths":["saves","Screenshots","CKAN/downloads"]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.cloneOptions(sourceInstanceId: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.sourceInstanceId, "primary")
        XCTAssertEqual(result.leaveEmptyPaths, ["saves", "Screenshots", "CKAN/downloads"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.cloneOptions""#))
        XCTAssertEqual(params["sourceInstanceId"] as? String, "primary")
    }

    func testInstanceFakeUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"defaultInstanceId":"Fake KSP","instances":[{"id":"Fake KSP","name":"Fake KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP-Fake","isDefault":true,"isValid":true,"isMaybeLocked":false}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.fakeInstance(
            name: "Fake KSP",
            path: "/Games/KSP-Fake",
            version: "1.12.5",
            gameId: "KSP",
            makingHistoryVersion: "1.12.1",
            breakingGroundVersion: "1.7.1",
            setDefault: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.defaultInstanceId, "Fake KSP")
        XCTAssertEqual(result.instances.map(\.id), ["Fake KSP"])
        XCTAssertEqual(result.instances[0].game, "KSP")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.fake""#))
        XCTAssertEqual(params["name"] as? String, "Fake KSP")
        XCTAssertEqual(params["path"] as? String, "/Games/KSP-Fake")
        XCTAssertEqual(params["version"] as? String, "1.12.5")
        XCTAssertEqual(params["gameId"] as? String, "KSP")
        XCTAssertEqual(params["makingHistoryVersion"] as? String, "1.12.1")
        XCTAssertEqual(params["breakingGroundVersion"] as? String, "1.7.1")
        XCTAssertEqual(params["setDefault"] as? Bool, true)
    }

    func testLaunchOptionsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","commandLines":["./KSP.app/Contents/MacOS/KSP","steam://run/220200"],"defaultCommandLines":["./KSP.app/Contents/MacOS/KSP"],"incompatibleModules":[{"identifier":"OldMod","name":"Old Mod","version":"0.9.0","compatibleGameVersions":"KSP 1.8"}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.launchOptions(instanceId: "primary")
        let requests = await transport.capturedRequests()

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.commandLines, ["./KSP.app/Contents/MacOS/KSP", "steam://run/220200"])
        XCTAssertEqual(result.defaultCommandLines, ["./KSP.app/Contents/MacOS/KSP"])
        XCTAssertEqual(result.incompatibleModules.map(\.identifier), ["OldMod"])
        XCTAssertEqual(result.incompatibleModules.first?.compatibleGameVersions, "KSP 1.8")
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.launchOptions""#))
        XCTAssertTrue(requests[0].contains(#""instanceId":"primary""#))
    }

    func testUpdateLaunchOptionsUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","commandLines":["./KSP.app/Contents/MacOS/KSP -popupwindow"],"defaultCommandLines":["./KSP.app/Contents/MacOS/KSP"]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.updateLaunchOptions(
            instanceId: "primary",
            commandLines: ["./KSP.app/Contents/MacOS/KSP -popupwindow"])
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.commandLines, ["./KSP.app/Contents/MacOS/KSP -popupwindow"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.updateLaunchOptions""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["commandLines"] as? [String], ["./KSP.app/Contents/MacOS/KSP -popupwindow"])
    }

    func testLaunchGameUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","commandLine":"./KSP.app/Contents/MacOS/KSP -popupwindow","status":"started","processId":12345}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.launchGame(
            instanceId: "primary",
            commandLine: "./KSP.app/Contents/MacOS/KSP -popupwindow")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.commandLine, "./KSP.app/Contents/MacOS/KSP -popupwindow")
        XCTAssertEqual(result.status, "started")
        XCTAssertEqual(result.processId, 12345)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"instances.launch""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["commandLine"] as? String, "./KSP.app/Contents/MacOS/KSP -popupwindow")
        XCTAssertEqual(params["suppressIncompatibleWarnings"] as? Bool, false)
    }

    func testLaunchGameCanSuppressIncompatibleWarnings() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","commandLine":"./KSP.app/Contents/MacOS/KSP -popupwindow","status":"started"}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.launchGame(
            instanceId: "primary",
            commandLine: "./KSP.app/Contents/MacOS/KSP -popupwindow",
            suppressIncompatibleWarnings: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(params["suppressIncompatibleWarnings"] as? Bool, true)
    }

    func testDefaultCommandPrefersBundledSidecarExecutable() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let serviceDirectory = tempRoot
            .appendingPathComponent("MACKAN.Service", isDirectory: true)
        let executableURL = serviceDirectory.appendingPathComponent("MACKAN.Service")

        try FileManager.default.createDirectory(
            at: serviceDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: executableURL.path, contents: Data())

        let command = SidecarClient.defaultCommand(
            environment: [:],
            bundleResourceURL: tempRoot,
            currentDirectoryPath: "/not/a/repo"
        )

        XCTAssertEqual(command?.executableURL.path, executableURL.path)
        XCTAssertEqual(command?.arguments, ["--stdio"])
        XCTAssertEqual(command?.workingDirectory?.path, serviceDirectory.path)
    }

    func testDefaultCommandPrefersArchitectureSpecificBundledSidecarExecutable() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let serviceRoot = tempRoot
            .appendingPathComponent("MACKAN.Service", isDirectory: true)
#if arch(arm64)
        let runtimeIdentifier = "osx-arm64"
#elseif arch(x86_64)
        let runtimeIdentifier = "osx-x64"
#else
        let runtimeIdentifier = "osx-unknown"
#endif
        let serviceDirectory = serviceRoot.appendingPathComponent(runtimeIdentifier, isDirectory: true)
        let executableURL = serviceDirectory.appendingPathComponent("MACKAN.Service")

        try FileManager.default.createDirectory(
            at: serviceDirectory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: executableURL.path, contents: Data())

        let command = SidecarClient.defaultCommand(
            environment: [:],
            bundleResourceURL: tempRoot,
            currentDirectoryPath: "/not/a/repo"
        )

        XCTAssertEqual(command?.executableURL.path, executableURL.path)
        XCTAssertEqual(command?.arguments, ["--stdio"])
        XCTAssertEqual(command?.workingDirectory?.path, serviceDirectory.path)
    }

    func testDecodesHealthResponseFromCleanJsonLine() throws {
        let health = try SidecarClient.decodeHealthResponse(
            from: #"{"jsonrpc":"2.0","id":1,"result":{"status":"ok","protocolVersion":"1","ckanVersion":"v1.36.5"}}"#
        )

        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.protocolVersion, "1")
        XCTAssertEqual(health.ckanVersion, "v1.36.5")
    }

    func testDecodesHealthResponseAfterBuildWarnings() throws {
        let health = try SidecarClient.decodeHealthResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":1,"result":{"status":"ok","protocolVersion":"1","ckanVersion":"v1.36.5.26146"}}
        """)

        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.protocolVersion, "1")
        XCTAssertEqual(health.ckanVersion, "v1.36.5.26146")
    }

    func testThrowsRPCError() {
        XCTAssertThrowsError(try SidecarClient.decodeHealthResponse(
            from: #"{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}"#
        )) { error in
            XCTAssertEqual(error as? SidecarClientError, .rpcError(code: -32601, message: "Method not found"))
        }
    }

    func testThrowsTypedRegistryLockRPCError() {
        XCTAssertThrowsError(try SidecarClient.decodeHealthResponse(
            from: #"{"jsonrpc":"2.0","id":1,"error":{"code":-32010,"message":"Registry is locked","data":{"kind":"registryLock","lockfilePath":"/Games/KSP/CKAN/registry.locked","suggestedAction":"waitRetry"}}}"#
        )) { error in
            XCTAssertEqual(
                error as? SidecarClientError,
                .registryLocked(message: "Registry is locked", lockfilePath: "/Games/KSP/CKAN/registry.locked"))
        }
    }

    func testThrowsTypedLaunchFailureRPCError() {
        XCTAssertThrowsError(try SidecarClient.decodeLaunchGameResponse(
            from: #"{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"Failed to launch game with command 'missing-ksp-launch-binary'.","data":{"kind":"launchFailure","command":"missing-ksp-launch-binary","lockfilePath":null,"suggestedAction":"retryOrCheckCommand"}}}"#
        )) { error in
            XCTAssertEqual(
                error as? SidecarClientError,
                .launchFailure(
                    message: "Failed to launch game with command 'missing-ksp-launch-binary'.",
                    command: "missing-ksp-launch-binary",
                    suggestedAction: "retryOrCheckCommand"))
        }
    }

    func testThrowsStructuredOperationRPCError() {
        XCTAssertThrowsError(try SidecarClient.decodeHealthResponse(
            from: #"{"jsonrpc":"2.0","id":1,"error":{"code":-32020,"message":"Downloads failed","data":{"kind":"downloadFailures","lockfilePath":null,"suggestedAction":"skipOrAbort","downloadFailures":[{"identifier":"ModuleManager","name":"Module Manager","version":"4.2.3","message":"Host returned 500","urls":["https://example.invalid/ModuleManager.zip"]}]}}}"#
        )) { error in
            guard let typedError = error as? SidecarClientError else {
                XCTFail("Expected SidecarClientError")
                return
            }
            guard case let .operationError(message: message, details: details) = typedError else {
                XCTFail("Expected operationError with details")
                return
            }
            XCTAssertEqual(message, "Downloads failed")
            XCTAssertEqual(details.kind, "downloadFailures")
            XCTAssertEqual(details.downloadFailures?.count, 1)
            XCTAssertEqual(details.downloadFailures?.first?.identifier, "ModuleManager")
            XCTAssertEqual(details.suggestedAction, "skipOrAbort")
        }
    }

    func testDecodesInstancesResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeInstancesResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":2,"result":{"defaultInstanceId":"primary","instances":[{"id":"primary","name":"Primary KSP","game":"KSP","gameVersion":"1.12.5","path":"/Games/KSP","isDefault":true,"isValid":true,"isMaybeLocked":false},{"id":"test","name":"Test KSP","game":"KSP","gameVersion":"1.11.2","path":"/Games/KSP-Test","isDefault":false,"isValid":false,"isMaybeLocked":true}]}}
        """)

        XCTAssertEqual(result.defaultInstanceId, "primary")
        XCTAssertEqual(result.instances.map(\.id), ["primary", "test"])
        XCTAssertEqual(result.instances[0].name, "Primary KSP")
        XCTAssertEqual(result.instances[0].game, "KSP")
        XCTAssertEqual(result.instances[0].gameVersion, "1.12.5")
        XCTAssertEqual(result.instances[0].path, "/Games/KSP")
        XCTAssertTrue(result.instances[0].isDefault)
        XCTAssertTrue(result.instances[0].isValid)
        XCTAssertFalse(result.instances[0].isMaybeLocked)
        XCTAssertFalse(result.instances[1].isDefault)
        XCTAssertFalse(result.instances[1].isValid)
        XCTAssertTrue(result.instances[1].isMaybeLocked)
    }

    func testDecodesModulesResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeModulesResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":3,"result":{"instanceId":"primary","modules":[{"identifier":"ModuleManager","name":"Module Manager","author":"sarbian","status":"installed","installedVersion":"4.2.3","latestVersion":"4.2.3","license":"CC-BY-SA","relationships":[{"kind":"Depends","value":"Kerbal Space Program"}],"versions":["4.2.3","4.2.2"],"contents":["GameData/ModuleManager.4.2.3.dll"],"isInstalled":true,"isCompatible":true,"isCached":true,"isNew":false,"hasUpdate":false,"hasReplacement":false,"tags":["plugin","library"],"abstract":"Shared plugin loader","description":"Loads ModuleManager patches for KSP.","localizations":["en-us","ru"],"gameCompatibility":"1.12.5","downloadSize":1024,"downloadSizeDisplay":"1 KiB","installSize":2048,"installSizeDisplay":"2 KiB","releaseDate":"2024-01-02T03:04:05.0000000Z","installDate":"2024-02-03T04:05:06.0000000Z","downloadCount":123456,"isAutoInstalled":true,"isAutodetected":false},{"identifier":"Scatterer","name":"Scatterer","author":"blackrack","status":"upgradable","installedVersion":"0.0838","latestVersion":"0.0878","license":"GPL-3.0","relationships":[{"kind":"Recommends","value":"EnvironmentalVisualEnhancements"}],"versions":["0.0878","0.0838"],"contents":["GameData/scatterer"],"isInstalled":true,"isCompatible":true,"isCached":false,"isNew":true,"hasUpdate":true,"hasReplacement":true,"tags":["visual"]}]}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.modules.map(\.identifier), ["ModuleManager", "Scatterer"])
        XCTAssertEqual(result.modules[0].name, "Module Manager")
        XCTAssertEqual(result.modules[0].author, "sarbian")
        XCTAssertEqual(result.modules[0].status, .installed)
        XCTAssertEqual(result.modules[0].installedVersion, "4.2.3")
        XCTAssertEqual(result.modules[0].latestVersion, "4.2.3")
        XCTAssertEqual(result.modules[0].license, "CC-BY-SA")
        XCTAssertEqual(result.modules[0].relationships.first?.kind, "Depends")
        XCTAssertEqual(result.modules[0].relationships.first?.value, "Kerbal Space Program")
        XCTAssertEqual(result.modules[0].versions, ["4.2.3", "4.2.2"])
        XCTAssertEqual(result.modules[0].contents, ["GameData/ModuleManager.4.2.3.dll"])
        XCTAssertTrue(result.modules[0].isInstalled)
        XCTAssertTrue(result.modules[0].isCompatible)
        XCTAssertTrue(result.modules[0].isCached)
        XCTAssertFalse(result.modules[0].isNew)
        XCTAssertFalse(result.modules[0].hasUpdate)
        XCTAssertFalse(result.modules[0].hasReplacement)
        XCTAssertEqual(result.modules[0].tags, ["plugin", "library"])
        XCTAssertEqual(result.modules[0].abstract, "Shared plugin loader")
        XCTAssertEqual(result.modules[0].description, "Loads ModuleManager patches for KSP.")
        XCTAssertEqual(result.modules[0].localizations, ["en-us", "ru"])
        XCTAssertEqual(result.modules[0].gameCompatibility, "1.12.5")
        XCTAssertEqual(result.modules[0].downloadSize, 1024)
        XCTAssertEqual(result.modules[0].downloadSizeDisplay, "1 KiB")
        XCTAssertEqual(result.modules[0].installSize, 2048)
        XCTAssertEqual(result.modules[0].installSizeDisplay, "2 KiB")
        XCTAssertEqual(result.modules[0].releaseDate, "2024-01-02T03:04:05.0000000Z")
        XCTAssertEqual(result.modules[0].installDate, "2024-02-03T04:05:06.0000000Z")
        XCTAssertEqual(result.modules[0].downloadCount, 123456)
        XCTAssertTrue(result.modules[0].isAutoInstalled)
        XCTAssertFalse(result.modules[0].isAutodetected)
        XCTAssertEqual(result.modules[1].status, .upgradable)
        XCTAssertTrue(result.modules[1].isInstalled)
        XCTAssertTrue(result.modules[1].isCompatible)
        XCTAssertFalse(result.modules[1].isCached)
        XCTAssertTrue(result.modules[1].isNew)
        XCTAssertTrue(result.modules[1].hasUpdate)
        XCTAssertTrue(result.modules[1].hasReplacement)
        XCTAssertEqual(result.modules[1].tags, ["visual"])
    }

    func testDecodesLabelsResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeLabelsResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":44,"result":{"instanceId":"primary","labels":[{"name":"Favourites","instanceName":null,"colorHex":"#98FB98","hide":false,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["ModuleManager"]},{"name":"Hidden","instanceName":"primary","colorHex":"#DB7093","hide":true,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["Scatterer"]}]}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.labels.map(\.name), ["Favourites", "Hidden"])
        XCTAssertNil(result.labels[0].instanceName)
        XCTAssertEqual(result.labels[0].colorHex, "#98FB98")
        XCTAssertFalse(result.labels[0].hide)
        XCTAssertFalse(result.labels[0].holdVersion)
        XCTAssertFalse(result.labels[0].ignoreMissingFiles)
        XCTAssertEqual(result.labels[0].identifiers, ["ModuleManager"])
        XCTAssertEqual(result.labels[1].instanceName, "primary")
        XCTAssertTrue(result.labels[1].hide)
        XCTAssertEqual(result.manageableLabels, result.labels)
    }

    func testDecodesLabelsResponseWithManageableLabelsAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeLabelsResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":44,"result":{"instanceId":"primary","labels":[{"name":"Global","instanceName":null,"colorHex":"#98FB98","hide":false,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["ModuleManager"]}],"manageableLabels":[{"name":"Global","instanceName":null,"colorHex":"#98FB98","hide":false,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["ModuleManager"]},{"name":"Secondary Only","instanceName":"secondary","colorHex":"#DB7093","hide":true,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["Scatterer"]}]}}
        """)

        XCTAssertEqual(result.labels.map(\.name), ["Global"])
        XCTAssertEqual(result.manageableLabels.map(\.name), ["Global", "Secondary Only"])
        XCTAssertEqual(result.manageableLabels[1].instanceName, "secondary")
    }

    func testToggleModuleLabelUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            ##"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","labels":[{"name":"Favourites","instanceName":null,"colorHex":"#98FB98","hide":false,"holdVersion":false,"ignoreMissingFiles":false,"identifiers":["ModuleManager","Scatterer"]}]}}"##,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.toggleModuleLabel(
            instanceId: "primary",
            labelName: "Favourites",
            identifier: "Scatterer")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.labels.first?.identifiers, ["ModuleManager", "Scatterer"])
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"labels.toggleModule""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["labelName"] as? String, "Favourites")
        XCTAssertEqual(params["identifier"] as? String, "Scatterer")
    }

    func testUpsertModuleLabelUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            ##"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","labels":[{"name":"Watch","instanceName":"primary","colorHex":"#336699","hide":true,"notifyOnChange":true,"removeOnChange":false,"alertOnInstall":true,"removeOnInstall":false,"holdVersion":true,"ignoreMissingFiles":true,"identifiers":["ModuleManager"]}]}}"##,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.upsertModuleLabel(
            instanceId: "primary",
            originalName: "Old Watch",
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
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])
        let label = params["label"] as? [String: Any]

        XCTAssertEqual(result.labels.first?.name, "Watch")
        XCTAssertEqual(result.labels.first?.notifyOnChange, true)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"labels.upsert""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["originalName"] as? String, "Old Watch")
        XCTAssertNil(params["originalInstanceName"] as? String)
        XCTAssertEqual(label?["name"] as? String, "Watch")
        XCTAssertEqual(label?["instanceName"] as? String, "primary")
        XCTAssertEqual(label?["colorHex"] as? String, "#336699")
        XCTAssertEqual(label?["hide"] as? Bool, true)
        XCTAssertEqual(label?["notifyOnChange"] as? Bool, true)
        XCTAssertEqual(label?["alertOnInstall"] as? Bool, true)
        XCTAssertEqual(label?["holdVersion"] as? Bool, true)
        XCTAssertEqual(label?["ignoreMissingFiles"] as? Bool, true)
    }

    func testDeleteModuleLabelUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","labels":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.deleteModuleLabel(
            instanceId: "primary",
            name: "Watch",
            instanceName: "primary")
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertTrue(result.labels.isEmpty)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"labels.delete""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["name"] as? String, "Watch")
        XCTAssertEqual(params["instanceName"] as? String, "primary")
    }

    func testSetAutoInstalledUsesExpectedMethodAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","modules":[{"identifier":"ModuleManager","name":"Module Manager","author":"sarbian","status":"installed","installedVersion":"4.2.3","latestVersion":"4.2.3","license":"CC-BY-SA","relationships":[],"versions":["4.2.3"],"contents":["GameData/ModuleManager.4.2.3.dll"],"isInstalled":true,"isAutoInstalled":true}]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let result = try await client.setAutoInstalled(
            instanceId: "primary",
            identifier: "ModuleManager",
            isAutoInstalled: true)
        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])

        XCTAssertEqual(result.modules.first?.identifier, "ModuleManager")
        XCTAssertEqual(result.modules.first?.isAutoInstalled, true)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests[0].contains(#""method":"mods.setAutoInstalled""#))
        XCTAssertEqual(params["instanceId"] as? String, "primary")
        XCTAssertEqual(params["identifier"] as? String, "ModuleManager")
        XCTAssertEqual(params["isAutoInstalled"] as? Bool, true)
    }

    func testDecodesModuleDetailsResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeModuleDetailsResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":4,"result":{"instanceId":"primary","module":{"identifier":"ModuleManager","name":"Module Manager","author":"sarbian","status":"installed","installedVersion":"4.2.3","latestVersion":"4.2.3","license":"CC-BY-SA","relationships":[{"kind":"Depends","value":"Kerbal Space Program"}],"versions":["4.2.3","4.2.2"],"contents":["GameData/ModuleManager.4.2.3.dll"]},"abstract":"Shared plugin loader","description":"Loads ModuleManager patches for KSP.","releaseStatus":"stable","kind":"package","releaseDate":"2024-01-02T03:04:05.0000000Z","downloadSize":1024,"installSize":2048,"resources":[{"label":"Homepage","url":"https://example.invalid/mod"},{"label":"Repository","url":"https://example.invalid/repo"}],"tags":["plugin","library"]}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.module.identifier, "ModuleManager")
        XCTAssertEqual(result.abstract, "Shared plugin loader")
        XCTAssertEqual(result.description, "Loads ModuleManager patches for KSP.")
        XCTAssertEqual(result.releaseStatus, "stable")
        XCTAssertEqual(result.kind, "package")
        XCTAssertEqual(result.releaseDate, "2024-01-02T03:04:05.0000000Z")
        XCTAssertEqual(result.downloadSize, 1024)
        XCTAssertEqual(result.installSize, 2048)
        XCTAssertEqual(result.resources.map(\.label), ["Homepage", "Repository"])
        XCTAssertEqual(result.resources.map(\.url), ["https://example.invalid/mod", "https://example.invalid/repo"])
        XCTAssertEqual(result.tags, ["plugin", "library"])
    }

    func testDecodesRepositoriesResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeRepositoriesResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":5,"result":{"instanceId":"primary","repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""},{"name":"mirror","url":"https://example.invalid/mirror.tar.gz","priority":1,"isMirror":true,"comment":"fallback mirror"}]}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.repositories.map(\.name), ["default", "mirror"])
        XCTAssertEqual(result.repositories[0].url, "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz")
        XCTAssertEqual(result.repositories[0].priority, 0)
        XCTAssertFalse(result.repositories[0].isMirror)
        XCTAssertEqual(result.repositories[1].priority, 1)
        XCTAssertTrue(result.repositories[1].isMirror)
        XCTAssertEqual(result.repositories[1].comment, "fallback mirror")
    }

    func testDecodesRepositoryRefreshResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeRepositoryRefreshResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":6,"result":{"instanceId":"primary","status":"updated","compatibleModuleCount":42,"repositories":[{"name":"default","url":"https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz","priority":0,"isMirror":false,"comment":""}],"events":[{"kind":"message","message":"Updating repositories","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null},{"kind":"progress","message":"Done","percent":100,"identifier":null,"remainingBytes":0,"totalBytes":4096}]}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.status, "updated")
        XCTAssertEqual(result.compatibleModuleCount, 42)
        XCTAssertEqual(result.repositories.map(\.name), ["default"])
        XCTAssertEqual(result.events.map(\.kind), ["message", "progress"])
        XCTAssertEqual(result.events.last?.percent, 100)
        XCTAssertEqual(result.events.last?.totalBytes, 4096)
    }

    func testDecodesRepositoryRefreshFailureDetailsAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeRepositoryRefreshResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":6,"result":{"operationId":"repo-op-1","operationStatus":"failed","instanceId":"primary","status":"failed","compatibleModuleCount":0,"repositories":[{"name":"broken","url":"file:///tmp/missing-repository.tar.gz","priority":0,"isMirror":false,"comment":""}],"events":[{"kind":"message","message":"Updating repositories","percent":null,"identifier":null,"remainingBytes":null,"totalBytes":null}],"error":"Repository metadata download failed","errorDetails":{"kind":"downloadFailures","lockfilePath":null,"suggestedAction":"retryOrEditRepository","downloadFailures":[{"identifier":"broken","name":"broken","version":"metadata","message":"File not found","urls":["file:///tmp/missing-repository.tar.gz"]}]}}}
        """)

        XCTAssertEqual(result.operationId, "repo-op-1")
        XCTAssertEqual(result.operationStatus, "failed")
        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.error, "Repository metadata download failed")
        XCTAssertEqual(result.errorDetails?.kind, "downloadFailures")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "retryOrEditRepository")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.identifier, "broken")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.version, "metadata")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.urls, ["file:///tmp/missing-repository.tar.gz"])
    }

    func testDecodesChangeSetResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeChangeSetResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":7,"result":{"instanceId":"primary","changes":[{"identifier":"ModuleManager","name":"Module Manager","action":"install","fromVersion":null,"toVersion":"4.2.3","reasons":["User requested"],"isUserRequested":true,"isAuto":false},{"identifier":"Harmony2","name":"Harmony 2","action":"install","fromVersion":null,"toVersion":"2.2.1","reasons":["Dependency of ModuleManager"],"isUserRequested":false,"isAuto":true}],"conflicts":[{"identifier":"OldHarmony","name":"Old Harmony","description":"Conflicts with Harmony2"}],"conflictDescriptions":["OldHarmony conflicts with Harmony2"],"providerChoices":[{"requested":"VirtualDependency","message":"Choose a provider","requesterIdentifier":"ModuleManager","requesterName":"Module Manager","options":[{"identifier":"ProviderA","name":"Provider A","version":"1.0.0","abstract":"First provider"},{"identifier":"ProviderB","name":"Provider B","version":"2.0.0","abstract":"Second provider"}]}],"recommendationChoices":[{"kind":"recommendation","identifier":"RecommendedMod","name":"Recommended Mod","version":"1.2.3","abstract":"Useful companion","dependents":["ModuleManager"],"isRecommendedDefault":true}],"suppressRecommendations":true}}
        """)

        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.changes.map(\.identifier), ["ModuleManager", "Harmony2"])
        XCTAssertEqual(result.changes[0].action, "install")
        XCTAssertNil(result.changes[0].fromVersion)
        XCTAssertEqual(result.changes[0].toVersion, "4.2.3")
        XCTAssertTrue(result.changes[0].isUserRequested)
        XCTAssertTrue(result.changes[1].isAuto)
        XCTAssertEqual(result.conflicts.first?.identifier, "OldHarmony")
        XCTAssertEqual(result.conflictDescriptions, ["OldHarmony conflicts with Harmony2"])
        XCTAssertEqual(result.providerChoices.first?.requested, "VirtualDependency")
        XCTAssertEqual(result.providerChoices.first?.options.map(\.identifier), ["ProviderA", "ProviderB"])
        XCTAssertEqual(result.recommendationChoices.first?.kind, "recommendation")
        XCTAssertEqual(result.recommendationChoices.first?.identifier, "RecommendedMod")
        XCTAssertEqual(result.recommendationChoices.first?.dependents, ["ModuleManager"])
        XCTAssertEqual(result.recommendationChoices.first?.isRecommendedDefault, true)
        XCTAssertTrue(result.suppressRecommendations)
    }

    func testRecommendationSettingsUsesExpectedMethodsAndParams() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","suppressRecommendations":false}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"instanceId":"primary","suppressRecommendations":true}}"#,
        ])
        let client = SidecarClient(transport: transport)

        let current = try await client.recommendationSettings(instanceId: "primary")
        let updated = try await client.updateRecommendationSettings(
            instanceId: "primary",
            suppressRecommendations: true)
        let requests = await transport.capturedRequests()

        XCTAssertEqual(current.instanceId, "primary")
        XCTAssertFalse(current.suppressRecommendations)
        XCTAssertTrue(updated.suppressRecommendations)
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[0].contains(#""method":"settings.recommendations""#))
        XCTAssertTrue(requests[1].contains(#""method":"settings.updateRecommendations""#))
        XCTAssertEqual(try requestParams(from: requests[0])["instanceId"] as? String, "primary")
        let updateParams = try requestParams(from: requests[1])
        XCTAssertEqual(updateParams["instanceId"] as? String, "primary")
        XCTAssertEqual(updateParams["suppressRecommendations"] as? Bool, true)
    }

    func testResolveChangesSendsProviderSelections() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","changes":[],"conflicts":[],"conflictDescriptions":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.resolveChanges(
            instanceId: "primary",
            install: ["ModuleManager"],
            remove: [],
            upgrade: [],
            replace: [],
            providerSelections: [
                ProviderSelection(
                    requested: "VirtualDependency",
                    requesterIdentifier: "ModuleManager",
                    selectedIdentifier: "ProviderA"),
            ])

        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])
        let selections = try XCTUnwrap(params["providerSelections"] as? [[String: Any]])
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections[0]["requested"] as? String, "VirtualDependency")
        XCTAssertEqual(selections[0]["requesterIdentifier"] as? String, "ModuleManager")
        XCTAssertEqual(selections[0]["selectedIdentifier"] as? String, "ProviderA")
    }

    func testResolveChangesSendsExactInstallVersions() async throws {
        let transport = RecordingSidecarTransport(responses: [
            #"{"jsonrpc":"2.0","id":1,"result":{"instanceId":"primary","changes":[],"conflicts":[],"conflictDescriptions":[]}}"#,
        ])
        let client = SidecarClient(transport: transport)

        _ = try await client.resolveChanges(
            instanceId: "primary",
            install: [],
            remove: [],
            upgrade: [],
            replace: [],
            installVersions: [
                VersionedModuleSelection(identifier: "ModuleManager", version: "4.2.3"),
            ])

        let requests = await transport.capturedRequests()
        let params = try requestParams(from: requests[0])
        let installVersions = try XCTUnwrap(params["installVersions"] as? [[String: Any]])
        XCTAssertNil(params["install"])
        XCTAssertEqual(installVersions.count, 1)
        XCTAssertEqual(installVersions[0]["identifier"] as? String, "ModuleManager")
        XCTAssertEqual(installVersions[0]["version"] as? String, "4.2.3")
    }

    func testDecodesOperationResultResponseAfterBuildWarnings() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":8,"result":{"operationId":"op-1","instanceId":"primary","status":"completed","changes":[{"identifier":"ModuleManager","name":"Module Manager","action":"install","fromVersion":null,"toVersion":"4.2.3","reasons":["User requested"],"isUserRequested":true,"isAuto":false}],"events":[{"kind":"message","message":"Installing Module Manager","percent":null,"identifier":"ModuleManager","remainingBytes":null,"totalBytes":null},{"kind":"progress","message":"Done","percent":100,"identifier":null,"remainingBytes":0,"totalBytes":4096}],"error":null,"errorDetails":{"kind":"registryLock","lockfilePath":"/Games/KSP/CKAN/registry.locked","suggestedAction":"waitRetry"}}}
        """)

        XCTAssertEqual(result.operationId, "op-1")
        XCTAssertEqual(result.instanceId, "primary")
        XCTAssertEqual(result.status, "completed")
        XCTAssertEqual(result.changes.map(\.identifier), ["ModuleManager"])
        XCTAssertEqual(result.events.map(\.kind), ["message", "progress"])
        XCTAssertEqual(result.events.last?.percent, 100)
        XCTAssertEqual(result.events.last?.totalBytes, 4096)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.errorDetails?.kind, "registryLock")
        XCTAssertEqual(result.errorDetails?.lockfilePath, "/Games/KSP/CKAN/registry.locked")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "waitRetry")
    }

    func testDecodesOperationResultPerFileProgressEvents() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        {"jsonrpc":"2.0","id":8,"result":{"operationId":"op-progress","instanceId":"primary","status":"running","changes":[],"events":[{"kind":"downloadProgress","message":"Module Manager","percent":45,"identifier":"ModuleManager","remainingBytes":5632,"totalBytes":10240},{"kind":"storeProgress","message":"Module Manager","percent":90,"identifier":"ModuleManager","remainingBytes":1024,"totalBytes":10240},{"kind":"installProgress","message":"Module Manager","percent":100,"identifier":"ModuleManager","remainingBytes":0,"totalBytes":10240}],"error":null,"errorDetails":null}}
        """)

        XCTAssertEqual(result.operationId, "op-progress")
        XCTAssertEqual(result.events.map(\.kind), ["downloadProgress", "storeProgress", "installProgress"])
        XCTAssertEqual(result.events.map(\.identifier), ["ModuleManager", "ModuleManager", "ModuleManager"])
        XCTAssertEqual(result.events.map(\.percent), [45, 90, 100])
        XCTAssertEqual(result.events.first?.remainingBytes, 5632)
        XCTAssertEqual(result.events.last?.totalBytes, 10240)
    }

    func testOperationEventFormatsProgressDetailsForNativeTimeline() {
        let event = OperationEvent(
            kind: "downloadProgress",
            message: "Module Manager",
            percent: 45,
            identifier: "ModuleManager",
            remainingBytes: 5632,
            totalBytes: 10240)

        XCTAssertEqual(event.progressFraction, 0.45)
        XCTAssertEqual(event.byteProgressDisplay, "4.6 KB of 10.2 KB")
    }

    func testDecodesOperationResultDownloadFailureDetails() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":9,"result":{"operationId":"op-downloads","instanceId":"primary","status":"failed","changes":[],"events":[],"error":"Downloads failed","errorDetails":{"kind":"downloadFailures","lockfilePath":null,"suggestedAction":"skipOrAbort","downloadFailures":[{"identifier":"ModuleManager","name":"Module Manager","version":"4.2.3","message":"Host returned 500","urls":["https://example.invalid/ModuleManager.zip"]}]}}}
        """)

        XCTAssertEqual(result.operationId, "op-downloads")
        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.error, "Downloads failed")
        XCTAssertEqual(result.errorDetails?.kind, "downloadFailures")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "skipOrAbort")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.identifier, "ModuleManager")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.message, "Host returned 500")
        XCTAssertEqual(result.errorDetails?.downloadFailures?.first?.urls, ["https://example.invalid/ModuleManager.zip"])
    }

    func testDecodesOperationResultProviderChoiceDetails() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":10,"result":{"operationId":"op-provider","instanceId":"primary","status":"failed","changes":[{"identifier":"LocalMetapackage","name":"Local Metapackage","action":"install","fromVersion":null,"toVersion":"1.0.0","reasons":["User requested"],"isUserRequested":true,"isAuto":false}],"events":[],"error":"Too many modules provide VirtualDependency","errorDetails":{"kind":"providerChoices","lockfilePath":null,"suggestedAction":"chooseProvider","providerChoices":[{"requested":"VirtualDependency","message":"Choose a provider","requesterIdentifier":"LocalMetapackage","requesterName":"Local Metapackage","options":[{"identifier":"ProviderA","name":"Provider A","version":"1.0.0","abstract":"First provider"},{"identifier":"ProviderB","name":"Provider B","version":"2.0.0","abstract":"Second provider"}]}]}}}
        """)

        XCTAssertEqual(result.operationId, "op-provider")
        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.errorDetails?.kind, "providerChoices")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "chooseProvider")
        XCTAssertEqual(result.errorDetails?.providerChoices?.first?.requested, "VirtualDependency")
        XCTAssertEqual(result.errorDetails?.providerChoices?.first?.requesterIdentifier, "LocalMetapackage")
        XCTAssertEqual(result.errorDetails?.providerChoices?.first?.options.map(\.identifier), ["ProviderA", "ProviderB"])
    }

    func testDecodesOperationResultRecommendationChoiceDetails() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":11,"result":{"operationId":"op-recommendation","instanceId":"primary","status":"failed","changes":[{"identifier":"LocalRecommender","name":"Local Recommender","action":"install","fromVersion":null,"toVersion":"1.0.0","reasons":["User requested"],"isUserRequested":true,"isAuto":false}],"events":[],"error":"Choose optional recommendations","errorDetails":{"kind":"recommendationChoices","lockfilePath":null,"suggestedAction":"chooseRecommendations","recommendationChoices":[{"kind":"recommendation","identifier":"RecommendedMod","name":"Recommended Mod","version":"1.0.0","abstract":"Useful companion","dependents":["LocalRecommender"],"isRecommendedDefault":true}]}}}
        """)

        XCTAssertEqual(result.operationId, "op-recommendation")
        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.errorDetails?.kind, "recommendationChoices")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "chooseRecommendations")
        XCTAssertEqual(result.errorDetails?.recommendationChoices?.first?.kind, "recommendation")
        XCTAssertEqual(result.errorDetails?.recommendationChoices?.first?.identifier, "RecommendedMod")
        XCTAssertEqual(result.errorDetails?.recommendationChoices?.first?.dependents, ["LocalRecommender"])
        XCTAssertEqual(result.errorDetails?.recommendationChoices?.first?.isRecommendedDefault, true)
    }

    func testDecodesOperationResultIncompatibleCkanFileDetails() throws {
        let result = try SidecarClient.decodeOperationResultResponse(from: """
        warning NU1904: Package warning
        {"jsonrpc":"2.0","id":12,"result":{"operationId":"op-incompatible","instanceId":"primary","status":"failed","changes":[{"identifier":"LocalIncompatibleMetapackage","name":"Local Incompatible Metapackage","action":"install","fromVersion":null,"toVersion":"1.0.0","reasons":["User requested"],"isUserRequested":true,"isAuto":false}],"events":[],"error":"Some .ckan files are not compatible","errorDetails":{"kind":"incompatibleCkanFiles","lockfilePath":null,"suggestedAction":"confirmIncompatible","incompatibleCkanFiles":[{"identifier":"LocalIncompatibleMetapackage","name":"Local Incompatible Metapackage","version":"1.0.0","compatibleGameVersions":"KSP 0.24"}]}}}
        """)

        XCTAssertEqual(result.operationId, "op-incompatible")
        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.errorDetails?.kind, "incompatibleCkanFiles")
        XCTAssertEqual(result.errorDetails?.suggestedAction, "confirmIncompatible")
        XCTAssertEqual(result.errorDetails?.incompatibleCkanFiles?.first?.identifier, "LocalIncompatibleMetapackage")
        XCTAssertEqual(result.errorDetails?.incompatibleCkanFiles?.first?.compatibleGameVersions, "KSP 0.24")
    }
}

private func requestParams(from request: String) throws -> [String: Any] {
    let data = Data(request.utf8)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(object["params"] as? [String: Any])
}

private actor RecordingSidecarTransport: SidecarTransport {
    private var responses: [String]
    private var requests: [String] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func request(_ requestLine: String) async throws -> String {
        requests.append(requestLine)
        guard !responses.isEmpty else {
            throw SidecarClientError.invalidResponse
        }
        return responses.removeFirst()
    }

    func capturedRequests() -> [String] {
        requests
    }
}

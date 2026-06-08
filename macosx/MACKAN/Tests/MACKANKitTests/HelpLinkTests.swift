import XCTest

@testable import MACKANKit

final class HelpLinkTests: XCTestCase {
    func testCoreHelpLinksMatchUpstreamCKANURLs() throws {
        XCTAssertEqual(MACKANHelpLink.coreLinks, [
            MACKANHelpLink.userGuide,
            MACKANHelpLink.ckanDiscord,
        ])
        XCTAssertEqual(MACKANHelpLink.userGuide.title, "User Guide")
        XCTAssertEqual(MACKANHelpLink.userGuide.url.absoluteString, "https://github.com/KSP-CKAN/CKAN/wiki/User-guide")
        XCTAssertEqual(MACKANHelpLink.ckanDiscord.title, "CKAN Discord")
        XCTAssertEqual(MACKANHelpLink.ckanDiscord.url.absoluteString, "https://discord.gg/Mb4nXQD")
    }

    func testGameSupportLinksMatchWindowsGameSpecificHelp() throws {
        XCTAssertEqual(MACKANHelpLink.gameSupportLinks(for: "KSP"), [
            MACKANHelpLink.gameDiscord(GameHelpProfile.ksp),
            MACKANHelpLink.modSupport(GameHelpProfile.ksp),
        ])
        XCTAssertEqual(
            MACKANHelpLink.gameDiscord(GameHelpProfile.ksp).url.absoluteString,
            "https://discord.gg/65hp7G7")
        XCTAssertEqual(
            MACKANHelpLink.modSupport(GameHelpProfile.ksp).url.absoluteString,
            "https://forum.kerbalspaceprogram.com/forum/70-ksp1-technical-support-pc-modded-installs/")
    }

    func testKSP2MetadataIssueUsesKSP2Tracker() throws {
        XCTAssertEqual(
            MACKANHelpLink.reportMetadataIssue(GameHelpProfile.ksp2).url.absoluteString,
            "https://github.com/KSP-CKAN/KSP2-NetKAN/issues/new/choose")
    }

    func testMetadataIssueCanPrefillSelectedModuleContext() throws {
        let link = MACKANHelpLink.reportMetadataIssue(
            GameHelpProfile.ksp,
            selectedModule: ModuleHelpContext(identifier: "SidecarOnlyMod", name: "Sidecar Only Mod"))
        let components = try XCTUnwrap(URLComponents(url: link.url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.path, "/KSP-CKAN/NetKAN/issues/new")
        XCTAssertEqual(queryItems["title"], "Sidecar Only Mod metadata issue")
        XCTAssertTrue(queryItems["body"]?.contains("Identifier: SidecarOnlyMod") == true)
        XCTAssertTrue(queryItems["body"]?.contains("Name: Sidecar Only Mod") == true)
        XCTAssertTrue(queryItems["body"]?.contains("Game: KSP") == true)
    }

    func testReportLinksRequireSelectedGameForMetadataTracker() throws {
        XCTAssertEqual(MACKANHelpLink.reportLinks(for: "KSP").map(\.id), [
            .reportClientIssue,
            .reportMetadataIssue,
        ])
        XCTAssertEqual(MACKANHelpLink.reportLinks(for: nil), [
            MACKANHelpLink.reportClientIssue,
        ])
        XCTAssertEqual(MACKANHelpLink.reportClientIssue.url.absoluteString, "https://github.com/KSP-CKAN/CKAN/issues/new/choose")
    }
}

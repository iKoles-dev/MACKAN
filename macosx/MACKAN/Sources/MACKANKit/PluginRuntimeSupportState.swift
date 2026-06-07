import Foundation

public struct PluginRuntimeSupportState: Equatable, Sendable {
    public let isSupported: Bool
    public let title: String
    public let explanation: String
    public let plannedPath: String
    public let links: [PluginRuntimeSupportLink]

    public static let nativeMacOS = PluginRuntimeSupportState(
        isSupported: false,
        title: "Not supported on native macOS yet",
        explanation: "Windows CKAN plugin extensions are not currently exposed through a supported macOS-native plugin runtime in CKAN Core.",
        plannedPath: "Provide native parity for Plugins after the cross-platform plugin host contract is implemented in CKAN Core.",
        links: [
            PluginRuntimeSupportLink(
                title: "Open CKAN repository",
                url: URL(string: "https://github.com/KSP-CKAN/CKAN")!),
            PluginRuntimeSupportLink(
                title: "Track CKAN plugin work",
                url: URL(string: "https://github.com/KSP-CKAN/CKAN/issues")!),
        ])
}

public struct PluginRuntimeSupportLink: Identifiable, Equatable, Sendable {
    public let title: String
    public let url: URL

    public var id: String {
        url.absoluteString
    }
}

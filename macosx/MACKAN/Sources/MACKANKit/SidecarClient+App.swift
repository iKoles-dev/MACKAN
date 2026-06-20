import Foundation

extension SidecarClient {
    public func health() async throws -> SidecarHealth {
        try await request(method: "app.health")
    }

    public func version() async throws -> SidecarVersion {
        try await request(method: "app.version")
    }

    public func checkForUpdates(useDevBuilds: Bool? = nil) async throws -> UpdateCheckResult {
        var params: [String: JSONRPCParameterValue] = [:]
        if let useDevBuilds {
            params["useDevBuilds"] = .bool(useDevBuilds)
        }
        return try await request(
            method: "app.checkForUpdates",
            params: params.isEmpty ? nil : params)
    }

}

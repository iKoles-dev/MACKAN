import XCTest
@testable import MACKANKit

@MainActor
final class E2ETests: XCTestCase {
    func testSidecarNotificationPayloadDecodesOperationProgress() throws {
        let payload = """
        {"jsonrpc":"2.0","method":"operations.event","params":{"operationId":"op-test","event":{"kind":"progress","message":"Downloading Mod","percent":45}}}
        """
        let parsed = try JSONDecoder().decode(JSONRPCNotification.self, from: Data(payload.utf8))

        XCTAssertEqual(parsed.method, "operations.event")
        XCTAssertEqual(parsed.params.operationId, "op-test")
        XCTAssertEqual(parsed.params.event.message, "Downloading Mod")
        XCTAssertEqual(parsed.params.event.progressFraction, 0.45)
    }

    func testCancelOperationUpdatesRealSidecarResult() async throws {
        var sidecar = FakeSidecar()
        sidecar.applyStatus = "cancelling"

        let result = try await sidecar.cancelOperation(operationId: "op-1")

        XCTAssertEqual(result.operationId, "op-1")
        XCTAssertEqual(result.status, "cancelling")
        XCTAssertEqual(result.events.last?.message, "Cancellation requested")
    }

    func testPresentationStillWorksAfterOperationErrorState() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        model.presentSheet(.updateCheck)

        let failedOperation = OperationResult(
            operationId: "op-failed",
            instanceId: "primary",
            status: "failed",
            changes: [],
            events: [
                OperationEvent(
                    kind: "message",
                    message: "Registry is locked",
                    percent: nil,
                    identifier: nil,
                    remainingBytes: nil,
                    totalBytes: nil)
            ],
            error: "Registry is locked")
        model.lastOperationResult = failedOperation

        model.presentSheet(.about)
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(model.activeSheet, .about)
        XCTAssertEqual(model.lastOperationResult?.status, "failed")
    }

    func testOperationProgressPresentationFormatsCompletedProgress() {
        let result = OperationResult(
            operationId: "repo-sync",
            instanceId: "primary",
            status: "completed",
            changes: [],
            events: [
                OperationEvent(
                    kind: "progress",
                    message: "Syncing repos",
                    percent: 100,
                    identifier: nil,
                    remainingBytes: 0,
                    totalBytes: 4096)
            ],
            error: nil)

        let event = result.events.last

        XCTAssertEqual(event?.progressFraction, 1.0)
        XCTAssertEqual(event?.byteProgressDisplay, "4.1 KB of 4.1 KB")
    }

    private struct JSONRPCNotification: Decodable {
        let jsonrpc: String
        let method: String
        let params: Params

        struct Params: Decodable {
            let operationId: String
            let event: OperationEvent
        }
    }
}

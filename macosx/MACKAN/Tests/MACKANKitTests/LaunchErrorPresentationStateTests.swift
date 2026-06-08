import XCTest

@testable import MACKANKit

final class LaunchErrorPresentationStateTests: XCTestCase {
    func testPlainErrorUsesOriginalMessageAndDoesNotOfferRetry() {
        let state = LaunchErrorPresentationState(
            message: "Launch failed",
            details: nil)

        XCTAssertEqual(state.messageText, "Launch failed")
        XCTAssertFalse(state.canRetry)
    }

    func testNonLaunchDetailsUseOriginalMessageAndDoNotOfferRetry() {
        let state = LaunchErrorPresentationState(
            message: "Registry locked",
            details: .registryLock("/tmp/registry.locked"))

        XCTAssertEqual(state.messageText, "Registry locked")
        XCTAssertFalse(state.canRetry)
    }

    func testLaunchFailureIncludesCommandAndSuggestedActionAndOffersRetry() {
        let state = LaunchErrorPresentationState(
            message: "Failed to launch game.",
            details: .launchFailure(
                command: "missing-ksp-launch-binary",
                suggestedAction: "retryOrCheckCommand"))

        XCTAssertEqual(
            state.messageText,
            "Failed to launch game.\nCommand: missing-ksp-launch-binary\nSuggested action: retryOrCheckCommand")
        XCTAssertTrue(state.canRetry)
    }

    func testLaunchFailureOmitsEmptyOptionalDetails() {
        let state = LaunchErrorPresentationState(
            message: "Failed to launch game.",
            details: .launchFailure(command: "", suggestedAction: ""))

        XCTAssertEqual(state.messageText, "Failed to launch game.")
        XCTAssertTrue(state.canRetry)
    }
}

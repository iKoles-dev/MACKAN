import XCTest
@testable import MACKANKit

@MainActor
final class AppSheetConcurrencyTests: XCTestCase {
    
    /// Test that a newer sheet presentation (.cloneInstance) is overwritten by an older delayed presentation (.addInstance).
    func testConcurrentSheetPresentationOverwritesNewerSheet() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        
        // 1. Present first sheet (immediate, since activeSheet is nil)
        model.presentSheet(.about)
        XCTAssertEqual(model.activeSheet, .about)
        
        // 2. Present second sheet (triggers dismiss and schedules presentation after 150ms)
        model.presentSheet(.addInstance)
        XCTAssertNil(model.activeSheet, "Should be nil immediately during dismissal animation")
        
        // 3. Present third sheet while task from step 2 is pending — cancels it and schedules cloneInstance
        // At this point activeSheet is nil, so presentSheet sets activeSheet = cloneInstance immediately
        model.presentSheet(.cloneInstance)
        
        // 4. Wait to confirm the sheet remains stable
        try await Task.sleep(nanoseconds: 250_000_000)
        
        // Verify it is cloneInstance (newest request) that ultimately wins
        XCTAssertEqual(model.activeSheet, .cloneInstance, "Expected the newer presentation (.cloneInstance) to persist")
    }

    /// Test that an explicit call to dismissSheet() is overwritten by a pending transition task.
    func testRapidDismissalGetsOverwrittenByPendingTransition() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        
        // 1. Present a sheet
        model.presentSheet(.about)
        XCTAssertEqual(model.activeSheet, .about)
        
        // 2. Present second sheet (triggers dismiss and schedules presentation after 150ms)
        model.presentSheet(.addInstance)
        XCTAssertNil(model.activeSheet)
        
        // 3. Dismiss sheet explicitly (e.g. user clicks close or hits escape immediately)
        model.dismissSheet()
        XCTAssertNil(model.activeSheet)
        
        // 4. Wait for the 150ms sleep of the second sheet's presentation Task to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNil(model.activeSheet, "Expected activeSheet to remain nil after explicit dismissal")
    }

    /// Test that rapidly presenting the same sheet twice causes flashing (resets to nil, then schedules presentation).
    func testRapidDoubleClickCausesFlashing() async throws {
        let model = AppModel(sidecar: FakeSidecar())
        
        // 1. First click: presents immediately
        model.presentSheet(.manageInstances)
        XCTAssertEqual(model.activeSheet, .manageInstances)
        
        // 2. Second click: should do nothing because activeSheet == sheet
        model.presentSheet(.manageInstances)
        XCTAssertEqual(model.activeSheet, .manageInstances, "Expected activeSheet to remain presented without flashing")
        
        // Wait for the task to complete
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(model.activeSheet, .manageInstances)
    }
}

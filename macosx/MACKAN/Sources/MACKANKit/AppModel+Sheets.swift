import Foundation
import SwiftUI

extension AppModel {
    /// Safe method to present a sheet, handling SwiftUI dismiss/present transition overlaps.
    @MainActor
    public func presentSheet(_ sheet: AppSheet) {
        if activeSheet == sheet {
            return
        }

        let wasPresenting = activeSheet != nil || sheetPresentationTask != nil
        sheetPresentationTask?.cancel()
        sheetPresentationTask = nil

        if wasPresenting {
            activeSheet = nil
            sheetPresentationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                self.activeSheet = sheet
                self.sheetPresentationTask = nil
            }
        } else {
            activeSheet = sheet
        }
    }

    /// Dismisses the currently presented app-level sheet.
    @MainActor
    public func dismissSheet() {
        sheetPresentationTask?.cancel()
        sheetPresentationTask = nil
        activeSheet = nil
    }
}

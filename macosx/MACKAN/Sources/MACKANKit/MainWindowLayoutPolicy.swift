import Foundation

public enum MainWindowLayoutPolicy {
    public static let minimumWindowWidth: Double = 760
    public static let minimumWindowHeight: Double = 620
    public static let sidebarVisibilityBreakpoint: Double = 820
    public static let inspectorVisibilityBreakpoint: Double = 1120
    public static let emptyInspectorVisibilityBreakpoint: Double = 1440
    public static let sidebarMinimumWidth: Double = 220
    public static let contentMinimumWidth: Double = 480
    public static let inspectorMinimumWidth: Double = 300

    public static func shouldShowInspector(windowWidth: Double, hasSelectedModule: Bool) -> Bool {
        if hasSelectedModule {
            return windowWidth >= inspectorVisibilityBreakpoint
        }
        return windowWidth >= emptyInspectorVisibilityBreakpoint
    }
}

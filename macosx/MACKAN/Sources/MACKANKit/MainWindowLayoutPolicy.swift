import CoreGraphics
import Foundation

public enum MainWindowLayoutPolicy {
    public static let defaultWindowWidth: Double = 1360
    public static let defaultWindowHeight: Double = 860
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

    public static func sidebarIdealWidth(forWindowWidth width: Double) -> Double {
        width >= 1400 ? 260 : 240
    }

    public static func sidebarMaximumWidth(forWindowWidth width: Double) -> Double {
        width >= 1400 ? 280 : 260
    }

    public static func constrainedStartupFrame(_ proposedFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else {
            return proposedFrame
        }

        let width = constrainedLength(
            proposedFrame.width,
            minimum: CGFloat(minimumWindowWidth),
            maximum: visibleFrame.width
        )
        let height = constrainedLength(
            proposedFrame.height,
            minimum: CGFloat(minimumWindowHeight),
            maximum: visibleFrame.height
        )

        let maxOriginX = max(visibleFrame.minX, visibleFrame.maxX - width)
        let maxOriginY = max(visibleFrame.minY, visibleFrame.maxY - height)
        let originX = min(max(proposedFrame.origin.x, visibleFrame.minX), maxOriginX)
        let originY = min(max(proposedFrame.origin.y, visibleFrame.minY), maxOriginY)

        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private static func constrainedLength(_ length: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else {
            return min(length, maximum)
        }
        return min(max(length, minimum), maximum)
    }
}

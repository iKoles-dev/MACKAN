import Foundation

public enum CatalogToolbarLayoutPolicy {
    public static let searchMinimumWidth: Double = 260
    public static let searchIdealWidth: Double = 340
    public static let controlsMinimumWidth: Double = 690
    public static let fixedPickerWidthTotal: Double = 415
    public static let iconControlWidthTotal: Double = 160
    public static let interControlSpacingTotal: Double = 100
    public static let horizontalPadding: Double = 24
    public static let searchControlGap: Double = 16

    public static var minimumContentWidth: Double {
        controlsMinimumWidth
            + horizontalPadding
    }

    public static var singleRowMinimumWidth: Double {
        searchIdealWidth
            + searchControlGap
            + controlsMinimumWidth
            + horizontalPadding
    }

    public static var calculatedControlsMinimumWidth: Double {
        fixedPickerWidthTotal
            + iconControlWidthTotal
            + interControlSpacingTotal
    }

    public static func shouldUseSingleRow(forWidth width: Double) -> Bool {
        width >= singleRowMinimumWidth
    }
}

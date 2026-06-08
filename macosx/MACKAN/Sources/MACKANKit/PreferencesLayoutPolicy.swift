import Foundation

public enum PreferencesLayoutPolicy {
    public static let minimumWidth: Double = 720
    public static let idealWidth: Double = 940
    public static let maximumWidth: Double = 1180
    public static let minimumHeight: Double = 500
    public static let idealHeight: Double = 620
    public static let tabItemEstimatedWidth: Double = 82
    public static let horizontalChromeAllowance: Double = 96

    public static func estimatedTabBarWidth(tabCount: Int) -> Double {
        Double(tabCount) * tabItemEstimatedWidth + horizontalChromeAllowance
    }
}

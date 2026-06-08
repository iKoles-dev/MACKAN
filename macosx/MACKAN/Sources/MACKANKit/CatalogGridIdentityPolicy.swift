import Foundation

public enum CatalogGridIdentityPolicy {
    public static func headerID(for column: ModuleTableColumn) -> String {
        "header-\(column.rawValue)"
    }

    public static func moduleCellID(moduleIdentifier: String, column: ModuleTableColumn) -> String {
        "module-\(moduleIdentifier)-\(column.rawValue)"
    }
}

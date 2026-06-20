import CoreGraphics
import Foundation

public enum CatalogLayoutPolicy {
    public struct Layout: Equatable, Sendable {
        public let columns: [ModuleTableColumn]
        public let widths: [ModuleTableColumn: CGFloat]

        public var totalWidth: CGFloat {
            columns.reduce(CGFloat(0)) { partial, column in
                partial + width(for: column)
            }
        }

        public func width(for column: ModuleTableColumn) -> CGFloat {
            widths[column] ?? CatalogLayoutPolicy.defaultWidth(for: column)
        }
    }

    public static func layout(
        forWidth width: CGFloat,
        storedColumns: [ModuleTableColumn]
    ) -> Layout {
        let columns = visibleColumns(forWidth: width, storedColumns: storedColumns)
        let baseWidths = Dictionary(uniqueKeysWithValues: columns.map { column in
            (column, responsiveWidth(for: column, viewportWidth: width))
        })
        let widths = widthsFillingViewport(
            width,
            columns: columns,
            baseWidths: baseWidths)

        return Layout(
            columns: columns,
            widths: widths)
    }

    public static func visibleColumns(
        forWidth width: CGFloat,
        storedColumns: [ModuleTableColumn]
    ) -> [ModuleTableColumn] {
        let normalized = ModuleTableColumn.normalized(storedColumns)
        if width < 900 {
            return [.status, .name, .installedVersion, .latestVersion]
        }
        if width < 1280 {
            return ModuleTableColumn.defaultVisible
        }
        return normalized.contains(.name) ? normalized : [.name] + normalized
    }

    public static func responsiveWidth(
        for column: ModuleTableColumn,
        viewportWidth: CGFloat
    ) -> CGFloat {
        switch column {
        case .status:
            return viewportWidth < 900 ? 72 : 86
        case .pending:
            return 88
        case .autoInstalled:
            return 108
        case .name:
            return viewportWidth < 900 ? 300 : 280
        case .identifier:
            return 170
        case .installedVersion, .latestVersion:
            return 128
        case .author:
            return viewportWidth < 1280 ? 150 : 190
        case .gameCompatibility:
            return 140
        case .downloadSize, .installSize:
            return 120
        case .releaseDate, .installDate:
            return 150
        case .downloadCount:
            return 110
        case .license:
            return 120
        case .tags:
            return 180
        case .description:
            return 320
        }
    }

    public static func defaultWidth(for column: ModuleTableColumn) -> CGFloat {
        responsiveWidth(for: column, viewportWidth: 1360)
    }

    public static func rowHeight(forWidth width: CGFloat) -> CGFloat {
        width >= 1400 ? 28 : 30
    }

    private static func widthsFillingViewport(
        _ viewportWidth: CGFloat,
        columns: [ModuleTableColumn],
        baseWidths: [ModuleTableColumn: CGFloat]
    ) -> [ModuleTableColumn: CGFloat] {
        let baseTotal = columns.reduce(CGFloat(0)) { partial, column in
            partial + (baseWidths[column] ?? defaultWidth(for: column))
        }
        guard baseTotal < viewportWidth else {
            return baseWidths
        }

        let flexibleColumns = columns.filter { column in
            flexibleWeight(for: column) > 0
        }
        guard !flexibleColumns.isEmpty else {
            return baseWidths
        }

        let extraWidth = viewportWidth - baseTotal
        let totalWeight = flexibleColumns.reduce(CGFloat(0)) { partial, column in
            partial + flexibleWeight(for: column)
        }
        guard totalWeight > 0 else {
            return baseWidths
        }

        var widths = baseWidths
        for column in flexibleColumns {
            let share = extraWidth * flexibleWeight(for: column) / totalWeight
            widths[column] = (widths[column] ?? defaultWidth(for: column)) + share
        }
        return widths
    }

    private static func flexibleWeight(for column: ModuleTableColumn) -> CGFloat {
        switch column {
        case .name:
            return 6
        case .description:
            return 5
        case .author:
            return 4
        case .tags, .identifier:
            return 2
        default:
            return 0
        }
    }
}

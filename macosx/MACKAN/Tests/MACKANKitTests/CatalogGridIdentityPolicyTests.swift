import XCTest
@testable import MACKANKit

final class CatalogGridIdentityPolicyTests: XCTestCase {
    func testHeaderAndModuleCellIdentifiersAreUniqueAcrossGrid() {
        let columns = ModuleTableColumn.defaultVisible
        let modules = ["MechJeb2", "Scatterer"]

        let headerIDs = columns.map(CatalogGridIdentityPolicy.headerID(for:))
        let moduleIDs = modules.flatMap { identifier in
            columns.map { column in
                CatalogGridIdentityPolicy.moduleCellID(moduleIdentifier: identifier, column: column)
            }
        }
        let allIDs = headerIDs + moduleIDs

        XCTAssertEqual(Set(allIDs).count, allIDs.count)
    }

    func testHeaderAndModuleCellIdentifiersUseStablePrefixes() {
        XCTAssertEqual(CatalogGridIdentityPolicy.headerID(for: .name), "header-name")
        XCTAssertEqual(
            CatalogGridIdentityPolicy.moduleCellID(moduleIdentifier: "4kSP_Expanded", column: .name),
            "module-4kSP_Expanded-name")
    }
}

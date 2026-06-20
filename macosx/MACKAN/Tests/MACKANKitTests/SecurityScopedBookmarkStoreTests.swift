import XCTest
@testable import MACKANKit

final class SecurityScopedBookmarkStoreTests: XCTestCase {
    func testStoresAndRemovesBookmarkForPath() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertTrue(store.storeBookmark(for: directory))
        XCTAssertTrue(store.hasBookmark(forPath: directory.path))

        store.removeBookmark(forPath: directory.path)
        XCTAssertFalse(store.hasBookmark(forPath: directory.path))
    }

    func testRestoresStoredBookmarkForPath() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertTrue(store.storeBookmark(for: directory))
        let restored = try XCTUnwrap(store.restoreAccess(forPath: directory.path))

        XCTAssertEqual(
            restored.resolvingSymlinksInPath().path,
            directory.resolvingSymlinksInPath().path)
    }

    private func makeStore() throws -> (SecurityScopedBookmarkStore, UserDefaults, String) {
        let suiteName = "MACKAN.SecurityScopedBookmarkStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return (SecurityScopedBookmarkStore(defaults: defaults), defaults, suiteName)
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

import Foundation

/// AppModel integration for Security-Scoped Bookmarks.
///
/// When the user adds or clones a game instance, the folder URL is bookmarked so that
/// MACKAN can restore file-system access to it on subsequent launches without presenting
/// a system file-picker dialog again.
///
/// Usage pattern
/// -------------
/// 1. After an `NSOpenPanel` or `fileImporter` returns a URL, call
///    `model.storeInstanceBookmark(for: url)` *before* passing the path string to the
///    sidecar.  The bookmark is associated with the canonical path of the URL.
/// 2. On app launch, call `model.restoreInstanceBookmarks()` once to re-start
///    security-scoped access for all known instance directories.
/// 3. When the user removes an instance, call
///    `model.removeInstanceBookmark(forPath: path)` to clean up.
extension AppModel {
    // MARK: - Bookmark storage

    /// Persists a security-scoped bookmark for the given directory URL.
    ///
    /// Call this immediately after the user selects a game directory in a file picker.
    /// - Parameter url: The URL returned by `NSOpenPanel` or `fileImporter`.
    /// - Returns: `true` when the bookmark was stored successfully.
    @discardableResult
    public func storeInstanceBookmark(for url: URL) -> Bool {
        SecurityScopedBookmarkStore.shared.storeBookmark(for: url)
    }

    /// Removes a previously stored bookmark for the given path.
    ///
    /// Call this when the user removes a game instance from MACKAN.
    public func removeInstanceBookmark(forPath path: String) {
        SecurityScopedBookmarkStore.shared.removeBookmark(forPath: path)
    }

    /// Returns `true` when a security-scoped bookmark exists for the given path.
    public func hasInstanceBookmark(forPath path: String) -> Bool {
        SecurityScopedBookmarkStore.shared.hasBookmark(forPath: path)
    }

    // MARK: - Access restoration

    /// Restores security-scoped access for all known game instance directories.
    ///
    /// This should be called once during app startup, after the instance list has been
    /// loaded from the sidecar.  It is safe to call repeatedly — already-active URLs
    /// are not re-started.
    ///
    /// - Returns: The set of paths for which access was successfully restored.
    @discardableResult
    public func restoreInstanceBookmarks() -> Set<String> {
        var restored: Set<String> = []
        for instance in instances {
            let path = instance.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            if SecurityScopedBookmarkStore.shared.restoreAccess(forPath: path) != nil {
                restored.insert(path)
            }
        }
        return restored
    }
}

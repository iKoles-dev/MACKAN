import Foundation

/// Persists and restores security-scoped bookmarks for game instance directories.
///
/// MACKAN is not distributed via the Mac App Store and does not use App Sandbox by default.
/// However, storing bookmarks ensures access survives future sandbox adoption or Hardened
/// Runtime restrictions without requiring the user to re-select their game folders.
///
/// Bookmark data is stored in UserDefaults under a stable key derived from the directory path.
/// On restore, the bookmark is resolved and security access is started before use.
public final class SecurityScopedBookmarkStore: @unchecked Sendable {
    public static let shared = SecurityScopedBookmarkStore()

    private let defaults: UserDefaults
    private let defaultsKeyPrefix = "mackan.bookmark."

    // Tracks URLs whose security-scoped resource access has been started so we can
    // stop it when the store is deallocated or access is explicitly relinquished.
    private var activeURLs: [URL] = []
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        stopAllAccess()
    }

    // MARK: - Public API

    /// Stores a security-scoped bookmark for the given directory URL.
    ///
    /// - Parameter url: A directory URL returned by `NSOpenPanel` or a system file picker.
    ///   The URL must point to a directory the user has explicitly granted access to.
    /// - Returns: `true` if the bookmark was created and stored successfully.
    @discardableResult
    public func storeBookmark(for url: URL) -> Bool {
        do {
            let bookmarkData = try bookmarkData(for: url)
            let key = defaultsKey(for: url)
            defaults.set(bookmarkData, forKey: key)
            return true
        } catch {
            return false
        }
    }

    /// Restores access to a previously bookmarked directory.
    ///
    /// - Parameter path: The absolute path of the directory (same path used when the bookmark
    ///   was stored).
    /// - Returns: The resolved `URL` with security-scoped access started, or `nil` if no
    ///   bookmark exists or the bookmark could not be resolved.
    public func restoreAccess(forPath path: String) -> URL? {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let key = defaultsKey(for: url)
        guard let bookmarkData = defaults.data(forKey: key) else {
            return nil
        }

        guard let resolvedURL = resolve(bookmarkData) else {
            return nil
        }

        var isStale = false
        _ = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        if isStale {
            // Refresh the bookmark while we still have access.
            storeBookmark(for: resolvedURL)
        }

        if resolvedURL.startAccessingSecurityScopedResource() {
            lock.lock()
            activeURLs.append(resolvedURL)
            lock.unlock()
        }

        return resolvedURL
    }

    /// Stops security-scoped access for a URL previously returned by ``restoreAccess(forPath:)``.
    public func stopAccess(for url: URL) {
        url.stopAccessingSecurityScopedResource()
        lock.lock()
        activeURLs.removeAll { $0 == url }
        lock.unlock()
    }

    /// Removes the stored bookmark for the given path.
    public func removeBookmark(forPath path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        defaults.removeObject(forKey: defaultsKey(for: url))
    }

    /// Returns whether a bookmark exists for the given path.
    public func hasBookmark(forPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return defaults.data(forKey: defaultsKey(for: url)) != nil
    }

    /// Stops security-scoped access for all currently active URLs.
    public func stopAllAccess() {
        lock.lock()
        let urls = activeURLs
        activeURLs.removeAll()
        lock.unlock()
        urls.forEach { $0.stopAccessingSecurityScopedResource() }
    }

    // MARK: - Private

    private func defaultsKey(for url: URL) -> String {
        defaultsKeyPrefix + url.standardizedFileURL.path
    }

    private func bookmarkData(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
        } catch {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil)
        }
    }

    private func resolve(_ bookmarkData: Data) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale) {
            return url
        }

        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
    }
}

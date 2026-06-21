import Foundation

/// AppModel integration for macOS Spotlight indexing via ``SpotlightIndexer``.
///
/// Installed mods are indexed automatically whenever the module catalog is loaded or
/// refreshed for a game instance.  When a mod is installed, upgraded, or removed as
/// part of an operation, the index for the affected instance is refreshed.
/// When an instance is removed from MACKAN its Spotlight domain is deleted entirely.
///
/// The integration intentionally keeps indexing out of the critical path: all index
/// mutations are fire-and-forget and any CoreSpotlight errors are logged but do not
/// surface to the user.
extension AppModel {
    /// The Spotlight indexer used by this model.
    ///
    /// Exposed as a testable surface; production code uses ``SpotlightIndexer.shared``.
    var spotlightIndexer: SpotlightIndexer { .shared }

    // MARK: - Catalog integration

    /// Indexes all installed mods in the current module catalog for the given instance.
    ///
    /// Call this after the module catalog has been loaded or refreshed.  Modules that are
    /// not installed are skipped; existing Spotlight items for mods that are no longer
    /// installed are left for removal on the next full re-index (CoreSpotlight handles
    /// staleness via ``expirationDate``).
    ///
    /// - Parameter instanceID: The stable identifier of the game instance whose mods should be indexed.
    public func indexInstalledModsForSpotlight(instanceID: String) {
        // Fire-and-forget: indexing errors are logged inside SpotlightIndexer.
        spotlightIndexer.indexInstalledMods(modules, forInstanceID: instanceID)
    }

    /// Updates the Spotlight entry for a single mod, e.g. after an operation completes.
    ///
    /// - Parameters:
    ///   - module: The module to index (or de-index if no longer installed).
    ///   - instanceID: The game instance the mod belongs to.
    public func updateSpotlightEntry(for module: ModuleSummary, instanceID: String) {
        spotlightIndexer.indexMod(module, forInstanceID: instanceID)
    }

    /// Removes all Spotlight entries for a game instance.
    ///
    /// Call this immediately before or after the instance is removed from MACKAN.
    public func removeSpotlightEntries(forInstanceID instanceID: String) {
        spotlightIndexer.removeAll(forInstanceID: instanceID)
    }

    // MARK: - Convenience: re-index after operations

    /// Re-indexes the full installed-mod catalog for the currently selected instance.
    ///
    /// Call this after `applyChanges`, `importDownloads`, or any other operation that may
    /// have changed which mods are installed.
    public func refreshSpotlightIndexForSelectedInstance() {
        guard let instanceID = selectedInstanceID else { return }
        spotlightIndexer.indexInstalledMods(modules, forInstanceID: instanceID)
    }
}

#if NET10_0_OR_GREATER

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Diagnostics.CodeAnalysis;

using CKAN;
using CKAN.Configuration;
using CKAN.Games;
using CKAN.Games.KerbalSpaceProgram;
using CKAN.MACKAN.Service;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanSettingsProviderTests
    {
        [Test]
        public void CacheSettingsUseInjectedConfiguration()
        {
            using var instance = new DisposableKSP();
            using var cacheParent = new TemporaryDirectory();
            var cachePath = Path.Combine(cacheParent.Directory.FullName, "cache");
            Directory.CreateDirectory(cachePath);
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var updated = provider.UpdateSettings(cachePath, 42_000);
            var loaded = provider.GetSettings();

            Assert.That(updated.DownloadCacheDir, Is.EqualTo(cachePath));
            Assert.That(updated.CacheSizeLimitBytes, Is.EqualTo(42_000));
            Assert.That(loaded.DownloadCacheDir, Is.EqualTo(cachePath));
            Assert.That(loaded.CacheSizeLimitBytes, Is.EqualTo(42_000));
            Assert.That(config.DownloadCacheDir, Is.EqualTo(cachePath));
            Assert.That(config.CacheSizeLimit, Is.EqualTo(42_000));
        }

        [Test]
        public void CacheMigrationMoveMovesExistingFilesToNewCache()
        {
            using var instance = new DisposableKSP();
            using var cacheParent = new TemporaryDirectory();
            var oldCachePath = Path.Combine(cacheParent.Directory.FullName, "old-cache");
            var newCachePath = Path.Combine(cacheParent.Directory.FullName, "new-cache");
            Directory.CreateDirectory(oldCachePath);
            Directory.CreateDirectory(newCachePath);
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, oldCachePath);
            var oldCacheFile = Path.Combine(oldCachePath, "cached-download.zip");
            File.WriteAllText(oldCacheFile, "cached bytes");
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var updated = provider.UpdateSettings(newCachePath, -1, "move");

            Assert.That(updated.DownloadCacheDir, Is.EqualTo(newCachePath));
            Assert.That(File.Exists(Path.Combine(newCachePath, "cached-download.zip")), Is.True);
            Assert.That(File.Exists(oldCacheFile), Is.False);
            Assert.That(config.DownloadCacheDir, Is.EqualTo(newCachePath));
        }

        [Test]
        public void CacheMigrationDeleteRemovesExistingFilesWithoutMovingThem()
        {
            using var instance = new DisposableKSP();
            using var cacheParent = new TemporaryDirectory();
            var oldCachePath = Path.Combine(cacheParent.Directory.FullName, "old-cache");
            var newCachePath = Path.Combine(cacheParent.Directory.FullName, "new-cache");
            Directory.CreateDirectory(oldCachePath);
            Directory.CreateDirectory(newCachePath);
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, oldCachePath);
            var oldCacheFile = Path.Combine(oldCachePath, "cached-download.zip");
            File.WriteAllText(oldCacheFile, "cached bytes");
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var updated = provider.UpdateSettings(newCachePath, -1, "delete");

            Assert.That(updated.DownloadCacheDir, Is.EqualTo(newCachePath));
            Assert.That(File.Exists(oldCacheFile), Is.False);
            Assert.That(File.Exists(Path.Combine(newCachePath, "cached-download.zip")), Is.False);
            Assert.That(config.DownloadCacheDir, Is.EqualTo(newCachePath));
        }

        [Test]
        public void UpdateGeneralSettingsPersistsAndReloadsValues()
        {
            using var instance = new DisposableKSP("primary", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var updated = provider.UpdateGeneralSettings(instance.KSP.Name, false, true, false, true);
            var reloaded = provider.GetGeneralSettings(instance.KSP.Name);

            Assert.That(updated.InstanceId, Is.EqualTo("primary"));
            Assert.That(updated.CheckForUpdatesOnLaunch, Is.False);
            Assert.That(updated.UseDevBuilds, Is.True);
            Assert.That(updated.RefreshRepositoriesOnLaunch, Is.False);
            Assert.That(updated.AutoSortByUpdate, Is.True);
            Assert.That(reloaded.CheckForUpdatesOnLaunch, Is.False);
            Assert.That(reloaded.UseDevBuilds, Is.True);
            Assert.That(reloaded.RefreshRepositoriesOnLaunch, Is.False);
            Assert.That(reloaded.AutoSortByUpdate, Is.True);
            Assert.That(config.DevBuilds, Is.True);
        }

        [Test]
        public void CompatibleStabilityAndInstallFiltersPersistInDisposableInstance()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var compatible = provider.UpdateCompatibleGameVersions(
                instance.KSP.Name,
                new[] { "1.12.5", "1.11" });
            var stability = provider.UpdateOverallStabilityTolerance(instance.KSP.Name, "development");
            provider.UpdateModuleStabilityTolerance(instance.KSP.Name, "ModuleManager", "testing");
            var filters = provider.UpdateInstallFilters(
                instance.KSP.Name,
                new[] { " Ships ", "MiniAVC.dll", "ships", "" },
                new[] { "GameData/TestMod/Extras", " GameData/TestMod/Extras " });

            var reloadedCompatible = provider.GetCompatibleGameVersions(instance.KSP.Name);
            var reloadedStability = provider.GetStabilityTolerance(instance.KSP.Name);
            var reloadedFilters = provider.GetInstallFilters(instance.KSP.Name);

            Assert.That(compatible.CompatibleVersions, Is.EqualTo(new[] { "1.12.5", "1.11" }));
            Assert.That(reloadedCompatible.CompatibleVersions, Is.EqualTo(new[] { "1.12.5", "1.11" }));
            Assert.That(File.Exists(Path.Combine(instance.KSP.CkanDir, instance.KSP.Game.CompatibleVersionsFile)), Is.True);
            Assert.That(stability.OverallStabilityTolerance, Is.EqualTo("development"));
            Assert.That(reloadedStability.OverallStabilityTolerance, Is.EqualTo("development"));
            Assert.That(
                reloadedStability.ModuleStabilityTolerances.Single().Identifier,
                Is.EqualTo("ModuleManager"));
            Assert.That(
                reloadedStability.ModuleStabilityTolerances.Single().StabilityTolerance,
                Is.EqualTo("testing"));
            Assert.That(filters.GlobalFilters, Is.EqualTo(new[] { "Ships", "MiniAVC.dll" }));
            Assert.That(filters.InstanceFilters, Is.EqualTo(new[] { "GameData/TestMod/Extras" }));
            Assert.That(reloadedFilters.GlobalFilters, Is.EqualTo(new[] { "Ships", "MiniAVC.dll" }));
            Assert.That(reloadedFilters.InstanceFilters, Is.EqualTo(new[] { "GameData/TestMod/Extras" }));
            Assert.That(File.Exists(Path.Combine(instance.KSP.CkanDir, "install_filters.json")), Is.True);
        }

        [Test]
        public void PreferredHostsAndAuthTokensUseInjectedConfiguration()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanSettingsProvider(config, new RepositoryDataManager());

            var hosts = provider.UpdatePreferredHosts(
                instance.KSP.Name,
                new[] { " github.com ", null, "spacedock.info", "github.com", "" });
            var added = provider.AddAuthToken(" github.com ", "abcdef123456");
            var savedBeforeRemove = config.TryGetAuthToken("github.com", out var savedToken);
            var removed = provider.RemoveAuthToken("github.com");

            Assert.That(hosts.PreferredHosts, Is.EqualTo(new[] { "github.com", null, "spacedock.info" }));
            Assert.That(config.PreferredHosts, Is.EqualTo(new[] { "github.com", null, "spacedock.info" }));
            Assert.That(added.AuthTokens.Select(token => token.Host), Is.EqualTo(new[] { "github.com" }));
            Assert.That(added.AuthTokens.Single().TokenPreview, Is.EqualTo("********3456"));
            Assert.That(added.AuthTokens.Single().GetType().GetProperty("Token"), Is.Null);
            Assert.That(savedBeforeRemove, Is.True);
            Assert.That(savedToken, Is.EqualTo("abcdef123456"));
            Assert.That(config.TryGetAuthToken("github.com", out var removedToken), Is.False);
            Assert.That(removedToken, Is.Null);
            Assert.That(removed.AuthTokens, Is.Empty);
        }

        [Test]
        public void AuthTokensAreStoredViaKeychainConfigurationAndMaskedInResponse()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);

            var tokenStore = new InMemoryAuthTokenSecretStore();
            var keychainConfig = new KeychainAuthTokenConfiguration(config, tokenStore);

            var provider = new CoreMackanSettingsProvider(keychainConfig, new RepositoryDataManager());
            var added = provider.AddAuthToken(" github.com ", "  abcdef123456  ");

            Assert.That(added.AuthTokens.Single().Host, Is.EqualTo("github.com"));
            Assert.That(added.AuthTokens.Single().TokenPreview, Is.EqualTo("********3456"));
            Assert.That(tokenStore.TryGetToken("github.com", out var keychainToken), Is.True);
            Assert.That(keychainToken, Is.EqualTo("abcdef123456"));

            Assert.That(config.TryGetAuthToken("github.com", out var rawConfigToken), Is.True);
            Assert.That(rawConfigToken, Is.EqualTo(KeychainAuthTokenConfiguration.StoredInKeychainMarker));

            var listed = provider.GetAuthTokens();
            Assert.That(listed.AuthTokens.Single().TokenPreview, Is.EqualTo("********3456"));

            var reloadProvider = new CoreMackanSettingsProvider(
                new KeychainAuthTokenConfiguration(config, tokenStore),
                new RepositoryDataManager());

            // Existing raw token values must be migrated once, and never returned unmasked.
            config.SetAuthToken("api.github.com", "legacy-token");
            var migratedTokens = reloadProvider.GetAuthTokens();

            Assert.That(migratedTokens.AuthTokens.Count, Is.EqualTo(2));
            Assert.That(
                migratedTokens.AuthTokens.Single(token => token.Host == "api.github.com").TokenPreview,
                Is.EqualTo("********oken"));
            Assert.That(tokenStore.TryGetToken("api.github.com", out var legacyMigrated), Is.True);
            Assert.That(legacyMigrated, Is.EqualTo("legacy-token"));
            Assert.That(config.TryGetAuthToken("api.github.com", out var legacyMarker), Is.True);
            Assert.That(legacyMarker, Is.EqualTo(KeychainAuthTokenConfiguration.StoredInKeychainMarker));
        }

        private sealed class InMemoryAuthTokenSecretStore : IAuthTokenSecretStore
        {
            public readonly Dictionary<string, string> Tokens = new Dictionary<string, string>();

            public bool TryGetToken(string host, [NotNullWhen(true)] out string? token)
                => Tokens.TryGetValue(host, out token);

            public void SetToken(string host, string token)
            {
                Tokens[host] = token;
            }

            public void DeleteToken(string host)
            {
                Tokens.Remove(host);
            }
        }
    }
}

#endif

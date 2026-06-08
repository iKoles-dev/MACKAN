#if NET10_0_OR_GREATER

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using CKAN;
using CKAN.Games.KerbalSpaceProgram;
using CKAN.IO;
using CKAN.MACKAN.Service;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanMaintenanceProviderTests
    {
        private const string HistoryExactOld = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""HistoryExact"",
            ""name"": ""History Exact"",
            ""abstract"": ""Older exact history module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string HistoryExactNew = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""HistoryExact"",
            ""name"": ""History Exact"",
            ""abstract"": ""Newer exact history module."",
            ""author"": ""Test"",
            ""version"": ""2.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string HistoryLatest = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""HistoryLatest"",
            ""name"": ""History Latest"",
            ""abstract"": ""Latest-only history module."",
            ""author"": ""Test"",
            ""version"": ""3.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string HistorySnapshot = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""installed-PrimaryKSP-test"",
            ""name"": ""Installed modules"",
            ""abstract"": ""Installed modules snapshot."",
            ""author"": ""CKAN"",
            ""version"": ""2026.05.31"",
            ""license"": ""MIT"",
            ""kind"": ""metapackage"",
            ""depends"": [
                { ""name"": ""HistoryExact"", ""version"": ""1.0.0"" },
                { ""name"": ""HistoryLatest"" },
                { ""name"": ""HistoryMissing"", ""version"": ""9.9.9"" }
            ]
        }";

        [Test]
        public void DownloadStatisticsGroupsDisposableCacheBytesByRegistryHost()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath);
            var module = TestData.DogeCoinFlag_101_module();
            var repo = new Repository("temp", "https://example.invalid/repo.tar.gz", 0);
            using var repoData = new TemporaryRepositoryData(
                user,
                new Dictionary<Repository, RepositoryData>
                {
                    { repo, new RepositoryData(new[] { module }, null, null, null, false) },
                });
            var zipBytes = new FileInfo(TestData.DogeCoinFlagZip()).Length;
            using (var registry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo }))
            {
                registry.Save();
            }

            using (var cache = new NetModuleCache(config.DownloadCacheDir!))
            {
                cache.Store(module, TestData.DogeCoinFlagZip(), null);
            }

            var registryUrls = RegistryManager
                .ReadOnlyRegistry(instance.KSP, repoData.Manager)
                ?.GetDownloadUrlsByHash();
            Assert.That(registryUrls, Is.Not.Null);
            Assert.That(registryUrls, Is.Not.Empty);
            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var result = provider.DownloadStatistics(instance.KSP.Name);
            var host = result.Hosts.Single();

            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(host.Host, Is.EqualTo(module.download![0].Host));
            Assert.That(host.Bytes, Is.EqualTo(zipBytes));
            Assert.That(host.Display, Is.EqualTo(CkanModule.FmtSize(zipBytes)));
            Assert.That(result.TotalBytes, Is.EqualTo(zipBytes));
            Assert.That(result.TotalDisplay, Is.EqualTo(CkanModule.FmtSize(zipBytes)));
        }

        [Test]
        public void ClearCacheRemovesDisposableDownloadCacheFiles()
        {
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath);
            var module = TestData.DogeCoinFlag_101_module();
            var zipBytes = new FileInfo(TestData.DogeCoinFlagZip()).Length;
            using (var cache = new NetModuleCache(config.DownloadCacheDir!))
            {
                cache.Store(module, TestData.DogeCoinFlagZip(), null);
            }

            var provider = new CoreMackanMaintenanceProvider(
                config,
                new RepositoryDataManager());

            var before = provider.CacheInfo();
            var cleared = provider.ClearCache();

            Assert.That(before.Path, Is.EqualTo(config.DownloadCacheDir));
            Assert.That(before.FileCount, Is.EqualTo(1));
            Assert.That(before.Bytes, Is.EqualTo(zipBytes));
            Assert.That(cleared.Mode, Is.EqualTo("all"));
            Assert.That(cleared.PurgedFileCount, Is.EqualTo(1));
            Assert.That(cleared.PurgedBytes, Is.EqualTo(zipBytes));
            Assert.That(cleared.Cache.FileCount, Is.EqualTo(0));
            Assert.That(cleared.Cache.Bytes, Is.EqualTo(0));
        }

        [Test]
        public void PurgeCacheToLimitRemovesDisposableCacheFilesOverConfiguredLimit()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath)
            {
                CacheSizeLimit = 1,
            };
            var module = TestData.DogeCoinFlag_101_module();
            var repo = new Repository("temp", "https://example.invalid/repo.tar.gz", 0);
            using var repoData = new TemporaryRepositoryData(
                user,
                new Dictionary<Repository, RepositoryData>
                {
                    { repo, new RepositoryData(new[] { module }, null, null, null, false) },
                });
            var zipBytes = new FileInfo(TestData.DogeCoinFlagZip()).Length;
            using (var registry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo }))
            {
                registry.Save();
            }

            using (var cache = new NetModuleCache(config.DownloadCacheDir!))
            {
                cache.Store(module, TestData.DogeCoinFlagZip(), null);
            }

            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var purged = provider.PurgeCacheToLimit(instance.KSP.Name);

            Assert.That(purged.Mode, Is.EqualTo("limit"));
            Assert.That(purged.PurgedFileCount, Is.EqualTo(1));
            Assert.That(purged.PurgedBytes, Is.EqualTo(zipBytes));
            Assert.That(purged.Cache.FileCount, Is.EqualTo(0));
            Assert.That(purged.Cache.Bytes, Is.EqualTo(0));
            Assert.That(purged.Cache.LimitBytes, Is.EqualTo(1));
        }

        [Test]
        public void DeduplicateHardLinksDuplicateFilesAcrossDisposableInstances()
        {
            var user = new NullUser();
            using var first = new DisposableKSP("dedupe-1", new KerbalSpaceProgram());
            using var second = new DisposableKSP("dedupe-2", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(
                new List<Tuple<string, string, string>>
                {
                    Tuple.Create(first.KSP.Name, first.KSP.GameDir, first.KSP.Game.ShortName),
                    Tuple.Create(second.KSP.Name, second.KSP.GameDir, second.KSP.Game.ShortName),
                },
                null,
                null);
            using var manager = new GameInstanceManager(user, config);
            using var repo = new TemporaryRepository();
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var firstRegistry = RegistryManager.Instance(first.KSP, repoData.Manager, new[] { repo.repo });
            using var secondRegistry = RegistryManager.Instance(second.KSP, repoData.Manager, new[] { repo.repo });
            var module = TestData.MissionModule();
            manager.Cache!.Store(module, TestData.MissionZip(), null);
            InstallMissionModule(first.KSP, manager, config, firstRegistry, module);
            InstallMissionModule(second.KSP, manager, config, secondRegistry, module);
            var beforePaths = AbsoluteInstalledPaths(first.KSP, firstRegistry.registry)
                .Concat(AbsoluteInstalledPaths(second.KSP, secondRegistry.registry))
                .Order()
                .ToArray();
            var beforeLinkedCount = MultiLinkedFileCount(beforePaths);
            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var result = provider.Deduplicate();
            var afterPaths = AbsoluteInstalledPaths(first.KSP, firstRegistry.registry)
                .Concat(AbsoluteInstalledPaths(second.KSP, secondRegistry.registry))
                .Order()
                .ToArray();
            var afterLinkedCount = MultiLinkedFileCount(afterPaths);

            Assert.That(beforeLinkedCount, Is.EqualTo(0));
            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Events.Any(evt => evt.Kind == "message"
                                                 && evt.Message.StartsWith("Deduplication complete", StringComparison.Ordinal)),
                Is.True,
                string.Join(Environment.NewLine, result.Events.Select(evt => $"{evt.Kind}: {evt.Message}"))
                + $"{Environment.NewLine}beforeLinks={beforeLinkedCount} afterLinks={afterLinkedCount}");
            Assert.That(afterLinkedCount, Is.EqualTo(6));
        }

        [Test]
        public void RepairRegistryReindexesDisposableInstanceInstalledFiles()
        {
            var user = new NullUser();
            var modGen = new RandomModuleGenerator(new Random());
            var mod = modGen.GenerateRandomModule();
            using var instance = new DisposableKSP();
            using var repoData = new TemporaryRepositoryData(user);
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var gamedata = instance.KSP.Game.PrimaryModDirectory(instance.KSP);
            File.WriteAllText(
                Path.Combine(instance.KSP.CkanDir, "registry.json"),
                $@"{{
                    ""registry_version"": 3,
                    ""installed_files"": {{ }},
                    ""installed_modules"": {{
                        ""{mod.identifier}"": {{
                            ""source_module"": {mod.ToJson()},
                            ""installed_files"": {{
                                ""{gamedata}/{mod.identifier}.dll"": {{}}
                            }}
                        }}
                    }}
                }}");
            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var result = provider.RepairRegistry(instance.KSP.Name);
            using var registry = RegistryManager.Instance(instance.KSP, repoData.Manager);

            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Events.Select(evt => evt.Message), Does.Contain("Repairing CKAN registry..."));
            Assert.That(registry.registry.InstalledFileInfo(), Is.Not.Empty);
        }

        [Test]
        public void RepairRegistryScansAutodetectedDllsAndLeavesDisposableCache()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath);
            using var repoData = new TemporaryRepositoryData(user);
            using (var emptyRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager))
            {
                emptyRegistry.Save();
            }
            var dllPath = Path.Combine(
                instance.KSP.Game.PrimaryModDirectory(instance.KSP),
                "RepairDetected.dll");
            File.WriteAllText(dllPath, "not a real dll");
            var module = TestData.DogeCoinFlag_101_module();
            using (var cache = new NetModuleCache(config.DownloadCacheDir!))
            {
                cache.Store(module, TestData.DogeCoinFlagZip(), null);
            }
            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var beforeCache = provider.CacheInfo();
            var result = provider.RepairRegistry(instance.KSP.Name);
            var afterCache = provider.CacheInfo();
            using var registry = RegistryManager.Instance(instance.KSP, repoData.Manager);

            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Events.Select(evt => evt.Message), Does.Contain("Scanning GameData for unmanaged files..."));
            Assert.That(registry.registry.InstalledDlls, Does.Contain("RepairDetected"));
            Assert.That(registry.registry.DllPath("RepairDetected"), Is.EqualTo("GameData/RepairDetected.dll"));
            Assert.That(afterCache.FileCount, Is.EqualTo(beforeCache.FileCount));
            Assert.That(afterCache.Bytes, Is.EqualTo(beforeCache.Bytes));
        }

        [Test]
        public void ListInstallationHistoryReadsDisposableInstanceSnapshotsAndRegistryMetadata()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(HistoryExactOld, HistoryExactNew, HistoryLatest);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            var snapshotPath = Path.Combine(instance.KSP.InstallHistoryDir, "installed-PrimaryKSP-test.ckan");
            File.WriteAllText(snapshotPath, HistorySnapshot);

            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var result = provider.ListInstallationHistory(instance.KSP.Name);
            var entry = result.Entries.Single();
            var exact = entry.Modules.Single(module => module.Identifier == "HistoryExact");
            var latest = entry.Modules.Single(module => module.Identifier == "HistoryLatest");
            var missing = entry.Modules.Single(module => module.Identifier == "HistoryMissing");

            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(entry.FileName, Is.EqualTo("installed-PrimaryKSP-test.ckan"));
            Assert.That(exact.Name, Is.EqualTo("History Exact"));
            Assert.That(exact.Version, Is.EqualTo("1.0.0"));
            Assert.That(exact.Abstract, Is.EqualTo("Older exact history module."));
            Assert.That(exact.IsAvailable, Is.True);
            Assert.That(exact.IsInstalled, Is.False);
            Assert.That(latest.Name, Is.EqualTo("History Latest"));
            Assert.That(latest.Version, Is.EqualTo("3.0.0"));
            Assert.That(latest.IsAvailable, Is.True);
            Assert.That(missing.Name, Is.EqualTo("HistoryMissing"));
            Assert.That(missing.Version, Is.EqualTo("9.9.9"));
            Assert.That(missing.IsAvailable, Is.False);
        }

        [Test]
        public void ScanAndListUnmanagedFilesReadsDisposableInstanceDllsAndDlcs()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using (var emptyRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager))
            {
                emptyRegistry.Save();
            }

            var dllPath = Path.Combine(
                instance.KSP.Game.PrimaryModDirectory(instance.KSP),
                "ExamplePlugin.dll");
            var dlcDirectory = Path.Combine(instance.KSP.CkanDir, "dlc");
            Directory.CreateDirectory(dlcDirectory);
            File.WriteAllText(dllPath, "not a real dll");
            File.WriteAllText(Path.Combine(dlcDirectory, "ExampleExpansion.dlc"), "1.2.3");

            var provider = new CoreMackanMaintenanceProvider(config, repoData.Manager);

            var scan = provider.ScanGameData(instance.KSP.Name);
            var result = provider.ListUnmanagedFiles(instance.KSP.Name);
            var dll = result.Files.Single(file => file.Identifier == "ExamplePlugin");
            var dlc = result.Files.Single(file => file.Identifier == "ExampleExpansion-DLC");

            Assert.That(scan.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(scan.Changed, Is.True);
            Assert.That(scan.DetectedDllCount, Is.EqualTo(1));
            Assert.That(scan.DetectedDlcCount, Is.EqualTo(1));
            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(result.Changed, Is.False);
            Assert.That(dll.Kind, Is.EqualTo("dll"));
            Assert.That(dll.Version, Is.Null);
            Assert.That(dll.Path, Is.EqualTo("GameData/ExamplePlugin.dll"));
            Assert.That(dlc.Kind, Is.EqualTo("dlc"));
            Assert.That(dlc.Version, Is.EqualTo("1.2.3 (unmanaged)"));
            Assert.That(dlc.Path, Is.Null);
        }

        [Test]
        public void ListAndUpdatePlayTimeUseDisposableInstancePlaytimeJson()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var existing = new TimeLog
            {
                Time = TimeSpan.FromHours(2.5),
            };
            existing.Save(TimeLog.GetPath(instance.KSP.CkanDir));

            var provider = new CoreMackanMaintenanceProvider(
                config,
                new RepositoryDataManager());

            var listed = provider.ListPlayTime();
            var updated = provider.UpdatePlayTime(instance.KSP.Name, 4.5);
            var saved = TimeLog.Load(TimeLog.GetPath(instance.KSP.CkanDir));

            Assert.That(listed.Entries, Has.Length.EqualTo(1));
            Assert.That(listed.Entries[0].InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(listed.Entries[0].Hours, Is.EqualTo(2.5));
            Assert.That(listed.Entries[0].Display, Is.EqualTo("2.5"));
            Assert.That(listed.TotalHours, Is.EqualTo(2.5));
            Assert.That(listed.TotalDisplay, Is.EqualTo("2.5"));
            Assert.That(updated.Entries, Has.Length.EqualTo(1));
            Assert.That(updated.Entries[0].Hours, Is.EqualTo(4.5));
            Assert.That(updated.Entries[0].Display, Is.EqualTo("4.5"));
            Assert.That(saved?.Time.TotalHours, Is.EqualTo(4.5).Within(0.0001));
        }

        private static void InstallMissionModule(
            GameInstance instance,
            GameInstanceManager manager,
            FakeConfiguration config,
            RegistryManager registry,
            CkanModule module)
        {
            var installer = new ModuleInstaller(instance, manager.Cache!, config, user: new NullUser());
            HashSet<string>? possibleConfigOnlyDirs = null;
            installer.InstallList(
                new List<CkanModule> { module },
                RelationshipResolverOptions.DependsOnlyOpts(instance.StabilityToleranceConfig),
                registry,
                ref possibleConfigOnlyDirs);
        }

        private static IEnumerable<string> AbsoluteInstalledPaths(GameInstance instance, Registry registry)
            => registry.InstalledFileInfo()
                .Select(ifi => ifi.relPath)
                .Select(instance.ToAbsoluteGameDir)
                .Where(File.Exists);

        private static int MultiLinkedFileCount(IEnumerable<string> absolutePaths)
            => HardLink.GetLinkCounts(absolutePaths)
                .Count(links => links > 1);
    }
}

#endif

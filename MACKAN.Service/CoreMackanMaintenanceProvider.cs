using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using Autofac;

using CKAN.Configuration;
using CKAN.Games;
using CKAN.IO;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanMaintenanceProvider : IMackanMaintenanceProvider
    {
        public CoreMackanMaintenanceProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanMaintenanceProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanMaintenanceScanResult ScanGameData(string? instanceId)
        {
            using var scan = Scan(instanceId);

            return new MackanMaintenanceScanResult(
                scan.Instance.Name,
                scan.Changed,
                scan.Registry.InstalledDlls.Count,
                scan.Registry.InstalledDlc.Count);
        }

        public MackanUnmanagedFilesResult ListUnmanagedFiles(string? instanceId)
        {
            using var scan = Scan(instanceId);
            var files = scan.Registry.InstalledDlls
                .OrderBy(identifier => identifier)
                .Select(identifier => new MackanUnmanagedFileSummary(
                    identifier,
                    "dll",
                    null,
                    scan.Registry.DllPath(identifier)))
                .Concat(scan.Registry.InstalledDlc
                    .OrderBy(kvp => kvp.Key)
                    .Select(kvp => new MackanUnmanagedFileSummary(
                        kvp.Key,
                        "dlc",
                        kvp.Value.ToString(),
                        null)))
                .ToArray();

            return new MackanUnmanagedFilesResult(
                scan.Instance.Name,
                scan.Changed,
                files);
        }

        public MackanInstallationHistoryResult ListInstallationHistory(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            if (!Directory.Exists(instance.InstallHistoryDir))
            {
                return new MackanInstallationHistoryResult(
                    instance.Name,
                    Array.Empty<MackanInstallationHistoryEntrySummary>());
            }

            var entries = instance.InstallHistoryFiles()
                .Select(HistoryEntrySummary)
                .ToArray();

            return new MackanInstallationHistoryResult(instance.Name, entries);
        }

        public MackanInstallationHistoryEntry LoadInstallationHistoryEntry(string? instanceId, string fileName)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }
            if (string.IsNullOrWhiteSpace(fileName))
            {
                throw new ArgumentException("History file name is required.");
            }

            var file = Directory.Exists(instance.InstallHistoryDir)
                ? instance.InstallHistoryFiles()
                    .FirstOrDefault(candidate => StringComparer.Ordinal.Equals(candidate.Name, fileName))
                : null;
            if (file == null)
            {
                throw new ArgumentException($"Installation history snapshot '{fileName}' was not found.");
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            return HistoryEntry(file, instance, registry);
        }

        public MackanPlayTimeResult ListPlayTime()
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            return PlayTimeResult(manager);
        }

        public MackanPlayTimeResult UpdatePlayTime(string instanceId, double hours)
        {
            if (string.IsNullOrWhiteSpace(instanceId) || hours < 0 || double.IsNaN(hours) || double.IsInfinity(hours))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            if (!manager.Instances.TryGetValue(instanceId, out var instance))
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            instance.playTime ??= new TimeLog();
            instance.playTime.Time = TimeSpan.FromHours(hours);
            Directory.CreateDirectory(instance.CkanDir);
            instance.playTime.Save(TimeLog.GetPath(instance.CkanDir));

            return PlayTimeResult(manager);
        }

        public MackanDownloadStatisticsResult DownloadStatistics(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            var cache = manager.Cache
                ?? throw new InvalidOperationException("Download cache is not available.");
            var bytesByHost = registry == null
                ? Array.Empty<MackanDownloadStatisticsHost>()
                : cache.CachedFileSizeByHost(registry.GetDownloadUrlsByHash())
                    .OrderByDescending(kvp => kvp.Value)
                    .ThenBy(kvp => kvp.Key, StringComparer.OrdinalIgnoreCase)
                    .Select(kvp => new MackanDownloadStatisticsHost(
                        kvp.Key,
                        kvp.Value,
                        CkanModule.FmtSize(kvp.Value)))
                    .ToArray();
            var totalBytes = bytesByHost.Sum(host => host.Bytes);
            return new MackanDownloadStatisticsResult(
                instance.Name,
                bytesByHost,
                totalBytes,
                CkanModule.FmtSize(totalBytes));
        }

        public MackanCacheInfoResult CacheInfo()
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            return CacheInfo(manager);
        }

        public MackanCachePurgeResult ClearCache()
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var before = CacheInfo(manager);
            var cache = manager.Cache
                ?? throw new InvalidOperationException("Download cache is not available.");
            cache.RemoveAll();
            var after = CacheInfo(manager);
            return CachePurgeResult("all", before, after);
        }

        public MackanCachePurgeResult PurgeCacheToLimit(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var before = CacheInfo(manager);
            if (manager.Configuration.CacheSizeLimit is not long limit)
            {
                return CachePurgeResult("limit", before, before);
            }

            var cache = manager.Cache
                ?? throw new InvalidOperationException("Download cache is not available.");
            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData)
                ?? throw new InvalidOperationException("Registry is not available.");
            cache.EnforceSizeLimit(limit, registry);
            var after = CacheInfo(manager);
            return CachePurgeResult("limit", before, after);
        }

        public MackanDeduplicateResult Deduplicate()
        {
            var events = new MaintenanceEventRecorder();
            try
            {
                using var manager = new GameInstanceManager(
                    events,
                    configuration);
                events.RaiseMessage("Scanning for duplicate installed files...");
                var deduper = new InstalledFilesDeduplicator(manager.Instances.Values, repositoryData);
                deduper.DeduplicateAll(events);
                return new MackanDeduplicateResult("completed", events.Events, null);
            }
            catch (CancelledActionKraken cancelled)
            {
                return new MackanDeduplicateResult("cancelled", events.Events, cancelled.Message);
            }
            catch (Exception exception)
            {
                events.RaiseError(exception.Message);
                return new MackanDeduplicateResult("failed", events.Events, exception.Message);
            }
        }

        public MackanRepairRegistryResult RepairRegistry(string? instanceId)
        {
            var events = new MaintenanceEventRecorder();
            using var manager = new GameInstanceManager(
                events,
                configuration);
            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            try
            {
                events.RaiseMessage("Repairing CKAN registry...");
                using var registryManager = RegistryManager.Instance(instance, repositoryData);
                registryManager.registry.Repair();
                events.RaiseMessage("Scanning GameData for unmanaged files...");
                registryManager.ScanUnmanagedFiles();
                registryManager.Save();
                events.RaiseMessage("Registry repairs attempted. Hope it helped.");
                return new MackanRepairRegistryResult(instance.Name, "completed", events.Events, null);
            }
            catch (CancelledActionKraken cancelled)
            {
                return new MackanRepairRegistryResult(instance.Name, "cancelled", events.Events, cancelled.Message);
            }
            catch (Exception exception)
            {
                events.RaiseError(exception.Message);
                return new MackanRepairRegistryResult(instance.Name, "failed", events.Events, exception.Message);
            }
        }

        public MackanRegistryLockRemovalResult RemoveRegistryLock(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var lockfilePath = Path.Combine(instance.CkanDir, "registry.locked");
            if (!File.Exists(lockfilePath))
            {
                return new MackanRegistryLockRemovalResult(
                    instance.Name,
                    lockfilePath,
                    "notFound",
                    false);
            }

            File.Delete(lockfilePath);
            return new MackanRegistryLockRemovalResult(
                instance.Name,
                lockfilePath,
                "removed",
                true);
        }

        private ScanContext Scan(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var registryManager = RegistryManager.Instance(instance, repositoryData);
            var changed = registryManager.ScanUnmanagedFiles();
            if (changed)
            {
                registryManager.Save();
            }

            return new ScanContext(instance, registryManager, changed);
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;

        private static GameInstance? SelectInstance(GameInstanceManager manager, string? instanceId)
        {
            if (!string.IsNullOrWhiteSpace(instanceId))
            {
                return manager.Instances.TryGetValue(instanceId, out var selected)
                    ? selected
                    : null;
            }

            var defaultId = manager.Configuration.AutoStartInstance;
            if (!string.IsNullOrWhiteSpace(defaultId)
                && manager.Instances.TryGetValue(defaultId, out var defaultInstance))
            {
                return defaultInstance;
            }

            return manager.Instances.Count == 1 ? manager.Instances.Values.First() : null;
        }

        private static MackanCacheInfoResult CacheInfo(GameInstanceManager manager)
        {
            var cache = manager.Cache
                ?? throw new InvalidOperationException("Download cache is not available.");
            cache.GetSizeInfo(out var fileCount, out var bytes, out var freeBytes);
            var limitBytes = manager.Configuration.CacheSizeLimit;
            return new MackanCacheInfoResult(
                manager.Configuration.DownloadCacheDir ?? GameInstanceManager.DefaultDownloadCacheDir,
                fileCount,
                bytes,
                CkanModule.FmtSize(bytes),
                freeBytes,
                freeBytes.HasValue ? CkanModule.FmtSize(freeBytes.Value) : null,
                limitBytes,
                limitBytes.HasValue ? CkanModule.FmtSize(limitBytes.Value) : null,
                limitBytes.HasValue && bytes > limitBytes.Value);
        }

        private static MackanCachePurgeResult CachePurgeResult(
            string mode,
            MackanCacheInfoResult before,
            MackanCacheInfoResult after)
        {
            var purgedBytes = Math.Max(0, before.Bytes - after.Bytes);
            return new MackanCachePurgeResult(
                mode,
                Math.Max(0, before.FileCount - after.FileCount),
                purgedBytes,
                CkanModule.FmtSize(purgedBytes),
                after);
        }

        private sealed class MaintenanceEventRecorder : IUser
        {
            public bool Headless => false;

            public MackanOperationEvent[] Events
            {
                get
                {
                    lock (events)
                    {
                        return events.ToArray();
                    }
                }
            }

            public bool RaiseYesNoDialog(string question)
            {
                Add("prompt", question, null, null, null, null);
                return true;
            }

            public int RaiseSelectionDialog(string message, params object[] args)
            {
                Add("prompt", string.Format(message, args), null, null, null, null);
                return 0;
            }

            public void RaiseError(string message, params object[] args)
                => Add("error", string.Format(message, args), null, null, null, null);

            public void RaiseProgress(string message, int percent)
                => Add("progress", message, percent, null, null, null);

            public void RaiseProgress(ByteRateCounter rateCounter)
                => Add("progress", rateCounter.Summary, rateCounter.Percent, null, rateCounter.BytesLeft, rateCounter.Size);

            public void RaiseMessage(string message, params object[] args)
                => Add("message", string.Format(message, args), null, null, null, null);

            private void Add(
                string kind,
                string message,
                int? percent,
                string? identifier,
                long? remainingBytes,
                long? totalBytes)
            {
                lock (events)
                {
                    events.Add(new MackanOperationEvent(
                        kind,
                        message,
                        percent,
                        identifier,
                        remainingBytes,
                        totalBytes));
                }
            }

            private readonly List<MackanOperationEvent> events = new();
        }

        private static MackanInstallationHistoryEntry HistoryEntry(
            FileInfo file,
            GameInstance instance,
            Registry? registry)
        {
            try
            {
                var modules = CkanModule.FromFile(file.FullName)
                    .depends
                    ?.OfType<ModuleRelationshipDescriptor>()
                    .Select(relationship => HistoryModule(
                        relationship,
                        registry,
                        instance.StabilityToleranceConfig,
                        instance.VersionCriteria()))
                    .OrderBy(module => module.Name, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(module => module.Identifier, StringComparer.OrdinalIgnoreCase)
                    .ToArray()
                    ?? Array.Empty<MackanInstallationHistoryModule>();
                return new MackanInstallationHistoryEntry(
                    file.Name,
                    file.CreationTimeUtc.ToString("O"),
                    modules);
            }
            catch
            {
                return new MackanInstallationHistoryEntry(
                    file.Name,
                    file.CreationTimeUtc.ToString("O"),
                    Array.Empty<MackanInstallationHistoryModule>());
            }
        }

        private static MackanInstallationHistoryEntrySummary HistoryEntrySummary(FileInfo file)
        {
            try
            {
                var moduleCount = CkanModule.FromFile(file.FullName)
                    .depends
                    ?.OfType<ModuleRelationshipDescriptor>()
                    .Count()
                    ?? 0;
                return new MackanInstallationHistoryEntrySummary(
                    file.Name,
                    file.CreationTimeUtc.ToString("O"),
                    moduleCount);
            }
            catch
            {
                return new MackanInstallationHistoryEntrySummary(
                    file.Name,
                    file.CreationTimeUtc.ToString("O"),
                    0);
            }
        }

        private static MackanInstallationHistoryModule HistoryModule(
            ModuleRelationshipDescriptor relationship,
            Registry? registry,
            StabilityToleranceConfig stabilityTolerance,
            GameVersionCriteria criteria)
        {
            var module = registry != null && relationship.version != null
                ? registry.GetModuleByVersion(relationship.name, relationship.version)
                  ?? SaneLatestAvailable(registry, relationship.name, stabilityTolerance, criteria)
                : registry != null
                    ? SaneLatestAvailable(registry, relationship.name, stabilityTolerance, criteria)
                    : null;
            return new MackanInstallationHistoryModule(
                relationship.name,
                ModuleName(module, relationship.name),
                HistoryVersion(relationship, module),
                module?.author is { Count: > 0 } authors
                    ? string.Join(", ", authors)
                    : null,
                module?.@abstract,
                registry?.IsInstalled(relationship.name, false) ?? false,
                module != null);
        }

        private static CkanModule? SaneLatestAvailable(
            Registry registry,
            string identifier,
            StabilityToleranceConfig stabilityTolerance,
            GameVersionCriteria criteria)
        {
            try
            {
                return registry.LatestAvailable(identifier, stabilityTolerance, criteria);
            }
            catch
            {
                try
                {
                    return registry.LatestAvailable(identifier, stabilityTolerance, null);
                }
                catch
                {
                    return null;
                }
            }
        }

        private static string ModuleName(CkanModule? module, string fallbackIdentifier)
            => module == null || string.IsNullOrWhiteSpace(module.name)
                ? fallbackIdentifier
                : module.name;

        private static string? HistoryVersion(ModuleRelationshipDescriptor relationship, CkanModule? module)
            => relationship.version?.ToString()
               ?? module?.version.ToString()
               ?? relationship.min_version?.ToString()
               ?? relationship.max_version?.ToString();

        private static MackanPlayTimeResult PlayTimeResult(GameInstanceManager manager)
        {
            var entries = manager.Instances.Values
                .OrderBy(instance => instance.Name, StringComparer.CurrentCultureIgnoreCase)
                .Select(instance => new MackanPlayTimeEntry(
                    instance.Name,
                    instance.Name,
                    instance.GameDir,
                    (instance.playTime?.Time ?? TimeSpan.Zero).TotalHours,
                    (instance.playTime ?? new TimeLog()).ToString()))
                .ToArray();
            var total = entries.Sum(entry => entry.Hours);
            return new MackanPlayTimeResult(
                entries,
                total,
                total.ToString("N1"));
        }

        private sealed class ScanContext : IDisposable
        {
            public ScanContext(GameInstance instance, RegistryManager registryManager, bool changed)
            {
                Instance = instance;
                RegistryManager = registryManager;
                Changed = changed;
            }

            public GameInstance Instance { get; }
            public RegistryManager RegistryManager { get; }
            public Registry Registry => RegistryManager.registry;
            public bool Changed { get; }

            public void Dispose()
            {
                RegistryManager.Dispose();
            }
        }
    }
}

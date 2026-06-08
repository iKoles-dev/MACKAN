using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Globalization;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Autofac;

using CKAN.Configuration;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanModuleProvider : IMackanModuleProvider
    {
        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;

        public CoreMackanModuleProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanModuleProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanModulesResult ListModules(string? instanceId)
        {
            var events = new ModuleListEventRecorder();
            return ListModulesCore(instanceId, events, CancellationToken.None);
        }

        public MackanModuleListOperationResult StartListModules(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var operationId = Guid.NewGuid().ToString("N");
            var events = new ModuleListEventRecorder();
            var cancellation = new CancellationTokenSource();
            var state = ModuleListOperationState.Running(operationId, instance.Name, events, cancellation);
            ListOperations[operationId] = state;
            events.Queued();

            _ = Task.Run(() =>
            {
                MackanModuleListOperationResult result;
                try
                {
                    var modulesResult = ListModulesCore(instanceId, events, cancellation.Token);
                    result = new MackanModuleListOperationResult(
                        operationId,
                        modulesResult.InstanceId,
                        "completed",
                        modulesResult.Modules,
                        events.Events,
                        null);
                }
                catch (OperationCanceledException)
                {
                    result = new MackanModuleListOperationResult(
                        operationId,
                        instance.Name,
                        "cancelled",
                        Array.Empty<MackanModuleSummary>(),
                        events.Events,
                        "Catalog loading was cancelled.");
                }
                catch (Exception exception)
                {
                    result = new MackanModuleListOperationResult(
                        operationId,
                        instance.Name,
                        "failed",
                        Array.Empty<MackanModuleSummary>(),
                        events.Events,
                        exception.Message);
                }

                state.Complete(result);
                ListOperations[operationId] = ModuleListOperationState.Final(result);
            });

            return state.Snapshot();
        }

        public MackanModuleListOperationResult GetListStatus(string operationId)
            => ListOperations.TryGetValue(operationId, out var state)
                ? state.Snapshot()
                : throw new ArgumentException($"Module list operation '{operationId}' was not found.");

        public MackanModuleListOperationResult CancelList(string operationId)
        {
            if (!ListOperations.TryGetValue(operationId, out var state))
            {
                throw new ArgumentException($"Module list operation '{operationId}' was not found.");
            }

            state.Cancel();
            return state.Snapshot();
        }

        private MackanModulesResult ListModulesCore(
            string? instanceId,
            ModuleListEventRecorder events,
            CancellationToken cancellationToken)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                return new MackanModulesResult(instance?.Name ?? instanceId, Array.Empty<MackanModuleSummary>());
            }

            events.OpeningRegistry();
            cancellationToken.ThrowIfCancellationRequested();
            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            if (registry == null)
            {
                return new MackanModulesResult(instance.Name, Array.Empty<MackanModuleSummary>());
            }

            events.ClassifyingModules();
            cancellationToken.ThrowIfCancellationRequested();
            var context = LoadModuleContext(instance, registry);
            var candidates = context.Compatible.Values
                                    .Concat(context.Incompatible.Values)
                                    .Concat(context.Installed.Values.Select(mod => mod.Module))
                                    .GroupBy(mod => mod.identifier, StringComparer.OrdinalIgnoreCase)
                                    .Select(group => group.First())
                                    .ToArray();
            var summaries = new List<MackanModuleSummary>(candidates.Length);
            var processed = 0;
            foreach (var module in candidates)
            {
                cancellationToken.ThrowIfCancellationRequested();
                summaries.Add(ToSummary(
                    instance,
                    registry,
                    repositoryData,
                    manager.Cache,
                    module,
                    context.Installed,
                    context.Compatible,
                    context.Incompatible,
                    includeExpensiveDetails: false));
                processed += 1;
                if (processed == 1 || processed == candidates.Length || processed % 25 == 0)
                {
                    events.ModulesPrepared(processed, candidates.Length, module.identifier);
                }
            }

            events.SortingModules(candidates.Length);
            cancellationToken.ThrowIfCancellationRequested();
            var orderedSummaries = summaries
                .OrderBy(mod => mod.Name, StringComparer.CurrentCultureIgnoreCase)
                .ThenBy(mod => mod.Identifier, StringComparer.OrdinalIgnoreCase)
                .ToArray();
            events.Completed(orderedSummaries.Length);

            return new MackanModulesResult(instance.Name, orderedSummaries);
        }

        public MackanModuleDetailsResult GetModuleDetails(string? instanceId, string identifier)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ModuleNotFoundKraken(identifier);
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            if (registry == null)
            {
                throw new ModuleNotFoundKraken(identifier);
            }

            var context = LoadModuleContext(instance, registry);
            var module = context.Compatible.GetValueOrDefault(identifier)
                ?? context.Incompatible.GetValueOrDefault(identifier)
                ?? context.Installed.GetValueOrDefault(identifier)?.Module
                ?? throw new ModuleNotFoundKraken(identifier);

            return ToDetails(instance, registry, repositoryData, manager.Cache, module, context.Installed, context.Compatible, context.Incompatible);
        }

        public MackanModulesResult SetAutoInstalled(string? instanceId, string identifier, bool isAutoInstalled)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            using var registryManager = RegistryManager.Instance(instance, repositoryData);
            var installedModule = registryManager.registry.InstalledModule(identifier)
                ?? throw new ArgumentException($"Module '{identifier}' is not installed.");
            if (registryManager.registry.IsAutodetected(identifier))
            {
                throw new InvalidOperationException($"Module '{identifier}' is autodetected and cannot be marked auto-installed.");
            }
            if (installedModule.Module.IsDLC)
            {
                throw new InvalidOperationException($"Module '{identifier}' is DLC and cannot be marked auto-installed.");
            }

            installedModule.AutoInstalled = isAutoInstalled;
            registryManager.Save(false);

            return ListModules(instance.Name);
        }

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

        private static ModuleContext LoadModuleContext(GameInstance instance, Registry registry)
        {
            var stability = instance.StabilityToleranceConfig;
            var criteria = instance.VersionCriteria();
            var installed = registry.InstalledModules.ToDictionary(mod => mod.identifier, StringComparer.OrdinalIgnoreCase);
            var compatible = registry.CompatibleModules(stability, criteria).ToDictionary(mod => mod.identifier, StringComparer.OrdinalIgnoreCase);
            var incompatible = registry.IncompatibleModules(stability, criteria)
                                       .Where(mod => !compatible.ContainsKey(mod.identifier))
                                       .ToDictionary(mod => mod.identifier, StringComparer.OrdinalIgnoreCase);
            return new ModuleContext(installed, compatible, incompatible);
        }

        private static MackanModuleSummary ToSummary(
            GameInstance instance,
            Registry registry,
            RepositoryDataManager repoData,
            NetModuleCache? cache,
            CkanModule module,
            IReadOnlyDictionary<string, InstalledModule> installed,
            IReadOnlyDictionary<string, CkanModule> compatible,
            IReadOnlyDictionary<string, CkanModule> incompatible,
            bool includeExpensiveDetails = true)
        {
            installed.TryGetValue(module.identifier, out var installedModule);
            compatible.TryGetValue(module.identifier, out var compatibleModule);
            incompatible.TryGetValue(module.identifier, out var incompatibleModule);

            var latestModule = compatibleModule ?? incompatibleModule ?? module;
            var status = Status(installedModule, compatibleModule, incompatibleModule);
            var criteria = instance.VersionCriteria();
            var isInstalled = installedModule != null;
            var isCompatible = compatibleModule != null
                || installedModule?.Module.IsCompatible(criteria) == true;
            var hasUpdate = isInstalled
                && compatibleModule != null
                && compatibleModule.version > installedModule!.Module.version;
            var hasReplacement = isInstalled
                && registry.GetReplacement(installedModule!.Module, instance.StabilityToleranceConfig, criteria) != null;
            var isCached = latestModule.download is { Count: > 0 }
                && cache?.IsMaybeCachedZip(latestModule) == true;
            var downloadCount = repoData.GetDownloadCount(registry.Repositories.Values, latestModule.identifier);

            return new MackanModuleSummary(
                module.identifier,
                latestModule.name,
                string.Join(", ", latestModule.author ?? Enumerable.Empty<string>()),
                status,
                installedModule?.Module.version.ToString() ?? "-",
                latestModule.version.ToString(),
                string.Join(", ", latestModule.license?.Select(license => license.ToString()) ?? Enumerable.Empty<string>()),
                Relationships(latestModule),
                includeExpensiveDetails
                    ? Versions(registry, latestModule)
                    : new[] { latestModule.version.ToString() },
                includeExpensiveDetails
                    ? Contents(instance, latestModule, installedModule)
                    : InstalledContents(installedModule),
                isInstalled,
                isCompatible,
                isCached,
                false,
                hasUpdate,
                hasReplacement,
                Tags(latestModule),
                latestModule.@abstract ?? "",
                latestModule.description ?? "",
                latestModule.localizations?.OrderBy(localization => localization, StringComparer.OrdinalIgnoreCase).ToArray()
                    ?? Array.Empty<string>(),
                includeExpensiveDetails
                    ? GameCompatibility(instance, registry, latestModule)
                    : ModuleGameCompatibility(instance, latestModule),
                latestModule.download_size,
                SizeDisplay(latestModule.download_size),
                latestModule.install_size,
                SizeDisplay(latestModule.install_size),
                latestModule.release_date?.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture) ?? "",
                installedModule?.InstallTime.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture) ?? "",
                downloadCount == 0 ? null : downloadCount,
                installedModule?.AutoInstalled ?? false,
                registry.IsAutodetected(module.identifier));
        }

        private static MackanModuleDetailsResult ToDetails(
            GameInstance instance,
            Registry registry,
            RepositoryDataManager repoData,
            NetModuleCache? cache,
            CkanModule module,
            IReadOnlyDictionary<string, InstalledModule> installed,
            IReadOnlyDictionary<string, CkanModule> compatible,
            IReadOnlyDictionary<string, CkanModule> incompatible)
        {
            var summary = ToSummary(instance, registry, repoData, cache, module, installed, compatible, incompatible);
            return new MackanModuleDetailsResult(
                instance.Name,
                summary,
                module.@abstract ?? "",
                module.description ?? "",
                module.release_status?.ToString() ?? "",
                module.kind.ToString(),
                module.release_date?.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture) ?? "",
                module.download_size,
                module.install_size,
                Resources(module.resources),
                module.Tags?.OrderBy(tag => tag, StringComparer.OrdinalIgnoreCase).ToArray()
                    ?? Array.Empty<string>());
        }

        private static string Status(InstalledModule? installedModule, CkanModule? compatibleModule, CkanModule? incompatibleModule)
        {
            if (installedModule != null)
            {
                if (compatibleModule != null && compatibleModule.version > installedModule.Module.version)
                {
                    return "upgradable";
                }
                return "installed";
            }
            return compatibleModule != null ? "available" : "incompatible";
        }

        private static MackanModuleRelationship[] Relationships(CkanModule module)
            => RelationshipGroup("Depends", module.depends)
                .Concat(RelationshipGroup("Recommends", module.recommends))
                .Concat(RelationshipGroup("Suggests", module.suggests))
                .Concat(RelationshipGroup("Supports", module.supports))
                .Concat(RelationshipGroup("Conflicts", module.conflicts))
                .ToArray();

        private static IEnumerable<MackanModuleRelationship> RelationshipGroup(
            string kind,
            IEnumerable<RelationshipDescriptor>? relationships)
            => relationships?.Select(rel => new MackanModuleRelationship(kind, rel.ToString() ?? ""))
               ?? Enumerable.Empty<MackanModuleRelationship>();

        private static string[] Versions(Registry registry, CkanModule module)
        {
            try
            {
                var versions = registry.AvailableByIdentifier(module.identifier)
                                       .Select(mod => mod.version.ToString())
                                       .Distinct()
                                       .Take(20)
                                       .ToArray();
                return versions.Length > 0 ? versions : new[] { module.version.ToString() };
            }
            catch (ModuleNotFoundKraken)
            {
                return new[] { module.version.ToString() };
            }
        }

        private static string[] Contents(GameInstance instance, CkanModule module, InstalledModule? installedModule)
            => installedModule?.Files.OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                              .Take(50)
                              .ToArray()
               ?? module.GetInstallStanzas(instance.Game)
                        .Select(stanza => stanza.install_to + "/" + (stanza.@as ?? stanza.find ?? stanza.file ?? stanza.find_regexp ?? module.identifier))
                        .Distinct()
                        .Take(50)
                        .ToArray();

        private static string[] InstalledContents(InstalledModule? installedModule)
            => installedModule?.Files.OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                              .Take(50)
                              .ToArray()
               ?? Array.Empty<string>();

        private static string[] Tags(CkanModule module)
            => module.Tags?.OrderBy(tag => tag, StringComparer.OrdinalIgnoreCase).ToArray()
               ?? Array.Empty<string>();

        private static string SizeDisplay(long bytes)
            => bytes > 0 ? CkanModule.FmtSize(bytes) : "";

        private static string GameCompatibility(GameInstance instance, Registry registry, CkanModule module)
        {
            var version = GameCompatibilityVersion(instance, registry, module);
            if (version == null)
            {
                return "Unknown";
            }
            return version.IsAny ? GameVersion.AnyString ?? "Any" : version.ToString() ?? "";
        }

        private static string ModuleGameCompatibility(GameInstance instance, CkanModule module)
        {
            var version = module.LatestCompatibleGameVersion();
            if (version.IsAny)
            {
                version = module.LatestCompatibleRealGameVersion(instance.Game.KnownVersions);
            }

            return version.IsAny ? GameVersion.AnyString ?? "Any" : version.ToString() ?? "";
        }

        private static GameVersion? GameCompatibilityVersion(GameInstance instance, Registry registry, CkanModule module)
        {
            try
            {
                var registryVersion = registry.LatestCompatibleGameVersion(instance.Game.KnownVersions, module.identifier);
                if (registryVersion != null)
                {
                    return registryVersion;
                }
            }
            catch
            {
                // DarkKAN or incomplete metadata can fail this lookup; fall back to module metadata.
            }

            var version = module.LatestCompatibleGameVersion();
            return version.IsAny
                ? module.LatestCompatibleRealGameVersion(instance.Game.KnownVersions)
                : version;
        }

        private static MackanModuleResource[] Resources(ResourcesDescriptor? resources)
        {
            if (resources == null)
            {
                return Array.Empty<MackanModuleResource>();
            }

            return new (string label, Uri? url)[]
                {
                    ("Homepage", resources.homepage),
                    ("SpaceDock", resources.spacedock),
                    ("Curse", resources.curse),
                    ("Repository", resources.repository),
                    ("Bug Tracker", resources.bugtracker),
                    ("Discussions", resources.discussions),
                    ("CI", resources.ci),
                    ("License", resources.license),
                    ("Manual", resources.manual),
                    ("MetaNetKAN", resources.metanetkan),
                    ("Remote AVC", resources.remoteAvc),
                    ("Remote SWInfo", resources.remoteSWInfo),
                    ("Store", resources.store),
                    ("Steam Store", resources.steamstore),
                    ("GOG Store", resources.gogstore),
                    ("Epic Store", resources.epicstore),
                }
                .Where(resource => resource.url != null)
                .Select(resource => new MackanModuleResource(resource.label, resource.url!.ToString()))
                .ToArray();
        }

        private sealed class ModuleListEventRecorder
        {
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

            public void Queued()
                => Add("message", "Catalog loading queued", 0, null, null, null, null, null);

            public void OpeningRegistry()
                => Add("progress", "Reading CKAN registry", 5, null, null, null, null, null);

            public void ClassifyingModules()
                => Add("progress", "Classifying module compatibility", 20, null, null, null, null, null);

            public void ModulesPrepared(int completedCount, int totalCount, string identifier)
            {
                var percent = totalCount > 0
                    ? 20 + (int)Math.Round(70d * completedCount / totalCount)
                    : 90;
                Add(
                    "progress",
                    $"Preparing {completedCount} of {totalCount} mods",
                    Math.Clamp(percent, 20, 90),
                    identifier,
                    null,
                    null,
                    completedCount,
                    totalCount);
            }

            public void SortingModules(int totalCount)
                => Add(
                    "progress",
                    $"Sorting {totalCount} mods",
                    95,
                    null,
                    null,
                    null,
                    totalCount,
                    totalCount);

            public void Completed(int totalCount)
                => Add(
                    "progress",
                    $"Loaded {totalCount} mods",
                    100,
                    null,
                    null,
                    null,
                    totalCount,
                    totalCount);

            public void CancellationRequested()
                => Add("message", "Cancellation requested", null, null, null, null, null, null);

            private void Add(
                string kind,
                string message,
                int? percent,
                string? identifier,
                long? remainingBytes,
                long? totalBytes,
                int? completedCount,
                int? totalCount)
            {
                lock (events)
                {
                    events.Add(new MackanOperationEvent(
                        kind,
                        message,
                        percent,
                        identifier,
                        remainingBytes,
                        totalBytes,
                        completedCount,
                        totalCount));
                }
            }

            private readonly List<MackanOperationEvent> events = new();
        }

        private sealed class ModuleListOperationState
        {
            private ModuleListOperationState(
                string operationId,
                string? instanceId,
                string status,
                ModuleListEventRecorder? recorder,
                MackanModuleListOperationResult? result,
                CancellationTokenSource? cancellation)
            {
                OperationId = operationId;
                InstanceId = instanceId;
                this.status = status;
                this.recorder = recorder;
                this.result = result;
                this.cancellation = cancellation;
            }

            public string OperationId { get; }
            public string? InstanceId { get; }

            public static ModuleListOperationState Running(
                string operationId,
                string? instanceId,
                ModuleListEventRecorder recorder,
                CancellationTokenSource cancellation)
                => new ModuleListOperationState(operationId, instanceId, "running", recorder, null, cancellation);

            public static ModuleListOperationState Final(MackanModuleListOperationResult result)
                => new ModuleListOperationState(result.OperationId, result.InstanceId, result.Status, null, result, null);

            public MackanModuleListOperationResult Snapshot()
            {
                lock (lockObject)
                {
                    if (result != null)
                    {
                        return result;
                    }

                    return new MackanModuleListOperationResult(
                        OperationId,
                        InstanceId,
                        status,
                        Array.Empty<MackanModuleSummary>(),
                        recorder?.Events,
                        null);
                }
            }

            public void Cancel()
            {
                lock (lockObject)
                {
                    if (result != null)
                    {
                        return;
                    }

                    status = "cancelling";
                    recorder?.CancellationRequested();
                    cancellation?.Cancel();
                }
            }

            public void Complete(MackanModuleListOperationResult completedResult)
            {
                lock (lockObject)
                {
                    result = completedResult;
                    recorder = null;
                    cancellation?.Dispose();
                    cancellation = null;
                    status = completedResult.Status;
                }
            }

            private readonly object lockObject = new();
            private string status;
            private ModuleListEventRecorder? recorder;
            private MackanModuleListOperationResult? result;
            private CancellationTokenSource? cancellation;
        }

        private sealed class ModuleContext
        {
            public ModuleContext(
                IReadOnlyDictionary<string, InstalledModule> installed,
                IReadOnlyDictionary<string, CkanModule> compatible,
                IReadOnlyDictionary<string, CkanModule> incompatible)
            {
                Installed = installed;
                Compatible = compatible;
                Incompatible = incompatible;
            }

            public IReadOnlyDictionary<string, InstalledModule> Installed { get; }
            public IReadOnlyDictionary<string, CkanModule> Compatible { get; }
            public IReadOnlyDictionary<string, CkanModule> Incompatible { get; }
        }

        private static readonly ConcurrentDictionary<string, ModuleListOperationState> ListOperations = new();
    }
}

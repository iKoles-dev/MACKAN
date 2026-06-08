using System;
using System.Collections.Generic;
using System.Linq;

using Autofac;

using CKAN.Configuration;
using CKAN.Games;
using CKAN.IO;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanChangeSetProvider : IMackanChangeSetProvider
    {
        public CoreMackanChangeSetProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanChangeSetProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData,
            IReadOnlyCollection<Repository>? initialRepositories = null)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
            this.initialRepositories = initialRepositories ?? Array.Empty<Repository>();
        }

        public MackanChangeSetResult ResolveChanges(MackanChangeSetRequest request)
        {
            using var manager = new GameInstanceManager(new NullUser(), configuration);

            var instance = SelectInstance(manager, request.InstanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            if (registry == null)
            {
                return new MackanChangeSetResult(
                    instance.Name,
                    Array.Empty<MackanChangeSummary>(),
                    Array.Empty<MackanConflictSummary>(),
                    Array.Empty<string>());
            }

            ApplyInitialRepositories(registry, initialRepositories);
            return Resolve(instance, registry, request, configuration);
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;
        private readonly IReadOnlyCollection<Repository> initialRepositories;

        internal static void ApplyInitialRepositories(
            Registry registry,
            IReadOnlyCollection<Repository> initialRepositories)
        {
            if (initialRepositories.Count == 0)
            {
                return;
            }

            registry.RepositoriesSet(new SortedDictionary<string, Repository>(
                initialRepositories.ToDictionary(repository => repository.name ?? string.Empty, repository => repository)));
        }

        private static MackanChangeSetResult Resolve(
            GameInstance requestInstance,
            Registry registry,
            MackanChangeSetRequest request,
            IConfiguration configuration)
        {
            var stability = requestInstance.StabilityToleranceConfig;
            var criteria = requestInstance.VersionCriteria();
            var requestedChanges = new List<PlannedChange>();
            foreach (var selection in request.InstallVersions)
            {
                var module = ExactAvailable(registry, selection, criteria);
                requestedChanges.Add(new PlannedChange(module, "install", null, module, true, false, new[] { "User requested" }));
            }

            var exactInstallIdentifiers = request.InstallVersions
                .Select(selection => selection.Identifier)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            foreach (var identifier in request.Install)
            {
                if (exactInstallIdentifiers.Contains(identifier))
                {
                    continue;
                }
                var module = LatestAvailable(registry, identifier, stability, criteria);
                requestedChanges.Add(new PlannedChange(module, "install", null, module, true, false, new[] { "User requested" }));
            }

            foreach (var selection in request.ProviderSelections)
            {
                var module = LatestAvailable(registry, selection.SelectedIdentifier, stability, criteria);
                requestedChanges.Add(new PlannedChange(
                    module,
                    "install",
                    null,
                    module,
                    false,
                    true,
                    new[] { $"Provider for {selection.Requested} requested by {selection.RequesterIdentifier}" }));
            }

            foreach (var identifier in request.Remove)
            {
                var module = Installed(registry, identifier);
                requestedChanges.Add(new PlannedChange(module, "remove", module, null, true, false, new[] { "User requested" }));
            }

            foreach (var identifier in request.Upgrade)
            {
                var installed = Installed(registry, identifier);
                var target = UpgradeTarget(registry, requestInstance, identifier, configuration);
                requestedChanges.Add(new PlannedChange(installed, "upgrade", installed, target, true, false, new[] { "User requested" }));
            }

            foreach (var identifier in request.Replace)
            {
                var replacement = Replacement(registry, identifier, stability, criteria);
                requestedChanges.Add(new PlannedChange(
                    replacement.ToReplace,
                    "replace",
                    replacement.ToReplace,
                    replacement.ReplaceWith,
                    true,
                    false,
                    new[] { "User requested" }));
                requestedChanges.Add(new PlannedChange(
                    replacement.ReplaceWith,
                    "install",
                    null,
                    replacement.ReplaceWith,
                    false,
                    false,
                    new[] { $"Replacing {ModuleName(replacement.ToReplace)}" }));
            }

            var toInstall = requestedChanges
                .Where(change => change.ToModule != null)
                .Select(change => change.ToModule!)
                .GroupBy(module => module.identifier, StringComparer.OrdinalIgnoreCase)
                .Select(group => group.First())
                .ToList();
            var toRemove = requestedChanges
                .Where(change => change.Action == "remove" || change.Action == "replace")
                .Select(change => change.FromModule ?? change.Module)
                .ToHashSet();

            AddReverseDependencyRemovals(registry, requestInstance, requestedChanges, toInstall, toRemove);
            AddUnusedAutoRemovals(registry, requestInstance, requestedChanges, toRemove);

            var resolver = new RelationshipResolver(
                toInstall,
                toRemove,
                ConflictOptions(stability),
                registry,
                requestInstance.Game,
                criteria);
            var providerChoices = FindProviderChoices(
                toInstall,
                toRemove,
                registry,
                requestInstance,
                stability,
                criteria);

            var requestedInstallKeys = toInstall
                .Select(module => module.identifier)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            var resolvedChanges = requestedChanges.ToList();
            var resolvedInstallModules = resolver.ModList(false).ToArray();
            foreach (var module in resolvedInstallModules
                         .Where(module => !requestedInstallKeys.Contains(module.identifier)))
            {
                resolvedChanges.Add(new PlannedChange(
                    module,
                    "install",
                    null,
                    module,
                    false,
                    resolver.IsAutoInstalled(module),
                    DescribeReasons(resolver.ReasonsFor(module))));
            }
            var recommendationChoices = providerChoices.Length == 0
                ? FindRecommendationChoices(
                    requestInstance,
                    registry,
                    resolvedChanges,
                    resolvedInstallModules,
                    toRemove)
                : Array.Empty<MackanRecommendationChoice>();

            var summaries = resolvedChanges
                .GroupBy(change => (change.Action, change.Module.identifier))
                .Select(group => group.First())
                .OrderBy(change => change.Action)
                .ThenBy(change => change.Module.identifier, StringComparer.OrdinalIgnoreCase)
                .Select(ToSummary)
                .ToArray();

            var conflicts = resolver.ConflictList
                .Select(conflict => new MackanConflictSummary(
                    conflict.Key.identifier,
                    ModuleName(conflict.Key),
                    conflict.Value))
                .OrderBy(conflict => conflict.Identifier, StringComparer.OrdinalIgnoreCase)
                .ToArray();

            return new MackanChangeSetResult(
                requestInstance.Name,
                summaries,
                conflicts,
                resolver.ConflictDescriptions.ToArray(),
                providerChoices,
                recommendationChoices,
                MackanGuiConfigStore.SuppressRecommendations(requestInstance));
        }

        private static MackanRecommendationChoice[] FindRecommendationChoices(
            GameInstance instance,
            Registry registry,
            IReadOnlyCollection<PlannedChange> resolvedChanges,
            IReadOnlyCollection<CkanModule> resolvedInstallModules,
            IReadOnlyCollection<CkanModule> toRemove)
        {
            var sourceModules = DistinctModules(resolvedChanges
                .Where(change => change.Action == "install" || change.Action == "upgrade")
                .Select(change => change.ToModule ?? change.Module));
            if (sourceModules.Length == 0)
            {
                return Array.Empty<MackanRecommendationChoice>();
            }

            var fullInstallSet = DistinctModules(resolvedInstallModules
                .Concat(resolvedChanges
                    .Where(change => change.Action == "install" || change.Action == "upgrade")
                    .Select(change => change.ToModule ?? change.Module)));
            var fullRemoveSet = DistinctModules(toRemove);

            try
            {
                return ModuleInstaller.FindRecommendations(
                        instance,
                        sourceModules,
                        fullInstallSet,
                        fullRemoveSet,
                        Array.Empty<CkanModule>(),
                        registry,
                        out var recommendations,
                        out var suggestions,
                        out var supporters)
                    ? ToRecommendationChoices(recommendations, suggestions, supporters)
                    : Array.Empty<MackanRecommendationChoice>();
            }
            catch (TooManyModsProvideKraken)
            {
                return Array.Empty<MackanRecommendationChoice>();
            }
        }

        private static MackanProviderChoice[] FindProviderChoices(
            IReadOnlyCollection<CkanModule> toInstall,
            IReadOnlyCollection<CkanModule> toRemove,
            IRegistryQuerier registry,
            GameInstance instance,
            StabilityToleranceConfig stability,
            GameVersionCriteria criteria)
        {
            var choices = new List<MackanProviderChoice>();
            var probingInstall = toInstall.ToList();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            while (true)
            {
                try
                {
                    _ = new RelationshipResolver(
                            probingInstall,
                            toRemove,
                            ProviderChoiceOptions(stability),
                            registry,
                            instance.Game,
                            criteria)
                        .ModList(false)
                        .ToArray();
                    break;
                }
                catch (TooManyModsProvideKraken kraken)
                {
                    var key = $"{kraken.requester.identifier}\0{kraken.requested}";
                    if (!seen.Add(key))
                    {
                        break;
                    }

                    choices.Add(ToProviderChoice(kraken));
                    var probeSelection = kraken.modules.FirstOrDefault();
                    if (probeSelection == null)
                    {
                        break;
                    }
                    if (!probingInstall.Any(module => module.identifier.Equals(
                            probeSelection.identifier,
                            StringComparison.OrdinalIgnoreCase)))
                    {
                        probingInstall.Add(probeSelection);
                    }
                }
                catch (Kraken)
                {
                    break;
                }
            }

            return choices
                .OrderBy(choice => choice.RequesterIdentifier, StringComparer.OrdinalIgnoreCase)
                .ThenBy(choice => choice.Requested, StringComparer.OrdinalIgnoreCase)
                .ToArray();
        }

        private static void AddReverseDependencyRemovals(
            IRegistryQuerier registry,
            GameInstance instance,
            List<PlannedChange> changes,
            IReadOnlyCollection<CkanModule> toInstall,
            HashSet<CkanModule> toRemove)
        {
            var installedModules = registry.InstalledModules
                .ToDictionary(module => module.Module.identifier, module => module.Module, StringComparer.OrdinalIgnoreCase);
            var removing = toRemove
                .Select(module => module.identifier)
                .Except(toInstall.Select(module => module.identifier), StringComparer.OrdinalIgnoreCase)
                .ToArray();

            foreach (var dependent in registry.FindReverseDependencies(removing, toInstall))
            {
                if (installedModules.TryGetValue(dependent, out var module)
                    && !changes.Any(change => (change.Action == "remove" || change.Action == "replace")
                                             && change.Module.identifier.Equals(module.identifier, StringComparison.OrdinalIgnoreCase)))
                {
                    changes.Add(new PlannedChange(
                        module,
                        "remove",
                        module,
                        null,
                        false,
                        true,
                        new[] { new SelectionReason.DependencyRemoved().ToString() ?? "Dependency removed" }));
                    toRemove.Add(module);
                }
            }
        }

        private static void AddUnusedAutoRemovals(
            IRegistryQuerier registry,
            GameInstance instance,
            List<PlannedChange> changes,
            HashSet<CkanModule> toRemove)
        {
            var installedAfterChanges = InstalledAfterChanges(registry, changes).ToArray();
            foreach (var installed in registry.FindRemovableAutoInstalled(
                         installedAfterChanges,
                         Array.Empty<CkanModule>(),
                         instance.Game,
                         instance.StabilityToleranceConfig,
                         instance.VersionCriteria()))
            {
                if (!changes.Any(change => (change.Action == "remove" || change.Action == "replace")
                                          && change.Module.identifier.Equals(installed.Module.identifier, StringComparison.OrdinalIgnoreCase)))
                {
                    changes.Add(new PlannedChange(
                        installed.Module,
                        "remove",
                        installed.Module,
                        null,
                        false,
                        true,
                        new[] { new SelectionReason.NoLongerUsed().ToString() ?? "No longer used" }));
                    toRemove.Add(installed.Module);
                }
            }
        }

        private static IEnumerable<InstalledModule> InstalledAfterChanges(
            IRegistryQuerier registry,
            IReadOnlyCollection<PlannedChange> changes)
        {
            var removing = changes
                .Where(change => change.Action == "remove" || change.Action == "replace")
                .Select(change => change.Module.identifier)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            return registry.InstalledModules
                .Where(installed => !removing.Contains(installed.identifier))
                .Concat(changes
                    .Where(change => change.Action != "remove"
                                     && change.Action != "replace"
                                     && change.ToModule != null)
                    .Select(change => new InstalledModule(
                        null,
                        change.ToModule!,
                        Enumerable.Empty<string>(),
                        false)));
        }

        private static CkanModule LatestAvailable(
            IRegistryQuerier registry,
            string identifier,
            StabilityToleranceConfig stability,
            GameVersionCriteria criteria)
        {
            try
            {
                return registry.LatestAvailable(identifier, stability, criteria)
                    ?? throw new ArgumentException($"Module '{identifier}' is not available.");
            }
            catch (ModuleNotFoundKraken)
            {
                throw new ArgumentException($"Module '{identifier}' was not found.");
            }
        }

        private static CkanModule ExactAvailable(
            IRegistryQuerier registry,
            MackanModuleVersionSelection selection,
            GameVersionCriteria criteria)
        {
            var module = registry.GetModuleByVersion(selection.Identifier, new ModuleVersion(selection.Version));
            if (module == null)
            {
                throw new ArgumentException(
                    $"Module '{selection.Identifier}' version '{selection.Version}' was not found.");
            }
            if (!module.IsCompatible(criteria))
            {
                throw new ArgumentException(
                    $"Module '{selection.Identifier}' version '{selection.Version}' is not compatible with the selected instance.");
            }
            return module;
        }

        private static CkanModule Installed(IRegistryQuerier registry, string identifier)
            => registry.InstalledModule(identifier)?.Module
               ?? throw new ArgumentException($"Module '{identifier}' is not installed.");

        private static CkanModule UpgradeTarget(
            IRegistryQuerier registry,
            GameInstance instance,
            string identifier,
            IConfiguration configuration)
        {
            var held = registry.Installed(false)
                .Keys
                .Where(installed => !installed.Equals(identifier, StringComparison.OrdinalIgnoreCase))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            var filters = InstallFilters(instance, configuration);
            var unrestricted = registry.Installed(false)
                .Keys
                .Select(installed => !held.Contains(installed)
                    && registry.HasUpdate(
                        installed,
                        instance.StabilityToleranceConfig,
                        instance,
                        filters,
                        true,
                        out var latest)
                    && latest is not null
                    && !latest.IsDLC
                        ? latest
                        : registry.GetInstalledVersion(installed))
                .OfType<CkanModule>()
                .ToList();
            var upgradeable = registry.CheckUpgradeable(instance, held, unrestricted, filters)[true]
                .ToDictionary(module => module.identifier, module => module, StringComparer.OrdinalIgnoreCase);
            return upgradeable.TryGetValue(identifier, out var target)
                ? target
                : throw new ArgumentException($"Module '{identifier}' is not upgradeable.");
        }

        private static HashSet<string> InstallFilters(GameInstance instance, IConfiguration configuration)
            => configuration.GetGlobalInstallFilters(instance.Game)
                .Concat(instance.InstallFilters)
                .ToHashSet();

        private static ModuleReplacement Replacement(
            IRegistryQuerier registry,
            string identifier,
            StabilityToleranceConfig stability,
            GameVersionCriteria criteria)
            => registry.GetReplacement(identifier, stability, criteria)
               ?? throw new ArgumentException($"Module '{identifier}' does not have an available replacement.");

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

        private static RelationshipResolverOptions ConflictOptions(StabilityToleranceConfig stability)
            => new RelationshipResolverOptions(stability)
            {
                without_toomanyprovides_kraken = true,
                proceed_with_inconsistencies = true,
                without_enforce_consistency = true,
                with_recommends = false,
            };

        private static RelationshipResolverOptions ProviderChoiceOptions(StabilityToleranceConfig stability)
            => new RelationshipResolverOptions(stability)
            {
                without_toomanyprovides_kraken = false,
                without_enforce_consistency = true,
                with_recommends = false,
            };

        private static MackanChangeSummary ToSummary(PlannedChange change)
            => new MackanChangeSummary(
                change.Module.identifier,
                ModuleName(change.ToModule ?? change.Module),
                change.Action,
                change.FromModule?.version.ToString(),
                change.ToModule?.version.ToString(),
                change.Reasons,
                change.IsUserRequested,
                change.IsAuto);

        private static string[] DescribeReasons(IEnumerable<SelectionReason> reasons)
            => reasons.Select(reason => reason.ToString() ?? reason.GetType().Name)
                .Where(reason => !string.IsNullOrWhiteSpace(reason))
                .Distinct()
                .ToArray();

        private static string ModuleName(CkanModule module)
            => string.IsNullOrWhiteSpace(module.name) ? module.identifier : module.name;

        private static MackanProviderChoice ToProviderChoice(TooManyModsProvideKraken kraken)
            => MackanProviderChoiceFactory.From(kraken);

        private static MackanRecommendationChoice[] ToRecommendationChoices(
            Dictionary<CkanModule, Tuple<bool, List<string>>> recommendations,
            Dictionary<CkanModule, List<string>> suggestions,
            Dictionary<CkanModule, HashSet<string>> supporters)
            => MackanRecommendationChoiceFactory.From(recommendations, suggestions, supporters);

        private static CkanModule[] DistinctModules(IEnumerable<CkanModule> modules)
            => modules
                .GroupBy(module => module.identifier, StringComparer.OrdinalIgnoreCase)
                .Select(group => group.First())
                .ToArray();

        private sealed class PlannedChange
        {
            public PlannedChange(
                CkanModule module,
                string action,
                CkanModule? fromModule,
                CkanModule? toModule,
                bool isUserRequested,
                bool isAuto,
                string[] reasons)
            {
                Module = module;
                Action = action;
                FromModule = fromModule;
                ToModule = toModule;
                IsUserRequested = isUserRequested;
                IsAuto = isAuto;
                Reasons = reasons;
            }

            public CkanModule Module { get; }
            public string Action { get; }
            public CkanModule? FromModule { get; }
            public CkanModule? ToModule { get; }
            public bool IsUserRequested { get; }
            public bool IsAuto { get; }
            public string[] Reasons { get; }
        }
    }
}

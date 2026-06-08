using System;
using System.Collections.Generic;
using System.Linq;

using Autofac;

using CKAN.Configuration;
using CKAN.IO;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanSettingsProvider : IMackanSettingsProvider
    {
        public CoreMackanSettingsProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanSettingsProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanSettingsResult GetSettings()
        {
            return SettingsResult(configuration);
        }

        public MackanSettingsResult UpdateSettings(
            string? downloadCacheDir,
            long cacheSizeLimitBytes,
            string? cacheMigrationChoice = null)
        {
            using var manager = new GameInstanceManager(
                new CacheSettingsUser(cacheMigrationChoice),
                configuration);
            var requestedCacheDir = string.IsNullOrWhiteSpace(downloadCacheDir)
                || string.Equals(downloadCacheDir, GameInstanceManager.DefaultDownloadCacheDir, StringComparison.Ordinal)
                    ? null
                    : downloadCacheDir;

            if (!manager.TrySetupCache(requestedCacheDir, new Progress<int>(), out var failureReason))
            {
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(failureReason)
                    ? "Cache path update was cancelled."
                    : failureReason);
            }

            manager.Configuration.CacheSizeLimit = cacheSizeLimitBytes < 0
                ? null
                : cacheSizeLimitBytes;

            return SettingsResult(manager.Configuration);
        }

        public MackanGeneralSettingsResult GetGeneralSettings(string? instanceId)
        {
            using var manager = CreateManager();
            return GeneralSettingsResult(manager, SelectInstance(manager, instanceId));
        }

        public MackanGeneralSettingsResult UpdateGeneralSettings(
            string? instanceId,
            bool checkForUpdatesOnLaunch,
            bool useDevBuilds,
            bool refreshRepositoriesOnLaunch,
            bool autoSortByUpdate)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            manager.Configuration.DevBuilds = useDevBuilds;
            MackanGuiConfigStore.SetGeneralSettings(
                instance,
                checkForUpdatesOnLaunch,
                refreshRepositoriesOnLaunch,
                autoSortByUpdate);
            return GeneralSettingsResult(manager, instance);
        }

        public MackanCompatibleGameVersionsResult GetCompatibleGameVersions(string? instanceId)
        {
            using var manager = CreateManager();
            return CompatibleGameVersionsResult(SelectInstance(manager, instanceId));
        }

        public MackanCompatibleGameVersionsResult UpdateCompatibleGameVersions(
            string? instanceId,
            IReadOnlyList<string> versions)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            instance.SetCompatibleVersions(ParseVersions(versions));
            return CompatibleGameVersionsResult(instance);
        }

        public MackanStabilityToleranceResult GetStabilityTolerance(string? instanceId)
        {
            using var manager = CreateManager();
            return StabilityToleranceResult(SelectInstance(manager, instanceId));
        }

        public MackanStabilityToleranceResult UpdateOverallStabilityTolerance(string? instanceId, string stabilityTolerance)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            instance.StabilityToleranceConfig.OverallStabilityTolerance = ParseReleaseStatus(stabilityTolerance);
            return StabilityToleranceResult(instance);
        }

        public MackanStabilityToleranceResult UpdateModuleStabilityTolerance(
            string? instanceId,
            string identifier,
            string? stabilityTolerance)
        {
            if (string.IsNullOrWhiteSpace(identifier))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            instance.StabilityToleranceConfig.SetModStabilityTolerance(
                identifier.Trim(),
                string.IsNullOrWhiteSpace(stabilityTolerance) ? null : ParseReleaseStatus(stabilityTolerance));
            return StabilityToleranceResult(instance);
        }

        public MackanPreferredHostsResult GetPreferredHosts(string? instanceId)
        {
            using var manager = CreateManager();
            return PreferredHostsResult(manager, SelectInstance(manager, instanceId));
        }

        public MackanPreferredHostsResult UpdatePreferredHosts(string? instanceId, IReadOnlyList<string?> preferredHosts)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            manager.Configuration.PreferredHosts = NormalizePreferredHosts(preferredHosts);
            return PreferredHostsResult(manager, instance);
        }

        public MackanInstallFiltersResult GetInstallFilters(string? instanceId)
        {
            using var manager = CreateManager();
            return InstallFiltersResult(manager, SelectInstance(manager, instanceId));
        }

        public MackanInstallFiltersResult UpdateInstallFilters(
            string? instanceId,
            IReadOnlyList<string> globalFilters,
            IReadOnlyList<string> instanceFilters)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            manager.Configuration.SetGlobalInstallFilters(instance.Game, NormalizeInstallFilters(globalFilters));
            instance.InstallFilters = NormalizeInstallFilters(instanceFilters);
            return InstallFiltersResult(manager, instance);
        }

        public MackanRecommendationSettingsResult GetRecommendationSettings(string? instanceId)
        {
            using var manager = CreateManager();
            return RecommendationSettingsResult(SelectInstance(manager, instanceId));
        }

        public MackanRecommendationSettingsResult UpdateRecommendationSettings(
            string? instanceId,
            bool suppressRecommendations)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            MackanGuiConfigStore.SetSuppressRecommendations(instance, suppressRecommendations);
            return RecommendationSettingsResult(instance);
        }

        public MackanAuthTokensResult GetAuthTokens()
        {
            using var manager = CreateManager();
            return AuthTokensResult(manager.Configuration);
        }

        public MackanAuthTokensResult AddAuthToken(string? host, string? token)
        {
            var normalizedHost = NormalizeAuthTokenHost(host);
            var normalizedToken = NormalizeAuthTokenValue(token);
            using var manager = CreateManager();
            manager.Configuration.SetAuthToken(normalizedHost, normalizedToken);
            return AuthTokensResult(manager.Configuration);
        }

        public MackanAuthTokensResult RemoveAuthToken(string? host)
        {
            var normalizedHost = NormalizeAuthTokenHost(host);
            using var manager = CreateManager();
            manager.Configuration.SetAuthToken(normalizedHost, null);
            return AuthTokensResult(manager.Configuration);
        }

        private static MackanSettingsResult SettingsResult(IConfiguration configuration)
        {
            var defaultCacheDir = GameInstanceManager.DefaultDownloadCacheDir;
            var cacheSizeLimit = configuration.CacheSizeLimit;
            return new MackanSettingsResult(
                configuration.DownloadCacheDir ?? defaultCacheDir,
                defaultCacheDir,
                configuration.DownloadCacheDir == null,
                cacheSizeLimit,
                cacheSizeLimit.HasValue ? CkanModule.FmtSize(cacheSizeLimit.Value) : "Unlimited");
        }

        private static MackanGeneralSettingsResult GeneralSettingsResult(
            GameInstanceManager manager,
            GameInstance instance)
        {
            var guiSettings = MackanGuiConfigStore.GeneralSettings(instance);
            return new MackanGeneralSettingsResult(
                instance.Name,
                guiSettings.CheckForUpdatesOnLaunch,
                manager.Configuration.DevBuilds ?? false,
                guiSettings.RefreshRepositoriesOnLaunch,
                guiSettings.AutoSortByUpdate);
        }

        private GameInstanceManager CreateManager()
            => new GameInstanceManager(
                new NullUser(),
                configuration);

        private static GameInstance SelectInstance(GameInstanceManager manager, string? instanceId)
        {
            if (!string.IsNullOrWhiteSpace(instanceId))
            {
                if (manager.Instances.TryGetValue(instanceId, out var selected))
                {
                    return selected;
                }
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var defaultId = manager.Configuration.AutoStartInstance;
            if (!string.IsNullOrWhiteSpace(defaultId)
                && manager.Instances.TryGetValue(defaultId, out var defaultInstance))
            {
                return defaultInstance;
            }

            if (manager.Instances.Count == 1)
            {
                return manager.Instances.Values.First();
            }

            throw new ArgumentException("Invalid params");
        }

        private static MackanCompatibleGameVersionsResult CompatibleGameVersionsResult(GameInstance instance)
        {
            var actualGameVersion = instance.Version();
            var compatibleVersions = instance.CompatibleVersions.ToArray();
            var knownVersions = instance.Game.KnownVersions.ToArray();
            var majorVersions = MajorVersions(knownVersions).ToArray();
            var availableVersions = compatibleVersions.Except(knownVersions)
                                                      .Except(majorVersions)
                                                      .Concat(majorVersions)
                                                      .Concat(knownVersions)
                                                      .Where(version => version != actualGameVersion)
                                                      .Distinct()
                                                      .OrderDescending()
                                                      .ToArray();

            return new MackanCompatibleGameVersionsResult(
                instance.Name,
                instance.Game.ShortName,
                actualGameVersion?.ToString(),
                instance.GameVersionWhenCompatibleVersionsWereStored?.ToString(),
                instance.CompatibleVersionsAreFromDifferentGameVersion,
                ToVersionStrings(compatibleVersions),
                ToVersionStrings(knownVersions.OrderDescending()),
                ToVersionStrings(availableVersions));
        }

        private static IEnumerable<GameVersion> MajorVersions(IReadOnlyCollection<GameVersion> knownVersions)
            => knownVersions.Select(version => version.ToVersionRange().Lower.Value)
                            .Select(version => new GameVersion(version.Major, version.Minor))
                            .Distinct();

        private static GameVersion[] ParseVersions(IReadOnlyList<string> versions)
        {
            try
            {
                return versions.Select(ParseVersion)
                               .Distinct()
                               .OrderDescending()
                               .ToArray();
            }
            catch (FormatException formatException)
            {
                throw new ArgumentException("Invalid game version.", formatException);
            }
        }

        private static GameVersion ParseVersion(string version)
        {
            if (version.Equals("any", StringComparison.OrdinalIgnoreCase))
            {
                throw new FormatException();
            }

            return GameVersion.Parse(version);
        }

        private static string[] ToVersionStrings(IEnumerable<GameVersion> versions)
            => versions.Select(version => version.ToString() ?? "").ToArray();

        private static MackanStabilityToleranceResult StabilityToleranceResult(GameInstance instance)
        {
            var config = instance.StabilityToleranceConfig;
            return new MackanStabilityToleranceResult(
                instance.Name,
                instance.Game.ShortName,
                config.OverallStabilityTolerance.ToString(),
                AvailableStabilityTolerances(),
                config.OverriddenModIdentifiers
                      .Select(identifier => new MackanModuleStabilityTolerance(
                          identifier,
                          config.ModStabilityTolerance(identifier)?.ToString() ?? "stable"))
                      .ToArray());
        }

        private static string[] AvailableStabilityTolerances()
            => Enum.GetValues(typeof(ReleaseStatus))
                   .OfType<ReleaseStatus>()
                   .OrderBy(status => (int)status)
                   .Select(status => status.ToString())
                   .ToArray();

        private static ReleaseStatus ParseReleaseStatus(string stabilityTolerance)
        {
            if (!Enum.TryParse<ReleaseStatus>(stabilityTolerance.Trim(), true, out var status)
                || !Enum.IsDefined(typeof(ReleaseStatus), status))
            {
                throw new ArgumentException("Invalid stability tolerance.");
            }

            return status;
        }

        private MackanPreferredHostsResult PreferredHostsResult(GameInstanceManager manager, GameInstance instance)
        {
            var registry = instance.Valid
                ? RegistryManager.ReadOnlyRegistry(instance, repositoryData)
                : null;
            return new MackanPreferredHostsResult(
                instance.Name,
                registry?.GetAllHosts().ToArray() ?? Array.Empty<string>(),
                manager.Configuration.PreferredHosts,
                "<ALL OTHER HOSTS>");
        }

        private static MackanInstallFiltersResult InstallFiltersResult(GameInstanceManager manager, GameInstance instance)
            => new MackanInstallFiltersResult(
                instance.Name,
                instance.Game.ShortName,
                manager.Configuration.GetGlobalInstallFilters(instance.Game),
                instance.InstallFilters,
                instance.Game.InstallFilterPresets
                        .OrderBy(preset => preset.Key, StringComparer.OrdinalIgnoreCase)
                        .Select(preset => new MackanInstallFilterPreset(
                            preset.Key,
                            preset.Value))
                        .ToArray());

        private static MackanRecommendationSettingsResult RecommendationSettingsResult(GameInstance instance)
            => new MackanRecommendationSettingsResult(
                instance.Name,
                MackanGuiConfigStore.SuppressRecommendations(instance));

        private static MackanAuthTokensResult AuthTokensResult(IConfiguration configuration)
            => new MackanAuthTokensResult(
                configuration.GetAuthTokenHosts()
                             .Where(host => configuration.TryGetAuthToken(host, out _))
                             .OrderBy(host => host, StringComparer.OrdinalIgnoreCase)
                             .Select(host =>
                             {
                                 configuration.TryGetAuthToken(host, out var token);
                                 return new MackanAuthTokenSummary(host, MaskAuthToken(token));
                             })
                             .ToArray());

        private static string NormalizeAuthTokenHost(string? host)
        {
            var normalizedHost = host?.Trim();
            if (string.IsNullOrWhiteSpace(normalizedHost)
                || Uri.CheckHostName(normalizedHost) == UriHostNameType.Unknown)
            {
                throw new ArgumentException("Invalid auth token host.");
            }

            return normalizedHost;
        }

        private static string NormalizeAuthTokenValue(string? token)
        {
            var normalizedToken = token?.Trim();
            if (string.IsNullOrWhiteSpace(normalizedToken))
            {
                throw new ArgumentException("Invalid auth token.");
            }

            return normalizedToken;
        }

        private static string MaskAuthToken(string? token)
        {
            if (string.IsNullOrEmpty(token))
            {
                return "********";
            }

            return token.Length <= 4
                ? "********"
                : $"********{token.Substring(token.Length - 4)}";
        }

        private static string?[] NormalizePreferredHosts(IReadOnlyList<string?> preferredHosts)
        {
            var values = new List<string?>();
            var seenHosts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var hasPlaceholder = false;
            foreach (var host in preferredHosts)
            {
                if (string.IsNullOrWhiteSpace(host))
                {
                    if (!hasPlaceholder)
                    {
                        values.Add(null);
                        hasPlaceholder = true;
                    }
                    continue;
                }

                var trimmedHost = host.Trim();
                if (seenHosts.Add(trimmedHost))
                {
                    values.Add(trimmedHost);
                }
            }

            return values.ToArray();
        }

        private static string[] NormalizeInstallFilters(IReadOnlyList<string> filters)
        {
            var values = new List<string>();
            var seenFilters = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var filter in filters)
            {
                if (string.IsNullOrWhiteSpace(filter))
                {
                    continue;
                }

                var trimmedFilter = filter.Trim();
                if (seenFilters.Add(trimmedFilter))
                {
                    values.Add(trimmedFilter);
                }
            }

            return values.ToArray();
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;

        private sealed class CacheSettingsUser : IUser
        {
            public CacheSettingsUser(string? migrationChoice)
            {
                this.migrationChoice = NormalizeMigrationChoice(migrationChoice);
            }

            public bool Headless => false;

            public bool RaiseYesNoDialog(string question) => true;

            public int RaiseSelectionDialog(string message, params object[] args)
                => migrationChoice;

            public void RaiseError(string message, params object[] args)
            {
            }

            public void RaiseProgress(string message, int percent)
            {
            }

            public void RaiseProgress(ByteRateCounter rateCounter)
            {
            }

            public void RaiseMessage(string message, params object[] args)
            {
            }

            private static int NormalizeMigrationChoice(string? migrationChoice)
                => string.IsNullOrWhiteSpace(migrationChoice)
                    ? 3
                    : migrationChoice.Trim().ToLowerInvariant() switch
                    {
                        "move" => 0,
                        "delete" => 1,
                        "open" => 2,
                        "keep" => 3,
                        "leave" => 3,
                        "revert" => 4,
                        "cancel" => 4,
                        _ => throw new ArgumentException("Invalid cache migration choice."),
                    };

            private readonly int migrationChoice;
        }
    }
}

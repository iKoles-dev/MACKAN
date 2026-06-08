using System.Collections.Generic;

namespace CKAN.MACKAN.Service
{
    public interface IMackanSettingsProvider
    {
        MackanSettingsResult GetSettings();
        MackanSettingsResult UpdateSettings(
            string? downloadCacheDir,
            long cacheSizeLimitBytes,
            string? cacheMigrationChoice = null);
        MackanGeneralSettingsResult GetGeneralSettings(string? instanceId);
        MackanGeneralSettingsResult UpdateGeneralSettings(
            string? instanceId,
            bool checkForUpdatesOnLaunch,
            bool useDevBuilds,
            bool refreshRepositoriesOnLaunch,
            bool autoSortByUpdate);
        MackanCompatibleGameVersionsResult GetCompatibleGameVersions(string? instanceId);
        MackanCompatibleGameVersionsResult UpdateCompatibleGameVersions(string? instanceId, IReadOnlyList<string> versions);
        MackanStabilityToleranceResult GetStabilityTolerance(string? instanceId);
        MackanStabilityToleranceResult UpdateOverallStabilityTolerance(string? instanceId, string stabilityTolerance);
        MackanStabilityToleranceResult UpdateModuleStabilityTolerance(string? instanceId, string identifier, string? stabilityTolerance);
        MackanPreferredHostsResult GetPreferredHosts(string? instanceId);
        MackanPreferredHostsResult UpdatePreferredHosts(string? instanceId, IReadOnlyList<string?> preferredHosts);
        MackanInstallFiltersResult GetInstallFilters(string? instanceId);
        MackanInstallFiltersResult UpdateInstallFilters(
            string? instanceId,
            IReadOnlyList<string> globalFilters,
            IReadOnlyList<string> instanceFilters);
        MackanRecommendationSettingsResult GetRecommendationSettings(string? instanceId);
        MackanRecommendationSettingsResult UpdateRecommendationSettings(string? instanceId, bool suppressRecommendations);
        MackanAuthTokensResult GetAuthTokens();
        MackanAuthTokensResult AddAuthToken(string? host, string? token);
        MackanAuthTokensResult RemoveAuthToken(string? host);
    }

    public sealed class MackanSettingsResult
    {
        public MackanSettingsResult(
            string downloadCacheDir,
            string defaultDownloadCacheDir,
            bool isDefaultDownloadCacheDir,
            long? cacheSizeLimitBytes,
            string cacheSizeLimitDisplay)
        {
            DownloadCacheDir = downloadCacheDir;
            DefaultDownloadCacheDir = defaultDownloadCacheDir;
            IsDefaultDownloadCacheDir = isDefaultDownloadCacheDir;
            CacheSizeLimitBytes = cacheSizeLimitBytes;
            CacheSizeLimitDisplay = cacheSizeLimitDisplay;
        }

        public string DownloadCacheDir { get; }
        public string DefaultDownloadCacheDir { get; }
        public bool IsDefaultDownloadCacheDir { get; }
        public long? CacheSizeLimitBytes { get; }
        public string CacheSizeLimitDisplay { get; }
    }

    public sealed class MackanGeneralSettingsResult
    {
        public MackanGeneralSettingsResult(
            string instanceId,
            bool checkForUpdatesOnLaunch,
            bool useDevBuilds,
            bool refreshRepositoriesOnLaunch,
            bool autoSortByUpdate)
        {
            InstanceId = instanceId;
            CheckForUpdatesOnLaunch = checkForUpdatesOnLaunch;
            UseDevBuilds = useDevBuilds;
            RefreshRepositoriesOnLaunch = refreshRepositoriesOnLaunch;
            AutoSortByUpdate = autoSortByUpdate;
        }

        public string InstanceId { get; }
        public bool CheckForUpdatesOnLaunch { get; }
        public bool UseDevBuilds { get; }
        public bool RefreshRepositoriesOnLaunch { get; }
        public bool AutoSortByUpdate { get; }
    }

    public sealed class MackanCompatibleGameVersionsResult
    {
        public MackanCompatibleGameVersionsResult(
            string instanceId,
            string game,
            string? actualGameVersion,
            string? gameVersionWhenWritten,
            bool compatibleVersionsAreFromDifferentGameVersion,
            IReadOnlyList<string> compatibleVersions,
            IReadOnlyList<string> knownVersions,
            IReadOnlyList<string> availableVersions)
        {
            InstanceId = instanceId;
            Game = game;
            ActualGameVersion = actualGameVersion;
            GameVersionWhenWritten = gameVersionWhenWritten;
            CompatibleVersionsAreFromDifferentGameVersion = compatibleVersionsAreFromDifferentGameVersion;
            CompatibleVersions = compatibleVersions;
            KnownVersions = knownVersions;
            AvailableVersions = availableVersions;
        }

        public string InstanceId { get; }
        public string Game { get; }
        public string? ActualGameVersion { get; }
        public string? GameVersionWhenWritten { get; }
        public bool CompatibleVersionsAreFromDifferentGameVersion { get; }
        public IReadOnlyList<string> CompatibleVersions { get; }
        public IReadOnlyList<string> KnownVersions { get; }
        public IReadOnlyList<string> AvailableVersions { get; }
    }

    public sealed class MackanStabilityToleranceResult
    {
        public MackanStabilityToleranceResult(
            string instanceId,
            string game,
            string overallStabilityTolerance,
            IReadOnlyList<string> availableStabilityTolerances,
            IReadOnlyList<MackanModuleStabilityTolerance> moduleStabilityTolerances)
        {
            InstanceId = instanceId;
            Game = game;
            OverallStabilityTolerance = overallStabilityTolerance;
            AvailableStabilityTolerances = availableStabilityTolerances;
            ModuleStabilityTolerances = moduleStabilityTolerances;
        }

        public string InstanceId { get; }
        public string Game { get; }
        public string OverallStabilityTolerance { get; }
        public IReadOnlyList<string> AvailableStabilityTolerances { get; }
        public IReadOnlyList<MackanModuleStabilityTolerance> ModuleStabilityTolerances { get; }
    }

    public sealed class MackanModuleStabilityTolerance
    {
        public MackanModuleStabilityTolerance(string identifier, string stabilityTolerance)
        {
            Identifier = identifier;
            StabilityTolerance = stabilityTolerance;
        }

        public string Identifier { get; }
        public string StabilityTolerance { get; }
    }

    public sealed class MackanPreferredHostsResult
    {
        public MackanPreferredHostsResult(
            string instanceId,
            IReadOnlyList<string> availableHosts,
            IReadOnlyList<string?> preferredHosts,
            string placeholderLabel)
        {
            InstanceId = instanceId;
            AvailableHosts = availableHosts;
            PreferredHosts = preferredHosts;
            PlaceholderLabel = placeholderLabel;
        }

        public string InstanceId { get; }
        public IReadOnlyList<string> AvailableHosts { get; }
        public IReadOnlyList<string?> PreferredHosts { get; }
        public string PlaceholderLabel { get; }
    }

    public sealed class MackanInstallFiltersResult
    {
        public MackanInstallFiltersResult(
            string instanceId,
            string game,
            IReadOnlyList<string> globalFilters,
            IReadOnlyList<string> instanceFilters,
            IReadOnlyList<MackanInstallFilterPreset> presets)
        {
            InstanceId = instanceId;
            Game = game;
            GlobalFilters = globalFilters;
            InstanceFilters = instanceFilters;
            Presets = presets;
        }

        public string InstanceId { get; }
        public string Game { get; }
        public IReadOnlyList<string> GlobalFilters { get; }
        public IReadOnlyList<string> InstanceFilters { get; }
        public IReadOnlyList<MackanInstallFilterPreset> Presets { get; }
    }

    public sealed class MackanInstallFilterPreset
    {
        public MackanInstallFilterPreset(string name, IReadOnlyList<string> filters)
        {
            Name = name;
            Filters = filters;
        }

        public string Name { get; }
        public IReadOnlyList<string> Filters { get; }
    }

    public sealed class MackanRecommendationSettingsResult
    {
        public MackanRecommendationSettingsResult(string instanceId, bool suppressRecommendations)
        {
            InstanceId = instanceId;
            SuppressRecommendations = suppressRecommendations;
        }

        public string InstanceId { get; }
        public bool SuppressRecommendations { get; }
    }

    public sealed class MackanAuthTokensResult
    {
        public MackanAuthTokensResult(IReadOnlyList<MackanAuthTokenSummary> authTokens)
        {
            AuthTokens = authTokens;
        }

        public IReadOnlyList<MackanAuthTokenSummary> AuthTokens { get; }
    }

    public sealed class MackanAuthTokenSummary
    {
        public MackanAuthTokenSummary(string host, string tokenPreview)
        {
            Host = host;
            TokenPreview = tokenPreview;
        }

        public string Host { get; }
        public string TokenPreview { get; }
    }
}

using System;

namespace CKAN.MACKAN.Service
{
    public interface IMackanModuleProvider
    {
        MackanModulesResult ListModules(string? instanceId);
        MackanModuleListOperationResult StartListModules(string? instanceId);
        MackanModuleListOperationResult GetListStatus(string operationId);
        MackanModuleListOperationResult CancelList(string operationId);
        MackanModuleDetailsResult GetModuleDetails(string? instanceId, string identifier);
        MackanModulesResult SetAutoInstalled(string? instanceId, string identifier, bool isAutoInstalled);
    }

    public sealed class MackanModulesResult
    {
        public MackanModulesResult(string? instanceId, MackanModuleSummary[] modules)
        {
            InstanceId = instanceId;
            Modules = modules;
        }

        public string? InstanceId { get; }
        public MackanModuleSummary[] Modules { get; }
    }

    public sealed class MackanModuleListOperationResult
    {
        public MackanModuleListOperationResult(
            string operationId,
            string? instanceId,
            string status,
            MackanModuleSummary[] modules,
            MackanOperationEvent[]? events = null,
            string? error = null)
        {
            OperationId = operationId;
            InstanceId = instanceId;
            Status = status;
            Modules = modules;
            Events = events ?? Array.Empty<MackanOperationEvent>();
            Error = error;
        }

        public string OperationId { get; }
        public string? InstanceId { get; }
        public string Status { get; }
        public MackanModuleSummary[] Modules { get; }
        public MackanOperationEvent[] Events { get; }
        public string? Error { get; }
    }

    public sealed class MackanModuleSummary
    {
        public MackanModuleSummary(
            string identifier,
            string name,
            string author,
            string status,
            string installedVersion,
            string latestVersion,
            string license,
            MackanModuleRelationship[] relationships,
            string[] versions,
            string[] contents,
            bool? isInstalled = null,
            bool? isCompatible = null,
            bool? isCached = null,
            bool? isNew = null,
            bool? hasUpdate = null,
            bool? hasReplacement = null,
            string[]? tags = null,
            string? @abstract = null,
            string? description = null,
            string[]? localizations = null,
            string? gameCompatibility = null,
            long? downloadSize = null,
            string? downloadSizeDisplay = null,
            long? installSize = null,
            string? installSizeDisplay = null,
            string? releaseDate = null,
            string? installDate = null,
            int? downloadCount = null,
            bool? isAutoInstalled = null,
            bool? isAutodetected = null)
        {
            Identifier = identifier;
            Name = name;
            Author = author;
            Status = status;
            InstalledVersion = installedVersion;
            LatestVersion = latestVersion;
            License = license;
            Relationships = relationships;
            Versions = versions;
            Contents = contents;
            IsInstalled = isInstalled ?? (status == "installed" || status == "upgradable");
            IsCompatible = isCompatible ?? (status != "incompatible");
            IsCached = isCached ?? (status == "cached");
            IsNew = isNew ?? false;
            HasUpdate = hasUpdate ?? status == "upgradable";
            HasReplacement = hasReplacement ?? false;
            Tags = tags ?? Array.Empty<string>();
            Abstract = @abstract ?? "";
            Description = description ?? "";
            Localizations = localizations ?? Array.Empty<string>();
            GameCompatibility = gameCompatibility ?? "";
            DownloadSize = downloadSize ?? 0;
            DownloadSizeDisplay = downloadSizeDisplay ?? "";
            InstallSize = installSize ?? 0;
            InstallSizeDisplay = installSizeDisplay ?? "";
            ReleaseDate = releaseDate ?? "";
            InstallDate = installDate ?? "";
            DownloadCount = downloadCount;
            IsAutoInstalled = isAutoInstalled ?? false;
            IsAutodetected = isAutodetected ?? false;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Author { get; }
        public string Status { get; }
        public string InstalledVersion { get; }
        public string LatestVersion { get; }
        public string License { get; }
        public MackanModuleRelationship[] Relationships { get; }
        public string[] Versions { get; }
        public string[] Contents { get; }
        public bool IsInstalled { get; }
        public bool IsCompatible { get; }
        public bool IsCached { get; }
        public bool IsNew { get; }
        public bool HasUpdate { get; }
        public bool HasReplacement { get; }
        public string[] Tags { get; }
        public string Abstract { get; }
        public string Description { get; }
        public string[] Localizations { get; }
        public string GameCompatibility { get; }
        public long DownloadSize { get; }
        public string DownloadSizeDisplay { get; }
        public long InstallSize { get; }
        public string InstallSizeDisplay { get; }
        public string ReleaseDate { get; }
        public string InstallDate { get; }
        public int? DownloadCount { get; }
        public bool IsAutoInstalled { get; }
        public bool IsAutodetected { get; }
    }

    public sealed class MackanModuleRelationship
    {
        public MackanModuleRelationship(string kind, string value)
        {
            Kind = kind;
            Value = value;
        }

        public string Kind { get; }
        public string Value { get; }
    }

    public sealed class MackanModuleDetailsResult
    {
        public MackanModuleDetailsResult(
            string? instanceId,
            MackanModuleSummary module,
            string @abstract,
            string description,
            string releaseStatus,
            string kind,
            string releaseDate,
            long downloadSize,
            long installSize,
            MackanModuleResource[] resources,
            string[] tags)
        {
            InstanceId = instanceId;
            Module = module;
            Abstract = @abstract;
            Description = description;
            ReleaseStatus = releaseStatus;
            Kind = kind;
            ReleaseDate = releaseDate;
            DownloadSize = downloadSize;
            InstallSize = installSize;
            Resources = resources;
            Tags = tags;
        }

        public string? InstanceId { get; }
        public MackanModuleSummary Module { get; }
        public string Abstract { get; }
        public string Description { get; }
        public string ReleaseStatus { get; }
        public string Kind { get; }
        public string ReleaseDate { get; }
        public long DownloadSize { get; }
        public long InstallSize { get; }
        public MackanModuleResource[] Resources { get; }
        public string[] Tags { get; }
    }

    public sealed class MackanModuleResource
    {
        public MackanModuleResource(string label, string url)
        {
            Label = label;
            Url = url;
        }

        public string Label { get; }
        public string Url { get; }
    }
}

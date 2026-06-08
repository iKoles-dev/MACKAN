namespace CKAN.MACKAN.Service
{
    public interface IMackanChangeSetProvider
    {
        MackanChangeSetResult ResolveChanges(MackanChangeSetRequest request);
    }

    public sealed class MackanChangeSetRequest
    {
        public MackanChangeSetRequest(
            string? instanceId,
            string[] install,
            string[] remove,
            string[] upgrade,
            string[]? replace = null,
            MackanProviderSelection[]? providerSelections = null,
            MackanModuleVersionSelection[]? installVersions = null,
            bool skipDownloadFailures = false)
        {
            InstanceId = instanceId;
            Install = install;
            Remove = remove;
            Upgrade = upgrade;
            Replace = replace ?? System.Array.Empty<string>();
            ProviderSelections = providerSelections ?? System.Array.Empty<MackanProviderSelection>();
            InstallVersions = installVersions ?? System.Array.Empty<MackanModuleVersionSelection>();
            SkipDownloadFailures = skipDownloadFailures;
        }

        public string? InstanceId { get; }
        public string[] Install { get; }
        public string[] Remove { get; }
        public string[] Upgrade { get; }
        public string[] Replace { get; }
        public MackanProviderSelection[] ProviderSelections { get; }
        public MackanModuleVersionSelection[] InstallVersions { get; }
        public bool SkipDownloadFailures { get; }
    }

    public sealed class MackanModuleVersionSelection
    {
        public MackanModuleVersionSelection(string identifier, string version)
        {
            Identifier = identifier;
            Version = version;
        }

        public string Identifier { get; }
        public string Version { get; }
    }

    public sealed class MackanChangeSetResult
    {
        public MackanChangeSetResult(
            string? instanceId,
            MackanChangeSummary[] changes,
            MackanConflictSummary[] conflicts,
            string[] conflictDescriptions,
            MackanProviderChoice[]? providerChoices = null,
            MackanRecommendationChoice[]? recommendationChoices = null,
            bool suppressRecommendations = false)
        {
            InstanceId = instanceId;
            Changes = changes;
            Conflicts = conflicts;
            ConflictDescriptions = conflictDescriptions;
            ProviderChoices = providerChoices ?? System.Array.Empty<MackanProviderChoice>();
            RecommendationChoices = recommendationChoices ?? System.Array.Empty<MackanRecommendationChoice>();
            SuppressRecommendations = suppressRecommendations;
        }

        public string? InstanceId { get; }
        public MackanChangeSummary[] Changes { get; }
        public MackanConflictSummary[] Conflicts { get; }
        public string[] ConflictDescriptions { get; }
        public MackanProviderChoice[] ProviderChoices { get; }
        public MackanRecommendationChoice[] RecommendationChoices { get; }
        public bool SuppressRecommendations { get; }
    }

    public sealed class MackanChangeSummary
    {
        public MackanChangeSummary(
            string identifier,
            string name,
            string action,
            string? fromVersion,
            string? toVersion,
            string[] reasons,
            bool isUserRequested,
            bool isAuto)
        {
            Identifier = identifier;
            Name = name;
            Action = action;
            FromVersion = fromVersion;
            ToVersion = toVersion;
            Reasons = reasons;
            IsUserRequested = isUserRequested;
            IsAuto = isAuto;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Action { get; }
        public string? FromVersion { get; }
        public string? ToVersion { get; }
        public string[] Reasons { get; }
        public bool IsUserRequested { get; }
        public bool IsAuto { get; }
    }

    public sealed class MackanConflictSummary
    {
        public MackanConflictSummary(string identifier, string name, string description)
        {
            Identifier = identifier;
            Name = name;
            Description = description;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Description { get; }
    }

    public sealed class MackanProviderChoice
    {
        public MackanProviderChoice(
            string requested,
            string message,
            string requesterIdentifier,
            string requesterName,
            MackanProviderOption[] options)
        {
            Requested = requested;
            Message = message;
            RequesterIdentifier = requesterIdentifier;
            RequesterName = requesterName;
            Options = options;
        }

        public string Requested { get; }
        public string Message { get; }
        public string RequesterIdentifier { get; }
        public string RequesterName { get; }
        public MackanProviderOption[] Options { get; }
    }

    public sealed class MackanProviderSelection
    {
        public MackanProviderSelection(
            string requested,
            string requesterIdentifier,
            string selectedIdentifier)
        {
            Requested = requested;
            RequesterIdentifier = requesterIdentifier;
            SelectedIdentifier = selectedIdentifier;
        }

        public string Requested { get; }
        public string RequesterIdentifier { get; }
        public string SelectedIdentifier { get; }
    }

    public sealed class MackanProviderOption
    {
        public MackanProviderOption(string identifier, string name, string version, string @abstract)
        {
            Identifier = identifier;
            Name = name;
            Version = version;
            Abstract = @abstract;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Version { get; }
        public string Abstract { get; }
    }

    public sealed class MackanRecommendationChoice
    {
        public MackanRecommendationChoice(
            string kind,
            string identifier,
            string name,
            string version,
            string @abstract,
            string[] dependents,
            bool isRecommendedDefault)
        {
            Kind = kind;
            Identifier = identifier;
            Name = name;
            Version = version;
            Abstract = @abstract;
            Dependents = dependents;
            IsRecommendedDefault = isRecommendedDefault;
        }

        public string Kind { get; }
        public string Identifier { get; }
        public string Name { get; }
        public string Version { get; }
        public string Abstract { get; }
        public string[] Dependents { get; }
        public bool IsRecommendedDefault { get; }
    }
}

using System;

namespace CKAN.MACKAN.Service
{

    public sealed class MackanErrorDetails
    {
        public MackanErrorDetails(
            string kind,
            string? lockfilePath,
            string? suggestedAction,
            string? command = null,
            MackanDownloadFailure[]? downloadFailures = null,
            MackanProviderChoice[]? providerChoices = null,
            MackanRecommendationChoice[]? recommendationChoices = null,
            MackanIncompatibleCkanFile[]? incompatibleCkanFiles = null)
        {
            Kind = kind;
            LockfilePath = lockfilePath;
            SuggestedAction = suggestedAction;
            Command = command;
            DownloadFailures = downloadFailures;
            ProviderChoices = providerChoices;
            RecommendationChoices = recommendationChoices;
            IncompatibleCkanFiles = incompatibleCkanFiles;
        }

        public string Kind { get; }
        public string? LockfilePath { get; }
        public string? SuggestedAction { get; }
        public string? Command { get; }
        public MackanDownloadFailure[]? DownloadFailures { get; }
        public MackanProviderChoice[]? ProviderChoices { get; }
        public MackanRecommendationChoice[]? RecommendationChoices { get; }
        public MackanIncompatibleCkanFile[]? IncompatibleCkanFiles { get; }

        public static MackanErrorDetails RegistryLock(string lockfilePath)
            => new MackanErrorDetails("registryLock", lockfilePath, "waitRetry");

        public static MackanErrorDetails DownloadFailureDetails(MackanDownloadFailure[] failures)
            => new MackanErrorDetails(
                kind: "downloadFailures",
                lockfilePath: null,
                suggestedAction: "skipOrAbort",
                command: null,
                downloadFailures: failures);

        public static MackanErrorDetails RepositoryDownloadFailureDetails(MackanDownloadFailure[] failures)
            => new MackanErrorDetails(
                kind: "downloadFailures",
                lockfilePath: null,
                suggestedAction: "retryOrEditRepository",
                command: null,
                downloadFailures: failures);

        public static MackanErrorDetails ProviderChoiceDetails(MackanProviderChoice[] choices)
            => new MackanErrorDetails(
                kind: "providerChoices",
                lockfilePath: null,
                suggestedAction: "chooseProvider",
                command: null,
                providerChoices: choices);

        public static MackanErrorDetails RecommendationChoiceDetails(MackanRecommendationChoice[] choices)
            => new MackanErrorDetails(
                kind: "recommendationChoices",
                lockfilePath: null,
                suggestedAction: "chooseRecommendations",
                command: null,
                recommendationChoices: choices);

        public static MackanErrorDetails IncompatibleCkanFileDetails(MackanIncompatibleCkanFile[] files)
            => new MackanErrorDetails(
                kind: "incompatibleCkanFiles",
                lockfilePath: null,
                suggestedAction: "confirmIncompatible",
                command: null,
                incompatibleCkanFiles: files);

        public static MackanErrorDetails LaunchFailureDetails(string command)
            => new MackanErrorDetails("launchFailure", null, "retryOrCheckCommand", command);
    }

    public sealed class MackanLaunchFailureException : InvalidOperationException
    {
        public MackanLaunchFailureException(string command, string message, Exception? innerException = null)
            : base(message, innerException)
        {
            Command = command;
        }

        public string Command { get; }
    }

    public sealed class MackanDownloadFailure
    {
        public MackanDownloadFailure(
            string identifier,
            string name,
            string version,
            string message,
            string[] urls)
        {
            Identifier = identifier;
            Name = name;
            Version = version;
            Message = message;
            Urls = urls;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Version { get; }
        public string Message { get; }
        public string[] Urls { get; }
    }

    public sealed class MackanIncompatibleCkanFile
    {
        public MackanIncompatibleCkanFile(
            string identifier,
            string name,
            string version,
            string compatibleGameVersions)
        {
            Identifier = identifier;
            Name = name;
            Version = version;
            CompatibleGameVersions = compatibleGameVersions;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string Version { get; }
        public string CompatibleGameVersions { get; }
    }
}

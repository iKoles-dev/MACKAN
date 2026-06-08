namespace CKAN.MACKAN.Service
{
    public interface IMackanOperationProvider
    {
        MackanOperationResult ApplyChanges(MackanChangeSetRequest request);
        MackanOperationResult StartApplyChanges(MackanChangeSetRequest request);
        MackanOperationResult InstallCkanFiles(MackanFileInstallRequest request);
        MackanOperationResult StartInstallCkanFiles(MackanFileInstallRequest request);
        MackanOperationResult ImportDownloads(MackanDownloadImportRequest request);
        MackanOperationResult StartImportDownloads(MackanDownloadImportRequest request);
        MackanOperationResult GetStatus(string operationId);
        MackanOperationResult CancelOperation(string operationId);
    }

    public sealed class MackanFileInstallRequest
    {
        public MackanFileInstallRequest(
            string? instanceId,
            string[] filePaths,
            MackanProviderSelection[]? providerSelections = null,
            string[]? recommendationSelections = null,
            bool skipRecommendations = false,
            bool allowIncompatibleCkanFiles = false,
            bool skipDownloadFailures = false)
        {
            InstanceId = instanceId;
            FilePaths = filePaths;
            ProviderSelections = providerSelections ?? System.Array.Empty<MackanProviderSelection>();
            RecommendationSelections = recommendationSelections ?? System.Array.Empty<string>();
            SkipRecommendations = skipRecommendations;
            AllowIncompatibleCkanFiles = allowIncompatibleCkanFiles;
            SkipDownloadFailures = skipDownloadFailures;
        }

        public string? InstanceId { get; }
        public string[] FilePaths { get; }
        public MackanProviderSelection[] ProviderSelections { get; }
        public string[] RecommendationSelections { get; }
        public bool SkipRecommendations { get; }
        public bool AllowIncompatibleCkanFiles { get; }
        public bool SkipDownloadFailures { get; }
    }

    public sealed class MackanDownloadImportRequest
    {
        public MackanDownloadImportRequest(
            string? instanceId,
            string[] paths,
            bool installImportedModules,
            bool deleteImportedFiles,
            bool previewBeforeInstall = false,
            bool skipDownloadFailures = false)
        {
            InstanceId = instanceId;
            Paths = paths;
            InstallImportedModules = installImportedModules;
            DeleteImportedFiles = deleteImportedFiles;
            PreviewBeforeInstall = previewBeforeInstall;
            SkipDownloadFailures = skipDownloadFailures;
        }

        public string? InstanceId { get; }
        public string[] Paths { get; }
        public bool InstallImportedModules { get; }
        public bool DeleteImportedFiles { get; }
        public bool PreviewBeforeInstall { get; }
        public bool SkipDownloadFailures { get; }
    }

    public sealed class MackanOperationResult
    {
        public MackanOperationResult(
            string operationId,
            string? instanceId,
            string status,
            MackanChangeSummary[] changes,
            MackanOperationEvent[] events,
            string? error,
            MackanErrorDetails? errorDetails = null)
        {
            OperationId = operationId;
            InstanceId = instanceId;
            Status = status;
            Changes = changes;
            Events = events;
            Error = error;
            ErrorDetails = errorDetails;
        }

        public string OperationId { get; }
        public string? InstanceId { get; }
        public string Status { get; }
        public MackanChangeSummary[] Changes { get; }
        public MackanOperationEvent[] Events { get; }
        public string? Error { get; }
        public MackanErrorDetails? ErrorDetails { get; }
    }

    public sealed class MackanOperationEvent
    {
        public MackanOperationEvent(
            string kind,
            string message,
            int? percent,
            string? identifier,
            long? remainingBytes,
            long? totalBytes,
            int? completedCount = null,
            int? totalCount = null)
        {
            Kind = kind;
            Message = message;
            Percent = percent;
            Identifier = identifier;
            RemainingBytes = remainingBytes;
            TotalBytes = totalBytes;
            CompletedCount = completedCount;
            TotalCount = totalCount;
        }

        public string Kind { get; }
        public string Message { get; }
        public int? Percent { get; }
        public string? Identifier { get; }
        public long? RemainingBytes { get; }
        public long? TotalBytes { get; }
        public int? CompletedCount { get; }
        public int? TotalCount { get; }
    }
}

namespace CKAN.MACKAN.Service
{
    public interface IMackanRepositoryProvider
    {
        MackanRepositoriesResult ListRepositories(string? instanceId);
        MackanRepositoriesResult ListAvailableRepositories(string? instanceId);
        MackanRepositoriesResult AddRepository(string? instanceId, string name, string url);
        MackanRepositoriesResult RemoveRepository(string? instanceId, string name);
        MackanRepositoriesResult SetRepositoryPriority(string? instanceId, string name, int priority);
        MackanRepositoryRefreshResult RefreshRepositories(string? instanceId, bool force);
        MackanRepositoryRefreshResult StartRefreshRepositories(string? instanceId, bool force);
        MackanRepositoryRefreshResult GetRefreshStatus(string operationId);
        MackanRepositoryRefreshResult CancelRefresh(string operationId);
    }

    public sealed class MackanRepositoriesResult
    {
        public MackanRepositoriesResult(string? instanceId, MackanRepositorySummary[] repositories)
        {
            InstanceId = instanceId;
            Repositories = repositories;
        }

        public string? InstanceId { get; }
        public MackanRepositorySummary[] Repositories { get; }
    }

    public sealed class MackanRepositorySummary
    {
        public MackanRepositorySummary(
            string name,
            string url,
            int priority,
            bool isMirror,
            string comment)
        {
            Name = name;
            Url = url;
            Priority = priority;
            IsMirror = isMirror;
            Comment = comment;
        }

        public string Name { get; }
        public string Url { get; }
        public int Priority { get; }
        public bool IsMirror { get; }
        public string Comment { get; }
    }

    public sealed class MackanRepositoryRefreshResult
    {
        public MackanRepositoryRefreshResult(
            string? instanceId,
            string status,
            int compatibleModuleCount,
            MackanRepositorySummary[] repositories,
            MackanOperationEvent[]? events = null,
            string? operationId = null,
            string operationStatus = "completed",
            string? error = null,
            MackanErrorDetails? errorDetails = null)
        {
            OperationId = operationId;
            OperationStatus = operationStatus;
            InstanceId = instanceId;
            Status = status;
            CompatibleModuleCount = compatibleModuleCount;
            Repositories = repositories;
            Events = events ?? System.Array.Empty<MackanOperationEvent>();
            Error = error;
            ErrorDetails = errorDetails;
        }

        public string? OperationId { get; }
        public string OperationStatus { get; }
        public string? InstanceId { get; }
        public string Status { get; }
        public int CompatibleModuleCount { get; }
        public MackanRepositorySummary[] Repositories { get; }
        public MackanOperationEvent[] Events { get; }
        public string? Error { get; }
        public MackanErrorDetails? ErrorDetails { get; }
    }
}

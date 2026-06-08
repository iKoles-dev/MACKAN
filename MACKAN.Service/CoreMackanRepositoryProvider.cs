using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Autofac;

using CKAN.Configuration;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanRepositoryProvider : IMackanRepositoryProvider
    {
        public CoreMackanRepositoryProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanRepositoryProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanRepositoriesResult ListRepositories(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                return new MackanRepositoriesResult(instance?.Name ?? instanceId, Array.Empty<MackanRepositorySummary>());
            }

            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            if (registry == null)
            {
                return new MackanRepositoriesResult(instance.Name, Array.Empty<MackanRepositorySummary>());
            }

            var repositories = registry.Repositories.Values
                .OrderBy(repository => repository.priority)
                .ThenBy(repository => repository.name, StringComparer.OrdinalIgnoreCase)
                .Select(repository => new MackanRepositorySummary(
                    repository.name,
                    repository.uri.ToString(),
                    repository.priority,
                    repository.x_mirror,
                    repository.x_comment ?? ""))
                .ToArray();

            return new MackanRepositoriesResult(instance.Name, repositories);
        }

        public MackanRepositoriesResult ListAvailableRepositories(string? instanceId)
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var instance = SelectInstance(manager, instanceId);
            if (instance == null || !instance.Valid)
            {
                return new MackanRepositoriesResult(instance?.Name ?? instanceId, Array.Empty<MackanRepositorySummary>());
            }

            var repositories = RepositoryList.DefaultRepositories(instance.Game, null)?.repositories
                ?? Array.Empty<Repository>();
            return ToResult(instance.Name, repositories);
        }

        public MackanRepositoriesResult AddRepository(string? instanceId, string name, string url)
        {
            using var context = RegistryManagerFor(instanceId);
            var manager = context.RegistryManager;
            var instance = context.Instance;
            var registry = manager.registry;

            if (registry.Repositories.Keys.Any(repositoryName => repositoryName.Equals(name, StringComparison.OrdinalIgnoreCase)))
            {
                throw new ArgumentException($"Repository '{name}' already exists.");
            }

            if (registry.Repositories.Values.Any(repository => repository.uri.ToString().Equals(url, StringComparison.OrdinalIgnoreCase)))
            {
                throw new ArgumentException($"Repository URL '{url}' already exists.");
            }

            registry.RepositoriesAdd(new Repository(name, url, registry.Repositories.Count));
            manager.Save();
            return ToResult(instance.Name, registry.Repositories.Values);
        }

        public MackanRepositoriesResult RemoveRepository(string? instanceId, string name)
        {
            using var context = RegistryManagerFor(instanceId);
            var manager = context.RegistryManager;
            var instance = context.Instance;
            var registry = manager.registry;

            if (registry.Repositories.Count <= 1)
            {
                throw new InvalidOperationException("Cannot remove the last repository.");
            }

            var exactName = RepositoryName(registry, name);
            registry.RepositoriesRemove(exactName);
            NormalizePriorities(registry.Repositories.Values);
            manager.Save();
            return ToResult(instance.Name, registry.Repositories.Values);
        }

        public MackanRepositoriesResult SetRepositoryPriority(string? instanceId, string name, int priority)
        {
            using var context = RegistryManagerFor(instanceId);
            var manager = context.RegistryManager;
            var instance = context.Instance;
            var registry = manager.registry;

            if (priority < 0 || priority >= registry.Repositories.Count)
            {
                throw new ArgumentException($"Repository priority {priority} is outside 0..{registry.Repositories.Count - 1}.");
            }

            var exactName = RepositoryName(registry, name);
            var repository = registry.Repositories[exactName];
            if (repository.priority != priority)
            {
                var sortedRepositories = registry.Repositories.Values
                    .OrderBy(repo => repo.priority)
                    .ToList();

                if (priority < repository.priority)
                {
                    for (var i = priority; i < repository.priority; ++i)
                    {
                        sortedRepositories[i].priority = i + 1;
                    }
                }
                else
                {
                    for (var i = repository.priority + 1; i <= priority; ++i)
                    {
                        sortedRepositories[i].priority = i - 1;
                    }
                }

                repository.priority = priority;
                manager.Save();
            }

            return ToResult(instance.Name, registry.Repositories.Values);
        }

        public MackanRepositoryRefreshResult RefreshRepositories(string? instanceId, bool force)
        {
            var events = new RepositoryEventRecorder();
            return RefreshRepositoriesCore(instanceId, force, null, "completed", events);
        }

        public MackanRepositoryRefreshResult StartRefreshRepositories(string? instanceId, bool force)
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
            var events = new RepositoryEventRecorder();
            var cancellation = new CancellationTokenSource();
            var state = RepositoryRefreshState.Running(operationId, instance.Name, events, cancellation);
            RefreshOperations[operationId] = state;
            events.RefreshQueued();

            _ = Task.Run(() =>
            {
                MackanRepositoryRefreshResult result;
                try
                {
                    result = RefreshRepositoriesCore(instanceId, force, operationId, "completed", events);
                }
                catch (Exception exception)
                {
                    result = new MackanRepositoryRefreshResult(
                        instance.Name,
                        "failed",
                        0,
                        Array.Empty<MackanRepositorySummary>(),
                        events.Events,
                        operationId,
                        "failed",
                        exception.Message);
                }

                state.Complete(result);
                RefreshOperations[operationId] = RepositoryRefreshState.Final(result);
            });

            return state.Snapshot();
        }

        public MackanRepositoryRefreshResult GetRefreshStatus(string operationId)
            => RefreshOperations.TryGetValue(operationId, out var state)
                ? state.Snapshot()
                : throw new ArgumentException($"Repository refresh operation '{operationId}' was not found.");

        public MackanRepositoryRefreshResult CancelRefresh(string operationId)
        {
            if (!RefreshOperations.TryGetValue(operationId, out var state))
            {
                throw new ArgumentException($"Repository refresh operation '{operationId}' was not found.");
            }

            state.Cancel();
            return state.Snapshot();
        }

        private MackanRepositoryRefreshResult RefreshRepositoriesCore(
            string? instanceId,
            bool force,
            string? operationId,
            string operationStatus,
            RepositoryEventRecorder events)
        {
            using var context = RegistryManagerFor(instanceId);
            var manager = context.RegistryManager;
            var instance = context.Instance;
            var registry = manager.registry;
            var repositories = registry.Repositories.Values.ToArray();

            RepositoryDataManager.UpdateResult result;
            try
            {
                result = repositoryData.Update(
                    repositories,
                    instance.Game,
                    force,
                    new NetAsyncDownloader(events, () => null),
                    events);
            }
            catch (DownloadErrorsKraken kraken)
            {
                return new MackanRepositoryRefreshResult(
                    instance.Name,
                    "failed",
                    0,
                    ToSummaries(repositories),
                    events.Events,
                    operationId,
                    "failed",
                    kraken.Message,
                    RepositoryDownloadFailureDetails(kraken, repositories));
            }

            var compatibleModuleCount = registry
                .CompatibleModules(
                    instance.StabilityToleranceConfig,
                    instance.VersionCriteria())
                .Count();

            return new MackanRepositoryRefreshResult(
                instance.Name,
                RefreshStatus(result),
                compatibleModuleCount,
                ToSummaries(registry.Repositories.Values),
                events.Events,
                operationId,
                operationStatus);
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

        private RegistryMutationContext RegistryManagerFor(string? instanceId)
        {
            var instanceManager = new GameInstanceManager(
                new NullUser(),
                configuration);

            var selected = SelectInstance(instanceManager, instanceId);
            if (selected == null || !selected.Valid)
            {
                instanceManager.Dispose();
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            return new RegistryMutationContext(
                instanceManager,
                selected,
                RegistryManager.Instance(selected, repositoryData));
        }

        private static string RepositoryName(Registry registry, string name)
            => registry.Repositories.Keys.FirstOrDefault(repositoryName => repositoryName.Equals(name, StringComparison.OrdinalIgnoreCase))
               ?? throw new ArgumentException($"Repository '{name}' was not found.");

        private static void NormalizePriorities(System.Collections.Generic.IEnumerable<Repository> repositories)
        {
            var sortedRepositories = repositories.OrderBy(repo => repo.priority).ToArray();
            for (var i = 0; i < sortedRepositories.Length; ++i)
            {
                sortedRepositories[i].priority = i;
            }
        }

        private static MackanRepositoriesResult ToResult(
            string? instanceId,
            System.Collections.Generic.IEnumerable<Repository> repositories)
            => new MackanRepositoriesResult(
                instanceId,
                ToSummaries(repositories));

        private static MackanRepositorySummary[] ToSummaries(
            System.Collections.Generic.IEnumerable<Repository> repositories)
            => repositories
                .OrderBy(repository => repository.priority)
                .ThenBy(repository => repository.name, StringComparer.OrdinalIgnoreCase)
                    .Select(repository => new MackanRepositorySummary(
                        repository.name,
                        repository.uri?.ToString() ?? "",
                        repository.priority,
                        repository.x_mirror,
                        repository.x_comment ?? ""))
                .ToArray();

        private static string RefreshStatus(RepositoryDataManager.UpdateResult result)
            => result switch
            {
                RepositoryDataManager.UpdateResult.Updated => "updated",
                RepositoryDataManager.UpdateResult.NoChanges => "noChanges",
                RepositoryDataManager.UpdateResult.OutdatedClient => "outdatedClient",
                _ => "failed",
            };

        private static MackanErrorDetails RepositoryDownloadFailureDetails(
            DownloadErrorsKraken kraken,
            Repository[] repositories)
        {
            var repositoriesByUrl = repositories
                .Where(repository => repository.uri != null)
                .ToDictionary(
                    repository => repository.uri.ToString(),
                    repository => repository,
                    StringComparer.OrdinalIgnoreCase);

            return MackanErrorDetails.RepositoryDownloadFailureDetails(kraken.Exceptions
                .Select(kvp =>
                {
                    var urls = kvp.Key.urls.Select(url => url.ToString()).ToArray();
                    var repository = urls
                        .Select(url => repositoriesByUrl.TryGetValue(url, out var matched) ? matched : null)
                        .FirstOrDefault(matched => matched != null);
                    var identifier = repository?.name ?? urls.FirstOrDefault() ?? "repository";

                    return new MackanDownloadFailure(
                        identifier,
                        repository?.name ?? identifier,
                        "metadata",
                        kvp.Value.Message,
                        urls);
                })
                .ToArray());
        }

        private sealed class RepositoryEventRecorder : IUser
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

            public void RefreshQueued()
                => Add("message", "Repository refresh queued", null, null, null, null);

            public void CancellationRequested()
                => Add("message", "Cancellation requested", null, null, null, null);

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

        private sealed class RepositoryRefreshState
        {
            private RepositoryRefreshState(
                string operationId,
                string? instanceId,
                string operationStatus,
                RepositoryEventRecorder? recorder,
                MackanRepositoryRefreshResult? result,
                CancellationTokenSource? cancellation)
            {
                OperationId = operationId;
                InstanceId = instanceId;
                this.operationStatus = operationStatus;
                this.recorder = recorder;
                this.result = result;
                this.cancellation = cancellation;
            }

            public string OperationId { get; }
            public string? InstanceId { get; }

            public static RepositoryRefreshState Running(
                string operationId,
                string? instanceId,
                RepositoryEventRecorder recorder,
                CancellationTokenSource cancellation)
                => new RepositoryRefreshState(
                    operationId,
                    instanceId,
                    "running",
                    recorder,
                    null,
                    cancellation);

            public static RepositoryRefreshState Final(MackanRepositoryRefreshResult result)
                => new RepositoryRefreshState(
                    result.OperationId ?? Guid.NewGuid().ToString("N"),
                    result.InstanceId,
                    result.OperationStatus,
                    null,
                    result,
                    null);

            public MackanRepositoryRefreshResult Snapshot()
            {
                lock (lockObject)
                {
                    if (result != null)
                    {
                        return result;
                    }

                    return new MackanRepositoryRefreshResult(
                        InstanceId,
                        operationStatus == "cancelling" ? "running" : operationStatus,
                        0,
                        Array.Empty<MackanRepositorySummary>(),
                        recorder?.Events,
                        OperationId,
                        operationStatus);
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

                    operationStatus = "cancelling";
                    recorder?.CancellationRequested();
                    cancellation?.Cancel();
                }
            }

            public void Complete(MackanRepositoryRefreshResult completedResult)
            {
                lock (lockObject)
                {
                    result = completedResult;
                    recorder = null;
                    cancellation?.Dispose();
                    cancellation = null;
                    operationStatus = completedResult.OperationStatus;
                }
            }

            private readonly object lockObject = new();
            private string operationStatus;
            private RepositoryEventRecorder? recorder;
            private MackanRepositoryRefreshResult? result;
            private CancellationTokenSource? cancellation;
        }

        private sealed class RegistryMutationContext : IDisposable
        {
            public RegistryMutationContext(
                GameInstanceManager instanceManager,
                GameInstance instance,
                RegistryManager registryManager)
            {
                this.instanceManager = instanceManager;
                Instance = instance;
                RegistryManager = registryManager;
            }

            public GameInstance Instance { get; }
            public RegistryManager RegistryManager { get; }

            public void Dispose()
            {
                RegistryManager.Dispose();
                instanceManager.Dispose();
            }

            private readonly GameInstanceManager instanceManager;
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;
        private static readonly ConcurrentDictionary<string, RepositoryRefreshState> RefreshOperations = new();
    }
}

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

using Autofac;

using CKAN.Configuration;
using CKAN.Games;
using CKAN.IO;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanOperationProvider : IMackanOperationProvider
    {
        public CoreMackanOperationProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanOperationProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData,
            IReadOnlyCollection<Repository>? initialRepositories = null)
            : this(
                configuration,
                repositoryData,
                new CoreMackanChangeSetProvider(configuration, repositoryData, initialRepositories),
                initialRepositories)
        {
        }

        private CoreMackanOperationProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData,
            IMackanChangeSetProvider changeSetProvider,
            IReadOnlyCollection<Repository>? initialRepositories)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
            this.changeSetProvider = changeSetProvider;
            this.initialRepositories = initialRepositories ?? Array.Empty<Repository>();
        }

        public MackanOperationResult ApplyChanges(MackanChangeSetRequest request)
        {
            var operationId = Guid.NewGuid().ToString("N");
            var events = new OperationEventRecorder();
            return Store(ApplyChangesCore(request, operationId, events, CancellationToken.None));
        }

        public MackanOperationResult StartApplyChanges(MackanChangeSetRequest request)
            => StartOperation(
                request.InstanceId,
                new OperationEventRecorder(),
                (operationId, events, cancellationToken) => ApplyChangesCore(
                    request,
                    operationId,
                    events,
                    cancellationToken));

        public MackanOperationResult StartInstallCkanFiles(MackanFileInstallRequest request)
            => StartOperation(
                request.InstanceId,
                new OperationEventRecorder(),
                (operationId, events, cancellationToken) => InstallCkanFilesCore(
                    request,
                    operationId,
                    events,
                    cancellationToken));

        public MackanOperationResult StartImportDownloads(MackanDownloadImportRequest request)
            => StartOperation(
                request.InstanceId,
                ImportEventRecorder(request),
                (operationId, events, cancellationToken) => ImportDownloadsCore(
                    request,
                    operationId,
                    events,
                    cancellationToken));

        private static MackanOperationResult StartOperation(
            string? instanceId,
            OperationEventRecorder events,
            Func<string, OperationEventRecorder, CancellationToken, MackanOperationResult> run)
        {
            var operationId = Guid.NewGuid().ToString("N");
            var cancellation = new CancellationTokenSource();
            var state = OperationState.Running(operationId, instanceId, events, cancellation);
            Operations[operationId] = state;
            events.OperationQueued();

            _ = Task.Run(() =>
            {
                MackanOperationResult result;
                try
                {
                    result = run(operationId, events, cancellation.Token);
                }
                catch (Exception exception)
                {
                    result = new MackanOperationResult(
                        operationId,
                        instanceId,
                        "failed",
                        Array.Empty<MackanChangeSummary>(),
                        events.Events,
                        exception.Message,
                        ErrorDetails(exception));
                }
                state.Complete(result);
            });

            return state.Snapshot();
        }

        private MackanOperationResult ApplyChangesCore(
            MackanChangeSetRequest request,
            string operationId,
            OperationEventRecorder events,
            CancellationToken cancellationToken)
        {
            MackanChangeSummary[] changes = Array.Empty<MackanChangeSummary>();

            try
            {
                using var manager = new GameInstanceManager(events, configuration);

                var instance = SelectInstance(manager, request.InstanceId);
                if (instance == null || !instance.Valid)
                {
                    throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
                }

                if (!request.Install.Any()
                    && !request.InstallVersions.Any()
                    && !request.Remove.Any()
                    && !request.Upgrade.Any()
                    && !request.Replace.Any()
                    && !request.ProviderSelections.Any())
                {
                    return new MackanOperationResult(
                        operationId,
                        instance.Name,
                        "completed",
                        Array.Empty<MackanChangeSummary>(),
                        events.Events,
                        null);
                }

                var preview = changeSetProvider.ResolveChanges(request);
                changes = preview.Changes;
                if (preview.Conflicts.Any() || preview.ConflictDescriptions.Any())
                {
                    return new MackanOperationResult(
                        operationId,
                        instance.Name,
                        "failed",
                        changes,
                        events.Events,
                        string.Join(Environment.NewLine, preview.ConflictDescriptions));
                }
                if (preview.ProviderChoices.Any())
                {
                    return new MackanOperationResult(
                        operationId,
                        instance.Name,
                        "failed",
                        changes,
                        events.Events,
                        "Choose dependency providers before applying these changes.",
                        MackanErrorDetails.ProviderChoiceDetails(preview.ProviderChoices));
                }

                using var registryManager = RegistryManager.Instance(instance, repositoryData, initialRepositories);
                CoreMackanChangeSetProvider.ApplyInitialRepositories(registryManager.registry, initialRepositories);
                registryManager.ScanUnmanagedFiles();
                var registry = registryManager.registry;
                var stability = instance.StabilityToleranceConfig;
                var criteria = instance.VersionCriteria();

                var exactInstallIdentifiers = request.InstallVersions
                    .Select(selection => selection.Identifier)
                    .ToHashSet(StringComparer.OrdinalIgnoreCase);
                var toInstall = request.InstallVersions
                    .Select(selection => ExactAvailable(registry, selection, criteria))
                    .Concat(request.Install
                        .Where(identifier => !exactInstallIdentifiers.Contains(identifier))
                        .Select(identifier => LatestAvailable(registry, identifier, stability, criteria)))
                    .Concat(request.ProviderSelections
                        .Select(selection => LatestAvailable(registry, selection.SelectedIdentifier, stability, criteria)))
                    .Concat(request.Replace
                        .Select(identifier => Replacement(registry, identifier, stability, criteria).ReplaceWith))
                    .GroupBy(module => module.identifier, StringComparer.OrdinalIgnoreCase)
                    .Select(group => group.First())
                    .ToList();
                var toRemove = request.Remove
                    .Concat(request.Replace
                        .Select(identifier => Replacement(registry, identifier, stability, criteria).ToReplace.identifier))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToArray();
                var toUpgrade = request.Upgrade
                    .Select(identifier => UpgradeTarget(registry, instance, identifier, configuration))
                    .ToHashSet();

                var cache = manager.Cache
                    ?? throw new InvalidOperationException("Download cache is not available.");
                var installer = new ModuleInstaller(
                    instance,
                    cache,
                    manager.Configuration,
                    events,
                    cancellationToken);
                installer.InstallProgress += events.InstallProgress;
                installer.RemoveProgress += events.RemoveProgress;
                installer.OneComplete += events.ModuleComplete;

                var downloader = new NetAsyncModulesDownloader(events, cache, null, cancellationToken);
                downloader.DownloadProgress += events.DownloadProgress;
                downloader.StoreProgress += events.StoreProgress;
                downloader.OneComplete += events.ModuleComplete;

                var deduper = new InstalledFilesDeduplicator(
                    instance,
                    manager.Instances.Values,
                    repositoryData);
                var autoInstalled = new HashSet<CkanModule>();
                HashSet<string>? possibleConfigOnlyDirs = null;

                while (true)
                {
                    try
                    {
                        using (var transaction = CkanTransaction.CreateTransactionScope())
                        {
                            if (toRemove.Length > 0)
                            {
                                installer.UninstallList(
                                    toRemove,
                                    ref possibleConfigOnlyDirs,
                                    registryManager,
                                    false,
                                    toInstall.Concat(toUpgrade).ToList());
                            }

                            if (toInstall.Count > 0)
                            {
                                installer.InstallList(
                                    toInstall,
                                    OperationResolverOptions(stability),
                                    registryManager,
                                    ref possibleConfigOnlyDirs,
                                    deduper,
                                    null,
                                    downloader,
                                    autoInstalled,
                                    false);
                            }

                            if (toUpgrade.Count > 0)
                            {
                                installer.Upgrade(
                                    toUpgrade,
                                    downloader,
                                    ref possibleConfigOnlyDirs,
                                    registryManager,
                                    deduper,
                                    autoInstalled,
                                    null,
                                    true,
                                    false);
                            }

                            transaction.Complete();
                        }

                        return new MackanOperationResult(
                            operationId,
                            instance.Name,
                            "completed",
                            changes,
                            events.Events,
                            null);
                    }
                    catch (ModuleDownloadErrorsKraken kraken) when (!request.SkipDownloadFailures)
                    {
                        return new MackanOperationResult(
                            operationId,
                            request.InstanceId,
                            "failed",
                            changes,
                            events.Events,
                            kraken.Message,
                            DownloadFailureDetails(kraken));
                    }
                    catch (ModuleDownloadErrorsKraken kraken)
                    {
                        var skipped = kraken.Exceptions
                            .Select(kvp => kvp.Key.identifier)
                            .Where(identifier => !string.IsNullOrWhiteSpace(identifier))
                            .ToHashSet(StringComparer.OrdinalIgnoreCase);
                        if (skipped.Count == 0)
                        {
                            return new MackanOperationResult(
                                operationId,
                                request.InstanceId,
                                "failed",
                                changes,
                                events.Events,
                                kraken.Message,
                                DownloadFailureDetails(kraken));
                        }

                        var dependers = Registry.FindReverseDependencies(
                                skipped.ToList(),
                                Array.Empty<CkanModule>(),
                                registry.InstalledModules.Select(installed => installed.Module)
                                    .Concat(toInstall)
                                    .Concat(toUpgrade)
                                    .ToArray(),
                                registry.InstalledDlls,
                                registry.InstalledDlc,
                                rel => rel.LatestAvailableWithProvides(registry, stability, criteria).Count > 1)
                            .ToHashSet(StringComparer.OrdinalIgnoreCase);
                        var toSkip = skipped.Concat(dependers).ToHashSet(StringComparer.OrdinalIgnoreCase);
                        var previousToInstallCount = toInstall.Count;
                        var previousToUpgradeCount = toUpgrade.Count;

                        toInstall.RemoveAll(module => toSkip.Contains(module.identifier));
                        toUpgrade.RemoveWhere(module => toSkip.Contains(module.identifier));
                        changes = changes
                            .Where(change => !toSkip.Contains(change.Identifier))
                            .ToArray();
                        if (toInstall.Count == previousToInstallCount
                            && toUpgrade.Count == previousToUpgradeCount)
                        {
                            return new MackanOperationResult(
                                operationId,
                                request.InstanceId,
                                "failed",
                                changes,
                                events.Events,
                                kraken.Message,
                                DownloadFailureDetails(kraken));
                        }
                    }
                }
            }
            catch (CancelledActionKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "cancelled",
                    changes,
                    events.Events,
                    kraken.Message);
            }
            catch (RegistryInUseKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    MackanErrorDetails.RegistryLock(kraken.lockfilePath));
            }
            catch (Kraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.InnerException == null
                        ? kraken.Message
                        : $"{kraken.Message}: {kraken.InnerException.Message}");
            }
            catch (Exception exception) when (exception is not ArgumentException)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    exception.Message);
            }
        }

        public MackanOperationResult InstallCkanFiles(MackanFileInstallRequest request)
        {
            var operationId = Guid.NewGuid().ToString("N");
            var events = new OperationEventRecorder();
            return Store(InstallCkanFilesCore(request, operationId, events, CancellationToken.None));
        }

        private MackanOperationResult InstallCkanFilesCore(
            MackanFileInstallRequest request,
            string operationId,
            OperationEventRecorder events,
            CancellationToken cancellationToken)
        {
            MackanChangeSummary[] changes = Array.Empty<MackanChangeSummary>();

            try
            {
                using var manager = new GameInstanceManager(events, configuration);

                var instance = SelectInstance(manager, request.InstanceId);
                if (instance == null || !instance.Valid)
                {
                    throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
                }

                var fileModules = request.FilePaths
                    .Select(CkanModule.FromFile)
                    .ToList();

                using var registryManager = RegistryManager.Instance(instance, repositoryData, initialRepositories);
                registryManager.ScanUnmanagedFiles();
                var registry = registryManager.registry;
                var stability = instance.StabilityToleranceConfig;
                var criteria = instance.VersionCriteria();
                var providerModules = request.ProviderSelections
                    .Select(selection => LatestAvailable(registry, selection.SelectedIdentifier, stability, criteria))
                    .ToArray();
                var recommendationModules = request.RecommendationSelections
                    .Select(identifier => LatestAvailable(registry, identifier, stability, criteria))
                    .ToArray();
                var modules = fileModules
                    .Concat(providerModules)
                    .Concat(recommendationModules)
                    .GroupBy(module => module.identifier, StringComparer.OrdinalIgnoreCase)
                    .Select(group => group.First())
                    .ToList();
                changes = fileModules
                    .Select(module => new MackanChangeSummary(
                        module.identifier,
                        ModuleName(module),
                        "install",
                        null,
                        module.version.ToString(),
                        new[] { "User requested" },
                        true,
                        false))
                    .Concat(request.ProviderSelections.Zip(providerModules, (selection, module) => new MackanChangeSummary(
                        module.identifier,
                        ModuleName(module),
                        "install",
                        null,
                        module.version.ToString(),
                        new[] { $"Provider for {selection.Requested} requested by {selection.RequesterIdentifier}" },
                        false,
                        true)))
                    .Concat(recommendationModules.Select(module => new MackanChangeSummary(
                        module.identifier,
                        ModuleName(module),
                        "install",
                        null,
                        module.version.ToString(),
                        new[] { "Optional recommendation selected" },
                        true,
                        false)))
                    .ToArray();

                if (!request.AllowIncompatibleCkanFiles)
                {
                    var incompatibleCkanFiles = IncompatibleCkanFiles(instance, fileModules);
                    if (incompatibleCkanFiles.Length > 0)
                    {
                        return new MackanOperationResult(
                            operationId,
                            instance.Name,
                            "failed",
                            changes,
                            events.Events,
                            "Some .ckan files are not compatible with the selected game instance.",
                            MackanErrorDetails.IncompatibleCkanFileDetails(incompatibleCkanFiles));
                    }
                }

                if (!request.SkipRecommendations)
                {
                    var recommendationChoices = FindRecommendationChoices(
                        instance,
                        registry,
                        modules,
                        recommendationModules);
                    if (recommendationChoices.Length > 0)
                    {
                        return new MackanOperationResult(
                            operationId,
                            instance.Name,
                            "failed",
                            changes,
                            events.Events,
                            "Choose optional recommendations before installing these .ckan files.",
                            MackanErrorDetails.RecommendationChoiceDetails(recommendationChoices));
                    }
                }

                var cache = manager.Cache
                    ?? throw new InvalidOperationException("Download cache is not available.");
                var installer = new ModuleInstaller(
                    instance,
                    cache,
                    manager.Configuration,
                    events,
                    cancellationToken);
                installer.InstallProgress += events.InstallProgress;
                installer.RemoveProgress += events.RemoveProgress;
                installer.OneComplete += events.ModuleComplete;

                var downloader = new NetAsyncModulesDownloader(events, cache, null, cancellationToken);
                downloader.DownloadProgress += events.DownloadProgress;
                downloader.StoreProgress += events.StoreProgress;
                downloader.OneComplete += events.ModuleComplete;

                var deduper = new InstalledFilesDeduplicator(
                    instance,
                    manager.Instances.Values,
                    repositoryData);
                var autoInstalled = new HashSet<CkanModule>();
                HashSet<string>? possibleConfigOnlyDirs = null;

                while (modules.Count > 0)
                {
                    try
                    {
                        using (var transaction = CkanTransaction.CreateTransactionScope())
                        {
                            installer.InstallList(
                                modules,
                                OperationResolverOptions(stability),
                                registryManager,
                                ref possibleConfigOnlyDirs,
                                deduper,
                                null,
                                downloader,
                                autoInstalled,
                                false);

                            transaction.Complete();
                        }

                        break;
                    }
                    catch (ModuleDownloadErrorsKraken kraken) when (!request.SkipDownloadFailures)
                    {
                        return new MackanOperationResult(
                            operationId,
                            request.InstanceId,
                            "failed",
                            changes,
                            events.Events,
                            kraken.Message,
                            DownloadFailureDetails(kraken));
                    }
                    catch (ModuleDownloadErrorsKraken kraken)
                    {
                        var skipped = DownloadFailureIdentifiers(kraken);
                        if (skipped.Count == 0)
                        {
                            return new MackanOperationResult(
                                operationId,
                                request.InstanceId,
                                "failed",
                                changes,
                                events.Events,
                                kraken.Message,
                                DownloadFailureDetails(kraken));
                        }

                        var dependers = Registry.FindReverseDependencies(
                                skipped.ToList(),
                                Array.Empty<CkanModule>(),
                                modules.ToArray(),
                                registry.InstalledDlls,
                                registry.InstalledDlc,
                                rel => rel.LatestAvailableWithProvides(registry, stability, criteria).Count > 1)
                            .ToHashSet(StringComparer.OrdinalIgnoreCase);
                        var toSkip = skipped.Concat(dependers).ToHashSet(StringComparer.OrdinalIgnoreCase);
                        var previousModuleCount = modules.Count;

                        modules.RemoveAll(module => toSkip.Contains(module.identifier));
                        changes = changes
                            .Where(change => !toSkip.Contains(change.Identifier))
                            .ToArray();
                        if (modules.Count == previousModuleCount)
                        {
                            return new MackanOperationResult(
                                operationId,
                                request.InstanceId,
                                "failed",
                                changes,
                                events.Events,
                                kraken.Message,
                                DownloadFailureDetails(kraken));
                        }
                    }
                }

                return new MackanOperationResult(
                    operationId,
                    instance.Name,
                    "completed",
                    changes,
                    events.Events,
                    null);
            }
            catch (CancelledActionKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "cancelled",
                    changes,
                    events.Events,
                    kraken.Message);
            }
            catch (RegistryInUseKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    MackanErrorDetails.RegistryLock(kraken.lockfilePath));
            }
            catch (ModuleDownloadErrorsKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    DownloadFailureDetails(kraken));
            }
            catch (TooManyModsProvideKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    MackanErrorDetails.ProviderChoiceDetails(new[] { MackanProviderChoiceFactory.From(kraken) }));
            }
            catch (Kraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.InnerException == null
                        ? kraken.Message
                        : $"{kraken.Message}: {kraken.InnerException.Message}");
            }
            catch (Exception exception) when (exception is not ArgumentException)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    exception.Message);
            }
        }

        public MackanOperationResult ImportDownloads(MackanDownloadImportRequest request)
        {
            var operationId = Guid.NewGuid().ToString("N");
            var events = ImportEventRecorder(request);
            return Store(ImportDownloadsCore(request, operationId, events, CancellationToken.None));
        }

        private MackanOperationResult ImportDownloadsCore(
            MackanDownloadImportRequest request,
            string operationId,
            OperationEventRecorder events,
            CancellationToken cancellationToken)
        {
            MackanChangeSummary[] changes = Array.Empty<MackanChangeSummary>();

            try
            {
                using var manager = new GameInstanceManager(events, configuration);

                var instance = SelectInstance(manager, request.InstanceId);
                if (instance == null || !instance.Valid)
                {
                    throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
                }

                var importFiles = ImportFiles(request.Paths);
                if (importFiles.Count == 0)
                {
                    throw new ArgumentException("No import files were found.");
                }

                var cache = manager.Cache
                    ?? throw new InvalidOperationException("Download cache is not available.");
                using var registryManager = RegistryManager.Instance(instance, repositoryData, initialRepositories);
                var registry = registryManager.registry;
                var toInstall = new List<CkanModule>();

                var success = ModuleImporter.ImportFiles(
                    importFiles,
                    events,
                    toInstall.Add,
                    registry,
                    instance,
                    cache,
                    request.DeleteImportedFiles);
                changes = toInstall
                    .Select(module => new MackanChangeSummary(
                        module.identifier,
                        ModuleName(module),
                        "install",
                        null,
                        module.version.ToString(),
                        new[] { "Imported download" },
                        true,
                        false))
                    .ToArray();

                if (!success)
                {
                    return new MackanOperationResult(
                        operationId,
                        instance.Name,
                        "failed",
                        changes,
                        events.Events,
                        "No selected downloads matched known CKAN modules.");
                }

                if (toInstall.Count > 0 && request.InstallImportedModules && !request.PreviewBeforeInstall)
                {
                    var stability = instance.StabilityToleranceConfig;
                    var criteria = instance.VersionCriteria();
                    var installer = new ModuleInstaller(
                        instance,
                        cache,
                        manager.Configuration,
                        events,
                        cancellationToken);
                    installer.InstallProgress += events.InstallProgress;
                    installer.RemoveProgress += events.RemoveProgress;
                    installer.OneComplete += events.ModuleComplete;

                    var downloader = new NetAsyncModulesDownloader(events, cache, null, cancellationToken);
                    downloader.DownloadProgress += events.DownloadProgress;
                    downloader.StoreProgress += events.StoreProgress;
                    downloader.OneComplete += events.ModuleComplete;

                    var deduper = new InstalledFilesDeduplicator(
                        instance,
                        manager.Instances.Values,
                        repositoryData);
                    var autoInstalled = new HashSet<CkanModule>();
                    HashSet<string>? possibleConfigOnlyDirs = null;

                    while (toInstall.Count > 0)
                    {
                        try
                        {
                            using (var transaction = CkanTransaction.CreateTransactionScope())
                            {
                                installer.InstallList(
                                    toInstall,
                                    OperationResolverOptions(stability),
                                    registryManager,
                                    ref possibleConfigOnlyDirs,
                                    deduper,
                                    null,
                                    downloader,
                                    autoInstalled,
                                    false);
                                transaction.Complete();
                            }

                            break;
                        }
                        catch (ModuleDownloadErrorsKraken kraken) when (!request.SkipDownloadFailures)
                        {
                            return new MackanOperationResult(
                                operationId,
                                request.InstanceId,
                                "failed",
                                changes,
                                events.Events,
                                kraken.Message,
                                DownloadFailureDetails(kraken));
                        }
                        catch (ModuleDownloadErrorsKraken kraken)
                        {
                            var skipped = DownloadFailureIdentifiers(kraken);
                            if (skipped.Count == 0)
                            {
                                return new MackanOperationResult(
                                    operationId,
                                    request.InstanceId,
                                    "failed",
                                    changes,
                                    events.Events,
                                    kraken.Message,
                                    DownloadFailureDetails(kraken));
                            }

                            var dependers = Registry.FindReverseDependencies(
                                    skipped.ToList(),
                                    Array.Empty<CkanModule>(),
                                    toInstall.ToArray(),
                                    registry.InstalledDlls,
                                    registry.InstalledDlc,
                                    rel => rel.LatestAvailableWithProvides(registry, stability, criteria).Count > 1)
                                .ToHashSet(StringComparer.OrdinalIgnoreCase);
                            var toSkip = skipped.Concat(dependers).ToHashSet(StringComparer.OrdinalIgnoreCase);
                            var previousInstallCount = toInstall.Count;

                            toInstall.RemoveAll(module => toSkip.Contains(module.identifier));
                            changes = changes
                                .Where(change => !toSkip.Contains(change.Identifier))
                                .ToArray();
                            if (toInstall.Count == previousInstallCount)
                            {
                                return new MackanOperationResult(
                                    operationId,
                                    request.InstanceId,
                                    "failed",
                                    changes,
                                    events.Events,
                                    kraken.Message,
                                    DownloadFailureDetails(kraken));
                            }
                        }
                    }
                }

                return new MackanOperationResult(
                    operationId,
                    instance.Name,
                    "completed",
                    changes,
                    events.Events,
                    null);
            }
            catch (CancelledActionKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "cancelled",
                    changes,
                    events.Events,
                    kraken.Message);
            }
            catch (RegistryInUseKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    MackanErrorDetails.RegistryLock(kraken.lockfilePath));
            }
            catch (ModuleDownloadErrorsKraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.Message,
                    DownloadFailureDetails(kraken));
            }
            catch (Kraken kraken)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    kraken.InnerException == null
                        ? kraken.Message
                        : $"{kraken.Message}: {kraken.InnerException.Message}");
            }
            catch (Exception exception) when (exception is not ArgumentException)
            {
                return new MackanOperationResult(
                    operationId,
                    request.InstanceId,
                    "failed",
                    changes,
                    events.Events,
                    exception.Message);
            }
        }

        private static OperationEventRecorder ImportEventRecorder(MackanDownloadImportRequest request)
            => new OperationEventRecorder(
                request.DeleteImportedFiles
                    ? new[] { true, request.InstallImportedModules || request.PreviewBeforeInstall }
                    : new[] { request.InstallImportedModules || request.PreviewBeforeInstall });

        public MackanOperationResult GetStatus(string operationId)
            => Operations.TryGetValue(operationId, out var state)
                ? state.Snapshot()
                : throw new ArgumentException($"Operation '{operationId}' was not found.");

        public MackanOperationResult CancelOperation(string operationId)
        {
            if (!Operations.TryGetValue(operationId, out var state))
            {
                throw new ArgumentException($"Operation '{operationId}' was not found.");
            }

            state.RequestCancel();
            return state.Snapshot();
        }

        private static MackanOperationResult Store(MackanOperationResult result)
        {
            Operations[result.OperationId] = OperationState.Final(result);
            return result;
        }

        private static MackanErrorDetails? ErrorDetails(Exception exception)
            => exception switch
            {
                RegistryInUseKraken registryInUse => MackanErrorDetails.RegistryLock(registryInUse.lockfilePath),
                ModuleDownloadErrorsKraken downloadErrors => DownloadFailureDetails(downloadErrors),
                _ => null,
            };

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

        private static HashSet<FileInfo> ImportFiles(IEnumerable<string> paths)
        {
            var files = new HashSet<FileInfo>();
            foreach (var path in paths)
            {
                if (Directory.Exists(path))
                {
                    foreach (var file in Directory.EnumerateFiles(path))
                    {
                        files.Add(new FileInfo(file));
                    }
                }
                else if (File.Exists(path))
                {
                    files.Add(new FileInfo(path));
                }
            }
            return files;
        }

        private static RelationshipResolverOptions OperationResolverOptions(StabilityToleranceConfig stability)
            => new RelationshipResolverOptions(stability)
            {
                with_recommends = false,
                with_suggests = false,
                with_all_suggests = false,
                without_toomanyprovides_kraken = false,
                without_enforce_consistency = false,
                proceed_with_inconsistencies = false,
            };

        private static string ModuleName(CkanModule module)
            => string.IsNullOrWhiteSpace(module.name) ? module.identifier : module.name;

        private static MackanErrorDetails DownloadFailureDetails(ModuleDownloadErrorsKraken kraken)
            => MackanErrorDetails.DownloadFailureDetails(kraken.Exceptions
                .Select(kvp => new MackanDownloadFailure(
                    kvp.Key.identifier,
                    ModuleName(kvp.Key),
                    kvp.Key.version.ToString(),
                    kvp.Value.Message,
                    (kvp.Key.download ?? Enumerable.Empty<Uri>())
                        .Select(uri => uri.ToString())
                        .ToArray()))
                .OrderBy(failure => failure.Name, StringComparer.OrdinalIgnoreCase)
                .ThenBy(failure => failure.Identifier, StringComparer.OrdinalIgnoreCase)
                .ToArray());

        private static HashSet<string> DownloadFailureIdentifiers(ModuleDownloadErrorsKraken kraken)
            => kraken.Exceptions
                .Select(kvp => kvp.Key.identifier)
                .Where(identifier => !string.IsNullOrWhiteSpace(identifier))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

        private static MackanIncompatibleCkanFile[] IncompatibleCkanFiles(
            GameInstance instance,
            IReadOnlyCollection<CkanModule> modules)
            => modules
                .Where(module => !module.IsCompatible(instance.VersionCriteria()))
                .Select(module => new MackanIncompatibleCkanFile(
                    module.identifier,
                    ModuleName(module),
                    module.version.ToString(),
                    module.CompatibleGameVersions(instance.Game)))
                .OrderBy(module => module.Name, StringComparer.OrdinalIgnoreCase)
                .ThenBy(module => module.Identifier, StringComparer.OrdinalIgnoreCase)
                .ToArray();

        private static MackanRecommendationChoice[] FindRecommendationChoices(
            GameInstance instance,
            Registry registry,
            IReadOnlyCollection<CkanModule> modules,
            IReadOnlyCollection<CkanModule> selectedRecommendations)
        {
            var resolvedInstallModules = new RelationshipResolver(
                    modules,
                    Array.Empty<CkanModule>(),
                    OperationResolverOptions(instance.StabilityToleranceConfig),
                    registry,
                    instance.Game,
                    instance.VersionCriteria())
                .ModList(false)
                .ToArray();
            var fullInstallSet = DistinctModules(modules.Concat(resolvedInstallModules));
            return ModuleInstaller.FindRecommendations(
                    instance,
                    fullInstallSet,
                    fullInstallSet,
                    Array.Empty<CkanModule>(),
                    selectedRecommendations,
                    registry,
                    out var recommendations,
                    out var suggestions,
                    out var supporters)
                ? MackanRecommendationChoiceFactory.From(recommendations, suggestions, supporters)
                : Array.Empty<MackanRecommendationChoice>();
        }

        private static CkanModule[] DistinctModules(IEnumerable<CkanModule> modules)
            => modules
                .GroupBy(module => module.identifier, StringComparer.OrdinalIgnoreCase)
                .Select(group => group.First())
                .ToArray();

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;
        private readonly IMackanChangeSetProvider changeSetProvider;
        private readonly IReadOnlyCollection<Repository> initialRepositories;

        private static readonly ConcurrentDictionary<string, OperationState> Operations = new();

        private sealed class OperationState
        {
            private OperationState(
                string operationId,
                string? instanceId,
                string status,
                MackanChangeSummary[] changes,
                OperationEventRecorder? recorder,
                MackanOperationEvent[] events,
                string? error,
                MackanErrorDetails? errorDetails,
                CancellationTokenSource? cancellation)
            {
                OperationId = operationId;
                InstanceId = instanceId;
                this.status = status;
                this.changes = changes;
                this.recorder = recorder;
                this.events = events;
                this.error = error;
                this.errorDetails = errorDetails;
                this.cancellation = cancellation;
            }

            public string OperationId { get; }
            public string? InstanceId { get; private set; }

            public static OperationState Running(
                string operationId,
                string? instanceId,
                OperationEventRecorder recorder,
                CancellationTokenSource cancellation)
                => new OperationState(
                    operationId,
                    instanceId,
                    "running",
                    Array.Empty<MackanChangeSummary>(),
                    recorder,
                    Array.Empty<MackanOperationEvent>(),
                    null,
                    null,
                    cancellation);

            public static OperationState Final(MackanOperationResult result)
                => new OperationState(
                    result.OperationId,
                    result.InstanceId,
                    result.Status,
                    result.Changes,
                    null,
                    result.Events,
                    result.Error,
                    result.ErrorDetails,
                    null);

            public MackanOperationResult Snapshot()
            {
                lock (sync)
                {
                    return new MackanOperationResult(
                        OperationId,
                        InstanceId,
                        status,
                        changes,
                        recorder?.Events ?? events,
                        error,
                        errorDetails);
                }
            }

            public void Complete(MackanOperationResult result)
            {
                lock (sync)
                {
                    InstanceId = result.InstanceId;
                    status = result.Status;
                    changes = result.Changes;
                    events = result.Events;
                    error = result.Error;
                    errorDetails = result.ErrorDetails;
                    cancellation?.Dispose();
                    cancellation = null;
                    recorder = null;
                }
            }

            public void RequestCancel()
            {
                lock (sync)
                {
                    if (status is "running" or "cancelling")
                    {
                        cancellation?.Cancel();
                        if (status != "cancelling")
                        {
                            status = "cancelling";
                            recorder?.CancellationRequested();
                        }
                    }
                }
            }

            private readonly object sync = new();
            private string status;
            private MackanChangeSummary[] changes;
            private OperationEventRecorder? recorder;
            private MackanOperationEvent[] events;
            private string? error;
            private MackanErrorDetails? errorDetails;
            private CancellationTokenSource? cancellation;
        }

        private sealed class OperationEventRecorder : IUser
        {
            public OperationEventRecorder(IEnumerable<bool>? yesNoResponses = null)
            {
                this.yesNoResponses = yesNoResponses == null
                    ? new Queue<bool>()
                    : new Queue<bool>(yesNoResponses);
            }

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
                return yesNoResponses.Count > 0
                    ? yesNoResponses.Dequeue()
                    : true;
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

            public void InstallProgress(CkanModule module, long remaining, long total)
                => Add("installProgress", module.name, Percent(remaining, total), module.identifier, remaining, total);

            public void RemoveProgress(InstalledModule module, long remaining, long total)
                => Add("removeProgress", module.Module.name, Percent(remaining, total), module.identifier, remaining, total);

            public void DownloadProgress(CkanModule module, long remaining, long total)
                => Add("downloadProgress", module.name, Percent(remaining, total), module.identifier, remaining, total);

            public void StoreProgress(CkanModule module, long remaining, long total)
                => Add("storeProgress", module.name, Percent(remaining, total), module.identifier, remaining, total);

            public void ModuleComplete(CkanModule module)
                => Add("complete", module.name, 100, module.identifier, 0, module.install_size);

            public void OperationQueued()
                => Add("message", "Operation queued", null, null, null, null);

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

            private static int? Percent(long remaining, long total)
                => total > 0 ? (int)(100 * (total - remaining) / total) : null;

            private readonly List<MackanOperationEvent> events = new();
            private readonly Queue<bool> yesNoResponses;
        }
    }
}

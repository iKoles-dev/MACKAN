using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class MackanServiceDispatcher
    {
        public const string ProtocolVersion = "1";

        public MackanServiceDispatcher(
            Func<string>? versionProvider = null,
            Func<MackanVersionResult>? appVersionProvider = null,
            IMackanInstanceProvider? instanceProvider = null,
            IMackanModuleProvider? moduleProvider = null,
            IMackanRepositoryProvider? repositoryProvider = null,
            IMackanChangeSetProvider? changeSetProvider = null,
            IMackanOperationProvider? operationProvider = null,
            IMackanExportProvider? exportProvider = null,
            IMackanMaintenanceProvider? maintenanceProvider = null,
            IMackanSettingsProvider? settingsProvider = null,
            IMackanLabelProvider? labelProvider = null,
            IMackanUpdateProvider? updateProvider = null)
        {
            this.versionProvider = versionProvider
                ?? (() => Meta.GetVersion(VersionFormat.Full)?.ToString() ?? "unknown");
            this.appVersionProvider = appVersionProvider
                ?? (() => MackanVersionResult.Current(this.versionProvider()));
            this.instanceProvider = instanceProvider ?? new CoreMackanInstanceProvider();
            this.moduleProvider = moduleProvider ?? new CoreMackanModuleProvider();
            this.repositoryProvider = repositoryProvider ?? new CoreMackanRepositoryProvider();
            this.changeSetProvider = changeSetProvider ?? new CoreMackanChangeSetProvider();
            this.operationProvider = operationProvider ?? new CoreMackanOperationProvider();
            this.exportProvider = exportProvider ?? new CoreMackanExportProvider();
            this.maintenanceProvider = maintenanceProvider ?? new CoreMackanMaintenanceProvider();
            this.settingsProvider = settingsProvider ?? new CoreMackanSettingsProvider();
            this.labelProvider = labelProvider ?? new CoreMackanLabelProvider();
            this.updateProvider = updateProvider ?? new CoreMackanUpdateProvider();
        }

        public string Handle(string requestLine)
        {
            object? id = null;
            try
            {
                using var document = JsonDocument.Parse(requestLine);
                var root = document.RootElement;
                id = ReadId(root);

                if (!root.TryGetProperty("method", out var methodElement)
                    || methodElement.ValueKind != JsonValueKind.String)
                {
                    return Error(id, -32600, "Invalid Request");
                }

                return methodElement.GetString() switch
                {
                    "app.health" => Result(id, new
                    {
                        status = "ok",
                        protocolVersion = ProtocolVersion,
                        ckanVersion = versionProvider(),
                    }),
                    "app.version" => Result(id, appVersionProvider()),
                    "app.checkForUpdates" => Result(id, updateProvider.CheckForUpdates(ReadBoolParam(root, "useDevBuilds"))),
                    "instances.list" => Result(id, instanceProvider.ListInstances()),
                    "instances.add" => InstanceAdd(id, root),
                    "instances.cloneOptions" => InstanceCloneOptions(id, root),
                    "instances.clone" => InstanceClone(id, root),
                    "instances.fake" => InstanceFake(id, root),
                    "instances.setDefault" => InstanceSetDefault(id, root),
                    "instances.remove" => InstanceRemove(id, root),
                    "instances.rename" => InstanceRename(id, root),
                    "instances.launchOptions" => InstanceLaunchOptions(id, root),
                    "instances.updateLaunchOptions" => InstanceUpdateLaunchOptions(id, root),
                    "instances.launch" => InstanceLaunch(id, root),
                    "mods.list" => Result(id, moduleProvider.ListModules(ReadStringParam(root, "instanceId"))),
                    "mods.startList" => Result(id, moduleProvider.StartListModules(ReadStringParam(root, "instanceId"))),
                    "mods.listStatus" => ModuleListStatus(id, root),
                    "mods.cancelList" => ModuleCancelList(id, root),
                    "mods.details" => ModuleDetails(id, root),
                    "mods.setAutoInstalled" => ModuleSetAutoInstalled(id, root),
                    "labels.list" => Result(id, labelProvider.ListLabels(ReadStringParam(root, "instanceId"))),
                    "labels.toggleModule" => LabelsToggleModule(id, root),
                    "labels.upsert" => LabelsUpsert(id, root),
                    "labels.delete" => LabelsDelete(id, root),
                    "mods.resolveChanges" => ResolveChanges(id, root),
                    "operations.applyChanges" => ApplyChanges(id, root),
                    "operations.startApplyChanges" => StartApplyChanges(id, root),
                    "operations.installCkanFiles" => InstallCkanFiles(id, root),
                    "operations.startInstallCkanFiles" => StartInstallCkanFiles(id, root),
                    "operations.importDownloads" => ImportDownloads(id, root),
                    "operations.startImportDownloads" => StartImportDownloads(id, root),
                    "operations.status" => OperationStatus(id, root),
                    "operations.cancel" => OperationCancel(id, root),
                    "exports.modList" => ExportModList(id, root),
                    "exports.modpack" => ExportModpack(id, root),
                    "maintenance.scan" => MaintenanceScan(id, root),
                    "maintenance.unmanagedFiles" => MaintenanceUnmanagedFiles(id, root),
                    "maintenance.history" => MaintenanceHistory(id, root),
                    "maintenance.playTime" => Result(id, maintenanceProvider.ListPlayTime()),
                    "maintenance.updatePlayTime" => MaintenanceUpdatePlayTime(id, root),
                    "maintenance.downloadStatistics" => MaintenanceDownloadStatistics(id, root),
                    "maintenance.cacheInfo" => Result(id, maintenanceProvider.CacheInfo()),
                    "maintenance.clearCache" => Result(id, maintenanceProvider.ClearCache()),
                    "maintenance.purgeCacheToLimit" => MaintenancePurgeCacheToLimit(id, root),
                    "maintenance.deduplicate" => Result(id, maintenanceProvider.Deduplicate()),
                    "maintenance.repairRegistry" => MaintenanceRepairRegistry(id, root),
                    "maintenance.removeRegistryLock" => MaintenanceRemoveRegistryLock(id, root),
                    "repositories.list" => Result(id, repositoryProvider.ListRepositories(ReadStringParam(root, "instanceId"))),
                    "repositories.available" => Result(id, repositoryProvider.ListAvailableRepositories(ReadStringParam(root, "instanceId"))),
                    "repositories.add" => RepositoryAdd(id, root),
                    "repositories.remove" => RepositoryRemove(id, root),
                    "repositories.setPriority" => RepositorySetPriority(id, root),
                    "repositories.refresh" => RepositoryRefresh(id, root),
                    "repositories.startRefresh" => RepositoryStartRefresh(id, root),
                    "repositories.refreshStatus" => RepositoryRefreshStatus(id, root),
                    "repositories.cancelRefresh" => RepositoryCancelRefresh(id, root),
                    "settings.get" => Result(id, settingsProvider.GetSettings()),
                    "settings.update" => SettingsUpdate(id, root),
                    "settings.general" => Result(
                        id,
                        settingsProvider.GetGeneralSettings(ReadStringParam(root, "instanceId"))),
                    "settings.updateGeneral" => SettingsUpdateGeneral(id, root),
                    "settings.compatibleVersions" => Result(
                        id,
                        settingsProvider.GetCompatibleGameVersions(ReadStringParam(root, "instanceId"))),
                    "settings.updateCompatibleVersions" => SettingsUpdateCompatibleVersions(id, root),
                    "settings.stabilityTolerance" => Result(
                        id,
                        settingsProvider.GetStabilityTolerance(ReadStringParam(root, "instanceId"))),
                    "settings.updateStabilityTolerance" => SettingsUpdateStabilityTolerance(id, root),
                    "settings.updateModuleStabilityTolerance" => SettingsUpdateModuleStabilityTolerance(id, root),
                    "settings.preferredHosts" => Result(
                        id,
                        settingsProvider.GetPreferredHosts(ReadStringParam(root, "instanceId"))),
                    "settings.updatePreferredHosts" => SettingsUpdatePreferredHosts(id, root),
                    "settings.installFilters" => Result(
                        id,
                        settingsProvider.GetInstallFilters(ReadStringParam(root, "instanceId"))),
                    "settings.updateInstallFilters" => SettingsUpdateInstallFilters(id, root),
                    "settings.recommendations" => Result(
                        id,
                        settingsProvider.GetRecommendationSettings(ReadStringParam(root, "instanceId"))),
                    "settings.updateRecommendations" => SettingsUpdateRecommendations(id, root),
                    "settings.authTokens" => Result(id, settingsProvider.GetAuthTokens()),
                    "settings.addAuthToken" => SettingsAddAuthToken(id, root),
                    "settings.removeAuthToken" => SettingsRemoveAuthToken(id, root),
                    _ => Error(id, -32601, "Method not found"),
                };
            }
            catch (JsonException)
            {
                return Error(null, -32700, "Parse error");
            }
            catch (RegistryInUseKraken registryInUse)
            {
                return Error(
                    id,
                    -32010,
                    registryInUse.Message,
                    MackanErrorDetails.RegistryLock(registryInUse.lockfilePath));
            }
            catch (MackanLaunchFailureException launchFailureException)
            {
                return Error(
                    id,
                    -32000,
                    launchFailureException.Message,
                    MackanErrorDetails.LaunchFailureDetails(launchFailureException.Command));
            }
            catch (ArgumentException argumentException)
            {
                return Error(id, -32602, argumentException.Message);
            }
            catch (InvalidOperationException invalidOperationException)
            {
                return Error(id, -32000, invalidOperationException.Message);
            }
        }

        private readonly Func<string> versionProvider;
        private readonly Func<MackanVersionResult> appVersionProvider;
        private readonly IMackanInstanceProvider instanceProvider;
        private readonly IMackanModuleProvider moduleProvider;
        private readonly IMackanRepositoryProvider repositoryProvider;
        private readonly IMackanChangeSetProvider changeSetProvider;
        private readonly IMackanOperationProvider operationProvider;
        private readonly IMackanExportProvider exportProvider;
        private readonly IMackanMaintenanceProvider maintenanceProvider;
        private readonly IMackanSettingsProvider settingsProvider;
        private readonly IMackanLabelProvider labelProvider;
        private readonly IMackanUpdateProvider updateProvider;
        private static readonly JsonSerializerOptions SerializerOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };

        private static object? ReadId(JsonElement root)
        {
            if (!root.TryGetProperty("id", out var idElement))
            {
                return null;
            }
            return idElement.ValueKind switch
            {
                JsonValueKind.Number when idElement.TryGetInt64(out var number) => number,
                JsonValueKind.String => idElement.GetString(),
                JsonValueKind.Null => null,
                _ => idElement.GetRawText(),
            };
        }

        private static string? ReadStringParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind != JsonValueKind.String)
            {
                return null;
            }
            return valueElement.GetString();
        }

        private static int? ReadIntParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind != JsonValueKind.Number
                || !valueElement.TryGetInt32(out var value))
            {
                return null;
            }
            return value;
        }

        private static bool? ReadBoolParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind is not JsonValueKind.True and not JsonValueKind.False)
            {
                return null;
            }
            return valueElement.GetBoolean();
        }

        private static double? ReadDoubleParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind != JsonValueKind.Number
                || !valueElement.TryGetDouble(out var value))
            {
                return null;
            }
            return value;
        }

        private static long? ReadLongParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind != JsonValueKind.Number
                || !valueElement.TryGetInt64(out var value))
            {
                return null;
            }
            return value;
        }

        private static string[] ReadStringArrayParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return Array.Empty<string>();
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<string>();
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.String
                    || string.IsNullOrWhiteSpace(item.GetString()))
                {
                    throw new ArgumentException("Invalid params");
                }
                values.Add(item.GetString()!);
            }
            return values.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        }

        private static string[]? ReadOptionalStringArrayParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return null;
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<string>();
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.String
                    || string.IsNullOrWhiteSpace(item.GetString()))
                {
                    throw new ArgumentException("Invalid params");
                }
                values.Add(item.GetString()!);
            }
            return values.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        }

        private static MackanProviderSelection[] ReadProviderSelections(JsonElement root)
        {
            const string name = "providerSelections";
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return Array.Empty<MackanProviderSelection>();
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<MackanProviderSelection>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object
                    || !TryReadStringProperty(item, "requested", out var requested)
                    || !TryReadStringProperty(item, "requesterIdentifier", out var requesterIdentifier)
                    || !TryReadStringProperty(item, "selectedIdentifier", out var selectedIdentifier))
                {
                    throw new ArgumentException("Invalid params");
                }

                if (seen.Add($"{requesterIdentifier}\n{requested}"))
                {
                    values.Add(new MackanProviderSelection(
                        requested,
                        requesterIdentifier,
                        selectedIdentifier));
                }
            }

            return values.ToArray();
        }

        private static MackanModuleVersionSelection[] ReadInstallVersions(JsonElement root)
        {
            const string name = "installVersions";
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return Array.Empty<MackanModuleVersionSelection>();
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<MackanModuleVersionSelection>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object
                    || !TryReadStringProperty(item, "identifier", out var identifier)
                    || !TryReadStringProperty(item, "version", out var version))
                {
                    throw new ArgumentException("Invalid params");
                }

                if (seen.Add($"{identifier}\n{version}"))
                {
                    values.Add(new MackanModuleVersionSelection(identifier, version));
                }
            }

            return values.ToArray();
        }

        private static MackanModpackRelationshipAssignment[] ReadModpackRelationshipAssignments(JsonElement root)
        {
            const string name = "relationshipAssignments";
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return Array.Empty<MackanModpackRelationshipAssignment>();
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<MackanModpackRelationshipAssignment>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object
                    || !TryReadStringProperty(item, "identifier", out var identifier)
                    || !TryReadStringProperty(item, "kind", out var kind))
                {
                    throw new ArgumentException("Invalid params");
                }

                if (seen.Add(identifier))
                {
                    values.Add(new MackanModpackRelationshipAssignment(identifier, kind));
                }
            }

            return values.ToArray();
        }

        private static bool TryReadStringProperty(JsonElement element, string name, out string value)
        {
            value = "";
            if (!element.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind != JsonValueKind.String
                || string.IsNullOrWhiteSpace(valueElement.GetString()))
            {
                return false;
            }
            value = valueElement.GetString()!.Trim();
            return true;
        }

        private static string?[] ReadNullableStringArrayParam(JsonElement root, string name)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty(name, out var valueElement)
                || valueElement.ValueKind == JsonValueKind.Null
                || valueElement.ValueKind == JsonValueKind.Undefined)
            {
                return Array.Empty<string?>();
            }

            if (valueElement.ValueKind != JsonValueKind.Array)
            {
                throw new ArgumentException("Invalid params");
            }

            var values = new List<string?>();
            var seenHosts = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var hasPlaceholder = false;
            foreach (var item in valueElement.EnumerateArray())
            {
                if (item.ValueKind == JsonValueKind.Null)
                {
                    if (!hasPlaceholder)
                    {
                        values.Add(null);
                        hasPlaceholder = true;
                    }
                    continue;
                }

                if (item.ValueKind != JsonValueKind.String
                    || string.IsNullOrWhiteSpace(item.GetString()))
                {
                    throw new ArgumentException("Invalid params");
                }

                var host = item.GetString()!.Trim();
                if (seenHosts.Add(host))
                {
                    values.Add(host);
                }
            }
            return values.ToArray();
        }

        private static string Result(object? id, object result)
            => JsonSerializer.Serialize(new
            {
                jsonrpc = "2.0",
                id,
                result,
            }, SerializerOptions);

        private static string Error(object? id, int code, string message)
            => JsonSerializer.Serialize(new
            {
                jsonrpc = "2.0",
                id,
                error = new
                {
                    code,
                    message,
                },
            }, SerializerOptions);

        private static string Error(object? id, int code, string message, MackanErrorDetails data)
            => JsonSerializer.Serialize(new
            {
                jsonrpc = "2.0",
                id,
                error = new
                {
                    code,
                    message,
                    data,
                },
            }, SerializerOptions);

        private string ModuleDetails(object? id, JsonElement root)
        {
            var identifier = ReadStringParam(root, "identifier");
            if (string.IsNullOrWhiteSpace(identifier))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, moduleProvider.GetModuleDetails(
                ReadStringParam(root, "instanceId"),
                identifier));
        }

        private string ModuleSetAutoInstalled(object? id, JsonElement root)
        {
            var identifier = ReadStringParam(root, "identifier");
            var isAutoInstalled = ReadBoolParam(root, "isAutoInstalled");
            if (string.IsNullOrWhiteSpace(identifier) || isAutoInstalled == null)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, moduleProvider.SetAutoInstalled(
                ReadStringParam(root, "instanceId"),
                identifier,
                isAutoInstalled.Value));
        }

        private string LabelsToggleModule(object? id, JsonElement root)
        {
            var labelName = ReadStringParam(root, "labelName");
            var identifier = ReadStringParam(root, "identifier");
            if (string.IsNullOrWhiteSpace(labelName) || string.IsNullOrWhiteSpace(identifier))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, labelProvider.ToggleModule(
                ReadStringParam(root, "instanceId"),
                labelName,
                identifier));
        }

        private string LabelsUpsert(object? id, JsonElement root)
        {
            var label = ReadLabelEditParam(root);
            if (label == null)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, labelProvider.UpsertLabel(
                ReadStringParam(root, "instanceId"),
                ReadStringParam(root, "originalName"),
                ReadStringParam(root, "originalInstanceName"),
                label));
        }

        private string LabelsDelete(object? id, JsonElement root)
        {
            var name = ReadStringParam(root, "name");
            if (string.IsNullOrWhiteSpace(name))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, labelProvider.DeleteLabel(
                ReadStringParam(root, "instanceId"),
                name,
                ReadStringParam(root, "instanceName")));
        }

        private static MackanModuleLabelEdit? ReadLabelEditParam(JsonElement root)
        {
            if (!root.TryGetProperty("params", out var paramsElement)
                || paramsElement.ValueKind != JsonValueKind.Object
                || !paramsElement.TryGetProperty("label", out var labelElement)
                || labelElement.ValueKind != JsonValueKind.Object
                || !labelElement.TryGetProperty("name", out var nameElement)
                || nameElement.ValueKind != JsonValueKind.String
                || string.IsNullOrWhiteSpace(nameElement.GetString()))
            {
                return null;
            }

            return new MackanModuleLabelEdit(
                nameElement.GetString()!,
                ReadOptionalString(labelElement, "instanceName"),
                ReadOptionalString(labelElement, "colorHex"),
                ReadBool(labelElement, "hide"),
                ReadBool(labelElement, "notifyOnChange"),
                ReadBool(labelElement, "removeOnChange"),
                ReadBool(labelElement, "alertOnInstall"),
                ReadBool(labelElement, "removeOnInstall"),
                ReadBool(labelElement, "holdVersion"),
                ReadBool(labelElement, "ignoreMissingFiles"));
        }

        private static string? ReadOptionalString(JsonElement element, string name)
            => element.TryGetProperty(name, out var valueElement)
               && valueElement.ValueKind == JsonValueKind.String
                ? valueElement.GetString()
                : null;

        private static bool ReadBool(JsonElement element, string name)
            => element.TryGetProperty(name, out var valueElement)
               && valueElement.ValueKind is JsonValueKind.True or JsonValueKind.False
               && valueElement.GetBoolean();

        private string InstanceSetDefault(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.SetDefaultInstance(instanceId));
        }

        private string InstanceAdd(object? id, JsonElement root)
        {
            var path = ReadStringParam(root, "path");
            var name = ReadStringParam(root, "name");
            if (string.IsNullOrWhiteSpace(path) || string.IsNullOrWhiteSpace(name))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.AddInstance(path, name));
        }

        private string InstanceCloneOptions(object? id, JsonElement root)
        {
            var sourceInstanceId = ReadStringParam(root, "sourceInstanceId");
            if (string.IsNullOrWhiteSpace(sourceInstanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.CloneOptions(sourceInstanceId));
        }

        private string InstanceClone(object? id, JsonElement root)
        {
            var sourceInstanceId = ReadStringParam(root, "sourceInstanceId");
            var newName = ReadStringParam(root, "newName");
            var newPath = ReadStringParam(root, "newPath");
            if (string.IsNullOrWhiteSpace(sourceInstanceId)
                || string.IsNullOrWhiteSpace(newName)
                || string.IsNullOrWhiteSpace(newPath))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.CloneInstance(
                sourceInstanceId,
                newName,
                newPath,
                ReadBoolParam(root, "shareStock") ?? false,
                ReadOptionalStringArrayParam(root, "leaveEmptyPaths")));
        }

        private string InstanceFake(object? id, JsonElement root)
        {
            var name = ReadStringParam(root, "name");
            var path = ReadStringParam(root, "path");
            var version = ReadStringParam(root, "version");
            var gameId = ReadStringParam(root, "gameId");
            if (string.IsNullOrWhiteSpace(name)
                || string.IsNullOrWhiteSpace(path)
                || string.IsNullOrWhiteSpace(version)
                || string.IsNullOrWhiteSpace(gameId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.FakeInstance(
                name,
                path,
                version,
                gameId,
                ReadStringParam(root, "makingHistoryVersion"),
                ReadStringParam(root, "breakingGroundVersion"),
                ReadBoolParam(root, "setDefault") ?? false));
        }

        private string InstanceRemove(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.RemoveInstance(instanceId));
        }

        private string InstanceRename(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            var newName = ReadStringParam(root, "newName");
            if (string.IsNullOrWhiteSpace(instanceId) || string.IsNullOrWhiteSpace(newName))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.RenameInstance(instanceId, newName));
        }

        private string InstanceLaunchOptions(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.LaunchOptions(instanceId));
        }

        private string InstanceUpdateLaunchOptions(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            var commandLines = ReadStringArrayParam(root, "commandLines");
            if (string.IsNullOrWhiteSpace(instanceId) || commandLines.Length == 0)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.UpdateLaunchOptions(instanceId, commandLines));
        }

        private string InstanceLaunch(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, instanceProvider.LaunchGame(
                instanceId,
                ReadStringParam(root, "commandLine"),
                ReadBoolParam(root, "suppressIncompatibleWarnings") ?? false));
        }

        private string ResolveChanges(object? id, JsonElement root)
            => Result(id, changeSetProvider.ResolveChanges(new MackanChangeSetRequest(
                ReadStringParam(root, "instanceId"),
                ReadStringArrayParam(root, "install"),
                ReadStringArrayParam(root, "remove"),
                ReadStringArrayParam(root, "upgrade"),
                ReadStringArrayParam(root, "replace"),
                ReadProviderSelections(root),
                ReadInstallVersions(root))));

        private string ApplyChanges(object? id, JsonElement root)
            => Result(id, operationProvider.ApplyChanges(new MackanChangeSetRequest(
                ReadStringParam(root, "instanceId"),
                ReadStringArrayParam(root, "install"),
                ReadStringArrayParam(root, "remove"),
                ReadStringArrayParam(root, "upgrade"),
                ReadStringArrayParam(root, "replace"),
                ReadProviderSelections(root),
                ReadInstallVersions(root),
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));

        private string StartApplyChanges(object? id, JsonElement root)
            => Result(id, operationProvider.StartApplyChanges(new MackanChangeSetRequest(
                ReadStringParam(root, "instanceId"),
                ReadStringArrayParam(root, "install"),
                ReadStringArrayParam(root, "remove"),
                ReadStringArrayParam(root, "upgrade"),
                ReadStringArrayParam(root, "replace"),
                ReadProviderSelections(root),
                ReadInstallVersions(root),
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));

        private string InstallCkanFiles(object? id, JsonElement root)
        {
            var filePaths = ReadStringArrayParam(root, "filePaths");
            if (filePaths.Length == 0)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.InstallCkanFiles(new MackanFileInstallRequest(
                ReadStringParam(root, "instanceId"),
                filePaths,
                ReadProviderSelections(root),
                ReadOptionalStringArrayParam(root, "recommendationSelections"),
                ReadBoolParam(root, "skipRecommendations") ?? false,
                ReadBoolParam(root, "allowIncompatibleCkanFiles") ?? false,
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));
        }

        private string StartInstallCkanFiles(object? id, JsonElement root)
        {
            var filePaths = ReadStringArrayParam(root, "filePaths");
            if (filePaths.Length == 0)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.StartInstallCkanFiles(new MackanFileInstallRequest(
                ReadStringParam(root, "instanceId"),
                filePaths,
                ReadProviderSelections(root),
                ReadOptionalStringArrayParam(root, "recommendationSelections"),
                ReadBoolParam(root, "skipRecommendations") ?? false,
                ReadBoolParam(root, "allowIncompatibleCkanFiles") ?? false,
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));
        }

        private string ImportDownloads(object? id, JsonElement root)
        {
            var paths = ReadStringArrayParam(root, "paths");
            if (paths.Length == 0)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.ImportDownloads(new MackanDownloadImportRequest(
                ReadStringParam(root, "instanceId"),
                paths,
                ReadBoolParam(root, "installImportedModules") ?? true,
                ReadBoolParam(root, "deleteImportedFiles") ?? false,
                ReadBoolParam(root, "previewBeforeInstall") ?? false,
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));
        }

        private string StartImportDownloads(object? id, JsonElement root)
        {
            var paths = ReadStringArrayParam(root, "paths");
            if (paths.Length == 0)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.StartImportDownloads(new MackanDownloadImportRequest(
                ReadStringParam(root, "instanceId"),
                paths,
                ReadBoolParam(root, "installImportedModules") ?? true,
                ReadBoolParam(root, "deleteImportedFiles") ?? false,
                ReadBoolParam(root, "previewBeforeInstall") ?? false,
                ReadBoolParam(root, "skipDownloadFailures") ?? false)));
        }

        private string OperationStatus(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.GetStatus(operationId));
        }

        private string OperationCancel(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, operationProvider.CancelOperation(operationId));
        }

        private string MaintenanceRemoveRegistryLock(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.RemoveRegistryLock(instanceId));
        }

        private string ExportModList(object? id, JsonElement root)
        {
            var format = ReadStringParam(root, "format");
            if (string.IsNullOrWhiteSpace(format))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, exportProvider.ExportModList(new MackanExportModListRequest(
                ReadStringParam(root, "instanceId"),
                format)));
        }

        private string ExportModpack(object? id, JsonElement root)
        {
            var identifier = ReadStringParam(root, "identifier");
            var name = ReadStringParam(root, "name");
            var version = ReadStringParam(root, "version");
            if (string.IsNullOrWhiteSpace(identifier)
                || string.IsNullOrWhiteSpace(name)
                || string.IsNullOrWhiteSpace(version))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, exportProvider.ExportModpack(new MackanExportModpackRequest(
                ReadStringParam(root, "instanceId"),
                identifier,
                name,
                ReadStringParam(root, "abstract"),
                ReadStringParam(root, "author"),
                version,
                ReadStringParam(root, "license"),
                ReadStringParam(root, "gameVersionMin"),
                ReadStringParam(root, "gameVersionMax"),
                ReadBoolParam(root, "includeVersions") ?? true,
                ReadBoolParam(root, "includeOptionalRelationships") ?? true,
                ReadModpackRelationshipAssignments(root))));
        }

        private string MaintenanceScan(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.ScanGameData(instanceId));
        }

        private string MaintenanceUnmanagedFiles(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.ListUnmanagedFiles(instanceId));
        }

        private string MaintenanceHistory(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.ListInstallationHistory(instanceId));
        }

        private string MaintenanceUpdatePlayTime(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            var hours = ReadDoubleParam(root, "hours");
            if (string.IsNullOrWhiteSpace(instanceId) || hours == null)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.UpdatePlayTime(instanceId, hours.Value));
        }

        private string MaintenanceDownloadStatistics(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.DownloadStatistics(instanceId));
        }

        private string MaintenancePurgeCacheToLimit(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.PurgeCacheToLimit(instanceId));
        }

        private string MaintenanceRepairRegistry(object? id, JsonElement root)
        {
            var instanceId = ReadStringParam(root, "instanceId");
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, maintenanceProvider.RepairRegistry(instanceId));
        }

        private string RepositoryAdd(object? id, JsonElement root)
        {
            var name = ReadStringParam(root, "name");
            var url = ReadStringParam(root, "url");
            if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(url))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, repositoryProvider.AddRepository(
                ReadStringParam(root, "instanceId"),
                name,
                url));
        }

        private string RepositoryRemove(object? id, JsonElement root)
        {
            var name = ReadStringParam(root, "name");
            if (string.IsNullOrWhiteSpace(name))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, repositoryProvider.RemoveRepository(
                ReadStringParam(root, "instanceId"),
                name));
        }

        private string RepositorySetPriority(object? id, JsonElement root)
        {
            var name = ReadStringParam(root, "name");
            var priority = ReadIntParam(root, "priority");
            if (string.IsNullOrWhiteSpace(name) || priority == null)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, repositoryProvider.SetRepositoryPriority(
                ReadStringParam(root, "instanceId"),
                name,
                priority.Value));
        }

        private string RepositoryRefresh(object? id, JsonElement root)
            => Result(id, repositoryProvider.RefreshRepositories(
                ReadStringParam(root, "instanceId"),
                ReadBoolParam(root, "force") ?? false));

        private string ModuleListStatus(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, moduleProvider.GetListStatus(operationId));
        }

        private string ModuleCancelList(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, moduleProvider.CancelList(operationId));
        }

        private string RepositoryStartRefresh(object? id, JsonElement root)
            => Result(id, repositoryProvider.StartRefreshRepositories(
                ReadStringParam(root, "instanceId"),
                ReadBoolParam(root, "force") ?? false));

        private string RepositoryRefreshStatus(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, repositoryProvider.GetRefreshStatus(operationId));
        }

        private string RepositoryCancelRefresh(object? id, JsonElement root)
        {
            var operationId = ReadStringParam(root, "operationId");
            if (string.IsNullOrWhiteSpace(operationId))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, repositoryProvider.CancelRefresh(operationId));
        }

        private string SettingsUpdate(object? id, JsonElement root)
        {
            var cacheSizeLimitBytes = ReadLongParam(root, "cacheSizeLimitBytes");
            if (cacheSizeLimitBytes == null)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, settingsProvider.UpdateSettings(
                ReadStringParam(root, "downloadCacheDir"),
                cacheSizeLimitBytes.Value,
                ReadStringParam(root, "cacheMigrationChoice")));
        }

        private string SettingsUpdateGeneral(object? id, JsonElement root)
        {
            var checkForUpdatesOnLaunch = ReadBoolParam(root, "checkForUpdatesOnLaunch");
            var useDevBuilds = ReadBoolParam(root, "useDevBuilds");
            var refreshRepositoriesOnLaunch = ReadBoolParam(root, "refreshRepositoriesOnLaunch");
            var autoSortByUpdate = ReadBoolParam(root, "autoSortByUpdate");
            if (!checkForUpdatesOnLaunch.HasValue
                || !useDevBuilds.HasValue
                || !refreshRepositoriesOnLaunch.HasValue
                || !autoSortByUpdate.HasValue)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, settingsProvider.UpdateGeneralSettings(
                ReadStringParam(root, "instanceId"),
                checkForUpdatesOnLaunch.Value,
                useDevBuilds.Value,
                refreshRepositoriesOnLaunch.Value,
                autoSortByUpdate.Value));
        }

        private string SettingsUpdateCompatibleVersions(object? id, JsonElement root)
            => Result(id, settingsProvider.UpdateCompatibleGameVersions(
                ReadStringParam(root, "instanceId"),
                ReadStringArrayParam(root, "versions")));

        private string SettingsUpdateStabilityTolerance(object? id, JsonElement root)
        {
            var stabilityTolerance = ReadStringParam(root, "stabilityTolerance");
            if (string.IsNullOrWhiteSpace(stabilityTolerance))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, settingsProvider.UpdateOverallStabilityTolerance(
                ReadStringParam(root, "instanceId"),
                stabilityTolerance));
        }

        private string SettingsUpdateModuleStabilityTolerance(object? id, JsonElement root)
        {
            var identifier = ReadStringParam(root, "identifier");
            if (string.IsNullOrWhiteSpace(identifier))
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, settingsProvider.UpdateModuleStabilityTolerance(
                ReadStringParam(root, "instanceId"),
                identifier,
                ReadStringParam(root, "stabilityTolerance")));
        }

        private string SettingsUpdatePreferredHosts(object? id, JsonElement root)
            => Result(id, settingsProvider.UpdatePreferredHosts(
                ReadStringParam(root, "instanceId"),
                ReadNullableStringArrayParam(root, "preferredHosts")));

        private string SettingsUpdateInstallFilters(object? id, JsonElement root)
            => Result(id, settingsProvider.UpdateInstallFilters(
                ReadStringParam(root, "instanceId"),
                ReadStringArrayParam(root, "globalFilters"),
                ReadStringArrayParam(root, "instanceFilters")));

        private string SettingsUpdateRecommendations(object? id, JsonElement root)
        {
            var suppressRecommendations = ReadBoolParam(root, "suppressRecommendations");
            if (!suppressRecommendations.HasValue)
            {
                return Error(id, -32602, "Invalid params");
            }

            return Result(id, settingsProvider.UpdateRecommendationSettings(
                ReadStringParam(root, "instanceId"),
                suppressRecommendations.Value));
        }

        private string SettingsAddAuthToken(object? id, JsonElement root)
            => Result(id, settingsProvider.AddAuthToken(
                ReadStringParam(root, "host"),
                ReadStringParam(root, "token")));

        private string SettingsRemoveAuthToken(object? id, JsonElement root)
            => Result(id, settingsProvider.RemoveAuthToken(
                ReadStringParam(root, "host")));
    }
}

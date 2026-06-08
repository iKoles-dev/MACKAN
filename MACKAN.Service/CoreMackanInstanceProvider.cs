using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Xml.Linq;

using Autofac;

using CKAN.Configuration;
using CKAN.DLC;
using CKAN.Games;
using CKAN.IO;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanInstanceProvider : IMackanInstanceProvider
    {
        public CoreMackanInstanceProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanInstanceProvider(
            IConfiguration configuration,
            RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanInstancesResult ListInstances()
        {
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);

            return ListInstances(manager);
        }

        public MackanInstancesResult AddInstance(string path, string name)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            var cleanedName = string.IsNullOrWhiteSpace(name)
                ? Path.GetFileName(Path.TrimEndingDirectorySeparator(path.Trim()))
                : name.Trim();
            if (string.IsNullOrWhiteSpace(cleanedName))
            {
                cleanedName = path.Trim();
            }
            cleanedName = manager.GetNextValidInstanceName(cleanedName);

            try
            {
                var instance = manager.AddInstance(path.Trim(), cleanedName, new NullUser())
                    ?? throw new ArgumentException($"No supported game was found at '{path}'.");
                return ListInstancesWithSelection(manager, instance.Name);
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }
        }

        public MackanCloneOptionsResult CloneOptions(string sourceInstanceId)
        {
            if (string.IsNullOrWhiteSpace(sourceInstanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var source = FindInstance(manager, sourceInstanceId);
            return new MackanCloneOptionsResult(
                source.Name,
                source.Game.LeaveEmptyInClones
                      .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                      .ToArray());
        }

        public MackanInstancesResult CloneInstance(
            string sourceInstanceId,
            string newName,
            string newPath,
            bool shareStock,
            IReadOnlyList<string>? leaveEmptyPaths)
        {
            if (string.IsNullOrWhiteSpace(sourceInstanceId)
                || string.IsNullOrWhiteSpace(newName)
                || string.IsNullOrWhiteSpace(newPath))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var source = FindInstance(manager, sourceInstanceId);
            try
            {
                var cloned = manager.CloneInstance(
                    source,
                    newName.Trim(),
                    newPath.Trim(),
                    CleanLeaveEmptyPaths(source, leaveEmptyPaths),
                    shareStock);
                CopyConfiguredLaunchCommandLines(manager, source, cloned);
                return ListInstancesWithSelection(manager, cloned.Name);
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }
            catch (IOException ioException)
            {
                throw new InvalidOperationException(ioException.Message, ioException);
            }
        }

        private static string[] CleanLeaveEmptyPaths(GameInstance source, IReadOnlyList<string>? leaveEmptyPaths)
        {
            if (leaveEmptyPaths == null)
            {
                return source.Game.LeaveEmptyInClones;
            }

            var allowed = source.Game.LeaveEmptyInClones.ToHashSet(StringComparer.OrdinalIgnoreCase);
            return leaveEmptyPaths
                .Select(path => path.Trim())
                .Where(path => !string.IsNullOrWhiteSpace(path))
                .Where(allowed.Contains)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
        }

        public MackanInstancesResult FakeInstance(
            string name,
            string path,
            string version,
            string gameId,
            string? makingHistoryVersion,
            string? breakingGroundVersion,
            bool setDefault)
        {
            if (string.IsNullOrWhiteSpace(name)
                || string.IsNullOrWhiteSpace(path)
                || string.IsNullOrWhiteSpace(version)
                || string.IsNullOrWhiteSpace(gameId))
            {
                throw new ArgumentException("Invalid params");
            }

            var game = KnownGames.knownGames.FirstOrDefault(
                candidate => string.Equals(candidate.ShortName, gameId.Trim(), StringComparison.OrdinalIgnoreCase))
                ?? throw new ArgumentException($"No such game '{gameId}'.");
            var gameVersion = ParseGameVersion(version, game);
            var dlcs = ParseFakeDlcVersions(game, makingHistoryVersion, breakingGroundVersion);
            using var manager = CreateManager();
            try
            {
                var fake = manager.FakeInstance(
                    game,
                    name.Trim(),
                    path.Trim(),
                    gameVersion,
                    dlcs);
                if (setDefault)
                {
                    manager.SetAutoStart(fake.Name);
                }

                return ListInstances(manager);
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }
            catch (IOException ioException)
            {
                throw new InvalidOperationException(ioException.Message, ioException);
            }
        }

        public MackanInstancesResult SetDefaultInstance(string instanceId)
        {
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            try
            {
                manager.SetAutoStart(instanceId);
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }

            return ListInstances(manager);
        }

        public MackanInstancesResult RemoveInstance(string instanceId)
        {
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            if (!manager.HasInstance(instanceId))
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var wasDefault = string.Equals(
                manager.Configuration.AutoStartInstance,
                instanceId,
                StringComparison.OrdinalIgnoreCase);
            manager.RemoveInstance(instanceId);
            if (wasDefault)
            {
                manager.ClearAutoStart();
            }

            return ListInstances(manager);
        }

        public MackanInstancesResult RenameInstance(string instanceId, string newName)
        {
            if (string.IsNullOrWhiteSpace(instanceId) || string.IsNullOrWhiteSpace(newName))
            {
                throw new ArgumentException("Invalid params");
            }

            newName = newName.Trim();
            using var manager = new GameInstanceManager(
                new NullUser(),
                configuration);
            if (!manager.HasInstance(instanceId))
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }
            if (!string.Equals(instanceId, newName, StringComparison.Ordinal)
                && manager.HasInstance(newName))
            {
                throw new ArgumentException($"Instance '{newName}' already exists.");
            }

            var wasDefault = string.Equals(
                manager.Configuration.AutoStartInstance,
                instanceId,
                StringComparison.OrdinalIgnoreCase);
            try
            {
                manager.RenameInstance(instanceId, newName);
                if (wasDefault)
                {
                    manager.SetAutoStart(newName);
                }
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }

            return ListInstances(manager);
        }

        public MackanLaunchOptionsResult LaunchOptions(string instanceId)
        {
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = FindInstance(manager, instanceId);
            var defaultCommandLines = DefaultLaunchCommandLines(manager, instance);
            var configured = ConfiguredLaunchCommandLines(manager, instance);
            return new MackanLaunchOptionsResult(
                instance.Name,
                configured.Length > 0 ? configured : defaultCommandLines,
                defaultCommandLines,
                IncompatibleLaunchModules(instance));
        }

        public MackanLaunchOptionsResult UpdateLaunchOptions(string instanceId, IReadOnlyList<string> commandLines)
        {
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            var cleanedCommandLines = commandLines
                .Select(commandLine => commandLine.Trim())
                .Where(commandLine => !string.IsNullOrWhiteSpace(commandLine))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (cleanedCommandLines.Length == 0)
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = FindInstance(manager, instanceId);
            SaveConfiguredLaunchCommandLines(instance, cleanedCommandLines);
            return new MackanLaunchOptionsResult(
                instance.Name,
                cleanedCommandLines,
                DefaultLaunchCommandLines(manager, instance),
                IncompatibleLaunchModules(instance));
        }

        public MackanLaunchResult LaunchGame(string instanceId, string? commandLine, bool suppressIncompatibleWarnings)
        {
            if (string.IsNullOrWhiteSpace(instanceId))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = FindInstance(manager, instanceId);
            var command = commandLine?.Trim();
            if (string.IsNullOrWhiteSpace(command))
            {
                command = LaunchCommandLines(manager, instance).FirstOrDefault();
            }
            if (string.IsNullOrWhiteSpace(command))
            {
                throw new ArgumentException($"Instance '{instanceId}' has no launch command lines.");
            }
            if (suppressIncompatibleWarnings)
            {
                instance.AddSuppressedCompatWarningIdentifiers(
                    IncompatibleLaunchModules(instance)
                        .Select(module => module.Identifier)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase));
            }

            var previousDirectory = Directory.GetCurrentDirectory();
            int? processId;
            try
            {
                processId = instance.PlayGameWithPid(command);
            }
            finally
            {
                Directory.SetCurrentDirectory(previousDirectory);
            }
            if (processId == null)
            {
                throw new MackanLaunchFailureException(
                    command,
                    $"Failed to launch game with command '{command}'.");
            }

            return new MackanLaunchResult(instance.Name, command, "started", processId);
        }

        private GameInstanceManager CreateManager()
            => new GameInstanceManager(
                new NullUser(),
                configuration);

        private static GameInstance FindInstance(GameInstanceManager manager, string instanceId)
        {
            if (!manager.Instances.TryGetValue(instanceId, out var instance))
            {
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            return instance;
        }

        private static MackanInstancesResult ListInstances(GameInstanceManager manager)
        {
            var instances = manager.Instances.Values.ToArray();
            var defaultId = manager.Configuration.AutoStartInstance;
            if (string.IsNullOrEmpty(defaultId)
                || !manager.Instances.ContainsKey(defaultId))
            {
                defaultId = instances.Length == 1 ? instances[0].Name : null;
            }

            return new MackanInstancesResult(
                defaultId,
                instances.Select(instance => ToSummary(instance, instance.Name == defaultId))
                         .ToArray());
        }

        private static MackanInstancesResult ListInstancesWithSelection(GameInstanceManager manager, string selectedInstanceId)
            => new MackanInstancesResult(
                selectedInstanceId,
                manager.Instances.Values
                       .Select(instance => ToSummary(instance, instance.Name == selectedInstanceId))
                       .ToArray());

        private static MackanInstanceSummary ToSummary(GameInstance instance, bool isDefault)
            => new MackanInstanceSummary(
                instance.Name,
                instance.Name,
                instance.Game.ShortName,
                instance.Version()?.ToString() ?? "",
                instance.GameDir,
                isDefault,
                instance.Valid,
                instance.IsMaybeLocked);

        private static string[] LaunchCommandLines(GameInstanceManager manager, GameInstance instance)
        {
            var configured = ConfiguredLaunchCommandLines(manager, instance);
            return configured.Length > 0
                ? configured
                : DefaultLaunchCommandLines(manager, instance);
        }

        private static string[] DefaultLaunchCommandLines(GameInstanceManager manager, GameInstance instance)
            => instance.Game.DefaultCommandLines(
                manager.SteamLibrary,
                new DirectoryInfo(instance.GameDir));

        private MackanLaunchIncompatibleModule[] IncompatibleLaunchModules(GameInstance instance)
        {
            var registry = RegistryManager.ReadOnlyRegistry(instance, repositoryData);
            if (registry == null)
            {
                return Array.Empty<MackanLaunchIncompatibleModule>();
            }

            var suppressedIdentifiers = instance.GetSuppressedCompatWarningIdentifiers;
            return registry.IncompatibleInstalled(instance.VersionCriteria())
                           .Where(module => !module.Module.IsDLC)
                           .Where(module => !suppressedIdentifiers.Contains(module.identifier))
                           .Select(module => new MackanLaunchIncompatibleModule(
                               module.identifier,
                               module.Module.name,
                               module.Module.version.ToString(),
                               module.Module.CompatibleGameVersions(instance.Game)))
                           .OrderBy(module => module.Name, StringComparer.CurrentCultureIgnoreCase)
                           .ThenBy(module => module.Identifier, StringComparer.OrdinalIgnoreCase)
                           .ToArray();
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;

        private static string[] ConfiguredLaunchCommandLines(GameInstanceManager manager, GameInstance instance)
        {
            var configPath = Path.Combine(instance.CkanDir, "GUIConfig.json");
            if (!File.Exists(configPath))
            {
                return LegacyXmlLaunchCommandLines(
                    instance,
                    DefaultLaunchCommandLines(manager, instance));
            }

            using var document = JsonDocument.Parse(File.ReadAllText(configPath));
            var root = document.RootElement;
            if (root.TryGetProperty("CommandLines", out var commandLinesElement)
                && commandLinesElement.ValueKind == JsonValueKind.Array)
            {
                var commandLines = commandLinesElement.EnumerateArray()
                    .Where(element => element.ValueKind == JsonValueKind.String)
                    .Select(element => element.GetString())
                    .Where(command => !string.IsNullOrWhiteSpace(command))
                    .Select(command => command!.Trim())
                    .ToArray();
                if (commandLines.Length > 0)
                {
                    return commandLines;
                }
            }
            if (root.TryGetProperty("CommandLineArguments", out var legacyElement)
                && legacyElement.ValueKind == JsonValueKind.String
                && !string.IsNullOrWhiteSpace(legacyElement.GetString()))
            {
                return new[] { legacyElement.GetString()!.Trim() };
            }

            return Array.Empty<string>();
        }

        private static string[] LegacyXmlLaunchCommandLines(
            GameInstance instance,
            IReadOnlyList<string> defaultCommandLines)
        {
            var configPath = Path.Combine(instance.CkanDir, "GUIConfig.xml");
            if (!File.Exists(configPath))
            {
                return Array.Empty<string>();
            }

            var document = XDocument.Load(configPath);
            var commandLineArguments = document.Descendants()
                .FirstOrDefault(element => element.Name.LocalName == "CommandLineArguments")
                ?.Value
                .Trim();
            if (!string.IsNullOrWhiteSpace(commandLineArguments))
            {
                return new[] { commandLineArguments }
                    .Concat(defaultCommandLines)
                    .Where(commandLine => !string.IsNullOrWhiteSpace(commandLine))
                    .Distinct(StringComparer.Ordinal)
                    .ToArray();
            }

            var commandLines = document.Descendants()
                .Where(element => element.Name.LocalName == "CommandLine")
                .Select(element => element.Value.Trim())
                .Where(commandLine => !string.IsNullOrWhiteSpace(commandLine))
                .ToArray();
            return commandLines.Length > 0
                ? commandLines
                : defaultCommandLines
                    .Where(commandLine => !string.IsNullOrWhiteSpace(commandLine))
                    .ToArray();
        }

        private static GameVersion ParseGameVersion(string version, IGame game)
        {
            try
            {
                return GameVersion.Parse(version.Trim())
                    .RaiseVersionSelectionDialog(game, new NullUser());
            }
            catch (FormatException formatException)
            {
                throw new ArgumentException("Invalid game version.", formatException);
            }
            catch (Kraken kraken)
            {
                throw new ArgumentException(kraken.Message, kraken);
            }
        }

        private static Dictionary<IDlcDetector, GameVersion> ParseFakeDlcVersions(
            IGame game,
            string? makingHistoryVersion,
            string? breakingGroundVersion)
        {
            var dlcs = new Dictionary<IDlcDetector, GameVersion>();
            AddDlcVersion(dlcs, game, "MakingHistory", makingHistoryVersion);
            AddDlcVersion(dlcs, game, "BreakingGround", breakingGroundVersion);
            return dlcs;
        }

        private static void AddDlcVersion(
            Dictionary<IDlcDetector, GameVersion> dlcs,
            IGame game,
            string identifierBaseName,
            string? version)
        {
            if (string.IsNullOrWhiteSpace(version)
                || string.Equals(version.Trim(), "none", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var detector = game.DlcDetectors.FirstOrDefault(
                candidate => string.Equals(
                    candidate.IdentifierBaseName,
                    identifierBaseName,
                    StringComparison.OrdinalIgnoreCase))
                ?? throw new ArgumentException($"DLC '{identifierBaseName}' is not supported by {game.ShortName}.");
            if (!GameVersion.TryParse(version.Trim(), out var dlcVersion))
            {
                throw new ArgumentException($"Invalid {identifierBaseName} DLC version.");
            }
            dlcs.Add(detector, dlcVersion);
        }

        private static void CopyConfiguredLaunchCommandLines(GameInstanceManager manager, GameInstance source, GameInstance cloned)
        {
            var configured = ConfiguredLaunchCommandLines(manager, source)
                .Where(commandLine => !SteamLibrary.IsSteamCmdLine(commandLine))
                .ToArray();
            if (configured.Length > 0)
            {
                SaveConfiguredLaunchCommandLines(cloned, configured);
            }
        }

        private static void SaveConfiguredLaunchCommandLines(GameInstance instance, IReadOnlyList<string> commandLines)
        {
            Directory.CreateDirectory(instance.CkanDir);
            var configPath = Path.Combine(instance.CkanDir, "GUIConfig.json");
            var configObject = LoadGuiConfigObject(configPath);
            var commandLineArray = new JsonArray();
            foreach (var commandLine in commandLines)
            {
                commandLineArray.Add(commandLine);
            }
            configObject["CommandLines"] = commandLineArray;
            configObject.Remove("CommandLineArguments");

            File.WriteAllText(configPath, configObject.ToJsonString(new JsonSerializerOptions
            {
                WriteIndented = true,
            }));
        }

        private static JsonObject LoadGuiConfigObject(string configPath)
        {
            if (!File.Exists(configPath))
            {
                return new JsonObject();
            }

            try
            {
                return JsonNode.Parse(File.ReadAllText(configPath)) as JsonObject
                    ?? new JsonObject();
            }
            catch (JsonException)
            {
                return new JsonObject();
            }
        }
    }
}

using System.Collections.Generic;

namespace CKAN.MACKAN.Service
{
    public interface IMackanInstanceProvider
    {
        MackanInstancesResult ListInstances();
        MackanInstancesResult AddInstance(string path, string name);
        MackanCloneOptionsResult CloneOptions(string sourceInstanceId);
        MackanInstancesResult CloneInstance(
            string sourceInstanceId,
            string newName,
            string newPath,
            bool shareStock,
            IReadOnlyList<string>? leaveEmptyPaths);
        MackanInstancesResult FakeInstance(
            string name,
            string path,
            string version,
            string gameId,
            string? makingHistoryVersion,
            string? breakingGroundVersion,
            bool setDefault);
        MackanInstancesResult SetDefaultInstance(string instanceId);
        MackanInstancesResult RemoveInstance(string instanceId);
        MackanInstancesResult RenameInstance(string instanceId, string newName);
        MackanLaunchOptionsResult LaunchOptions(string instanceId);
        MackanLaunchOptionsResult UpdateLaunchOptions(string instanceId, IReadOnlyList<string> commandLines);
        MackanLaunchResult LaunchGame(string instanceId, string? commandLine, bool suppressIncompatibleWarnings);
    }

    public sealed class MackanInstancesResult
    {
        public MackanInstancesResult(string? defaultInstanceId, IReadOnlyList<MackanInstanceSummary> instances)
        {
            DefaultInstanceId = string.IsNullOrEmpty(defaultInstanceId) ? null : defaultInstanceId;
            Instances = instances;
        }

        public string? DefaultInstanceId { get; }

        public IReadOnlyList<MackanInstanceSummary> Instances { get; }
    }

    public sealed class MackanCloneOptionsResult
    {
        public MackanCloneOptionsResult(string sourceInstanceId, IReadOnlyList<string> leaveEmptyPaths)
        {
            SourceInstanceId = sourceInstanceId;
            LeaveEmptyPaths = leaveEmptyPaths;
        }

        public string SourceInstanceId { get; }

        public IReadOnlyList<string> LeaveEmptyPaths { get; }
    }

    public sealed class MackanInstanceSummary
    {
        public MackanInstanceSummary(
            string id,
            string name,
            string game,
            string gameVersion,
            string path,
            bool isDefault,
            bool isValid,
            bool isMaybeLocked)
        {
            Id = id;
            Name = name;
            Game = game;
            GameVersion = gameVersion;
            Path = path;
            IsDefault = isDefault;
            IsValid = isValid;
            IsMaybeLocked = isMaybeLocked;
        }

        public string Id { get; }

        public string Name { get; }

        public string Game { get; }

        public string GameVersion { get; }

        public string Path { get; }

        public bool IsDefault { get; }

        public bool IsValid { get; }

        public bool IsMaybeLocked { get; }
    }

    public sealed class MackanLaunchOptionsResult
    {
        public MackanLaunchOptionsResult(
            string instanceId,
            IReadOnlyList<string> commandLines,
            IReadOnlyList<string> defaultCommandLines,
            IReadOnlyList<MackanLaunchIncompatibleModule> incompatibleModules)
        {
            InstanceId = instanceId;
            CommandLines = commandLines;
            DefaultCommandLines = defaultCommandLines;
            IncompatibleModules = incompatibleModules;
        }

        public string InstanceId { get; }

        public IReadOnlyList<string> CommandLines { get; }

        public IReadOnlyList<string> DefaultCommandLines { get; }

        public IReadOnlyList<MackanLaunchIncompatibleModule> IncompatibleModules { get; }
    }

    public sealed class MackanLaunchIncompatibleModule
    {
        public MackanLaunchIncompatibleModule(
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

    public sealed class MackanLaunchResult
    {
        public MackanLaunchResult(string instanceId, string commandLine, string status, int? processId = null)
        {
            InstanceId = instanceId;
            CommandLine = commandLine;
            Status = status;
            ProcessId = processId;
        }

        public string InstanceId { get; }

        public string CommandLine { get; }

        public string Status { get; }

        public int? ProcessId { get; }
    }
}

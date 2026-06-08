using System;

namespace CKAN.MACKAN.Service
{
    public interface IMackanLabelProvider
    {
        MackanLabelsResult ListLabels(string? instanceId);
        MackanLabelsResult ToggleModule(string? instanceId, string labelName, string identifier);
        MackanLabelsResult UpsertLabel(
            string? instanceId,
            string? originalName,
            string? originalInstanceName,
            MackanModuleLabelEdit label);
        MackanLabelsResult DeleteLabel(string? instanceId, string name, string? instanceName);
    }

    public sealed class MackanLabelsResult
    {
        public MackanLabelsResult(
            string? instanceId,
            MackanModuleLabel[] labels,
            MackanModuleLabel[]? manageableLabels = null)
        {
            InstanceId = instanceId;
            Labels = labels;
            ManageableLabels = manageableLabels ?? labels;
        }

        public string? InstanceId { get; }
        public MackanModuleLabel[] Labels { get; }
        public MackanModuleLabel[] ManageableLabels { get; }
    }

    public sealed class MackanModuleLabel
    {
        public MackanModuleLabel(
            string name,
            string? instanceName,
            string? colorHex,
            bool hide,
            bool holdVersion,
            bool ignoreMissingFiles,
            string[]? identifiers = null)
            : this(
                name,
                instanceName,
                colorHex,
                hide,
                false,
                false,
                false,
                false,
                holdVersion,
                ignoreMissingFiles,
                identifiers)
        {
        }

        public MackanModuleLabel(
            string name,
            string? instanceName,
            string? colorHex,
            bool hide,
            bool notifyOnChange,
            bool removeOnChange,
            bool alertOnInstall,
            bool removeOnInstall,
            bool holdVersion,
            bool ignoreMissingFiles,
            string[]? identifiers = null)
        {
            Name = name;
            InstanceName = instanceName;
            ColorHex = colorHex;
            Hide = hide;
            NotifyOnChange = notifyOnChange;
            RemoveOnChange = removeOnChange;
            AlertOnInstall = alertOnInstall;
            RemoveOnInstall = removeOnInstall;
            HoldVersion = holdVersion;
            IgnoreMissingFiles = ignoreMissingFiles;
            Identifiers = identifiers ?? Array.Empty<string>();
        }

        public string Name { get; }
        public string? InstanceName { get; }
        public string? ColorHex { get; }
        public bool Hide { get; }
        public bool NotifyOnChange { get; }
        public bool RemoveOnChange { get; }
        public bool AlertOnInstall { get; }
        public bool RemoveOnInstall { get; }
        public bool HoldVersion { get; }
        public bool IgnoreMissingFiles { get; }
        public string[] Identifiers { get; }
    }

    public sealed class MackanModuleLabelEdit
    {
        public MackanModuleLabelEdit(
            string name,
            string? instanceName,
            string? colorHex,
            bool hide,
            bool notifyOnChange,
            bool removeOnChange,
            bool alertOnInstall,
            bool removeOnInstall,
            bool holdVersion,
            bool ignoreMissingFiles)
        {
            Name = name;
            InstanceName = instanceName;
            ColorHex = colorHex;
            Hide = hide;
            NotifyOnChange = notifyOnChange;
            RemoveOnChange = removeOnChange;
            AlertOnInstall = alertOnInstall;
            RemoveOnInstall = removeOnInstall;
            HoldVersion = holdVersion;
            IgnoreMissingFiles = ignoreMissingFiles;
        }

        public string Name { get; }
        public string? InstanceName { get; }
        public string? ColorHex { get; }
        public bool Hide { get; }
        public bool NotifyOnChange { get; }
        public bool RemoveOnChange { get; }
        public bool AlertOnInstall { get; }
        public bool RemoveOnInstall { get; }
        public bool HoldVersion { get; }
        public bool IgnoreMissingFiles { get; }
    }
}

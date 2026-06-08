using System;
using System.Drawing;
using System.Linq;

using Autofac;

using CKAN.Configuration;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanLabelProvider : IMackanLabelProvider
    {
        public MackanLabelsResult ListLabels(string? instanceId)
        {
            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            return LabelsFor(instance);
        }

        public MackanLabelsResult ToggleModule(string? instanceId, string labelName, string identifier)
        {
            if (string.IsNullOrWhiteSpace(labelName)
                || string.IsNullOrWhiteSpace(identifier))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            var label = ModuleLabelList.ModuleLabels
                                       .LabelsFor(instance.Name)
                                       .FirstOrDefault(candidate =>
                                           string.Equals(candidate.Name, labelName.Trim(), StringComparison.OrdinalIgnoreCase))
                ?? throw new ArgumentException($"Label '{labelName}' was not found.");
            var cleanedIdentifier = identifier.Trim();
            if (label.ContainsModule(instance.Game, cleanedIdentifier))
            {
                label.Remove(instance.Game, cleanedIdentifier);
            }
            else
            {
                label.Add(instance.Game, cleanedIdentifier);
            }
            if (!ModuleLabelList.ModuleLabels.Save(ModuleLabelList.DefaultPath))
            {
                throw new InvalidOperationException($"Could not save labels to '{ModuleLabelList.DefaultPath}'.");
            }
            return LabelsFor(instance);
        }

        public MackanLabelsResult UpsertLabel(
            string? instanceId,
            string? originalName,
            string? originalInstanceName,
            MackanModuleLabelEdit label)
        {
            if (string.IsNullOrWhiteSpace(label.Name))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            var targetInstanceName = NormalizeInstanceName(label.InstanceName);
            if (targetInstanceName != null
                && !manager.Instances.ContainsKey(targetInstanceName))
            {
                throw new ArgumentException($"Instance '{targetInstanceName}' was not found.");
            }

            var cleanedOriginalName = NormalizeInstanceName(originalName);
            var existing = cleanedOriginalName == null
                ? null
                : FindLabel(cleanedOriginalName, NormalizeInstanceName(originalInstanceName));
            if (cleanedOriginalName != null && existing == null)
            {
                throw new ArgumentException($"Label '{cleanedOriginalName}' was not found.");
            }
            var edited = existing ?? new ModuleLabel(label.Name.Trim());
            EnsureUniqueLabel(edited, label.Name.Trim(), targetInstanceName);
            ApplyEdit(edited, label, targetInstanceName);

            if (existing == null)
            {
                ModuleLabelList.ModuleLabels.Labels = ModuleLabelList.ModuleLabels.Labels
                    .Concat(new[] { edited })
                    .OrderBy(candidate => candidate.InstanceName == null)
                    .ThenBy(candidate => candidate.InstanceName, StringComparer.CurrentCultureIgnoreCase)
                    .ThenBy(candidate => candidate.Name, StringComparer.CurrentCultureIgnoreCase)
                    .ToArray();
            }

            SaveLabels();
            return LabelsFor(instance);
        }

        public MackanLabelsResult DeleteLabel(string? instanceId, string name, string? instanceName)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = CreateManager();
            var instance = SelectInstance(manager, instanceId);
            var label = FindLabel(name.Trim(), NormalizeInstanceName(instanceName))
                ?? throw new ArgumentException($"Label '{name}' was not found.");
            ModuleLabelList.ModuleLabels.Labels = ModuleLabelList.ModuleLabels.Labels
                .Where(candidate => candidate != label)
                .ToArray();

            SaveLabels();
            return LabelsFor(instance);
        }

        private static GameInstanceManager CreateManager()
            => new GameInstanceManager(
                new NullUser(),
                ServiceLocator.Container.Resolve<IConfiguration>());

        private static GameInstance SelectInstance(GameInstanceManager manager, string? instanceId)
        {
            if (!string.IsNullOrWhiteSpace(instanceId))
            {
                if (manager.Instances.TryGetValue(instanceId, out var selected))
                {
                    return selected;
                }
                throw new ArgumentException($"Instance '{instanceId}' was not found.");
            }

            var defaultId = manager.Configuration.AutoStartInstance;
            if (!string.IsNullOrWhiteSpace(defaultId)
                && manager.Instances.TryGetValue(defaultId, out var defaultInstance))
            {
                return defaultInstance;
            }

            if (manager.Instances.Count == 1)
            {
                return manager.Instances.Values.First();
            }

            throw new ArgumentException("Invalid params");
        }

        private static MackanLabelsResult LabelsFor(GameInstance instance)
            => new MackanLabelsResult(
                instance.Name,
                ModuleLabelList.ModuleLabels
                               .LabelsFor(instance.Name)
                               .Select(label => ToSummary(instance, label))
                               .OrderBy(label => label.InstanceName == null)
                               .ThenBy(label => label.Name, StringComparer.CurrentCultureIgnoreCase)
                               .ToArray(),
                ModuleLabelList.ModuleLabels
                               .Labels
                               .Select(label => ToSummary(instance, label))
                               .OrderBy(label => label.InstanceName == null)
                               .ThenBy(label => label.InstanceName, StringComparer.CurrentCultureIgnoreCase)
                               .ThenBy(label => label.Name, StringComparer.CurrentCultureIgnoreCase)
                               .ToArray());

        private static MackanModuleLabel ToSummary(GameInstance instance, ModuleLabel label)
            => new MackanModuleLabel(
                label.Name,
                label.InstanceName,
                ColorHex(label.Color),
                label.Hide,
                label.NotifyOnChange,
                label.RemoveOnChange,
                label.AlertOnInstall,
                label.RemoveOnInstall,
                label.HoldVersion,
                label.IgnoreMissingFiles,
                label.IdentifiersFor(instance.Game)
                     .OrderBy(identifier => identifier, StringComparer.OrdinalIgnoreCase)
                     .ToArray());

        private static string? ColorHex(Color? color)
            => color.HasValue
                ? $"#{color.Value.R:X2}{color.Value.G:X2}{color.Value.B:X2}"
                : null;

        private static ModuleLabel? FindLabel(string name, string? instanceName)
            => ModuleLabelList.ModuleLabels.Labels.FirstOrDefault(label =>
                string.Equals(label.Name, name, StringComparison.OrdinalIgnoreCase)
                && string.Equals(label.InstanceName, instanceName, StringComparison.OrdinalIgnoreCase));

        private static void EnsureUniqueLabel(ModuleLabel edited, string name, string? instanceName)
        {
            var duplicate = ModuleLabelList.ModuleLabels.Labels.FirstOrDefault(label =>
                label != edited
                && string.Equals(label.Name, name, StringComparison.OrdinalIgnoreCase)
                && (string.Equals(label.InstanceName, instanceName, StringComparison.OrdinalIgnoreCase)
                    || instanceName == null
                    || label.InstanceName == null));
            if (duplicate != null)
            {
                throw new ArgumentException($"Label '{name}' already exists.");
            }
        }

        private static void ApplyEdit(ModuleLabel destination, MackanModuleLabelEdit source, string? instanceName)
        {
            destination.Name = source.Name.Trim();
            destination.InstanceName = instanceName;
            destination.Color = ParseColor(source.ColorHex);
            destination.Hide = source.Hide;
            destination.NotifyOnChange = source.NotifyOnChange;
            destination.RemoveOnChange = source.RemoveOnChange;
            destination.AlertOnInstall = source.AlertOnInstall;
            destination.RemoveOnInstall = source.RemoveOnInstall;
            destination.HoldVersion = source.HoldVersion;
            destination.IgnoreMissingFiles = source.IgnoreMissingFiles;
        }

        private static string? NormalizeInstanceName(string? instanceName)
            => string.IsNullOrWhiteSpace(instanceName)
                ? null
                : instanceName.Trim();

        private static Color? ParseColor(string? colorHex)
        {
            var trimmed = colorHex?.Trim();
            if (string.IsNullOrWhiteSpace(trimmed))
            {
                return null;
            }

            if (trimmed.Length != 7 || trimmed[0] != '#')
            {
                throw new ArgumentException("Invalid colorHex");
            }

            return ColorTranslator.FromHtml(trimmed);
        }

        private static void SaveLabels()
        {
            if (!ModuleLabelList.ModuleLabels.Save(ModuleLabelList.DefaultPath))
            {
                throw new InvalidOperationException($"Could not save labels to '{ModuleLabelList.DefaultPath}'.");
            }
        }
    }
}

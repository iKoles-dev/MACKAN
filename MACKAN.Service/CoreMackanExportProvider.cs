using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

using Autofac;

using CKAN.Configuration;
using CKAN.Exporters;
using CKAN.Games;
using CKAN.Types;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanExportProvider : IMackanExportProvider
    {
        public CoreMackanExportProvider()
            : this(
                ServiceLocator.Container.Resolve<IConfiguration>(),
                ServiceLocator.Container.Resolve<RepositoryDataManager>())
        {
        }

        public CoreMackanExportProvider(IConfiguration configuration, RepositoryDataManager repositoryData)
        {
            this.configuration = configuration;
            this.repositoryData = repositoryData;
        }

        public MackanExportModListResult ExportModList(MackanExportModListRequest request)
        {
            var export = ExportInfo(request.Format);

            using var manager = new GameInstanceManager(new NullUser(), configuration);

            var instance = SelectInstance(manager, request.InstanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
            }

            using var registryManager = RegistryManager.Instance(instance, repositoryData);
            using var stream = new MemoryStream();
            new Exporter(export.FileType).Export(registryManager, registryManager.registry, stream);

            return new MackanExportModListResult(
                instance.Name,
                export.Format,
                SuggestedFileName(instance.Name, export.Extension),
                export.ContentType,
                Encoding.UTF8.GetString(stream.ToArray()));
        }

        public MackanExportModpackResult ExportModpack(MackanExportModpackRequest request)
        {
            if (!Identifier.ValidIdentifierPattern.IsMatch(request.Identifier)
                || string.IsNullOrWhiteSpace(request.Name)
                || string.IsNullOrWhiteSpace(request.Version))
            {
                throw new ArgumentException("Invalid params");
            }

            using var manager = new GameInstanceManager(new NullUser(), configuration);

            var instance = SelectInstance(manager, request.InstanceId);
            if (instance == null || !instance.Valid)
            {
                throw new ArgumentException($"Instance '{request.InstanceId}' was not found.");
            }

            using var registryManager = RegistryManager.Instance(instance, repositoryData);
            var module = registryManager.GenerateModpack(false, request.IncludeVersions);

            module.identifier = request.Identifier;
            module.name = request.Name;
            module.@abstract = request.Abstract ?? string.Empty;
            module.author = Authors(request.Author);
            module.version = new ModuleVersion(request.Version);
            module.license = new List<License>
            {
                string.IsNullOrWhiteSpace(request.License)
                    ? License.UnknownLicense
                    : new License(request.License),
            };
            module.ksp_version_min = GameVersionOrNull(request.GameVersionMin);
            module.ksp_version_max = GameVersionOrNull(request.GameVersionMax);

            if (module.ksp_version_min != null
                && module.ksp_version_max != null
                && module.ksp_version_min > module.ksp_version_max)
            {
                throw new ArgumentException("Invalid params");
            }

            ApplyRelationshipAssignments(module, request.RelationshipAssignments);

            if (!request.IncludeOptionalRelationships && module.depends != null)
            {
                foreach (var relationship in module.depends)
                {
                    relationship.suppress_recommendations = true;
                }
            }

            EmptyToNull(ref module.depends);
            EmptyToNull(ref module.recommends);
            EmptyToNull(ref module.suggests);
            module.spec_version = SpecVersionAnalyzer.MinimumSpecVersion(module);

            return new MackanExportModpackResult(
                instance.Name,
                module.identifier,
                SuggestedModpackFileName(module.identifier),
                "application/json",
                module.ToJson());
        }

        private static ExportDescriptor ExportInfo(string? format)
            => format switch
            {
                "plainText" or "text" => new ExportDescriptor("plainText", ExportFileType.PlainText, "txt", "text/plain"),
                "markdown" => new ExportDescriptor("markdown", ExportFileType.Markdown, "md", "text/markdown"),
                "bbcode" => new ExportDescriptor("bbcode", ExportFileType.BbCode, "txt", "text/plain"),
                "csv" => new ExportDescriptor("csv", ExportFileType.Csv, "csv", "text/csv"),
                "tsv" => new ExportDescriptor("tsv", ExportFileType.Tsv, "tsv", "text/tab-separated-values"),
                _ => throw new ArgumentException("Invalid params"),
            };

        private static List<string> Authors(string? author)
        {
            var authors = (author ?? string.Empty)
                .Split(',')
                .Select(value => value.Trim())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .ToList();
            return authors.Count > 0 ? authors : new List<string> { Environment.UserName };
        }

        private static GameVersion? GameVersionOrNull(string? version)
            => string.IsNullOrWhiteSpace(version) ? null : GameVersion.Parse(version);

        private static void EmptyToNull<T>(ref List<T>? relationships)
        {
            if (relationships?.Count == 0)
            {
                relationships = null;
            }
        }

        private static void ApplyRelationshipAssignments(
            CkanModule module,
            MackanModpackRelationshipAssignment[] assignments)
        {
            if (assignments.Length == 0)
            {
                return;
            }

            var descriptors = new Dictionary<string, ModuleRelationshipDescriptor>(StringComparer.OrdinalIgnoreCase);
            CaptureRelationshipDescriptors(module.depends, descriptors);
            CaptureRelationshipDescriptors(module.recommends, descriptors);
            CaptureRelationshipDescriptors(module.suggests, descriptors);

            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var assignment in assignments)
            {
                var identifier = assignment.Identifier.Trim();
                var kind = assignment.Kind.Trim().ToLowerInvariant();
                if (string.IsNullOrWhiteSpace(identifier)
                    || !seen.Add(identifier)
                    || (kind is not "depends" and not "recommends" and not "suggests" and not "ignore"))
                {
                    throw new ArgumentException("Invalid params");
                }

                RemoveModuleRelationship(module.depends, identifier);
                RemoveModuleRelationship(module.recommends, identifier);
                RemoveModuleRelationship(module.suggests, identifier);

                if (kind == "ignore")
                {
                    continue;
                }

                var descriptor = descriptors.TryGetValue(identifier, out var existing)
                    ? existing
                    : new ModuleRelationshipDescriptor { name = identifier };
                AddRelationship(module, kind, descriptor);
            }
        }

        private static void CaptureRelationshipDescriptors(
            IEnumerable<RelationshipDescriptor>? source,
            Dictionary<string, ModuleRelationshipDescriptor> descriptors)
        {
            if (source == null)
            {
                return;
            }

            foreach (var relationship in source.OfType<ModuleRelationshipDescriptor>())
            {
                descriptors.TryAdd(relationship.name, relationship);
            }
        }

        private static void RemoveModuleRelationship(List<RelationshipDescriptor>? relationships, string identifier)
            => relationships?.RemoveAll(relationship =>
                relationship is ModuleRelationshipDescriptor descriptor
                && string.Equals(descriptor.name, identifier, StringComparison.OrdinalIgnoreCase));

        private static void AddRelationship(
            CkanModule module,
            string kind,
            ModuleRelationshipDescriptor descriptor)
        {
            switch (kind)
            {
                case "depends":
                    module.depends ??= new List<RelationshipDescriptor>();
                    module.depends.Add(descriptor);
                    break;
                case "recommends":
                    module.recommends ??= new List<RelationshipDescriptor>();
                    module.recommends.Add(descriptor);
                    break;
                case "suggests":
                    module.suggests ??= new List<RelationshipDescriptor>();
                    module.suggests.Add(descriptor);
                    break;
            }
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

        private static string SuggestedFileName(string instanceName, string extension)
            => $"{SanitizedFileNameBase(instanceName)}-mods.{extension}";

        private static string SuggestedModpackFileName(string identifier)
            => $"{SanitizedFileNameBase(identifier)}.ckan";

        private static string SanitizedFileNameBase(string value)
        {
            var invalid = Path.GetInvalidFileNameChars().ToHashSet();
            var safeName = new string(value
                .Select(character => invalid.Contains(character) ? '-' : character)
                .ToArray())
                .Trim();
            if (string.IsNullOrWhiteSpace(safeName))
            {
                safeName = "MACKAN";
            }
            return safeName;
        }

        private readonly IConfiguration configuration;
        private readonly RepositoryDataManager repositoryData;

        private sealed class ExportDescriptor
        {
            public ExportDescriptor(string format, ExportFileType fileType, string extension, string contentType)
            {
                Format = format;
                FileType = fileType;
                Extension = extension;
                ContentType = contentType;
            }

            public string Format { get; }
            public ExportFileType FileType { get; }
            public string Extension { get; }
            public string ContentType { get; }
        }
    }
}

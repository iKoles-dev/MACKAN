using System;

namespace CKAN.MACKAN.Service
{
    public interface IMackanExportProvider
    {
        MackanExportModListResult ExportModList(MackanExportModListRequest request);
        MackanExportModpackResult ExportModpack(MackanExportModpackRequest request);
    }

    public sealed class MackanExportModListRequest
    {
        public MackanExportModListRequest(string? instanceId, string? format)
        {
            InstanceId = instanceId;
            Format = format;
        }

        public string? InstanceId { get; }
        public string? Format { get; }
    }

    public sealed class MackanExportModListResult
    {
        public MackanExportModListResult(
            string? instanceId,
            string format,
            string suggestedFileName,
            string contentType,
            string contents)
        {
            InstanceId = instanceId;
            Format = format;
            SuggestedFileName = suggestedFileName;
            ContentType = contentType;
            Contents = contents;
        }

        public string? InstanceId { get; }
        public string Format { get; }
        public string SuggestedFileName { get; }
        public string ContentType { get; }
        public string Contents { get; }
    }

    public sealed class MackanExportModpackRequest
    {
        public MackanExportModpackRequest(
            string? instanceId,
            string identifier,
            string name,
            string? @abstract,
            string? author,
            string version,
            string? license,
            string? gameVersionMin,
            string? gameVersionMax,
            bool includeVersions,
            bool includeOptionalRelationships,
            MackanModpackRelationshipAssignment[]? relationshipAssignments = null)
        {
            InstanceId = instanceId;
            Identifier = identifier;
            Name = name;
            Abstract = @abstract;
            Author = author;
            Version = version;
            License = license;
            GameVersionMin = gameVersionMin;
            GameVersionMax = gameVersionMax;
            IncludeVersions = includeVersions;
            IncludeOptionalRelationships = includeOptionalRelationships;
            RelationshipAssignments = relationshipAssignments ?? Array.Empty<MackanModpackRelationshipAssignment>();
        }

        public string? InstanceId { get; }
        public string Identifier { get; }
        public string Name { get; }
        public string? Abstract { get; }
        public string? Author { get; }
        public string Version { get; }
        public string? License { get; }
        public string? GameVersionMin { get; }
        public string? GameVersionMax { get; }
        public bool IncludeVersions { get; }
        public bool IncludeOptionalRelationships { get; }
        public MackanModpackRelationshipAssignment[] RelationshipAssignments { get; }
    }

    public sealed class MackanModpackRelationshipAssignment
    {
        public MackanModpackRelationshipAssignment(string identifier, string kind)
        {
            Identifier = identifier;
            Kind = kind;
        }

        public string Identifier { get; }
        public string Kind { get; }
    }

    public sealed class MackanExportModpackResult
    {
        public MackanExportModpackResult(
            string? instanceId,
            string identifier,
            string suggestedFileName,
            string contentType,
            string contents)
        {
            InstanceId = instanceId;
            Identifier = identifier;
            SuggestedFileName = suggestedFileName;
            ContentType = contentType;
            Contents = contents;
        }

        public string? InstanceId { get; }
        public string Identifier { get; }
        public string SuggestedFileName { get; }
        public string ContentType { get; }
        public string Contents { get; }
    }
}

namespace CKAN.MACKAN.Service
{
    public interface IMackanMaintenanceProvider
    {
        MackanMaintenanceScanResult ScanGameData(string? instanceId);
        MackanUnmanagedFilesResult ListUnmanagedFiles(string? instanceId);
        MackanInstallationHistoryResult ListInstallationHistory(string? instanceId);
        MackanInstallationHistoryEntry LoadInstallationHistoryEntry(string? instanceId, string fileName);
        MackanPlayTimeResult ListPlayTime();
        MackanPlayTimeResult UpdatePlayTime(string instanceId, double hours);
        MackanDownloadStatisticsResult DownloadStatistics(string? instanceId);
        MackanCacheInfoResult CacheInfo();
        MackanCachePurgeResult ClearCache();
        MackanCachePurgeResult PurgeCacheToLimit(string? instanceId);
        MackanDeduplicateResult Deduplicate();
        MackanRepairRegistryResult RepairRegistry(string? instanceId);
        MackanRegistryLockRemovalResult RemoveRegistryLock(string? instanceId);
    }

    public sealed class MackanMaintenanceScanResult
    {
        public MackanMaintenanceScanResult(
            string? instanceId,
            bool changed,
            int detectedDllCount,
            int detectedDlcCount)
        {
            InstanceId = instanceId;
            Changed = changed;
            DetectedDllCount = detectedDllCount;
            DetectedDlcCount = detectedDlcCount;
        }

        public string? InstanceId { get; }
        public bool Changed { get; }
        public int DetectedDllCount { get; }
        public int DetectedDlcCount { get; }
    }

    public sealed class MackanUnmanagedFilesResult
    {
        public MackanUnmanagedFilesResult(
            string? instanceId,
            bool changed,
            MackanUnmanagedFileSummary[] files)
        {
            InstanceId = instanceId;
            Changed = changed;
            Files = files;
        }

        public string? InstanceId { get; }
        public bool Changed { get; }
        public MackanUnmanagedFileSummary[] Files { get; }
    }

    public sealed class MackanRegistryLockRemovalResult
    {
        public MackanRegistryLockRemovalResult(
            string? instanceId,
            string lockfilePath,
            string status,
            bool removed)
        {
            InstanceId = instanceId;
            LockfilePath = lockfilePath;
            Status = status;
            Removed = removed;
        }

        public string? InstanceId { get; }
        public string LockfilePath { get; }
        public string Status { get; }
        public bool Removed { get; }
    }

    public sealed class MackanUnmanagedFileSummary
    {
        public MackanUnmanagedFileSummary(
            string identifier,
            string kind,
            string? version,
            string? path)
        {
            Identifier = identifier;
            Kind = kind;
            Version = version;
            Path = path;
        }

        public string Identifier { get; }
        public string Kind { get; }
        public string? Version { get; }
        public string? Path { get; }
    }

    public sealed class MackanInstallationHistoryResult
    {
        public MackanInstallationHistoryResult(
            string? instanceId,
            MackanInstallationHistoryEntrySummary[] entries)
        {
            InstanceId = instanceId;
            Entries = entries;
        }

        public string? InstanceId { get; }
        public MackanInstallationHistoryEntrySummary[] Entries { get; }
    }

    public sealed class MackanInstallationHistoryEntrySummary
    {
        public MackanInstallationHistoryEntrySummary(
            string fileName,
            string savedAt,
            int moduleCount)
        {
            FileName = fileName;
            SavedAt = savedAt;
            ModuleCount = moduleCount;
        }

        public string FileName { get; }
        public string SavedAt { get; }
        public int ModuleCount { get; }
    }

    public sealed class MackanInstallationHistoryEntry
    {
        public MackanInstallationHistoryEntry(
            string fileName,
            string savedAt,
            MackanInstallationHistoryModule[] modules)
        {
            FileName = fileName;
            SavedAt = savedAt;
            Modules = modules;
        }

        public string FileName { get; }
        public string SavedAt { get; }
        public MackanInstallationHistoryModule[] Modules { get; }
    }

    public sealed class MackanInstallationHistoryModule
    {
        public MackanInstallationHistoryModule(
            string identifier,
            string name,
            string? version,
            string? author,
            string? @abstract,
            bool isInstalled,
            bool isAvailable)
        {
            Identifier = identifier;
            Name = name;
            Version = version;
            Author = author;
            Abstract = @abstract;
            IsInstalled = isInstalled;
            IsAvailable = isAvailable;
        }

        public string Identifier { get; }
        public string Name { get; }
        public string? Version { get; }
        public string? Author { get; }
        public string? Abstract { get; }
        public bool IsInstalled { get; }
        public bool IsAvailable { get; }
    }

    public sealed class MackanPlayTimeResult
    {
        public MackanPlayTimeResult(
            MackanPlayTimeEntry[] entries,
            double totalHours,
            string totalDisplay)
        {
            Entries = entries;
            TotalHours = totalHours;
            TotalDisplay = totalDisplay;
        }

        public MackanPlayTimeEntry[] Entries { get; }
        public double TotalHours { get; }
        public string TotalDisplay { get; }
    }

    public sealed class MackanPlayTimeEntry
    {
        public MackanPlayTimeEntry(
            string instanceId,
            string name,
            string path,
            double hours,
            string display)
        {
            InstanceId = instanceId;
            Name = name;
            Path = path;
            Hours = hours;
            Display = display;
        }

        public string InstanceId { get; }
        public string Name { get; }
        public string Path { get; }
        public double Hours { get; }
        public string Display { get; }
    }

    public sealed class MackanDownloadStatisticsResult
    {
        public MackanDownloadStatisticsResult(
            string? instanceId,
            MackanDownloadStatisticsHost[] hosts,
            long totalBytes,
            string totalDisplay)
        {
            InstanceId = instanceId;
            Hosts = hosts;
            TotalBytes = totalBytes;
            TotalDisplay = totalDisplay;
        }

        public string? InstanceId { get; }
        public MackanDownloadStatisticsHost[] Hosts { get; }
        public long TotalBytes { get; }
        public string TotalDisplay { get; }
    }

    public sealed class MackanDownloadStatisticsHost
    {
        public MackanDownloadStatisticsHost(string host, long bytes, string display)
        {
            Host = host;
            Bytes = bytes;
            Display = display;
        }

        public string Host { get; }
        public long Bytes { get; }
        public string Display { get; }
    }

    public sealed class MackanCacheInfoResult
    {
        public MackanCacheInfoResult(
            string path,
            int fileCount,
            long bytes,
            string display,
            long? freeBytes,
            string? freeDisplay,
            long? limitBytes,
            string? limitDisplay,
            bool isOverLimit)
        {
            Path = path;
            FileCount = fileCount;
            Bytes = bytes;
            Display = display;
            FreeBytes = freeBytes;
            FreeDisplay = freeDisplay;
            LimitBytes = limitBytes;
            LimitDisplay = limitDisplay;
            IsOverLimit = isOverLimit;
        }

        public string Path { get; }
        public int FileCount { get; }
        public long Bytes { get; }
        public string Display { get; }
        public long? FreeBytes { get; }
        public string? FreeDisplay { get; }
        public long? LimitBytes { get; }
        public string? LimitDisplay { get; }
        public bool IsOverLimit { get; }
    }

    public sealed class MackanCachePurgeResult
    {
        public MackanCachePurgeResult(
            string mode,
            int purgedFileCount,
            long purgedBytes,
            string purgedDisplay,
            MackanCacheInfoResult cache)
        {
            Mode = mode;
            PurgedFileCount = purgedFileCount;
            PurgedBytes = purgedBytes;
            PurgedDisplay = purgedDisplay;
            Cache = cache;
        }

        public string Mode { get; }
        public int PurgedFileCount { get; }
        public long PurgedBytes { get; }
        public string PurgedDisplay { get; }
        public MackanCacheInfoResult Cache { get; }
    }

    public sealed class MackanDeduplicateResult
    {
        public MackanDeduplicateResult(
            string status,
            MackanOperationEvent[] events,
            string? error)
        {
            Status = status;
            Events = events;
            Error = error;
        }

        public string Status { get; }
        public MackanOperationEvent[] Events { get; }
        public string? Error { get; }
    }

    public sealed class MackanRepairRegistryResult
    {
        public MackanRepairRegistryResult(
            string? instanceId,
            string status,
            MackanOperationEvent[] events,
            string? error)
        {
            InstanceId = instanceId;
            Status = status;
            Events = events;
            Error = error;
        }

        public string? InstanceId { get; }
        public string Status { get; }
        public MackanOperationEvent[] Events { get; }
        public string? Error { get; }
    }
}

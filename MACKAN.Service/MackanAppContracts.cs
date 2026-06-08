using System;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.InteropServices;

namespace CKAN.MACKAN.Service
{
    public interface IMackanUpdateProvider
    {
        MackanUpdateCheckResult CheckForUpdates(bool? useDevBuilds);
    }

    public sealed class MackanVersionResult
    {
        public MackanVersionResult(
            string appName,
            string serviceVersion,
            string ckanVersion,
            string protocolVersion,
            string dotnetVersion,
            string operatingSystem,
            string processArchitecture)
        {
            AppName = appName;
            ServiceVersion = serviceVersion;
            CkanVersion = ckanVersion;
            ProtocolVersion = protocolVersion;
            DotnetVersion = dotnetVersion;
            OperatingSystem = operatingSystem;
            ProcessArchitecture = processArchitecture;
        }

        public string AppName { get; }
        public string ServiceVersion { get; }
        public string CkanVersion { get; }
        public string ProtocolVersion { get; }
        public string DotnetVersion { get; }
        public string OperatingSystem { get; }
        public string ProcessArchitecture { get; }

        public static MackanVersionResult Current(string ckanVersion)
            => new MackanVersionResult(
                "MACKAN",
                AssemblyVersion(),
                ckanVersion,
                MackanServiceDispatcher.ProtocolVersion,
                RuntimeInformation.FrameworkDescription,
                RuntimeInformation.OSDescription,
                RuntimeInformation.ProcessArchitecture.ToString());

        private static string AssemblyVersion()
            => typeof(MackanVersionResult)
                .Assembly
                .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
                ?.InformationalVersion
               ?? typeof(MackanVersionResult).Assembly.GetName().Version?.ToString()
               ?? "unknown";
    }

    public sealed class MackanUpdateCheckResult
    {
        public MackanUpdateCheckResult(
            string status,
            string currentVersion,
            string? latestVersion,
            string? latestDisplayVersion,
            string? releaseNotes,
            string source,
            bool useDevBuilds,
            bool canAutoInstall,
            string installMessage,
            IReadOnlyList<string> downloadUrls,
            string? error)
        {
            Status = status;
            CurrentVersion = currentVersion;
            LatestVersion = latestVersion;
            LatestDisplayVersion = latestDisplayVersion;
            ReleaseNotes = releaseNotes;
            Source = source;
            UseDevBuilds = useDevBuilds;
            CanAutoInstall = canAutoInstall;
            InstallMessage = installMessage;
            DownloadUrls = downloadUrls;
            Error = error;
        }

        public string Status { get; }
        public string CurrentVersion { get; }
        public string? LatestVersion { get; }
        public string? LatestDisplayVersion { get; }
        public string? ReleaseNotes { get; }
        public string Source { get; }
        public bool UseDevBuilds { get; }
        public bool CanAutoInstall { get; }
        public string InstallMessage { get; }
        public IReadOnlyList<string> DownloadUrls { get; }
        public string? Error { get; }
    }
}

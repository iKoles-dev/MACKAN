using System;
using System.Collections.Generic;
using System.Linq;

using Autofac;

using CKAN.Configuration;
using CKAN.Versioning;

namespace CKAN.MACKAN.Service
{
    public sealed class CoreMackanUpdateProvider : IMackanUpdateProvider
    {
        public CoreMackanUpdateProvider(
            AutoUpdate? updater = null,
            Func<bool?>? devBuildsProvider = null,
            Func<bool, CkanUpdate>? updateProvider = null,
            Func<ModuleVersion>? currentVersionProvider = null)
        {
            this.updater = updater ?? new AutoUpdate();
            this.devBuildsProvider = devBuildsProvider
                ?? (() => ServiceLocator.Container.Resolve<IConfiguration>().DevBuilds);
            this.updateProvider = updateProvider
                ?? (devBuilds => this.updater.GetUpdate(devBuilds, Net.UserAgentString));
            this.currentVersionProvider = currentVersionProvider
                ?? (() => Meta.ReleaseVersion);
        }

        public MackanUpdateCheckResult CheckForUpdates(bool? useDevBuilds)
        {
            var devBuilds = useDevBuilds ?? devBuildsProvider() ?? false;
            var source = devBuilds ? "dev" : "stable";
            var currentVersion = currentVersionProvider();
            var currentVersionString = currentVersion.ToString();

            try
            {
                var update = updateProvider(devBuilds);
                if (update.Version is not CkanModuleVersion latestVersion)
                {
                    return Failure(
                        currentVersionString,
                        source,
                        devBuilds,
                        "Update metadata did not include a CKAN client version.");
                }

                var downloadUrls = NativeInstallUrls(update.Targets, latestVersion, devBuilds);
                var updateAvailable = !latestVersion.SameClientVersion(currentVersion)
                    && latestVersion.CompareTo(currentVersion) > 0;

                return new MackanUpdateCheckResult(
                    updateAvailable ? "available" : "current",
                    currentVersionString,
                    latestVersion.ToString(false, false),
                    latestVersion.ToString(),
                    update.ReleaseNotes,
                    source,
                    devBuilds,
                    false,
                    InstallMessage,
                    downloadUrls,
                    null);
            }
            catch (Exception exception)
            {
                return Failure(currentVersionString, source, devBuilds, exception.Message);
            }
        }

        private static MackanUpdateCheckResult Failure(
            string currentVersion,
            string source,
            bool useDevBuilds,
            string error)
            => new MackanUpdateCheckResult(
                "failed",
                currentVersion,
                null,
                null,
                null,
                source,
                useDevBuilds,
                false,
                InstallMessage,
                Array.Empty<string>(),
                error);

        private static IReadOnlyList<string> NativeInstallUrls(
            IReadOnlyCollection<NetAsyncDownloader.DownloadTarget> targets,
            CkanModuleVersion latestVersion,
            bool devBuilds)
        {
            var macInstallUrls = targets
                .SelectMany(target => target.urls)
                .Select(url => url.ToString())
                .Where(IsMacInstallUrl)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (macInstallUrls.Length > 0)
            {
                return macInstallUrls;
            }

            return devBuilds
                ? Array.Empty<string>()
                : new[] { $"https://github.com/KSP-CKAN/CKAN/releases/tag/{latestVersion.ToString(false, false)}" };
        }

        private static bool IsMacInstallUrl(string url)
            => Uri.TryCreate(url, UriKind.Absolute, out var parsedUrl)
               && parsedUrl.AbsolutePath.EndsWith(".dmg", StringComparison.OrdinalIgnoreCase);

        private const string InstallMessage =
            "MACKAN can check for updates, but signed in-app installation is not enabled yet. Install the signed MACKAN DMG from the release page.";

        private readonly AutoUpdate updater;
        private readonly Func<bool, CkanUpdate> updateProvider;
        private readonly Func<ModuleVersion> currentVersionProvider;
        private readonly Func<bool?> devBuildsProvider;
    }
}

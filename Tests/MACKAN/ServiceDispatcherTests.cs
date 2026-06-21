#if NET10_0_OR_GREATER

using System.Text.Json;
using System.Collections.Generic;
using System;
using System.Linq;

using CKAN;
using CKAN.MACKAN.Service;
using CKAN.Versioning;

using NUnit.Framework;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class ServiceDispatcherTests
    {
        [Test]
        public void HealthRequestReturnsProtocolAndVersion()
        {
            var dispatcher = new MackanServiceDispatcher(() => "1.2.3-test");

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"app.health\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(7));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("ok"));
            Assert.That(result.GetProperty("protocolVersion").GetString(), Is.EqualTo("1"));
            Assert.That(result.GetProperty("ckanVersion").GetString(), Is.EqualTo("1.2.3-test"));
        }

        [Test]
        public void VersionRequestReturnsServiceAndRuntimeMetadata()
        {
            var dispatcher = new MackanServiceDispatcher(() => "1.2.3-test");

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"app.version\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(8));
            Assert.That(result.GetProperty("appName").GetString(), Is.EqualTo("MACKAN"));
            Assert.That(result.GetProperty("protocolVersion").GetString(), Is.EqualTo("1"));
            Assert.That(result.GetProperty("ckanVersion").GetString(), Is.EqualTo("1.2.3-test"));
            Assert.That(result.GetProperty("serviceVersion").GetString(), Is.Not.Empty);
            Assert.That(result.GetProperty("dotnetVersion").GetString(), Is.Not.Empty);
            Assert.That(result.GetProperty("operatingSystem").GetString(), Is.Not.Empty);
            Assert.That(result.GetProperty("processArchitecture").GetString(), Is.Not.Empty);
        }

        [Test]
        public void CheckForUpdatesReturnsNativeUpdateStatus()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "v1.0.0-test",
                updateProvider: new FakeUpdateProvider(new MackanUpdateCheckResult(
                    "available",
                    "v1.0.0-test",
                    "v1.1.0",
                    "v1.1.0 aka Mun",
                    "Stable release notes",
                    "stable",
                    false,
                    false,
                    "Install the signed MACKAN DMG from the release page.",
                    new[] { "https://github.com/KSP-CKAN/CKAN/releases/download/v1.1.0/MACKAN.dmg" },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"app.checkForUpdates\",\"params\":{\"useDevBuilds\":false}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(9));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("available"));
            Assert.That(result.GetProperty("currentVersion").GetString(), Is.EqualTo("v1.0.0-test"));
            Assert.That(result.GetProperty("latestVersion").GetString(), Is.EqualTo("v1.1.0"));
            Assert.That(result.GetProperty("latestDisplayVersion").GetString(), Is.EqualTo("v1.1.0 aka Mun"));
            Assert.That(result.GetProperty("releaseNotes").GetString(), Is.EqualTo("Stable release notes"));
            Assert.That(result.GetProperty("source").GetString(), Is.EqualTo("stable"));
            Assert.That(result.GetProperty("useDevBuilds").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("canAutoInstall").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("installMessage").GetString(), Does.Contain("signed MACKAN DMG"));
            Assert.That(result.GetProperty("downloadUrls")[0].GetString(), Does.EndWith("MACKAN.dmg"));
            Assert.That(result.GetProperty("error").ValueKind, Is.EqualTo(JsonValueKind.Null));
        }

        [Test]
        public void CoreUpdateProviderDoesNotOfferOlderStableReleaseAsAvailable()
        {
            var provider = new CoreMackanUpdateProvider(
                updateProvider: _ => new FakeCkanUpdate(new CkanModuleVersion("v1.36.4", "v1.36.4")),
                devBuildsProvider: () => false,
                currentVersionProvider: () => new ModuleVersion("v1.36.5.26146"));

            var result = provider.CheckForUpdates(false);

            Assert.That(result.Status, Is.EqualTo("current"));
            Assert.That(result.CurrentVersion, Is.EqualTo("v1.36.5.26146"));
            Assert.That(result.LatestVersion, Is.EqualTo("v1.36.4"));
            Assert.That(result.LatestDisplayVersion, Is.EqualTo("v1.36.4 aka v1.36.4"));
            Assert.That(result.Error, Is.Null);
        }

        [Test]
        public void CoreUpdateProviderReturnsNativeInstallUrlInsteadOfWindowsUpdaterTargets()
        {
            var provider = new CoreMackanUpdateProvider(
                updateProvider: _ => new FakeCkanUpdate(
                    new CkanModuleVersion("v1.36.4", "v1.36.4"),
                    "https://github.com/KSP-CKAN/CKAN/releases/download/v1.36.4/AutoUpdater.exe",
                    "https://github.com/KSP-CKAN/CKAN/releases/download/v1.36.4/ckan.exe"),
                devBuildsProvider: () => false,
                currentVersionProvider: () => new ModuleVersion("v1.36.3"));

            var result = provider.CheckForUpdates(false);

            Assert.That(result.Status, Is.EqualTo("available"));
            Assert.That(result.DownloadUrls, Is.EqualTo(new[]
            {
                "https://github.com/KSP-CKAN/CKAN/releases/tag/v1.36.4",
            }));
        }

        [Test]
        public void UnknownMethodReturnsMethodNotFoundError()
        {
            var dispatcher = new MackanServiceDispatcher(() => "1.2.3-test");

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"method\":\"missing.method\"}"));
            var root = document.RootElement;
            var error = root.GetProperty("error");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetString(), Is.EqualTo("abc"));
            Assert.That(error.GetProperty("code").GetInt32(), Is.EqualTo(-32601));
            Assert.That(error.GetProperty("message").GetString(), Is.EqualTo("Method not found"));
        }

        [Test]
        public void RegistryLockKrakenReturnsTypedJsonRpcError()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                changeSetProvider: new ThrowingChangeSetProvider(
                    new RegistryInUseKraken("/Games/KSP/CKAN/registry.locked")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":58,\"method\":\"mods.resolveChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"]}}"));
            var root = document.RootElement;
            var error = root.GetProperty("error");
            var data = error.GetProperty("data");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(58));
            Assert.That(error.GetProperty("code").GetInt32(), Is.EqualTo(-32010));
            Assert.That(error.GetProperty("message").GetString(), Does.Contain("registry.locked"));
            Assert.That(data.GetProperty("kind").GetString(), Is.EqualTo("registryLock"));
            Assert.That(data.GetProperty("lockfilePath").GetString(), Is.EqualTo("/Games/KSP/CKAN/registry.locked"));
            Assert.That(data.GetProperty("suggestedAction").GetString(), Is.EqualTo("waitRetry"));
        }

        [Test]
        public void SettingsGetReturnsCacheSettings()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(new MackanSettingsResult(
                    "/Users/test/Library/Caches/CKAN/downloads",
                    "/Users/test/Library/Caches/CKAN/downloads",
                    true,
                    1073741824,
                    "1 GiB")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":41,\"method\":\"settings.get\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(41));
            Assert.That(result.GetProperty("downloadCacheDir").GetString(), Is.EqualTo("/Users/test/Library/Caches/CKAN/downloads"));
            Assert.That(result.GetProperty("defaultDownloadCacheDir").GetString(), Is.EqualTo("/Users/test/Library/Caches/CKAN/downloads"));
            Assert.That(result.GetProperty("isDefaultDownloadCacheDir").GetBoolean(), Is.True);
            Assert.That(result.GetProperty("cacheSizeLimitBytes").GetInt64(), Is.EqualTo(1073741824));
            Assert.That(result.GetProperty("cacheSizeLimitDisplay").GetString(), Is.EqualTo("1 GiB"));
        }

        [Test]
        public void SettingsUpdateAcceptsCacheSettings()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(new MackanSettingsResult(
                    "/Users/test/CKANCache",
                    "/Users/test/Library/Caches/CKAN/downloads",
                    false,
                    null,
                    "Unlimited")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":42,\"method\":\"settings.update\",\"params\":{\"downloadCacheDir\":\"/Users/test/CKANCache\",\"cacheSizeLimitBytes\":-1,\"cacheMigrationChoice\":\"delete\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(42));
            Assert.That(result.GetProperty("downloadCacheDir").GetString(), Is.EqualTo("/Users/test/CKANCache"));
            Assert.That(result.GetProperty("isDefaultDownloadCacheDir").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("cacheSizeLimitBytes").ValueKind, Is.EqualTo(JsonValueKind.Null));
            Assert.That(result.GetProperty("cacheSizeLimitDisplay").GetString(), Is.EqualTo("Unlimited"));
        }

        [Test]
        public void SettingsGeneralReturnsUpdatePreferences()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":43,\"method\":\"settings.general\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(43));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("checkForUpdatesOnLaunch").GetBoolean(), Is.True);
            Assert.That(result.GetProperty("useDevBuilds").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("refreshRepositoriesOnLaunch").GetBoolean(), Is.True);
            Assert.That(result.GetProperty("autoSortByUpdate").GetBoolean(), Is.True);
        }

        [Test]
        public void SettingsUpdateGeneralAcceptsUpdatePreferences()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":44,\"method\":\"settings.updateGeneral\",\"params\":{\"instanceId\":\"primary\",\"checkForUpdatesOnLaunch\":false,\"useDevBuilds\":true,\"refreshRepositoriesOnLaunch\":false,\"autoSortByUpdate\":false}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(44));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("checkForUpdatesOnLaunch").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("useDevBuilds").GetBoolean(), Is.True);
            Assert.That(result.GetProperty("refreshRepositoriesOnLaunch").GetBoolean(), Is.False);
            Assert.That(result.GetProperty("autoSortByUpdate").GetBoolean(), Is.False);
        }

        [Test]
        public void SettingsCompatibleVersionsReturnsPerInstanceVersions()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    new MackanCompatibleGameVersionsResult(
                        "primary",
                        "KSP",
                        "1.12.5",
                        "1.12.4",
                        true,
                        new[] { "1.12.5", "1.12.4" },
                        new[] { "1.12.5", "1.12.4", "1.11.2" },
                        new[] { "1.12.5", "1.12.4", "1.11.2" })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":43,\"method\":\"settings.compatibleVersions\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(43));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("game").GetString(), Is.EqualTo("KSP"));
            Assert.That(result.GetProperty("actualGameVersion").GetString(), Is.EqualTo("1.12.5"));
            Assert.That(result.GetProperty("gameVersionWhenWritten").GetString(), Is.EqualTo("1.12.4"));
            Assert.That(result.GetProperty("compatibleVersionsAreFromDifferentGameVersion").GetBoolean(), Is.True);
            Assert.That(ReadStrings(result.GetProperty("compatibleVersions")), Is.EqualTo(new[] { "1.12.5", "1.12.4" }));
            Assert.That(ReadStrings(result.GetProperty("knownVersions")), Is.EqualTo(new[] { "1.12.5", "1.12.4", "1.11.2" }));
            Assert.That(ReadStrings(result.GetProperty("availableVersions")), Is.EqualTo(new[] { "1.12.5", "1.12.4", "1.11.2" }));
        }

        [Test]
        public void SettingsUpdateCompatibleVersionsAcceptsVersions()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    new MackanCompatibleGameVersionsResult(
                        "primary",
                        "KSP",
                        "1.12.5",
                        "1.12.5",
                        false,
                        new[] { "1.12.5", "1.11" },
                        new[] { "1.12.5", "1.12.4", "1.11.2" },
                        new[] { "1.12.5", "1.12.4", "1.11.2", "1.11" })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":44,\"method\":\"settings.updateCompatibleVersions\",\"params\":{\"instanceId\":\"primary\",\"versions\":[\"1.12.5\",\"1.11\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(44));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(ReadStrings(result.GetProperty("compatibleVersions")), Is.EqualTo(new[] { "1.12.5", "1.11" }));
            Assert.That(result.GetProperty("compatibleVersionsAreFromDifferentGameVersion").GetBoolean(), Is.False);
        }

        [Test]
        public void SettingsStabilityToleranceReturnsOverallAndModuleOverrides()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    stabilityToleranceResult: new MackanStabilityToleranceResult(
                        "primary",
                        "KSP",
                        "testing",
                        new[] { "stable", "testing", "development" },
                        new[]
                        {
                            new MackanModuleStabilityTolerance("ModuleManager", "stable"),
                            new MackanModuleStabilityTolerance("UnstableAddon", "development"),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":45,\"method\":\"settings.stabilityTolerance\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var overrides = result.GetProperty("moduleStabilityTolerances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(45));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("game").GetString(), Is.EqualTo("KSP"));
            Assert.That(result.GetProperty("overallStabilityTolerance").GetString(), Is.EqualTo("testing"));
            Assert.That(ReadStrings(result.GetProperty("availableStabilityTolerances")), Is.EqualTo(new[] { "stable", "testing", "development" }));
            Assert.That(overrides.GetArrayLength(), Is.EqualTo(2));
            Assert.That(overrides[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(overrides[0].GetProperty("stabilityTolerance").GetString(), Is.EqualTo("stable"));
            Assert.That(overrides[1].GetProperty("identifier").GetString(), Is.EqualTo("UnstableAddon"));
            Assert.That(overrides[1].GetProperty("stabilityTolerance").GetString(), Is.EqualTo("development"));
        }

        [Test]
        public void SettingsUpdateStabilityToleranceAcceptsOverallTolerance()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    stabilityToleranceResult: new MackanStabilityToleranceResult(
                        "primary",
                        "KSP",
                        "development",
                        new[] { "stable", "testing", "development" },
                        Array.Empty<MackanModuleStabilityTolerance>())));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":46,\"method\":\"settings.updateStabilityTolerance\",\"params\":{\"instanceId\":\"primary\",\"stabilityTolerance\":\"development\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(46));
            Assert.That(result.GetProperty("overallStabilityTolerance").GetString(), Is.EqualTo("development"));
        }

        [Test]
        public void SettingsUpdateModuleStabilityToleranceAcceptsOverrideAndClear()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    stabilityToleranceResult: new MackanStabilityToleranceResult(
                        "primary",
                        "KSP",
                        "testing",
                        new[] { "stable", "testing", "development" },
                        new[]
                        {
                            new MackanModuleStabilityTolerance("ModuleManager", "testing"),
                        })));

            using var updateDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":47,\"method\":\"settings.updateModuleStabilityTolerance\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"ModuleManager\",\"stabilityTolerance\":\"testing\"}}"));
            using var clearDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":48,\"method\":\"settings.updateModuleStabilityTolerance\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"ModuleManager\"}}"));

            Assert.That(updateDocument.RootElement.GetProperty("result").GetProperty("moduleStabilityTolerances")[0].GetProperty("stabilityTolerance").GetString(), Is.EqualTo("testing"));
            Assert.That(clearDocument.RootElement.GetProperty("result").GetProperty("overallStabilityTolerance").GetString(), Is.EqualTo("testing"));
        }

        [Test]
        public void SettingsPreferredHostsReturnsAvailableHostsAndConfiguredPriority()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    preferredHostsResult: new MackanPreferredHostsResult(
                        "primary",
                        new[] { "github.com", "spacedock.info", "archive.org" },
                        new[] { "github.com", null, "spacedock.info" },
                        "<ALL OTHER HOSTS>")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":49,\"method\":\"settings.preferredHosts\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(49));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(ReadStrings(result.GetProperty("availableHosts")), Is.EqualTo(new[] { "github.com", "spacedock.info", "archive.org" }));
            Assert.That(ReadNullableStrings(result.GetProperty("preferredHosts")), Is.EqualTo(new[] { "github.com", null, "spacedock.info" }));
            Assert.That(result.GetProperty("placeholderLabel").GetString(), Is.EqualTo("<ALL OTHER HOSTS>"));
        }

        [Test]
        public void SettingsUpdatePreferredHostsAcceptsOrderedHostsAndAllOtherMarker()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    preferredHostsResult: new MackanPreferredHostsResult(
                        "primary",
                        new[] { "github.com", "spacedock.info", "archive.org" },
                        new[] { "github.com", null, "spacedock.info" },
                        "<ALL OTHER HOSTS>")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":50,\"method\":\"settings.updatePreferredHosts\",\"params\":{\"instanceId\":\"primary\",\"preferredHosts\":[\"github.com\",null,\"spacedock.info\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(50));
            Assert.That(ReadNullableStrings(result.GetProperty("preferredHosts")), Is.EqualTo(new[] { "github.com", null, "spacedock.info" }));
        }

        [Test]
        public void SettingsInstallFiltersReturnsGlobalInstanceAndPresets()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    installFiltersResult: new MackanInstallFiltersResult(
                        "primary",
                        "KSP",
                        new[] { "GameData/ModuleManager.ConfigCache", "Ships" },
                        new[] { "GameData/TestMod/Extras" },
                        new[]
                        {
                            new MackanInstallFilterPreset("MiniAVC", new[] { "MiniAVC.dll", "MiniAVC.xml" }),
                            new MackanInstallFilterPreset("Craft files", new[] { "Ships", "SPH", "VAB" }),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":51,\"method\":\"settings.installFilters\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var presets = result.GetProperty("presets");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(51));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("game").GetString(), Is.EqualTo("KSP"));
            Assert.That(ReadStrings(result.GetProperty("globalFilters")), Is.EqualTo(new[] { "GameData/ModuleManager.ConfigCache", "Ships" }));
            Assert.That(ReadStrings(result.GetProperty("instanceFilters")), Is.EqualTo(new[] { "GameData/TestMod/Extras" }));
            Assert.That(presets[0].GetProperty("name").GetString(), Is.EqualTo("MiniAVC"));
            Assert.That(ReadStrings(presets[0].GetProperty("filters")), Is.EqualTo(new[] { "MiniAVC.dll", "MiniAVC.xml" }));
            Assert.That(presets[1].GetProperty("name").GetString(), Is.EqualTo("Craft files"));
            Assert.That(ReadStrings(presets[1].GetProperty("filters")), Is.EqualTo(new[] { "Ships", "SPH", "VAB" }));
        }

        [Test]
        public void SettingsUpdateInstallFiltersAcceptsGlobalAndInstanceFilters()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    installFiltersResult: new MackanInstallFiltersResult(
                        "primary",
                        "KSP",
                        new[] { "Ships", "MiniAVC.dll" },
                        new[] { "GameData/TestMod/Extras" },
                        new[]
                        {
                            new MackanInstallFilterPreset("MiniAVC", new[] { "MiniAVC.dll", "MiniAVC.xml" }),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":52,\"method\":\"settings.updateInstallFilters\",\"params\":{\"instanceId\":\"primary\",\"globalFilters\":[\"Ships\",\"MiniAVC.dll\"],\"instanceFilters\":[\"GameData/TestMod/Extras\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(52));
            Assert.That(ReadStrings(result.GetProperty("globalFilters")), Is.EqualTo(new[] { "Ships", "MiniAVC.dll" }));
            Assert.That(ReadStrings(result.GetProperty("instanceFilters")), Is.EqualTo(new[] { "GameData/TestMod/Extras" }));
        }

        [Test]
        public void SettingsRecommendationPreferencesReturnAndUpdateSuppression()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    recommendationSettingsResult: new MackanRecommendationSettingsResult("primary", true)));

            using var getDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":56,\"method\":\"settings.recommendations\",\"params\":{\"instanceId\":\"primary\"}}"));
            using var updateDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":57,\"method\":\"settings.updateRecommendations\",\"params\":{\"instanceId\":\"primary\",\"suppressRecommendations\":true}}"));

            var getResult = getDocument.RootElement.GetProperty("result");
            var updateResult = updateDocument.RootElement.GetProperty("result");
            Assert.That(getResult.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(getResult.GetProperty("suppressRecommendations").GetBoolean(), Is.True);
            Assert.That(updateResult.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(updateResult.GetProperty("suppressRecommendations").GetBoolean(), Is.True);
        }

        [Test]
        public void SettingsAuthTokensReturnsHostsWithMaskedTokens()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    authTokensResult: new MackanAuthTokensResult(
                        new[]
                        {
                            new MackanAuthTokenSummary("api.github.com", "********7890"),
                            new MackanAuthTokenSummary("github.com", "********cdef"),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":53,\"method\":\"settings.authTokens\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var tokens = result.GetProperty("authTokens");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(53));
            Assert.That(tokens.GetArrayLength(), Is.EqualTo(2));
            Assert.That(tokens[0].GetProperty("host").GetString(), Is.EqualTo("api.github.com"));
            Assert.That(tokens[0].GetProperty("tokenPreview").GetString(), Is.EqualTo("********7890"));
            Assert.That(tokens[0].TryGetProperty("token", out _), Is.False);
            Assert.That(tokens[1].GetProperty("host").GetString(), Is.EqualTo("github.com"));
            Assert.That(tokens[1].GetProperty("tokenPreview").GetString(), Is.EqualTo("********cdef"));
            Assert.That(tokens[1].TryGetProperty("token", out _), Is.False);
        }

        [Test]
        public void SettingsAddAndRemoveAuthTokenUseHostAndTokenParams()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                settingsProvider: new FakeSettingsProvider(
                    new MackanSettingsResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        "/Users/test/Library/Caches/CKAN/downloads",
                        true,
                        1073741824,
                        "1 GiB"),
                    authTokensResult: new MackanAuthTokensResult(
                        new[]
                        {
                            new MackanAuthTokenSummary("github.com", "********cdef"),
                        })));

            using var addDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":54,\"method\":\"settings.addAuthToken\",\"params\":{\"host\":\"github.com\",\"token\":\"abcdef\"}}"));
            using var removeDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":55,\"method\":\"settings.removeAuthToken\",\"params\":{\"host\":\"github.com\"}}"));

            Assert.That(addDocument.RootElement.GetProperty("id").GetInt32(), Is.EqualTo(54));
            Assert.That(addDocument.RootElement.GetProperty("result").GetProperty("authTokens")[0].GetProperty("host").GetString(), Is.EqualTo("github.com"));
            Assert.That(removeDocument.RootElement.GetProperty("id").GetInt32(), Is.EqualTo(55));
            Assert.That(removeDocument.RootElement.GetProperty("result").GetProperty("authTokens")[0].GetProperty("tokenPreview").GetString(), Is.EqualTo("********cdef"));
        }

        [Test]
        public void InvalidJsonReturnsParseErrorWithNullId()
        {
            var dispatcher = new MackanServiceDispatcher(() => "1.2.3-test");

            using var document = JsonDocument.Parse(dispatcher.Handle("{"));
            var root = document.RootElement;
            var error = root.GetProperty("error");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").ValueKind, Is.EqualTo(JsonValueKind.Null));
            Assert.That(error.GetProperty("code").GetInt32(), Is.EqualTo(-32700));
            Assert.That(error.GetProperty("message").GetString(), Is.EqualTo("Parse error"));
        }

        [Test]
        public void InstancesListReturnsKnownInstances()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "primary",
                            "Primary KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP",
                            true,
                            true,
                            false),
                        new MackanInstanceSummary(
                            "test",
                            "Test KSP",
                            "KSP",
                            "1.11.2",
                            "/Games/KSP-Test",
                            false,
                            false,
                            true),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"instances.list\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(8));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(2));
            Assert.That(instances[0].GetProperty("id").GetString(), Is.EqualTo("primary"));
            Assert.That(instances[0].GetProperty("name").GetString(), Is.EqualTo("Primary KSP"));
            Assert.That(instances[0].GetProperty("game").GetString(), Is.EqualTo("KSP"));
            Assert.That(instances[0].GetProperty("gameVersion").GetString(), Is.EqualTo("1.12.5"));
            Assert.That(instances[0].GetProperty("path").GetString(), Is.EqualTo("/Games/KSP"));
            Assert.That(instances[0].GetProperty("isDefault").GetBoolean(), Is.True);
            Assert.That(instances[0].GetProperty("isValid").GetBoolean(), Is.True);
            Assert.That(instances[0].GetProperty("isMaybeLocked").GetBoolean(), Is.False);
            Assert.That(instances[1].GetProperty("isDefault").GetBoolean(), Is.False);
            Assert.That(instances[1].GetProperty("isValid").GetBoolean(), Is.False);
            Assert.That(instances[1].GetProperty("isMaybeLocked").GetBoolean(), Is.True);
        }

        [Test]
        public void InstancesSetDefaultReturnsUpdatedInstances()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "secondary",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "primary",
                            "Primary KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP",
                            false,
                            true,
                            false),
                        new MackanInstanceSummary(
                            "secondary",
                            "Secondary KSP",
                            "KSP",
                            "1.11.2",
                            "/Games/KSP-Secondary",
                            true,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":20,\"method\":\"instances.setDefault\",\"params\":{\"instanceId\":\"secondary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(20));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("secondary"));
            Assert.That(instances[0].GetProperty("isDefault").GetBoolean(), Is.False);
            Assert.That(instances[1].GetProperty("isDefault").GetBoolean(), Is.True);
        }

        [Test]
        public void InstancesAddUsesPathAndName()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "New KSP",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "New KSP",
                            "New KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP-New",
                            true,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":43,\"method\":\"instances.add\",\"params\":{\"path\":\"/Games/KSP-New\",\"name\":\"New KSP\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(43));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("New KSP"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(1));
            Assert.That(instances[0].GetProperty("id").GetString(), Is.EqualTo("New KSP"));
            Assert.That(instances[0].GetProperty("path").GetString(), Is.EqualTo("/Games/KSP-New"));
            Assert.That(instances[0].GetProperty("isValid").GetBoolean(), Is.True);
        }

        [Test]
        public void InstancesCloneUsesSourceNamePathShareStockAndLeaveEmptyPaths()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "Cloned KSP",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "primary",
                            "Primary KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP",
                            false,
                            true,
                            false),
                        new MackanInstanceSummary(
                            "Cloned KSP",
                            "Cloned KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP-Clone",
                            true,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":44,\"method\":\"instances.clone\",\"params\":{\"sourceInstanceId\":\"primary\",\"newName\":\"Cloned KSP\",\"newPath\":\"/Games/KSP-Clone\",\"shareStock\":false,\"leaveEmptyPaths\":[\"saves\",\"Screenshots\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(44));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("Cloned KSP"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(2));
            Assert.That(instances[1].GetProperty("id").GetString(), Is.EqualTo("Cloned KSP"));
            Assert.That(instances[1].GetProperty("path").GetString(), Is.EqualTo("/Games/KSP-Clone"));
        }

        [Test]
        public void InstancesCloneOptionsReturnsLeaveEmptyPaths()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    Array.Empty<MackanInstanceSummary>())));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":46,\"method\":\"instances.cloneOptions\",\"params\":{\"sourceInstanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var paths = result.GetProperty("leaveEmptyPaths");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(46));
            Assert.That(result.GetProperty("sourceInstanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(paths.GetArrayLength(), Is.EqualTo(2));
            Assert.That(paths[0].GetString(), Is.EqualTo("saves"));
            Assert.That(paths[1].GetString(), Is.EqualTo("Screenshots"));
        }

        [Test]
        public void InstancesFakeUsesGameVersionPathNameDlcAndDefaultFlag()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "Fake KSP",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "Fake KSP",
                            "Fake KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP-Fake",
                            true,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":45,\"method\":\"instances.fake\",\"params\":{\"name\":\"Fake KSP\",\"path\":\"/Games/KSP-Fake\",\"version\":\"1.12.5\",\"gameId\":\"KSP\",\"makingHistoryVersion\":\"1.12.1\",\"breakingGroundVersion\":\"1.7.1\",\"setDefault\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(45));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("Fake KSP"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(1));
            Assert.That(instances[0].GetProperty("id").GetString(), Is.EqualTo("Fake KSP"));
            Assert.That(instances[0].GetProperty("game").GetString(), Is.EqualTo("KSP"));
            Assert.That(instances[0].GetProperty("path").GetString(), Is.EqualTo("/Games/KSP-Fake"));
        }

        [Test]
        public void InstancesRemoveReturnsUpdatedInstances()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "primary",
                            "Primary KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP",
                            true,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":21,\"method\":\"instances.remove\",\"params\":{\"instanceId\":\"secondary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(21));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(1));
            Assert.That(instances[0].GetProperty("id").GetString(), Is.EqualTo("primary"));
            Assert.That(instances[0].GetProperty("isDefault").GetBoolean(), Is.True);
        }

        [Test]
        public void InstancesRenameReturnsUpdatedInstances()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new[]
                    {
                        new MackanInstanceSummary(
                            "primary",
                            "Primary KSP",
                            "KSP",
                            "1.12.5",
                            "/Games/KSP",
                            true,
                            true,
                            false),
                        new MackanInstanceSummary(
                            "renamed",
                            "Renamed KSP",
                            "KSP",
                            "1.11.2",
                            "/Games/KSP-Secondary",
                            false,
                            true,
                            false),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":22,\"method\":\"instances.rename\",\"params\":{\"instanceId\":\"secondary\",\"newName\":\"renamed\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var instances = result.GetProperty("instances");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(22));
            Assert.That(result.GetProperty("defaultInstanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(instances.GetArrayLength(), Is.EqualTo(2));
            Assert.That(instances[1].GetProperty("id").GetString(), Is.EqualTo("renamed"));
            Assert.That(instances[1].GetProperty("name").GetString(), Is.EqualTo("Renamed KSP"));
        }

        [Test]
        public void InstancesLaunchOptionsReturnsCommandLines()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new MackanInstanceSummary[] { })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":23,\"method\":\"instances.launchOptions\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var commandLines = result.GetProperty("commandLines");
            var defaultCommandLines = result.GetProperty("defaultCommandLines");
            var incompatibleModules = result.GetProperty("incompatibleModules");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(23));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(commandLines.GetArrayLength(), Is.EqualTo(2));
            Assert.That(commandLines[0].GetString(), Is.EqualTo("./KSP.app/Contents/MacOS/KSP"));
            Assert.That(commandLines[1].GetString(), Is.EqualTo("steam://run/220200"));
            Assert.That(defaultCommandLines.GetArrayLength(), Is.EqualTo(1));
            Assert.That(defaultCommandLines[0].GetString(), Is.EqualTo("./KSP.app/Contents/MacOS/KSP"));
            Assert.That(incompatibleModules.GetArrayLength(), Is.EqualTo(1));
            Assert.That(incompatibleModules[0].GetProperty("identifier").GetString(), Is.EqualTo("OldMod"));
            Assert.That(incompatibleModules[0].GetProperty("name").GetString(), Is.EqualTo("Old Mod"));
            Assert.That(incompatibleModules[0].GetProperty("version").GetString(), Is.EqualTo("0.9.0"));
            Assert.That(incompatibleModules[0].GetProperty("compatibleGameVersions").GetString(), Is.EqualTo("KSP 1.8"));
        }

        [Test]
        public void InstancesUpdateLaunchOptionsReturnsSavedCommandLines()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new MackanInstanceSummary[] { })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":25,\"method\":\"instances.updateLaunchOptions\",\"params\":{\"instanceId\":\"primary\",\"commandLines\":[\"./KSP.app/Contents/MacOS/KSP -popupwindow\",\"steam://run/220200\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var commandLines = result.GetProperty("commandLines");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(25));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(commandLines.GetArrayLength(), Is.EqualTo(2));
            Assert.That(commandLines[0].GetString(), Is.EqualTo("./KSP.app/Contents/MacOS/KSP -popupwindow"));
            Assert.That(commandLines[1].GetString(), Is.EqualTo("steam://run/220200"));
        }

        [Test]
        public void InstancesLaunchStartsRequestedCommandLine()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new MackanInstanceSummary[] { })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":24,\"method\":\"instances.launch\",\"params\":{\"instanceId\":\"primary\",\"commandLine\":\"./KSP.app/Contents/MacOS/KSP -popupwindow\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(24));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("commandLine").GetString(), Is.EqualTo("./KSP.app/Contents/MacOS/KSP -popupwindow"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("started"));
            Assert.That(result.GetProperty("processId").GetInt32(), Is.EqualTo(12345));
        }

        [Test]
        public void InstancesLaunchCanSuppressIncompatibleWarnings()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: new FakeInstanceProvider(new MackanInstancesResult(
                    "primary",
                    new MackanInstanceSummary[] { })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":26,\"method\":\"instances.launch\",\"params\":{\"instanceId\":\"primary\",\"commandLine\":\"./KSP.app/Contents/MacOS/KSP -popupwindow\",\"suppressIncompatibleWarnings\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(26));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("started"));
            Assert.That(result.GetProperty("processId").GetInt32(), Is.EqualTo(12345));
        }

        [Test]
        public void InstancesLaunchReturnsLaunchFailureErrorForFailedProcessStart()
        {
            var instanceProvider = new FailingLaunchInstanceProvider(
                new FakeInstanceProvider(
                    new MackanInstancesResult(
                        "primary",
                        new MackanInstanceSummary[] { })));

            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                instanceProvider: instanceProvider);

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":27,\"method\":\"instances.launch\",\"params\":{\"instanceId\":\"primary\",\"commandLine\":\"missing-ksp-launch-binary\"}}"));
            var root = document.RootElement;
            var error = root.GetProperty("error");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(27));
            Assert.That(error.GetProperty("code").GetInt32(), Is.EqualTo(-32000));
            Assert.That(error.GetProperty("message").GetString(), Is.EqualTo("Failed to launch game with command 'missing-ksp-launch-binary'."));
            var errorData = error.GetProperty("data");
            Assert.That(errorData.GetProperty("kind").GetString(), Is.EqualTo("launchFailure"));
            Assert.That(errorData.GetProperty("command").GetString(), Is.EqualTo("missing-ksp-launch-binary"));
            Assert.That(errorData.GetProperty("suggestedAction").GetString(), Is.EqualTo("retryOrCheckCommand"));
        }

        [Test]
        public void ModsListReturnsKnownModulesForRequestedInstance()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                moduleProvider: new FakeModuleProvider(new MackanModulesResult(
                    "primary",
                    new[]
                    {
                        new MackanModuleSummary(
                            "ModuleManager",
                            "Module Manager",
                            "sarbian",
                            "installed",
                            "4.2.3",
                            "4.2.3",
                            "CC-BY-SA",
                            new[]
                            {
                                new MackanModuleRelationship("Depends", "Kerbal Space Program"),
                            },
                            new[] { "4.2.3", "4.2.2" },
                            new[] { "GameData/ModuleManager.4.2.3.dll" },
                            isInstalled: true,
                            isCompatible: true,
                            isCached: true,
                            isNew: false,
                            hasUpdate: false,
                            hasReplacement: false,
                            tags: new[] { "plugin", "library" },
                            @abstract: "Shared plugin loader",
                            description: "Loads ModuleManager patches for KSP.",
                            localizations: new[] { "en-us", "ru" },
                            gameCompatibility: "1.12.5",
                            downloadSize: 1024,
                            downloadSizeDisplay: "1 KiB",
                            installSize: 2048,
                            installSizeDisplay: "2 KiB",
                            releaseDate: "2024-01-02T03:04:05.0000000Z",
                            installDate: "2024-02-03T04:05:06.0000000Z",
                            downloadCount: 123456,
                            isAutoInstalled: true,
                            isAutodetected: false),
                        new MackanModuleSummary(
                            "Scatterer",
                            "Scatterer",
                            "blackrack",
                            "upgradable",
                            "0.0838",
                            "0.0878",
                            "GPL-3.0",
                            new[]
                            {
                                new MackanModuleRelationship("Recommends", "EnvironmentalVisualEnhancements"),
                            },
                            new[] { "0.0878", "0.0838" },
                            new[] { "GameData/scatterer" },
                            isInstalled: true,
                            isCompatible: true,
                            isCached: false,
                            isNew: true,
                            hasUpdate: true,
                            hasReplacement: true),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"mods.list\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var modules = result.GetProperty("modules");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(9));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(modules.GetArrayLength(), Is.EqualTo(2));
            Assert.That(modules[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(modules[0].GetProperty("name").GetString(), Is.EqualTo("Module Manager"));
            Assert.That(modules[0].GetProperty("author").GetString(), Is.EqualTo("sarbian"));
            Assert.That(modules[0].GetProperty("status").GetString(), Is.EqualTo("installed"));
            Assert.That(modules[0].GetProperty("installedVersion").GetString(), Is.EqualTo("4.2.3"));
            Assert.That(modules[0].GetProperty("latestVersion").GetString(), Is.EqualTo("4.2.3"));
            Assert.That(modules[0].GetProperty("license").GetString(), Is.EqualTo("CC-BY-SA"));
            Assert.That(modules[0].GetProperty("relationships")[0].GetProperty("kind").GetString(), Is.EqualTo("Depends"));
            Assert.That(modules[0].GetProperty("relationships")[0].GetProperty("value").GetString(), Is.EqualTo("Kerbal Space Program"));
            Assert.That(modules[0].GetProperty("versions")[0].GetString(), Is.EqualTo("4.2.3"));
            Assert.That(modules[0].GetProperty("contents")[0].GetString(), Is.EqualTo("GameData/ModuleManager.4.2.3.dll"));
            Assert.That(modules[0].GetProperty("isInstalled").GetBoolean(), Is.True);
            Assert.That(modules[0].GetProperty("isCompatible").GetBoolean(), Is.True);
            Assert.That(modules[0].GetProperty("isCached").GetBoolean(), Is.True);
            Assert.That(modules[0].GetProperty("isNew").GetBoolean(), Is.False);
            Assert.That(modules[0].GetProperty("hasUpdate").GetBoolean(), Is.False);
            Assert.That(modules[0].GetProperty("hasReplacement").GetBoolean(), Is.False);
            Assert.That(modules[0].GetProperty("tags")[0].GetString(), Is.EqualTo("plugin"));
            Assert.That(modules[0].GetProperty("tags")[1].GetString(), Is.EqualTo("library"));
            Assert.That(modules[0].GetProperty("abstract").GetString(), Is.EqualTo("Shared plugin loader"));
            Assert.That(modules[0].GetProperty("description").GetString(), Is.EqualTo("Loads ModuleManager patches for KSP."));
            Assert.That(modules[0].GetProperty("localizations")[0].GetString(), Is.EqualTo("en-us"));
            Assert.That(modules[0].GetProperty("localizations")[1].GetString(), Is.EqualTo("ru"));
            Assert.That(modules[0].GetProperty("gameCompatibility").GetString(), Is.EqualTo("1.12.5"));
            Assert.That(modules[0].GetProperty("downloadSize").GetInt64(), Is.EqualTo(1024));
            Assert.That(modules[0].GetProperty("downloadSizeDisplay").GetString(), Is.EqualTo("1 KiB"));
            Assert.That(modules[0].GetProperty("installSize").GetInt64(), Is.EqualTo(2048));
            Assert.That(modules[0].GetProperty("installSizeDisplay").GetString(), Is.EqualTo("2 KiB"));
            Assert.That(modules[0].GetProperty("releaseDate").GetString(), Is.EqualTo("2024-01-02T03:04:05.0000000Z"));
            Assert.That(modules[0].GetProperty("installDate").GetString(), Is.EqualTo("2024-02-03T04:05:06.0000000Z"));
            Assert.That(modules[0].GetProperty("downloadCount").GetInt32(), Is.EqualTo(123456));
            Assert.That(modules[0].GetProperty("isAutoInstalled").GetBoolean(), Is.True);
            Assert.That(modules[0].GetProperty("isAutodetected").GetBoolean(), Is.False);
            Assert.That(modules[1].GetProperty("status").GetString(), Is.EqualTo("upgradable"));
            Assert.That(modules[1].GetProperty("isInstalled").GetBoolean(), Is.True);
            Assert.That(modules[1].GetProperty("isCompatible").GetBoolean(), Is.True);
            Assert.That(modules[1].GetProperty("isCached").GetBoolean(), Is.False);
            Assert.That(modules[1].GetProperty("isNew").GetBoolean(), Is.True);
            Assert.That(modules[1].GetProperty("hasUpdate").GetBoolean(), Is.True);
            Assert.That(modules[1].GetProperty("hasReplacement").GetBoolean(), Is.True);
        }

        [Test]
        public void ModsListStatusReturnsProgressAndFinalModules()
        {
            var module = new MackanModuleSummary(
                "ModuleManager",
                "Module Manager",
                "sarbian",
                "installed",
                "4.2.3",
                "4.2.3",
                "CC-BY-SA",
                Array.Empty<MackanModuleRelationship>(),
                new[] { "4.2.3" },
                new[] { "GameData/ModuleManager.4.2.3.dll" });
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                moduleProvider: new FakeModuleProvider(new MackanModulesResult("primary", new[] { module })));

            using var startedDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"mods.startList\",\"params\":{\"instanceId\":\"primary\"}}"));
            var started = startedDocument.RootElement.GetProperty("result");
            using var statusDocument = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"mods.listStatus\",\"params\":{\"operationId\":\"module-op-1\"}}"));
            var status = statusDocument.RootElement.GetProperty("result");

            Assert.That(started.GetProperty("operationId").GetString(), Is.EqualTo("module-op-1"));
            Assert.That(started.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(started.GetProperty("events")[0].GetProperty("completedCount").GetInt32(), Is.EqualTo(100));
            Assert.That(started.GetProperty("events")[0].GetProperty("totalCount").GetInt32(), Is.EqualTo(350));
            Assert.That(status.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(status.GetProperty("modules")[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(status.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Loaded 1 mods"));
        }

        [Test]
        public void ModsSetAutoInstalledUpdatesModuleAndReturnsRefreshedCatalog()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                moduleProvider: new FakeModuleProvider(new MackanModulesResult(
                    "primary",
                    new[]
                    {
                        new MackanModuleSummary(
                            "ModuleManager",
                            "Module Manager",
                            "sarbian",
                            "installed",
                            "4.2.3",
                            "4.2.3",
                            "CC-BY-SA",
                            Array.Empty<MackanModuleRelationship>(),
                            new[] { "4.2.3" },
                            new[] { "GameData/ModuleManager.4.2.3.dll" },
                            isInstalled: true,
                            isAutoInstalled: true),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":91,\"method\":\"mods.setAutoInstalled\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"ModuleManager\",\"isAutoInstalled\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var module = result.GetProperty("modules")[0];

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(91));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(module.GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(module.GetProperty("isAutoInstalled").GetBoolean(), Is.True);
        }

        [Test]
        public void ModsDetailsReturnsSelectedModuleDetails()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                moduleProvider: new FakeModuleProvider(
                    new MackanModulesResult("primary", new MackanModuleSummary[] { }),
                    new MackanModuleDetailsResult(
                        "primary",
                        new MackanModuleSummary(
                            "ModuleManager",
                            "Module Manager",
                            "sarbian",
                            "installed",
                            "4.2.3",
                            "4.2.3",
                            "CC-BY-SA",
                            new[]
                            {
                                new MackanModuleRelationship("Depends", "Kerbal Space Program"),
                            },
                            new[] { "4.2.3", "4.2.2" },
                            new[] { "GameData/ModuleManager.4.2.3.dll" }),
                        "Shared plugin loader",
                        "Loads ModuleManager patches for KSP.",
                        "stable",
                        "package",
                        "2024-01-02T03:04:05.0000000Z",
                        1024,
                        2048,
                        new[]
                        {
                            new MackanModuleResource("Homepage", "https://example.invalid/mod"),
                            new MackanModuleResource("Repository", "https://example.invalid/repo"),
                        },
                        new[] { "plugin", "library" })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"mods.details\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"ModuleManager\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var module = result.GetProperty("module");
            var resources = result.GetProperty("resources");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(10));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(module.GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(module.GetProperty("name").GetString(), Is.EqualTo("Module Manager"));
            Assert.That(result.GetProperty("abstract").GetString(), Is.EqualTo("Shared plugin loader"));
            Assert.That(result.GetProperty("description").GetString(), Is.EqualTo("Loads ModuleManager patches for KSP."));
            Assert.That(result.GetProperty("releaseStatus").GetString(), Is.EqualTo("stable"));
            Assert.That(result.GetProperty("kind").GetString(), Is.EqualTo("package"));
            Assert.That(result.GetProperty("releaseDate").GetString(), Is.EqualTo("2024-01-02T03:04:05.0000000Z"));
            Assert.That(result.GetProperty("downloadSize").GetInt64(), Is.EqualTo(1024));
            Assert.That(result.GetProperty("installSize").GetInt64(), Is.EqualTo(2048));
            Assert.That(resources.GetArrayLength(), Is.EqualTo(2));
            Assert.That(resources[0].GetProperty("label").GetString(), Is.EqualTo("Homepage"));
            Assert.That(resources[0].GetProperty("url").GetString(), Is.EqualTo("https://example.invalid/mod"));
            Assert.That(result.GetProperty("tags")[0].GetString(), Is.EqualTo("plugin"));
        }

        [Test]
        public void LabelsListReturnsCustomLabelsForRequestedInstance()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                labelProvider: new FakeLabelProvider(new MackanLabelsResult(
                    "primary",
                    new[]
                    {
                        new MackanModuleLabel(
                            "Favourites",
                            null,
                            "#98FB98",
                            false,
                            false,
                            false,
                            new[] { "ModuleManager" }),
                        new MackanModuleLabel(
                            "Hidden",
                            "primary",
                            "#DB7093",
                            true,
                            false,
                            false,
                            new[] { "Scatterer" }),
                    },
                    new[]
                    {
                        new MackanModuleLabel(
                            "Favourites",
                            null,
                            "#98FB98",
                            false,
                            false,
                            false,
                            new[] { "ModuleManager" }),
                        new MackanModuleLabel(
                            "Secondary Only",
                            "secondary",
                            "#DB7093",
                            true,
                            false,
                            false,
                            new[] { "Scatterer" }),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":44,\"method\":\"labels.list\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var labels = result.GetProperty("labels");
            var manageableLabels = result.GetProperty("manageableLabels");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(44));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(labels.GetArrayLength(), Is.EqualTo(2));
            Assert.That(labels[0].GetProperty("name").GetString(), Is.EqualTo("Favourites"));
            Assert.That(labels[0].GetProperty("instanceName").ValueKind, Is.EqualTo(JsonValueKind.Null));
            Assert.That(labels[0].GetProperty("colorHex").GetString(), Is.EqualTo("#98FB98"));
            Assert.That(labels[0].GetProperty("hide").GetBoolean(), Is.False);
            Assert.That(labels[0].GetProperty("holdVersion").GetBoolean(), Is.False);
            Assert.That(labels[0].GetProperty("ignoreMissingFiles").GetBoolean(), Is.False);
            Assert.That(labels[0].GetProperty("identifiers")[0].GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(labels[1].GetProperty("instanceName").GetString(), Is.EqualTo("primary"));
            Assert.That(labels[1].GetProperty("hide").GetBoolean(), Is.True);
            Assert.That(manageableLabels.GetArrayLength(), Is.EqualTo(2));
            Assert.That(manageableLabels[1].GetProperty("name").GetString(), Is.EqualTo("Secondary Only"));
            Assert.That(manageableLabels[1].GetProperty("instanceName").GetString(), Is.EqualTo("secondary"));
        }

        [Test]
        public void LabelsToggleModuleUsesRequestedLabelAndIdentifier()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                labelProvider: new FakeLabelProvider(new MackanLabelsResult(
                    "primary",
                    new[]
                    {
                        new MackanModuleLabel(
                            "Favourites",
                            null,
                            "#98FB98",
                            false,
                            false,
                            false,
                            new[] { "ModuleManager", "Scatterer" }),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":45,\"method\":\"labels.toggleModule\",\"params\":{\"instanceId\":\"primary\",\"labelName\":\"Favourites\",\"identifier\":\"Scatterer\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var labels = result.GetProperty("labels");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(45));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(labels[0].GetProperty("name").GetString(), Is.EqualTo("Favourites"));
            Assert.That(labels[0].GetProperty("identifiers")[1].GetString(), Is.EqualTo("Scatterer"));
        }

        [Test]
        public void LabelsUpsertCreatesInstanceScopedLabelWithWindowsFlags()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                labelProvider: new FakeLabelProvider(new MackanLabelsResult(
                    "primary",
                    new[]
                    {
                        new MackanModuleLabel(
                            "Watch",
                            "primary",
                            "#336699",
                            true,
                            true,
                            false,
                            true,
                            false,
                            true,
                            true,
                            new[] { "ModuleManager" }),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle(
                    "{\"jsonrpc\":\"2.0\",\"id\":46,\"method\":\"labels.upsert\",\"params\":{\"instanceId\":\"primary\",\"label\":{\"name\":\"Watch\",\"instanceName\":\"primary\",\"colorHex\":\"#336699\",\"hide\":true,\"notifyOnChange\":true,\"removeOnChange\":false,\"alertOnInstall\":true,\"removeOnInstall\":false,\"holdVersion\":true,\"ignoreMissingFiles\":true}}}"));
            var root = document.RootElement;
            var label = root.GetProperty("result").GetProperty("labels")[0];

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(46));
            Assert.That(label.GetProperty("name").GetString(), Is.EqualTo("Watch"));
            Assert.That(label.GetProperty("instanceName").GetString(), Is.EqualTo("primary"));
            Assert.That(label.GetProperty("colorHex").GetString(), Is.EqualTo("#336699"));
            Assert.That(label.GetProperty("hide").GetBoolean(), Is.True);
            Assert.That(label.GetProperty("notifyOnChange").GetBoolean(), Is.True);
            Assert.That(label.GetProperty("removeOnChange").GetBoolean(), Is.False);
            Assert.That(label.GetProperty("alertOnInstall").GetBoolean(), Is.True);
            Assert.That(label.GetProperty("removeOnInstall").GetBoolean(), Is.False);
            Assert.That(label.GetProperty("holdVersion").GetBoolean(), Is.True);
            Assert.That(label.GetProperty("ignoreMissingFiles").GetBoolean(), Is.True);
        }

        [Test]
        public void LabelsDeleteUsesRequestedLabelIdentity()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                labelProvider: new FakeLabelProvider(new MackanLabelsResult(
                    "primary",
                    Array.Empty<MackanModuleLabel>())));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":47,\"method\":\"labels.delete\",\"params\":{\"instanceId\":\"primary\",\"name\":\"Watch\",\"instanceName\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(47));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("labels").GetArrayLength(), Is.EqualTo(0));
        }

        [Test]
        public void RepositoriesListReturnsRepositoriesForRequestedInstance()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(new MackanRepositoriesResult(
                    "primary",
                    new[]
                    {
                        new MackanRepositorySummary(
                            "default",
                            "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                            0,
                            false,
                            ""),
                        new MackanRepositorySummary(
                            "mirror",
                            "https://example.invalid/mirror.tar.gz",
                            1,
                            true,
                            "fallback mirror"),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"repositories.list\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");

            Assert.That(root.GetProperty("jsonrpc").GetString(), Is.EqualTo("2.0"));
            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(11));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(repositories.GetArrayLength(), Is.EqualTo(2));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("default"));
            Assert.That(repositories[0].GetProperty("url").GetString(), Is.EqualTo("https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz"));
            Assert.That(repositories[0].GetProperty("priority").GetInt32(), Is.EqualTo(0));
            Assert.That(repositories[0].GetProperty("isMirror").GetBoolean(), Is.False);
            Assert.That(repositories[0].GetProperty("comment").GetString(), Is.EqualTo(""));
            Assert.That(repositories[1].GetProperty("name").GetString(), Is.EqualTo("mirror"));
            Assert.That(repositories[1].GetProperty("isMirror").GetBoolean(), Is.True);
            Assert.That(repositories[1].GetProperty("comment").GetString(), Is.EqualTo("fallback mirror"));
        }

        [Test]
        public void RepositoriesAvailableReturnsCanonicalRepositories()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(
                    new MackanRepositoriesResult("primary", new MackanRepositorySummary[] { }),
                    availableResult: new MackanRepositoriesResult(
                        "primary",
                        new[]
                        {
                            new MackanRepositorySummary(
                                "stable",
                                "https://example.invalid/stable.tar.gz",
                                0,
                                false,
                                "canonical stable"),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":16,\"method\":\"repositories.available\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(16));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("stable"));
            Assert.That(repositories[0].GetProperty("comment").GetString(), Is.EqualTo("canonical stable"));
        }

        [Test]
        public void RepositoriesAddReturnsUpdatedRepositories()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(new MackanRepositoriesResult(
                    "primary",
                    new[]
                    {
                        new MackanRepositorySummary(
                            "newrepo",
                            "https://example.invalid/newrepo.tar.gz",
                            1,
                            false,
                            ""),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"repositories.add\",\"params\":{\"instanceId\":\"primary\",\"name\":\"newrepo\",\"url\":\"https://example.invalid/newrepo.tar.gz\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(12));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("newrepo"));
            Assert.That(repositories[0].GetProperty("url").GetString(), Is.EqualTo("https://example.invalid/newrepo.tar.gz"));
        }

        [Test]
        public void RepositoriesRemoveReturnsUpdatedRepositories()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(new MackanRepositoriesResult(
                    "primary",
                    new[]
                    {
                        new MackanRepositorySummary(
                            "default",
                            "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                            0,
                            false,
                            ""),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":13,\"method\":\"repositories.remove\",\"params\":{\"instanceId\":\"primary\",\"name\":\"mirror\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(13));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(repositories.GetArrayLength(), Is.EqualTo(1));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("default"));
        }

        [Test]
        public void RepositoriesSetPriorityReturnsReorderedRepositories()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(new MackanRepositoriesResult(
                    "primary",
                    new[]
                    {
                        new MackanRepositorySummary(
                            "mirror",
                            "https://example.invalid/mirror.tar.gz",
                            0,
                            true,
                            ""),
                        new MackanRepositorySummary(
                            "default",
                            "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                            1,
                            false,
                            ""),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":14,\"method\":\"repositories.setPriority\",\"params\":{\"instanceId\":\"primary\",\"name\":\"mirror\",\"priority\":0}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(14));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("mirror"));
            Assert.That(repositories[0].GetProperty("priority").GetInt32(), Is.EqualTo(0));
            Assert.That(repositories[1].GetProperty("name").GetString(), Is.EqualTo("default"));
            Assert.That(repositories[1].GetProperty("priority").GetInt32(), Is.EqualTo(1));
        }

        [Test]
        public void RepositoriesRefreshReturnsSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(
                    new MackanRepositoriesResult("primary", new MackanRepositorySummary[] { }),
                    new MackanRepositoryRefreshResult(
                        "primary",
                        "updated",
                        42,
                        new[]
                        {
                            new MackanRepositorySummary(
                                "default",
                                "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                                0,
                                false,
                                ""),
                        },
                        new[]
                        {
                            new MackanOperationEvent("message", "Updating repositories", null, null, null, null),
                            new MackanOperationEvent("progress", "Done", 100, null, null, null),
                        })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":15,\"method\":\"repositories.refresh\",\"params\":{\"instanceId\":\"primary\",\"force\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var repositories = result.GetProperty("repositories");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(15));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("updated"));
            Assert.That(result.GetProperty("compatibleModuleCount").GetInt32(), Is.EqualTo(42));
            Assert.That(repositories[0].GetProperty("name").GetString(), Is.EqualTo("default"));
            Assert.That(events.GetArrayLength(), Is.EqualTo(2));
            Assert.That(events[0].GetProperty("kind").GetString(), Is.EqualTo("message"));
            Assert.That(events[1].GetProperty("percent").GetInt32(), Is.EqualTo(100));
        }

        [Test]
        public void RepositoriesStartRefreshReturnsRunningOperationSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(
                    new MackanRepositoriesResult("primary", new MackanRepositorySummary[] { }),
                    startRefreshResult: new MackanRepositoryRefreshResult(
                        "primary",
                        "running",
                        0,
                        Array.Empty<MackanRepositorySummary>(),
                        new[]
                        {
                            new MackanOperationEvent("message", "Repository refresh queued", null, null, null, null),
                        },
                        "repo-op-1",
                        "running")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":151,\"method\":\"repositories.startRefresh\",\"params\":{\"instanceId\":\"primary\",\"force\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(151));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("repo-op-1"));
            Assert.That(result.GetProperty("operationStatus").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Repository refresh queued"));
        }

        [Test]
        public void RepositoriesRefreshStatusReturnsLatestOperationSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(
                    new MackanRepositoriesResult("primary", new MackanRepositorySummary[] { }),
                    statusRefreshResult: new MackanRepositoryRefreshResult(
                        "primary",
                        "updated",
                        42,
                        new[]
                        {
                            new MackanRepositorySummary(
                                "default",
                                "https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz",
                                0,
                                false,
                                ""),
                        },
                        new[]
                        {
                            new MackanOperationEvent("progress", "Done", 100, null, 0, 4096),
                        },
                        "repo-op-1",
                        "completed")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":152,\"method\":\"repositories.refreshStatus\",\"params\":{\"operationId\":\"repo-op-1\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(152));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("repo-op-1"));
            Assert.That(result.GetProperty("operationStatus").GetString(), Is.EqualTo("completed"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("updated"));
            Assert.That(result.GetProperty("compatibleModuleCount").GetInt32(), Is.EqualTo(42));
            Assert.That(result.GetProperty("repositories")[0].GetProperty("name").GetString(), Is.EqualTo("default"));
        }

        [Test]
        public void RepositoriesCancelRefreshReturnsCancellingOperationSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                repositoryProvider: new FakeRepositoryProvider(
                    new MackanRepositoriesResult("primary", new MackanRepositorySummary[] { }),
                    cancelRefreshResult: new MackanRepositoryRefreshResult(
                        "primary",
                        "running",
                        0,
                        Array.Empty<MackanRepositorySummary>(),
                        new[]
                        {
                            new MackanOperationEvent("message", "Cancellation requested", null, null, null, null),
                        },
                        "repo-op-1",
                        "cancelling")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":153,\"method\":\"repositories.cancelRefresh\",\"params\":{\"operationId\":\"repo-op-1\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(153));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("repo-op-1"));
            Assert.That(result.GetProperty("operationStatus").GetString(), Is.EqualTo("cancelling"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Cancellation requested"));
        }

        [Test]
        public void ModsResolveChangesReturnsPreview()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                changeSetProvider: new FakeChangeSetProvider(new MackanChangeSetResult(
                    "primary",
                    new[]
                    {
                        new MackanChangeSummary(
                            "ModuleManager",
                            "Module Manager",
                            "install",
                            null,
                            "4.2.3",
                            new[] { "User requested" },
                            true,
                            false),
                        new MackanChangeSummary(
                            "DependencyMod",
                            "Dependency Mod",
                            "install",
                            null,
                            "1.0.0",
                            new[] { "Depends on Module Manager" },
                            false,
                            true),
                    },
                    new MackanConflictSummary[] { },
                    new string[] { },
                    new[]
                    {
                        new MackanProviderChoice(
                            "VirtualDependency",
                            "Choose a provider for VirtualDependency",
                            "ModuleManager",
                            "Module Manager",
                            new[]
                            {
                                new MackanProviderOption("ProviderA", "Provider A", "1.0.0", "First provider"),
                                new MackanProviderOption("ProviderB", "Provider B", "2.0.0", "Second provider"),
                            }),
                    },
                    new[]
                    {
                        new MackanRecommendationChoice(
                            "recommendation",
                            "RecommendedMod",
                            "Recommended Mod",
                            "1.2.3",
                            "Useful companion",
                            new[] { "ModuleManager" },
                            true),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":17,\"method\":\"mods.resolveChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[\"OldMod\"],\"upgrade\":[\"UpgradeableMod\"],\"replace\":[\"DeprecatedMod\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var changes = result.GetProperty("changes");
            var providerChoices = result.GetProperty("providerChoices");
            var recommendationChoices = result.GetProperty("recommendationChoices");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(17));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(changes.GetArrayLength(), Is.EqualTo(2));
            Assert.That(changes[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(changes[0].GetProperty("action").GetString(), Is.EqualTo("install"));
            Assert.That(changes[0].GetProperty("toVersion").GetString(), Is.EqualTo("4.2.3"));
            Assert.That(changes[0].GetProperty("isUserRequested").GetBoolean(), Is.True);
            Assert.That(changes[1].GetProperty("isAuto").GetBoolean(), Is.True);
            Assert.That(providerChoices[0].GetProperty("requested").GetString(), Is.EqualTo("VirtualDependency"));
            Assert.That(providerChoices[0].GetProperty("options")[1].GetProperty("identifier").GetString(), Is.EqualTo("ProviderB"));
            Assert.That(recommendationChoices[0].GetProperty("kind").GetString(), Is.EqualTo("recommendation"));
            Assert.That(recommendationChoices[0].GetProperty("identifier").GetString(), Is.EqualTo("RecommendedMod"));
            Assert.That(recommendationChoices[0].GetProperty("dependents")[0].GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(recommendationChoices[0].GetProperty("isRecommendedDefault").GetBoolean(), Is.True);
        }

        [Test]
        public void ModsResolveChangesAcceptsProviderSelections()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                changeSetProvider: new FakeChangeSetProvider(
                    new MackanChangeSetResult(
                        "primary",
                        Array.Empty<MackanChangeSummary>(),
                        Array.Empty<MackanConflictSummary>(),
                        Array.Empty<string>()),
                    new[]
                    {
                        new MackanProviderSelection(
                            "VirtualDependency",
                            "ModuleManager",
                            "ProviderA"),
                    }));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":68,\"method\":\"mods.resolveChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"providerSelections\":[{\"requested\":\"VirtualDependency\",\"requesterIdentifier\":\"ModuleManager\",\"selectedIdentifier\":\"ProviderA\"}]}}"));

            Assert.That(document.RootElement.GetProperty("id").GetInt32(), Is.EqualTo(68));
            Assert.That(document.RootElement.GetProperty("result").GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
        }

        [Test]
        public void ModsResolveChangesAcceptsExactInstallVersions()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                changeSetProvider: new FakeChangeSetProvider(
                    new MackanChangeSetResult(
                        "primary",
                        Array.Empty<MackanChangeSummary>(),
                        Array.Empty<MackanConflictSummary>(),
                        Array.Empty<string>()),
                    expectedInstall: Array.Empty<string>(),
                    expectedRemove: Array.Empty<string>(),
                    expectedUpgrade: Array.Empty<string>(),
                    expectedReplace: Array.Empty<string>(),
                    expectedInstallVersions: new[]
                    {
                        new MackanModuleVersionSelection("ModuleManager", "4.2.3"),
                    }));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":69,\"method\":\"mods.resolveChanges\",\"params\":{\"instanceId\":\"primary\",\"installVersions\":[{\"identifier\":\"ModuleManager\",\"version\":\"4.2.3\"}]}}"));

            Assert.That(document.RootElement.GetProperty("id").GetInt32(), Is.EqualTo(69));
            Assert.That(document.RootElement.GetProperty("result").GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
        }

        [Test]
        public void OperationsApplyChangesReturnsOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-1",
                    "primary",
                    "completed",
                    new[]
                    {
                        new MackanChangeSummary(
                            "ModuleManager",
                            "Module Manager",
                            "install",
                            null,
                            "4.2.3",
                            new[] { "User requested" },
                            true,
                            false),
                    },
                    new[]
                    {
                        new MackanOperationEvent("message", "Installing Module Manager", null, "ModuleManager", null, null),
                        new MackanOperationEvent("downloadProgress", "Module Manager", 35, "ModuleManager", 1024, 2048),
                        new MackanOperationEvent("installProgress", "Module Manager", 100, "ModuleManager", 0, 2048),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":18,\"method\":\"operations.applyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[\"OldMod\"],\"upgrade\":[\"UpgradeableMod\"],\"replace\":[\"DeprecatedMod\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var changes = result.GetProperty("changes");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(18));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-1"));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(changes[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(events[0].GetProperty("kind").GetString(), Is.EqualTo("message"));
            Assert.That(events[0].GetProperty("message").GetString(), Is.EqualTo("Installing Module Manager"));
            Assert.That(events[1].GetProperty("kind").GetString(), Is.EqualTo("downloadProgress"));
            Assert.That(events[1].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(events[1].GetProperty("remainingBytes").GetInt64(), Is.EqualTo(1024));
            Assert.That(events[2].GetProperty("kind").GetString(), Is.EqualTo("installProgress"));
            Assert.That(events[2].GetProperty("percent").GetInt32(), Is.EqualTo(100));
        }

        [Test]
        public void OperationsApplyChangesForwardsSkipDownloadFailuresToProvider()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(
                    new MackanOperationResult(
                        "op-1",
                        "primary",
                        "completed",
                        new[]
                        {
                            new MackanChangeSummary(
                                "ModuleManager",
                                "Module Manager",
                                "install",
                                null,
                                "4.2.3",
                                new[] { "User requested" },
                                true,
                                false),
                        },
                        Array.Empty<MackanOperationEvent>(),
                        null),
                    expectedSkipDownloadFailures: true));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":20,\"method\":\"operations.applyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[\"OldMod\"],\"upgrade\":[\"UpgradeableMod\"],\"replace\":[\"DeprecatedMod\"],\"skipDownloadFailures\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(20));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-1"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(result.GetProperty("changes").GetArrayLength(), Is.EqualTo(1));
        }

        [Test]
        public void OperationsApplyChangesCanReturnTypedRegistryLockDetails()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-locked",
                    "primary",
                    "failed",
                    Array.Empty<MackanChangeSummary>(),
                    Array.Empty<MackanOperationEvent>(),
                    "Registry is locked",
                    new MackanErrorDetails(
                        "registryLock",
                        "/Games/KSP/CKAN/registry.locked",
                        "waitRetry"))));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":59,\"method\":\"operations.applyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[\"OldMod\"],\"upgrade\":[\"UpgradeableMod\"],\"replace\":[\"DeprecatedMod\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var errorDetails = result.GetProperty("errorDetails");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(59));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("failed"));
            Assert.That(result.GetProperty("error").GetString(), Is.EqualTo("Registry is locked"));
            Assert.That(errorDetails.GetProperty("kind").GetString(), Is.EqualTo("registryLock"));
            Assert.That(errorDetails.GetProperty("lockfilePath").GetString(), Is.EqualTo("/Games/KSP/CKAN/registry.locked"));
            Assert.That(errorDetails.GetProperty("suggestedAction").GetString(), Is.EqualTo("waitRetry"));
        }

        [Test]
        public void OperationsApplyChangesCanReturnTypedDownloadFailureDetails()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-downloads",
                    "primary",
                    "failed",
                    Array.Empty<MackanChangeSummary>(),
                    Array.Empty<MackanOperationEvent>(),
                    "Downloads failed",
                    MackanErrorDetails.DownloadFailureDetails(new[]
                    {
                        new MackanDownloadFailure(
                            "ModuleManager",
                            "Module Manager",
                            "4.2.3",
                            "Host returned 500",
                            new[] { "https://example.invalid/ModuleManager.zip" }),
                    }))));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":60,\"method\":\"operations.applyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[\"OldMod\"],\"upgrade\":[\"UpgradeableMod\"],\"replace\":[\"DeprecatedMod\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var errorDetails = result.GetProperty("errorDetails");
            var failures = errorDetails.GetProperty("downloadFailures");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(60));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("failed"));
            Assert.That(result.GetProperty("error").GetString(), Is.EqualTo("Downloads failed"));
            Assert.That(errorDetails.GetProperty("kind").GetString(), Is.EqualTo("downloadFailures"));
            Assert.That(errorDetails.GetProperty("suggestedAction").GetString(), Is.EqualTo("skipOrAbort"));
            Assert.That(failures.GetArrayLength(), Is.EqualTo(1));
            Assert.That(failures[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(failures[0].GetProperty("name").GetString(), Is.EqualTo("Module Manager"));
            Assert.That(failures[0].GetProperty("version").GetString(), Is.EqualTo("4.2.3"));
            Assert.That(failures[0].GetProperty("message").GetString(), Is.EqualTo("Host returned 500"));
            Assert.That(failures[0].GetProperty("urls")[0].GetString(), Is.EqualTo("https://example.invalid/ModuleManager.zip"));
        }

        [Test]
        public void OperationsStartApplyChangesReturnsRunningOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-running",
                    "primary",
                    "running",
                    Array.Empty<MackanChangeSummary>(),
                    new[]
                    {
                        new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":56,\"method\":\"operations.startApplyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[],\"upgrade\":[],\"replace\":[\"DeprecatedMod\"]}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(56));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Operation queued"));
        }

        [Test]
        public void OperationsStartApplyChangesForwardsSkipDownloadFailuresToProvider()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(
                    new MackanOperationResult(
                        "op-running",
                        "primary",
                        "running",
                        Array.Empty<MackanChangeSummary>(),
                        new[]
                        {
                            new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                        },
                        null),
                    expectedSkipDownloadFailures: true));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":57,\"method\":\"operations.startApplyChanges\",\"params\":{\"instanceId\":\"primary\",\"install\":[\"ModuleManager\"],\"remove\":[],\"upgrade\":[],\"replace\":[\"DeprecatedMod\"],\"skipDownloadFailures\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(57));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Operation queued"));
        }

        [Test]
        public void OperationsInstallCkanFilesReturnsOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-files",
                    "primary",
                    "completed",
                    new[]
                    {
                        new MackanChangeSummary(
                            "ModuleManager",
                            "Module Manager",
                            "install",
                            null,
                            "4.2.3",
                            new[] { "User requested" },
                            true,
                            false),
                    },
                    new[]
                    {
                        new MackanOperationEvent("message", "Installing Module Manager", null, "ModuleManager", null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":27,\"method\":\"operations.installCkanFiles\",\"params\":{\"instanceId\":\"primary\",\"filePaths\":[\"/tmp/ModuleManager.ckan\",\"/tmp/Other.ckan\"],\"providerSelections\":[{\"requested\":\"VirtualDependency\",\"requesterIdentifier\":\"ModuleManager\",\"selectedIdentifier\":\"ProviderA\"}],\"recommendationSelections\":[\"RecommendedMod\"],\"skipRecommendations\":true,\"allowIncompatibleCkanFiles\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var changes = result.GetProperty("changes");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(27));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-files"));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(changes[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(events[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
        }

        [Test]
        public void OperationsStartInstallCkanFilesReturnsRunningOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-file-running",
                    "primary",
                    "running",
                    Array.Empty<MackanChangeSummary>(),
                    new[]
                    {
                        new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":28,\"method\":\"operations.startInstallCkanFiles\",\"params\":{\"instanceId\":\"primary\",\"filePaths\":[\"/tmp/ModuleManager.ckan\",\"/tmp/Other.ckan\"],\"providerSelections\":[{\"requested\":\"VirtualDependency\",\"requesterIdentifier\":\"ModuleManager\",\"selectedIdentifier\":\"ProviderA\"}],\"recommendationSelections\":[\"RecommendedMod\"],\"skipRecommendations\":true,\"allowIncompatibleCkanFiles\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(28));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-file-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Operation queued"));
        }

        [Test]
        public void OperationsStartInstallCkanFilesForwardsSkipDownloadFailuresToProvider()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(
                    new MackanOperationResult(
                        "op-file-running",
                        "primary",
                        "running",
                        Array.Empty<MackanChangeSummary>(),
                        new[]
                        {
                            new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                        },
                        null),
                    expectedSkipDownloadFailures: true));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":31,\"method\":\"operations.startInstallCkanFiles\",\"params\":{\"instanceId\":\"primary\",\"filePaths\":[\"/tmp/ModuleManager.ckan\",\"/tmp/Other.ckan\"],\"providerSelections\":[{\"requested\":\"VirtualDependency\",\"requesterIdentifier\":\"ModuleManager\",\"selectedIdentifier\":\"ProviderA\"}],\"recommendationSelections\":[\"RecommendedMod\"],\"skipRecommendations\":true,\"allowIncompatibleCkanFiles\":true,\"skipDownloadFailures\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(31));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-file-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
        }

        [Test]
        public void OperationsImportDownloadsReturnsOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-import",
                    "primary",
                    "completed",
                    new[]
                    {
                        new MackanChangeSummary(
                            "DogeCoinPlugin",
                            "Dogecoin Core Plugin",
                            "install",
                            null,
                            "1.01",
                            new[] { "Imported download" },
                            true,
                            false),
                    },
                    new[]
                    {
                        new MackanOperationEvent("message", "Importing DogeCoinPlugin.zip", null, "DogeCoinPlugin", null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":29,\"method\":\"operations.importDownloads\",\"params\":{\"instanceId\":\"primary\",\"paths\":[\"/Downloads/DogeCoinPlugin.zip\",\"/Downloads/Other.zip\"],\"installImportedModules\":true,\"deleteImportedFiles\":false,\"previewBeforeInstall\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var changes = result.GetProperty("changes");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(29));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-import"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(changes[0].GetProperty("identifier").GetString(), Is.EqualTo("DogeCoinPlugin"));
            Assert.That(events[0].GetProperty("identifier").GetString(), Is.EqualTo("DogeCoinPlugin"));
        }

        [Test]
        public void OperationsStartImportDownloadsReturnsRunningOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-import-running",
                    "primary",
                    "running",
                    Array.Empty<MackanChangeSummary>(),
                    new[]
                    {
                        new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":30,\"method\":\"operations.startImportDownloads\",\"params\":{\"instanceId\":\"primary\",\"paths\":[\"/Downloads/DogeCoinPlugin.zip\",\"/Downloads/Other.zip\"],\"installImportedModules\":true,\"deleteImportedFiles\":false,\"previewBeforeInstall\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(30));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-import-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Operation queued"));
        }

        [Test]
        public void OperationsStartImportDownloadsForwardsSkipDownloadFailuresToProvider()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(
                    new MackanOperationResult(
                        "op-import-running",
                        "primary",
                        "running",
                        Array.Empty<MackanChangeSummary>(),
                        new[]
                        {
                            new MackanOperationEvent("message", "Operation queued", null, null, null, null),
                        },
                        null),
                    expectedSkipDownloadFailures: true));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":32,\"method\":\"operations.startImportDownloads\",\"params\":{\"instanceId\":\"primary\",\"paths\":[\"/Downloads/DogeCoinPlugin.zip\",\"/Downloads/Other.zip\"],\"installImportedModules\":true,\"deleteImportedFiles\":false,\"previewBeforeInstall\":true,\"skipDownloadFailures\":true}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(32));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-import-running"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
        }

        [Test]
        public void OperationsStatusReturnsOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-1",
                    "primary",
                    "running",
                    new MackanChangeSummary[] { },
                    new[]
                    {
                        new MackanOperationEvent("downloadProgress", "Module Manager", 35, "ModuleManager", 1024, 2048),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":19,\"method\":\"operations.status\",\"params\":{\"operationId\":\"op-1\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(19));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-1"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("running"));
            Assert.That(events[0].GetProperty("kind").GetString(), Is.EqualTo("downloadProgress"));
            Assert.That(events[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(events[0].GetProperty("remainingBytes").GetInt64(), Is.EqualTo(1024));
            Assert.That(events[0].GetProperty("totalBytes").GetInt64(), Is.EqualTo(2048));
        }

        [Test]
        public void OperationsCancelReturnsCurrentOperationResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                operationProvider: new FakeOperationProvider(new MackanOperationResult(
                    "op-1",
                    "primary",
                    "cancelling",
                    Array.Empty<MackanChangeSummary>(),
                    new[]
                    {
                        new MackanOperationEvent("message", "Cancellation requested", null, null, null, null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":57,\"method\":\"operations.cancel\",\"params\":{\"operationId\":\"op-1\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(57));
            Assert.That(result.GetProperty("operationId").GetString(), Is.EqualTo("op-1"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("cancelling"));
            Assert.That(result.GetProperty("events")[0].GetProperty("message").GetString(), Is.EqualTo("Cancellation requested"));
        }

        [Test]
        public void ExportsModListReturnsExportedContents()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                exportProvider: new FakeExportProvider(new MackanExportModListResult(
                    "primary",
                    "markdown",
                    "Primary KSP-mods.md",
                    "text/markdown",
                    "- **Module Manager** `ModuleManager 4.2.3`")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":28,\"method\":\"exports.modList\",\"params\":{\"instanceId\":\"primary\",\"format\":\"markdown\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(28));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("format").GetString(), Is.EqualTo("markdown"));
            Assert.That(result.GetProperty("suggestedFileName").GetString(), Is.EqualTo("Primary KSP-mods.md"));
            Assert.That(result.GetProperty("contentType").GetString(), Is.EqualTo("text/markdown"));
            Assert.That(result.GetProperty("contents").GetString(), Does.Contain("Module Manager"));
        }

        [Test]
        public void ExportsModpackReturnsCkanContents()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                exportProvider: new FakeExportProvider(modpackResult: new MackanExportModpackResult(
                    "primary",
                    "MyModpack",
                    "MyModpack.ckan",
                    "application/json",
                    "{\"identifier\":\"MyModpack\",\"depends\":[{\"name\":\"ModuleManager\"}]}")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":29,\"method\":\"exports.modpack\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"MyModpack\",\"name\":\"My Modpack\",\"abstract\":\"Essential mods\",\"author\":\"Jeb Kerman\",\"version\":\"v1\",\"license\":\"MIT\",\"gameVersionMin\":\"1.12\",\"gameVersionMax\":\"1.12.5\",\"includeVersions\":false,\"includeOptionalRelationships\":false}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(29));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("identifier").GetString(), Is.EqualTo("MyModpack"));
            Assert.That(result.GetProperty("suggestedFileName").GetString(), Is.EqualTo("MyModpack.ckan"));
            Assert.That(result.GetProperty("contentType").GetString(), Is.EqualTo("application/json"));
            Assert.That(result.GetProperty("contents").GetString(), Does.Contain("ModuleManager"));
        }

        [Test]
        public void ExportsModpackAcceptsRelationshipAssignments()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                exportProvider: new FakeExportProvider(
                    modpackResult: new MackanExportModpackResult(
                        "primary",
                        "MyModpack",
                        "MyModpack.ckan",
                        "application/json",
                        "{\"identifier\":\"MyModpack\",\"depends\":[{\"name\":\"ModuleManager\"}]}"),
                    expectedRelationshipAssignments: new[]
                    {
                        new MackanModpackRelationshipAssignment("ModuleManager", "depends"),
                        new MackanModpackRelationshipAssignment("Scatterer", "recommends"),
                        new MackanModpackRelationshipAssignment("UnusedVisualPack", "ignore"),
                    }));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":61,\"method\":\"exports.modpack\",\"params\":{\"instanceId\":\"primary\",\"identifier\":\"MyModpack\",\"name\":\"My Modpack\",\"abstract\":\"Essential mods\",\"author\":\"Jeb Kerman\",\"version\":\"v1\",\"license\":\"MIT\",\"gameVersionMin\":\"1.12\",\"gameVersionMax\":\"1.12.5\",\"includeVersions\":false,\"includeOptionalRelationships\":false,\"relationshipAssignments\":[{\"identifier\":\"ModuleManager\",\"kind\":\"depends\"},{\"identifier\":\"Scatterer\",\"kind\":\"recommends\"},{\"identifier\":\"UnusedVisualPack\",\"kind\":\"ignore\"}]}}"));

            Assert.That(document.RootElement.GetProperty("id").GetInt32(), Is.EqualTo(61));
            Assert.That(document.RootElement.GetProperty("result").GetProperty("identifier").GetString(), Is.EqualTo("MyModpack"));
        }

        [Test]
        public void MaintenanceScanReturnsScanResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(new MackanMaintenanceScanResult(
                    "primary",
                    true,
                    2,
                    1)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":30,\"method\":\"maintenance.scan\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(30));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("changed").GetBoolean(), Is.True);
            Assert.That(result.GetProperty("detectedDllCount").GetInt32(), Is.EqualTo(2));
            Assert.That(result.GetProperty("detectedDlcCount").GetInt32(), Is.EqualTo(1));
        }

        [Test]
        public void MaintenanceUnmanagedFilesReturnsDetectedDllsAndDlcs()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(unmanagedResult: new MackanUnmanagedFilesResult(
                    "primary",
                    true,
                    new[]
                    {
                        new MackanUnmanagedFileSummary(
                            "ManualPlugin",
                            "dll",
                            null,
                            "GameData/Manual/ManualPlugin.dll"),
                        new MackanUnmanagedFileSummary(
                            "MakingHistory-DLC",
                            "dlc",
                            "1.12.1 (unmanaged)",
                            null),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":31,\"method\":\"maintenance.unmanagedFiles\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var files = result.GetProperty("files");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(31));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("changed").GetBoolean(), Is.True);
            Assert.That(files.GetArrayLength(), Is.EqualTo(2));
            Assert.That(files[0].GetProperty("identifier").GetString(), Is.EqualTo("ManualPlugin"));
            Assert.That(files[0].GetProperty("kind").GetString(), Is.EqualTo("dll"));
            Assert.That(files[0].GetProperty("path").GetString(), Is.EqualTo("GameData/Manual/ManualPlugin.dll"));
            Assert.That(files[1].GetProperty("identifier").GetString(), Is.EqualTo("MakingHistory-DLC"));
            Assert.That(files[1].GetProperty("kind").GetString(), Is.EqualTo("dlc"));
            Assert.That(files[1].GetProperty("version").GetString(), Is.EqualTo("1.12.1 (unmanaged)"));
        }

        [Test]
        public void MaintenanceHistoryReturnsInstallationSnapshotSummaries()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(historyResult: new MackanInstallationHistoryResult(
                    "primary",
                    new[]
                    {
                        new MackanInstallationHistoryEntrySummary(
                            "installed-Primary_KSP-2026-05-31_10-00-00.ckan",
                            "2026-05-31T10:00:00.0000000Z",
                            1),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":32,\"method\":\"maintenance.history\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var entries = result.GetProperty("entries");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(32));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(entries.GetArrayLength(), Is.EqualTo(1));
            Assert.That(entries[0].GetProperty("fileName").GetString(), Is.EqualTo("installed-Primary_KSP-2026-05-31_10-00-00.ckan"));
            Assert.That(entries[0].GetProperty("savedAt").GetString(), Is.EqualTo("2026-05-31T10:00:00.0000000Z"));
            Assert.That(entries[0].GetProperty("moduleCount").GetInt32(), Is.EqualTo(1));
            Assert.That(entries[0].TryGetProperty("modules", out _), Is.False);
        }

        [Test]
        public void MaintenanceHistoryEntryReturnsSelectedSnapshotModules()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(historyEntry: new MackanInstallationHistoryEntry(
                    "installed-Primary_KSP-2026-05-31_10-00-00.ckan",
                    "2026-05-31T10:00:00.0000000Z",
                    new[]
                    {
                        new MackanInstallationHistoryModule(
                            "ModuleManager",
                            "Module Manager",
                            "4.2.3",
                            "sarbian",
                            "Core patch manager",
                            false,
                            true),
                    })));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":33,\"method\":\"maintenance.historyEntry\",\"params\":{\"instanceId\":\"primary\",\"fileName\":\"installed-Primary_KSP-2026-05-31_10-00-00.ckan\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var modules = result.GetProperty("modules");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(33));
            Assert.That(result.GetProperty("fileName").GetString(), Is.EqualTo("installed-Primary_KSP-2026-05-31_10-00-00.ckan"));
            Assert.That(result.GetProperty("savedAt").GetString(), Is.EqualTo("2026-05-31T10:00:00.0000000Z"));
            Assert.That(modules.GetArrayLength(), Is.EqualTo(1));
            Assert.That(modules[0].GetProperty("identifier").GetString(), Is.EqualTo("ModuleManager"));
            Assert.That(modules[0].GetProperty("name").GetString(), Is.EqualTo("Module Manager"));
            Assert.That(modules[0].GetProperty("version").GetString(), Is.EqualTo("4.2.3"));
            Assert.That(modules[0].GetProperty("author").GetString(), Is.EqualTo("sarbian"));
            Assert.That(modules[0].GetProperty("abstract").GetString(), Is.EqualTo("Core patch manager"));
            Assert.That(modules[0].GetProperty("isInstalled").GetBoolean(), Is.False);
            Assert.That(modules[0].GetProperty("isAvailable").GetBoolean(), Is.True);
        }

        [Test]
        public void MaintenancePlayTimeReturnsKnownInstanceHours()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(playTimeResult: new MackanPlayTimeResult(
                    new[]
                    {
                        new MackanPlayTimeEntry(
                            "primary",
                            "Primary KSP",
                            "/Games/KSP",
                            12.5,
                            "12.5"),
                        new MackanPlayTimeEntry(
                            "secondary",
                            "Secondary KSP",
                            "/Games/KSP-Secondary",
                            0.0,
                            "0.0"),
                    },
                    12.5,
                    "12.5")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":33,\"method\":\"maintenance.playTime\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var entries = result.GetProperty("entries");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(33));
            Assert.That(result.GetProperty("totalHours").GetDouble(), Is.EqualTo(12.5));
            Assert.That(result.GetProperty("totalDisplay").GetString(), Is.EqualTo("12.5"));
            Assert.That(entries.GetArrayLength(), Is.EqualTo(2));
            Assert.That(entries[0].GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(entries[0].GetProperty("name").GetString(), Is.EqualTo("Primary KSP"));
            Assert.That(entries[0].GetProperty("path").GetString(), Is.EqualTo("/Games/KSP"));
            Assert.That(entries[0].GetProperty("hours").GetDouble(), Is.EqualTo(12.5));
            Assert.That(entries[0].GetProperty("display").GetString(), Is.EqualTo("12.5"));
        }

        [Test]
        public void MaintenanceUpdatePlayTimeReturnsUpdatedHours()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(playTimeResult: new MackanPlayTimeResult(
                    new[]
                    {
                        new MackanPlayTimeEntry(
                            "primary",
                            "Primary KSP",
                            "/Games/KSP",
                            14.25,
                            "14.3"),
                    },
                    14.25,
                    "14.3")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":34,\"method\":\"maintenance.updatePlayTime\",\"params\":{\"instanceId\":\"primary\",\"hours\":14.25}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var entries = result.GetProperty("entries");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(34));
            Assert.That(result.GetProperty("totalHours").GetDouble(), Is.EqualTo(14.25));
            Assert.That(result.GetProperty("totalDisplay").GetString(), Is.EqualTo("14.3"));
            Assert.That(entries.GetArrayLength(), Is.EqualTo(1));
            Assert.That(entries[0].GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(entries[0].GetProperty("hours").GetDouble(), Is.EqualTo(14.25));
            Assert.That(entries[0].GetProperty("display").GetString(), Is.EqualTo("14.3"));
        }

        [Test]
        public void MaintenanceDownloadStatisticsReturnsHostByteTotals()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(downloadStatisticsResult: new MackanDownloadStatisticsResult(
                    "primary",
                    new[]
                    {
                        new MackanDownloadStatisticsHost(
                            "spacedock.info",
                            1536,
                            "1.5 KiB"),
                        new MackanDownloadStatisticsHost(
                            "archive.org",
                            512,
                            "512 bytes"),
                    },
                    2048,
                    "2 KiB")));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":35,\"method\":\"maintenance.downloadStatistics\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var hosts = result.GetProperty("hosts");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(35));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("totalBytes").GetInt64(), Is.EqualTo(2048));
            Assert.That(result.GetProperty("totalDisplay").GetString(), Is.EqualTo("2 KiB"));
            Assert.That(hosts.GetArrayLength(), Is.EqualTo(2));
            Assert.That(hosts[0].GetProperty("host").GetString(), Is.EqualTo("spacedock.info"));
            Assert.That(hosts[0].GetProperty("bytes").GetInt64(), Is.EqualTo(1536));
            Assert.That(hosts[0].GetProperty("display").GetString(), Is.EqualTo("1.5 KiB"));
            Assert.That(hosts[1].GetProperty("host").GetString(), Is.EqualTo("archive.org"));
            Assert.That(hosts[1].GetProperty("bytes").GetInt64(), Is.EqualTo(512));
        }

        [Test]
        public void MaintenanceCacheInfoReturnsDownloadCacheSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(cacheInfoResult: new MackanCacheInfoResult(
                    "/Users/test/Library/Caches/CKAN/downloads",
                    7,
                    4096,
                    "4 KiB",
                    8192,
                    "8 KiB",
                    2048,
                    "2 KiB",
                    true)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":36,\"method\":\"maintenance.cacheInfo\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(36));
            Assert.That(result.GetProperty("path").GetString(), Is.EqualTo("/Users/test/Library/Caches/CKAN/downloads"));
            Assert.That(result.GetProperty("fileCount").GetInt32(), Is.EqualTo(7));
            Assert.That(result.GetProperty("bytes").GetInt64(), Is.EqualTo(4096));
            Assert.That(result.GetProperty("display").GetString(), Is.EqualTo("4 KiB"));
            Assert.That(result.GetProperty("freeBytes").GetInt64(), Is.EqualTo(8192));
            Assert.That(result.GetProperty("freeDisplay").GetString(), Is.EqualTo("8 KiB"));
            Assert.That(result.GetProperty("limitBytes").GetInt64(), Is.EqualTo(2048));
            Assert.That(result.GetProperty("limitDisplay").GetString(), Is.EqualTo("2 KiB"));
            Assert.That(result.GetProperty("isOverLimit").GetBoolean(), Is.True);
        }

        [Test]
        public void MaintenanceClearCacheReturnsPurgeSummary()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(cachePurgeResult: new MackanCachePurgeResult(
                    "all",
                    7,
                    4096,
                    "4 KiB",
                    new MackanCacheInfoResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        0,
                        0,
                        "0 bytes",
                        8192,
                        "8 KiB",
                        null,
                        null,
                        false))));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":37,\"method\":\"maintenance.clearCache\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(37));
            Assert.That(result.GetProperty("mode").GetString(), Is.EqualTo("all"));
            Assert.That(result.GetProperty("purgedFileCount").GetInt32(), Is.EqualTo(7));
            Assert.That(result.GetProperty("purgedBytes").GetInt64(), Is.EqualTo(4096));
            Assert.That(result.GetProperty("purgedDisplay").GetString(), Is.EqualTo("4 KiB"));
            Assert.That(result.GetProperty("cache").GetProperty("fileCount").GetInt32(), Is.EqualTo(0));
        }

        [Test]
        public void MaintenancePurgeCacheToLimitUsesRequestedInstance()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(cachePurgeResult: new MackanCachePurgeResult(
                    "limit",
                    2,
                    2048,
                    "2 KiB",
                    new MackanCacheInfoResult(
                        "/Users/test/Library/Caches/CKAN/downloads",
                        5,
                        2048,
                        "2 KiB",
                        null,
                        null,
                        2048,
                        "2 KiB",
                        false))));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":38,\"method\":\"maintenance.purgeCacheToLimit\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(38));
            Assert.That(result.GetProperty("mode").GetString(), Is.EqualTo("limit"));
            Assert.That(result.GetProperty("purgedFileCount").GetInt32(), Is.EqualTo(2));
            Assert.That(result.GetProperty("purgedBytes").GetInt64(), Is.EqualTo(2048));
            Assert.That(result.GetProperty("cache").GetProperty("isOverLimit").GetBoolean(), Is.False);
        }

        [Test]
        public void MaintenanceDeduplicateReturnsCapturedEvents()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(deduplicateResult: new MackanDeduplicateResult(
                    "completed",
                    new[]
                    {
                        new MackanOperationEvent(
                            "message",
                            "Scanning for duplicate installed files...",
                            null,
                            null,
                            null,
                            null),
                        new MackanOperationEvent(
                            "progress",
                            "Deduplicated 2 copies of GameData/Example/model.mu",
                            100,
                            null,
                            null,
                            null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":39,\"method\":\"maintenance.deduplicate\"}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(39));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(events.GetArrayLength(), Is.EqualTo(2));
            Assert.That(events[0].GetProperty("kind").GetString(), Is.EqualTo("message"));
            Assert.That(events[0].GetProperty("message").GetString(), Is.EqualTo("Scanning for duplicate installed files..."));
            Assert.That(events[1].GetProperty("kind").GetString(), Is.EqualTo("progress"));
            Assert.That(events[1].GetProperty("percent").GetInt32(), Is.EqualTo(100));
            Assert.That(result.GetProperty("error").ValueKind, Is.EqualTo(JsonValueKind.Null));
        }

        [Test]
        public void MaintenanceRepairRegistryUsesRequestedInstanceAndReturnsCapturedEvents()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(repairRegistryResult: new MackanRepairRegistryResult(
                    "primary",
                    "completed",
                    new[]
                    {
                        new MackanOperationEvent(
                            "message",
                            "Repairing CKAN registry...",
                            null,
                            null,
                            null,
                            null),
                        new MackanOperationEvent(
                            "message",
                            "Registry repairs attempted. Hope it helped.",
                            null,
                            null,
                            null,
                            null),
                    },
                    null)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":40,\"method\":\"maintenance.repairRegistry\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");
            var events = result.GetProperty("events");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(40));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("completed"));
            Assert.That(events.GetArrayLength(), Is.EqualTo(2));
            Assert.That(events[0].GetProperty("kind").GetString(), Is.EqualTo("message"));
            Assert.That(events[0].GetProperty("message").GetString(), Is.EqualTo("Repairing CKAN registry..."));
            Assert.That(events[1].GetProperty("message").GetString(), Is.EqualTo("Registry repairs attempted. Hope it helped."));
            Assert.That(result.GetProperty("error").ValueKind, Is.EqualTo(JsonValueKind.Null));
        }

        [Test]
        public void MaintenanceRemoveRegistryLockReturnsExplicitRemovalResult()
        {
            var dispatcher = new MackanServiceDispatcher(
                () => "1.2.3-test",
                maintenanceProvider: new FakeMaintenanceProvider(registryLockRemovalResult: new MackanRegistryLockRemovalResult(
                    "primary",
                    "/Games/KSP/CKAN/registry.locked",
                    "removed",
                    true)));

            using var document = JsonDocument.Parse(
                dispatcher.Handle("{\"jsonrpc\":\"2.0\",\"id\":60,\"method\":\"maintenance.removeRegistryLock\",\"params\":{\"instanceId\":\"primary\"}}"));
            var root = document.RootElement;
            var result = root.GetProperty("result");

            Assert.That(root.GetProperty("id").GetInt32(), Is.EqualTo(60));
            Assert.That(result.GetProperty("instanceId").GetString(), Is.EqualTo("primary"));
            Assert.That(result.GetProperty("lockfilePath").GetString(), Is.EqualTo("/Games/KSP/CKAN/registry.locked"));
            Assert.That(result.GetProperty("status").GetString(), Is.EqualTo("removed"));
            Assert.That(result.GetProperty("removed").GetBoolean(), Is.True);
        }

        private sealed class FakeUpdateProvider : IMackanUpdateProvider
        {
            public FakeUpdateProvider(MackanUpdateCheckResult result)
            {
                this.result = result;
            }

            public MackanUpdateCheckResult CheckForUpdates(bool? useDevBuilds)
                => result;

            private readonly MackanUpdateCheckResult result;
        }

        private sealed class FakeCkanUpdate : CkanUpdate
        {
            public FakeCkanUpdate(CkanModuleVersion version, params string[] targetUrls)
            {
                Version = version;
                ReleaseNotes = "Fake release notes";
                targets = targetUrls
                    .Select(targetUrl => new NetAsyncDownloader.DownloadTargetFile(new Uri(targetUrl)))
                    .Cast<NetAsyncDownloader.DownloadTarget>()
                    .ToArray();
            }

            public override IReadOnlyCollection<NetAsyncDownloader.DownloadTarget> Targets
                => targets;

            private readonly IReadOnlyCollection<NetAsyncDownloader.DownloadTarget> targets;
        }

        private sealed class FakeInstanceProvider : IMackanInstanceProvider
        {
            public FakeInstanceProvider(MackanInstancesResult result)
            {
                this.result = result;
            }

            public MackanInstancesResult ListInstances() => result;

            public MackanInstancesResult AddInstance(string path, string name)
            {
                Assert.That(path, Is.EqualTo("/Games/KSP-New"));
                Assert.That(name, Is.EqualTo("New KSP"));
                return result;
            }

            public MackanCloneOptionsResult CloneOptions(string sourceInstanceId)
            {
                Assert.That(sourceInstanceId, Is.EqualTo("primary"));
                return new MackanCloneOptionsResult(
                    sourceInstanceId,
                    new[]
                    {
                        "saves",
                        "Screenshots",
                    });
            }

            public MackanInstancesResult CloneInstance(
                string sourceInstanceId,
                string newName,
                string newPath,
                bool shareStock,
                IReadOnlyList<string>? leaveEmptyPaths)
            {
                Assert.That(sourceInstanceId, Is.EqualTo("primary"));
                Assert.That(newName, Is.EqualTo("Cloned KSP"));
                Assert.That(newPath, Is.EqualTo("/Games/KSP-Clone"));
                Assert.That(shareStock, Is.False);
                Assert.That(leaveEmptyPaths, Is.EqualTo(new[]
                {
                    "saves",
                    "Screenshots",
                }));
                return result;
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
                Assert.That(name, Is.EqualTo("Fake KSP"));
                Assert.That(path, Is.EqualTo("/Games/KSP-Fake"));
                Assert.That(version, Is.EqualTo("1.12.5"));
                Assert.That(gameId, Is.EqualTo("KSP"));
                Assert.That(makingHistoryVersion, Is.EqualTo("1.12.1"));
                Assert.That(breakingGroundVersion, Is.EqualTo("1.7.1"));
                Assert.That(setDefault, Is.True);
                return result;
            }

            public MackanInstancesResult SetDefaultInstance(string instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("secondary"));
                return result;
            }

            public MackanInstancesResult RemoveInstance(string instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("secondary"));
                return result;
            }

            public MackanInstancesResult RenameInstance(string instanceId, string newName)
            {
                Assert.That(instanceId, Is.EqualTo("secondary"));
                Assert.That(newName, Is.EqualTo("renamed"));
                return result;
            }

            public MackanLaunchOptionsResult LaunchOptions(string instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return new MackanLaunchOptionsResult(
                    instanceId,
                    new[]
                    {
                        "./KSP.app/Contents/MacOS/KSP",
                        "steam://run/220200",
                    },
                new[]
                {
                    "./KSP.app/Contents/MacOS/KSP",
                },
                new[]
                {
                    new MackanLaunchIncompatibleModule(
                        "OldMod",
                        "Old Mod",
                        "0.9.0",
                        "KSP 1.8"),
                });
            }

            public MackanLaunchOptionsResult UpdateLaunchOptions(string instanceId, IReadOnlyList<string> commandLines)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(commandLines, Is.EqualTo(new[]
                {
                    "./KSP.app/Contents/MacOS/KSP -popupwindow",
                    "steam://run/220200",
                }));
                return new MackanLaunchOptionsResult(
                    instanceId,
                    commandLines,
                new[]
                {
                    "./KSP.app/Contents/MacOS/KSP",
                },
                System.Array.Empty<MackanLaunchIncompatibleModule>());
            }

            public MackanLaunchResult LaunchGame(string instanceId, string? commandLine, bool suppressIncompatibleWarnings)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(commandLine, Is.EqualTo("./KSP.app/Contents/MacOS/KSP -popupwindow"));
                if (suppressIncompatibleWarnings)
                {
                    Assert.That(suppressIncompatibleWarnings, Is.True);
                }
                return new MackanLaunchResult(instanceId, commandLine!, "started", 12345);
            }

            private readonly MackanInstancesResult result;
        }

        private sealed class FailingLaunchInstanceProvider : IMackanInstanceProvider
        {
            public FailingLaunchInstanceProvider(IMackanInstanceProvider innerProvider)
            {
                this.innerProvider = innerProvider;
            }

            public MackanInstancesResult ListInstances()
                => innerProvider.ListInstances();

            public MackanInstancesResult AddInstance(string path, string name)
                => innerProvider.AddInstance(path, name);

            public MackanCloneOptionsResult CloneOptions(string sourceInstanceId)
                => innerProvider.CloneOptions(sourceInstanceId);

            public MackanInstancesResult CloneInstance(
                string sourceInstanceId,
                string newName,
                string newPath,
                bool shareStock,
                IReadOnlyList<string>? leaveEmptyPaths)
                => innerProvider.CloneInstance(sourceInstanceId, newName, newPath, shareStock, leaveEmptyPaths);

            public MackanInstancesResult FakeInstance(
                string name,
                string path,
                string version,
                string gameId,
                string? makingHistoryVersion,
                string? breakingGroundVersion,
                bool setDefault)
                => innerProvider.FakeInstance(
                    name,
                    path,
                    version,
                    gameId,
                    makingHistoryVersion,
                    breakingGroundVersion,
                    setDefault);

            public MackanInstancesResult SetDefaultInstance(string instanceId)
                => innerProvider.SetDefaultInstance(instanceId);

            public MackanInstancesResult RemoveInstance(string instanceId)
                => innerProvider.RemoveInstance(instanceId);

            public MackanInstancesResult RenameInstance(string instanceId, string newName)
                => innerProvider.RenameInstance(instanceId, newName);

            public MackanLaunchOptionsResult LaunchOptions(string instanceId)
                => innerProvider.LaunchOptions(instanceId);

            public MackanLaunchOptionsResult UpdateLaunchOptions(string instanceId, IReadOnlyList<string> commandLines)
                => innerProvider.UpdateLaunchOptions(instanceId, commandLines);

            public MackanLaunchResult LaunchGame(string instanceId, string? commandLine, bool suppressIncompatibleWarnings)
                => throw new MackanLaunchFailureException(
                    commandLine!,
                    $"Failed to launch game with command '{commandLine}'.");

            private readonly IMackanInstanceProvider innerProvider;
        }

        private sealed class FakeModuleProvider : IMackanModuleProvider
        {
            public FakeModuleProvider(MackanModulesResult result, MackanModuleDetailsResult? details = null)
            {
                this.result = result;
                this.details = details;
            }

            public MackanModulesResult ListModules(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return result;
            }

            public MackanModuleListOperationResult StartListModules(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return new MackanModuleListOperationResult(
                    "module-op-1",
                    "primary",
                    "running",
                    Array.Empty<MackanModuleSummary>(),
                    new[]
                    {
                        new MackanOperationEvent(
                            "progress",
                            "Preparing 100 of 350 mods",
                            40,
                            "ModuleManager",
                            null,
                            null,
                            100,
                            350),
                    });
            }

            public MackanModuleListOperationResult GetListStatus(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("module-op-1"));
                return new MackanModuleListOperationResult(
                    operationId,
                    "primary",
                    "completed",
                    result.Modules,
                    new[]
                    {
                        new MackanOperationEvent(
                            "progress",
                            "Loaded 1 mods",
                            100,
                            null,
                            null,
                            null,
                            1,
                            1),
                    });
            }

            public MackanModuleListOperationResult CancelList(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("module-op-1"));
                return new MackanModuleListOperationResult(
                    operationId,
                    "primary",
                    "cancelled",
                    Array.Empty<MackanModuleSummary>());
            }

            public MackanModuleDetailsResult GetModuleDetails(string? instanceId, string identifier)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(identifier, Is.EqualTo("ModuleManager"));
                return details!;
            }

            public MackanModulesResult SetAutoInstalled(string? instanceId, string identifier, bool isAutoInstalled)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(identifier, Is.EqualTo("ModuleManager"));
                Assert.That(isAutoInstalled, Is.True);
                return result;
            }

            private readonly MackanModulesResult result;
            private readonly MackanModuleDetailsResult? details;
        }

        private sealed class FakeLabelProvider : IMackanLabelProvider
        {
            public FakeLabelProvider(MackanLabelsResult result)
            {
                this.result = result;
            }

            public MackanLabelsResult ListLabels(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return result;
            }

            public MackanLabelsResult ToggleModule(string? instanceId, string labelName, string identifier)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(labelName, Is.EqualTo("Favourites"));
                Assert.That(identifier, Is.EqualTo("Scatterer"));
                return result;
            }

            public MackanLabelsResult UpsertLabel(
                string? instanceId,
                string? originalName,
                string? originalInstanceName,
                MackanModuleLabelEdit label)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(originalName, Is.Null);
                Assert.That(originalInstanceName, Is.Null);
                Assert.That(label.Name, Is.EqualTo("Watch"));
                Assert.That(label.InstanceName, Is.EqualTo("primary"));
                Assert.That(label.ColorHex, Is.EqualTo("#336699"));
                Assert.That(label.Hide, Is.True);
                Assert.That(label.NotifyOnChange, Is.True);
                Assert.That(label.RemoveOnChange, Is.False);
                Assert.That(label.AlertOnInstall, Is.True);
                Assert.That(label.RemoveOnInstall, Is.False);
                Assert.That(label.HoldVersion, Is.True);
                Assert.That(label.IgnoreMissingFiles, Is.True);
                return result;
            }

            public MackanLabelsResult DeleteLabel(string? instanceId, string name, string? instanceName)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(name, Is.EqualTo("Watch"));
                Assert.That(instanceName, Is.EqualTo("primary"));
                return result;
            }

            private readonly MackanLabelsResult result;
        }

        private sealed class FakeRepositoryProvider : IMackanRepositoryProvider
        {
            public FakeRepositoryProvider(
                MackanRepositoriesResult result,
                MackanRepositoryRefreshResult? refreshResult = null,
                MackanRepositoryRefreshResult? startRefreshResult = null,
                MackanRepositoryRefreshResult? statusRefreshResult = null,
                MackanRepositoryRefreshResult? cancelRefreshResult = null,
                MackanRepositoriesResult? availableResult = null)
            {
                this.result = result;
                this.refreshResult = refreshResult;
                this.startRefreshResult = startRefreshResult;
                this.statusRefreshResult = statusRefreshResult;
                this.cancelRefreshResult = cancelRefreshResult;
                this.availableResult = availableResult;
            }

            public MackanRepositoriesResult ListRepositories(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return result;
            }

            public MackanRepositoriesResult AddRepository(string? instanceId, string name, string url)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(name, Is.EqualTo("newrepo"));
                Assert.That(url, Is.EqualTo("https://example.invalid/newrepo.tar.gz"));
                return result;
            }

            public MackanRepositoriesResult RemoveRepository(string? instanceId, string name)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(name, Is.EqualTo("mirror"));
                return result;
            }

            public MackanRepositoriesResult SetRepositoryPriority(string? instanceId, string name, int priority)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(name, Is.EqualTo("mirror"));
                Assert.That(priority, Is.EqualTo(0));
                return result;
            }

            public MackanRepositoryRefreshResult RefreshRepositories(string? instanceId, bool force)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(force, Is.True);
                return refreshResult!;
            }

            public MackanRepositoryRefreshResult StartRefreshRepositories(string? instanceId, bool force)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(force, Is.True);
                return startRefreshResult!;
            }

            public MackanRepositoryRefreshResult GetRefreshStatus(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("repo-op-1"));
                return statusRefreshResult!;
            }

            public MackanRepositoryRefreshResult CancelRefresh(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("repo-op-1"));
                return cancelRefreshResult!;
            }

            public MackanRepositoriesResult ListAvailableRepositories(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return availableResult!;
            }

            private readonly MackanRepositoriesResult result;
            private readonly MackanRepositoryRefreshResult? refreshResult;
            private readonly MackanRepositoryRefreshResult? startRefreshResult;
            private readonly MackanRepositoryRefreshResult? statusRefreshResult;
            private readonly MackanRepositoryRefreshResult? cancelRefreshResult;
            private readonly MackanRepositoriesResult? availableResult;
        }

        private sealed class FakeChangeSetProvider : IMackanChangeSetProvider
        {
            public FakeChangeSetProvider(
                MackanChangeSetResult result,
                MackanProviderSelection[]? expectedProviderSelections = null,
                string[]? expectedInstall = null,
                string[]? expectedRemove = null,
                string[]? expectedUpgrade = null,
                string[]? expectedReplace = null,
                MackanModuleVersionSelection[]? expectedInstallVersions = null)
            {
                this.result = result;
                this.expectedProviderSelections = expectedProviderSelections ?? Array.Empty<MackanProviderSelection>();
                this.expectedInstall = expectedInstall ?? new[] { "ModuleManager" };
                this.expectedRemove = expectedRemove ?? (this.expectedProviderSelections.Length == 0
                    ? new[] { "OldMod" }
                    : Array.Empty<string>());
                this.expectedUpgrade = expectedUpgrade ?? (this.expectedProviderSelections.Length == 0
                    ? new[] { "UpgradeableMod" }
                    : Array.Empty<string>());
                this.expectedReplace = expectedReplace ?? (this.expectedProviderSelections.Length == 0
                    ? new[] { "DeprecatedMod" }
                    : Array.Empty<string>());
                this.expectedInstallVersions = expectedInstallVersions ?? Array.Empty<MackanModuleVersionSelection>();
            }

            public MackanChangeSetResult ResolveChanges(MackanChangeSetRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Install, Is.EqualTo(expectedInstall));
                Assert.That(request.Remove, Is.EqualTo(expectedRemove));
                Assert.That(request.Upgrade, Is.EqualTo(expectedUpgrade));
                Assert.That(request.Replace, Is.EqualTo(expectedReplace));
                Assert.That(
                    request.InstallVersions.Select(selection => selection.Identifier),
                    Is.EqualTo(expectedInstallVersions.Select(selection => selection.Identifier)));
                Assert.That(
                    request.InstallVersions.Select(selection => selection.Version),
                    Is.EqualTo(expectedInstallVersions.Select(selection => selection.Version)));
                Assert.That(
                    request.ProviderSelections.Select(selection => selection.Requested),
                    Is.EqualTo(expectedProviderSelections.Select(selection => selection.Requested)));
                Assert.That(
                    request.ProviderSelections.Select(selection => selection.RequesterIdentifier),
                    Is.EqualTo(expectedProviderSelections.Select(selection => selection.RequesterIdentifier)));
                Assert.That(
                    request.ProviderSelections.Select(selection => selection.SelectedIdentifier),
                    Is.EqualTo(expectedProviderSelections.Select(selection => selection.SelectedIdentifier)));
                return result;
            }

            private readonly MackanChangeSetResult result;
            private readonly MackanProviderSelection[] expectedProviderSelections;
            private readonly string[] expectedInstall;
            private readonly string[] expectedRemove;
            private readonly string[] expectedUpgrade;
            private readonly string[] expectedReplace;
            private readonly MackanModuleVersionSelection[] expectedInstallVersions;
        }

        private sealed class ThrowingChangeSetProvider : IMackanChangeSetProvider
        {
            public ThrowingChangeSetProvider(Exception exception)
            {
                this.exception = exception;
            }

            public MackanChangeSetResult ResolveChanges(MackanChangeSetRequest request)
                => throw exception;

            private readonly Exception exception;
        }

        private sealed class FakeOperationProvider : IMackanOperationProvider
        {
            public FakeOperationProvider(MackanOperationResult result, bool expectedSkipDownloadFailures = false)
            {
                this.result = result;
                this.expectedSkipDownloadFailures = expectedSkipDownloadFailures;
            }

            public MackanOperationResult ApplyChanges(MackanChangeSetRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Install, Is.EqualTo(new[] { "ModuleManager" }));
                Assert.That(request.Remove, Is.EqualTo(new[] { "OldMod" }));
                Assert.That(request.Upgrade, Is.EqualTo(new[] { "UpgradeableMod" }));
                Assert.That(request.Replace, Is.EqualTo(new[] { "DeprecatedMod" }));
                Assert.That(request.SkipDownloadFailures, Is.EqualTo(expectedSkipDownloadFailures));
                return result;
            }

            public MackanOperationResult StartApplyChanges(MackanChangeSetRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Install, Is.EqualTo(new[] { "ModuleManager" }));
                Assert.That(request.Replace, Is.EqualTo(new[] { "DeprecatedMod" }));
                Assert.That(request.SkipDownloadFailures, Is.EqualTo(expectedSkipDownloadFailures));
                return result;
            }

            public MackanOperationResult InstallCkanFiles(MackanFileInstallRequest request)
            {
                AssertFileInstallRequest(request);
                return result;
            }

            public MackanOperationResult StartInstallCkanFiles(MackanFileInstallRequest request)
            {
                AssertFileInstallRequest(request);
                return result;
            }

            public MackanOperationResult ImportDownloads(MackanDownloadImportRequest request)
            {
                AssertImportDownloadsRequest(request);
                return result;
            }

            public MackanOperationResult StartImportDownloads(MackanDownloadImportRequest request)
            {
                AssertImportDownloadsRequest(request);
                return result;
            }

            private void AssertFileInstallRequest(MackanFileInstallRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.FilePaths, Is.EqualTo(new[]
                {
                    "/tmp/ModuleManager.ckan",
                    "/tmp/Other.ckan",
                }));
                Assert.That(request.ProviderSelections.Select(selection => selection.Requested), Is.EqualTo(new[] { "VirtualDependency" }));
                Assert.That(request.ProviderSelections.Select(selection => selection.RequesterIdentifier), Is.EqualTo(new[] { "ModuleManager" }));
                Assert.That(request.ProviderSelections.Select(selection => selection.SelectedIdentifier), Is.EqualTo(new[] { "ProviderA" }));
                Assert.That(request.RecommendationSelections, Is.EqualTo(new[] { "RecommendedMod" }));
                Assert.That(request.SkipRecommendations, Is.True);
                Assert.That(request.AllowIncompatibleCkanFiles, Is.True);
                Assert.That(request.SkipDownloadFailures, Is.EqualTo(expectedSkipDownloadFailures));
            }

            private void AssertImportDownloadsRequest(MackanDownloadImportRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Paths, Is.EqualTo(new[]
                {
                    "/Downloads/DogeCoinPlugin.zip",
                    "/Downloads/Other.zip",
                }));
                Assert.That(request.InstallImportedModules, Is.True);
                Assert.That(request.DeleteImportedFiles, Is.False);
                Assert.That(request.PreviewBeforeInstall, Is.True);
                Assert.That(request.SkipDownloadFailures, Is.EqualTo(expectedSkipDownloadFailures));
            }

            public MackanOperationResult GetStatus(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("op-1"));
                return result;
            }

            public MackanOperationResult CancelOperation(string operationId)
            {
                Assert.That(operationId, Is.EqualTo("op-1"));
                return result;
            }

            private readonly MackanOperationResult result;
            private readonly bool expectedSkipDownloadFailures;
        }

        private sealed class FakeExportProvider : IMackanExportProvider
        {
            public FakeExportProvider(
                MackanExportModListResult? result = null,
                MackanExportModpackResult? modpackResult = null,
                MackanModpackRelationshipAssignment[]? expectedRelationshipAssignments = null)
            {
                this.result = result;
                this.modpackResult = modpackResult;
                this.expectedRelationshipAssignments = expectedRelationshipAssignments ?? Array.Empty<MackanModpackRelationshipAssignment>();
            }

            public MackanExportModListResult ExportModList(MackanExportModListRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Format, Is.EqualTo("markdown"));
                return result ?? throw new InvalidOperationException("Unexpected mod list export.");
            }

            public MackanExportModpackResult ExportModpack(MackanExportModpackRequest request)
            {
                Assert.That(request.InstanceId, Is.EqualTo("primary"));
                Assert.That(request.Identifier, Is.EqualTo("MyModpack"));
                Assert.That(request.Name, Is.EqualTo("My Modpack"));
                Assert.That(request.Abstract, Is.EqualTo("Essential mods"));
                Assert.That(request.Author, Is.EqualTo("Jeb Kerman"));
                Assert.That(request.Version, Is.EqualTo("v1"));
                Assert.That(request.License, Is.EqualTo("MIT"));
                Assert.That(request.GameVersionMin, Is.EqualTo("1.12"));
                Assert.That(request.GameVersionMax, Is.EqualTo("1.12.5"));
                Assert.That(request.IncludeVersions, Is.False);
                Assert.That(request.IncludeOptionalRelationships, Is.False);
                Assert.That(
                    request.RelationshipAssignments.Select(assignment => assignment.Identifier),
                    Is.EqualTo(expectedRelationshipAssignments.Select(assignment => assignment.Identifier)));
                Assert.That(
                    request.RelationshipAssignments.Select(assignment => assignment.Kind),
                    Is.EqualTo(expectedRelationshipAssignments.Select(assignment => assignment.Kind)));
                return modpackResult ?? throw new InvalidOperationException("Unexpected modpack export.");
            }

            private readonly MackanExportModListResult? result;
            private readonly MackanExportModpackResult? modpackResult;
            private readonly MackanModpackRelationshipAssignment[] expectedRelationshipAssignments;
        }

        private sealed class FakeMaintenanceProvider : IMackanMaintenanceProvider
        {
            public FakeMaintenanceProvider(
                MackanMaintenanceScanResult? result = null,
                MackanUnmanagedFilesResult? unmanagedResult = null,
                MackanInstallationHistoryResult? historyResult = null,
                MackanInstallationHistoryEntry? historyEntry = null,
                MackanPlayTimeResult? playTimeResult = null,
                MackanDownloadStatisticsResult? downloadStatisticsResult = null,
                MackanCacheInfoResult? cacheInfoResult = null,
                MackanCachePurgeResult? cachePurgeResult = null,
                MackanDeduplicateResult? deduplicateResult = null,
                MackanRepairRegistryResult? repairRegistryResult = null,
                MackanRegistryLockRemovalResult? registryLockRemovalResult = null)
            {
                this.result = result;
                this.unmanagedResult = unmanagedResult;
                this.historyResult = historyResult;
                this.historyEntry = historyEntry;
                this.playTimeResult = playTimeResult;
                this.downloadStatisticsResult = downloadStatisticsResult;
                this.cacheInfoResult = cacheInfoResult;
                this.cachePurgeResult = cachePurgeResult;
                this.deduplicateResult = deduplicateResult;
                this.repairRegistryResult = repairRegistryResult;
                this.registryLockRemovalResult = registryLockRemovalResult;
            }

            public MackanMaintenanceScanResult ScanGameData(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return result ?? throw new InvalidOperationException("Unexpected maintenance scan.");
            }

            public MackanUnmanagedFilesResult ListUnmanagedFiles(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return unmanagedResult ?? throw new InvalidOperationException("Unexpected unmanaged files list.");
            }

            public MackanInstallationHistoryResult ListInstallationHistory(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return historyResult ?? throw new InvalidOperationException("Unexpected installation history list.");
            }

            public MackanInstallationHistoryEntry LoadInstallationHistoryEntry(string? instanceId, string fileName)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(fileName, Is.EqualTo("installed-Primary_KSP-2026-05-31_10-00-00.ckan"));
                return historyEntry ?? throw new InvalidOperationException("Unexpected installation history entry.");
            }

            public MackanPlayTimeResult ListPlayTime()
            {
                return playTimeResult ?? throw new InvalidOperationException("Unexpected play time list.");
            }

            public MackanPlayTimeResult UpdatePlayTime(string instanceId, double hours)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(hours, Is.EqualTo(14.25));
                return playTimeResult ?? throw new InvalidOperationException("Unexpected play time update.");
            }

            public MackanDownloadStatisticsResult DownloadStatistics(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return downloadStatisticsResult ?? throw new InvalidOperationException("Unexpected download statistics.");
            }

            public MackanCacheInfoResult CacheInfo()
            {
                return cacheInfoResult ?? throw new InvalidOperationException("Unexpected cache info.");
            }

            public MackanCachePurgeResult ClearCache()
            {
                return cachePurgeResult ?? throw new InvalidOperationException("Unexpected cache purge.");
            }

            public MackanCachePurgeResult PurgeCacheToLimit(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return cachePurgeResult ?? throw new InvalidOperationException("Unexpected cache purge.");
            }

            public MackanDeduplicateResult Deduplicate()
            {
                return deduplicateResult ?? throw new InvalidOperationException("Unexpected deduplicate.");
            }

            public MackanRepairRegistryResult RepairRegistry(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return repairRegistryResult ?? throw new InvalidOperationException("Unexpected registry repair.");
            }

            public MackanRegistryLockRemovalResult RemoveRegistryLock(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return registryLockRemovalResult ?? throw new InvalidOperationException("Unexpected registry lock removal.");
            }

            private readonly MackanMaintenanceScanResult? result;
            private readonly MackanUnmanagedFilesResult? unmanagedResult;
            private readonly MackanInstallationHistoryResult? historyResult;
            private readonly MackanInstallationHistoryEntry? historyEntry;
            private readonly MackanPlayTimeResult? playTimeResult;
            private readonly MackanDownloadStatisticsResult? downloadStatisticsResult;
            private readonly MackanCacheInfoResult? cacheInfoResult;
            private readonly MackanCachePurgeResult? cachePurgeResult;
            private readonly MackanDeduplicateResult? deduplicateResult;
            private readonly MackanRepairRegistryResult? repairRegistryResult;
            private readonly MackanRegistryLockRemovalResult? registryLockRemovalResult;
        }

        private sealed class FakeSettingsProvider : IMackanSettingsProvider
        {
            public FakeSettingsProvider(
                MackanSettingsResult result,
                MackanCompatibleGameVersionsResult? compatibleVersionsResult = null,
                MackanStabilityToleranceResult? stabilityToleranceResult = null,
                MackanPreferredHostsResult? preferredHostsResult = null,
                MackanInstallFiltersResult? installFiltersResult = null,
                MackanRecommendationSettingsResult? recommendationSettingsResult = null,
                MackanGeneralSettingsResult? generalSettingsResult = null,
                MackanGeneralSettingsResult? updatedGeneralSettingsResult = null,
                MackanAuthTokensResult? authTokensResult = null)
            {
                this.result = result;
                this.compatibleVersionsResult = compatibleVersionsResult;
                this.stabilityToleranceResult = stabilityToleranceResult;
                this.preferredHostsResult = preferredHostsResult;
                this.installFiltersResult = installFiltersResult;
                this.recommendationSettingsResult = recommendationSettingsResult;
                this.generalSettingsResult = generalSettingsResult
                    ?? new MackanGeneralSettingsResult("primary", true, false, true, true);
                this.updatedGeneralSettingsResult = updatedGeneralSettingsResult
                    ?? new MackanGeneralSettingsResult("primary", false, true, false, false);
                this.authTokensResult = authTokensResult;
            }

            public MackanSettingsResult GetSettings()
            {
                return result;
            }

            public MackanSettingsResult UpdateSettings(
                string? downloadCacheDir,
                long cacheSizeLimitBytes,
                string? cacheMigrationChoice = null)
            {
                Assert.That(downloadCacheDir, Is.EqualTo("/Users/test/CKANCache"));
                Assert.That(cacheSizeLimitBytes, Is.EqualTo(-1));
                Assert.That(cacheMigrationChoice, Is.EqualTo("delete"));
                return result;
            }

            public MackanGeneralSettingsResult GetGeneralSettings(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return generalSettingsResult;
            }

            public MackanGeneralSettingsResult UpdateGeneralSettings(
                string? instanceId,
                bool checkForUpdatesOnLaunch,
                bool useDevBuilds,
                bool refreshRepositoriesOnLaunch,
                bool autoSortByUpdate)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(checkForUpdatesOnLaunch, Is.False);
                Assert.That(useDevBuilds, Is.True);
                Assert.That(refreshRepositoriesOnLaunch, Is.False);
                Assert.That(autoSortByUpdate, Is.False);
                return updatedGeneralSettingsResult;
            }

            public MackanCompatibleGameVersionsResult GetCompatibleGameVersions(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return compatibleVersionsResult ?? throw new InvalidOperationException("Unexpected compatible versions request.");
            }

            public MackanCompatibleGameVersionsResult UpdateCompatibleGameVersions(string? instanceId, IReadOnlyList<string> versions)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(versions, Is.EqualTo(new[] { "1.12.5", "1.11" }));
                return compatibleVersionsResult ?? throw new InvalidOperationException("Unexpected compatible versions update.");
            }

            public MackanStabilityToleranceResult GetStabilityTolerance(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return stabilityToleranceResult ?? throw new InvalidOperationException("Unexpected stability tolerance request.");
            }

            public MackanStabilityToleranceResult UpdateOverallStabilityTolerance(string? instanceId, string stabilityTolerance)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(stabilityTolerance, Is.EqualTo("development"));
                return stabilityToleranceResult ?? throw new InvalidOperationException("Unexpected stability tolerance update.");
            }

            public MackanStabilityToleranceResult UpdateModuleStabilityTolerance(string? instanceId, string identifier, string? stabilityTolerance)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(identifier, Is.EqualTo("ModuleManager"));
                Assert.That(stabilityTolerance is "testing" or null, Is.True);
                return stabilityToleranceResult ?? throw new InvalidOperationException("Unexpected module stability tolerance update.");
            }

            public MackanPreferredHostsResult GetPreferredHosts(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return preferredHostsResult ?? throw new InvalidOperationException("Unexpected preferred hosts request.");
            }

            public MackanPreferredHostsResult UpdatePreferredHosts(string? instanceId, IReadOnlyList<string?> preferredHosts)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(preferredHosts, Is.EqualTo(new[] { "github.com", null, "spacedock.info" }));
                return preferredHostsResult ?? throw new InvalidOperationException("Unexpected preferred hosts update.");
            }

            public MackanInstallFiltersResult GetInstallFilters(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return installFiltersResult ?? throw new InvalidOperationException("Unexpected install filters request.");
            }

            public MackanInstallFiltersResult UpdateInstallFilters(
                string? instanceId,
                IReadOnlyList<string> globalFilters,
                IReadOnlyList<string> instanceFilters)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(globalFilters, Is.EqualTo(new[] { "Ships", "MiniAVC.dll" }));
                Assert.That(instanceFilters, Is.EqualTo(new[] { "GameData/TestMod/Extras" }));
                return installFiltersResult ?? throw new InvalidOperationException("Unexpected install filters update.");
            }

            public MackanRecommendationSettingsResult GetRecommendationSettings(string? instanceId)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                return recommendationSettingsResult ?? throw new InvalidOperationException("Unexpected recommendation settings request.");
            }

            public MackanRecommendationSettingsResult UpdateRecommendationSettings(string? instanceId, bool suppressRecommendations)
            {
                Assert.That(instanceId, Is.EqualTo("primary"));
                Assert.That(suppressRecommendations, Is.True);
                return recommendationSettingsResult ?? throw new InvalidOperationException("Unexpected recommendation settings update.");
            }

            public MackanAuthTokensResult GetAuthTokens()
            {
                return authTokensResult ?? throw new InvalidOperationException("Unexpected auth tokens request.");
            }

            public MackanAuthTokensResult AddAuthToken(string? host, string? token)
            {
                Assert.That(host, Is.EqualTo("github.com"));
                Assert.That(token, Is.EqualTo("abcdef"));
                return authTokensResult ?? throw new InvalidOperationException("Unexpected auth token add.");
            }

            public MackanAuthTokensResult RemoveAuthToken(string? host)
            {
                Assert.That(host, Is.EqualTo("github.com"));
                return authTokensResult ?? throw new InvalidOperationException("Unexpected auth token remove.");
            }

            private readonly MackanSettingsResult result;
            private readonly MackanCompatibleGameVersionsResult? compatibleVersionsResult;
            private readonly MackanStabilityToleranceResult? stabilityToleranceResult;
            private readonly MackanPreferredHostsResult? preferredHostsResult;
            private readonly MackanInstallFiltersResult? installFiltersResult;
            private readonly MackanRecommendationSettingsResult? recommendationSettingsResult;
            private readonly MackanGeneralSettingsResult generalSettingsResult;
            private readonly MackanGeneralSettingsResult updatedGeneralSettingsResult;
            private readonly MackanAuthTokensResult? authTokensResult;
        }

        private static string[] ReadStrings(JsonElement element)
        {
            var values = new List<string>();
            foreach (var item in element.EnumerateArray())
            {
                values.Add(item.GetString()!);
            }
            return values.ToArray();
        }

        private static string?[] ReadNullableStrings(JsonElement element)
        {
            var values = new List<string?>();
            foreach (var item in element.EnumerateArray())
            {
                values.Add(item.ValueKind == JsonValueKind.Null ? null : item.GetString());
            }
            return values.ToArray();
        }
    }
}

#endif

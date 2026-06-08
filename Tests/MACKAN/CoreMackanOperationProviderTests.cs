#if NET10_0_OR_GREATER

using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;

using CKAN;
using CKAN.MACKAN.Service;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanOperationProviderTests
    {
        private const string ProviderA = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ProviderA"",
            ""name"": ""Provider A"",
            ""abstract"": ""First virtual provider."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/provider-a.zip"",
            ""kind"": ""metapackage"",
            ""provides"": [""VirtualDependency""]
        }";
        private const string ProviderB = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ProviderB"",
            ""name"": ""Provider B"",
            ""abstract"": ""Second virtual provider."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/provider-b.zip"",
            ""kind"": ""metapackage"",
            ""provides"": [""VirtualDependency""]
        }";
        private const string LocalMetapackage = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""LocalMetapackage"",
            ""name"": ""Local Metapackage"",
            ""abstract"": ""Local metapackage with a virtual dependency."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage"",
            ""depends"": [{ ""name"": ""VirtualDependency"" }]
        }";
        private const string RecommendedMod = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""RecommendedMod"",
            ""name"": ""Recommended Mod"",
            ""abstract"": ""Useful optional companion."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/recommended.zip"",
            ""kind"": ""metapackage""
        }";
        private const string LocalRecommender = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""LocalRecommender"",
            ""name"": ""Local Recommender"",
            ""abstract"": ""Local metapackage with an optional recommendation."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage"",
            ""recommends"": [{ ""name"": ""RecommendedMod"" }]
        }";
        private const string LocalIncompatibleMetapackage = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""LocalIncompatibleMetapackage"",
            ""name"": ""Local Incompatible Metapackage"",
            ""abstract"": ""Local metapackage for a different game version."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.24"",
            ""kind"": ""metapackage""
        }";
        private const string HistoryRestorableOld = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""HistoryRestorable"",
            ""name"": ""History Restorable"",
            ""abstract"": ""Older history restorable test module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string HistoryRestorableNew = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""HistoryRestorable"",
            ""name"": ""History Restorable"",
            ""abstract"": ""Newer history restorable test module."",
            ""author"": ""Test"",
            ""version"": ""2.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string UpgradableOld = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""UpgradableMod"",
            ""name"": ""Upgradable Mod"",
            ""abstract"": ""Older upgradable test module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""download"": ""https://example.invalid/upgradable-old.zip"",
            ""install"": [{ ""find_regexp"": ""^DogeCoinFlag$"", ""install_to"": ""GameData"" }]
        }";
        private const string UpgradableNew = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""UpgradableMod"",
            ""name"": ""Upgradable Mod"",
            ""abstract"": ""Newer upgradable test module."",
            ""author"": ""Test"",
            ""version"": ""1.1.0"",
            ""license"": ""MIT"",
            ""download"": ""https://example.invalid/upgradable-new.zip"",
            ""install"": [{ ""find"": ""DogeCoinFlag"", ""install_to"": ""GameData"" }]
        }";
        private const string ReplaceableMod = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ReplaceableMod"",
            ""name"": ""Replaceable Mod"",
            ""abstract"": ""Module with a replacement."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""download"": ""https://example.invalid/replaceable.zip"",
            ""install"": [{ ""find"": ""DogeCoinFlag"", ""install_to"": ""GameData"" }],
            ""replaced_by"": { ""name"": ""ReplacementMod"" }
        }";
        private const string ReplacementMod = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ReplacementMod"",
            ""name"": ""Replacement Mod"",
            ""abstract"": ""Replacement test module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""download"": ""https://example.invalid/replacement.zip"",
            ""install"": [{ ""find"": ""DogeCoinFlag"", ""install_to"": ""GameData"" }]
        }";

        [Test]
        public void InstallCkanFilesWithoutCompatibilityConfirmationReturnsIncompatibleDetails()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalIncompatibleMetapackage.ckan");
            File.WriteAllText(ckanPath, LocalIncompatibleMetapackage);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager);

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("incompatibleCkanFiles"));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("confirmIncompatible"));
            Assert.That(result.ErrorDetails.IncompatibleCkanFiles, Has.Length.EqualTo(1));
            Assert.That(result.ErrorDetails.IncompatibleCkanFiles![0].Identifier, Is.EqualTo("LocalIncompatibleMetapackage"));
            Assert.That(result.ErrorDetails.IncompatibleCkanFiles[0].Name, Is.EqualTo("Local Incompatible Metapackage"));
            Assert.That(result.ErrorDetails.IncompatibleCkanFiles[0].Version, Is.EqualTo("1.0.0"));
            Assert.That(result.ErrorDetails.IncompatibleCkanFiles[0].CompatibleGameVersions, Is.EqualTo("KSP 0.24"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalIncompatibleMetapackage"), Is.Null);
        }

        [Test]
        public void InstallCkanFilesWithCompatibilityConfirmationInstallsIncompatibleModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalIncompatibleMetapackage.ckan");
            File.WriteAllText(ckanPath, LocalIncompatibleMetapackage);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath },
                allowIncompatibleCkanFiles: true));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager);

            Assert.That(
                result.Status,
                Is.EqualTo("completed"),
                result.Error ?? string.Join(System.Environment.NewLine, result.Events.Select(evt => $"{evt.Kind}: {evt.Message}")));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalIncompatibleMetapackage"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalIncompatibleMetapackage"), Is.Not.Null);
        }

        [Test]
        public void InstallCkanFilesInstallsCompatibleLocalCkanModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "HistoryRestorable.ckan");
            File.WriteAllText(ckanPath, HistoryRestorableOld);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager);
            var installed = verifyRegistryManager.registry.InstalledModule("HistoryRestorable");

            Assert.That(
                result.Status,
                Is.EqualTo("completed"),
                result.Error ?? string.Join(System.Environment.NewLine, result.Events.Select(evt => $"{evt.Kind}: {evt.Message}")));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Changes.Select(change => change.Identifier), Is.EqualTo(new[] { "HistoryRestorable" }));
            Assert.That(result.Changes[0].Action, Is.EqualTo("install"));
            Assert.That(result.Changes[0].Reasons, Is.EqualTo(new[] { "User requested" }));
            Assert.That(installed, Is.Not.Null);
            Assert.That(installed!.Module.version.ToString(), Is.EqualTo("1.0.0"));
        }

        [Test]
        public void InstallCkanFilesEmitsDownloadStoreAndInstallProgressEvents()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using var ckanDir = new TemporaryDirectory();
            var localCkan = UpgradableNew.Replace(
                "https://example.invalid/upgradable-new.zip",
                new System.Uri(TestData.DogeCoinFlagZip()).ToString());
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "UpgradableMod.ckan");
            File.WriteAllText(ckanPath, localCkan);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("downloadProgress"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("storeProgress"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("installProgress"));
            Assert.That(
                result.Events
                    .Where(evt => evt.Kind is "downloadProgress" or "storeProgress" or "installProgress")
                    .Select(evt => evt.Identifier)
                    .Distinct(),
                Is.EqualTo(new[] { "UpgradableMod" }));
            Assert.That(
                result.Events.Where(evt => evt.Kind == "complete").Select(evt => evt.Identifier),
                Does.Contain("UpgradableMod"));
        }

        [Test]
        public void ApplyChangesWithInstallVersionsInstallsRequestedSnapshotVersion()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(HistoryRestorableOld, HistoryRestorableNew);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                installVersions: new[]
                {
                    new MackanModuleVersionSelection("HistoryRestorable", "1.0.0"),
                }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            var installed = verifyRegistryManager.registry.InstalledModule("HistoryRestorable");

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Single(change => change.Identifier == "HistoryRestorable").ToVersion, Is.EqualTo("1.0.0"));
            Assert.That(installed, Is.Not.Null);
            Assert.That(installed!.Module.version.ToString(), Is.EqualTo("1.0.0"));
        }

        [Test]
        public void ApplyChangesInstallsSelectedModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(HistoryRestorableOld);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "HistoryRestorable" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>()));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            var installed = verifyRegistryManager.registry.InstalledModule("HistoryRestorable");

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Single(change => change.Identifier == "HistoryRestorable").Action, Is.EqualTo("install"));
            Assert.That(installed, Is.Not.Null);
            Assert.That(installed!.Module.version.ToString(), Is.EqualTo("1.0.0"));
        }

        [Test]
        public void ApplyChangesEmitsDownloadStoreAndInstallProgressEvents()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var downloadable = UpgradableNew.Replace(
                "https://example.invalid/upgradable-new.zip",
                new System.Uri(TestData.DogeCoinFlagZip()).ToString());
            using var repo = new TemporaryRepository(downloadable);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "UpgradableMod" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>()));

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("downloadProgress"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("storeProgress"));
            Assert.That(result.Events.Select(evt => evt.Kind), Does.Contain("installProgress"));
            Assert.That(
                result.Events
                    .Where(evt => evt.Kind is "downloadProgress" or "storeProgress" or "installProgress")
                    .Select(evt => evt.Identifier)
                    .Distinct(),
                Is.EqualTo(new[] { "UpgradableMod" }));
            Assert.That(
                result.Events.Where(evt => evt.Kind == "complete").Select(evt => evt.Identifier),
                Does.Contain("UpgradableMod"));
        }

        [Test]
        public void ApplyChangesRemovesSelectedModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager))
            {
                registryManager.registry.RegisterModule(
                    CkanModule.FromJson(HistoryRestorableOld),
                    System.Array.Empty<string>(),
                    instance.KSP,
                    false);
                registryManager.Save(false);
            }

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                System.Array.Empty<string>(),
                new[] { "HistoryRestorable" },
                System.Array.Empty<string>()));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager);

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Single(change => change.Identifier == "HistoryRestorable").Action, Is.EqualTo("remove"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("HistoryRestorable"), Is.Null);
        }

        [Test]
        public void ApplyChangesUpgradesSelectedModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var upgradableNew = UpgradableNew.Replace(
                "https://example.invalid/upgradable-new.zip",
                new System.Uri(TestData.DogeCoinFlagZip()).ToString());
            using var repo = new TemporaryRepository(UpgradableOld, upgradableNew);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo }))
            {
                var fromModule = registryManager.registry.GetModuleByVersion("UpgradableMod", "1.0.0")!;
                var installedPath = instance.KSP.ToAbsoluteGameDir("GameData/DogeCoinFlag");
                Directory.CreateDirectory(installedPath);
                registryManager.registry.RegisterModule(
                    fromModule,
                    new[] { installedPath },
                    instance.KSP,
                    false);
                Assert.That(
                    registryManager.registry.HasUpdate(
                        "UpgradableMod",
                        instance.KSP.StabilityToleranceConfig,
                        instance.KSP,
                        new HashSet<string>(),
                        true,
                        out var latestBeforeSave),
                    Is.True);
                Assert.That(latestBeforeSave!.version.ToString(), Is.EqualTo("1.1.0"));
                registryManager.Save(false);
            }

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                new[] { "UpgradableMod" }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            var installed = verifyRegistryManager.registry.InstalledModule("UpgradableMod");

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Single(change => change.Identifier == "UpgradableMod").Action, Is.EqualTo("upgrade"));
            Assert.That(result.Changes.Single(change => change.Identifier == "UpgradableMod").ToVersion, Is.EqualTo("1.1.0"));
            Assert.That(installed, Is.Not.Null);
            Assert.That(installed!.Module.version.ToString(), Is.EqualTo("1.1.0"));
        }

        [Test]
        public void ApplyChangesReplacesSelectedModule()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var replacement = ReplacementMod.Replace(
                "https://example.invalid/replacement.zip",
                new System.Uri(TestData.DogeCoinFlagZip()).ToString());
            using var repo = new TemporaryRepository(ReplaceableMod, replacement);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo }))
            {
                var fromModule = registryManager.registry.GetModuleByVersion("ReplaceableMod", "1.0.0")!;
                registryManager.registry.RegisterModule(
                    fromModule,
                    System.Array.Empty<string>(),
                    instance.KSP,
                    false);
                registryManager.Save(false);
            }

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                replace: new[] { "ReplaceableMod" }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(
                result.Changes.Select(change => $"{change.Identifier}:{change.Action}:{string.Join("+", change.Reasons)}"),
                Is.EqualTo(new[]
                {
                    "ReplacementMod:install:Replacing Replaceable Mod",
                    "ReplaceableMod:replace:User requested",
                }));
            Assert.That(result.Changes.Single(change => change.Identifier == "ReplaceableMod").Action, Is.EqualTo("replace"));
            Assert.That(result.Changes.Single(change => change.Identifier == "ReplacementMod").Action, Is.EqualTo("install"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("ReplaceableMod"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ReplacementMod"), Is.Not.Null);
        }

        [Test]
        public void ApplyChangesInstallsStagedRecommendation()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(LocalRecommender, RecommendedMod);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalRecommender", "RecommendedMod" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>()));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalRecommender"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("RecommendedMod"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalRecommender"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("RecommendedMod"), Is.Not.Null);
        }

        [Test]
        public void ApplyChangesReturnsRegistryLockDetailsWhenRegistryIsLocked()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(HistoryRestorableOld);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo }))
            {
                registryManager.Save(false);
            }
            var lockfilePath = WriteLiveRegistryLock(instance.KSP);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "HistoryRestorable" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>()));

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("registryLock"));
            Assert.That(result.ErrorDetails.LockfilePath, Is.EqualTo(lockfilePath));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("waitRetry"));
        }

        [Test]
        public void InstallCkanFilesReturnsRegistryLockDetailsWhenRegistryIsLocked()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager))
            {
                registryManager.Save(false);
            }
            var lockfilePath = WriteLiveRegistryLock(instance.KSP);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "HistoryRestorable.ckan");
            File.WriteAllText(ckanPath, HistoryRestorableOld);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager);

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("registryLock"));
            Assert.That(result.ErrorDetails.LockfilePath, Is.EqualTo(lockfilePath));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("waitRetry"));
        }

        [Test]
        public void ImportDownloadsReturnsRegistryLockDetailsWhenRegistryIsLocked()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(TestData.DogeCoinPlugin());
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo }))
            {
                registryManager.Save(false);
            }
            var lockfilePath = WriteLiveRegistryLock(instance.KSP);
            using var zipDir = new TemporaryDirectory();
            var zipPath = Path.Combine(zipDir.Directory.FullName, Path.GetFileName(TestData.DogeCoinPluginZip()));
            File.Copy(TestData.DogeCoinPluginZip(), zipPath);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ImportDownloads(new MackanDownloadImportRequest(
                instance.KSP.Name,
                new[] { zipPath },
                installImportedModules: true,
                deleteImportedFiles: false));

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("registryLock"));
            Assert.That(result.ErrorDetails.LockfilePath, Is.EqualTo(lockfilePath));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("waitRetry"));
        }

        [Test]
        public void InstallCkanFilesWithoutRecommendationDecisionReturnsRecommendationChoiceDetails()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(RecommendedMod);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalRecommender.ckan");
            File.WriteAllText(ckanPath, LocalRecommender);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("recommendationChoices"));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("chooseRecommendations"));
            Assert.That(result.ErrorDetails.RecommendationChoices, Has.Length.EqualTo(1));
            Assert.That(result.ErrorDetails.RecommendationChoices![0].Kind, Is.EqualTo("recommendation"));
            Assert.That(result.ErrorDetails.RecommendationChoices[0].Identifier, Is.EqualTo("RecommendedMod"));
            Assert.That(result.ErrorDetails.RecommendationChoices[0].Dependents, Is.EqualTo(new[] { "LocalRecommender" }));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalRecommender"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("RecommendedMod"), Is.Null);
        }

        [Test]
        public void InstallCkanFilesWithRecommendationSelectionInstallsSelectedRecommendation()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(RecommendedMod);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalRecommender.ckan");
            File.WriteAllText(ckanPath, LocalRecommender);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath },
                recommendationSelections: new[] { "RecommendedMod" },
                skipRecommendations: true));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalRecommender"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("RecommendedMod"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalRecommender"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("RecommendedMod"), Is.Not.Null);
        }

        [Test]
        public void InstallCkanFilesWithoutProviderSelectionReturnsProviderChoiceDetails()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(ProviderA, ProviderB);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalMetapackage.ckan");
            File.WriteAllText(ckanPath, LocalMetapackage);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("providerChoices"));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("chooseProvider"));
            Assert.That(result.ErrorDetails.ProviderChoices, Has.Length.EqualTo(1));
            Assert.That(result.ErrorDetails.ProviderChoices![0].Requested, Is.EqualTo("VirtualDependency"));
            Assert.That(result.ErrorDetails.ProviderChoices[0].RequesterIdentifier, Is.EqualTo("LocalMetapackage"));
            Assert.That(
                result.ErrorDetails.ProviderChoices[0].Options.Select(option => option.Identifier),
                Is.EqualTo(new[] { "ProviderA", "ProviderB" }));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalMetapackage"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderA"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderB"), Is.Null);
        }

        [Test]
        public void InstallCkanFilesWithProviderSelectionInstallsSelectedProvider()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(ProviderA, ProviderB);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var ckanDir = new TemporaryDirectory();
            var ckanPath = Path.Combine(ckanDir.Directory.FullName, "LocalMetapackage.ckan");
            File.WriteAllText(ckanPath, LocalMetapackage);
            var setupRegistry = new CKAN.Registry(repoData.Manager, repo.repo);
            Assert.That(
                setupRegistry.LatestAvailable(
                    "ProviderA",
                    instance.KSP.StabilityToleranceConfig,
                    instance.KSP.VersionCriteria()),
                Is.Not.Null);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.InstallCkanFiles(new MackanFileInstallRequest(
                instance.KSP.Name,
                new[] { ckanPath },
                new[]
                {
                    new MackanProviderSelection(
                        "VirtualDependency",
                        "LocalMetapackage",
                        "ProviderA"),
                }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalMetapackage"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("ProviderA"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalMetapackage"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderA"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderB"), Is.Null);
        }

        [Test]
        public void ApplyChangesWithoutProviderSelectionReturnsProviderChoiceDetails()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(ProviderA, ProviderB, LocalMetapackage);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalMetapackage" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>()));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("failed"));
            Assert.That(result.ErrorDetails, Is.Not.Null);
            Assert.That(result.ErrorDetails!.Kind, Is.EqualTo("providerChoices"));
            Assert.That(result.ErrorDetails.SuggestedAction, Is.EqualTo("chooseProvider"));
            Assert.That(result.ErrorDetails.ProviderChoices, Has.Length.EqualTo(1));
            Assert.That(result.ErrorDetails.ProviderChoices![0].Requested, Is.EqualTo("VirtualDependency"));
            Assert.That(result.ErrorDetails.ProviderChoices[0].RequesterIdentifier, Is.EqualTo("LocalMetapackage"));
            Assert.That(
                result.ErrorDetails.ProviderChoices[0].Options.Select(option => option.Identifier),
                Is.EqualTo(new[] { "ProviderA", "ProviderB" }));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalMetapackage"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderA"), Is.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderB"), Is.Null);
        }

        [Test]
        public void ApplyChangesWithProviderSelectionInstallsSelectedProvider()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(ProviderA, ProviderB, LocalMetapackage);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ApplyChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalMetapackage" },
                System.Array.Empty<string>(),
                System.Array.Empty<string>(),
                providerSelections: new[]
                {
                    new MackanProviderSelection(
                        "VirtualDependency",
                        "LocalMetapackage",
                        "ProviderA"),
                }));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalMetapackage"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("ProviderA"));
            Assert.That(verifyRegistryManager.registry.InstalledModule("LocalMetapackage"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderA"), Is.Not.Null);
            Assert.That(verifyRegistryManager.registry.InstalledModule("ProviderB"), Is.Null);
        }

        [Test]
        public void ImportDownloadsWithPreviewReturnsInstallChangesWithoutInstalling()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(TestData.DogeCoinPlugin());
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var zipDir = new TemporaryDirectory();
            var zipPath = Path.Combine(zipDir.Directory.FullName, Path.GetFileName(TestData.DogeCoinPluginZip()));
            File.Copy(TestData.DogeCoinPluginZip(), zipPath);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ImportDownloads(new MackanDownloadImportRequest(
                instance.KSP.Name,
                new[] { zipPath },
                installImportedModules: false,
                deleteImportedFiles: false,
                previewBeforeInstall: true));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Changes.Select(change => change.Identifier), Is.EqualTo(new[] { "DogeCoinPlugin" }));
            Assert.That(result.Changes[0].Action, Is.EqualTo("install"));
            Assert.That(result.Changes[0].Reasons, Is.EqualTo(new[] { "Imported download" }));
            Assert.That(verifyRegistryManager.registry.InstalledModule("DogeCoinPlugin"), Is.Null);
        }

        [Test]
        public void ImportDownloadsWithInstallImportedModulesInstallsMatchedArchiveAndCachesIt()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath);
            using var repo = new TemporaryRepository(TestData.DogeCoinPlugin());
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var zipDir = new TemporaryDirectory();
            var zipPath = Path.Combine(zipDir.Directory.FullName, Path.GetFileName(TestData.DogeCoinPluginZip()));
            File.Copy(TestData.DogeCoinPluginZip(), zipPath);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ImportDownloads(new MackanDownloadImportRequest(
                instance.KSP.Name,
                new[] { zipPath },
                installImportedModules: true,
                deleteImportedFiles: false));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            using var cache = new NetModuleCache(config.DownloadCacheDir!);

            Assert.That(result.Status, Is.EqualTo("completed"));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Changes.Select(change => change.Identifier), Is.EqualTo(new[] { "DogeCoinPlugin" }));
            Assert.That(result.Changes[0].Action, Is.EqualTo("install"));
            Assert.That(result.Changes[0].Reasons, Is.EqualTo(new[] { "Imported download" }));
            Assert.That(verifyRegistryManager.registry.InstalledModule("DogeCoinPlugin"), Is.Not.Null);
            Assert.That(cache.GetCachedFilename(TestData.DogeCoinPlugin_module()), Is.Not.Null);
            Assert.That(File.Exists(zipPath), Is.True);
        }

        [Test]
        public void ImportDownloadsWithDeleteImportedFilesMovesMatchedArchiveIntoCacheWithoutInstalling()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            var cachePath = Path.Combine(instance.KSP.GameDir, "MACKANCache");
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name, cachePath);
            using var repo = new TemporaryRepository(TestData.DogeCoinPlugin());
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var zipDir = new TemporaryDirectory();
            var zipPath = Path.Combine(zipDir.Directory.FullName, Path.GetFileName(TestData.DogeCoinPluginZip()));
            File.Copy(TestData.DogeCoinPluginZip(), zipPath);

            var provider = new CoreMackanOperationProvider(config, repoData.Manager, new[] { repo.repo });

            var result = provider.ImportDownloads(new MackanDownloadImportRequest(
                instance.KSP.Name,
                new[] { zipPath },
                installImportedModules: false,
                deleteImportedFiles: true));

            using var verifyRegistryManager = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });
            using var cache = new NetModuleCache(config.DownloadCacheDir!);

            Assert.That(
                result.Status,
                Is.EqualTo("completed"),
                result.Error ?? string.Join(System.Environment.NewLine, result.Events.Select(evt => $"{evt.Kind}: {evt.Message}")));
            Assert.That(result.Error, Is.Null);
            Assert.That(result.Changes, Is.Empty);
            Assert.That(verifyRegistryManager.registry.InstalledModule("DogeCoinPlugin"), Is.Null);
            Assert.That(cache.GetCachedFilename(TestData.DogeCoinPlugin_module()), Is.Not.Null);
            Assert.That(File.Exists(zipPath), Is.False);
        }

        private static string WriteLiveRegistryLock(GameInstance instance)
        {
            RegistryManager.DisposeInstance(instance);
            Directory.CreateDirectory(instance.CkanDir);
            var lockfilePath = Path.Combine(instance.CkanDir, "registry.locked");
            File.WriteAllText(lockfilePath, Process.GetCurrentProcess().Id.ToString());
            return lockfilePath;
        }
    }
}

#endif

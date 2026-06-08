#if NET10_0_OR_GREATER

using System;
using System.Linq;

using CKAN;
using CKAN.MACKAN.Service;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanModuleProviderTests
    {
        private const string FullListFeature = @"{
            ""spec_version"": ""v1.34"",
            ""identifier"": ""MACKANFullListFeature"",
            ""name"": ""MACKAN Full List Feature"",
            ""abstract"": ""Short full-list summary."",
            ""description"": ""Long full-list description shown in details and searchable columns."",
            ""author"": [""Alpha"", ""Beta""],
            ""version"": ""1.2.3"",
            ""license"": ""MIT"",
            ""ksp_version"": ""any"",
            ""download"": ""https://example.invalid/mackan-full-list.zip"",
            ""download_size"": 123456,
            ""install_size"": 654321,
            ""release_date"": ""2020-01-02T03:04:05Z"",
            ""tags"": [""utility"", ""graphics""],
            ""localizations"": [""fr-fr"", ""en-us""],
            ""recommends"": [{ ""name"": ""ModuleManager"" }]
        }";

        private const string FutureFeature = @"{
            ""spec_version"": ""v1.34"",
            ""identifier"": ""MACKANFutureFeature"",
            ""name"": ""MACKAN Future Feature"",
            ""abstract"": ""Future-only metadata."",
            ""author"": ""Gamma"",
            ""version"": ""9.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""99.0"",
            ""download"": ""https://example.invalid/mackan-future.zip""
        }";

        private const string InstalledOnlyFeature = @"{
            ""spec_version"": ""v1.34"",
            ""identifier"": ""MACKANInstalledOnlyFeature"",
            ""name"": ""MACKAN Installed Only Feature"",
            ""abstract"": ""Installed-only metadata."",
            ""author"": ""Delta"",
            ""version"": ""0.1.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""any"",
            ""kind"": ""metapackage""
        }";

        [Test]
        public void ListModulesReturnsFullCoreCatalogFromDisposableRegistry()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(FullListFeature, FutureFeature);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var registryManager = RegistryManager.Instance(
                instance.KSP,
                repoData.Manager,
                new[] { repo.repo });
            var installedModule = CkanModule.FromJson(InstalledOnlyFeature);
            registryManager.registry.RegisterModule(
                installedModule,
                new[] { instance.KSP.ToAbsoluteGameDir("GameData/MACKANInstalledOnlyFeature") },
                instance.KSP,
                true);
            registryManager.Save(false);
            var provider = new CoreMackanModuleProvider(config, repoData.Manager);

            var result = provider.ListModules(instance.KSP.Name);

            Assert.That(result.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(
                result.Modules.Select(module => module.Identifier),
                Is.EquivalentTo(new[]
                {
                    "MACKANFullListFeature",
                    "MACKANFutureFeature",
                    "MACKANInstalledOnlyFeature",
                }));

            var available = result.Modules.Single(module => module.Identifier == "MACKANFullListFeature");
            Assert.That(available.Status, Is.EqualTo("available"));
            Assert.That(available.IsInstalled, Is.False);
            Assert.That(available.IsCompatible, Is.True);
            Assert.That(available.Name, Is.EqualTo("MACKAN Full List Feature"));
            Assert.That(available.Author, Is.EqualTo("Alpha, Beta"));
            Assert.That(available.InstalledVersion, Is.EqualTo("-"));
            Assert.That(available.LatestVersion, Is.EqualTo("1.2.3"));
            Assert.That(available.License, Is.EqualTo("MIT"));
            Assert.That(available.Tags, Is.EqualTo(new[] { "graphics", "utility" }));
            Assert.That(available.Abstract, Is.EqualTo("Short full-list summary."));
            Assert.That(available.Description, Is.EqualTo("Long full-list description shown in details and searchable columns."));
            Assert.That(available.Localizations, Is.EqualTo(new[] { "en-us", "fr-fr" }));
            Assert.That(available.GameCompatibility, Is.Not.Empty);
            Assert.That(available.DownloadSize, Is.EqualTo(123456));
            Assert.That(available.DownloadSizeDisplay, Is.Not.Empty);
            Assert.That(available.InstallSize, Is.EqualTo(654321));
            Assert.That(available.InstallSizeDisplay, Is.Not.Empty);
            Assert.That(available.ReleaseDate, Does.StartWith("2020-01-02T03:04:05"));
            Assert.That(available.Relationships.Single().Kind, Is.EqualTo("Recommends"));
            Assert.That(available.Relationships.Single().Value, Is.EqualTo("ModuleManager"));
            Assert.That(available.Contents, Is.Empty);
            Assert.That(available.Versions, Is.EqualTo(new[] { "1.2.3" }));
            var availableDetails = provider.GetModuleDetails(instance.KSP.Name, "MACKANFullListFeature");
            Assert.That(availableDetails.Module.Contents, Does.Contain("GameData/MACKANFullListFeature"));

            var incompatible = result.Modules.Single(module => module.Identifier == "MACKANFutureFeature");
            Assert.That(incompatible.Status, Is.EqualTo("incompatible"));
            Assert.That(incompatible.IsCompatible, Is.False);

            var installed = result.Modules.Single(module => module.Identifier == "MACKANInstalledOnlyFeature");
            Assert.That(installed.Status, Is.EqualTo("installed"));
            Assert.That(installed.IsInstalled, Is.True);
            Assert.That(installed.IsAutoInstalled, Is.True);
            Assert.That(installed.InstalledVersion, Is.EqualTo("0.1.0"));
            Assert.That(installed.Contents, Is.EqualTo(new[] { "GameData/MACKANInstalledOnlyFeature" }));
        }

        [Test]
        public void SetAutoInstalledUpdatesDisposableRegistryAndReturnsRefreshedCatalog()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user);
            using (var registryManager = RegistryManager.Instance(instance.KSP, repoData.Manager))
            {
                registryManager.registry.RegisterModule(
                    CkanModule.FromJson(InstalledOnlyFeature),
                    new[] { instance.KSP.ToAbsoluteGameDir("GameData/MACKANInstalledOnlyFeature") },
                    instance.KSP,
                    true);
                registryManager.Save(false);
            }
            var provider = new CoreMackanModuleProvider(config, repoData.Manager);

            var result = provider.SetAutoInstalled(
                instance.KSP.Name,
                "MACKANInstalledOnlyFeature",
                false);

            var module = result.Modules.Single(module => module.Identifier == "MACKANInstalledOnlyFeature");
            Assert.That(module.IsInstalled, Is.True);
            Assert.That(module.IsAutoInstalled, Is.False);
            using var reloadedRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager);
            Assert.That(
                reloadedRegistry.registry.InstalledModule("MACKANInstalledOnlyFeature")?.AutoInstalled,
                Is.False);
        }
    }
}

#endif

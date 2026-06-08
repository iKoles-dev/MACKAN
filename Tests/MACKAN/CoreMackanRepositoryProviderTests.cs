#if NET10_0_OR_GREATER

using System;
using System.IO;
using System.Linq;

using CKAN;
using CKAN.Versioning;
using CKAN.Games;
using CKAN.Games.KerbalSpaceProgram;
using CKAN.MACKAN.Service;
using Moq;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanRepositoryProviderTests
    {
        [Test]
        public void ListAddMoveAndRemoveRepositoriesUseDisposableRegistry()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var repositoryData = new RepositoryDataManager();
            var baseRepo = new Repository("base", "https://example.invalid/base.tar.gz", 0);
            var extraRepo = new Repository("extra", "https://example.invalid/extra.tar.gz", 1);
            using (var registry = RegistryManager.Instance(
                       instance.KSP,
                       repositoryData,
                       new[] { baseRepo, extraRepo }))
            {
                registry.Save();
            }

            var provider = new CoreMackanRepositoryProvider(config, repositoryData);

            var listed = provider.ListRepositories(instance.KSP.Name);
            var added = provider.AddRepository(instance.KSP.Name, "third", "https://example.invalid/third.tar.gz");
            var moved = provider.SetRepositoryPriority(instance.KSP.Name, "third", 0);
            var removed = provider.RemoveRepository(instance.KSP.Name, "base");
            var persisted = provider.ListRepositories(instance.KSP.Name);

            Assert.That(listed.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(listed.Repositories.Select(repo => repo.Name), Is.EqualTo(new[] { "base", "extra" }));
            Assert.That(added.Repositories.Select(repo => repo.Name), Is.EqualTo(new[] { "base", "extra", "third" }));
            Assert.That(added.Repositories.Single(repo => repo.Name == "third").Priority, Is.EqualTo(2));
            Assert.That(moved.Repositories.Select(repo => repo.Name), Is.EqualTo(new[] { "third", "base", "extra" }));
            Assert.That(moved.Repositories.Select(repo => repo.Priority), Is.EqualTo(new[] { 0, 1, 2 }));
            Assert.That(removed.Repositories.Select(repo => repo.Name), Is.EqualTo(new[] { "third", "extra" }));
            Assert.That(removed.Repositories.Select(repo => repo.Priority), Is.EqualTo(new[] { 0, 1 }));
            Assert.That(persisted.Repositories.Select(repo => repo.Name), Is.EqualTo(new[] { "third", "extra" }));
            Assert.That(persisted.Repositories.Single(repo => repo.Name == "third").Url, Is.EqualTo("https://example.invalid/third.tar.gz"));
        }

        [Test]
        public void AddRepositoryRejectsDuplicateNameAndUrlInDisposableRegistry()
        {
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var repositoryData = new RepositoryDataManager();
            using (var registry = RegistryManager.Instance(
                       instance.KSP,
                       repositoryData,
                       new[] { new Repository("base", "https://example.invalid/base.tar.gz", 0) }))
            {
                registry.Save();
            }

            var provider = new CoreMackanRepositoryProvider(config, repositoryData);

            var duplicateName = Assert.Throws<System.ArgumentException>(
                () => provider.AddRepository(instance.KSP.Name, "BASE", "https://example.invalid/other.tar.gz"));
            var duplicateUrl = Assert.Throws<System.ArgumentException>(
                () => provider.AddRepository(instance.KSP.Name, "other", "https://example.invalid/base.tar.gz"));

            Assert.That(duplicateName?.Message, Is.EqualTo("Repository 'BASE' already exists."));
            Assert.That(duplicateUrl?.Message, Is.EqualTo("Repository URL 'https://example.invalid/base.tar.gz' already exists."));
        }

        [Test]
        public void ListAvailableRepositoriesLoadsCanonicalRepositoriesFromGameSource()
        {
            using var instance = new DisposableKSP("canonical-available", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var repositoryData = new RepositoryDataManager();
            var provider = new CoreMackanRepositoryProvider(config, repositoryData);

            var available = provider.ListAvailableRepositories(instance.KSP.Name);

            Assert.That(available.InstanceId, Is.EqualTo(instance.KSP.Name));
            Assert.That(available.Repositories, Is.Not.Empty);
            Assert.That(
                available.Repositories.Any(repo => repo.Name == "KSP-default"),
                Is.True);
            Assert.That(available.Repositories.Any(repo => repo.Name == "KSP-default" && repo.IsMirror),
                Is.True);
            Assert.That(
                available.Repositories.First(repo => repo.Name == "KSP-default").Url,
                Is.EqualTo("https://github.com/KSP-CKAN/CKAN-meta/archive/master.tar.gz"));
        }

        [Test]
        public void RefreshRepositoriesReturnsCapturedProgressEvents()
        {
            using var instance = new DisposableKSP("refresh", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repository = new TemporaryRepository(TestData.DogeCoinFlag_101());
            var fileRepository = new Repository(
                "temp",
                new UriBuilder(Uri.UriSchemeFile, string.Empty)
                {
                    Path = repository.uri.OriginalString,
                }.Uri);
            var repositoryData = new RepositoryDataManager();
            using (var registry = RegistryManager.Instance(
                       instance.KSP,
                       repositoryData,
                       new[] { fileRepository }))
            {
                registry.Save();
            }
            var provider = new CoreMackanRepositoryProvider(config, repositoryData);

            var refreshed = provider.RefreshRepositories(instance.KSP.Name, true);

            Assert.That(refreshed.Status, Is.EqualTo("updated"));
            Assert.That(refreshed.Events.Select(evt => evt.Kind), Does.Contain("message"));
            Assert.That(refreshed.Events.Select(evt => evt.Kind), Does.Contain("progress"));
            Assert.That(refreshed.Events.Select(evt => evt.Message), Does.Contain("Refreshing game version data"));
            Assert.That(refreshed.CompatibleModuleCount, Is.GreaterThan(0));
        }

        [Test]
        public void RefreshRepositoriesReturnsDownloadFailureDetailsForMetadataDownloadFailures()
        {
            var game = FakeGame(
                new Uri("https://example.invalid/repositories.json"),
                new Uri("https://example.invalid/default.tar.gz"),
                new GameVersion(1, 12, 5));
            using var instance = new DisposableKSP("refresh-download-failure", game.Object);
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var repositoryData = new RepositoryDataManager();
            var missingMetadataPath = Path.Combine(instance.KSP.CkanDir, "missing-repository.tar.gz");
            var brokenRepository = new Repository(
                "broken",
                new UriBuilder(Uri.UriSchemeFile, string.Empty)
                {
                    Path = missingMetadataPath,
                }.Uri);
            using (var registry = RegistryManager.Instance(
                       instance.KSP,
                       repositoryData,
                       new[] { brokenRepository }))
            {
                registry.Save();
            }
            var provider = new CoreMackanRepositoryProvider(config, repositoryData);

            var refreshed = provider.RefreshRepositories(instance.KSP.Name, true);

            Assert.That(refreshed.OperationStatus, Is.EqualTo("failed"));
            Assert.That(refreshed.Status, Is.EqualTo("failed"));
            Assert.That(refreshed.Error, Is.Not.Null.And.Not.Empty);
            Assert.That(refreshed.ErrorDetails, Is.Not.Null);
            Assert.That(refreshed.ErrorDetails!.Kind, Is.EqualTo("downloadFailures"));
            Assert.That(refreshed.ErrorDetails.SuggestedAction, Is.EqualTo("retryOrEditRepository"));
            Assert.That(refreshed.ErrorDetails.DownloadFailures, Has.Length.EqualTo(1));
            Assert.That(refreshed.ErrorDetails.DownloadFailures![0].Identifier, Is.EqualTo("broken"));
            Assert.That(refreshed.ErrorDetails.DownloadFailures[0].Name, Is.EqualTo("broken"));
            Assert.That(refreshed.ErrorDetails.DownloadFailures[0].Version, Is.EqualTo("metadata"));
            Assert.That(refreshed.ErrorDetails.DownloadFailures[0].Urls, Is.EqualTo(new[] { brokenRepository.uri.ToString() }));
            Assert.That(refreshed.ErrorDetails.DownloadFailures[0].Message, Is.Not.Empty);
        }

        private static Mock<IGame> FakeGame(Uri repoListURL, Uri defaultRepoURL, GameVersion gv)
        {
            var mock = new Mock<IGame>();
            mock.Setup(g => g.ShortName).Returns("FakeGame");
            mock.Setup(g => g.RepositoryListURL).Returns(repoListURL);
            mock.Setup(g => g.DefaultRepositoryURL).Returns(defaultRepoURL);
            mock.Setup(g => g.GameInFolder(It.IsAny<System.IO.DirectoryInfo>())).Returns(true);
            mock.Setup(g => g.CompatibleVersionsFile).Returns("dummy.txt");
            mock.Setup(g => g.PrimaryModDirectoryRelative).Returns("GameData");
            mock.Setup(g => g.DetectVersion(It.IsAny<System.IO.DirectoryInfo>())).Returns(gv);
            mock.Setup(g => g.KnownVersions).Returns(new System.Collections.Generic.List<GameVersion> { gv });
            return mock;
        }
    }
}

#endif

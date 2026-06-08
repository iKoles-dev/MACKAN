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
    public sealed class CoreMackanChangeSetProviderTests
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
        private const string ProviderC = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ProviderC"",
            ""name"": ""Provider C"",
            ""abstract"": ""First alternate virtual provider."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/provider-c.zip"",
            ""kind"": ""metapackage"",
            ""provides"": [""OtherVirtualDependency""]
        }";
        private const string ProviderD = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ProviderD"",
            ""name"": ""Provider D"",
            ""abstract"": ""Second alternate virtual provider."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/provider-d.zip"",
            ""kind"": ""metapackage"",
            ""provides"": [""OtherVirtualDependency""]
        }";
        private const string LocalMetapackage = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""LocalMetapackage"",
            ""name"": ""Local Metapackage"",
            ""abstract"": ""Metapackage with a virtual dependency."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage"",
            ""depends"": [{ ""name"": ""VirtualDependency"" }]
        }";
        private const string OtherMetapackage = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""OtherMetapackage"",
            ""name"": ""Other Metapackage"",
            ""abstract"": ""Metapackage with another virtual dependency."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage"",
            ""depends"": [{ ""name"": ""OtherVirtualDependency"" }]
        }";
        private const string ConflictA = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ConflictA"",
            ""name"": ""Conflict A"",
            ""abstract"": ""First conflicting test module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/conflict-a.zip"",
            ""kind"": ""metapackage"",
            ""conflicts"": [{ ""name"": ""ConflictB"" }]
        }";
        private const string ConflictB = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""ConflictB"",
            ""name"": ""Conflict B"",
            ""abstract"": ""Second conflicting test module."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""download"": ""https://www.nonexistent.com/conflict-b.zip"",
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
        private const string RecommendedMod = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""RecommendedMod"",
            ""name"": ""Recommended Mod"",
            ""abstract"": ""Useful optional companion."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage""
        }";
        private const string LocalRecommender = @"{
            ""spec_version"": ""v1.4"",
            ""identifier"": ""LocalRecommender"",
            ""name"": ""Local Recommender"",
            ""abstract"": ""Metapackage with an optional recommendation."",
            ""author"": ""Test"",
            ""version"": ""1.0.0"",
            ""license"": ""MIT"",
            ""ksp_version"": ""0.25"",
            ""kind"": ""metapackage"",
            ""recommends"": [{ ""name"": ""RecommendedMod"" }]
        }";

        [Test]
        public void ResolveChangesReturnsAllIndependentProviderChoices()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(
                ProviderA,
                ProviderB,
                ProviderC,
                ProviderD,
                LocalMetapackage,
                OtherMetapackage);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalMetapackage", "OtherMetapackage" },
                Array.Empty<string>(),
                Array.Empty<string>()));

            Assert.That(result.ProviderChoices, Has.Length.EqualTo(2));
            Assert.That(
                result.ProviderChoices.Select(choice => choice.Requested),
                Is.EquivalentTo(new[] { "VirtualDependency", "OtherVirtualDependency" }));
            Assert.That(
                result.ProviderChoices.Single(choice => choice.Requested == "VirtualDependency")
                    .Options.Select(option => option.Identifier),
                Is.EqualTo(new[] { "ProviderA", "ProviderB" }));
            Assert.That(
                result.ProviderChoices.Single(choice => choice.Requested == "OtherVirtualDependency")
                    .Options.Select(option => option.Identifier),
                Is.EqualTo(new[] { "ProviderC", "ProviderD" }));
        }

        [Test]
        public void ResolveChangesWithProviderSelectionsResolvesSelectedProvidersAsAutomaticInstalls()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(
                ProviderA,
                ProviderB,
                ProviderC,
                ProviderD,
                LocalMetapackage,
                OtherMetapackage);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalMetapackage", "OtherMetapackage" },
                Array.Empty<string>(),
                Array.Empty<string>(),
                providerSelections: new[]
                {
                    new MackanProviderSelection("VirtualDependency", "LocalMetapackage", "ProviderA"),
                    new MackanProviderSelection("OtherVirtualDependency", "OtherMetapackage", "ProviderC"),
                }));

            Assert.That(result.ProviderChoices, Is.Empty);
            Assert.That(
                result.Changes.Select(change => change.Identifier),
                Does.Contain("ProviderA").And.Contain("ProviderC"));
            Assert.That(result.Changes.Single(change => change.Identifier == "ProviderA").IsAuto, Is.True);
            Assert.That(result.Changes.Single(change => change.Identifier == "ProviderA").IsUserRequested, Is.False);
            Assert.That(result.Changes.Single(change => change.Identifier == "ProviderC").IsAuto, Is.True);
            Assert.That(result.Changes.Single(change => change.Identifier == "ProviderC").IsUserRequested, Is.False);
        }

        [Test]
        public void ResolveChangesReturnsConflictSummariesForConflictingSelections()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(ConflictA, ConflictB);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "ConflictA", "ConflictB" },
                Array.Empty<string>(),
                Array.Empty<string>()));

            Assert.That(result.ProviderChoices, Is.Empty);
            Assert.That(result.Conflicts.Select(conflict => conflict.Identifier), Does.Contain("ConflictA"));
            Assert.That(result.Conflicts.Single(conflict => conflict.Identifier == "ConflictA").Name, Is.EqualTo("Conflict A"));
            Assert.That(result.ConflictDescriptions, Is.Not.Empty);
            Assert.That(
                string.Join("\n", result.ConflictDescriptions),
                Does.Contain("ConflictA").And.Contain("ConflictB"));
        }

        [Test]
        public void ResolveChangesWithInstallVersionsUsesRequestedSnapshotVersion()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(HistoryRestorableOld, HistoryRestorableNew);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                Array.Empty<string>(),
                Array.Empty<string>(),
                Array.Empty<string>(),
                installVersions: new[]
                {
                    new MackanModuleVersionSelection("HistoryRestorable", "1.0.0"),
                }));

            var change = result.Changes.Single(change => change.Identifier == "HistoryRestorable");
            Assert.That(change.Action, Is.EqualTo("install"));
            Assert.That(change.ToVersion, Is.EqualTo("1.0.0"));
            Assert.That(change.IsUserRequested, Is.True);
        }

        [Test]
        public void ResolveChangesReturnsRecommendationChoicesForOptionalCompanions()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(LocalRecommender, RecommendedMod);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalRecommender" },
                Array.Empty<string>(),
                Array.Empty<string>()));

            Assert.That(result.ProviderChoices, Is.Empty);
            Assert.That(result.RecommendationChoices, Has.Length.EqualTo(1));
            Assert.That(result.RecommendationChoices[0].Kind, Is.EqualTo("recommendation"));
            Assert.That(result.RecommendationChoices[0].Identifier, Is.EqualTo("RecommendedMod"));
            Assert.That(result.RecommendationChoices[0].Dependents, Is.EqualTo(new[] { "LocalRecommender" }));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalRecommender"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Not.Contain("RecommendedMod"));
        }

        [Test]
        public void ResolveChangesWithStagedRecommendationIncludesItAsUserRequestedInstall()
        {
            var user = new NullUser();
            using var instance = new DisposableKSP();
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repo = new TemporaryRepository(LocalRecommender, RecommendedMod);
            using var repoData = new TemporaryRepositoryData(user, repo.repo);
            using var setupRegistry = RegistryManager.Instance(instance.KSP, repoData.Manager, new[] { repo.repo });

            var provider = new CoreMackanChangeSetProvider(config, repoData.Manager);

            var result = provider.ResolveChanges(new MackanChangeSetRequest(
                instance.KSP.Name,
                new[] { "LocalRecommender", "RecommendedMod" },
                Array.Empty<string>(),
                Array.Empty<string>()));

            Assert.That(result.RecommendationChoices, Is.Empty);
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("LocalRecommender"));
            Assert.That(result.Changes.Select(change => change.Identifier), Does.Contain("RecommendedMod"));
            Assert.That(result.Changes.Single(change => change.Identifier == "RecommendedMod").IsUserRequested, Is.True);
        }
    }
}

#endif

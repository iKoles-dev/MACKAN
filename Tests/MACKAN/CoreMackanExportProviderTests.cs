#if NET10_0_OR_GREATER

using System;
using System.Collections.Generic;
using System.Linq;

using CKAN;
using CKAN.MACKAN.Service;

using Newtonsoft.Json.Linq;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanExportProviderTests
    {
        [Test]
        public void ExportModpackWithRelationshipAssignmentsWritesNativeGroups()
        {
            var user = new NullUser();
            var repo = new Repository("test", "https://github.com/");
            using var instance = new DisposableKSP(TestData.TestRegistry());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            using var repoData = new TemporaryRepositoryData(user, new Dictionary<Repository, RepositoryData>
            {
                {
                    repo,
                    RepositoryData.FromJson(TestData.TestRepository(), null)!
                },
            });
            using (var registryManager = RegistryManager.Instance(
                       instance.KSP,
                       repoData.Manager,
                       new Repository[] { repo }))
            {
                registryManager.registry.RepositoriesAdd(repo);
                registryManager.Save();
            }

            var provider = new CoreMackanExportProvider(config, repoData.Manager);

            var result = provider.ExportModpack(new MackanExportModpackRequest(
                null,
                "NativeRelationshipPack",
                "Native Relationship Pack",
                "Integration coverage for native modpack relationship groups.",
                "Jeb Kerman",
                "v1",
                "MIT",
                "1.0",
                "1.12.5",
                true,
                true,
                new[]
                {
                    new MackanModpackRelationshipAssignment("DogeCoinFlag", "depends"),
                    new MackanModpackRelationshipAssignment("ModuleManager", "recommends"),
                    new MackanModpackRelationshipAssignment("RealismOverhaul", "suggests"),
                    new MackanModpackRelationshipAssignment("AJE", "ignore"),
                }));

            var exported = JObject.Parse(result.Contents);

            Assert.That(Names(exported, "depends"), Does.Contain("DogeCoinFlag"));
            Assert.That(Names(exported, "recommends"), Does.Contain("ModuleManager"));
            Assert.That(Names(exported, "suggests"), Does.Contain("RealismOverhaul"));
            Assert.That(AllRelationshipNames(exported), Does.Not.Contain("AJE"));
        }

        private static string[] Names(JObject module, string relationship)
            => module[relationship]?.Select(item => item?["name"]?.Value<string>() ?? "")
                   .Where(name => !string.IsNullOrWhiteSpace(name))
                   .ToArray()
               ?? Array.Empty<string>();

        private static string[] AllRelationshipNames(JObject module)
            => new[] { "depends", "recommends", "suggests" }
                .SelectMany(relationship => Names(module, relationship))
                .ToArray();
    }
}

#endif

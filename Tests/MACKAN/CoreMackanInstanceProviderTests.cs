#if NET10_0_OR_GREATER

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using CKAN;
using CKAN.Games.KerbalSpaceProgram;
using CKAN.MACKAN.Service;

using NUnit.Framework;

using Tests.Core.Configuration;
using Tests.Data;

namespace Tests.MACKAN
{
    [TestFixture]
    public sealed class CoreMackanInstanceProviderTests
    {
        [Test]
        public void AddInstanceRegistersDisposableKspPathAndSelectsIt()
        {
            using var instance = new DisposableKSP("addable", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(
                new List<Tuple<string, string, string>>(),
                null,
                null);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());

            var result = provider.AddInstance(instance.KSP.GameDir, "Added KSP");

            Assert.That(result.DefaultInstanceId, Is.EqualTo("Added KSP"));
            Assert.That(result.Instances.Select(inst => inst.Id), Is.EqualTo(new[] { "Added KSP" }));
            Assert.That(result.Instances[0].Path, Is.EqualTo(instance.KSP.GameDir));
            Assert.That(result.Instances[0].Game, Is.EqualTo("KSP"));
            Assert.That(result.Instances[0].IsValid, Is.True);
            Assert.That(config.GetInstances().Select(inst => inst.Item1), Is.EqualTo(new[] { "Added KSP" }));
        }

        [Test]
        public void RenameSetDefaultAndRemoveUseDisposableConfiguration()
        {
            using var first = new DisposableKSP("primary", new KerbalSpaceProgram());
            using var second = new DisposableKSP("secondary", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(
                new List<Tuple<string, string, string>>
                {
                    Tuple.Create(first.KSP.Name, first.KSP.GameDir, first.KSP.Game.ShortName),
                    Tuple.Create(second.KSP.Name, second.KSP.GameDir, second.KSP.Game.ShortName),
                },
                first.KSP.Name,
                null);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());

            var renamed = provider.RenameInstance(second.KSP.Name, "renamed");
            var madeDefault = provider.SetDefaultInstance("renamed");
            var removed = provider.RemoveInstance("renamed");

            Assert.That(renamed.Instances.Select(inst => inst.Id), Is.EqualTo(new[] { first.KSP.Name, "renamed" }));
            Assert.That(renamed.Instances.Single(inst => inst.Id == "renamed").Path, Is.EqualTo(second.KSP.GameDir));
            Assert.That(madeDefault.DefaultInstanceId, Is.EqualTo("renamed"));
            Assert.That(madeDefault.Instances.Single(inst => inst.Id == "renamed").IsDefault, Is.True);
            Assert.That(removed.Instances.Select(inst => inst.Id), Is.EqualTo(new[] { first.KSP.Name }));
            Assert.That(removed.DefaultInstanceId, Is.EqualTo(first.KSP.Name));
            Assert.That(config.GetInstances().Select(inst => inst.Item1), Is.EqualTo(new[] { first.KSP.Name }));
        }

        [Test]
        public void CloneInstanceCopiesDisposableKspAndConfiguredLaunchOptions()
        {
            using var source = new DisposableKSP("source", new KerbalSpaceProgram());
            using var destination = new TemporaryDirectory();
            Directory.Delete(destination.Directory.FullName, true);
            using var config = new FakeConfiguration(source.KSP, source.KSP.Name);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());
            File.WriteAllText(
                Path.Combine(source.KSP.CkanDir, "GUIConfig.json"),
                @"{ ""CommandLines"": [ ""./KSP.app/Contents/MacOS/KSP -popupwindow"" ] }");

            var cloned = provider.CloneInstance(
                source.KSP.Name,
                "Cloned KSP",
                destination.Directory.FullName,
                false,
                Array.Empty<string>());
            var launchOptions = provider.LaunchOptions("Cloned KSP");

            Assert.That(cloned.DefaultInstanceId, Is.EqualTo("Cloned KSP"));
            Assert.That(cloned.Instances.Select(inst => inst.Id), Is.EquivalentTo(new[] { source.KSP.Name, "Cloned KSP" }));
            Assert.That(cloned.Instances.Single(inst => inst.Id == "Cloned KSP").Path, Is.EqualTo(destination.Directory.FullName));
            Assert.That(Directory.Exists(Path.Combine(destination.Directory.FullName, "GameData")), Is.True);
            Assert.That(launchOptions.CommandLines, Is.EqualTo(new[] { "./KSP.app/Contents/MacOS/KSP -popupwindow" }));
        }

        [Test]
        public void LaunchOptionsReadLegacyXmlCommandLineArgumentsFromDisposableKsp()
        {
            using var instance = new DisposableKSP("legacy", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());
            File.WriteAllText(
                Path.Combine(instance.KSP.CkanDir, "GUIConfig.xml"),
                TestData.ConfigurationFile());

            var launchOptions = provider.LaunchOptions(instance.KSP.Name);

            Assert.That(
                launchOptions.CommandLines,
                Is.EqualTo(new[]
                {
                    "KSP.exe -force-opengl",
                    "./KSP.app/Contents/MacOS/KSP",
                }));
        }

        [Test]
        public void FakeInstanceCreatesDisposableKspFolderWithDlcAndDefault()
        {
            using var existing = new DisposableKSP("existing", new KerbalSpaceProgram());
            using var fakeDir = new TemporaryDirectory();
            using var config = new FakeConfiguration(existing.KSP, existing.KSP.Name);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());

            var result = provider.FakeInstance(
                "Fake KSP",
                fakeDir.Directory.FullName,
                "1.12.5",
                "KSP",
                "1.0.0",
                "1.0.0",
                true);

            Assert.That(result.DefaultInstanceId, Is.EqualTo("Fake KSP"));
            Assert.That(result.Instances.Select(inst => inst.Id), Is.EqualTo(new[] { existing.KSP.Name, "Fake KSP" }));
            Assert.That(result.Instances.Single(inst => inst.Id == "Fake KSP").IsDefault, Is.True);
            Assert.That(File.Exists(Path.Combine(fakeDir.Directory.FullName, "buildID.txt")), Is.True);
            Assert.That(Directory.Exists(Path.Combine(fakeDir.Directory.FullName, "GameData")), Is.True);
            Assert.That(Directory.Exists(Path.Combine(fakeDir.Directory.FullName, "GameData", "SquadExpansion", "MakingHistory")), Is.True);
            Assert.That(Directory.Exists(Path.Combine(fakeDir.Directory.FullName, "GameData", "SquadExpansion", "Serenity")), Is.True);
        }

        [Test]
        public void LaunchGameThrowsWhenCommandCannotStart()
        {
            using var instance = new DisposableKSP("launch", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());

            Assert.That(
                () => provider.LaunchGame(instance.KSP.Name, "missing-ksp-launch-binary", false),
                Throws.TypeOf<MackanLaunchFailureException>().With.Message.Contains("Failed to launch game with command"));
        }

        [Test]
        public void UpdateLaunchOptionsTrimsDistinctsAndPersistsInGuiConfig()
        {
            using var instance = new DisposableKSP("launch", new KerbalSpaceProgram());
            using var config = new FakeConfiguration(instance.KSP, instance.KSP.Name);
            var provider = new CoreMackanInstanceProvider(config, new RepositoryDataManager());

            var updated = provider.UpdateLaunchOptions(
                instance.KSP.Name,
                new[]
                {
                    " ./KSP.app/Contents/MacOS/KSP -popupwindow ",
                    "steam://run/220200",
                    "",
                    "./KSP.app/Contents/MacOS/KSP -popupwindow",
                    "./KSP.app/Contents/MacOS/KSP -popupwindow",
                });

            var launched = provider.LaunchOptions(instance.KSP.Name);
            var savedConfig = File.ReadAllText(Path.Combine(instance.KSP.CkanDir, "GUIConfig.json"));

            Assert.That(updated.CommandLines, Is.EqualTo(new[]
            {
                "./KSP.app/Contents/MacOS/KSP -popupwindow",
                "steam://run/220200",
            }));
            Assert.That(updated.DefaultCommandLines, Is.EqualTo(launched.DefaultCommandLines));
            Assert.That(updated.IncompatibleModules, Is.Empty);
            Assert.That(launched.CommandLines, Is.EqualTo(updated.CommandLines));
            Assert.That(savedConfig, Does.Contain("CommandLines"));
            Assert.That(savedConfig, Does.Contain("./KSP.app/Contents/MacOS/KSP -popupwindow"));
            Assert.That(savedConfig, Does.Contain("steam://run/220200"));
        }
    }
}

#endif

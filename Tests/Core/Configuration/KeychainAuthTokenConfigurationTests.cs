using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Linq;

using CKAN;
using CKAN.Configuration;
using CKAN.Games;

using NUnit.Framework;

namespace Tests.Core.Configuration
{
    [TestFixture]
    public sealed class KeychainAuthTokenConfigurationTests
    {
        [Test]
        public void SetAuthTokenStoresSecretInKeychainAndOnlyMarkerInInnerConfig()
        {
            var inner = new InMemoryConfiguration();
            var store = new InMemoryAuthTokenSecretStore();
            var config = new KeychainAuthTokenConfiguration(inner, store);

            config.SetAuthToken("github.com", "abcdef123456");

            Assert.That(store.Tokens["github.com"], Is.EqualTo("abcdef123456"));
            Assert.That(inner.RawAuthTokens["github.com"], Is.EqualTo(KeychainAuthTokenConfiguration.StoredInKeychainMarker));
            Assert.That(config.GetAuthTokenHosts().ToArray(), Is.EqualTo(new[] { "github.com" }));
            Assert.That(config.TryGetAuthToken("github.com", out var token), Is.True);
            Assert.That(token, Is.EqualTo("abcdef123456"));
        }

        [Test]
        public void RemoveAuthTokenDeletesSecretAndHostMarker()
        {
            var inner = new InMemoryConfiguration();
            var store = new InMemoryAuthTokenSecretStore();
            var config = new KeychainAuthTokenConfiguration(inner, store);
            config.SetAuthToken("github.com", "abcdef123456");

            config.SetAuthToken("github.com", null);

            Assert.That(store.Tokens.ContainsKey("github.com"), Is.False);
            Assert.That(inner.RawAuthTokens.ContainsKey("github.com"), Is.False);
            Assert.That(config.TryGetAuthToken("github.com", out _), Is.False);
        }

        [Test]
        public void TryGetAuthTokenMigratesExistingRawConfigTokenToKeychain()
        {
            var inner = new InMemoryConfiguration();
            inner.SetAuthToken("api.github.com", "legacy-token");
            var store = new InMemoryAuthTokenSecretStore();
            var config = new KeychainAuthTokenConfiguration(inner, store);

            Assert.That(config.TryGetAuthToken("api.github.com", out var token), Is.True);

            Assert.That(token, Is.EqualTo("legacy-token"));
            Assert.That(store.Tokens["api.github.com"], Is.EqualTo("legacy-token"));
            Assert.That(inner.RawAuthTokens["api.github.com"], Is.EqualTo(KeychainAuthTokenConfiguration.StoredInKeychainMarker));
        }

        [Test]
        public void TryGetAuthTokenReturnsLegacyConfigTokenIfMigrationFails()
        {
            var inner = new InMemoryConfiguration();
            inner.SetAuthToken("api.github.com", "legacy-token");
            var store = new InMemoryAuthTokenSecretStore { FailWrites = true };
            var config = new KeychainAuthTokenConfiguration(inner, store);

            Assert.That(config.TryGetAuthToken("api.github.com", out var token), Is.True);

            Assert.That(token, Is.EqualTo("legacy-token"));
            Assert.That(inner.RawAuthTokens["api.github.com"], Is.EqualTo("legacy-token"));
        }

        private sealed class InMemoryAuthTokenSecretStore : IAuthTokenSecretStore
        {
            public readonly Dictionary<string, string> Tokens = new Dictionary<string, string>();
            public bool FailWrites { get; set; }

            public bool TryGetToken(string host, [NotNullWhen(true)] out string? token)
                => Tokens.TryGetValue(host, out token);

            public void SetToken(string host, string token)
            {
                if (FailWrites)
                {
                    throw new InvalidOperationException("Simulated Keychain failure.");
                }
                Tokens[host] = token;
            }

            public void DeleteToken(string host)
                => Tokens.Remove(host);
        }

        private sealed class InMemoryConfiguration : IConfiguration
        {
            public readonly Dictionary<string, string> RawAuthTokens = new Dictionary<string, string>();

            public string? AutoStartInstance { get; set; }
            public string? DownloadCacheDir { get; set; }
            public long? CacheSizeLimit { get; set; }
            public int RefreshRate { get; set; }
            public string? Language { get; set; }
            public string?[] PreferredHosts { get; set; } = Array.Empty<string>();
            public bool? DevBuilds { get; set; }

            public IEnumerable<string> GetAuthTokenHosts()
                => RawAuthTokens.Keys;

            public bool TryGetAuthToken(string host, [NotNullWhen(true)] out string? token)
                => RawAuthTokens.TryGetValue(host, out token);

            public void SetAuthToken(string host, string? token)
            {
                if (token == null)
                {
                    RawAuthTokens.Remove(host);
                }
                else
                {
                    RawAuthTokens[host] = token;
                }
            }

            public void SetRegistryToInstances(SortedList<string, GameInstance> instances)
            {
            }

            public IEnumerable<Tuple<string, string, string>> GetInstances()
                => Enumerable.Empty<Tuple<string, string, string>>();

            public string[] GetGlobalInstallFilters(IGame game)
                => Array.Empty<string>();

            public void SetGlobalInstallFilters(IGame game, string[] value)
            {
            }

            #pragma warning disable CS0067
            public event PropertyChangedEventHandler? PropertyChanged;
            #pragma warning restore CS0067
        }
    }
}

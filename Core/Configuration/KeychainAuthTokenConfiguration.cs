using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

using CKAN.Games;

namespace CKAN.Configuration
{
    public interface IAuthTokenSecretStore
    {
        bool TryGetToken(string host, [NotNullWhen(true)] out string? token);
        void SetToken(string host, string token);
        void DeleteToken(string host);
    }

    public sealed class KeychainAuthTokenConfiguration : IConfiguration
    {
        public const string StoredInKeychainMarker = "__MACKAN_KEYCHAIN_AUTH_TOKEN__";

        private readonly IConfiguration inner;
        private readonly IAuthTokenSecretStore tokenStore;

        public KeychainAuthTokenConfiguration(IConfiguration inner, IAuthTokenSecretStore tokenStore)
        {
            this.inner      = inner;
            this.tokenStore = tokenStore;
        }

        public string? AutoStartInstance
        {
            get => inner.AutoStartInstance;
            set => inner.AutoStartInstance = value;
        }

        public string? DownloadCacheDir
        {
            get => inner.DownloadCacheDir;
            set => inner.DownloadCacheDir = value;
        }

        public long? CacheSizeLimit
        {
            get => inner.CacheSizeLimit;
            set => inner.CacheSizeLimit = value;
        }

        public int RefreshRate
        {
            get => inner.RefreshRate;
            set => inner.RefreshRate = value;
        }

        public string? Language
        {
            get => inner.Language;
            set => inner.Language = value;
        }

        public string?[] PreferredHosts
        {
            get => inner.PreferredHosts;
            set => inner.PreferredHosts = value;
        }

        public bool? DevBuilds
        {
            get => inner.DevBuilds;
            set => inner.DevBuilds = value;
        }

        public IEnumerable<string> GetAuthTokenHosts()
            => inner.GetAuthTokenHosts().Distinct();

        public bool TryGetAuthToken(string host, [NotNullWhen(true)] out string? token)
        {
            if (tokenStore.TryGetToken(host, out token))
            {
                return true;
            }

            if (!inner.TryGetAuthToken(host, out var innerToken)
                || innerToken == StoredInKeychainMarker)
            {
                token = null;
                return false;
            }

            try
            {
                tokenStore.SetToken(host, innerToken);
                inner.SetAuthToken(host, StoredInKeychainMarker);
            }
            catch (Exception)
            {
                token = innerToken;
                return true;
            }
            token = innerToken;
            return true;
        }

        public void SetAuthToken(string host, string? token)
        {
            if (string.IsNullOrEmpty(token))
            {
                tokenStore.DeleteToken(host);
                inner.SetAuthToken(host, null);
            }
            else
            {
                tokenStore.SetToken(host, token);
                inner.SetAuthToken(host, StoredInKeychainMarker);
            }
        }

        public void SetRegistryToInstances(SortedList<string, GameInstance> instances)
            => inner.SetRegistryToInstances(instances);

        public IEnumerable<Tuple<string, string, string>> GetInstances()
            => inner.GetInstances();

        public string[] GetGlobalInstallFilters(IGame game)
            => inner.GetGlobalInstallFilters(game);

        public void SetGlobalInstallFilters(IGame game, string[] value)
            => inner.SetGlobalInstallFilters(game, value);

        public event PropertyChangedEventHandler? PropertyChanged
        {
            add    => inner.PropertyChanged += value;
            remove => inner.PropertyChanged -= value;
        }
    }

    public sealed class MacOSKeychainAuthTokenSecretStore : IAuthTokenSecretStore
    {
        private const string ServiceName         = "org.ksp-ckan.mackan.auth-token";
        private const string SecurityFramework  = "/System/Library/Frameworks/Security.framework/Security";
        private const string CoreFoundation     = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
        private const string LibSystem          = "/usr/lib/libSystem.dylib";
        private const int    ErrSecSuccess      = 0;
        private const int    ErrSecItemNotFound = -25300;
        private const int    ErrSecDuplicate    = -25299;
        private const int    RtldLazy           = 1;
        private const uint   Utf8Encoding       = 0x08000100;

        public bool TryGetToken(string host, [NotNullWhen(true)] out string? token)
        {
            using var query = CreateBaseQuery(host);
            query.SetConstant(KSecReturnData, KCFBooleanTrue);
            query.SetConstant(KSecMatchLimit, KSecMatchLimitOne);

            var status = SecItemCopyMatching(query.Handle, out var result);
            if (status == ErrSecItemNotFound)
            {
                token = null;
                return false;
            }

            CheckStatus(status, "read auth token from macOS Keychain");
            try
            {
                token = StringFromCFData(result);
                return token != null;
            }
            finally
            {
                if (result != IntPtr.Zero)
                {
                    CFRelease(result);
                }
            }
        }

        public void SetToken(string host, string token)
        {
            using var query = CreateBaseQuery(host);
            using var update = new CFMutableDictionary();
            update.SetData(KSecValueData, Encoding.UTF8.GetBytes(token));

            var status = SecItemUpdate(query.Handle, update.Handle);
            if (status == ErrSecItemNotFound)
            {
                using var add = CreateBaseQuery(host);
                add.SetData(KSecValueData, Encoding.UTF8.GetBytes(token));
                status = SecItemAdd(add.Handle, out var result);
                if (result != IntPtr.Zero)
                {
                    CFRelease(result);
                }
            }
            if (status == ErrSecDuplicate)
            {
                status = SecItemUpdate(query.Handle, update.Handle);
            }
            CheckStatus(status, "write auth token to macOS Keychain");
        }

        public void DeleteToken(string host)
        {
            using var query = CreateBaseQuery(host);
            var status = SecItemDelete(query.Handle);
            if (status != ErrSecItemNotFound)
            {
                CheckStatus(status, "delete auth token from macOS Keychain");
            }
        }

        private static CFMutableDictionary CreateBaseQuery(string host)
        {
            var query = new CFMutableDictionary();
            query.SetConstant(KSecClass, KSecClassGenericPassword);
            query.SetString(KSecAttrService, ServiceName);
            query.SetString(KSecAttrAccount, host);
            return query;
        }

        private static string? StringFromCFData(IntPtr data)
        {
            if (data == IntPtr.Zero)
            {
                return null;
            }

            var length = CFDataGetLength(data);
            if (length <= 0 || length > int.MaxValue)
            {
                return null;
            }

            var bytes = new byte[length];
            Marshal.Copy(CFDataGetBytePtr(data), bytes, 0, (int)length);
            return Encoding.UTF8.GetString(bytes);
        }

        private static void CheckStatus(int status, string operation)
        {
            if (status != ErrSecSuccess)
            {
                throw new InvalidOperationException($"Unable to {operation}. Keychain status: {status}.");
            }
        }

        private sealed class CFMutableDictionary : IDisposable
        {
            public CFMutableDictionary()
            {
                Handle = CFDictionaryCreateMutable(
                    IntPtr.Zero,
                    IntPtr.Zero,
                    KCFTypeDictionaryKeyCallBacks,
                    KCFTypeDictionaryValueCallBacks);
                if (Handle == IntPtr.Zero)
                {
                    throw new InvalidOperationException("Unable to create CoreFoundation dictionary.");
                }
            }

            public IntPtr Handle { get; }

            public void SetConstant(IntPtr key, IntPtr value)
                => CFDictionarySetValue(Handle, key, value);

            public void SetString(IntPtr key, string value)
            {
                var cfString = CFStringCreateWithCString(IntPtr.Zero, value, Utf8Encoding);
                if (cfString == IntPtr.Zero)
                {
                    throw new InvalidOperationException("Unable to create CoreFoundation string.");
                }

                try
                {
                    CFDictionarySetValue(Handle, key, cfString);
                }
                finally
                {
                    CFRelease(cfString);
                }
            }

            public void SetData(IntPtr key, byte[] value)
            {
                var cfData = CFDataCreate(IntPtr.Zero, value, (IntPtr)value.Length);
                if (cfData == IntPtr.Zero)
                {
                    throw new InvalidOperationException("Unable to create CoreFoundation data.");
                }

                try
                {
                    CFDictionarySetValue(Handle, key, cfData);
                }
                finally
                {
                    CFRelease(cfData);
                }
            }

            public void Dispose()
            {
                if (Handle != IntPtr.Zero)
                {
                    CFRelease(Handle);
                }
            }
        }

        private static IntPtr ReadCFStringConstant(string symbol)
            => Marshal.ReadIntPtr(FindSymbol(SecurityFramework, symbol));

        private static IntPtr ReadCoreFoundationConstant(string symbol)
            => Marshal.ReadIntPtr(FindSymbol(CoreFoundation, symbol));

        private static IntPtr FindCoreFoundationStruct(string symbol)
            => FindSymbol(CoreFoundation, symbol);

        private static IntPtr FindSymbol(string library, string symbol)
        {
            var libraryHandle = dlopen(library, RtldLazy);
            if (libraryHandle == IntPtr.Zero)
            {
                throw new InvalidOperationException($"Unable to open native library: {library}");
            }

            var symbolHandle = dlsym(libraryHandle, symbol);
            if (symbolHandle == IntPtr.Zero)
            {
                throw new InvalidOperationException($"Unable to find native symbol: {symbol}");
            }
            return symbolHandle;
        }

        private static readonly IntPtr KSecClass                  = ReadCFStringConstant("kSecClass");
        private static readonly IntPtr KSecClassGenericPassword   = ReadCFStringConstant("kSecClassGenericPassword");
        private static readonly IntPtr KSecAttrService            = ReadCFStringConstant("kSecAttrService");
        private static readonly IntPtr KSecAttrAccount            = ReadCFStringConstant("kSecAttrAccount");
        private static readonly IntPtr KSecValueData              = ReadCFStringConstant("kSecValueData");
        private static readonly IntPtr KSecReturnData             = ReadCFStringConstant("kSecReturnData");
        private static readonly IntPtr KSecMatchLimit             = ReadCFStringConstant("kSecMatchLimit");
        private static readonly IntPtr KSecMatchLimitOne          = ReadCFStringConstant("kSecMatchLimitOne");
        private static readonly IntPtr KCFBooleanTrue             = ReadCoreFoundationConstant("kCFBooleanTrue");
        private static readonly IntPtr KCFTypeDictionaryKeyCallBacks   = FindCoreFoundationStruct("kCFTypeDictionaryKeyCallBacks");
        private static readonly IntPtr KCFTypeDictionaryValueCallBacks = FindCoreFoundationStruct("kCFTypeDictionaryValueCallBacks");

        [DllImport(SecurityFramework)]
        private static extern int SecItemCopyMatching(IntPtr query, out IntPtr result);

        [DllImport(SecurityFramework)]
        private static extern int SecItemAdd(IntPtr attributes, out IntPtr result);

        [DllImport(SecurityFramework)]
        private static extern int SecItemUpdate(IntPtr query, IntPtr attributesToUpdate);

        [DllImport(SecurityFramework)]
        private static extern int SecItemDelete(IntPtr query);

        [DllImport(CoreFoundation)]
        private static extern IntPtr CFStringCreateWithCString(IntPtr allocator, string value, uint encoding);

        [DllImport(CoreFoundation)]
        private static extern IntPtr CFDataCreate(IntPtr allocator, byte[] bytes, IntPtr length);

        [DllImport(CoreFoundation)]
        private static extern int CFDataGetLength(IntPtr data);

        [DllImport(CoreFoundation)]
        private static extern IntPtr CFDataGetBytePtr(IntPtr data);

        [DllImport(CoreFoundation)]
        private static extern IntPtr CFDictionaryCreateMutable(
            IntPtr allocator,
            IntPtr capacity,
            IntPtr keyCallbacks,
            IntPtr valueCallbacks);

        [DllImport(CoreFoundation)]
        private static extern void CFDictionarySetValue(IntPtr dictionary, IntPtr key, IntPtr value);

        [DllImport(CoreFoundation)]
        private static extern void CFRelease(IntPtr value);

        [DllImport(LibSystem)]
        private static extern IntPtr dlopen(string path, int mode);

        [DllImport(LibSystem)]
        private static extern IntPtr dlsym(IntPtr handle, string symbol);
    }
}

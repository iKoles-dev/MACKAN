using System;
using System.Linq;

namespace CKAN.MACKAN.Service
{
    internal static class MackanProviderChoiceFactory
    {
        public static MackanProviderChoice From(TooManyModsProvideKraken kraken)
            => new MackanProviderChoice(
                kraken.requested,
                kraken.Message,
                kraken.requester.identifier,
                ModuleName(kraken.requester),
                kraken.modules
                    .Select(module => new MackanProviderOption(
                        module.identifier,
                        ModuleName(module),
                        module.version.ToString(),
                        module.@abstract ?? ""))
                    .OrderBy(option => option.Name, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(option => option.Identifier, StringComparer.OrdinalIgnoreCase)
                    .ToArray());

        private static string ModuleName(CkanModule module)
            => string.IsNullOrWhiteSpace(module.name) ? module.identifier : module.name;
    }
}

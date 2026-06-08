using System;
using System.Collections.Generic;
using System.Linq;

namespace CKAN.MACKAN.Service
{
    internal static class MackanRecommendationChoiceFactory
    {
        public static MackanRecommendationChoice[] From(
            Dictionary<CkanModule, Tuple<bool, List<string>>> recommendations,
            Dictionary<CkanModule, List<string>> suggestions,
            Dictionary<CkanModule, HashSet<string>> supporters)
            => recommendations
                .Select(kvp => ToRecommendationChoice(
                    "recommendation",
                    kvp.Key,
                    kvp.Value.Item2,
                    kvp.Value.Item1))
                .Concat(suggestions.Select(kvp => ToRecommendationChoice(
                    "suggestion",
                    kvp.Key,
                    kvp.Value,
                    false)))
                .Concat(supporters.Select(kvp => ToRecommendationChoice(
                    "supporter",
                    kvp.Key,
                    kvp.Value.Order(StringComparer.OrdinalIgnoreCase),
                    false)))
                .OrderBy(choice => RecommendationKindOrder(choice.Kind))
                .ThenBy(choice => choice.Name, StringComparer.OrdinalIgnoreCase)
                .ThenBy(choice => choice.Identifier, StringComparer.OrdinalIgnoreCase)
                .ToArray();

        private static MackanRecommendationChoice ToRecommendationChoice(
            string kind,
            CkanModule module,
            IEnumerable<string> dependents,
            bool isRecommendedDefault)
            => new MackanRecommendationChoice(
                kind,
                module.identifier,
                ModuleName(module),
                module.version.ToString(),
                module.@abstract ?? "",
                dependents
                    .Where(dependent => !string.IsNullOrWhiteSpace(dependent))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .Order(StringComparer.OrdinalIgnoreCase)
                    .ToArray(),
                isRecommendedDefault);

        private static int RecommendationKindOrder(string kind)
            => kind switch
            {
                "recommendation" => 0,
                "suggestion"     => 1,
                "supporter"      => 2,
                _                => 3,
            };

        private static string ModuleName(CkanModule module)
            => string.IsNullOrWhiteSpace(module.name) ? module.identifier : module.name;
    }
}

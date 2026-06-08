using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CKAN.MACKAN.Service
{
    internal static class MackanGuiConfigStore
    {
        public static MackanGeneralGuiSettings GeneralSettings(GameInstance instance)
        {
            var configObject = Load(instance);
            return new MackanGeneralGuiSettings(
                configObject["CheckForUpdatesOnLaunch"]?.GetValue<bool>() ?? false,
                configObject["RefreshOnStartup"]?.GetValue<bool>() ?? true,
                configObject["AutoSortByUpdate"]?.GetValue<bool>() ?? true);
        }

        public static void SetGeneralSettings(
            GameInstance instance,
            bool checkForUpdatesOnLaunch,
            bool refreshRepositoriesOnLaunch,
            bool autoSortByUpdate)
        {
            Directory.CreateDirectory(instance.CkanDir);
            var configObject = Load(instance);
            configObject["CheckForUpdatesOnLaunch"] = checkForUpdatesOnLaunch;
            configObject["RefreshOnStartup"] = refreshRepositoriesOnLaunch;
            configObject["AutoSortByUpdate"] = autoSortByUpdate;
            Save(instance, configObject);
        }

        public static bool SuppressRecommendations(GameInstance instance)
        {
            var configObject = Load(instance);
            return configObject["SuppressRecommendations"]?.GetValue<bool>() ?? false;
        }

        public static void SetSuppressRecommendations(GameInstance instance, bool suppressRecommendations)
        {
            Directory.CreateDirectory(instance.CkanDir);
            var configObject = Load(instance);
            configObject["SuppressRecommendations"] = suppressRecommendations;
            Save(instance, configObject);
        }

        private static JsonObject Load(GameInstance instance)
        {
            var configPath = ConfigPath(instance);
            if (!File.Exists(configPath))
            {
                return new JsonObject();
            }

            try
            {
                return JsonNode.Parse(File.ReadAllText(configPath)) as JsonObject
                    ?? new JsonObject();
            }
            catch (JsonException)
            {
                return new JsonObject();
            }
        }

        private static void Save(GameInstance instance, JsonObject configObject)
            => File.WriteAllText(ConfigPath(instance), configObject.ToJsonString(new JsonSerializerOptions
            {
                WriteIndented = true,
            }));

        private static string ConfigPath(GameInstance instance)
            => Path.Combine(instance.CkanDir, "GUIConfig.json");
    }

    internal sealed class MackanGeneralGuiSettings
    {
        public MackanGeneralGuiSettings(
            bool checkForUpdatesOnLaunch,
            bool refreshRepositoriesOnLaunch,
            bool autoSortByUpdate)
        {
            CheckForUpdatesOnLaunch = checkForUpdatesOnLaunch;
            RefreshRepositoriesOnLaunch = refreshRepositoriesOnLaunch;
            AutoSortByUpdate = autoSortByUpdate;
        }

        public bool CheckForUpdatesOnLaunch { get; }
        public bool RefreshRepositoriesOnLaunch { get; }
        public bool AutoSortByUpdate { get; }
    }
}

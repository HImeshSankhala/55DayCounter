namespace FiftyFiveDayCounter.App;

internal static class AppPaths
{
    public static string ResolveDataPath()
    {
        var basePath = Path.Combine(AppContext.BaseDirectory, "guests.json");
        if (File.Exists(basePath))
        {
            return basePath;
        }

        var cwdPath = Path.Combine(Environment.CurrentDirectory, "guests.json");
        if (File.Exists(cwdPath))
        {
            return cwdPath;
        }

        var appData = ResolveAppDataDirectory();
        return Path.Combine(appData, "guests.json");
    }

    public static string ResolveSettingsPath()
    {
        return Path.Combine(ResolveAppDataDirectory(), "settings.json");
    }

    public static string ResolveIconPath()
    {
        return Path.Combine(AppContext.BaseDirectory, ProductInfo.IconFileName);
    }

    public static string ResolveNotificationLogPath()
    {
        return Path.Combine(ResolveAppDataDirectory(), "notification-check.log");
    }

    public static string ResolveExecutablePath()
    {
        return Environment.ProcessPath ?? Application.ExecutablePath;
    }

    private static string ResolveAppDataDirectory()
    {
        var appData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), ProductInfo.AppDataFolder);
        Directory.CreateDirectory(appData);
        return appData;
    }
}

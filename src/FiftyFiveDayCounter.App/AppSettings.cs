using System.Text.Json;
using System.Text.Json.Serialization;
using FiftyFiveDayCounter.Core;

namespace FiftyFiveDayCounter.App;

internal sealed class AppSettings
{
    public bool NotificationPermissionPromptShown { get; set; }
    public bool ScheduledNotificationsEnabled { get; set; }
    public bool ScheduleHasBeenConfigured { get; set; }
    public string ScheduledNotificationTime { get; set; } = "09:00";
    public int CycleLengthDays { get; set; } = CycleRules.DefaultCycleLengthDays;

    [JsonIgnore]
    public TimeSpan ScheduledTime
    {
        get => TimeSpan.TryParse(ScheduledNotificationTime, out var value) ? value : new TimeSpan(9, 0, 0);
        set => ScheduledNotificationTime = value.ToString(@"hh\:mm");
    }

    public static AppSettings Load()
    {
        var path = AppPaths.ResolveSettingsPath();
        if (!File.Exists(path))
        {
            return new AppSettings();
        }

        try
        {
            var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path)) ?? new AppSettings();
            settings.CycleLengthDays = Math.Clamp(settings.CycleLengthDays, CycleRules.MinimumCycleLengthDays, CycleRules.MaximumCycleLengthDays);
            return settings;
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save()
    {
        var path = AppPaths.ResolveSettingsPath();
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
    }
}

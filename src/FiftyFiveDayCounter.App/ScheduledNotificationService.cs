namespace FiftyFiveDayCounter.App;

internal static class ScheduledNotificationService
{
    private const string TaskName = ProductInfo.TaskName;

    public static string Configure(TimeSpan time, bool enabled)
    {
        var executablePath = AppPaths.ResolveExecutablePath();
        if (!File.Exists(executablePath)
            || Path.GetExtension(executablePath).Equals(".dll", StringComparison.OrdinalIgnoreCase)
            || Path.GetFileName(executablePath).Equals("dotnet.exe", StringComparison.OrdinalIgnoreCase))
        {
            return "Schedule can be saved after the app is published as an .exe. Run it from the published DaysCounter app and try again.";
        }

        try
        {
            RegisterTask(executablePath, time, enabled);
            return enabled
                ? $"Scheduled notifications are ON. Windows will check daily at {DateTime.Today.Add(time):h:mm tt}, even when the app window is closed."
                : "Scheduled notifications are OFF. The Windows task exists, but it will not run until you open Schedule, check Enable, and save.";
        }
        catch (Exception ex)
        {
            return $"Could not save scheduled notifications. Windows returned: {ex.Message}";
        }
    }

    private static void RegisterTask(string executablePath, TimeSpan time, bool enabled)
    {
        var serviceType = Type.GetTypeFromProgID("Schedule.Service")
            ?? throw new InvalidOperationException("Windows Task Scheduler service is not available.");
        dynamic service = Activator.CreateInstance(serviceType)
            ?? throw new InvalidOperationException("Windows Task Scheduler service could not be started.");

        service.Connect();
        dynamic rootFolder = service.GetFolder("\\");
        DeleteTaskIfPresent(rootFolder, ProductInfo.LegacyTaskName);
        dynamic task = service.NewTask(0);

        task.RegistrationInfo.Description = "Checks DaysCounter guests and shows checkout reminders.";
        task.Principal.LogonType = 3; // TASK_LOGON_INTERACTIVE_TOKEN
        task.Principal.RunLevel = 0; // TASK_RUNLEVEL_LUA

        task.Settings.Enabled = enabled;
        task.Settings.StartWhenAvailable = true;
        task.Settings.AllowDemandStart = true;
        task.Settings.DisallowStartIfOnBatteries = false;
        task.Settings.StopIfGoingOnBatteries = false;
        task.Settings.ExecutionTimeLimit = "PT5M";

        dynamic trigger = task.Triggers.Create(2); // TASK_TRIGGER_DAILY
        trigger.StartBoundary = DateTime.Today.Add(time).ToString("yyyy-MM-ddTHH:mm:ss");
        trigger.DaysInterval = 1;
        trigger.Enabled = enabled;

        dynamic action = task.Actions.Create(0); // TASK_ACTION_EXEC
        action.Path = executablePath;
        action.Arguments = "--check-notifications";

        rootFolder.RegisterTaskDefinition(TaskName, task, 6, null, null, 3); // TASK_CREATE_OR_UPDATE, TASK_LOGON_INTERACTIVE_TOKEN
    }

    private static void DeleteTaskIfPresent(dynamic rootFolder, string taskName)
    {
        try
        {
            rootFolder.DeleteTask(taskName, 0);
        }
        catch
        {
            // The legacy task is optional cleanup; absence is the normal case.
        }
    }
}

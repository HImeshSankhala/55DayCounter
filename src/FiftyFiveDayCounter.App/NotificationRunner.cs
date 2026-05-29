using FiftyFiveDayCounter.Core;
using FiftyFiveDayCounter.Storage;
using System.Diagnostics;

namespace FiftyFiveDayCounter.App;

internal static class NotificationRunner
{
    public static void RunScheduledCheck()
    {
        try
        {
            WriteLog("Scheduled check started.");
            var repository = new JsonGuestRepository(AppPaths.ResolveDataPath());
            var guests = repository.Load().ToList();
            var today = DateTime.Today;
            var dueGuests = guests
                .Where(g => CycleRules.IsNotificationEligible(g, today))
                .OrderBy(g => g.CheckOutDate)
                .ThenBy(g => g.RoomNumber)
                .ToList();

            WriteLog($"Eligible guests: {dueGuests.Count}.");
            if (dueGuests.Count == 0)
            {
                return;
            }

            using var notifyIcon = new NotifyIcon
            {
                Icon = File.Exists(AppPaths.ResolveIconPath()) ? new Icon(AppPaths.ResolveIconPath()) : SystemIcons.Information,
                Text = "55 Day Counter",
                Visible = true,
                BalloonTipTitle = "55 Day Counter",
                BalloonTipText = FormatNotificationList(dueGuests, today)
            };

            notifyIcon.BalloonTipClicked += (_, _) => OpenTodayList();
            notifyIcon.ShowBalloonTip(15000);
            WriteLog("Notification requested.");
            Application.DoEvents();
            Thread.Sleep(60000);
        }
        catch (Exception ex)
        {
            WriteLog($"Scheduled check failed: {ex}");
        }
    }

    public static string FormatNotificationList(IReadOnlyList<GuestCycle> guests, DateTime today)
    {
        var lines = guests
            .Take(4)
            .Select(g => $"Rm {g.RoomNumber}: {g.GuestName} - {CycleRules.FormatDaysLeft(g, today)}")
            .ToList();

        if (guests.Count > 4)
        {
            lines.Add($"+ {guests.Count - 4} more in Today's List");
        }

        return string.Join(Environment.NewLine, lines);
    }

    private static void OpenTodayList()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = AppPaths.ResolveExecutablePath(),
                Arguments = "--today-list",
                UseShellExecute = true
            });
        }
        catch
        {
            // Notification click is best-effort. The next app open still has Today's List.
        }
    }

    private static void WriteLog(string message)
    {
        var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {message}";
        File.AppendAllLines(AppPaths.ResolveNotificationLogPath(), [line]);
    }
}

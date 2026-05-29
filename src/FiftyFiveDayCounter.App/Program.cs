namespace FiftyFiveDayCounter.App;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        if (args.Any(arg => arg.Equals("--check-notifications", StringComparison.OrdinalIgnoreCase)))
        {
            NotificationRunner.RunScheduledCheck();
            return;
        }

        var openTodayList = args.Any(arg => arg.Equals("--today-list", StringComparison.OrdinalIgnoreCase));
        Application.Run(new MainForm(openTodayList));
    }    
}

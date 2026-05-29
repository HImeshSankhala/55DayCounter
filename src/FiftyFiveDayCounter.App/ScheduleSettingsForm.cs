namespace FiftyFiveDayCounter.App;

internal sealed class ScheduleSettingsForm : Form
{
    private readonly CheckBox _enabled = new();
    private readonly DateTimePicker _timePicker = new();

    public ScheduleSettingsForm(AppSettings settings)
    {
        Text = "Notification Schedule";
        StartPosition = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(450, 220);
        Font = new Font("Segoe UI", 10);

        _enabled.Text = "Enable daily scheduled notification check";
        _enabled.Location = new Point(18, 18);
        _enabled.Size = new Size(360, 28);
        _enabled.Checked = !settings.ScheduleHasBeenConfigured || settings.ScheduledNotificationsEnabled;

        var timeLabel = new Label { Text = "Daily check time", Location = new Point(18, 64), AutoSize = true };
        _timePicker.Format = DateTimePickerFormat.Time;
        _timePicker.ShowUpDown = true;
        _timePicker.Location = new Point(150, 60);
        _timePicker.Size = new Size(110, 26);
        _timePicker.Value = DateTime.Today.Add(settings.ScheduledTime);

        var note = new Label
        {
            Text = "Keep this enabled if you want reminders even when the main app window is closed.",
            Location = new Point(18, 105),
            Size = new Size(405, 42)
        };

        var saveButton = new Button { Text = "Save", Location = new Point(240, 165), Size = new Size(90, 32), DialogResult = DialogResult.OK };
        var cancelButton = new Button { Text = "Cancel", Location = new Point(340, 165), Size = new Size(90, 32), DialogResult = DialogResult.Cancel };
        Controls.AddRange([_enabled, timeLabel, _timePicker, note, saveButton, cancelButton]);
        AcceptButton = saveButton;
        CancelButton = cancelButton;
    }

    public bool ScheduledNotificationsEnabled => _enabled.Checked;
    public TimeSpan ScheduledTime => _timePicker.Value.TimeOfDay;
}

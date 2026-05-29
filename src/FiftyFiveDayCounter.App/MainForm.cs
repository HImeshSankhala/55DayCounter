using FiftyFiveDayCounter.Core;
using FiftyFiveDayCounter.Storage;

namespace FiftyFiveDayCounter.App;

public sealed class MainForm : Form
{
    private readonly JsonGuestRepository _repository;
    private readonly List<GuestCycle> _guests;
    private readonly AppSettings _settings;
    private readonly DataGridView _grid = new();
    private readonly TextBox _searchBox = new();
    private readonly ComboBox _statusFilter = new();
    private readonly Label _summaryLabel = new();
    private readonly NotifyIcon _notifyIcon = new();
    private readonly System.Windows.Forms.Timer _notificationTimer = new();
    private readonly bool _openTodayListOnShown;

    public MainForm(bool openTodayListOnShown = false)
    {
        _openTodayListOnShown = openTodayListOnShown;
        Text = "55 Day Counter";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(1050, 640);
        Size = new Size(1180, 720);
        Font = new Font("Segoe UI", 10);
        AutoScaleMode = AutoScaleMode.Dpi;

        var iconPath = AppPaths.ResolveIconPath();
        if (File.Exists(iconPath))
        {
            Icon = new Icon(iconPath);
            _notifyIcon.Icon = new Icon(iconPath);
        }
        else
        {
            _notifyIcon.Icon = SystemIcons.Information;
        }
        _notifyIcon.Text = "55 Day Counter";
        _notifyIcon.Visible = true;
        _notifyIcon.BalloonTipClicked += (_, _) => ShowTodaysList();

        _notificationTimer.Interval = 60 * 60 * 1000;
        _notificationTimer.Tick += (_, _) => CheckAlerts(manual: false);
        _notificationTimer.Start();

        _settings = AppSettings.Load();
        _repository = new JsonGuestRepository(AppPaths.ResolveDataPath());
        _guests = _repository.Load().ToList();
        if (_guests.Count == 0)
        {
            _repository.Save(_guests);
        }

        BuildUi();
        RefreshGrid();
    }

    private void BuildUi()
    {
        var topPanel = new Panel
        {
            Dock = DockStyle.Top,
            Height = 198,
            Padding = new Padding(14)
        };

        var title = new Label
        {
            Text = "55 Day Counter",
            Font = new Font("Segoe UI Semibold", 17),
            Location = new Point(14, 12),
            Size = new Size(300, 34)
        };

        var help = new Label
        {
            Text = "Phase 2 .NET preview. Check-in is day 1; 55th day is check-in + 54 days.",
            Location = new Point(16, 52),
            Size = new Size(900, 24)
        };

        _summaryLabel.Location = new Point(16, 80);
        _summaryLabel.Size = new Size(1000, 24);

        var searchLabel = new Label { Text = "Search", Location = new Point(16, 116), AutoSize = true };
        _searchBox.Location = new Point(76, 112);
        _searchBox.Size = new Size(230, 26);
        _searchBox.TextChanged += (_, _) => RefreshGrid();

        var filterLabel = new Label { Text = "Status", Location = new Point(326, 116), AutoSize = true };
        _statusFilter.DropDownStyle = ComboBoxStyle.DropDownList;
        _statusFilter.Location = new Point(386, 112);
        _statusFilter.Size = new Size(150, 26);
        _statusFilter.Items.Add("All");
        _statusFilter.Items.AddRange(CycleStatus.All);
        _statusFilter.SelectedIndex = 0;
        _statusFilter.SelectedIndexChanged += (_, _) => RefreshGrid();

        var buttons = new FlowLayoutPanel
        {
            Location = new Point(16, 148),
            Size = new Size(1120, 38),
            Anchor = AnchorStyles.Left | AnchorStyles.Top | AnchorStyles.Right,
            WrapContents = false,
            Margin = Padding.Empty,
            Padding = Padding.Empty
        };

        AddButton(buttons, "Add Guest", (_, _) => AddGuest(), 105);
        AddButton(buttons, "Edit", (_, _) => EditSelectedGuest(), 85);
        AddButton(buttons, "Complete", (_, _) => SetSelectedStatus(CycleStatus.Completed), 95);
        AddButton(buttons, "Cancel Cycle", (_, _) => SetSelectedStatus(CycleStatus.Canceled), 110);
        AddButton(buttons, "Check Alerts", (_, _) => CheckAlerts(manual: true), 105);
        AddButton(buttons, "Test Alert", (_, _) => ShowTestNotification(), 95);
        AddButton(buttons, "Schedule", (_, _) => ShowScheduleSettings(), 95);
        AddButton(buttons, "Today's List", (_, _) => ShowTodaysList(), 110);
        AddButton(buttons, "Export CSV", (_, _) => ExportCsv(), 105);

        topPanel.Controls.AddRange([title, help, _summaryLabel, searchLabel, _searchBox, filterLabel, _statusFilter, buttons]);

        _grid.Dock = DockStyle.Fill;
        _grid.AllowUserToAddRows = false;
        _grid.AllowUserToDeleteRows = false;
        _grid.ReadOnly = true;
        _grid.MultiSelect = false;
        _grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        _grid.RowHeadersVisible = false;
        _grid.BackgroundColor = Color.White;
        _grid.SelectionChanged += (_, _) => _grid.Invalidate();
        _grid.RowPostPaint += PaintSelectedRowBorder;
        _grid.SortCompare += GridSortCompare;
        _grid.CellDoubleClick += (_, args) =>
        {
            if (args.RowIndex >= 0)
            {
                EditSelectedGuest();
            }
        };

        AddColumn("Id", "Id", 45, false);
        AddColumn("Status", "Status", 90, true);
        AddColumn("GuestName", "Guest Name", 170, true);
        AddColumn("RoomNumber", "Room", 75, true);
        AddColumn("CheckInDate", "Check-in", 105, true);
        AddColumn("CheckOutDate", "55th Day", 105, true);
        AddColumn("NotifyDate", "Notify", 105, true);
        AddColumn("DaysLeft", "Days Left", 95, true);
        AddColumn("Notes", "Notes", 240, true);

        var legend = new Label
        {
            Dock = DockStyle.Bottom,
            Height = 30,
            Padding = new Padding(12, 6, 0, 0),
            Text = "Blue: active    Yellow: within 5 days    Orange: due today    Red: overdue    Green: completed    Gray: canceled"
        };

        Controls.Add(_grid);
        Controls.Add(legend);
        Controls.Add(topPanel);
    }

    private static void AddButton(Control parent, string text, EventHandler onClick, int width)
    {
        var button = new Button
        {
            Text = text,
            Size = new Size(width, 32),
            Margin = new Padding(0, 0, 8, 0)
        };
        button.Click += onClick;
        parent.Controls.Add(button);
    }

    private void AddColumn(string name, string header, float fillWeight, bool visible)
    {
        _grid.Columns.Add(new DataGridViewTextBoxColumn
        {
            Name = name,
            HeaderText = header,
            FillWeight = fillWeight,
            Visible = visible,
            SortMode = DataGridViewColumnSortMode.Automatic
        });
    }

    private static void GridSortCompare(object? sender, DataGridViewSortCompareEventArgs e)
    {
        if (e.Column.Name == "RoomNumber")
        {
            e.SortResult = CompareRoomNumbers(e.CellValue1?.ToString() ?? string.Empty, e.CellValue2?.ToString() ?? string.Empty);
            e.Handled = true;
            return;
        }

        if (e.Column.Name is "CheckInDate" or "CheckOutDate" or "NotifyDate"
            && DateTime.TryParse(e.CellValue1?.ToString(), out var leftDate)
            && DateTime.TryParse(e.CellValue2?.ToString(), out var rightDate))
        {
            e.SortResult = DateTime.Compare(leftDate, rightDate);
            e.Handled = true;
            return;
        }

        e.SortResult = string.Compare(e.CellValue1?.ToString(), e.CellValue2?.ToString(), StringComparison.OrdinalIgnoreCase);
        e.Handled = true;
    }

    private static int CompareRoomNumbers(string left, string right)
    {
        if (int.TryParse(left, out var leftNumber) && int.TryParse(right, out var rightNumber))
        {
            return leftNumber.CompareTo(rightNumber);
        }

        return string.Compare(left, right, StringComparison.OrdinalIgnoreCase);
    }

    private void RefreshGrid()
    {
        var today = DateTime.Today;
        _grid.Rows.Clear();

        var filter = _statusFilter.SelectedItem?.ToString() ?? "All";
        var search = _searchBox.Text.Trim();

        foreach (var guest in _guests.OrderBy(g => g.CheckOutDate).ThenBy(g => g.RoomNumber))
        {
            var status = CycleRules.GetDisplayStatus(guest, today);
            guest.Status = status;

            if (filter != "All" && status != filter)
            {
                continue;
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var haystack = $"{guest.GuestName} {guest.RoomNumber} {guest.Notes}";
                if (!haystack.Contains(search, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
            }

            var rowIndex = _grid.Rows.Add(
                guest.Id,
                status,
                guest.GuestName,
                guest.RoomNumber,
                guest.CheckInDate.ToString("MM/dd/yyyy"),
                guest.CheckOutDate.ToString("MM/dd/yyyy"),
                guest.NotifyDate.ToString("MM/dd/yyyy"),
                CycleRules.FormatDaysLeft(guest, today),
                guest.Notes);

            ApplyRowStatusStyle(_grid.Rows[rowIndex], status);
        }

        var active = _guests.Count(g => CycleRules.GetDisplayStatus(g, today) == CycleStatus.Active);
        var dueSoon = _guests.Count(g => CycleRules.GetDisplayStatus(g, today) == CycleStatus.DueSoon);
        var dueToday = _guests.Count(g => CycleRules.GetDisplayStatus(g, today) == CycleStatus.DueToday);
        var overdue = _guests.Count(g => CycleRules.GetDisplayStatus(g, today) == CycleStatus.Overdue);
        _summaryLabel.Text = $"Active: {active}    Due soon: {dueSoon}    Due today: {dueToday}    Overdue: {overdue}    Total records: {_guests.Count}";
    }

    private void CheckAlerts(bool manual)
    {
        var today = DateTime.Today;
        var dueGuests = _guests
            .Where(g => CycleRules.IsNotificationEligible(g, today))
            .OrderBy(g => g.CheckOutDate)
            .ThenBy(g => g.RoomNumber)
            .ToList();

        if (dueGuests.Count == 0)
        {
            if (manual)
            {
                MessageBox.Show(this, "No overdue guests or guests due in the next 5 days.", "55 Day Counter");
            }
            return;
        }

        _notifyIcon.BalloonTipTitle = "55 Day Counter";
        _notifyIcon.BalloonTipText = NotificationRunner.FormatNotificationList(dueGuests, today);
        _notifyIcon.ShowBalloonTip(8000);

    }

    private void ShowTestNotification()
    {
        _notifyIcon.BalloonTipTitle = "55 Day Counter Test";
        _notifyIcon.BalloonTipText = "Notifications are working. Click this notification to open Today's List.";
        _notifyIcon.ShowBalloonTip(8000);
    }

    private void ShowScheduleSettings()
    {
        using var dialog = new ScheduleSettingsForm(_settings);
        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        _settings.ScheduledNotificationsEnabled = dialog.ScheduledNotificationsEnabled;
        _settings.ScheduleHasBeenConfigured = true;
        _settings.ScheduledTime = new TimeSpan(dialog.ScheduledTime.Hours, dialog.ScheduledTime.Minutes, 0);
        _settings.Save();

        var result = ScheduledNotificationService.Configure(_settings.ScheduledTime, _settings.ScheduledNotificationsEnabled);
        MessageBox.Show(this, result, "Notification Schedule");
    }

    private void PromptForNotificationPermissionIfNeeded()
    {
        if (_settings.NotificationPermissionPromptShown)
        {
            return;
        }

        _settings.NotificationPermissionPromptShown = true;
        _settings.Save();

        var result = MessageBox.Show(
            this,
            "55 Day Counter needs Windows notifications for checkout reminders. A test notification will be sent now. If you do not see it, open Windows Notification settings and allow notifications for this app.",
            "Enable Notifications",
            MessageBoxButtons.OKCancel,
            MessageBoxIcon.Information);

        if (result != DialogResult.OK)
        {
            return;
        }

        ShowTestNotification();

        var openSettings = MessageBox.Show(
            this,
            "Did the test notification appear? Click No to open Windows Notification settings.",
            "Enable Notifications",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question);

        if (openSettings == DialogResult.No)
        {
            OpenWindowsNotificationSettings();
        }
    }

    private static void OpenWindowsNotificationSettings()
    {
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "ms-settings:notifications",
                UseShellExecute = true
            });
        }
        catch
        {
            MessageBox.Show("Open Windows Settings > System > Notifications and allow notifications for 55 Day Counter.", "55 Day Counter");
        }
    }

    private static void ApplyRowStatusStyle(DataGridViewRow row, string status)
    {
        var color = status switch
        {
            CycleStatus.Active => Color.FromArgb(232, 244, 255),
            CycleStatus.DueSoon => Color.FromArgb(255, 245, 204),
            CycleStatus.DueToday => Color.FromArgb(255, 226, 190),
            CycleStatus.Overdue => Color.FromArgb(255, 222, 222),
            CycleStatus.Completed => Color.FromArgb(224, 245, 224),
            CycleStatus.Canceled => Color.FromArgb(232, 232, 232),
            _ => Color.White
        };

        row.DefaultCellStyle.BackColor = color;
        row.DefaultCellStyle.SelectionBackColor = color;
        row.DefaultCellStyle.SelectionForeColor = Color.Black;
    }

    private void PaintSelectedRowBorder(object? sender, DataGridViewRowPostPaintEventArgs e)
    {
        if (!_grid.Rows[e.RowIndex].Selected)
        {
            return;
        }

        using var pen = new Pen(Color.FromArgb(0, 92, 170), 2);
        var bounds = new Rectangle(0, e.RowBounds.Top, _grid.ClientSize.Width - 1, e.RowBounds.Height - 1);
        bounds.Inflate(-1, -1);
        e.Graphics.DrawRectangle(pen, bounds);
    }

    private GuestCycle? SelectedGuest()
    {
        if (_grid.SelectedRows.Count == 0)
        {
            return null;
        }

        var id = Convert.ToInt32(_grid.SelectedRows[0].Cells["Id"].Value);
        return _guests.FirstOrDefault(g => g.Id == id);
    }

    private void AddGuest()
    {
        using var dialog = new GuestDialog();
        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        var conflict = CycleRules.FindActiveRoomConflict(_guests, dialog.RoomNumber, 0, DateTime.Today);
        if (conflict is not null && MessageBox.Show(this,
                $"Room {dialog.RoomNumber} already has an active cycle for {conflict.GuestName}. Add this guest anyway?",
                "55 Day Counter",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            return;
        }

        var nextId = _guests.Count == 0 ? 1 : _guests.Max(g => g.Id) + 1;
        _guests.Add(CycleRules.CreateGuest(nextId, dialog.GuestName, dialog.RoomNumber, dialog.CheckInDate, dialog.Notes));
        SaveAndRefresh();
    }

    private void EditSelectedGuest()
    {
        var guest = SelectedGuest();
        if (guest is null)
        {
            MessageBox.Show(this, "Select a guest first.", "55 Day Counter");
            return;
        }

        using var dialog = new GuestDialog(guest);
        if (dialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        var conflict = CycleRules.FindActiveRoomConflict(_guests, dialog.RoomNumber, guest.Id, DateTime.Today);
        if (conflict is not null && MessageBox.Show(this,
                $"Room {dialog.RoomNumber} already has an active cycle for {conflict.GuestName}. Save this edit anyway?",
                "55 Day Counter",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning) != DialogResult.Yes)
        {
            return;
        }

        CycleRules.ApplyEditableFields(guest, dialog.GuestName, dialog.RoomNumber, dialog.CheckInDate, dialog.Notes);
        SaveAndRefresh();
    }

    private void SetSelectedStatus(string status)
    {
        var guest = SelectedGuest();
        if (guest is null)
        {
            MessageBox.Show(this, "Select a guest first.", "55 Day Counter");
            return;
        }

        var action = status == CycleStatus.Completed ? "complete" : "cancel";
        var result = MessageBox.Show(
            this,
            $"This will permanently remove {guest.GuestName} in room {guest.RoomNumber} from the active list and database. Continue?",
            $"Confirm {action}",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning);

        if (result != DialogResult.Yes)
        {
            return;
        }

        _guests.Remove(guest);
        SaveAndRefresh();
    }

    private void SaveAndRefresh()
    {
        _repository.Save(_guests);
        RefreshGrid();
    }

    private void ShowTodaysList()
    {
        var today = DateTime.Today;
        var rows = _guests
            .Where(g => CycleRules.IsTodayListEligible(g, today))
            .OrderBy(g => g.CheckOutDate)
            .ThenBy(g => g.RoomNumber)
            .ToList();

        using var form = new TodayListForm(rows);
        form.ShowDialog(this);
    }

    private void ExportCsv()
    {
        using var saveDialog = new SaveFileDialog
        {
            Filter = "CSV files (*.csv)|*.csv",
            DefaultExt = "csv",
            AddExtension = true,
            FileName = $"55-day-counter-active-guests-{DateTime.Today:yyyy-MM-dd}.csv"
        };

        if (saveDialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        var fileName = Path.ChangeExtension(saveDialog.FileName, ".csv");
        using var writer = new StreamWriter(fileName);
        writer.WriteLine($"Report Date,{DateTime.Today:MM/dd/yyyy}");
        writer.WriteLine("Report,Active Guest List");
        writer.WriteLine();
        writer.WriteLine("GuestName,RoomNumber,CheckInDate,CheckOutDate,NotifyDate,Status,Notes");
        var activeGuests = _grid.Rows
            .Cast<DataGridViewRow>()
            .Where(row => !row.IsNewRow)
            .Select(row => Convert.ToInt32(row.Cells["Id"].Value))
            .Select(id => _guests.First(g => g.Id == id))
            .Where(g => CycleRules.GetDisplayStatus(g, DateTime.Today) is CycleStatus.Active or CycleStatus.DueSoon or CycleStatus.DueToday or CycleStatus.Overdue);

        foreach (var guest in activeGuests)
        {
            var values = new[]
            {
                guest.GuestName,
                guest.RoomNumber,
                guest.CheckInDate.ToString("MM/dd/yyyy"),
                guest.CheckOutDate.ToString("MM/dd/yyyy"),
                guest.NotifyDate.ToString("MM/dd/yyyy"),
                CycleRules.GetDisplayStatus(guest, DateTime.Today),
                guest.Notes
            };
            writer.WriteLine(string.Join(",", values.Select(EscapeCsv)));
        }

        MessageBox.Show(this, "Export complete.", "55 Day Counter");
    }

    private static string EscapeCsv(string value)
    {
        return $"\"{value.Replace("\"", "\"\"")}\"";
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        PromptForNotificationPermissionIfNeeded();
        CheckAlerts(manual: false);
        if (_openTodayListOnShown)
        {
            BeginInvoke(ShowTodaysList);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _notificationTimer.Dispose();
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }
        base.Dispose(disposing);
    }
}

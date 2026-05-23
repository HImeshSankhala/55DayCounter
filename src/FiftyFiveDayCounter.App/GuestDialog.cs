using FiftyFiveDayCounter.Core;

namespace FiftyFiveDayCounter.App;

public sealed class GuestDialog : Form
{
    private readonly TextBox _nameBox = new();
    private readonly TextBox _roomBox = new();
    private readonly DateTimePicker _checkInPicker = new();
    private readonly Label _checkoutValue = new();
    private readonly Label _notifyValue = new();
    private readonly TextBox _notesBox = new();

    public GuestDialog(GuestCycle? guest = null)
    {
        Text = guest is null ? "Add Guest" : "Edit Guest";
        StartPosition = FormStartPosition.CenterParent;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ClientSize = new Size(430, 330);
        Font = new Font("Segoe UI", 10);

        AddLabel("Guest name", 16, 18);
        _nameBox.Location = new Point(140, 14);
        _nameBox.Size = new Size(260, 26);

        AddLabel("Room number", 16, 58);
        _roomBox.Location = new Point(140, 54);
        _roomBox.Size = new Size(260, 26);

        AddLabel("Check-in date", 16, 98);
        _checkInPicker.Format = DateTimePickerFormat.Short;
        _checkInPicker.Location = new Point(140, 94);
        _checkInPicker.Size = new Size(140, 26);
        _checkInPicker.ValueChanged += (_, _) => UpdateCalculatedDates();

        AddLabel("55th day", 16, 138);
        _checkoutValue.Location = new Point(140, 138);
        _checkoutValue.Size = new Size(260, 24);

        AddLabel("Notify on", 16, 174);
        _notifyValue.Location = new Point(140, 174);
        _notifyValue.Size = new Size(260, 24);

        AddLabel("Notes", 16, 212);
        _notesBox.Location = new Point(140, 208);
        _notesBox.Size = new Size(260, 62);
        _notesBox.Multiline = true;
        _notesBox.ScrollBars = ScrollBars.Vertical;

        var saveButton = new Button { Text = "Save", Location = new Point(244, 288), Size = new Size(75, 30) };
        saveButton.Click += (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(_nameBox.Text) || string.IsNullOrWhiteSpace(_roomBox.Text))
            {
                MessageBox.Show(this, "Guest name and room number are required.", "55 Day Counter");
                return;
            }

            DialogResult = DialogResult.OK;
            Close();
        };

        var closeButton = new Button { Text = "Close", Location = new Point(325, 288), Size = new Size(75, 30), DialogResult = DialogResult.Cancel };

        Controls.AddRange([_nameBox, _roomBox, _checkInPicker, _checkoutValue, _notifyValue, _notesBox, saveButton, closeButton]);
        AcceptButton = saveButton;
        CancelButton = closeButton;

        if (guest is not null)
        {
            _nameBox.Text = guest.GuestName;
            _roomBox.Text = guest.RoomNumber;
            _checkInPicker.Value = guest.CheckInDate;
            _notesBox.Text = guest.Notes;
        }
        else
        {
            _checkInPicker.Value = DateTime.Today;
        }

        UpdateCalculatedDates();
    }

    public string GuestName => _nameBox.Text.Trim();
    public string RoomNumber => _roomBox.Text.Trim();
    public DateTime CheckInDate => _checkInPicker.Value.Date;
    public string Notes => _notesBox.Text.Trim();

    private void AddLabel(string text, int x, int y)
    {
        Controls.Add(new Label { Text = text, Location = new Point(x, y), AutoSize = true });
    }

    private void UpdateCalculatedDates()
    {
        var dates = CycleRules.GetCycleDates(_checkInPicker.Value);
        _checkoutValue.Text = dates.CheckOutDate.ToString("dddd, MMM d, yyyy");
        _notifyValue.Text = dates.NotifyDate.ToString("dddd, MMM d, yyyy");
    }
}

using System.Text;
using FiftyFiveDayCounter.Core;

namespace FiftyFiveDayCounter.App;

public sealed class TodayListForm : Form
{
    private readonly IReadOnlyList<GuestCycle> _guests;
    private readonly DataGridView _grid = new();

    public TodayListForm(IReadOnlyList<GuestCycle> guests)
    {
        _guests = guests;
        Text = "Today's List";
        StartPosition = FormStartPosition.CenterParent;
        MinimumSize = new Size(860, 420);
        Size = new Size(980, 560);
        Font = new Font("Segoe UI", 10);

        BuildUi();
        LoadRows();
    }

    private void BuildUi()
    {
        var top = new Panel { Dock = DockStyle.Top, Height = 64 };
        top.Controls.Add(new Label
        {
            Text = "Overdue guests, today, and the next 5 days",
            Font = new Font("Segoe UI Semibold", 13),
            Location = new Point(12, 10),
            Size = new Size(620, 26)
        });
        top.Controls.Add(new Label { Text = $"{_guests.Count} guest(s) found", Location = new Point(14, 38), Size = new Size(260, 22) });

        var downloadButton = new Button { Text = "Download Excel", Size = new Size(130, 32), Anchor = AnchorStyles.Top | AnchorStyles.Right, Location = new Point(704, 16) };
        downloadButton.Click += (_, _) => DownloadExcel();
        var closeButton = new Button { Text = "Close", Size = new Size(90, 32), Anchor = AnchorStyles.Top | AnchorStyles.Right, Location = new Point(842, 16), DialogResult = DialogResult.Cancel };
        top.Controls.AddRange([downloadButton, closeButton]);

        _grid.Dock = DockStyle.Fill;
        _grid.AllowUserToAddRows = false;
        _grid.AllowUserToDeleteRows = false;
        _grid.ReadOnly = true;
        _grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
        _grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
        _grid.RowHeadersVisible = false;
        _grid.BackgroundColor = Color.White;

        AddColumn("Status", "Status", 90);
        AddColumn("GuestName", "Guest Name", 170);
        AddColumn("RoomNumber", "Room", 75);
        AddColumn("CheckInDate", "Check-in", 105);
        AddColumn("CheckOutDate", "Checkout", 105);
        AddColumn("DaysLeft", "Days Left", 95);
        AddColumn("Notes", "Notes", 240);

        Controls.Add(_grid);
        Controls.Add(top);
        CancelButton = closeButton;
    }

    private void AddColumn(string name, string header, float fillWeight)
    {
        _grid.Columns.Add(new DataGridViewTextBoxColumn { Name = name, HeaderText = header, FillWeight = fillWeight });
    }

    private void LoadRows()
    {
        foreach (var guest in _guests)
        {
            var status = CycleRules.GetDisplayStatus(guest, DateTime.Today);
            var rowIndex = _grid.Rows.Add(
                status,
                guest.GuestName,
                guest.RoomNumber,
                guest.CheckInDate.ToString("MM/dd/yyyy"),
                guest.CheckOutDate.ToString("MM/dd/yyyy"),
                CycleRules.FormatDaysLeft(guest, DateTime.Today),
                guest.Notes);
            MainFormApplyStyle(_grid.Rows[rowIndex], status);
        }
    }

    private static void MainFormApplyStyle(DataGridViewRow row, string status)
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

    private void DownloadExcel()
    {
        if (_guests.Count == 0)
        {
            MessageBox.Show(this, "There are no overdue guests or guests checking out today or in the next 5 days.", "Today's List");
            return;
        }

        using var saveDialog = new SaveFileDialog
        {
            Filter = "Excel files (*.xls)|*.xls",
            FileName = $"dayscounter-today-list-{DateTime.Today:yyyy-MM-dd}.xls"
        };

        if (saveDialog.ShowDialog(this) != DialogResult.OK)
        {
            return;
        }

        File.WriteAllText(saveDialog.FileName, BuildSpreadsheetXml());
        MessageBox.Show(this, "Excel file saved.", "Today's List");
    }

    private string BuildSpreadsheetXml()
    {
        var builder = new StringBuilder();
        builder.AppendLine("""<?xml version="1.0"?>""");
        builder.AppendLine("""<?mso-application progid="Excel.Sheet"?>""");
        builder.AppendLine("""<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">""");
        builder.AppendLine("""<Worksheet ss:Name="Today List"><Table>""");
        WriteRow(builder, ["Status", "Guest Name", "Room", "Check-in", "Checkout", "Days Left", "Notes"]);
        foreach (var guest in _guests)
        {
            WriteRow(builder,
            [
                CycleRules.GetDisplayStatus(guest, DateTime.Today),
                guest.GuestName,
                guest.RoomNumber,
                guest.CheckInDate.ToString("MM/dd/yyyy"),
                guest.CheckOutDate.ToString("MM/dd/yyyy"),
                CycleRules.FormatDaysLeft(guest, DateTime.Today),
                guest.Notes
            ]);
        }

        builder.AppendLine("</Table></Worksheet></Workbook>");
        return builder.ToString();
    }

    private static void WriteRow(StringBuilder builder, IEnumerable<string> values)
    {
        builder.AppendLine("<Row>");
        foreach (var value in values)
        {
            builder.Append("<Cell><Data ss:Type=\"String\">");
            builder.Append(System.Security.SecurityElement.Escape(value));
            builder.AppendLine("</Data></Cell>");
        }
        builder.AppendLine("</Row>");
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$Script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:DataPath = Join-Path $Script:AppDir "guests.json"
$Script:IconPath = Join-Path $Script:AppDir "55DayCounter.ico"
$Script:Guests = New-Object System.Collections.ArrayList
$Script:NextId = 1
$Script:CanSave = $true
$Script:AppMutex = New-Object System.Threading.Mutex($false, "55DayCounterAppRunning")
if (-not $Script:AppMutex.WaitOne(0)) {
    [System.Windows.Forms.MessageBox]::Show(
        "55 Day Counter is already open.",
        "55 Day Counter",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    $Script:AppMutex.Dispose()
    exit
}

function Invoke-WithDataLock {
    param([scriptblock]$Action)

    $mutex = New-Object System.Threading.Mutex($false, "55DayCounterDataLock")
    $hasLock = $false
    try {
        $hasLock = $mutex.WaitOne(10000)
        if (-not $hasLock) {
            throw "Could not access the guest database because it is busy. Please try again."
        }
        & $Action
    }
    finally {
        if ($hasLock) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Get-CycleDates {
    param([datetime]$CheckIn)

    $checkout = $CheckIn.Date.AddDays(54)
    [pscustomobject]@{
        CheckOut = $checkout
        NotifyOn = $checkout.AddDays(-5)
    }
}

function Get-GuestStatus {
    param($Guest)

    if ($Guest.Status -eq "Completed") { return "Completed" }
    if ($Guest.Status -eq "Canceled") { return "Canceled" }

    $today = (Get-Date).Date
    $checkout = ([datetime]$Guest.CheckOutDate).Date
    $daysLeft = ($checkout - $today).Days

    if ($daysLeft -lt 0) { return "Overdue" }
    if ($daysLeft -eq 0) { return "Due Today" }
    if ($daysLeft -le 5) { return "Due Soon" }
    return "Active"
}

function Get-StatusColor {
    param([string]$Status)

    switch ($Status) {
        "Active" { return [System.Drawing.Color]::FromArgb(232, 244, 255) }
        "Due Soon" { return [System.Drawing.Color]::FromArgb(255, 245, 204) }
        "Due Today" { return [System.Drawing.Color]::FromArgb(255, 226, 190) }
        "Overdue" { return [System.Drawing.Color]::FromArgb(255, 222, 222) }
        "Completed" { return [System.Drawing.Color]::FromArgb(224, 245, 224) }
        "Canceled" { return [System.Drawing.Color]::FromArgb(232, 232, 232) }
        default { return [System.Drawing.Color]::White }
    }
}

function Save-Guests {
    if (-not $Script:CanSave) {
        [System.Windows.Forms.MessageBox]::Show(
            "Guest data was not saved because the database could not be loaded safely. Please close the app and restore or repair guests.json before making changes.",
            "55 Day Counter",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    try {
        Invoke-WithDataLock {
            $tempPath = Join-Path $Script:AppDir ("guests.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
            try {
                $Script:Guests | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tempPath -Encoding UTF8
                Move-Item -LiteralPath $tempPath -Destination $Script:DataPath -Force
            }
            finally {
                if (Test-Path $tempPath) {
                    Remove-Item -LiteralPath $tempPath -Force
                }
            }
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Guest data could not be saved.`n`n$($_.Exception.Message)",
            "55 Day Counter",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Load-Guests {
    if (-not (Test-Path $Script:DataPath)) { return }

    try {
        Invoke-WithDataLock {
            $raw = Get-Content -Path $Script:DataPath -Raw
            if ([string]::IsNullOrWhiteSpace($raw)) { return }

            $loaded = $raw | ConvertFrom-Json
            foreach ($item in @($loaded)) {
                $guest = [pscustomobject]@{
                    Id = [int]$item.Id
                    GuestName = [string]$item.GuestName
                    RoomNumber = [string]$item.RoomNumber
                    CheckInDate = ([datetime]$item.CheckInDate).Date
                    CheckOutDate = ([datetime]$item.CheckOutDate).Date
                    NotifyDate = ([datetime]$item.NotifyDate).Date
                    Status = [string]$item.Status
                    Notes = [string]$item.Notes
                    LastNotifiedFor = [string]$item.LastNotifiedFor
                }
                [void]$Script:Guests.Add($guest)
                if ($guest.Id -ge $Script:NextId) { $Script:NextId = $guest.Id + 1 }
            }
        }
    }
    catch {
        $Script:CanSave = $false
        $backupPath = Join-Path $Script:AppDir ("guests.unreadable-{0}.json" -f (Get-Date).ToString("yyyyMMdd-HHmmss"))
        try {
            if (Test-Path $Script:DataPath) {
                Copy-Item -LiteralPath $Script:DataPath -Destination $backupPath -Force
            }
        }
        catch {
            $backupPath = "Backup could not be created."
        }

        [System.Windows.Forms.MessageBox]::Show(
            "Could not read guests.json, so saving has been disabled to protect existing data.`n`nBackup: $backupPath`n`n$($_.Exception.Message)",
            "55 Day Counter",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
}

function Test-ActiveRoomConflict {
    param(
        [string]$RoomNumber,
        [int]$ExcludeId = 0
    )

    $requestedRoom = $RoomNumber.Trim()
    return $Script:Guests | Where-Object {
        $_.Id -ne $ExcludeId -and
        $_.RoomNumber.Trim().Equals($requestedRoom, [System.StringComparison]::OrdinalIgnoreCase) -and
        ((Get-GuestStatus $_) -eq "Active" -or (Get-GuestStatus $_) -eq "Due Soon" -or (Get-GuestStatus $_) -eq "Due Today" -or (Get-GuestStatus $_) -eq "Overdue")
    } | Select-Object -First 1
}

function New-Guest {
    param(
        [string]$GuestName,
        [string]$RoomNumber,
        [datetime]$CheckInDate,
        [string]$Notes
    )

    $dates = Get-CycleDates -CheckIn $CheckInDate
    [pscustomobject]@{
        Id = $Script:NextId++
        GuestName = $GuestName.Trim()
        RoomNumber = $RoomNumber.Trim()
        CheckInDate = $CheckInDate.Date
        CheckOutDate = $dates.CheckOut
        NotifyDate = $dates.NotifyOn
        Status = "Active"
        Notes = $Notes.Trim()
        LastNotifiedFor = ""
    }
}

function Show-GuestDialog {
    param($ExistingGuest)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = if ($ExistingGuest) { "Edit Guest" } else { "Add Guest" }
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(430, 330)
    $dialog.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = "Guest name"
    $nameLabel.Location = New-Object System.Drawing.Point(16, 18)
    $nameLabel.AutoSize = $true

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Location = New-Object System.Drawing.Point(140, 14)
    $nameBox.Size = New-Object System.Drawing.Size(260, 26)

    $roomLabel = New-Object System.Windows.Forms.Label
    $roomLabel.Text = "Room number"
    $roomLabel.Location = New-Object System.Drawing.Point(16, 58)
    $roomLabel.AutoSize = $true

    $roomBox = New-Object System.Windows.Forms.TextBox
    $roomBox.Location = New-Object System.Drawing.Point(140, 54)
    $roomBox.Size = New-Object System.Drawing.Size(260, 26)

    $checkInLabel = New-Object System.Windows.Forms.Label
    $checkInLabel.Text = "Check-in date"
    $checkInLabel.Location = New-Object System.Drawing.Point(16, 98)
    $checkInLabel.AutoSize = $true

    $checkInPicker = New-Object System.Windows.Forms.DateTimePicker
    $checkInPicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
    $checkInPicker.Location = New-Object System.Drawing.Point(140, 94)
    $checkInPicker.Size = New-Object System.Drawing.Size(140, 26)

    $checkoutLabel = New-Object System.Windows.Forms.Label
    $checkoutLabel.Text = "55th day"
    $checkoutLabel.Location = New-Object System.Drawing.Point(16, 138)
    $checkoutLabel.AutoSize = $true

    $checkoutValue = New-Object System.Windows.Forms.Label
    $checkoutValue.Location = New-Object System.Drawing.Point(140, 138)
    $checkoutValue.Size = New-Object System.Drawing.Size(260, 24)

    $notifyLabel = New-Object System.Windows.Forms.Label
    $notifyLabel.Text = "Notify on"
    $notifyLabel.Location = New-Object System.Drawing.Point(16, 174)
    $notifyLabel.AutoSize = $true

    $notifyValue = New-Object System.Windows.Forms.Label
    $notifyValue.Location = New-Object System.Drawing.Point(140, 174)
    $notifyValue.Size = New-Object System.Drawing.Size(260, 24)

    $notesLabel = New-Object System.Windows.Forms.Label
    $notesLabel.Text = "Notes"
    $notesLabel.Location = New-Object System.Drawing.Point(16, 212)
    $notesLabel.AutoSize = $true

    $notesBox = New-Object System.Windows.Forms.TextBox
    $notesBox.Location = New-Object System.Drawing.Point(140, 208)
    $notesBox.Size = New-Object System.Drawing.Size(260, 62)
    $notesBox.Multiline = $true
    $notesBox.ScrollBars = "Vertical"

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Save"
    $okButton.Location = New-Object System.Drawing.Point(244, 288)
    $okButton.Size = New-Object System.Drawing.Size(75, 30)
    $okButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($nameBox.Text) -or [string]::IsNullOrWhiteSpace($roomBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Guest name and room number are required.", "55 Day Counter") | Out-Null
            return
        }

        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Close"
    $cancelButton.Location = New-Object System.Drawing.Point(325, 288)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $updateCalculatedDates = {
        $dates = Get-CycleDates -CheckIn $checkInPicker.Value
        $checkoutValue.Text = $dates.CheckOut.ToString("dddd, MMM d, yyyy")
        $notifyValue.Text = $dates.NotifyOn.ToString("dddd, MMM d, yyyy")
    }
    $checkInPicker.Add_ValueChanged($updateCalculatedDates)

    if ($ExistingGuest) {
        $nameBox.Text = $ExistingGuest.GuestName
        $roomBox.Text = $ExistingGuest.RoomNumber
        $checkInPicker.Value = [datetime]$ExistingGuest.CheckInDate
        $notesBox.Text = $ExistingGuest.Notes
    }
    else {
        $checkInPicker.Value = (Get-Date).Date
    }
    & $updateCalculatedDates

    $dialog.Controls.AddRange(@(
        $nameLabel, $nameBox, $roomLabel, $roomBox, $checkInLabel, $checkInPicker,
        $checkoutLabel, $checkoutValue, $notifyLabel, $notifyValue,
        $notesLabel, $notesBox, $okButton, $cancelButton
    ))
    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    if ($dialog.ShowDialog($Script:MainForm) -ne [System.Windows.Forms.DialogResult]::OK) {
        $dialog.Dispose()
        return $null
    }

    $result = [pscustomobject]@{
        GuestName = $nameBox.Text.Trim()
        RoomNumber = $roomBox.Text.Trim()
        CheckInDate = $checkInPicker.Value.Date
        Notes = $notesBox.Text.Trim()
    }
    $dialog.Dispose()
    return $result
}

function Refresh-Grid {
    $Script:Grid.Rows.Clear()

    foreach ($guest in $Script:Guests | Sort-Object Status, CheckOutDate, RoomNumber) {
        $status = Get-GuestStatus -Guest $guest
        $guest.Status = $status
        $filter = if ($Script:FilterCombo) { [string]$Script:FilterCombo.SelectedItem } else { "All" }
        $search = if ($Script:SearchBox) { $Script:SearchBox.Text.Trim().ToLowerInvariant() } else { "" }
        $searchText = "$($guest.GuestName) $($guest.RoomNumber) $($guest.Notes)".ToLowerInvariant()
        if ($filter -and $filter -ne "All" -and $status -ne $filter) { continue }
        if ($search -and -not $searchText.Contains($search)) { continue }

        $daysLeft = (([datetime]$guest.CheckOutDate).Date - (Get-Date).Date).Days
        $displayDays = if ($status -eq "Completed" -or $status -eq "Canceled") {
            ""
        }
        elseif ($daysLeft -eq 0) {
            "Due today"
        }
        elseif ($daysLeft -lt 0) {
            "$([math]::Abs($daysLeft)) overdue"
        }
        else {
            "$daysLeft left"
        }

        $rowIndex = $Script:Grid.Rows.Add(
            $guest.Id,
            $status,
            $guest.GuestName,
            $guest.RoomNumber,
            ([datetime]$guest.CheckInDate).ToString("MM/dd/yyyy"),
            ([datetime]$guest.CheckOutDate).ToString("MM/dd/yyyy"),
            ([datetime]$guest.NotifyDate).ToString("MM/dd/yyyy"),
            $displayDays,
            $guest.Notes
        )
        $row = $Script:Grid.Rows[$rowIndex]
        $row.DefaultCellStyle.BackColor = Get-StatusColor -Status $status
    }

    $activeCount = @($Script:Guests | Where-Object { (Get-GuestStatus $_) -eq "Active" }).Count
    $dueCount = @($Script:Guests | Where-Object { (Get-GuestStatus $_) -eq "Due Soon" }).Count
    $todayCount = @($Script:Guests | Where-Object { (Get-GuestStatus $_) -eq "Due Today" }).Count
    $overdueCount = @($Script:Guests | Where-Object { (Get-GuestStatus $_) -eq "Overdue" }).Count
    $Script:SummaryLabel.Text = "Active: $activeCount    Due soon: $dueCount    Due today: $todayCount    Overdue: $overdueCount    Total records: $($Script:Guests.Count)"
}

function Get-SelectedGuest {
    if ($Script:Grid.SelectedRows.Count -eq 0) { return $null }
    $id = [int]$Script:Grid.SelectedRows[0].Cells["Id"].Value
    return $Script:Guests | Where-Object { $_.Id -eq $id } | Select-Object -First 1
}

function Check-Notifications {
    param([switch]$Manual)

    $today = (Get-Date).Date
    $dueGuests = New-Object System.Collections.ArrayList
    foreach ($guest in $Script:Guests) {
        $status = Get-GuestStatus -Guest $guest
        if ($status -ne "Due Soon" -and $status -ne "Due Today") { continue }

        $notificationKey = "$(([datetime]$guest.CheckOutDate).ToString("yyyy-MM-dd"))|$($today.ToString("yyyy-MM-dd"))"
        if (-not $Manual -and $guest.LastNotifiedFor -eq $notificationKey) { continue }

        [void]$dueGuests.Add($guest)
        if (-not $Manual) {
            $guest.LastNotifiedFor = $notificationKey
        }
    }

    if ($dueGuests.Count -gt 0) {
        if ($dueGuests.Count -eq 1) {
            $guest = $dueGuests[0]
            $daysLeft = (([datetime]$guest.CheckOutDate).Date - $today).Days
            $remainingText = if ($daysLeft -eq 0) { "today" } else { "in $daysLeft day(s)" }
            $message = "$($guest.GuestName) in room $($guest.RoomNumber) reaches day 55 $remainingText, on $(([datetime]$guest.CheckOutDate).ToString("MMM d, yyyy"))."
        }
        else {
            $message = "$($dueGuests.Count) guests are checking out today or in the next 5 days. Open Today's List to review them."
        }

        $Script:NotifyIcon.BalloonTipTitle = "55 Day Counter"
        $Script:NotifyIcon.BalloonTipText = $message
        $Script:NotifyIcon.ShowBalloonTip(8000)
        if (-not $Manual) {
            Save-Guests
        }
    }
    elseif ($Manual) {
        [System.Windows.Forms.MessageBox]::Show("No guests are within 5 days of the 55th day.", "55 Day Counter") | Out-Null
    }
}

function Show-TestNotification {
    $Script:NotifyIcon.BalloonTipTitle = "55 Day Counter Test"
    $Script:NotifyIcon.BalloonTipText = "Notifications are working for 55 Day Counter. If you see this, app alerts can appear on this PC."
    $Script:NotifyIcon.ShowBalloonTip(8000)
    [System.Windows.Forms.MessageBox]::Show(
        "A test notification was sent. If you did not see it, check Windows Notifications and Do Not Disturb/Focus Assist settings.",
        "55 Day Counter",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Get-TodaysListItems {
    $today = (Get-Date).Date
    $endDate = $today.AddDays(5)
    $items = New-Object System.Collections.ArrayList

    foreach ($guest in $Script:Guests | Sort-Object CheckOutDate, RoomNumber) {
        $status = Get-GuestStatus -Guest $guest
        if ($status -eq "Completed" -or $status -eq "Canceled") { continue }

        $checkout = ([datetime]$guest.CheckOutDate).Date
        if ($checkout -lt $today -or $checkout -gt $endDate) { continue }

        $daysLeft = ($checkout - $today).Days
        $daysText = if ($daysLeft -eq 0) { "Due today" } else { "$daysLeft day(s) left" }

        [void]$items.Add([pscustomobject]@{
            Status = $status
            GuestName = $guest.GuestName
            RoomNumber = $guest.RoomNumber
            CheckInDate = ([datetime]$guest.CheckInDate).ToString("MM/dd/yyyy")
            CheckOutDate = $checkout.ToString("MM/dd/yyyy")
            DaysLeft = $daysText
            Notes = $guest.Notes
        })
    }

    return @($items)
}

function ConvertTo-ExcelXml {
    param($Rows)

    $xml = New-Object System.Text.StringBuilder
    [void]$xml.AppendLine('<?xml version="1.0"?>')
    [void]$xml.AppendLine('<?mso-application progid="Excel.Sheet"?>')
    [void]$xml.AppendLine('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">')
    [void]$xml.AppendLine('<Worksheet ss:Name="Today List"><Table>')

    $headers = @("Status", "Guest Name", "Room", "Check-in", "Checkout", "Days Left", "Notes")
    [void]$xml.AppendLine("<Row>")
    foreach ($header in $headers) {
        [void]$xml.AppendLine("<Cell><Data ss:Type=`"String`">$([System.Security.SecurityElement]::Escape($header))</Data></Cell>")
    }
    [void]$xml.AppendLine("</Row>")

    foreach ($row in $Rows) {
        [void]$xml.AppendLine("<Row>")
        $values = @($row.Status, $row.GuestName, $row.RoomNumber, $row.CheckInDate, $row.CheckOutDate, $row.DaysLeft, $row.Notes)
        foreach ($value in $values) {
            [void]$xml.AppendLine("<Cell><Data ss:Type=`"String`">$([System.Security.SecurityElement]::Escape([string]$value))</Data></Cell>")
        }
        [void]$xml.AppendLine("</Row>")
    }

    [void]$xml.AppendLine("</Table></Worksheet></Workbook>")
    return $xml.ToString()
}

function Export-TodaysList {
    param($Rows)

    if (-not $Rows -or $Rows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("There are no guests checking out today or in the next 5 days.", "Today's List") | Out-Null
        return
    }

    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Excel files (*.xls)|*.xls"
    $saveDialog.FileName = "today-list-$((Get-Date).ToString('yyyy-MM-dd')).xls"
    if ($saveDialog.ShowDialog($Script:MainForm) -ne [System.Windows.Forms.DialogResult]::OK) {
        $saveDialog.Dispose()
        return
    }

    try {
        ConvertTo-ExcelXml -Rows $Rows | Set-Content -Path $saveDialog.FileName -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Excel file saved.", "Today's List") | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Excel file could not be saved.`n`n$($_.Exception.Message)", "Today's List", "OK", "Error") | Out-Null
    }
    finally {
        $saveDialog.Dispose()
    }
}

function Show-TodaysListDialog {
    $rows = Get-TodaysListItems

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Today's List"
    $dialog.StartPosition = "CenterParent"
    $dialog.MinimumSize = New-Object System.Drawing.Size(860, 420)
    $dialog.Size = New-Object System.Drawing.Size(980, 560)
    $dialog.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = "Top"
    $top.Height = 64

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Guests checking out today and in the next 5 days"
    $title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
    $title.Location = New-Object System.Drawing.Point(12, 10)
    $title.Size = New-Object System.Drawing.Size(620, 26)

    $count = New-Object System.Windows.Forms.Label
    $count.Text = "$($rows.Count) guest(s) found"
    $count.Location = New-Object System.Drawing.Point(14, 38)
    $count.Size = New-Object System.Drawing.Size(260, 22)

    $downloadButton = New-Object System.Windows.Forms.Button
    $downloadButton.Text = "Download Excel"
    $downloadButton.Size = New-Object System.Drawing.Size(130, 32)
    $downloadButton.Anchor = "Top, Right"
    $downloadButton.Location = New-Object System.Drawing.Point(704, 16)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Close"
    $closeButton.Size = New-Object System.Drawing.Size(90, 32)
    $closeButton.Anchor = "Top, Right"
    $closeButton.Location = New-Object System.Drawing.Point(842, 16)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $previewGrid = New-Object System.Windows.Forms.DataGridView
    $previewGrid.Dock = "Fill"
    $previewGrid.AllowUserToAddRows = $false
    $previewGrid.AllowUserToDeleteRows = $false
    $previewGrid.ReadOnly = $true
    $previewGrid.SelectionMode = "FullRowSelect"
    $previewGrid.AutoSizeColumnsMode = "Fill"
    $previewGrid.RowHeadersVisible = $false
    $previewGrid.BackgroundColor = [System.Drawing.Color]::White

    $previewColumns = @(
        @{ Name = "Status"; Header = "Status"; Width = 90 },
        @{ Name = "GuestName"; Header = "Guest Name"; Width = 170 },
        @{ Name = "RoomNumber"; Header = "Room"; Width = 75 },
        @{ Name = "CheckInDate"; Header = "Check-in"; Width = 105 },
        @{ Name = "CheckOutDate"; Header = "Checkout"; Width = 105 },
        @{ Name = "DaysLeft"; Header = "Days Left"; Width = 95 },
        @{ Name = "Notes"; Header = "Notes"; Width = 240 }
    )

    foreach ($column in $previewColumns) {
        $gridColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $gridColumn.Name = $column.Name
        $gridColumn.HeaderText = $column.Header
        $gridColumn.FillWeight = $column.Width
        [void]$previewGrid.Columns.Add($gridColumn)
    }

    foreach ($row in $rows) {
        $rowIndex = $previewGrid.Rows.Add($row.Status, $row.GuestName, $row.RoomNumber, $row.CheckInDate, $row.CheckOutDate, $row.DaysLeft, $row.Notes)
        $previewGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = Get-StatusColor -Status $row.Status
    }

    $downloadButton.Add_Click({ Export-TodaysList -Rows $rows })

    $top.Controls.AddRange(@($title, $count, $downloadButton, $closeButton))
    $dialog.Controls.Add($previewGrid)
    $dialog.Controls.Add($top)
    $dialog.CancelButton = $closeButton
    [void]$dialog.ShowDialog($Script:MainForm)
    $dialog.Dispose()
}

Load-Guests

$Script:MainForm = New-Object System.Windows.Forms.Form
$Script:MainForm.Text = "55 Day Counter"
$Script:MainForm.StartPosition = "CenterScreen"
$Script:MainForm.MinimumSize = New-Object System.Drawing.Size(1000, 620)
$Script:MainForm.Size = New-Object System.Drawing.Size(1120, 680)
$Script:MainForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$Script:MainForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
if (Test-Path $Script:IconPath) {
    $Script:MainForm.Icon = New-Object System.Drawing.Icon($Script:IconPath)
}

$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Dock = "Top"
$topPanel.Height = 184
$topPanel.Padding = New-Object System.Windows.Forms.Padding(12)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "55 Day Counter"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 17)
$titleLabel.Location = New-Object System.Drawing.Point(12, 10)
$titleLabel.Size = New-Object System.Drawing.Size(360, 34)

$helpLabel = New-Object System.Windows.Forms.Label
$helpLabel.Text = "Check-in is counted as day 1. The system calculates the 55th day as check-in + 54 days and alerts 5 days before."
$helpLabel.Location = New-Object System.Drawing.Point(14, 48)
$helpLabel.Size = New-Object System.Drawing.Size(850, 24)

$Script:SummaryLabel = New-Object System.Windows.Forms.Label
$Script:SummaryLabel.Location = New-Object System.Drawing.Point(14, 76)
$Script:SummaryLabel.Size = New-Object System.Drawing.Size(980, 22)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = "Search"
$searchLabel.Location = New-Object System.Drawing.Point(14, 114)
$searchLabel.AutoSize = $true

$Script:SearchBox = New-Object System.Windows.Forms.TextBox
$Script:SearchBox.Location = New-Object System.Drawing.Point(72, 110)
$Script:SearchBox.Size = New-Object System.Drawing.Size(220, 26)

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = "Status"
$filterLabel.Location = New-Object System.Drawing.Point(312, 114)
$filterLabel.AutoSize = $true

$Script:FilterCombo = New-Object System.Windows.Forms.ComboBox
$Script:FilterCombo.DropDownStyle = "DropDownList"
$Script:FilterCombo.Location = New-Object System.Drawing.Point(370, 110)
$Script:FilterCombo.Size = New-Object System.Drawing.Size(140, 26)
[void]$Script:FilterCombo.Items.AddRange(@("All", "Active", "Due Soon", "Due Today", "Overdue", "Completed", "Canceled"))
$Script:FilterCombo.SelectedIndex = 0

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Location = New-Object System.Drawing.Point(14, 142)
$buttonPanel.Size = New-Object System.Drawing.Size(1060, 36)
$buttonPanel.Anchor = "Top, Left, Right"
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0)
$buttonPanel.FlowDirection = "LeftToRight"
$buttonPanel.WrapContents = $false

$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "Add Guest"
$addButton.Size = New-Object System.Drawing.Size(105, 32)

$editButton = New-Object System.Windows.Forms.Button
$editButton.Text = "Edit"
$editButton.Size = New-Object System.Drawing.Size(85, 32)

$completeButton = New-Object System.Windows.Forms.Button
$completeButton.Text = "Complete"
$completeButton.Size = New-Object System.Drawing.Size(95, 32)

$cancelCycleButton = New-Object System.Windows.Forms.Button
$cancelCycleButton.Text = "Cancel Cycle"
$cancelCycleButton.Size = New-Object System.Drawing.Size(105, 32)

$notifyButton = New-Object System.Windows.Forms.Button
$notifyButton.Text = "Check Alerts"
$notifyButton.Size = New-Object System.Drawing.Size(105, 32)

$testNotifyButton = New-Object System.Windows.Forms.Button
$testNotifyButton.Text = "Test Alert"
$testNotifyButton.Size = New-Object System.Drawing.Size(95, 32)

$todayListButton = New-Object System.Windows.Forms.Button
$todayListButton.Text = "Today's List"
$todayListButton.Size = New-Object System.Drawing.Size(105, 32)

$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Text = "Export CSV"
$exportButton.Size = New-Object System.Drawing.Size(105, 32)

$buttonPanel.Controls.AddRange(@($addButton, $editButton, $completeButton, $cancelCycleButton, $notifyButton, $testNotifyButton, $todayListButton, $exportButton))

$topPanel.Controls.AddRange(@($titleLabel, $helpLabel, $Script:SummaryLabel, $searchLabel, $Script:SearchBox, $filterLabel, $Script:FilterCombo, $buttonPanel))

if (-not $Script:CanSave) {
    $addButton.Enabled = $false
    $editButton.Enabled = $false
    $completeButton.Enabled = $false
    $cancelCycleButton.Enabled = $false
    $notifyButton.Enabled = $false
    $testNotifyButton.Enabled = $false
    $todayListButton.Enabled = $false
    $exportButton.Enabled = $false
}

$Script:Grid = New-Object System.Windows.Forms.DataGridView
$Script:Grid.Dock = "Fill"
$Script:Grid.AllowUserToAddRows = $false
$Script:Grid.AllowUserToDeleteRows = $false
$Script:Grid.ReadOnly = $true
$Script:Grid.SelectionMode = "FullRowSelect"
$Script:Grid.MultiSelect = $false
$Script:Grid.AutoSizeColumnsMode = "Fill"
$Script:Grid.RowHeadersVisible = $false
$Script:Grid.BackgroundColor = [System.Drawing.Color]::White

$columns = @(
    @{ Name = "Id"; Header = "Id"; Width = 45 },
    @{ Name = "Status"; Header = "Status"; Width = 90 },
    @{ Name = "GuestName"; Header = "Guest Name"; Width = 170 },
    @{ Name = "RoomNumber"; Header = "Room"; Width = 75 },
    @{ Name = "CheckInDate"; Header = "Check-in"; Width = 105 },
    @{ Name = "CheckOutDate"; Header = "55th Day"; Width = 105 },
    @{ Name = "NotifyDate"; Header = "Notify"; Width = 105 },
    @{ Name = "DaysLeft"; Header = "Days Left"; Width = 75 },
    @{ Name = "Notes"; Header = "Notes"; Width = 240 }
)

foreach ($column in $columns) {
    $gridColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $gridColumn.Name = $column.Name
    $gridColumn.HeaderText = $column.Header
    $gridColumn.FillWeight = $column.Width
    [void]$Script:Grid.Columns.Add($gridColumn)
}
$Script:Grid.Columns["Id"].Visible = $false

$legend = New-Object System.Windows.Forms.Label
$legend.Dock = "Bottom"
$legend.Height = 30
$legend.Padding = New-Object System.Windows.Forms.Padding(12, 6, 0, 0)
$legend.Text = "Blue: active    Yellow: within 5 days    Orange: due today    Red: overdue    Green: completed    Gray: canceled"

$Script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $Script:IconPath) {
    $Script:NotifyIcon.Icon = New-Object System.Drawing.Icon($Script:IconPath)
}
else {
    $Script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
}
$Script:NotifyIcon.Visible = $true
$Script:NotifyIcon.Text = "55 Day Counter"

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3600000
$timer.Add_Tick({
    Check-Notifications
    Refresh-Grid
})
$timer.Start()

$addButton.Add_Click({
    $guestInput = Show-GuestDialog
    if ($null -eq $guestInput) { return }
    $requestedRoom = $guestInput.RoomNumber.Trim()
    $duplicateRoom = Test-ActiveRoomConflict -RoomNumber $requestedRoom
    if ($duplicateRoom) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Room $requestedRoom already has an active cycle for $($duplicateRoom.GuestName). Add this guest anyway?", "55 Day Counter", "YesNo", "Warning")
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    [void]$Script:Guests.Add((New-Guest -GuestName $guestInput.GuestName -RoomNumber $guestInput.RoomNumber -CheckInDate $guestInput.CheckInDate -Notes $guestInput.Notes))
    Save-Guests
    Refresh-Grid
})

$editButton.Add_Click({
    $guest = Get-SelectedGuest
    if ($null -eq $guest) {
        [System.Windows.Forms.MessageBox]::Show("Select a guest first.", "55 Day Counter") | Out-Null
        return
    }
    if ($guest.Status -eq "Completed" -or $guest.Status -eq "Canceled") {
        $answer = [System.Windows.Forms.MessageBox]::Show("This cycle is $($guest.Status). Edit it anyway?", "55 Day Counter", "YesNo", "Question")
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $guestInput = Show-GuestDialog -ExistingGuest $guest
    if ($null -eq $guestInput) { return }
    $requestedRoom = $guestInput.RoomNumber.Trim()
    $duplicateRoom = Test-ActiveRoomConflict -RoomNumber $requestedRoom -ExcludeId $guest.Id
    if ($duplicateRoom) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Room $requestedRoom already has an active cycle for $($duplicateRoom.GuestName). Save this edit anyway?", "55 Day Counter", "YesNo", "Warning")
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $dates = Get-CycleDates -CheckIn $guestInput.CheckInDate
    $guest.GuestName = $guestInput.GuestName
    $guest.RoomNumber = $guestInput.RoomNumber
    $guest.CheckInDate = $guestInput.CheckInDate
    $guest.CheckOutDate = $dates.CheckOut
    $guest.NotifyDate = $dates.NotifyOn
    $guest.Notes = $guestInput.Notes
    if ($guest.Status -ne "Completed" -and $guest.Status -ne "Canceled") {
        $guest.Status = "Active"
    }
    $guest.LastNotifiedFor = ""
    Save-Guests
    Refresh-Grid
})

$completeButton.Add_Click({
    $guest = Get-SelectedGuest
    if ($null -eq $guest) {
        [System.Windows.Forms.MessageBox]::Show("Select a guest first.", "55 Day Counter") | Out-Null
        return
    }
    $guest.Status = "Completed"
    Save-Guests
    Refresh-Grid
})

$cancelCycleButton.Add_Click({
    $guest = Get-SelectedGuest
    if ($null -eq $guest) {
        [System.Windows.Forms.MessageBox]::Show("Select a guest first.", "55 Day Counter") | Out-Null
        return
    }
    $answer = [System.Windows.Forms.MessageBox]::Show("Cancel the 55-day cycle for $($guest.GuestName)?", "55 Day Counter", "YesNo", "Question")
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $guest.Status = "Canceled"
    Save-Guests
    Refresh-Grid
})

$notifyButton.Add_Click({
    Check-Notifications -Manual
    Refresh-Grid
})

$testNotifyButton.Add_Click({
    Show-TestNotification
})

$todayListButton.Add_Click({
    Show-TodaysListDialog
})

$exportButton.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "CSV files (*.csv)|*.csv"
    $saveDialog.FileName = "55-day-counter-export.csv"
    if ($saveDialog.ShowDialog($Script:MainForm) -ne [System.Windows.Forms.DialogResult]::OK) {
        $saveDialog.Dispose()
        return
    }

    try {
        $Script:Guests |
            Sort-Object CheckOutDate, RoomNumber |
            Select-Object GuestName, RoomNumber, CheckInDate, CheckOutDate, NotifyDate, Status, Notes |
            Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Export complete.", "55 Day Counter") | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("CSV file could not be saved.`n`n$($_.Exception.Message)", "55 Day Counter", "OK", "Error") | Out-Null
    }
    finally {
        $saveDialog.Dispose()
    }
})

$Script:SearchBox.Add_TextChanged({ Refresh-Grid })
$Script:FilterCombo.Add_SelectedIndexChanged({ Refresh-Grid })

$Script:Grid.Add_CellDoubleClick({
    if ($_.RowIndex -ge 0) { $editButton.PerformClick() }
})

$Script:MainForm.Add_FormClosing({
    Save-Guests
    $Script:NotifyIcon.Visible = $false
    $Script:NotifyIcon.Dispose()
    if ($Script:AppMutex) {
        $Script:AppMutex.ReleaseMutex()
        $Script:AppMutex.Dispose()
    }
})

$Script:MainForm.Controls.Add($Script:Grid)
$Script:MainForm.Controls.Add($legend)
$Script:MainForm.Controls.Add($topPanel)

Refresh-Grid
Check-Notifications

[void][System.Windows.Forms.Application]::Run($Script:MainForm)

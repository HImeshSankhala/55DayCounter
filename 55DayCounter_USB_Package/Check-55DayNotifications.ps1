Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataPath = Join-Path $AppDir "guests.json"

if (-not (Test-Path $DataPath)) { exit 0 }

function Invoke-WithDataLock {
    param([scriptblock]$Action)

    $mutex = New-Object System.Threading.Mutex($false, "55DayCounterDataLock")
    $hasLock = $false
    try {
        $hasLock = $mutex.WaitOne(10000)
        if (-not $hasLock) { exit 2 }
        & $Action
    }
    finally {
        if ($hasLock) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
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

try {
    Invoke-WithDataLock {
        $raw = Get-Content -Path $DataPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
        $script:guests = @($raw | ConvertFrom-Json)
    }
}
catch {
    exit 1
}

$today = (Get-Date).Date
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Visible = $true
$notifyIcon.Text = "55 Day Counter"
$changed = $false
$dueGuests = New-Object System.Collections.ArrayList

foreach ($guest in $guests) {
    $status = Get-GuestStatus -Guest $guest
    if ($status -ne "Due Soon" -and $status -ne "Due Today") { continue }

    $notificationKey = "$(([datetime]$guest.CheckOutDate).ToString("yyyy-MM-dd"))|$($today.ToString("yyyy-MM-dd"))"
    if ($guest.LastNotifiedFor -eq $notificationKey) { continue }

    [void]$dueGuests.Add($guest)
    $guest.LastNotifiedFor = $notificationKey
    $changed = $true
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

    $notifyIcon.BalloonTipTitle = "55 Day Counter"
    $notifyIcon.BalloonTipText = $message
    $notifyIcon.ShowBalloonTip(8000)
    Start-Sleep -Seconds 10
}

$notifyIcon.Visible = $false
$notifyIcon.Dispose()

if ($changed) {
    Invoke-WithDataLock {
        $tempPath = Join-Path $AppDir ("guests.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
        try {
            $guests | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $tempPath -Encoding UTF8
            Move-Item -LiteralPath $tempPath -Destination $DataPath -Force
        }
        finally {
            if (Test-Path $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }
    }
}

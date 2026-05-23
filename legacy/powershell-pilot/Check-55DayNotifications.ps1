Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataPath = Join-Path $AppDir "guests.json"
$IconPath = Join-Path $AppDir "55DayCounter.ico"

if (-not (Test-Path $DataPath)) { exit 0 }

$appMutex = New-Object System.Threading.Mutex($false, "55DayCounterAppRunning")
$appLock = $false
try {
    $appLock = $appMutex.WaitOne(0)
    if (-not $appLock) { exit 0 }
}
finally {
    if ($appLock) { $appMutex.ReleaseMutex() }
    $appMutex.Dispose()
}

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

function Format-NotificationList {
    param(
        $Guests,
        [datetime]$Today
    )

    $lines = New-Object System.Collections.ArrayList
    $maxRows = 4
    foreach ($guest in @($Guests | Sort-Object CheckOutDate, RoomNumber | Select-Object -First $maxRows)) {
        $checkout = ([datetime]$guest.CheckOutDate).Date
        $daysLeft = ($checkout - $Today).Days
        $dueText = if ($daysLeft -eq 0) { "today" } else { "$daysLeft day(s)" }
        [void]$lines.Add("Rm $($guest.RoomNumber): $($guest.GuestName) - $dueText")
    }

    if ($Guests.Count -gt $maxRows) {
        [void]$lines.Add("+ $($Guests.Count - $maxRows) more in Today's List")
    }

    return ($lines -join "`n")
}

try {
    Invoke-WithDataLock {
        $raw = Get-Content -Path $DataPath -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
        $parsed = $raw | ConvertFrom-Json
        if ($null -eq $parsed) {
            $script:guests = @()
        }
        elseif ($parsed -is [System.Array]) {
            $script:guests = $parsed
        }
        else {
            $script:guests = @($parsed)
        }
    }
}
catch {
    exit 1
}

$today = (Get-Date).Date
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $IconPath) {
    $notifyIcon.Icon = New-Object System.Drawing.Icon($IconPath)
}
else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
}
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
    $message = Format-NotificationList -Guests $dueGuests -Today $today

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

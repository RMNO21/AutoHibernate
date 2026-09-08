param(
    [switch]$Active = $false,
    [switch]$ShowStatus = $false
)

$mutexName = "AutoHibernate_SingleInstance_Mutex"
$createdNew = $false
$script:mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    if ($Active) {
        try {
            $ev = [System.Threading.EventWaitHandle]::OpenExisting("AutoHibernate_Start_Event")
            $ev.Set() | Out-Null
            $ev.Close()
        } catch {}
    }
    if ($ShowStatus) {
        try {
            $ev = [System.Threading.EventWaitHandle]::OpenExisting("AutoHibernate_Status_Event")
            $ev.Set() | Out-Null
            $ev.Close()
        } catch {}
    }
    exit
}

# Load Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Event Handles for IPC
$script:startEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, "AutoHibernate_Start_Event")
$script:stopEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, "AutoHibernate_Stop_Event")
$script:statusEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, "AutoHibernate_Status_Event")

# Native Win32 definitions
$codeDefinition = @"
using System;
using System.Runtime.InteropServices;

public class WinInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint GetIdleMs() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(lii);
        GetLastInputInfo(ref lii);
        return (uint)Environment.TickCount - lii.dwTime;
    }
}

public class WinGuiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
Add-Type -TypeDefinition $codeDefinition -ErrorAction SilentlyContinue

$appDir = "$env:LOCALAPPDATA\AutoHibernate"
if (-not (Test-Path $appDir)) { New-Item -ItemType Directory -Path $appDir -Force | Out-Null }
$configFile = "$appDir\config.ini"
$activeIco = "$appDir\AutoHibernate_Active.ico"
$inactiveIco = "$appDir\AutoHibernate_Inactive.ico"

# Read Config
$script:timeoutMinutes = 30
if (Test-Path $configFile) {
    try {
        $content = Get-Content $configFile -Raw
        if ($content -match "TimeoutMinutes=(\d+)") {
            $script:timeoutMinutes = [int]$matches[1]
        }
    } catch {}
}

function Save-Timeout([int]$mins) {
    $script:timeoutMinutes = $mins
    try { Set-Content -Path $configFile -Value "TimeoutMinutes=$mins" -Encoding ASCII } catch {}
}

# State variables
$script:isTimerActive = [bool]$Active
$script:isHibernatingSelf = $false
$script:lastTickTime = [DateTime]::UtcNow

$bulletOn = [char]0x25CF
$bulletOff = [char]0x25CB

# Modern OSD Banner Function
function Show-OSD([string]$title, [string]$subtitle = "", [string]$colorHex = "#00E5FF") {
    try {
        $osd = New-Object System.Windows.Forms.Form
        $osd.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $osd.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $osd.TopMost = $true
        $osd.ShowInTaskbar = $false
        $osd.BackColor = [System.Drawing.Color]::FromArgb(18, 22, 30)
        $osd.Opacity = 0.94
        $osd.Size = New-Object System.Drawing.Size(380, 68)
        
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $osd.Location = New-Object System.Drawing.Point(($screen.Right - 400), ($screen.Bottom - 90))
        
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $panel.Padding = New-Object System.Windows.Forms.Padding(14, 10, 14, 10)
        $osd.Controls.Add($panel)

        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Dock = [System.Windows.Forms.DockStyle]::Top
        $lblTitle.Height = 26
        $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($colorHex)
        $lblTitle.Text = $title
        $panel.Controls.Add($lblTitle)

        if ($subtitle) {
            $lblSub = New-Object System.Windows.Forms.Label
            $lblSub.Dock = [System.Windows.Forms.DockStyle]::Bottom
            $lblSub.Height = 20
            $lblSub.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            $lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 205)
            $lblSub.Text = $subtitle
            $panel.Controls.Add($lblSub)
        }
        
        $osd.Show()
        
        $osdTimer = New-Object System.Windows.Forms.Timer
        $osdTimer.Interval = 2500
        $osdTimer.Tag = $osd
        $osdTimer.Add_Tick({
            param($s, $e)
            try {
                $s.Stop()
                $f = $s.Tag
                $s.Dispose()
                if ($f -and -not $f.IsDisposed) {
                    $f.Close()
                    $f.Dispose()
                }
            } catch {}
        })
        $osdTimer.Start()
    } catch {}
}

# --- STATUS WINDOW (GUI Card) ---
$script:statusForm = New-Object System.Windows.Forms.Form
$script:statusForm.Text = "Auto Hibernate - Sleep Timer"
$script:statusForm.Size = New-Object System.Drawing.Size(430, 275)
$script:statusForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$script:statusForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$script:statusForm.MaximizeBox = $false
$script:statusForm.MinimizeBox = $false
$script:statusForm.ShowInTaskbar = $true
$script:statusForm.TopMost = $true
$script:statusForm.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 38)
$script:statusForm.ForeColor = [System.Drawing.Color]::White
if (Test-Path $activeIco) {
    try { $script:statusForm.Icon = New-Object System.Drawing.Icon($activeIco) } catch {}
}

# Close button hides to tray
$script:statusForm.add_FormClosing({
    param($sender, $e)
    $e.Cancel = $true
    $script:statusForm.Hide()
})

$cardPanel = New-Object System.Windows.Forms.Panel
$cardPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$cardPanel.Padding = New-Object System.Windows.Forms.Padding(20, 16, 20, 16)
$script:statusForm.Controls.Add($cardPanel)

$lblStatusBadge = New-Object System.Windows.Forms.Label
$lblStatusBadge.Location = New-Object System.Drawing.Point(20, 14)
$lblStatusBadge.AutoSize = $true
$lblStatusBadge.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$cardPanel.Controls.Add($lblStatusBadge)

$lblCountdown = New-Object System.Windows.Forms.Label
$lblCountdown.Location = New-Object System.Drawing.Point(18, 40)
$lblCountdown.AutoSize = $true
$lblCountdown.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 32, [System.Drawing.FontStyle]::Bold)
$cardPanel.Controls.Add($lblCountdown)

$lblTimeout = New-Object System.Windows.Forms.Label
$lblTimeout.Location = New-Object System.Drawing.Point(220, 52)
$lblTimeout.AutoSize = $true
$lblTimeout.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblTimeout.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 205)
$lblTimeout.Text = "Timeout:"
$cardPanel.Controls.Add($lblTimeout)

$cboTimeout = New-Object System.Windows.Forms.ComboBox
$cboTimeout.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cboTimeout.Location = New-Object System.Drawing.Point(280, 50)
$cboTimeout.Width = 110
$cboTimeout.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$cboTimeout.BackColor = [System.Drawing.Color]::FromArgb(34, 40, 55)
$cboTimeout.ForeColor = [System.Drawing.Color]::White
$times = @(10, 15, 20, 30, 45, 60, 90, 120)
foreach ($t in $times) { $cboTimeout.Items.Add("$t Min") | Out-Null }
$idx = [array]::IndexOf($times, $script:timeoutMinutes)
if ($idx -ge 0) { $cboTimeout.SelectedIndex = $idx } else { $cboTimeout.SelectedIndex = 3 }
$cardPanel.Controls.Add($cboTimeout)

$cboTimeout.Add_SelectedIndexChanged({
    $selText = $cboTimeout.SelectedItem.ToString()
    if ($selText -match "(\d+)") {
        $val = [int]$matches[1]
        Save-Timeout $val
        Update-TimeMenuChecks
        Update-StatusWindowUI
        Update-TrayState
    }
})

$lblStatusDesc = New-Object System.Windows.Forms.Label
$lblStatusDesc.Location = New-Object System.Drawing.Point(20, 108)
$lblStatusDesc.Size = New-Object System.Drawing.Size(370, 36)
$lblStatusDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatusDesc.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 210)
$cardPanel.Controls.Add($lblStatusDesc)

# Controls Row
$btnStartStop = New-Object System.Windows.Forms.Button
$btnStartStop.Location = New-Object System.Drawing.Point(20, 160)
$btnStartStop.Size = New-Object System.Drawing.Size(110, 36)
$btnStartStop.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStartStop.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$cardPanel.Controls.Add($btnStartStop)

$btnStartStop.Add_Click({
    if ($script:isTimerActive) {
        Set-TimerActive $false -fromUser $true
    } else {
        Set-TimerActive $true -fromUser $true
    }
    Update-StatusWindowUI
})

$btnHibNow = New-Object System.Windows.Forms.Button
$btnHibNow.Text = "Hibernate Now"
$btnHibNow.Location = New-Object System.Drawing.Point(140, 160)
$btnHibNow.Size = New-Object System.Drawing.Size(120, 36)
$btnHibNow.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnHibNow.BackColor = [System.Drawing.Color]::FromArgb(40, 48, 66)
$btnHibNow.ForeColor = [System.Drawing.Color]::FromArgb(220, 230, 245)
$btnHibNow.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnHibNow.Add_Click({ Trigger-Hibernate })
$cardPanel.Controls.Add($btnHibNow)

$btnHide = New-Object System.Windows.Forms.Button
$btnHide.Text = "Hide to Tray"
$btnHide.Location = New-Object System.Drawing.Point(270, 160)
$btnHide.Size = New-Object System.Drawing.Size(120, 36)
$btnHide.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnHide.BackColor = [System.Drawing.Color]::FromArgb(0, 130, 200)
$btnHide.ForeColor = [System.Drawing.Color]::White
$btnHide.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$btnHide.Add_Click({ $script:statusForm.Hide() })
$cardPanel.Controls.Add($btnHide)

$lblFooter = New-Object System.Windows.Forms.Label
$lblFooter.Location = New-Object System.Drawing.Point(20, 212)
$lblFooter.Size = New-Object System.Drawing.Size(370, 20)
$lblFooter.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblFooter.ForeColor = [System.Drawing.Color]::FromArgb(120, 132, 150)
$lblFooter.Text = "Resets automatically on physical mouse or keyboard activity."
$cardPanel.Controls.Add($lblFooter)

function Update-StatusWindowUI {
    if ($script:isTimerActive) {
        $idleMs = [WinInput]::GetIdleMs()
        $thresholdMs = [uint32]($script:timeoutMinutes * 60 * 1000)
        $remainSec = [Math]::Max(0, ($thresholdMs - $idleMs) / 1000)
        $m = [Math]::Floor($remainSec / 60)
        $s = [Math]::Floor($remainSec % 60)

        $lblStatusBadge.Text = "$bulletOn ACTIVE - SLEEP TIMER RUNNING"
        $lblStatusBadge.ForeColor = [System.Drawing.Color]::FromArgb(0, 235, 255)
        $lblCountdown.Text = ("{0:D2}:{1:D2}" -f [int]$m, [int]$s)
        $lblCountdown.ForeColor = [System.Drawing.Color]::White
        $lblStatusDesc.Text = "Remaining until Hibernate. Resets to $($script:timeoutMinutes):00 on mouse or keyboard movement."
        
        $btnStartStop.Text = "Turn Off"
        $btnStartStop.BackColor = [System.Drawing.Color]::FromArgb(120, 30, 45)
        $btnStartStop.ForeColor = [System.Drawing.Color]::White
    } else {
        $lblStatusBadge.Text = "$bulletOff DISABLED (STANDBY)"
        $lblStatusBadge.ForeColor = [System.Drawing.Color]::FromArgb(160, 170, 185)
        $lblCountdown.Text = "--:--"
        $lblCountdown.ForeColor = [System.Drawing.Color]::FromArgb(160, 170, 185)
        $lblStatusDesc.Text = "Sleep timer is currently OFF.`nClick 'Start Timer' below to activate."

        $btnStartStop.Text = "Start Timer"
        $btnStartStop.BackColor = [System.Drawing.Color]::FromArgb(20, 120, 80)
        $btnStartStop.ForeColor = [System.Drawing.Color]::White
    }
}

function Show-StatusWindow {
    Update-StatusWindowUI
    if ($script:statusForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
        $script:statusForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    }
    $script:statusForm.Show()
    $script:statusForm.BringToFront()
    $script:statusForm.Activate()
    [WinGuiHelper]::SetForegroundWindow($script:statusForm.Handle) | Out-Null
}

# --- TRAY ICON SETUP ---
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Visible = $true

function Update-TrayState {
    if ($script:isTimerActive) {
        if (Test-Path $activeIco) {
            $tray.Icon = New-Object System.Drawing.Icon($activeIco)
        } else {
            $tray.Icon = [System.Drawing.SystemIcons]::Shield
        }
        $tray.Text = "Auto Hibernate: $($script:timeoutMinutes)m Active (Idle Reset)"
    } else {
        if (Test-Path $inactiveIco) {
            $tray.Icon = New-Object System.Drawing.Icon($inactiveIco)
        } else {
            $tray.Icon = [System.Drawing.SystemIcons]::Application
        }
        $tray.Text = "Auto Hibernate: Inactive (Standby)"
    }
    if ($script:statusForm.Visible) {
        Update-StatusWindowUI
    }
}

# Context Menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$lblStatus = $menu.Items.Add("Auto Hibernate")
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblStatus.Enabled = $false

$null = $menu.Items.Add("-")

# Show Status Window Menu Item
$itemOpenStatus = $menu.Items.Add("Open Status Window...")
$itemOpenStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$itemOpenStatus.Add_Click({
    Show-StatusWindow
})

# Toggle Item
$itemToggle = $menu.Items.Add("Active (Sleep Timer Enabled)")
$itemToggle.CheckOnClick = $true
$itemToggle.Checked = $script:isTimerActive
$itemToggle.Add_Click({
    if ($itemToggle.Checked) {
        Set-TimerActive $true -fromUser $true
    } else {
        Set-TimerActive $false -fromUser $true
    }
})

# Submenu for Time Selection
$timeMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Idle Timeout")

function Update-TimeMenuChecks {
    foreach ($item in $timeMenu.DropDownItems) {
        $item.Checked = ($item.Tag -eq $script:timeoutMinutes)
    }
    $idx = [array]::IndexOf($times, $script:timeoutMinutes)
    if ($idx -ge 0 -and $cboTimeout.SelectedIndex -ne $idx) {
        $cboTimeout.SelectedIndex = $idx
    }
}

foreach ($t in $times) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem("$t Minutes")
    $item.Tag = $t
    $item.Add_Click({
        param($sender, $e)
        Save-Timeout ($sender.Tag)
        Update-TimeMenuChecks
        if ($script:isTimerActive) {
            Show-OSD "Auto Hibernate Configured" "Timeout set to $($sender.Tag) minutes of inactivity" "#00E5FF"
        }
        Update-TrayState
    })
    $timeMenu.DropDownItems.Add($item) | Out-Null
}
Update-TimeMenuChecks
$menu.Items.Add($timeMenu) | Out-Null

$null = $menu.Items.Add("-")

# Hibernate Now
$itemHibernateNow = $menu.Items.Add("Hibernate Now")
$itemHibernateNow.Add_Click({
    Trigger-Hibernate
})

# Exit Program
$itemExit = $menu.Items.Add("Exit Program")
$itemExit.Add_Click({
    Exit-Program
})

$tray.ContextMenuStrip = $menu

function Set-TimerActive([bool]$state, [bool]$fromUser = $true) {
    $script:isTimerActive = $state
    $itemToggle.Checked = $state
    Update-TrayState
    if ($fromUser) {
        if ($state) {
            Show-OSD "Auto Hibernate: Started ($($script:timeoutMinutes)m)" "Hibernate after $($script:timeoutMinutes)m inactivity. Resets on mouse/keyboard." "#00E5FF"
        } else {
            Show-OSD "Auto Hibernate: Stopped" "Timer has been turned off." "#FF5252"
        }
    }
}

function Trigger-Hibernate {
    $script:isHibernatingSelf = $true
    $tray.Visible = $false
    $tray.Dispose()
    if ($script:statusForm) { $script:statusForm.Dispose() }
    [System.Windows.Forms.Application]::Exit()
    cmd.exe /c "shutdown /h /f"
    [Environment]::Exit(0)
}

function Exit-Program {
    if ($script:timer) { $script:timer.Stop() }
    $tray.Visible = $false
    $tray.Dispose()
    if ($script:statusForm) { $script:statusForm.Dispose() }
    if ($script:startEvent) { $script:startEvent.Close() }
    if ($script:stopEvent) { $script:stopEvent.Close() }
    if ($script:statusEvent) { $script:statusEvent.Close() }
    if ($script:mutex) { try { $script:mutex.ReleaseMutex() } catch {}; $script:mutex.Dispose() }
    [System.Windows.Forms.Application]::Exit()
    [Environment]::Exit(0)
}

# Power Event Handler:
# If user puts PC to sleep or hibernates manually, or system resumes:
# Reset timer to INACTIVE!
$powerHandler = [Microsoft.Win32.PowerModeChangedEventHandler]{
    param($s, $e)
    if ($e.Mode -eq [Microsoft.Win32.PowerModes]::Suspend -or $e.Mode -eq [Microsoft.Win32.PowerModes]::Resume) {
        if (-not $script:isHibernatingSelf) {
            Set-TimerActive $false -fromUser $false
        }
    }
}
[Microsoft.Win32.SystemEvents]::add_PowerModeChanged($powerHandler)

# Click or Double click tray icon opens Status Window
$tray.Add_Click({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Show-StatusWindow
    }
})
$tray.Add_DoubleClick({
    Show-StatusWindow
})

# Dynamically update context menu status label
$menu.add_Opening({
    if ($script:isTimerActive) {
        $idleMs = [WinInput]::GetIdleMs()
        $thresholdMs = [uint32]($script:timeoutMinutes * 60 * 1000)
        $remainSec = [Math]::Max(0, ($thresholdMs - $idleMs) / 1000)
        $m = [Math]::Floor($remainSec / 60)
        $s = [Math]::Floor($remainSec % 60)
        $lblStatus.Text = ("Status: Active - {0:D2}:{1:D2} Left ({2}m)" -f [int]$m, [int]$s, $script:timeoutMinutes)
    } else {
        $lblStatus.Text = "Status: Inactive (Standby)"
    }
})

Update-TrayState
if ($Active) {
    Show-OSD "Auto Hibernate: Started ($($script:timeoutMinutes)m)" "Hibernate after $($script:timeoutMinutes)m inactivity. Resets on mouse/keyboard." "#00E5FF"
}

if ($ShowStatus) {
    Show-StatusWindow
}

# Main timer tick (runs every 250ms for snappy IPC response)
$script:timer = New-Object System.Windows.Forms.Timer
$script:timer.Interval = 250
$script:tickCounter = 0

$script:timer.Add_Tick({
    $script:tickCounter++

    # 1. Check IPC Start Event
    if ($script:startEvent.WaitOne(0)) {
        Set-TimerActive $true -fromUser $true
    }

    # 2. Check IPC Stop Event
    if ($script:stopEvent.WaitOne(0)) {
        Set-TimerActive $false -fromUser $true
    }

    # 3. Check IPC Status Event
    if ($script:statusEvent.WaitOne(0)) {
        Show-StatusWindow
    }

    # 4. Check for clock jump (manual sleep/hibernate resume)
    $now = [DateTime]::UtcNow
    $diffSec = ($now - $script:lastTickTime).TotalSeconds
    $script:lastTickTime = $now
    if ($diffSec -gt 10) {
        Set-TimerActive $false -fromUser $false
    }

    # 5. Live update of Status Window if open
    if ($script:statusForm.Visible) {
        Update-StatusWindowUI
    }

    # 6. If active, calculate idle countdown
    if ($script:isTimerActive) {
        $idleMs = [WinInput]::GetIdleMs()
        $thresholdMs = [uint32]($script:timeoutMinutes * 60 * 1000)

        # Update tray text once every 4 ticks (~1 sec)
        if ($script:tickCounter % 4 -eq 0) {
            $idleSec = [Math]::Floor($idleMs / 1000)
            $remainSec = [Math]::Max(0, ($thresholdMs / 1000) - $idleSec)
            $remainMin = [Math]::Ceiling($remainSec / 60)

            $trayText = "Auto Hibernate: $remainMin min left ($($script:timeoutMinutes)m idle)"
            if ($trayText.Length -gt 63) { $trayText = $trayText.Substring(0, 63) }
            $tray.Text = $trayText
        }

        # If threshold reached, hibernate!
        if ($idleMs -ge $thresholdMs) {
            Trigger-Hibernate
        }
    }
})
$script:timer.Start()

[System.Windows.Forms.Application]::Run()

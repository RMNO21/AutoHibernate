<#
.SYNOPSIS
    Installs Auto Hibernate utility on Windows 11.
#>
$ErrorActionPreference = "Stop"

$installDir = "$env:LOCALAPPDATA\AutoHibernate"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$scriptDir = $PSScriptRoot

$files = @(
    "AutoHibernate.ps1",
    "AutoHibernate_Silent.vbs",
    "AutoHibernate_Start.vbs",
    "AutoHibernate_Start.ps1",
    "AutoHibernate_Stop.vbs",
    "AutoHibernate_Stop.ps1",
    "AutoHibernate_Status.vbs",
    "AutoHibernate_Status.ps1",
    "Create_Shortcuts.ps1",
    "AutoHibernate_Active.ico",
    "AutoHibernate_Inactive.ico"
)

foreach ($f in $files) {
    $src = Join-Path $scriptDir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $installDir -Force
    }
}

# Create Start Menu Shortcut
& "$installDir\Create_Shortcuts.ps1"

# Setup Windows Startup
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regValue = "wscript.exe `"$installDir\AutoHibernate_Silent.vbs`""
Set-ItemProperty -Path $regPath -Name "AutoHibernate" -Value $regValue -Force

# Start background service
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$installDir\AutoHibernate_Silent.vbs`""

Write-Host "Auto Hibernate has been successfully installed and started in background!" -ForegroundColor Cyan
Write-Host "Search for 'Auto Hibernate' in your Windows Start Menu anytime." -ForegroundColor Green
Write-Host "Hotkeys: Start: Ctrl+Shift+H | Stop: Ctrl+Shift+X | Status: Ctrl+Shift+S" -ForegroundColor Green

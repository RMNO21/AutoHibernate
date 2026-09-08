<#
.SYNOPSIS
    Uninstalls Auto Hibernate utility.
#>
$ErrorActionPreference = "SilentlyContinue"

$installDir = "$env:LOCALAPPDATA\AutoHibernate"

# 1. Stop background processes
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*AutoHibernate.ps1*" } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}

# 2. Remove Startup Registry
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "AutoHibernate" -Force

# 3. Remove Start Menu Shortcut
$programsPath = [Environment]::GetFolderPath('Programs')
Remove-Item -Path "$programsPath\Auto Hibernate*.lnk" -Force

# 4. Remove installation folder
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "Auto Hibernate has been completely uninstalled." -ForegroundColor Yellow

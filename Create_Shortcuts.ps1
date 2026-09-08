$programsPath = [Environment]::GetFolderPath('Programs')
$desktopPath = [Environment]::GetFolderPath('Desktop')
$appDir = "$env:LOCALAPPDATA\AutoHibernate"
$icoPath = "$appDir\AutoHibernate_Active.ico"
$wscriptExe = "$env:SystemRoot\System32\wscript.exe"

# Clean any desktop shortcuts if present
Get-ChildItem -Path $desktopPath -Filter "*Auto Hibernate*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $programsPath -Filter "*Auto Hibernate*.lnk" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$wshShell = New-Object -ComObject WScript.Shell

# Create clean Start Menu Program shortcut
$mainLnk = $wshShell.CreateShortcut((Join-Path $programsPath "Auto Hibernate.lnk"))
$mainLnk.TargetPath = $wscriptExe
$mainLnk.Arguments = "`"$appDir\AutoHibernate_Status.vbs`""
$mainLnk.WorkingDirectory = $appDir
$mainLnk.WindowStyle = 7
$mainLnk.Description = "Auto Hibernate - Smart OLED Sleep & Hibernate Timer"
if (Test-Path $icoPath) {
    $mainLnk.IconLocation = "$icoPath,0"
}
$mainLnk.Save()

Write-Output "Start Menu shortcut created: $(Join-Path $programsPath 'Auto Hibernate.lnk')"

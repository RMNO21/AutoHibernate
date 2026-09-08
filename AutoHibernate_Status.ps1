$proc = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -like "*AutoHibernate.ps1*" }

if ($proc) {
    try {
        $ev = [System.Threading.EventWaitHandle]::OpenExisting("AutoHibernate_Status_Event")
        $ev.Set() | Out-Null
        $ev.Close()
    } catch {}
} else {
    $appDir = "$env:LOCALAPPDATA\AutoHibernate"
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$appDir\AutoHibernate_Silent.vbs`" -ShowStatus"
}

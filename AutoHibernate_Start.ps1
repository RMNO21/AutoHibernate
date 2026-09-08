$signaled = $false
try {
    $ev = [System.Threading.EventWaitHandle]::OpenExisting("AutoHibernate_Start_Event")
    $ev.Set() | Out-Null
    $ev.Close()
    $signaled = $true
} catch {}

if (-not $signaled) {
    $appDir = "$env:LOCALAPPDATA\AutoHibernate"
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$appDir\AutoHibernate_Silent.vbs`" -Active"
}

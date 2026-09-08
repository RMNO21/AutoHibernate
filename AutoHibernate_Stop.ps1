try {
    $ev = [System.Threading.EventWaitHandle]::OpenExisting("AutoHibernate_Stop_Event")
    $ev.Set() | Out-Null
    $ev.Close()
} catch {}

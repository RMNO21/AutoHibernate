Set WshShell = CreateObject("WScript.Shell")
appDir = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\AutoHibernate"
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\AutoHibernate_Status.ps1""", 0, False

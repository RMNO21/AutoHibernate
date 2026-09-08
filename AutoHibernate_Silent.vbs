Set WshShell = CreateObject("WScript.Shell")
appDir = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\AutoHibernate"
args = ""
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & appDir & "\AutoHibernate.ps1""" & args, 0, False

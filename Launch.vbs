' Starts the wallpaper script with no console window at all.
' Used by Install.ps1 so the context menu never flashes a terminal.
Dim shell, fso, here, ps
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
ps = here & "\OpenSlideshowWallpaperPath.ps1"

Dim args, i
args = ""
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next

shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps & """" & args, 0, False

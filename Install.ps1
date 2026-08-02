<#
    Builds the "Open wallpaper location" desktop context menu.

    Creates a single menu entry pointing at Launch.vbs. The script works out the
    monitor count when clicked, so this never needs re-running after a display
    change -- only if you move this folder.

        .\Install.ps1           install or repair the menu entry
        .\Install.ps1 -Remove   uninstall

    No admin rights needed.
#>
param([switch]$Remove)

$ErrorActionPreference = 'Stop'

$root     = 'HKCU:\Software\Classes\DesktopBackground\Shell\CurrentWallpaper'
$script   = Join-Path $PSScriptRoot 'OpenSlideshowWallpaperPath.ps1'
$launcher = Join-Path $PSScriptRoot 'Launch.vbs'

function Remove-Menu {
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
}

if ($Remove) {
    Remove-Menu
    Write-Host "Removed the menu entry."
    return
}

foreach ($f in @($script, $launcher)) {
    if (-not (Test-Path $f)) { throw "Cannot find $(Split-Path $f -Leaf) next to this installer." }
}

Remove-Menu

New-Item $root -Force | Out-Null
Set-ItemProperty $root -Name 'MUIVerb'  -Value 'Open wallpaper location'
Set-ItemProperty $root -Name 'Icon'     -Value 'imageres.dll,-68'
Set-ItemProperty $root -Name 'Position' -Value 'Bottom'

# wscript + Launch.vbs starts PowerShell with no console window at all
New-Item "$root\command" -Force | Out-Null
Set-ItemProperty "$root\command" -Name '(default)' -Value "wscript.exe `"$launcher`""

Write-Host "Installed. Right-click the desktop to use it."
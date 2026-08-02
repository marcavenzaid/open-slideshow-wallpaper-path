<#
    Builds the "Open wallpaper location" desktop context menu.

    Default: a single menu entry. The script counts monitors when clicked, so it
    never needs reinstalling. Shows a picker when several wallpapers are in use.

    -Submenu: fixed Monitor 1 / Monitor 2 entries instead. One click straight to
    Explorer, but the entries are written at install time, so re-run after any
    monitor change (or use -AutoRefresh).

        .\Install.ps1                 install the picker (adapts to any monitor count)
        .\Install.ps1 -Submenu        install a fixed Monitor 1 / Monitor 2 submenu
        .\Install.ps1 -AutoRefresh    with -Submenu, rebuild it at each sign-in
        .\Install.ps1 -Remove         uninstall everything

    No admin rights needed.
#>
param([switch]$Submenu, [switch]$AutoRefresh, [switch]$Remove)

$ErrorActionPreference = 'Stop'

$root     = 'HKCU:\Software\Classes\DesktopBackground\Shell\CurrentWallpaper'
$script   = Join-Path $PSScriptRoot 'OpenSlideshowWallpaperPath.ps1'
$launcher = Join-Path $PSScriptRoot 'Launch.vbs'
$installer= Join-Path $PSScriptRoot 'Install.ps1'
$taskName = 'OpenSlideshowWallpaperPath Refresh'

function Remove-Menu {
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
}

function Remove-Task {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($t) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
}

if ($Remove) {
    Remove-Menu
    Remove-Task
    Write-Host "Removed the menu entry and any refresh task."
    return
}

foreach ($f in @($script, $launcher)) {
    if (-not (Test-Path $f)) { throw "Cannot find $(Split-Path $f -Leaf) next to this installer." }
}

# How many wallpapers is Windows tracking right now?
$values = (Get-Item 'HKCU:\Control Panel\Desktop').GetValueNames()
$count  = @($values | Where-Object { $_ -match '^TranscodedImageCache_\d+$' }).Count

# wscript + Launch.vbs starts PowerShell with no console window at all
$exec = "wscript.exe `"$launcher`""

Remove-Menu
New-Item $root -Force | Out-Null
Set-ItemProperty $root -Name 'MUIVerb'  -Value 'Open wallpaper location'
Set-ItemProperty $root -Name 'Icon'     -Value 'imageres.dll,-68'
Set-ItemProperty $root -Name 'Position' -Value 'Bottom'

if (-not $Submenu -or $count -le 1) {
    # One entry. The script sizes itself to the monitor count at click time.
    New-Item "$root\command" -Force | Out-Null
    Set-ItemProperty "$root\command" -Name '(default)' -Value $exec
    if ($Submenu) {
        Write-Host "Installed: one display detected, single menu entry created."
    } else {
        Write-Host "Installed: single menu entry, adapts to any monitor count."
    }
} else {
    Set-ItemProperty $root -Name 'SubCommands' -Value ''
    for ($i = 0; $i -lt $count; $i++) {
        $key = "$root\shell\{0:D2}Monitor{1}" -f ($i + 1), ($i + 1)
        New-Item $key -Force | Out-Null
        Set-ItemProperty $key -Name 'MUIVerb' -Value "Monitor $($i + 1)"
        New-Item "$key\command" -Force | Out-Null
        Set-ItemProperty "$key\command" -Name '(default)' -Value "$exec -Index $i"
    }
    Write-Host "Installed: $count displays detected, submenu created."
}

if ($AutoRefresh -and -not $Submenu) {
    Write-Host "Note: -AutoRefresh only applies to -Submenu. The picker never goes stale."
} elseif ($AutoRefresh) {
    Remove-Task
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installer`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Description 'Rebuilds the wallpaper context menu for the current monitor count.' | Out-Null
    Write-Host "Auto-refresh enabled: the menu rebuilds itself at each sign-in."
}

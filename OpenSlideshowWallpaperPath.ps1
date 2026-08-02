<#
    Opens File Explorer with the current wallpaper image selected.

    -Index 0   first monitor  (TranscodedImageCache_000)
    -Index 1   second monitor (TranscodedImageCache_001)
    omitted    one wallpaper -> opens directly
               several       -> picker with filenames and previews
#>
param([int]$Index = -1)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Hide the console window this script was launched in. -WindowStyle Hidden alone
# leaves it on screen while the dialog is open, so hide it explicitly.
try {
    Add-Type -Name Win -Namespace Con -MemberDefinition '
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    ' -ErrorAction Stop
    $console = [Con.Win]::GetConsoleWindow()
    if ($console -ne [IntPtr]::Zero) { [void][Con.Win]::ShowWindow($console, 0) }
} catch { }

function Show-Warning($text) {
    [System.Windows.Forms.MessageBox]::Show(
        $text, "Wallpaper location", 'OK', 'Warning') | Out-Null
}

function Get-WallpaperPaths {
    $key = 'HKCU:\Control Panel\Desktop'
    $all = (Get-Item $key).GetValueNames()

    # Numbered values are per-monitor. Fall back to the legacy single value.
    $names = @($all | Where-Object { $_ -match '^TranscodedImageCache_\d+$' } | Sort-Object)
    if ($names.Count -eq 0) {
        $names = @($all | Where-Object { $_ -eq 'TranscodedImageCache' })
    }

    foreach ($n in $names) {
        try {
            $data = (Get-ItemProperty $key -Name $n).$n
            $s = [Text.Encoding]::Unicode.GetString($data[24..($data.Length - 1)])
            $i = $s.IndexOf([char]0)
            if ($i -gt 0) { $s.Substring(0, $i) }
        } catch { }
    }
}

function Open-InExplorer($paths) {
    $opened = $false
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) { explorer.exe "/select,`"$p`""; $opened = $true }
    }
    if (-not $opened) {
        Show-Warning "The wallpaper file no longer exists at:`r`n`r`n$($paths -join "`r`n")"
    }
}

function Read-ImageUnlocked($path) {
    # Load via memory stream so Explorer/Settings can still touch the file
    try {
        $bytes = [IO.File]::ReadAllBytes($path)
        $ms = New-Object IO.MemoryStream(,$bytes)
        return [System.Drawing.Image]::FromStream($ms)
    } catch { return $null }
}

function Show-Picker($paths) {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Which wallpaper?"
    $form.Size = New-Object Drawing.Size(620, 400)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object Drawing.Size(500, 320)

    $list = New-Object Windows.Forms.ListBox
    $list.Location = New-Object Drawing.Point(12, 12)
    $list.Size = New-Object Drawing.Size(250, 300)
    $list.Anchor = 'Top,Left,Bottom'
    $list.IntegralHeight = $false
    for ($i = 0; $i -lt $paths.Count; $i++) {
        [void]$list.Items.Add("Monitor $($i + 1) - " + (Split-Path $paths[$i] -Leaf))
    }
    $form.Controls.Add($list)

    $pic = New-Object Windows.Forms.PictureBox
    $pic.Location = New-Object Drawing.Point(274, 12)
    $pic.Size = New-Object Drawing.Size(320, 250)
    $pic.Anchor = 'Top,Left,Right,Bottom'
    $pic.SizeMode = 'Zoom'
    $pic.BorderStyle = 'FixedSingle'
    $form.Controls.Add($pic)

    $label = New-Object Windows.Forms.Label
    $label.Location = New-Object Drawing.Point(274, 268)
    $label.Size = New-Object Drawing.Size(320, 44)
    $label.Anchor = 'Left,Right,Bottom'
    $form.Controls.Add($label)

    $list.Add_SelectedIndexChanged({
        $p = $paths[$list.SelectedIndex]
        $label.Text = $p
        if ($pic.Image) { $pic.Image.Dispose() }
        $pic.Image = Read-ImageUnlocked $p
    })

    $open = New-Object Windows.Forms.Button
    $open.Text = "Open location"
    $open.Size = New-Object Drawing.Size(110, 30)
    $open.Location = New-Object Drawing.Point(274, 320)
    $open.Anchor = 'Bottom,Left'
    $open.Add_Click({ Open-InExplorer @($paths[$list.SelectedIndex]); $form.Close() })
    $form.Controls.Add($open)

    $all = New-Object Windows.Forms.Button
    $all.Text = "Open all"
    $all.Size = New-Object Drawing.Size(90, 30)
    $all.Location = New-Object Drawing.Point(392, 320)
    $all.Anchor = 'Bottom,Left'
    $all.Add_Click({ Open-InExplorer $paths; $form.Close() })
    $form.Controls.Add($all)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "Cancel"
    $cancel.Size = New-Object Drawing.Size(90, 30)
    $cancel.Location = New-Object Drawing.Point(490, 320)
    $cancel.Anchor = 'Bottom,Left'
    $cancel.Add_Click({ $form.Close() })
    $form.Controls.Add($cancel)

    $form.AcceptButton = $open
    $form.CancelButton = $cancel
    $list.SelectedIndex = 0
    [void]$form.ShowDialog()
    if ($pic.Image) { $pic.Image.Dispose() }
    $form.Dispose()
}

if ($Index -ge 0) {
    $all = @(Get-WallpaperPaths)
    if ($Index -ge $all.Count -or -not $all[$Index]) {
        Show-Warning "No wallpaper is recorded for monitor $($Index + 1)."
    } else {
        Open-InExplorer @($all[$Index])
    }
    return
}

$paths = @(Get-WallpaperPaths | Where-Object { $_ } | Select-Object -Unique)

if ($paths.Count -eq 0) {
    Show-Warning "Could not read the wallpaper path from the registry."
} elseif ($paths.Count -eq 1) {
    Open-InExplorer $paths
} else {
    Show-Picker $paths
}

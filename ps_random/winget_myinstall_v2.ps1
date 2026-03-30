# Winget Interactive Installer - TUI Checkbox Menu
# Navigate: Arrow Keys | Toggle: Space | Select All: A | None: N | Install: Enter | Quit: Esc
# On a category row, Space toggles all packages in that group.

# ============================================================================
# Package Catalog
# ============================================================================
$Catalog = [ordered]@{
    "Browsers" = @(
        @{ Id = "Google.Chrome";              Name = "Google Chrome" }
        @{ Id = "Mozilla.Firefox";            Name = "Mozilla Firefox" }
    )
    "Azure & Cloud Tools" = @(
        @{ Id = "Microsoft.Azure.AZCopy.10";       Name = "AzCopy 10" }
        @{ Id = "Microsoft.AzureCLI";              Name = "Azure CLI" }
        @{ Id = "Microsoft.Bicep";                 Name = "Bicep" }
        @{ Id = "Microsoft.Azure.StorageExplorer"; Name = "Azure Storage Explorer" }
        @{ Id = "Microsoft.AzureVPNClient";        Name = "Azure VPN Client" }
    )
    "Development Tools" = @(
        @{ Id = "Microsoft.PowerShell";       Name = "PowerShell 7" }
        @{ Id = "Git.Git";                    Name = "Git" }
        @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" }
        @{ Id = "Python.Python.3.12";         Name = "Python 3.12" }
        @{ Id = "GoLang.Go";                  Name = "Go" }
        @{ Id = "Hashicorp.Terraform";        Name = "Terraform" }
        @{ Id = "Microsoft.NuGet";            Name = "NuGet" }
    )
    "AI Coding Assistants" = @(
        @{ Id = "Tencent.CodeBuddy";          Name = "Tencent CodeBuddy" }
        @{ Id = "Anthropic.ClaudeCode";       Name = "Claude Code" }
        @{ Id = "github.copilot";             Name = "GitHub Copilot" }
    )
    ".NET Runtimes" = @(
        @{ Id = "Microsoft.DotNet.DesktopRuntime.8"; Name = ".NET Desktop Runtime 8" }
        @{ Id = "Microsoft.DotNet.Runtime.8";        Name = ".NET Runtime 8" }
    )
    "Java Runtime" = @(
        @{ Id = "Microsoft.OpenJDK.21";       Name = "Microsoft OpenJDK 21" }
    )
    "Editors & IDEs" = @(
        @{ Id = "Notepad++.Notepad++";        Name = "Notepad++" }
        @{ Id = "SublimeHQ.SublimeText.4";    Name = "Sublime Text 4" }
    )
    "Utilities" = @(
        @{ Id = "ScooterSoftware.BeyondCompare.5"; Name = "Beyond Compare 5" }
        @{ Id = "JGraph.Draw";                     Name = "draw.io" }
        @{ Id = "FastStone.Capture";               Name = "FastStone Capture" }
        @{ Id = "PuTTY.PuTTY";                    Name = "PuTTY" }
        @{ Id = "WinSCP.WinSCP";                  Name = "WinSCP" }
        @{ Id = "Microsoft.Sysinternals.Suite";    Name = "Sysinternals Suite" }
    )
    "Network & Debugging Tools" = @(
        @{ Id = "Telerik.Fiddler.Classic";    Name = "Fiddler Classic" }
        @{ Id = "WiresharkFoundation.Wireshark"; Name = "Wireshark" }
        @{ Id = "Insomnia.Insomnia";          Name = "Insomnia" }
    )
    "Database Tools" = @(
        @{ Id = "Microsoft.Sqlcmd";           Name = "sqlcmd" }
    )
    "Media Tools" = @(
        @{ Id = "Gyan.FFmpeg";                Name = "FFmpeg" }
        @{ Id = "VideoLAN.VLC";               Name = "VLC" }
        @{ Id = "XnSoft.XnViewMP";            Name = "XnView MP" }
        @{ Id = "ImageMagick.ImageMagick";    Name = "ImageMagick" }
    )
    "VC++ Redistributable" = @(
        @{ Id = "Microsoft.VCRedist.2015+.x64"; Name = "VC++ 2015-2022 x64" }
    )
}

$PSModules = @(
    @{ Name = "AzureAd";         Desc = "Azure Active Directory" }
    @{ Name = "Microsoft.Graph"; Desc = "Microsoft Graph" }
    @{ Name = "MSAL.PS";         Desc = "MSAL Authentication" }
    @{ Name = "PowerShellGet";   Desc = "PowerShellGet" }
    @{ Name = "Az";              Desc = "Azure PowerShell"; Repo = "PSGallery" }
)

# ============================================================================
# Build flat menu item list from catalog
# ============================================================================
function Build-MenuItems {
    $items = [System.Collections.ArrayList]::new()
    $first = $true
    foreach ($cat in $script:Catalog.Keys) {
        if (-not $first) { [void]$items.Add(@{ Type = 'Blank' }) }
        $first = $false
        [void]$items.Add(@{ Type = 'Category'; Name = $cat })
        foreach ($pkg in $script:Catalog[$cat]) {
            [void]$items.Add(@{
                Type     = 'Package'
                Name     = $pkg.Name
                Id       = $pkg.Id
                Category = $cat
                Selected = $false
            })
        }
    }
    return $items
}

# ============================================================================
# Rendering helpers
# ============================================================================
function Write-At {
    param([int]$Row, [string]$Text, [string]$FG = 'Gray', $BG = $null, [int]$Width)
    [Console]::SetCursorPosition(0, $Row)
    $w = [Math]::Max(1, $Width)
    $padded = $Text.PadRight($w)
    if ($padded.Length -gt $w) { $padded = $padded.Substring(0, $w) }
    $p = @{ Object = $padded; NoNewline = $true; ForegroundColor = $FG }
    if ($null -ne $BG) { $p.BackgroundColor = $BG }
    Write-Host @p
}

function Render-Menu {
    param($Items, [int]$Pos, [int]$ViewStart, [int]$ViewHeight, [int]$Width)
    $hdr = 4  # header rows

    # Precompute category counts
    $catSel = @{}; $catTot = @{}
    $totalPkg = 0; $totalSel = 0
    foreach ($it in $Items) {
        if ($it.Type -eq 'Package') {
            $c = $it.Category
            if (-not $catTot.ContainsKey($c)) { $catTot[$c] = 0; $catSel[$c] = 0 }
            $catTot[$c]++; $totalPkg++
            if ($it.Selected) { $catSel[$c]++; $totalSel++ }
        }
    }

    # Header
    Write-At -Row 0 -Text ("=" * $Width) -FG DarkGray -Width $Width
    Write-At -Row 1 -Text "  Winget Interactive Installer" -FG Cyan -Width $Width
    Write-At -Row 2 -Text ("=" * $Width) -FG DarkGray -Width $Width
    Write-At -Row 3 -Text "" -Width $Width

    # Scroll indicators
    $canUp = ($ViewStart -gt 0)
    $canDn = (($ViewStart + $ViewHeight) -lt $Items.Count)

    # Viewport
    for ($vi = 0; $vi -lt $ViewHeight; $vi++) {
        $idx = $ViewStart + $vi
        $row = $hdr + $vi
        if ($idx -ge $Items.Count) {
            Write-At -Row $row -Text "" -Width $Width
            continue
        }
        $item = $Items[$idx]
        $cur = ($idx -eq $Pos)

        switch ($item.Type) {
            'Blank' {
                Write-At -Row $row -Text "" -Width $Width
            }
            'Category' {
                $s = $catSel[$item.Name]; $t = $catTot[$item.Name]
                $mark = if ($cur) { " >> " } else { "    " }
                $lbl = "$mark$($item.Name)"
                $cnt = "[$s/$t]"
                $gap = [Math]::Max(1, $Width - $lbl.Length - $cnt.Length)
                $line = "$lbl$(' ' * $gap)$cnt"
                if ($cur) {
                    Write-At -Row $row -Text $line -FG White -BG DarkCyan -Width $Width
                } else {
                    Write-At -Row $row -Text $line -FG Yellow -Width $Width
                }
            }
            'Package' {
                $chk = if ($item.Selected) { "[X]" } else { "[ ]" }
                $ptr = if ($cur) { "   > " } else { "     " }
                $lbl = "$ptr$chk $($item.Name)"
                $id  = $item.Id
                $gap = [Math]::Max(1, $Width - $lbl.Length - $id.Length)
                $line = "$lbl$(' ' * $gap)$id"
                if ($cur) {
                    Write-At -Row $row -Text $line -FG White -BG DarkBlue -Width $Width
                } else {
                    $fg = if ($item.Selected) { "Green" } else { "DarkGray" }
                    Write-At -Row $row -Text $line -FG $fg -Width $Width
                }
            }
        }
    }

    # Footer
    $fr = $hdr + $ViewHeight
    $scroll = ""
    if ($canUp) { $scroll += " [more above]" }
    if ($canDn) { $scroll += " [more below]" }
    Write-At -Row $fr     -Text $scroll -FG DarkYellow -Width $Width
    Write-At -Row ($fr+1) -Text "  Up/Dn:Move  Space:Toggle  A:All  N:None  Enter:Install  Esc:Quit" -FG DarkGray -Width $Width
    Write-At -Row ($fr+2) -Text "  $totalSel of $totalPkg packages selected" -FG Cyan -Width $Width
}

# ============================================================================
# Main TUI Loop - returns selected packages
# ============================================================================
function Show-CheckboxMenu {
    if ($host.Name -eq 'Windows PowerShell ISE Host') {
        Write-Host "This script requires a real console (pwsh.exe or powershell.exe), not ISE." -ForegroundColor Red
        return @()
    }

    $items = Build-MenuItems
    $pos = 0
    while ($pos -lt $items.Count -and $items[$pos].Type -eq 'Blank') { $pos++ }

    $viewStart = 0
    $prevW = 0; $prevH = 0

    [Console]::CursorVisible = $false

    try {
        while ($true) {
            $w = [Console]::WindowWidth - 1
            $h = [Console]::WindowHeight
            if ($w -ne $prevW -or $h -ne $prevH) { Clear-Host; $prevW = $w; $prevH = $h }

            $vH = [Math]::Max(3, $h - 7)

            # Keep cursor in view
            if ($pos -lt $viewStart) { $viewStart = $pos }
            if ($pos -ge $viewStart + $vH) { $viewStart = $pos - $vH + 1 }
            $viewStart = [Math]::Max(0, [Math]::Min($viewStart, [Math]::Max(0, $items.Count - $vH)))

            Render-Menu -Items $items -Pos $pos -ViewStart $viewStart -ViewHeight $vH -Width $w

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    $n = $pos - 1
                    while ($n -ge 0 -and $items[$n].Type -eq 'Blank') { $n-- }
                    if ($n -ge 0) { $pos = $n }
                }
                'DownArrow' {
                    $n = $pos + 1
                    while ($n -lt $items.Count -and $items[$n].Type -eq 'Blank') { $n++ }
                    if ($n -lt $items.Count) { $pos = $n }
                }
                'PageUp' {
                    for ($i = 0; $i -lt $vH; $i++) {
                        $n = $pos - 1
                        while ($n -ge 0 -and $items[$n].Type -eq 'Blank') { $n-- }
                        if ($n -ge 0) { $pos = $n } else { break }
                    }
                }
                'PageDown' {
                    for ($i = 0; $i -lt $vH; $i++) {
                        $n = $pos + 1
                        while ($n -lt $items.Count -and $items[$n].Type -eq 'Blank') { $n++ }
                        if ($n -lt $items.Count) { $pos = $n } else { break }
                    }
                }
                'Home' {
                    $pos = 0
                    while ($pos -lt $items.Count -and $items[$pos].Type -eq 'Blank') { $pos++ }
                }
                'End' {
                    $pos = $items.Count - 1
                    while ($pos -ge 0 -and $items[$pos].Type -eq 'Blank') { $pos-- }
                }
                'Spacebar' {
                    if ($items[$pos].Type -eq 'Package') {
                        $items[$pos].Selected = -not $items[$pos].Selected
                    }
                    elseif ($items[$pos].Type -eq 'Category') {
                        $cat = $items[$pos].Name
                        $allOn = $true
                        foreach ($it in $items) {
                            if ($it.Type -eq 'Package' -and $it.Category -eq $cat -and -not $it.Selected) {
                                $allOn = $false; break
                            }
                        }
                        $set = -not $allOn
                        foreach ($it in $items) {
                            if ($it.Type -eq 'Package' -and $it.Category -eq $cat) { $it.Selected = $set }
                        }
                    }
                }
                'Enter' {
                    Clear-Host
                    [Console]::CursorVisible = $true
                    $sel = @()
                    foreach ($it in $items) {
                        if ($it.Type -eq 'Package' -and $it.Selected) { $sel += $it }
                    }
                    return $sel
                }
                'Escape' {
                    Clear-Host
                    [Console]::CursorVisible = $true
                    return @()
                }
                default {
                    $ch = $key.KeyChar
                    if ($ch -eq 'a' -or $ch -eq 'A') {
                        foreach ($it in $items) { if ($it.Type -eq 'Package') { $it.Selected = $true } }
                    }
                    elseif ($ch -eq 'n' -or $ch -eq 'N') {
                        foreach ($it in $items) { if ($it.Type -eq 'Package') { $it.Selected = $false } }
                    }
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

# ============================================================================
# Install selected packages
# ============================================================================
function Install-WingetPackages {
    param([array]$Packages)
    if ($Packages.Count -eq 0) {
        Write-Host "`n  No packages selected." -ForegroundColor DarkGray
        return
    }

    Write-Host "`n  ============================================" -ForegroundColor DarkGray
    Write-Host "  $($Packages.Count) package(s) selected:" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor DarkGray

    $lastCat = ""
    foreach ($pkg in $Packages) {
        if ($pkg.Category -ne $lastCat) {
            $lastCat = $pkg.Category
            Write-Host "`n  $lastCat" -ForegroundColor Yellow
        }
        Write-Host "    - $($pkg.Name) " -NoNewline
        Write-Host "($($pkg.Id))" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  Proceed with install? [Y/n]: " -ForegroundColor Cyan -NoNewline
    $ans = Read-Host
    if ($ans -match '^[Nn]') {
        Write-Host "  Cancelled." -ForegroundColor DarkGray
        return
    }

    Write-Host ""
    $ok = 0; $fail = 0
    foreach ($pkg in $Packages) {
        $i = $ok + $fail + 1
        Write-Host "  [$i/$($Packages.Count)] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($pkg.Name) " -NoNewline -ForegroundColor Cyan
        winget install --id $pkg.Id -e --accept-package-agreements --accept-source-agreements --silent 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OK" -ForegroundColor Green
            $ok++
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            $fail++
        }
    }

    $color = if ($fail -gt 0) { "Yellow" } else { "Green" }
    Write-Host "`n  Done: $ok succeeded, $fail failed`n" -ForegroundColor $color
}

# ============================================================================
# Post-install options
# ============================================================================
function Show-PostInstall {
    Write-Host "  ============================================" -ForegroundColor DarkGray
    Write-Host "  Post-Install Options" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [1] Enable .NET Framework 3.5"
    Write-Host "  [2] Install PowerShell Modules (Az, Graph, AzureAD, MSAL)"
    Write-Host "  [3] Upgrade all winget packages"
    Write-Host "  [4] All of the above"
    Write-Host "  [S] Skip"
    Write-Host ""
    Write-Host "  Select: " -NoNewline
    $ch = Read-Host

    if ($ch -match '[14]') {
        Write-Host "`n  Enabling .NET Framework 3.5..." -ForegroundColor Cyan
        Dism /online /enable-feature /featurename:NetFX3 /All /Source:D:\Kuaipan\setup\NetFX /LimitAccess
    }
    if ($ch -match '[24]') {
        Write-Host "`n  Installing PowerShell Modules..." -ForegroundColor Cyan
        foreach ($mod in $script:PSModules) {
            Write-Host "    $($mod.Name)... " -NoNewline -ForegroundColor Gray
            $p = @{ Name = $mod.Name; Force = $true }
            if ($mod.Repo) { $p.Repository = $mod.Repo }
            try {
                Install-Module @p -ErrorAction Stop
                Write-Host "OK" -ForegroundColor Green
            } catch {
                Write-Host "FAILED" -ForegroundColor Red
            }
        }
    }
    if ($ch -match '[34]') {
        Write-Host "`n  Upgrading all winget packages..." -ForegroundColor Cyan
        winget upgrade --all --accept-package-agreements --accept-source-agreements --silent
    }
}

# ============================================================================
# Entry Point
# ============================================================================
$selected = Show-CheckboxMenu
Install-WingetPackages -Packages $selected
if ($selected.Count -gt 0) {
    Show-PostInstall
}

# Winget Interactive Installer - TUI Checkbox Menu  (v2.3)
# Navigate: Arrow Keys | Toggle: Space | Select All: A | None: N | Install: Enter | Quit: Esc
# On a category row, Space toggles all packages in that group.
#
# v2.4 changes:
#   a. The script runs as the current user by default. Use -Elevate when the
#      whole session must run as Administrator.
#   b. The Non-Administrator Installers category runs winget with a limited token
#      of the elevated account. If UAC uses a different account, run Office from
#      the intended user's shell without -Elevate instead.
#   c. PowerShell modules install to CurrentUser scope (no admin needed).
#   d. Microsoft.Entra replaces the retired AzureAD module.
#   e. Installation start and completion lines include UTC timestamps.
#
# v2.1 changes:
#   a. Self-elevation: re-launches itself as Administrator if not already elevated.
#   b. Enables winget setting "InstallerHashOverride" at startup.
#   c. New "Microsoft Store Apps" category - installed with the msstore parameter
#      set: --source msstore --accept-package-agreements --accept-source-agreements
#   d. All non-msstore installs now append --ignore-security-hash.
#   e. PowerShell Modules are selectable in the menu (installed via Install-Module).

# ============================================================================
# Script options
# ============================================================================
param(
    [switch]$Elevate,
    [switch]$NoElevation
)

# ============================================================================
# Package Catalog
# ============================================================================
$Catalog = [ordered]@{
    "Browsers" = @(
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
        @{ Id = "Python.Python.3.14";         Name = "Python 3.14" }
        @{ Id = "GoLang.Go";                  Name = "Go" }
        @{ Id = "Hashicorp.Terraform";        Name = "Terraform" }
        @{ Id = "Microsoft.NuGet";            Name = "NuGet" }
        @{ Id = "OpenJS.NodeJS";              Name = "Node.js" }
    )
    "AI Coding Assistants" = @(
        @{ Id = "Tencent.WorkBuddy";          Name = "Tencent WorkBuddy" }
        #@{ Id = "Anthropic.ClaudeCode";       Name = "Claude Code" }
        @{ Id = "GitHub.Copilot";             Name = "GitHub Copilot" }
        @{ Id = "GitHub.CopilotApp";          Name = "GitHub Copilot App" }
        @{ Id = "GitHub.cli";                 Name = "GitHub CLI" }
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
        @{ Id = "Microsoft.WindowsApp";            Name = "Windows App" }
    )    
    "Network & Debugging Tools" = @(
        @{ Id = "WiresharkFoundation.Wireshark"; Name = "Wireshark" }
        @{ Id = "Telerik.Fiddler.Classic";    Name = "Fiddler Classic" }
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

# ----------------------------------------------------------------------------
# Packages that must be installed from a non-administrator process.
# ----------------------------------------------------------------------------
$NonAdminCatalog = [ordered]@{
    "Non-Administrator Installers" = @(
        @{ Id = "Google.Chrome"; Name = "Google Chrome" }
        @{ Id = "Microsoft.Office"; Name = "Microsoft Office" }
    )
}

# ----------------------------------------------------------------------------
# Microsoft Store Catalog
# Installed with a DIFFERENT winget parameter set (Store product IDs, not repo IDs):
#   winget install --id <StoreId> --source msstore --accept-package-agreements --accept-source-agreements
# ----------------------------------------------------------------------------
$MsStoreCatalog = [ordered]@{
    "Microsoft Store Apps" = @(
        @{ Id = "9MSPC6MP8FM4";  Name = "Microsoft Whiteboard" }
    )
}

$PSModules = @(
    @{ Name = "Microsoft.Entra"; Desc = "Microsoft Entra PowerShell"; Repo = "PSGallery"; AllowClobber = $true }
    @{ Name = "Microsoft.Graph"; Desc = "Microsoft Graph" }
    @{ Name = "MSAL.PS";         Desc = "MSAL Authentication" }
    @{ Name = "PowerShellGet";   Desc = "PowerShellGet" }
    @{ Name = "Az";              Desc = "Azure PowerShell"; Repo = "PSGallery"; AllowClobber = $true }
)

# ============================================================================
# Build flat menu item list from catalog
# ============================================================================
function Build-MenuItems {
    $items = [System.Collections.ArrayList]::new()
    $first = $true

    # Catalog sources: regular winget, explicitly non-admin winget, and Microsoft Store.
    $sources = @(
        @{ Data = $script:Catalog;        Source = 'winget';  InstallMode = 'Administrator' }
        @{ Data = $script:NonAdminCatalog; Source = 'winget'; InstallMode = 'NonAdministrator' }
        @{ Data = $script:MsStoreCatalog; Source = 'msstore'; InstallMode = 'Administrator' }
    )

    foreach ($entry in $sources) {
        $catData = $entry.Data
        $src     = $entry.Source
        foreach ($cat in $catData.Keys) {
            if (-not $first) { [void]$items.Add(@{ Type = 'Blank' }) }
            $first = $false
            [void]$items.Add(@{
                Type = 'Category'; Name = $cat; Source = $src; InstallMode = $entry.InstallMode
            })
            foreach ($pkg in $catData[$cat]) {
                [void]$items.Add(@{
                    Type     = 'Package'
                    Name     = $pkg.Name
                    Id       = $pkg.Id
                    Category = $cat
                    Source   = $src
                    InstallMode = $entry.InstallMode
                    Selected = $false
                })
            }
        }
    }

    # PowerShell modules: selectable too, but installed with Install-Module (not winget)
    if ($script:PSModules.Count -gt 0) {
        $modCat = "PowerShell Modules"
        [void]$items.Add(@{ Type = 'Blank' })
        [void]$items.Add(@{ Type = 'Category'; Name = $modCat; Source = 'psmodule' })
        foreach ($mod in $script:PSModules) {
            [void]$items.Add(@{
                Type     = 'Package'
                Name     = $mod.Name
                Id       = $mod.Name
                Desc     = $mod.Desc
                Repo     = $mod.Repo
                AllowClobber = $mod.AllowClobber
                Category = $modCat
                Source   = 'psmodule'
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
                $tag = switch ($item.Source) {
                    'msstore'  { " [Store]" }
                    'psmodule' { " [Module]" }
                    default    { if ($item.InstallMode -eq 'NonAdministrator') { " [Non-Admin]" } else { "" } }
                }
                $lbl = "$ptr$chk $($item.Name)$tag"
                $id  = if ($item.Source -eq 'psmodule') { $item.Desc } else { $item.Id }
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
function Get-UtcTimestamp {
    return [DateTime]::UtcNow.ToString(
        'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
}

function Install-PSModuleItem {
    param([hashtable]$Module)
    # CurrentUser scope: works without Administrator rights.
    $p = @{ Name = $Module.Name; Force = $true; Scope = 'CurrentUser'; ErrorAction = 'Stop' }
    if ($Module.Repo) { $p.Repository = $Module.Repo }
    if ($Module.AllowClobber) { $p.AllowClobber = $true }
    try {
        Install-Module @p | Out-Null
        return $true
    }
    catch {
        Write-Host $($_.Exception.Message) -ForegroundColor DarkRed
        return $false
    }
}

function Invoke-WingetNonAdmin {
    param(
        [string[]]$Arguments
    )

    $taskName = "WingetInstaller-{0}" -f [guid]::NewGuid().ToString('N')
    $resultPath = Join-Path $env:TEMP "$taskName.result"
    $outputPath = Join-Path $env:TEMP "$taskName.log"
    $registered = $false

    try {
        $psExe = (Get-Process -Id $PID).Path
        $wingetExe = (Get-Command winget.exe -CommandType Application -ErrorAction Stop).Source
        $exeLiteral = "'$($wingetExe.Replace("'", "''"))'"
        $resultLiteral = "'$($resultPath.Replace("'", "''"))'"
        $outputLiteral = "'$($outputPath.Replace("'", "''"))'"
        $argumentText = ($Arguments | ForEach-Object {
            "'" + $_.Replace("'", "''") + "'"
        }) -join ', '
        $child = @"
`$ErrorActionPreference = 'Continue'
`$wingetArguments = @($argumentText)
try {
    & $exeLiteral @wingetArguments *>&1 | Out-File -LiteralPath $outputLiteral -Encoding utf8
    `$code = `$LASTEXITCODE
    if (`$null -eq `$code) { throw 'winget returned no exit code.' }
}
catch {
    `$_ | Out-File -LiteralPath $outputLiteral -Encoding utf8 -Append
    `$code = 1
}
Set-Content -LiteralPath $resultLiteral -Value `$code -Encoding ascii
exit `$code
"@
        $encoded = [Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($child))
        $taskArguments = "-NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded"
        $userName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $action = New-ScheduledTaskAction -Execute $psExe -Argument $taskArguments
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
        $principal = New-ScheduledTaskPrincipal -UserId $userName `
            -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action `
            -Trigger $trigger -Principal $principal -Force -ErrorAction Stop | Out-Null
        $registered = $true
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop

        $startedAt = Get-Date
        $deadline = $startedAt.AddHours(2)
        $nextStatus = $startedAt.AddMinutes(1)
        while (-not (Test-Path -LiteralPath $resultPath)) {
            $now = Get-Date
            if ($now -ge $deadline) {
                throw "Timed out waiting for non-administrator winget task $taskName."
            }
            if ($now -ge $startedAt.AddSeconds(15)) {
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
                if ($task.State -notin @('Running', 'Queued') -and
                    -not (Test-Path -LiteralPath $resultPath)) {
                    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
                    throw "Non-administrator task $taskName ended or did not start (state: $($task.State), result: $($info.LastTaskResult))."
                }
            }
            if ($now -ge $nextStatus) {
                Write-Host "  Still waiting for $taskName..." -ForegroundColor DarkGray
                $nextStatus = $now.AddMinutes(1)
            }
            Start-Sleep -Seconds 2
        }

        $resultText = (Get-Content -LiteralPath $resultPath -Raw -ErrorAction Stop).Trim()
        $code = 0
        if (-not [int]::TryParse($resultText, [ref]$code)) {
            throw "Non-administrator task $taskName returned an invalid exit code: '$resultText'."
        }
        if (Test-Path -LiteralPath $outputPath) {
            Get-Content -LiteralPath $outputPath | Write-Host
        }
        return $code
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        return 1
    }
    finally {
        $task = if ($registered) { Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue }
        if ($task -and $task.State -in @('Running', 'Queued') -and
            (Test-Path -LiteralPath $resultPath)) {
            $exitDeadline = (Get-Date).AddSeconds(15)
            do {
                Start-Sleep -Milliseconds 500
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            } while ($task -and $task.State -in @('Running', 'Queued') -and
                (Get-Date) -lt $exitDeadline)
        }
        if ($task -and $task.State -in @('Running', 'Queued')) {
            Write-Host "  Task $taskName is still active; inspect it and $outputPath before retrying." -ForegroundColor Yellow
        }
        else {
            if ($registered) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            }
            Remove-Item -LiteralPath $resultPath, $outputPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-WingetInstall {
    param(
        [hashtable]$Package,
        [string[]]$Arguments
    )

    if ($Package.InstallMode -eq 'NonAdministrator' -and (Test-IsAdmin)) {
        return Invoke-WingetNonAdmin -Arguments $Arguments
    }

    # Preserve winget's native console output without returning it as a status value.
    $wingetExe = (Get-Command winget.exe -CommandType Application -ErrorAction Stop).Source
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($wingetExe, ($Arguments -join ' '))
    $startInfo.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $process.WaitForExit()
        return $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

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
    $ok = 0; $present = 0; $fail = 0
    foreach ($pkg in $Packages) {
        $i = $ok + $present + $fail + 1
        $mode = switch ($pkg.Source) {
            'msstore'  { 'msstore' }
            'psmodule' { 'module' }
            default {
                if ($pkg.InstallMode -eq 'NonAdministrator') {
                    'winget non-admin'
                } elseif (Test-IsAdmin) {
                    'winget admin'
                } else {
                    'winget user'
                }
            }
        }
        Write-Host "[$(Get-UtcTimestamp)] UTC [$i/$($Packages.Count)] Installing $($pkg.Name) ($($pkg.Id)) [$mode]" -ForegroundColor Cyan

        $code = 0
        switch ($pkg.Source) {
            'msstore' {
                # Microsoft Store apps: different parameter set, no --ignore-security-hash
                $args = @(
                    'install', '--id', $pkg.Id, '-e', '--source', 'msstore',
                    '--accept-package-agreements', '--accept-source-agreements'
                )
                $code = Invoke-WingetInstall -Package $pkg -Arguments $args
            }
            'psmodule' {
                # PowerShell modules: Install-Module, not winget
                if (Install-PSModuleItem -Module $pkg) { $code = 0 } else { $code = 1 }
            }
            default {
                # Regular winget repo: always allow a stale CDN installer hash
                $args = @(
                    'install', '--id', $pkg.Id, '-e', '--accept-package-agreements',
                    '--accept-source-agreements', '--silent', '--ignore-security-hash'
                )
                $code = Invoke-WingetInstall -Package $pkg -Arguments $args
            }
        }

        $completed = "[$(Get-UtcTimestamp)] UTC [$i/$($Packages.Count)] $($pkg.Name):"
        if ($code -eq 0) {
            Write-Host "$completed OK" -ForegroundColor Green
            $ok++
        } elseif ($code -eq -1978335189 -or $code -eq -1978335135) {
            # WinGet: 0x8A15002B (no update) and 0x8A150061 (already installed).
            $status = if ($code -eq -1978335189) { "UP TO DATE" } else { "ALREADY INSTALLED" }
            Write-Host "$completed $status" -ForegroundColor DarkGreen
            $present++
        } else {
            $detail = if ($pkg.Source -eq 'psmodule') {
                ""
            } else {
                " (winget exit 0x{0:X8})" -f [uint32]([long]$code -band 0xFFFFFFFFL)
            }
            Write-Host "$completed FAILED$detail" -ForegroundColor Red
            $fail++
        }
    }

    $color = if ($fail -gt 0) { "Yellow" } else { "Green" }
    Write-Host "`n  Done: $ok succeeded, $present already present, $fail failed`n" -ForegroundColor $color
}

# ============================================================================
# Elevation helpers
# ============================================================================
function Test-IsAdmin {
    $principal = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-RunAsAdmin {
    if (Test-IsAdmin) {
        Write-Host "  [OK] Running with Administrator privileges." -ForegroundColor Green
        return
    }

    if (-not $script:Elevate -or $script:NoElevation) {
        Write-Host "  [OK] Running as the current user (winget hash override is supported)." -ForegroundColor Green
        return
    }

    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) {
        Write-Host "  [X] Cannot self-elevate: script path is unavailable." -ForegroundColor Red
        exit 1
    }

    Write-Host "  [!] -Elevate specified - requesting Administrator privileges..." -ForegroundColor Yellow
    $exe = (Get-Process -Id $PID).Path
    $argList = "-NoProfile -NoLogo -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`""
    try {
        Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs `
            -WorkingDirectory (Get-Location).Path -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "  [X] Elevation cancelled or denied: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# ============================================================================
# Winget InstallerHashOverride configuration
# ============================================================================
function Enable-InstallerHashOverride {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [X] winget not found. Install 'App Installer' from the Microsoft Store." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Enabling winget setting 'InstallerHashOverride'... " -NoNewline -ForegroundColor Gray
    $output = @(winget settings --enable InstallerHashOverride 2>&1)
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    }
    else {
        Write-Host "FAILED" -ForegroundColor Yellow
        Write-Host "       (older winget builds lack this setting; --ignore-security-hash is still passed)" -ForegroundColor DarkGray
        foreach ($line in $output) { Write-Host "       $line" -ForegroundColor DarkGray }
    }
}

# Native winget output is UTF-8. Set the console encoding before launching it
# so status and progress characters are rendered consistently in pwsh.exe.
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
[Console]::InputEncoding = $utf8
$OutputEncoding = $utf8

# ============================================================================
# Entry Point
# ============================================================================
Assert-RunAsAdmin
Write-Host "  Running as $([Security.Principal.WindowsIdentity]::GetCurrent().Name) " -NoNewline -ForegroundColor DarkGray
Write-Host $(if (Test-IsAdmin) { "(Administrator)" } else { "(standard user)" }) -ForegroundColor DarkGray
Enable-InstallerHashOverride

$selected = Show-CheckboxMenu
Install-WingetPackages -Packages $selected

# ============================================================================
# Reference
# ============================================================================
# Store-only app (not in the winget repo):
#   winget install --id 9MSPC6MP8FM4 --source msstore --accept-package-agreements --accept-source-agreements
#
# Repo app whose installer hash on the vendor CDN is stale (run Office non-admin):
#   winget install --id Microsoft.Office -e --ignore-security-hash
#
# Find a Store product ID:
#   winget search "<name>" --source msstore --accept-source-agreements

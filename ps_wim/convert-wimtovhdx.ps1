<#
.SYNOPSIS
    Converts a Windows install.wim / install.esd (or a Windows ISO) into a bootable VHD/VHDX.

.DESCRIPTION
    Convert-WimToVhdx.ps1 creates a virtual disk, partitions it (UEFI/GPT or BIOS/MBR),
    applies a Windows image with DISM, writes boot files with bcdboot and optionally
    injects drivers, an unattend.xml and a WinRE recovery partition.

    Typical uses:
      * Build a Hyper-V Generation 2 (UEFI) VHDX straight from an ISO.
      * Build a native boot (boot-to-VHD) VHDX on the running machine.
      * Slipstream drivers / unattend into a VHDX that is later uploaded to Azure
        or deployed to physical hardware.

    Requirements:
      * Windows 10/11 or Windows Server 2016+ with DISM.
      * Elevated (Run as Administrator) PowerShell.
      * Hyper-V PowerShell module (Windows feature "Microsoft-Hyper-V-Management-PowerShell").
        The Hyper-V role / hypervisor itself is NOT required.
      * The output VHD must live on a local path (Mount-VHD does not support UNC).

.PARAMETER SourcePath
    Path to install.wim, install.esd or a Windows ISO. When an ISO is supplied it is
    mounted automatically and sources\install.wim (or install.esd) is located.

.PARAMETER VhdPath
    Output VHDX/VHD path. Optional: when it is omitted the file name is generated from the
    image metadata as <version>-<architecture>-<name>-<editionid>-<languages>-<disklayout>-<size>GB
    (e.g. 10.0.26172.1-x64-Windows-Server-2025-Standard-ServerStandard-en-US-UEFI-64GB.vhdx),
    spaces replaced by hyphens, and, if the file already exists, suffixed with -1, -2 ...

.PARAMETER OutDirectory
    Directory for the generated file name when -VhdPath is omitted. Defaults to the current
    directory. Ignored when -VhdPath is given.

.PARAMETER VhdFormat
    VHDX (default) or VHD. VHD is limited to 2040 GB and cannot be used with
    UEFI in some older hosts, prefer VHDX.

.PARAMETER VhdType
    Dynamic (default, file grows on demand) or Fixed (pre-allocated).

.PARAMETER DiskLayout
    UEFI (default): GPT with EFI (FAT32, 100 MB) + MSR (16 MB) + Windows (NTFS).
    BIOS: MBR with System (NTFS, 100 MB, active) + Windows (NTFS).

.PARAMETER Index
    Image index inside the WIM/ESD. Use -ListImages to see the available indexes.

.PARAMETER Edition
    Image name instead of an index, e.g. "Windows 11 Pro". Exact match first, then a
    unique case-insensitive substring match.

.PARAMETER SizeBytes
    Maximum size of the virtual disk. Default: image size * 1.5 + 4 GB, minimum 32 GB.

.PARAMETER ListImages
    List the images contained in the source WIM/ESD and exit. Prints one summary line per
    image (index, name, architecture, version, edition, install type, languages, size).

.PARAMETER ListImageDetailed
    With -ListImages, also print the full metadata block of every image (product name,
    system root, file/dir counts, created/modified, image state, ...).

.PARAMETER Force
    Overwrite the output VHD if it already exists.

.PARAMETER DriverPath
    One or more folders with .inf drivers injected into the applied image (recursive).

.PARAMETER ForceUnsignedDrivers
    Allows injection of unsigned drivers (-ForceUnsigned on Add-WindowsDriver).

.PARAMETER UnattendPath
    unattend.xml copied to <Windows>\Windows\Panther\unattend.xml.

.PARAMETER RecoveryPartition
    Adds a 750 MB WinRE partition at the end of the disk, copies Winre.wim into
    <Recovery>\Recovery\WindowsRE and registers it with reagentc (best effort).

.PARAMETER NativeBoot
    In addition to the boot files inside the VHD, runs bcdboot against the running OS
    so the VHDX can be booted natively (boot-to-VHD).

.PARAMETER BootDescription
    Description applied to the boot entry created by bcdboot (bcdboot /description),
    e.g. "Windows 11 Lab VHDX".

.PARAMETER CheckIntegrity
    Verifies the WIM is not corrupted before applying.

.PARAMETER Verify
    Verifies files written during apply (slower).

.PARAMETER LogPath
    Transcript log. Default: $env:TEMP\Convert-WimToVhdx_<timestamp>.log

.EXAMPLE
    .\Convert-WimToVhdx.ps1 -SourcePath D:\sources\install.wim -ListImages

.EXAMPLE
    .\Convert-WimToVhdx.ps1 -SourcePath C:\iso\Win11_24H2.iso -VhdPath D:\vhdx\win11.vhdx -Edition 'Windows 11 Pro'

.EXAMPLE
    # No -VhdPath: file name generated from the image metadata into the current directory
    .\Convert-WimToVhdx.ps1 -SourcePath C:\iso\server2025.iso -Edition 'Server Standard' -OutDirectory D:\vhdx

.EXAMPLE
    .\Convert-WimToVhdx.ps1 -SourcePath D:\sources\install.wim -Index 3 -VhdPath D:\vhdx\gen1.vhd -DiskLayout BIOS -VhdType Fixed -SizeBytes 64GB -Force

.EXAMPLE
    .\Convert-WimToVhdx.ps1 -SourcePath C:\iso\server2025.iso -VhdPath D:\vhdx\srv.vhdx -Edition 'Server Standard' -DriverPath C:\drivers -UnattendPath C:\unattend.xml -NativeBoot -BootDescription 'Server 2025 VHDX'

.NOTES
    Author : demystify / ps_wim
    License: MIT

    Every console line is prefixed with a UTC timestamp: [yyyy-MM-dd HH:mm:ss].
    The same lines are captured in the transcript log (-LogPath).
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath,

    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$VhdPath,

    [ValidateNotNullOrEmpty()]
    [string]$OutDirectory,

    [ValidateSet('VHDX', 'VHD')]
    [string]$VhdFormat = 'VHDX',

    [ValidateSet('Dynamic', 'Fixed')]
    [string]$VhdType = 'Dynamic',

    [ValidateSet('UEFI', 'BIOS')]
    [string]$DiskLayout = 'UEFI',

    [ValidateRange(1, 999)]
    [int]$Index,

    [ValidateNotNullOrEmpty()]
    [string]$Edition,

    [Alias('Size')]
    [ValidateRange(1GB, 64TB)]
    [uint64]$SizeBytes,

    [switch]$ListImages,

    [switch]$ListImageDetailed,

    [switch]$Force,

    [string[]]$DriverPath,

    [switch]$ForceUnsignedDrivers,

    [ValidateNotNullOrEmpty()]
    [string]$UnattendPath,

    [switch]$RecoveryPartition,

    [switch]$NativeBoot,

    [ValidateNotNullOrEmpty()]
    [string]$BootDescription,

    [switch]$CheckIntegrity,

    [switch]$Verify,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# PowerShell 7 colors table headers with ANSI escapes - keep redirected output and the
# transcript free of them ($PSStyle does not exist in Windows PowerShell 5.1).
if ($PSStyle) { $PSStyle.OutputRendering = 'PlainText' }

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$script:GptType = @{
    System    = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' # EFI system partition
    MicrosoftReserved = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    BasicData = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    Recovery  = '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
}
$script:EfiSize      = 100MB
$script:MsrSize      = 16MB
$script:SystemSize   = 100MB
$script:RecoverySize = 750MB
$script:MaxVhdSize   = 2040GB

# <WINDOWS><ARCH> codes used by the WIM manifest (PROCESSOR_ARCHITECTURE_*)
$script:WimArchitectures = @{
    0  = 'x86'
    5  = 'ARM'
    6  = 'IA64'
    9  = 'x64'
    12 = 'ARM64'
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-LogTimestamp {
    # UTC timestamp used as the prefix of every console line.
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[$(Get-LogTimestamp)] == $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[$(Get-LogTimestamp)]    $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[$(Get-LogTimestamp)]    WARNING: $Message" -ForegroundColor Yellow
}

function Write-LogError {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[$(Get-LogTimestamp)] !! ERROR: $Message" -ForegroundColor Red
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Native {
    # Runs a native tool, throws on a non-zero exit code.
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$AllowFailure
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($Arguments | ForEach-Object { '"{0}"' -f ($_ -replace '(\\*)"', '$1$1\"') }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    if ($stdout) { Write-Verbose $stdout }
    if ($stderr) { Write-Verbose $stderr }

    if ($proc.ExitCode -ne 0) {
        $message = "{0} exited with code {1}. {2}" -f (Split-Path $FilePath -Leaf), $proc.ExitCode, ($stderr.Trim())
        if (-not $AllowFailure) { throw $message }
        Write-Warn $message
    }
    # No output: callers only care about the throw above, so the exit code would
    # otherwise leak into the console as a stray integer.
}

function Invoke-DiskPart {
    param([Parameter(Mandatory)][string[]]$Commands)
    $scriptFile = Join-Path $env:TEMP ("diskpart_{0}.txt" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $scriptFile -Value $Commands -Encoding ASCII
        Invoke-Native -FilePath "$env:SystemRoot\System32\diskpart.exe" -Arguments @('/s', $scriptFile)
    }
    finally {
        Remove-Item -LiteralPath $scriptFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-FreeDriveLetter {
    $inUse = New-Object System.Collections.Generic.List[string]
    Get-Partition -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveLetter -and $_.DriveLetter -ne 0 } |
        ForEach-Object { $inUse.Add($_.DriveLetter.ToString().ToUpperInvariant()) }
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.Length -eq 1 } |
        ForEach-Object { $inUse.Add($_.Name.ToUpperInvariant()) }

    foreach ($c in 'EFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()) {
        $letter = [string]$c
        if (-not $inUse.Contains($letter)) { return $letter }
    }
    throw 'No free drive letter available. Free a drive letter and retry.'
}

function Wait-ForVolumePath {
    param(
        [Parameter(Mandatory)][string]$Letter,
        [int]$TimeoutSec = 60
    )
    $path = "$($Letter):\"
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $path) { return }
        Start-Sleep -Milliseconds 500
    }
    throw "Volume $path did not become available within $TimeoutSec seconds."
}

function Set-PartitionDriveLetter {
    param([Parameter(Mandatory)][Microsoft.Management.Infrastructure.CimInstance]$Partition)
    $letter = Get-FreeDriveLetter
    $null = Set-Partition -InputObject $Partition -NewDriveLetter ([char]$letter) -ErrorAction Stop
    Wait-ForVolumePath -Letter $letter
    return $letter
}

function Remove-AccessPathWithRetry {
    param(
        [Parameter(Mandatory)][int]$DiskNumber,
        [Parameter(Mandatory)][int]$PartitionNumber,
        [Parameter(Mandatory)][string]$Letter,
        [int]$Attempts = 10
    )
    $accessPath = "$($Letter):\"
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            Remove-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AccessPath $accessPath -ErrorAction Stop
            return
        }
        catch {
            if ($i -eq $Attempts) {
                Write-Warn "Could not remove access path '$accessPath': $($_.Exception.Message). Remove it manually with diskpart."
                return
            }
            Write-Verbose "Retry $i removing '$accessPath': $($_.Exception.Message)"
            Start-Sleep -Seconds 3
        }
    }
}

function Dismount-VhdWithRetry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Attempts = 10
    )
    for ($i = 1; $i -le $Attempts; $i++) {
        try {
            Dismount-VHD -Path $Path -ErrorAction Stop
            return
        }
        catch {
            if ($i -eq $Attempts) { throw "Could not dismount '$Path': $($_.Exception.Message)" }
            Write-Verbose "Retry $i dismounting '$Path': $($_.Exception.Message)"
            Start-Sleep -Seconds 3
        }
    }
}

function Resolve-SourceImage {
    # Returns [pscustomobject] @{ Path = <wim>; IsoPath = <iso or $null> }
    param([Parameter(Mandatory)][string]$Path)

    $full = (Resolve-Path -LiteralPath $Path).ProviderPath
    $extension = [System.IO.Path]::GetExtension($full).ToLowerInvariant()

    switch ($extension) {
        '.wim' { return [pscustomobject]@{ Path = $full; IsoPath = $null } }
        '.esd' { return [pscustomobject]@{ Path = $full; IsoPath = $null } }
        '.iso' {
            Write-Step "Mounting ISO '$full'"
            $null = Mount-DiskImage -ImagePath $full -PassThru -ErrorAction Stop
            $volume = $null
            for ($i = 0; $i -lt 30 -and -not $volume; $i++) {
                Start-Sleep -Seconds 1
                $volume = Get-Volume -DiskImage (Get-DiskImage -ImagePath $full -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue |
                    Where-Object { $_.DriveLetter } | Select-Object -First 1
            }
            if (-not $volume) { throw "ISO '$full' was mounted but no volume appeared." }
            $root = "$($volume.DriveLetter):\"
            foreach ($candidate in @('sources\install.wim', 'sources\install.esd')) {
                $wim = Join-Path $root $candidate
                if (Test-Path -LiteralPath $wim) {
                    Write-Info "Using '$wim'"
                    return [pscustomobject]@{ Path = $wim; IsoPath = $full }
                }
            }
            throw "No sources\install.wim or sources\install.esd found inside ISO '$full'."
        }
        default { throw "Unsupported source '$full'. Supply install.wim, install.esd or a Windows ISO." }
    }
}

function Get-WimFileMetadata {
    # Reads the XML manifest embedded in a .wim/.esd. Get-WindowsImage only exposes
    # name/index/size - arch, build, edition, languages, file counts and timestamps live
    # in this manifest. Returns $null when it cannot be read (compressed metadata,
    # split/spanned WIM, .esd with a different layout) and the caller falls back to DISM.
    param([Parameter(Mandatory)][string]$Path)

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $header = New-Object byte[] 0x94
            if ($stream.Read($header, 0, 0x94) -ne 0x94) { return $null }
            if ([System.Text.Encoding]::ASCII.GetString($header, 0, 5) -ne 'MSWIM') { return $null }

            # XML resource header at 0x48: size in WIM (56 bits) + flags (8 bits), offset, uncompressed size
            $packedSize = [System.BitConverter]::ToUInt64($header, 0x48)
            $flags = [int]($packedSize -shr 56)
            $sizeInWim = [uint64]($packedSize -band 0x00FFFFFFFFFFFFFF)
            $offset = [System.BitConverter]::ToUInt64($header, 0x50)

            if (($flags -band 0x04) -or $sizeInWim -eq 0 -or $offset -eq 0 -or $sizeInWim -gt 64MB) { return $null }
            if (($offset + $sizeInWim) -gt [uint64](Get-Item -LiteralPath $Path).Length) { return $null }

            $null = $stream.Seek([long]$offset, [System.IO.SeekOrigin]::Begin)
            $bytes = New-Object byte[] ([int]$sizeInWim)
            if ($stream.Read($bytes, 0, $bytes.Length) -ne $bytes.Length) { return $null }
        }
        finally { $stream.Close() }

        # The manifest is UTF-16 (BOM included); fall back to UTF-8 for odd files.
        foreach ($encoding in @([System.Text.Encoding]::Unicode, [System.Text.Encoding]::UTF8)) {
            $text = $encoding.GetString($bytes).TrimStart([char]0xFEFF, [char]0x200B)
            try { return [xml]$text } catch { }
        }
        return $null
    }
    catch {
        Write-Verbose "WIM manifest not readable: $($_.Exception.Message)"
        return $null
    }
}

function ConvertFrom-WimFileTime {
    # <CREATIONTIME><HIGHPART>0x01DC4D97</HIGHPART><LOWPART>0xC82CE7B9</LOWPART></CREATIONTIME>
    param($Node)
    if (-not $Node -or -not $Node.HIGHPART -or -not $Node.LOWPART) { return $null }
    try {
        $high = [System.Convert]::ToUInt64(([string]$Node.HIGHPART).TrimStart('0', 'x').TrimStart('x'), 16)
        $low = [System.Convert]::ToUInt64(([string]$Node.LOWPART).TrimStart('0', 'x').TrimStart('x'), 16)
        return [DateTime]::FromFileTime([long](($high -shl 32) -bor $low)).ToUniversalTime()
    }
    catch { return $null }
}

function New-AutoVhdName {
    # version-architecture-name-editionid-languages-disklayout-<size>GB, safe for any filesystem.
    param(
        [Parameter(Mandatory)]$ImageDetail,
        [Parameter(Mandatory)][string]$Extension,
        [Parameter(Mandatory)][ValidateSet('UEFI', 'BIOS')][string]$DiskLayout,
        [Parameter(Mandatory)][uint64]$SizeBytes
    )
    $parts = @($ImageDetail.Version, $ImageDetail.Architecture, $ImageDetail.Name,
        $ImageDetail.EditionId, $ImageDetail.Languages) | Where-Object { $_ }
    $name = $parts -join '-'

    $name = $name -replace '[\\/:*?"<>|,()\[\]{}]+', '-' # illegal filename characters and separators
    $name = $name -replace '\s+', '-'                   # spaces (and ' - ') become '-'
    $name = $name -replace '-{2,}', '-'                 # collapse runs caused by the above
    $name = $name.Trim('-', '.', ' ')

    if (-not $name) { $name = "image-$($ImageDetail.Index)" } # WIM without manifest data
    $sizeLabel = '{0}GB' -f [int][math]::Round($SizeBytes / 1GB)
    return "$name-$DiskLayout-$sizeLabel$Extension"
}

function Resolve-UniqueVhdPath {
    # Never overwrites: appends -1, -2 ... until the name is free.
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$FileName
    )
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $extension = [System.IO.Path]::GetExtension($FileName)
    $candidate = Join-Path $Directory $FileName
    $suffix = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Directory "$base-$suffix$extension"
        $suffix++
    }
    return $candidate
}

function Get-WimImageDetail {
    # Merges the DISM image object with the richer data from the WIM manifest.
    param(
        [Parameter(Mandatory)]$Image,
        $WimXml
    )
    $node = $null
    if ($WimXml) {
        $node = @($WimXml.WIM.IMAGE) | Where-Object { [int]$_.INDEX -eq [int]$Image.ImageIndex } | Select-Object -First 1
    }

    $architecture = $null
    $version = $null
    $build = $null
    $branch = $null
    $editionId = $null
    $installationType = $null
    $productType = $null
    $productSuite = $null
    $productName = $null
    $systemRoot = $null
    $hal = $null
    $languages = $null
    $defaultLanguage = $null
    $dirCount = $null
    $fileCount = $null
    $created = $null
    $modified = $null
    $wimBoot = $null
    $imageState = $null

    if ($node) {
        if ($node.WINDOWS.ARCH) {
            $parsed = 0
            if ([int]::TryParse([string]$node.WINDOWS.ARCH, [ref]$parsed)) {
                $architecture = if ($script:WimArchitectures.ContainsKey($parsed)) { $script:WimArchitectures[$parsed] } else { "Unknown ($parsed)" }
            }
            else { $architecture = [string]$node.WINDOWS.ARCH } # some tools write the name directly
        }

        $v = $node.WINDOWS.VERSION
        if ($v) {
            $version = '{0}.{1}.{2}.{3}' -f $v.MAJOR, $v.MINOR, $v.BUILD, $v.SPBUILD
            $build = [string]$v.BUILD
            $branch = [string]$v.BRANCH
        }
        $editionId = [string]$node.WINDOWS.EDITIONID
        $installationType = [string]$node.WINDOWS.INSTALLATIONTYPE
        $productType = [string]$node.WINDOWS.PRODUCTTYPE
        $productSuite = [string]$node.WINDOWS.PRODUCTSUITE
        $productName = [string]$node.WINDOWS.PRODUCTNAME
        $systemRoot = [string]$node.WINDOWS.SYSTEMROOT
        $hal = [string]$node.WINDOWS.HAL
        if ($node.WINDOWS.LANGUAGES) {
            $languages = (@($node.WINDOWS.LANGUAGES.LANGUAGE) | Where-Object { $_ }) -join ', '
            $defaultLanguage = [string]$node.WINDOWS.LANGUAGES.DEFAULT
        }
        if ($node.DIRCOUNT) { $dirCount = [int64]$node.DIRCOUNT }
        if ($node.FILECOUNT) { $fileCount = [int64]$node.FILECOUNT }
        $created = ConvertFrom-WimFileTime $node.CREATIONTIME
        $modified = ConvertFrom-WimFileTime $node.LASTMODIFICATIONTIME
        if ($node.WIMBOOT) { $wimBoot = ([string]$node.WIMBOOT) -eq '1' }
        if ($node.WINDOWS.SERVICINGDATA) { $imageState = [string]$node.WINDOWS.SERVICINGDATA.IMAGESTATE }
    }

    [pscustomobject]@{
        Index            = [int]$Image.ImageIndex
        Name             = [string]$Image.ImageName
        Description      = [string]$Image.ImageDescription
        DisplayName      = [string]$node.DISPLAYNAME
        DisplayDescription = [string]$node.DISPLAYDESCRIPTION
        Flags            = [string]$node.FLAGS
        Architecture     = $architecture
        Version          = $version
        Build            = $build
        Branch           = $branch
        EditionId        = $editionId
        InstallationType = $installationType
        ProductType      = $productType
        ProductSuite     = $productSuite
        ProductName      = $productName
        Hal              = $hal
        SystemRoot       = $systemRoot
        Languages        = $languages
        DefaultLanguage  = $defaultLanguage
        SizeGB           = [math]::Round($Image.ImageSize / 1GB, 2)
        SizeBytes        = [uint64]$Image.ImageSize
        DirectoryCount   = $dirCount
        FileCount        = $fileCount
        HardlinkBytesGB  = if ($node.HARDLINKBYTES) { [math]::Round([double]$node.HARDLINKBYTES / 1GB, 2) } else { $null }
        CreatedUtc       = $created
        ModifiedUtc      = $modified
        WimBootable      = $wimBoot
        ImageState       = $imageState
    }
}

function Get-TargetImage {
    param(
        [Parameter(Mandatory)][string]$ImagePath,
        [int]$ImageIndex,
        [string]$ImageEdition
    )
    $images = @(Get-WindowsImage -ImagePath $ImagePath -ErrorAction Stop)
    if ($images.Count -eq 0) { throw "No images found in '$ImagePath'." }

    if ($ImageEdition) {
        $matches = @($images | Where-Object { $_.ImageName -eq $ImageEdition })
        if ($matches.Count -eq 0) {
            $matches = @($images | Where-Object { $_.ImageName -like "*$ImageEdition*" })
        }
        if ($matches.Count -eq 0) {
            throw "Edition '$ImageEdition' not found. Available: $(($images.ImageName) -join ', ')"
        }
        if ($matches.Count -gt 1) {
            throw "Edition '$ImageEdition' is ambiguous: $(($matches.ImageName) -join ', '). Use -Index instead."
        }
        return $matches[0]
    }

    if ($ImageIndex -gt 0) {
        $match = $images | Where-Object { $_.ImageIndex -eq $ImageIndex }
        if (-not $match) {
            throw "Index $ImageIndex not found in '$ImagePath'. Available indexes: $(($images.ImageIndex) -join ', ')"
        }
        return $match
    }

    if ($images.Count -eq 1) { return $images[0] }
    throw "The source contains $($images.Count) images. Specify -Index or -Edition (use -ListImages to see them)."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$transcriptStarted = $false
$isoMounted = $false
$vhdMounted = $false
$assignedAccessPaths = @()

try {
    if (-not $LogPath) {
        $LogPath = Join-Path $env:TEMP ("Convert-WimToVhdx_{0}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
    }
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }
    try {
        Start-Transcript -Path $LogPath -Append -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
    }
    catch {
        Write-Warn "Could not start the transcript: $($_.Exception.Message)"
    }
    Write-Info "Log: $LogPath"

    if ($IsLinux -or $IsMacOS) { throw 'This script only runs on Windows.' }
    if (-not (Test-IsAdministrator)) { throw 'This script must be run elevated (Run as Administrator).' }

    Write-Step 'Loading modules'
    Import-Module Dism -ErrorAction Stop
    Import-Module Hyper-V -ErrorAction Stop
    Write-Info 'Dism + Hyper-V modules loaded'

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        throw "SourcePath '$SourcePath' does not exist or is not a file."
    }

    $source = Resolve-SourceImage -Path $SourcePath
    if ($source.IsoPath) { $isoMounted = $true }
    $wimPath = $source.Path

    # --- list only -------------------------------------------------------
    $images = @(Get-WindowsImage -ImagePath $wimPath -ErrorAction Stop)
    if ($images.Count -eq 0) { throw "No images found in '$wimPath'." }
    $wimXml = Get-WimFileMetadata -Path $wimPath
    if (-not $wimXml) { Write-Verbose 'WIM manifest unavailable - only DISM metadata will be shown.' }

    if ($ListImages) {
        Write-Step "Images in '$wimPath'"
        $details = @($images | ForEach-Object { Get-WimImageDetail -Image $_ -WimXml $wimXml })
        # Out-String -Width keeps the table from being truncated at the host width.
        $details |
            Select-Object Index, Name, Architecture, Version, EditionId, InstallationType, Languages, SizeGB |
            Format-Table -AutoSize | Out-String -Width 250
        if ($ListImageDetailed) {
            $details | Format-List | Out-String -Width 250
        }
        return
    }

    if ($ListImageDetailed) { throw '-ListImageDetailed is only used with -ListImages.' }
    if ($Index -and $Edition) { throw 'Specify either -Index or -Edition, not both.' }

    # --- source image ----------------------------------------------------
    Write-Step "Reading image information from '$wimPath'"
    $image = Get-TargetImage -ImagePath $wimPath -ImageIndex $Index -ImageEdition $Edition
    $imageDetail = Get-WimImageDetail -Image $image -WimXml $wimXml
    Write-Info ("Selected: index {0} - '{1}' ({2}, {3}, {4:N2} GB)" -f $image.ImageIndex, $image.ImageName,
        $(if ($imageDetail.Architecture) { $imageDetail.Architecture } else { 'unknown arch' }),
        $(if ($imageDetail.Version) { $imageDetail.Version } else { 'unknown version' }),
        ($image.ImageSize / 1GB))

    if (-not $SizeBytes) {
        $SizeBytes = [uint64]([math]::Ceiling((($image.ImageSize * 1.5) + 4GB) / 1GB) * 1GB)
        if ($SizeBytes -lt 32GB) { $SizeBytes = [uint64]32GB }
        Write-Info ("Auto sized disk: {0:N2} GB" -f ($SizeBytes / 1GB))
    }
    if ($VhdFormat -eq 'VHD' -and $SizeBytes -gt $script:MaxVhdSize) {
        throw "VHD is limited to 2040 GB. Use -VhdFormat VHDX or a smaller -SizeBytes."
    }

    # --- output path -----------------------------------------------------
    if (-not $OutDirectory) {
        if ((Get-Location).Provider.Name -ne 'FileSystem') {
            throw 'Cannot derive an output directory from a non-FileSystem location. Specify -OutDirectory (or -VhdPath).'
        }
        $OutDirectory = (Get-Location).ProviderPath
    }

    if ($VhdPath) {
        $vhdFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($VhdPath)
        $vhdExtension = [System.IO.Path]::GetExtension($vhdFull).ToLowerInvariant()

        if (-not $PSBoundParameters.ContainsKey('VhdFormat')) {
            if ($vhdExtension -eq '.vhd') { $VhdFormat = 'VHD' }
            elseif ($vhdExtension -eq '.vhdx') { $VhdFormat = 'VHDX' }
            else { throw "VhdPath must end with .vhdx or .vhd (or set -VhdFormat explicitly): '$VhdPath'." }
        }
        elseif (".{0}" -f $VhdFormat.ToLowerInvariant() -ne $vhdExtension) {
            throw "Extension '$vhdExtension' does not match -VhdFormat '$VhdFormat'."
        }

        if (Test-Path -LiteralPath $vhdFull) {
            if (-not $Force) { throw "'$vhdFull' already exists. Use -Force to overwrite." }
            if ($PSCmdlet.ShouldProcess($vhdFull, 'Delete existing virtual disk')) {
                Remove-Item -LiteralPath $vhdFull -Force -ErrorAction Stop
            }
        }
    }
    else {
        # Auto name: version-architecture-name-editionid-languages-disklayout-sizeGB
        $vhdExtension = if ($VhdFormat -eq 'VHD') { '.vhd' } else { '.vhdx' }
        $vhdFull = Resolve-UniqueVhdPath -Directory $OutDirectory -FileName (New-AutoVhdName -ImageDetail $imageDetail -Extension $vhdExtension -DiskLayout $DiskLayout -SizeBytes $SizeBytes)
        Write-Info ("VhdPath not specified - generated '{0}' in '{1}'" -f (Split-Path $vhdFull -Leaf), (Split-Path $vhdFull -Parent))
    }

    if ($vhdFull -match '^\\\\') { throw "The output path must be local; UNC paths are not supported by Mount-VHD: '$vhdFull'." }

    $vhdDir = Split-Path -Path $vhdFull -Parent
    if ($vhdDir -and -not (Test-Path -LiteralPath $vhdDir)) { New-Item -ItemType Directory -Path $vhdDir -Force | Out-Null }

    $rootDrive = ([System.IO.Path]::GetPathRoot($vhdFull)).TrimEnd('\')
    $psDrive = Get-PSDrive -Name $rootDrive.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($psDrive -and $psDrive.Free -ne $null) {
        if ($VhdType -eq 'Fixed' -and $psDrive.Free -lt $SizeBytes) {
            throw "Not enough free space on $rootDrive for a fixed disk of $('{0:N2}' -f ($SizeBytes / 1GB)) GB (free: $('{0:N2}' -f ($psDrive.Free / 1GB)) GB)."
        }
        if ($VhdType -eq 'Dynamic' -and $psDrive.Free -lt ($SizeBytes * 0.25)) {
            Write-Warn "Only $('{0:N2}' -f ($psDrive.Free / 1GB)) GB free on $rootDrive for a dynamic disk of $('{0:N2}' -f ($SizeBytes / 1GB)) GB."
        }
    }

    $action = "Create $DiskLayout $VhdType $VhdFormat '$vhdFull' ($('{0:N2}' -f ($SizeBytes / 1GB)) GB) from index $($image.ImageIndex) '$($image.ImageName)'"
    if (-not $PSCmdlet.ShouldProcess($vhdFull, $action)) { return }

    # --- create + partition ---------------------------------------------
    Write-Step "Creating $VhdType $VhdFormat '$vhdFull'"
    $newVhd = @{ Path = $vhdFull; SizeBytes = $SizeBytes; ErrorAction = 'Stop' }
    if ($VhdType -eq 'Fixed') { $newVhd['Fixed'] = $true } else { $newVhd['Dynamic'] = $true }
    New-VHD @newVhd | Out-Null

    Write-Step 'Attaching and partitioning the disk'
    $vhdObject = Mount-VHD -Path $vhdFull -PassThru -ErrorAction Stop
    $vhdMounted = $true
    Start-Sleep -Seconds 2
    $disk = Get-Disk -Number $vhdObject.DiskNumber -ErrorAction Stop
    $diskNumber = $disk.Number
    Write-Info "Disk $diskNumber ($('{0:N2}' -f ($disk.Size / 1GB)) GB)"

    $partitionStyle = if ($DiskLayout -eq 'UEFI') { 'GPT' } else { 'MBR' }
    Initialize-Disk -Number $diskNumber -PartitionStyle $partitionStyle -Confirm:$false -ErrorAction Stop

    if ($DiskLayout -eq 'UEFI') {
        $systemPartition = New-Partition -DiskNumber $diskNumber -Size $script:EfiSize -GptType $script:GptType.System -ErrorAction Stop

        # Initialize-Disk already creates an MSR on current Windows builds - do not add a second one.
        $msr = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue |
            Where-Object { $_.GptType -eq $script:GptType.MicrosoftReserved }
        if (-not $msr) {
            $null = New-Partition -DiskNumber $diskNumber -Size $script:MsrSize -GptType $script:GptType.MicrosoftReserved -ErrorAction Stop
        }

        # Size from the real free extent - MBR/GPT alignment makes disk - sum(partitions) unreliable.
        $free = (Get-Disk -Number $diskNumber -ErrorAction Stop).LargestFreeExtent
        if ($RecoveryPartition) {
            $windowsPartition = New-Partition -DiskNumber $diskNumber -Size ($free - $script:RecoverySize - 1MB) -GptType $script:GptType.BasicData -ErrorAction Stop
            $winrePartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -GptType $script:GptType.Recovery -ErrorAction Stop
        }
        else {
            $windowsPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -GptType $script:GptType.BasicData -ErrorAction Stop
            $winrePartition = $null
        }
    }
    else {
        $systemPartition = New-Partition -DiskNumber $diskNumber -Size $script:SystemSize -MbrType 0x07 -IsActive -ErrorAction Stop

        $free = (Get-Disk -Number $diskNumber -ErrorAction Stop).LargestFreeExtent
        if ($RecoveryPartition) {
            $windowsPartition = New-Partition -DiskNumber $diskNumber -Size ($free - $script:RecoverySize - 1MB) -MbrType 0x07 -ErrorAction Stop
            # 0x27 = hidden NTFS, the type Windows uses for a WinRE partition on MBR disks
            $winrePartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -MbrType 0x27 -ErrorAction Stop
        }
        else {
            $windowsPartition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -MbrType 0x07 -ErrorAction Stop
            $winrePartition = $null
        }
    }

    Write-Step 'Formatting volumes'
    $null = Format-Volume -Partition $systemPartition -FileSystem $(if ($DiskLayout -eq 'UEFI') { 'FAT32' } else { 'NTFS' }) `
        -NewFileSystemLabel 'System' -Force -Confirm:$false -ErrorAction Stop
    $null = Format-Volume -Partition $windowsPartition -FileSystem NTFS -NewFileSystemLabel 'Windows' -Force -Confirm:$false -ErrorAction Stop
    if ($winrePartition) {
        $null = Format-Volume -Partition $winrePartition -FileSystem NTFS -NewFileSystemLabel 'Windows RE' -Force -Confirm:$false -ErrorAction Stop
    }

    $systemLetter = Set-PartitionDriveLetter -Partition (Get-Partition -DiskNumber $diskNumber -PartitionNumber $systemPartition.PartitionNumber -ErrorAction Stop)
    $assignedAccessPaths += [pscustomobject]@{ DiskNumber = $diskNumber; PartitionNumber = $systemPartition.PartitionNumber; Letter = $systemLetter }
    $windowsLetter = Set-PartitionDriveLetter -Partition (Get-Partition -DiskNumber $diskNumber -PartitionNumber $windowsPartition.PartitionNumber -ErrorAction Stop)
    $assignedAccessPaths += [pscustomobject]@{ DiskNumber = $diskNumber; PartitionNumber = $windowsPartition.PartitionNumber; Letter = $windowsLetter }
    $recoveryLetter = $null
    if ($winrePartition) {
        $recoveryLetter = Set-PartitionDriveLetter -Partition (Get-Partition -DiskNumber $diskNumber -PartitionNumber $winrePartition.PartitionNumber -ErrorAction Stop)
        $assignedAccessPaths += [pscustomobject]@{ DiskNumber = $diskNumber; PartitionNumber = $winrePartition.PartitionNumber; Letter = $recoveryLetter }
    }
    Write-Info ("System: {0}:  Windows: {1}:{2}" -f $systemLetter, $windowsLetter, $(if ($recoveryLetter) { "  Recovery: $($recoveryLetter):" } else { '' }))

    # --- apply image -----------------------------------------------------
    Write-Step "Applying image $($image.ImageIndex) '$($image.ImageName)' to $($windowsLetter):\"
    $expandParams = @{
        ImagePath   = $wimPath
        Index       = $image.ImageIndex
        ApplyPath   = "$($windowsLetter):\"
        ErrorAction = 'Stop'
    }
    if ($CheckIntegrity) { $expandParams['CheckIntegrity'] = $true }
    if ($Verify) { $expandParams['Verify'] = $true }
    Expand-WindowsImage @expandParams | Out-Null

    # --- drivers ---------------------------------------------------------
    if ($DriverPath) {
        foreach ($driver in $DriverPath) {
            $driverFull = (Resolve-Path -LiteralPath $driver).ProviderPath
            if (-not (Test-Path -LiteralPath $driverFull -PathType Container)) { throw "DriverPath '$driver' is not a folder." }
            if ($PSCmdlet.ShouldProcess("$($windowsLetter):\", "Add drivers from '$driverFull'")) {
                Write-Step "Injecting drivers from '$driverFull'"
                $driverParams = @{ Path = "$($windowsLetter):\"; Driver = $driverFull; Recurse = $true; ErrorAction = 'Stop' }
                if ($ForceUnsignedDrivers) { $driverParams['ForceUnsigned'] = $true }
                Add-WindowsDriver @driverParams | Out-Null
            }
        }
    }

    # --- unattend --------------------------------------------------------
    if ($UnattendPath) {
        $unattendFull = (Resolve-Path -LiteralPath $UnattendPath).ProviderPath
        if ($PSCmdlet.ShouldProcess("$($windowsLetter):\Windows\Panther\unattend.xml", "Copy unattend from '$unattendFull'")) {
            Write-Step 'Copying unattend.xml'
            $panther = "$($windowsLetter):\Windows\Panther"
            New-Item -ItemType Directory -Path $panther -Force | Out-Null
            Copy-Item -LiteralPath $unattendFull -Destination (Join-Path $panther 'unattend.xml') -Force -ErrorAction Stop
        }
    }

    # --- boot files ------------------------------------------------------
    if ($PSCmdlet.ShouldProcess("$($systemLetter):", "Write $DiskLayout boot files with bcdboot")) {
        Write-Step "Writing $DiskLayout boot files with bcdboot"
        $bcdbootArgs = @("$($windowsLetter):\Windows", '/s', "$($systemLetter):", '/f', $DiskLayout, '/v')
        if ($BootDescription) { $bcdbootArgs += @('/description', $BootDescription) }
        Invoke-Native -FilePath "$env:SystemRoot\System32\bcdboot.exe" -Arguments $bcdbootArgs
    }

    if ($NativeBoot) {
        if ($PSCmdlet.ShouldProcess('host boot configuration', "Add native boot entry for $($windowsLetter):\Windows")) {
            Write-Step 'Adding native boot entry on the running OS'
            $nativeArgs = @("$($windowsLetter):\Windows", '/f', $DiskLayout, '/v')
            if ($BootDescription) { $nativeArgs += @('/description', $BootDescription) }
            Invoke-Native -FilePath "$env:SystemRoot\System32\bcdboot.exe" -Arguments $nativeArgs
        }
    }

    # --- recovery --------------------------------------------------------
    if ($winrePartition -and $recoveryLetter) {
        $winreSource = "$($windowsLetter):\Windows\System32\Recovery\Winre.wim"
        if (-not (Test-Path -LiteralPath $winreSource)) {
            Write-Warn "Winre.wim not found in the applied image ($winreSource); recovery partition left empty."
        }
        elseif ($PSCmdlet.ShouldProcess("$($recoveryLetter):", 'Configure Windows Recovery Environment')) {
            Write-Step 'Configuring Windows Recovery Environment'
            $recoveryDir = "$($recoveryLetter):\Recovery\WindowsRE"
            New-Item -ItemType Directory -Path $recoveryDir -Force | Out-Null
            Copy-Item -LiteralPath $winreSource -Destination (Join-Path $recoveryDir 'Winre.wim') -Force -ErrorAction Stop

            if ($DiskLayout -eq 'UEFI') {
                try {
                    Invoke-DiskPart -Commands @("select disk $diskNumber", "select partition $($winrePartition.PartitionNumber)", 'gpt attributes=0x8000000000000001')
                }
                catch { Write-Warn "Could not set the GPT attributes of the recovery partition: $($_.Exception.Message)" }
            }
            try {
                Invoke-Native -FilePath "$env:SystemRoot\System32\reagentc.exe" -Arguments @('/setreimage', '/path', $recoveryDir, '/target', "$($windowsLetter):\Windows") -AllowFailure
            }
            catch { Write-Warn "reagentc /setreimage failed: $($_.Exception.Message)" }
        }
    }

    Write-Step "Done: '$vhdFull'"
    [pscustomobject]@{
        VhdPath      = $vhdFull
        VhdFormat    = $VhdFormat
        VhdType      = $VhdType
        DiskLayout   = $DiskLayout
        SizeBytes    = $SizeBytes
        SizeGB       = [math]::Round($SizeBytes / 1GB, 2)
        SourcePath   = $wimPath
        ImageIndex   = $image.ImageIndex
        ImageName    = $image.ImageName
        ImageSizeGB  = [math]::Round($image.ImageSize / 1GB, 2)
        Architecture = $imageDetail.Architecture
        Build        = $imageDetail.Build
        EditionId    = $imageDetail.EditionId
        NativeBoot   = [bool]$NativeBoot
        Recovery     = [bool]$winrePartition
        LogPath      = $LogPath
    }
}
catch {
    Write-LogError $($_.Exception.Message)
    throw
}
finally {
    Write-Step 'Cleaning up'
    foreach ($accessPath in $assignedAccessPaths) {
        Write-Verbose "Removing access path $($accessPath.Letter):\"
        Remove-AccessPathWithRetry -DiskNumber $accessPath.DiskNumber -PartitionNumber $accessPath.PartitionNumber -Letter $accessPath.Letter
    }
    if ($vhdMounted) {
        try { Dismount-VhdWithRetry -Path $vhdFull } catch { Write-Warn $_.Exception.Message }
    }
    if ($isoMounted) {
        try { Dismount-DiskImage -ImagePath $source.IsoPath -ErrorAction Stop } catch { Write-Warn "Could not dismount ISO: $($_.Exception.Message)" }
    }
    if ($transcriptStarted) { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null }
}

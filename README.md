# Demystify Things and Share Ideas I Work with Every Day

This repository is a personal toolbox of scripts, notebooks, prompts, and notes for Azure infrastructure automation, network diagnostics, Azure AI experiments, media processing, and Windows/Linux system administration.

Most content is organized by scenario. Start with the folder that matches the task you are working on, then read the folder-level README or script header before running commands.

## Table of Contents

- [Getting Started](#getting-started)
- [Common Prerequisites](#common-prerequisites)
- [Recent Development](#recent-development)
- [Azure Platform Tools](#azure-platform-tools)
- [Azure AI Integration](#azure-ai-integration)
- [Network & Connectivity](#network--connectivity)
- [Media Processing](#media-processing)
- [System Utilities](#system-utilities)
- [Tips & Tricks](#tips--tricks)

---

## Getting Started

1. Clone the repository and open a PowerShell terminal at the repo root.
2. Review the relevant folder README before running a script; many scripts assume local tools, cloud credentials, or environment-specific paths.
3. Run PowerShell scripts from their own folder unless the script documents a different working directory.
4. For Azure scripts, sign in first with `az login` or `Connect-AzAccount`, depending on whether the script uses Azure CLI or Az PowerShell.

## Common Prerequisites

| Area | Typical tools |
|------|---------------|
| Azure automation | Azure CLI, Az PowerShell, Terraform |
| Network diagnostics | PowerShell, curl, psping, tshark/tcpdump, Python |
| Video cutting / transcoding | FFmpeg and FFprobe on PATH; Windows PowerShell 5.1 or PowerShell 7+ on Windows; compatible GPU/drivers for hardware encoders |
| Speech-to-text subtitles | Python and faster-whisper; see the media folder's setup guide |
| Windows image conversion | Elevated PowerShell, DISM, Hyper-V PowerShell management module, local output disk |
| Kusto / ADX analysis | Kusto Explorer, Azure Data Explorer access |

> **Note:** Some scripts can change Azure resources, routing, files, installed packages, or system configuration. Review parameters and test in a non-production environment first.

## Recent Development

| Area | Updates |
|------|---------|
| Video cutting | Embedded text subtitle clipping and time shifting, including middle removal with `-revert`; manual or preference-based audio track selection |
| Batch transcoding | Renamed `Transcode-Video.ps1` to `Batch-Transcode-Videos.ps1` to make its folder-based workflow explicit; existing parameters are unchanged |
| PowerShell compatibility | Both video scripts support Windows PowerShell 5.1 and PowerShell 7+ on Windows and share one `help_class.ps1` for UTF-8 stream probing, stream selection, and process launching |
| Windows image conversion | `ps_wim\convert-wimtovhdx.ps1` creates bootable UEFI/BIOS VHD/VHDX files from WIM, ESD, or ISO sources, with image metadata listing and optional driver/unattend injection |
| Package installation | Winget installer v2.2 runs without whole-script elevation, uses a short-lived elevated process for machine-wide configuration, and installs PowerShell modules in CurrentUser scope; the catalog includes Microsoft Store apps, Node.js, and Windows App |

---

## Azure Platform Tools

### Infrastructure & Automation

| Folder | Description |
|--------|-------------|
| [azurespeedstorage](./azurespeedstorage/) | Terraform sample for creating storage accounts across Azure regions |
| [ps_azure](./ps_azure/) | PowerShell library for Azure automation |
| [linux_bash](./linux_bash/) | Post-boot scripts for Azure Linux VMs, NVA configuration |

**Key Scripts in ps_azure:**
- `azurelb_monitor.ps1` - Monitors Azure Load Balancer health, auto-removes/adds unhealthy backends
- `check_available_vm_sizes_and_quota.ps1` - Check VM size availability and quota across regions

### Azure Data Explorer (ADX) / Kusto

| Folder | Description |
|--------|-------------|
| [analyzestoragelog](./analyzestoragelog/) | Analyze Azure Storage Analytics logs with ADX |
| [network/pcap2kusto](./network/pcap2kusto/) | Import PCAP files into Kusto for analysis |
| [network/flowlog](./network/flowlog/) | Process Azure VNET Flow Logs (PT1H.json) into Kusto. See [Guide](./network/flowlog/Flowlog%20to%20Kusto.md) |

**Query CSV directly in Kusto** (no import needed). More at [Blocklist & Kusto table](https://firewalliplists.gypthecat.com/kusto-tables/):
```kql
let CIDRRanges = (
    externaldata (
        CIDRCountry:string, CIDR:string, CIDRCountryName:string,
        CIDRContinent:string, CIDRContinentName:string, CIDRSource:string
    ) ['https://firewalliplists.gypthecat.com/lists/kusto/kusto-cidr-countries.csv.zip']
    with (ignoreFirstRecord=true)
);
CIDRRanges | take 200
```

---

## Azure AI Integration

| Folder | Description |
|--------|-------------|
| [azureai](./azureai/) | Azure OpenAI (GPT) integration scripts and prompt library |

**Key Files:**
- `invoke-azureai-gpt.ps1` - PowerShell script for Azure OpenAI API calls
- `invoke-dbrx.ps1` - Databricks model integration
- `prompt.json` - 25+ predefined prompts for various use cases
- `prompt_library/` - Individual prompt files for business, DevOps, and support scenarios
- [model_readme.md](./azureai/model_readme.md) - Azure AI model availability by region

---

## Network & Connectivity

### Connectivity Testing

| Folder | Description |
|--------|-------------|
| [connectivityscript](./connectivityscript/) | Cross-platform network testing (DNS, TCP, UDP, ICMP, HTTPS, SQL). See [README](./connectivityscript/README.md) |

**Platforms supported:** Windows (PowerShell), Linux (Bash), Python (AI-enhanced)

**Features:**
- PingMesh for distributed network testing
- Real-time logging with UTC timestamps
- Multi-protocol support (DNS, HTTP/HTTPS, ICMP, TCP, UDP, SQL)

### Network Analysis Tools

| File/Folder | Description |
|-------------|-------------|
| [network/tshark_samples.md](./network/tshark_samples.md) | tshark and tcpdump command samples |
| [network/get-MicrosoftIpAddressRange.ps1](./network/get-MicrosoftIpAddressRange.ps1) | Fetch Microsoft Azure/Office 365 IP ranges |
| [network/convert-nsgflowlog2csv.ps1](./network/convert-nsgflowlog2csv.ps1) | Convert NSG Flow Logs to CSV |
| [network/pcap2kusto/mergecapfiles.ps1](./network/pcap2kusto/mergecapfiles.ps1) | Merge multiple PCAP files into one |

---

## Media Processing

| Folder | Description |
|--------|-------------|
| [ps_mediaencoder](./ps_mediaencoder/) | FFmpeg-based video/audio processing. See [README](./ps_mediaencoder/README.md) |

**Key Tools:**

| Script | Description |
|--------|-------------|
| [`Video_Header_Trail_remove.ps1`](./ps_mediaencoder/Video_Header_Trail_remove.ps1) | Single-file GPU re-encoding, header/trailer or middle removal, audio selection, and synchronized embedded text subtitles |
| [`Batch-Transcode-Videos.ps1`](./ps_mediaencoder/Batch-Transcode-Videos.ps1) | Folder-based MKV/MP4 transcoding with audio/subtitle selection, configurable resolution and encoding, stereo output, existing-output skipping, and a batch summary |
| [`help_class.ps1`](./ps_mediaencoder/help_class.ps1) | Shared UTF-8 FFprobe reader, audio/subtitle selection, and FFmpeg process launcher; keep alongside both video scripts |
| [`Video_Header_Trail_remove.Tests.ps1`](./ps_mediaencoder/Video_Header_Trail_remove.Tests.ps1) | Pester regression coverage for subtitle timing, audio selection, and process error handling; not needed for normal encoding |
| `whisper_subtitle_generator.py` | Speech-to-text subtitle generation using faster-whisper. See [Guide](./ps_mediaencoder/whisper_readme.md) |
| `whisper_setup.ps1` | Automated setup for Whisper environment |
| `ffmpeg.powershell.ps1` | Batch encoding with customizable profiles |
| `ffmpeg_profile.json` | Encoding profiles configuration |

### Video Cutting and Subtitle Retention

`Video_Header_Trail_remove.ps1` accepts cut times as seconds, `MM:ss`, or `HH:mm:ss`. Normally it removes the header and trailer. With `-revert`, it keeps those segments and removes the middle instead.

Embedded text subtitles are clipped to retained segments, shifted to the new timeline, and merged as selectable MP4 subtitles with the default-display flag. Player preferences can override automatic display. Use `-SubtitleLanguage chi` (the default), an absolute `-SubtitleStreamIndex`, or `-SkipSubtitles`. External subtitle files and bitmap subtitles requiring OCR are not supported by the cutter; advanced subtitle styling is not retained.

Audio can be selected with an absolute `-AudioStreamIndex`, or automatically using `-AudioCodec`, `-AudioChannels`, and `-AudioLanguage`. Explicit `-AudioStreamIndex -1` enables automatic selection with default preferences; omitting all audio-selection options retains the first audio track. Preferences rank available tracks rather than strictly filtering them, and a manual index takes precedence. In the cutter, codec/channel preferences select the **source track**: they do not request a different output codec or stereo downmix.

```powershell
# From the repository root; create your output and log directories first.
.\ps_mediaencoder\Video_Header_Trail_remove.ps1 `
    -filename "D:\Input\episode.mkv" `
    -outputfolder "D:\Output" -logfolder "D:\Logs" `
    -gpu hevc_qsv -bitrate 2300 -startsecs "01:37" -lastsecs "02:24" `
    -AudioCodec aac -AudioChannels 2 -AudioLanguage chi -SubtitleLanguage chi

# Batch processing: use the new script name in existing commands.
.\ps_mediaencoder\Batch-Transcode-Videos.ps1 `
    -SourceDir "D:\Input" -TargetDir "D:\Output" `
    -HeaderCutSeconds 97 -TrailCutSeconds 144 -SubtitleLanguage chi
```

Both commands run in **Windows PowerShell 5.1** (`powershell.exe`) and **PowerShell 7+** (`pwsh.exe`) on Windows. Keep `help_class.ps1` with the scripts, and preserve UTF-8 with BOM for scripts containing Chinese text. The default encoder is Intel HEVC QSV; select a supported encoder for your hardware.

**Operational differences:** the cutter overwrites existing output, requires existing output/log folders, and defaults to network-specific paths unless overridden. The batch script skips existing output and currently uses `G:\DOWNLOADS\ffmpeg_log\cut` for logs. Review these paths before running. Cutter encoding, extraction, and merge logs are separate; FFmpeg failures include exit codes and log details, and empty video output is rejected.

Other media tools provide profile-based batch encoding, multilingual speech-to-text subtitle generation, audio extraction/conversion, and screen-capture examples. See the [media guide](./ps_mediaencoder/README.md) for parameter details and the [Whisper guide](./ps_mediaencoder/whisper_readme.md) for subtitle generation.

---

## System Utilities

| Folder | Description |
|--------|-------------|
| [ps_random](./ps_random/) | Miscellaneous PowerShell utilities |
| [ps_storeapp](./ps_storeapp/) | Windows Store app management |
| [ps_wim](./ps_wim/) | Windows image inspection and bootable VHD/VHDX creation. See [Guide](./ps_wim/README.md) |
| [py_portrait](./py_portrait/) | Python portrait extraction from images |

**Key Scripts in ps_random:**

| Script | Description |
|--------|-------------|
| `winget_myinstall_v2.ps1` | Interactive checkbox installer for winget packages, Microsoft Store apps, and CurrentUser PowerShell modules; v2.2 avoids whole-script elevation |
| `get_sysinfo.ps1` | System information collection |
| `filename_cleanup.ps1` | Batch file renaming utility |

The winget installer enables `InstallerHashOverride` and passes `--ignore-security-hash` for non-Store installs. Review this security tradeoff and the package catalog before use; individual installers may still request elevation.

**Windows image conversion:** [`convert-wimtovhdx.ps1`](./ps_wim/convert-wimtovhdx.ps1) supports WIM/ESD/ISO input, image selection by index or edition, metadata-based output naming, dynamic/fixed VHD or VHDX, UEFI/GPT or BIOS/MBR layouts, and optional drivers, unattended setup, recovery partition, and native boot configuration. Run elevated with the Hyper-V management module installed and use a local output path. `-NativeBoot` changes the running machine's boot configuration.

```powershell
# Inspect available Windows images before selecting one.
.\ps_wim\convert-wimtovhdx.ps1 -SourcePath "D:\ISO\Windows.iso" -ListImages -ListImageDetailed
```

---

## Tips & Tricks

### Windows Terminal on Server 2022/2019

1. Go to [MS STORE link](https://store.rg-adguard.net/)
2. Choose **PackageFamilyName**, search for:
   - `Microsoft.UI.Xaml.2.8_8wekyb3d8bbwe`
   - `Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe`
3. Download [Windows Terminal (latest)](https://github.com/microsoft/terminal/releases)
4. Install in order:
   ```powershell
   Add-AppxPackage -Path .\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx
   Add-AppxPackage -Path .\Microsoft.UI.Xaml.2.8_8.2310.30001.0_x64__8wekyb3d8bbwe.appx
   Add-AppxPackage -Path .\Microsoft.WindowsTerminal_Win11_1.15.2875.0_8wekyb3d8bbwe.msixbundle
   ```

### HEVC (H.265) Codec on Windows 11

1. Go to [MS STORE link](https://store.rg-adguard.net/)
2. Search **PackageFamilyName**: `Microsoft.HEVCVideoExtension_8wekyb3d8bbwe`
3. Download the largest file matching your CPU type

### Get System Temperature

**PowerShell:**
```powershell
$temps = Get-CimInstance -Namespace root/wmi -ClassName MsAcpi_ThermalZoneTemperature
$temps | ForEach-Object {
    "$($_.InstanceName): $((($_.CurrentTemperature - 2732) / 10))°C"
}
```

**WMIC (legacy):**
```cmd
wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CriticalTripPoint, CurrentTemperature
```

### Windows 11 Setup Bypass (TPM/RAM/SecureBoot)

```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig]
"BypassTPMCheck"=dword:00000001
"BypassRAMCheck"=dword:00000001
"BypassSecureBootCheck"=dword:00000001
```

### Treat BIOS Time as UTC (for dual-boot with Linux)

```reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation]
"RealTimeIsUniversal"=dword:00000001
```

### Convert PDF to Images (ImageMagick + Ghostscript)

Prerequisites: [ImageMagick](https://imagemagick.org/script/download.php), [Ghostscript](https://www.ghostscript.com/releases/gsdnld.html)

```cmd
:: Single file
magick convert -density 200 input.pdf output.png

:: Batch convert
for %a in (*.pdf) do (magick convert -density 150 -colorspace CMYK "%a" "%~na.png")
```

### Convert PDF to Text (Ghostscript)

```cmd
:: Single file
gswin64c -sDEVICE=txtwrite -o output.txt input.pdf

:: Batch convert
for %a in (*.pdf) do (gswin64c -sDEVICE=txtwrite -o "%~na.txt" "%a")
```

### Slipstream Drivers to install.wim

```cmd
:: Mount the WIM
DISM /Mount-Wim /WimFile:"D:\sources\install.wim" /index:1 /MountDir:"D:\wim"

:: Add drivers
DISM /Image:"D:\wim" /Add-Driver /Driver:"C:\Drivers" /Recurse

:: Unmount and commit
DISM /Unmount-Wim /MountDir:"D:\wim" /Commit
```

### Enable High Performance / Ultimate Performance Power Plan

```cmd
:: Enable High Performance
powercfg -s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

:: Enable Ultimate Performance (create if hidden)
powercfg /DUPLICATESCHEME e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /l
```

---

## External Resources

- [Azure Files Diagnostics](https://github.com/Azure-Samples/azure-files-samples/tree/master/AzFileDiagnostics)
- [Blocklist & Kusto Tables](https://firewalliplists.gypthecat.com/kusto-tables/)

-Qing Liu
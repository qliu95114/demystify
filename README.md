# Demystify Things and Share Ideas I am Working with Everyday

A collection of scripts, tools, and documentation for Azure infrastructure automation, network diagnostics, media processing, and system administration.

## Table of Contents

- [Azure Platform Tools](#azure-platform-tools)
- [Azure AI Integration](#azure-ai-integration)
- [Network & Connectivity](#network--connectivity)
- [Media Processing](#media-processing)
- [System Utilities](#system-utilities)
- [Tips & Tricks](#tips--tricks)

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
| [network/mergecapfiles.ps1](./network/mergecapfiles.ps1) | Merge multiple PCAP files into one |

---

## Media Processing

| Folder | Description |
|--------|-------------|
| [ps_mediaencoder](./ps_mediaencoder/) | FFmpeg-based video/audio processing. See [README](./ps_mediaencoder/README.md) |

**Key Tools:**

| Script | Description |
|--------|-------------|
| `Transcode-Video.ps1` | Batch video transcoding with automatic stream detection (MKV/MP4 → MP4) |
| `whisper_subtitle_generator.py` | Speech-to-text subtitle generation using faster-whisper. See [Guide](./ps_mediaencoder/whisper_readme.md) |
| `whisper_setup.ps1` | Automated setup for Whisper environment |
| `ffmpeg.powershell.ps1` | Batch encoding with customizable profiles |
| `ffmpeg_profile.json` | Encoding profiles configuration |

**Capabilities:**
- Batch video transcoding with codec/resolution presets
- Automatic subtitle generation from audio (multi-language)
- Subtitle timing adjustment and manipulation
- Video trimming, header/trailer removal
- Audio extraction and conversion

---

## System Utilities

| Folder | Description |
|--------|-------------|
| [ps_random](./ps_random/) | Miscellaneous PowerShell utilities |
| [ps_storeapp](./ps_storeapp/) | Windows Store app management |
| [py_portrait](./py_portrait/) | Python portrait extraction from images |

**Key Scripts in ps_random:**

| Script | Description |
|--------|-------------|
| `winget_myinstall_v2.ps1` | Interactive Windows Package Manager (winget) installer with curated app catalog |
| `get_sysinfo.ps1` | System information collection |
| `filename_cleanup.ps1` | Batch file renaming utility |

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


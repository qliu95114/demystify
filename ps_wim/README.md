# ps_wim — Windows install.wim → bootable VHDX

PowerShell tooling that turns a Windows installation image (`install.wim` / `install.esd` / a Windows ISO)
into a bootable VHD/VHDX. Everything lives in this folder.

| File | Purpose |
| --- | --- |
| `convert-wimtovhdx.ps1` | Main script. Creates the virtual disk, partitions it, applies the image with DISM, writes boot files with `bcdboot`, optionally injects drivers / unattend / WinRE. |

## Requirements

* Windows 10/11 or Windows Server 2016+ with DISM (`Get-WindowsImage`, `Expand-WindowsImage`).
* **Elevated** PowerShell (Run as Administrator) — required by the storage cmdlets and `bcdboot`.
* Hyper-V PowerShell module. The Hyper-V *role* is not needed, only the management module:

  ```powershell
  # Windows client / server, PowerShell as admin
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell
  # or
  DISM /Online /Enable-Feature /FeatureName:Microsoft-Hyper-V-Management-PowerShell
  ```

* The output VHD must be on a **local** path — `Mount-VHD` does not support UNC paths.

## Quick start

```powershell
# What is inside the image? (one summary line per image)
.\convert-wimtovhdx.ps1 -SourcePath D:\sources\install.wim -ListImages

# ...and the full metadata block per image
.\convert-wimtovhdx.ps1 -SourcePath D:\sources\install.wim -ListImages -ListImageDetailed

# Hyper-V Gen 2 (UEFI) VHDX straight from an ISO
.\convert-wimtovhdx.ps1 `
    -SourcePath C:\iso\Win11_24H2_English_x64.iso `
    -VhdPath D:\vhdx\win11-pro.vhdx `
    -Edition 'Windows 11 Pro'

# Gen 1 (BIOS/MBR) fixed-size VHD, explicit index, overwrite if it exists
.\convert-wimtovhdx.ps1 -SourcePath D:\sources\install.wim -Index 3 `
    -VhdPath D:\vhdx\gen1.vhd -DiskLayout BIOS -VhdType Fixed -SizeBytes 64GB -Force

# Drivers + unattend + WinRE partition, bigger disk
.\convert-wimtovhdx.ps1 -SourcePath C:\iso\server2025.iso -VhdPath D:\vhdx\srv2025.vhdx `
    -Edition 'Windows Server 2025 Standard' -SizeBytes 80GB `
    -DriverPath C:\drivers\nic,C:\drivers\storage -ForceUnsignedDrivers `
    -UnattendPath C:\unattend.xml -RecoveryPartition

# Native boot (boot-to-VHD) from the running OS
.\convert-wimtovhdx.ps1 -SourcePath D:\sources\install.wim -Edition 'Windows 11 Pro' `
    -VhdPath C:\vhdx\native.vhdx -NativeBoot -BootDescription 'Win11 Lab (VHDX)'

# No -VhdPath: file name generated from the image metadata, written to -OutDirectory
.\convert-wimtovhdx.ps1 -SourcePath 'E:\setup\...\sources\install.wim' -Index 1 -OutDirectory D:\vhdx

# Dry run - validates every input, changes nothing
.\convert-wimtovhdx.ps1 -SourcePath D:\sources\install.wim -VhdPath D:\vhdx\win.vhdx -WhatIf
```

## Auto-generated file name

When `-VhdPath` is omitted the name is built from the image metadata:

```
<version>-<architecture>-<name>-<editionid>-<languages>-<disklayout>-<size>GB.<vhdx|vhd>
```

Spaces, illegal filename characters and brackets become `-`, runs collapse, and if the
file already exists a `-1`, `-2` ... suffix is appended (never overwritten). Examples from
real WIMs:

```text
10.0.28000.1-x64-Windows-11-Enterprise-Enterprise-en-US-UEFI-128GB.vhdx
10.0.28000.1-x64-Windows-11-Enterprise-Enterprise-en-US-BIOS-128GB.vhd
10.0.19041.2243-x64-Windows-10-IoT-Enterprise-IoTEnterprise-en-US-UEFI-64GB.vhdx
10.0.26172.1-x64-Windows-Server-2025-Standard-ServerStandard-en-US-UEFI-64GB.vhdx
```

Notes:

* A WIM without a readable manifest (no version/arch/edition) falls back to
  `image-<index>-<layout>-<size>GB.vhdx`, or the sanitized image name if it has one.
* The size is the disk size (`-SizeBytes`, or the auto-sized value), not the image size.
* `-VhdFormat VHD` produces the same name with a `.vhd` extension.
* Multi-image sources still need `-Index` or `-Edition` — the name is built from the
  selected image only.

The script prints a summary object when it succeeds and always writes a transcript log
(default `$env:TEMP\Convert-WimToVhdx_<timestamp>.log`, override with `-LogPath`).

## End-to-end example — Windows 11 Enterprise → Hyper-V Gen 2

Real run against a Windows build share, from listing the image to a VHDX that boots in a
Generation 2 VM.

**1. List the images**

```powershell
.\convert-wimtovhdx.ps1 -SourcePath 'E:\setup\Microsoft\relsys\28000.amd64fre.enterprise_en-us_vl\sources\install.wim' -ListImages
```

```text
[2026-09-19 06:13:09] == Images in 'E:\setup\Microsoft\relsys\28000.amd64fre.enterprise_en-us_vl\sources\install.wim'

Index Name                  Architecture Version     EditionId  InstallationType Languages SizeGB
----- ----                  ------------ -------     ---------  ---------------- --------- ------
    1 Windows 11 Enterprise x64          10.0.28000.1 Enterprise Client           en-US     20.07
```

Add `-ListImageDetailed` when you want the full metadata block of every image:

```powershell
.\convert-wimtovhdx.ps1 -SourcePath 'E:\setup\Microsoft\relsys\28000.amd64fre.enterprise_en-us_vl\sources\install.wim' -ListImages -ListImageDetailed
```

```text
Index              : 1
Name               : Windows 11 Enterprise
Description        : Windows 11 Enterprise
DisplayName        : Windows 11 Enterprise
DisplayDescription : Windows 11 Enterprise
Flags              : Enterprise
Architecture       : x64
Version            : 10.0.28000.1
Build              : 28000
Branch             : br_release
EditionId          : Enterprise
InstallationType   : Client
ProductType        : WinNT
ProductSuite       : Terminal Server
ProductName        : Microsoft® Windows® Operating System
SystemRoot         : WINDOWS
Languages          : en-US
DefaultLanguage    : en-US
SizeGB             : 20.07
SizeBytes          : 21549176896
DirectoryCount     : 21923
FileCount          : 109343
HardlinkBytesGB    : 9.24
CreatedUtc         : 2025-11-04 2:32:00 PM
ModifiedUtc        : 2025-11-04 3:05:45 PM
WimBootable        : False
ImageState         : IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE
```

Only one image, so no `-Index` / `-Edition` is needed below.

> The extra columns and the `-ListImageDetailed` block come from the XML manifest stored
> inside the WIM, which has far more than `Get-WindowsImage` returns (that cmdlet only
> exposes name/index/description/size).
> If the manifest is unreadable (compressed metadata, split `.swm`, or an `.esd` with a
> different layout) the script falls back to the DISM fields and simply leaves the extra
> properties blank — it never fails the listing.

**2. Build the VHDX**

```powershell
.\convert-wimtovhdx.ps1 `
    -SourcePath 'E:\setup\Microsoft\relsys\28000.amd64fre.enterprise_en-us_vl\sources\install.wim' `
    -VhdPath 'D:\TEMP\28000.amd64fre.enterprise_en-us_vl.gen2.vhdx' `
    -SizeBytes 64GB -Force
```

```text
[2026-09-19 05:52:40]    Log: C:\Users\qliu\AppData\Local\Temp\Convert-WimToVhdx_20260919_135240.log
[2026-09-19 05:52:40] == Loading modules
[2026-09-19 05:52:40]    Dism + Hyper-V modules loaded
[2026-09-19 05:52:40] == Reading image information from 'E:\setup\...\sources\install.wim'
[2026-09-19 05:52:41]    Selected: index 1 - 'Windows 11 Enterprise' (20.07 GB)
[2026-09-19 05:52:42] == Creating Dynamic VHDX 'D:\TEMP\28000.amd64fre.enterprise_en-us_vl.gen2.vhdx'
[2026-09-19 05:52:43] == Attaching and partitioning the disk
[2026-09-19 05:52:47]    Disk 1 (64.00 GB)
[2026-09-19 05:52:51] == Formatting volumes
[2026-09-19 05:52:57]    System: F:  Windows: G:
[2026-09-19 05:52:57] == Applying image 1 'Windows 11 Enterprise' to G:\
[2026-09-19 05:59:35] == Writing UEFI boot files with bcdboot
[2026-09-19 05:59:35] == Done: 'D:\TEMP\28000.amd64fre.enterprise_en-us_vl.gen2.vhdx'

VhdPath     : D:\TEMP\28000.amd64fre.enterprise_en-us_vl.gen2.vhdx
VhdFormat   : VHDX
VhdType     : Dynamic
DiskLayout  : UEFI
SizeBytes   : 68719476736
SizeGB      : 64
SourcePath  : E:\setup\Microsoft\relsys\28000.amd64fre.enterprise_en-us_vl\sources\install.wim
ImageIndex  : 1
ImageName   : Windows 11 Enterprise
ImageSizeGB : 20.07
NativeBoot  : False
Recovery    : False
LogPath     : C:\Users\qliu\AppData\Local\Temp\Convert-WimToVhdx_20260919_135240.log

[2026-09-19 05:59:35] == Cleaning up
```

Result: 64 GB dynamic VHDX, 11.35 GB on disk, UEFI/GPT, dismounted automatically — attach it
to a Generation 2 VM and it boots.

> Applying 20 GB took about 6.5 minutes. Run long conversions in a **foreground** shell —
> a scheduled/background host that kills the job mid-apply leaves the VHD attached with
> `F:`/`G:` assigned. If that happens, recover with
> `Get-VHD -Path <vhd> | Dismount-VHD` (see Troubleshooting).

## Logging format

Every console line (and therefore every line of the transcript) starts with a **UTC** timestamp:

```text
[2026-09-19 05:41:02] == Applying image 1 'Windows 11 Pro' to G:\
[2026-09-19 05:41:03]    Log: C:\Users\...\Convert-WimToVhdx_20260919_054101.log
[2026-09-19 05:41:30]    WARNING: Winre.wim not found in the applied image ...
[2026-09-19 05:41:31] !! ERROR: bcdboot.exe exited with code 193.
```

| Marker | Meaning |
| --- | --- |
| `==` | Step started |
| *(none)* | Informational detail |
| `WARNING:` | Non-fatal problem, the run continues |
| `!! ERROR:` | Fatal error, the script aborts and cleans up |

Timestamps come from `(Get-Date).ToUniversalTime()`; only the log *file name* keeps local time.

## Parameters

| Parameter | Default | Notes |
| --- | --- | --- |
| `-SourcePath` | (required) | `install.wim`, `install.esd` or a Windows ISO (mounted automatically). |
| `-VhdPath` | auto | Output VHDX/VHD path. Optional — see [Auto-generated file name](#auto-generated-file-name). The extension picks the format unless `-VhdFormat` is given. |
| `-OutDirectory` | current dir | Where the auto-generated file is written. Ignored when `-VhdPath` is given. |
| `-Index` / `-Edition` | auto | Image index or image name. Omit both when the source has a single image. |
| `-ListImages` | off | List images and exit: one summary line per image (index, name, arch, version/build, edition, install type, languages, size). |
| `-ListImageDetailed` | off | With `-ListImages`, also print the full metadata block of every image (flags, product name, system root, file/dir counts, created/modified, image state, ...). |
| `-VhdFormat` | `VHDX` | `VHDX` or `VHD` (VHD is capped at 2040 GB). |
| `-VhdType` | `Dynamic` | `Dynamic` or `Fixed`. |
| `-DiskLayout` | `UEFI` | `UEFI` (GPT) or `BIOS` (MBR). |
| `-SizeBytes` | auto | `image size * 1.5 + 4 GB`, minimum 32 GB. |
| `-Force` | off | Overwrite an existing VHD. |
| `-DriverPath` | — | One or more driver folders, injected recursively. |
| `-ForceUnsignedDrivers` | off | Allows unsigned drivers. |
| `-UnattendPath` | — | Copied to `\Windows\Panther\unattend.xml`. |
| `-RecoveryPartition` | off | 750 MB WinRE partition + `reagentc` registration (best effort). |
| `-NativeBoot` | off | Adds a boot entry on the running OS in addition to the in-VHD boot files. |
| `-BootDescription` | — | `bcdboot /description` for the created boot entry. |
| `-CheckIntegrity` / `-Verify` | off | WIM integrity check / verify applied files (slower). |
| `-LogPath` | temp | Transcript log path. |

## Disk layouts

```
UEFI / GPT   [ MSR 16 MB ][ EFI 100 MB FAT32 ][ Windows NTFS ][ WinRE 750 MB (optional) ]
BIOS / MBR   [ System 100 MB NTFS (active)  ][ Windows NTFS  ][ WinRE 750 MB (optional) ]
```

The Windows partition takes the rest of the disk. `Initialize-Disk` already creates the MSR on current
Windows builds, so the script only adds one when it is missing.

## Troubleshooting

* **"This script must be run elevated"** — start PowerShell with *Run as Administrator*.
* **Leftover drive letters after a crash** — the script removes the letters it assigned and dismounts
  the VHD in a `finally` block, retrying while DISM still holds handles. If it still fails, clean up with:

  ```powershell
  Get-VHD -Path D:\vhdx\win.vhdx | Dismount-VHD
  # or: diskpart -> select vdisk file="D:\vhdx\win.vhdx" -> detach vdisk
  ```
* **DISM errors** — see `C:\Windows\Logs\DISM\dism.log`; the transcript log contains the step timings.
* **ISO left mounted** — `Get-DiskImage | Where-Object Attached | Dismount-DiskImage`.
* **`bcdboot` fails** — usually means the applied image is not a Windows OS image (e.g. a WinPE/data WIM)
  or the system partition is not FAT32.

## Notes

* Applying from an `.esd` is supported as long as the host DISM version can read it (Windows 10 1809+ recommended).
* Native boot with `-NativeBoot` modifies the boot configuration of the **running** machine. Use `-WhatIf`
  first, and keep a repair disk handy.
* BitLocker-protected or compressed target folders will slow down or fail dynamic VHD growth.

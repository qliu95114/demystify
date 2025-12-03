# Demystify things and share ideas I am working with Everyday

## Things are related to Azure Platform 

This repository contains various scripts and samples that can be used to enhance your Azure infrastructure and streamline your network operations. From analyzing network packets and logs to automating tasks, these resources aim to simplify your Azure VM management and network troubleshooting.

Contents

1. **AzureSpeedStorage**: Explore a Terraform sample that demonstrates how to create storage accounts in different Azure regions.
1. **PS_Azure(Library)**: Discover a set of PowerShell scripts that can assist you in automating common Azure tasks. This script showcases the power and flexibility of PowerShell for managing your Azure environment.
1. **ADX for Storage Analytics Logs**: Learn how to leverage Azure Data Explorer (ADX) to analyze Storage Analytics logs with ease. By following a few simple steps, you can gather logs from customers and other sources without the need for complex log configuration.
1. **ADX for Network Trace PCAPs**: Explore the capabilities of ADX in analyzing network trace PCAPs. This functionality enables you to gather network traces from customers and efficiently analyze them using ADX's powerful querying capabilities.
1. **ADX for NSGFlowLogV2**: Discover how ADX can be utilized to analyze NSGFlowLogV2, allowing you to obtain raw JSON logs from customers and other sources without the need for extensive log configuration. ADX simplifies the process of extracting valuable insights from network flow logs.
1. **Use CSV directly by Kusto**: the following show to query csv save on public url without import.  For More [Blocklist & Kusto table](https://firewalliplists.gypthecat.com/kusto-tables/)
   ```sql
   let spike_time = datetime(2025-02-15T10:00:00.000Z);
   let CIDRRanges = (
       externaldata (
           CIDRCountry:string,
           CIDR:string,
           CIDRCountryName:string,
           CIDRContinent:string,
           CIDRContinentName:string,
           CIDRSource:string
       ) ['https://firewalliplists.gypthecat.com/lists/kusto/kusto-cidr-countries.csv.zip']
       with (ignoreFirstRecord=true)
   );
   CIDRRanges
   | take 200
   ```
1. **ADX for Random Text Logs**: Learn how ADX can be used to analyze various types of random text logs, such as Linux secure logs and DNS fail logs. By leveraging ADX's query language, you can gain valuable insights from these logs and identify potential issues in your environment.
1. **Linux_bash**: Access a post-boot script designed specifically for Azure VMs running Linux. This script provides a set of useful commands and configurations to optimize your Linux-based VMs.
1. **Folder network\pcap2kusto**: Utilize the pcap2kusto.ps1 script to import PCAP files into Azure Data Explorer (Kusto). This enables you to perform advanced analysis on network packet captures and gain deeper visibility into your network traffic.
1. **Folder network\mergecapfiles**: Combine multiple PCAP files into a single file using the mergecapfiles.ps1 script. This simplifies the management and analysis of network packet captures by consolidating them into a single, unified file.
1. **Script network\get-MicrosoftIpAddressRange.ps1**: which helps you find Microsoft Azure and Office 365 IP ranges and details using public data files. This script simplifies the process of identifying and managing IP ranges associated with Microsoft services.
1. (ExternalLink) **Azure file storage**: [Diagnose Script on Azure File Storage](https://github.com/Azure-Samples/azure-files-samples/tree/master/AzFileDiagnostics)


## Things are NOT related to Azure Platform 

1. **connectivityscript**: This script is specifically designed for cloud environments and allows you to perform network connectivity tests across your infrastructure.
1. **pingmesh**: Find the pingmesh script for both Linux and Windows environments within the respective folders. 
1. **ps_mediaencoder** : Powershell script with ffmpeg 
1. How to install Windows Terminal on Windows Server 2022/2019
   1. Go to [MS STORE link](https://store.rg-adguard.net/)
   2. Choose **PackageFamilyName**, Search **Microsoft.UI.Xaml.2.8_8wekyb3d8bbwe** and **Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe**, choose the largest file match your CPU type
   3. Download [Windows Terminal(latest)](https://github.com/microsoft/terminal/releases?WT.mc_id=modinfra-26926-thmaure)
   4. Go to download folder 
      ```
       Add-AppxPackage -Path C:\setup\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx
       Add-AppxPackage -Path C:\setup\Microsoft.UI.Xaml.2.8_8.2310.30001.0_x64__8wekyb3d8bbwe.appx
       Add-AppxPackage -Path C:\setup\Microsoft.WindowsTerminal_Win11_1.15.2875.0_8wekyb3d8bbwe.msixbundle
      ```
1. How to install HEVC (h.265 on Windows 11 native)
   1. Go to [MS STORE link](https://store.rg-adguard.net/)
   2. Choose **PackageFamilyName**, Search **Microsoft.HEVCVideoExtension_8wekyb3d8bbwe** and choose the largest file match your CPU type
1. How to get temperature
   
   WMIC version
   ```dos
   wmic /namespace:\\root\wmi PATH MSAcpi_ThermalZoneTemperature get CriticalTripPoint, CurrentTemperature
   ```

   Powershell version
   ```powershell
   $a=Get-CimInstance -Namespace root/wmi -ClassName MsAcpi_ThermalZoneTemperature | select CriticalTripPoint, CurrentTemperature , InstanceName
   foreach ($line in $a) { write-output "$($line.InstanceName),$(($line.CriticalTripPoint-2732)/10),$(($line.CurrentTemperature-2732)/10)"}
    ACPI\ThermalZone\CPUZ_0,128,71
    ACPI\ThermalZone\GFXZ_0,128,30
    ACPI\ThermalZone\EXTZ_0,128,41
    ACPI\ThermalZone\LOCZ_0,128,47
    ACPI\ThermalZone\BATZ_0,128,23
    ACPI\ThermalZone\CHGZ_0,128,45
    ACPI\ThermalZone\PCHZ_0,128,0
   ```
1. Windows 11 Setup Bypass Registery
   ```
   Windows Registry Editor Version 5.00

   [HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig]
   "BypassTPMCheck"=dword:00000001
   "BypassRAMCheck"=dword:00000001
   "BypassSecureBootCheck"=dword:00000001
   '``
1. On Windows how to treat BIOS time as UTC timezone
   ```
   Windows Registry Editor Version 5.00

   [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation]
   "RealTimeIsUniversal"=dword:00000001
   ```
1. (It's gone) Fun Apple II Video Game in 1983 hxxp://loderunnerwebgame.com/game/

1. How to convert PDF(s) to JPG,PNG by GhostScript
   1. Download ImageMagick from the official website: [ImageMagick Download](https://imagemagick.org/script/download.php)
   2. Download Ghostscript from the official website: [Ghostscript Download](https://www.ghostscript.com/releases/gsdnld.html)
   3. Run in Command Prompt
   ```
   magick convert -density 200 <pathofpdffile> <pathofjpgfile or pathofpngfile>
   magick convert -density 200 -colorspace CMYK <pathofpdffile> <pathofjpgfile or pathofpngfile>

   >batch convert for all the files start with 2024*.pdf, replace the extension and use .png instead
   for %a in (2024*.pdf) do (magick convert -density 150 -colorspace CMYK "%a" "%~na.png")
   ```

1. How to convert PDF(s) to text by GhostScript
   ```
   rem one pdf file
   gswin64c -sDEVICE=txtwrite -o output.txt input.pdf

   rem *.pdf to *.txt 
   for %a in (*.pdf) do (gswin64c -sDEVICE=txtwrite -o "%~na.txt" "%a")
   ```

1. how to slipstream drivers to install.wim
   ```
   rem either imagex or dism works
   rem DISM /Mount-Wim /WimFile:"D:\temp\26100.amd64fre.enterprise_en-us_vl\sources\install.wim" /index:1 /MountDir:"D:\Temp\wim"
   
   C:\>imagex.exe /mount D:\temp\26100.amd64fre.enterprise_en-us_vl\sources\install.wim\install.wim 1 D:\VHD\wim
   ImageX Tool for Windows
   Copyright (C) Microsoft Corp. All rights reserved.
   Version: 10.0.10011.16384
   Mounting: [D:\TEMP\26100.amd64fre.enterprise_en-us_vl\sources\install.wim, 1] -> [D:\VHD\wim]...
   [ 100% ] Mounting progress
   Successfully mounted image.
   Total elapsed time: 2 min 25 sec
   
   C:\>for /f "delims=" %a in ('dir /b /o K:\Download\SurfaceUpdate') do DISM /Image:"D:\VHD\wim" /Add-Driver /Driver:"K:\Download\SurfaceUpdate\%a"
   C:\>DISM /Image:"D:\VHD\wim" /Add-Driver /Driver:"K:\Download\SurfaceUpdate\13inches"

   Deployment Image Servicing and Management tool
   Version: 10.0.26100.1
   Image Version: 10.0.26100.1
   
   Searching for driver packages to install...
   Found 1 driver package(s) to install.
   Installing 1 of 1 - K:\Download\SurfaceUpdate\13inches\SurfaceTCON.inf: The driver package was successfully installed.
   The operation completed successfully.

   C:\>imagex.exe /unmount D:\VHD\wim
   ```
1. Recover Windows 11 high performance power profile
   ```
   C:\Windows\System32>powercfg -s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

   C:\Windows\System32>powercfg /l
   Existing Power Schemes (* Active)
   -----------------------------------
   Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)
   Power Scheme GUID: 6d5da386-1e15-4830-bcc3-f4b1d9ef7d86  (HighPerf-selfcreated)
   Power Scheme GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  (High performance) *
    
   # you may want to the (Ultimate Performance) profile instead
   C:\Users\Administrator>powercfg /DUPLICATESCHEME e9a42b02-d5df-448d-aa00-03f14749eb61
   Power Scheme GUID: 0591eafb-62a8-449a-b767-b92a5143fd74  (Ultimate Performance)
   
   C:\Users\Administrator>powercfg /s 0591eafb-62a8-449a-b767-b92a5143fd74
   C:\Users\Administrator>powercfg /l
    
   Existing Power Schemes (* Active)
   -----------------------------------
   Power Scheme GUID: 0591eafb-62a8-449a-b767-b92a5143fd74  (Ultimate Performance) *
   ```






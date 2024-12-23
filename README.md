# Demystify things and share ideas I am working with Everyday

## Things are related to Azure Platform 

This repository contains various scripts and samples that can be used to enhance your Azure infrastructure and streamline your network operations. From analyzing network packets and logs to automating tasks, these resources aim to simplify your Azure VM management and network troubleshooting.

Contents

1. **AzureSpeedStorage**: Explore a Terraform sample that demonstrates how to create storage accounts in different Azure regions.
1. **PS_Azure(Library)**: Discover a set of PowerShell scripts that can assist you in automating common Azure tasks. This script showcases the power and flexibility of PowerShell for managing your Azure environment.
1. **ADX for Storage Analytics Logs**: Learn how to leverage Azure Data Explorer (ADX) to analyze Storage Analytics logs with ease. By following a few simple steps, you can gather logs from customers and other sources without the need for complex log configuration.
1. **ADX for Network Trace PCAPs**: Explore the capabilities of ADX in analyzing network trace PCAPs. This functionality enables you to gather network traces from customers and efficiently analyze them using ADX's powerful querying capabilities.
1. **ADX for NSGFlowLogV2**: Discover how ADX can be utilized to analyze NSGFlowLogV2, allowing you to obtain raw JSON logs from customers and other sources without the need for extensive log configuration. ADX simplifies the process of extracting valuable insights from network flow logs.
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
   2. Choose **PackageFamilyName**, Search Microsoft.UI.Xaml.2.8_8wekyb3d8bbwe and Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe
   3. Download [Microsoft.UI.Xaml.2.8_8.2310.30001.0_x64__8wekyb3d8bbwe.appx](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/251bbb12-dbfc-4820-b0ff-c4dfa70ffb09?P1=1723447519&P2=404&P3=2&P4=A3MMz53WZCm9IVOueU0EcBq9rfamD4UgkW538ErD5HrR06yfivfpGshtQC63FqxZUvwnIRZmCl6CWLMjeGnxDg%3d%3d)
   4. Downlaod [Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/8a26c76e-5a63-42d5-9f7d-df053c273363?P1=1670124447&P2=404&P3=2&P4=SOgVXaRGFTkCWtPYEwF6eXQpfKSIOAjRs%2fQotvgUTkTYMgooAxXVu0P8UWsKEWpMlhln5s6BwkIIlM7sdle5ew%3d%3d)
   5. Download [Windows Terminal(latest)](https://github.com/microsoft/terminal/releases?WT.mc_id=modinfra-26926-thmaure)
   6. Go to download folder 
      ```
       Add-AppxPackage -Path C:\setup\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx
       Add-AppxPackage -Path C:\setup\Microsoft.UI.Xaml.2.8_8.2310.30001.0_x64__8wekyb3d8bbwe.appx
       Add-AppxPackage -Path C:\setup\Microsoft.WindowsTerminal_Win11_1.15.2875.0_8wekyb3d8bbwe.msixbundle
      ```
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
1. Fun Apple II Video Game in 1983
   http://loderunnerwebgame.com/game/

1. How to convert PDF(s) to JPG,PNG by GhostScript
   1. Download ImageMagick from the official website: [ImageMagick Download](https://imagemagick.org/script/download.php)
   2. Download Ghostscript from the official website: [Ghostscript Download](https://www.ghostscript.com/releases/gsdnld.html)
   3. Run in Command Prompt
   ```
   magick convert -density 200 <pathofpdffile> <pathofjpgfile or pathofpngfile>
   magick convert -density 200 -colorspace CMYK <pathofpdffile> <pathofjpgfile or pathofpngfile>

   >batch convert for all the files start with 2024*.pdf, replace the extension and use .png instead
   for %a in (2024*.pdf) do (magick convert -density 150 -colorspace CMYK %a %~na.png)
   ```

1. How to convert PDF(s) to text by GhostScript
   ```
   rem one pdf file
   gswin64c -sDEVICE=txtwrite -o output.txt input.pdf

   rem *.pdf
   for %a in (*.pdf) do (gswin64c -sDEVICE=txtwrite -o %~na.txt %a)
   ```
   
   






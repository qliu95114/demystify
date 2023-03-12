# Demystify things and share ideas I am working with Everyday

## Things are related to Azure Platform 

1. How Network Packet travel bidirection between Internet to Azure VM, between Azure VM to Azure VM, between Azure VM to OnPrem Network (not started)
1. azurespeedstorage : Terraform sample of creating storage accounts in different Azure regions
1. ps_azure : random powershell script 
1. How to use ADX to analyze Storage Analytis Log in a few clicks (get logs from customer and other without config LA)
1. How to use ADX to analyze Wireshark Pcap (get network trace from customer)
1. How to use ADX to analyze NSGFlowLogV2 (get RAW JSON logs from customer and other without config LA)
1. How to use ADX to analyze Random TEXT log (linux secure log, random dns fail log and ...)
1. Linux_bash : Post-boot script for Azure VM 

## Things are NOT related to Azure Platform 

1. connectivityscript : script library of connectivity testing
1. ps_mediaencoder : powershell script with ffmpeg 
1. how to install Windows Terminal on Windows Server 2022/2019
   1. go to [MS STORE link](https://store.rg-adguard.net/)
   1. search Microsoft.UI.Xaml.2.7_8wekyb3d8bbwe and Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe
   1. Download [Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.appx](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/cadae296-3389-40c2-b927-605f7b399b78?P1=1670124102&P2=404&P3=2&P4=erd0dYktWppM%2bMNpZjs1V%2btMPjunra8%2fvJmZxF1JM%2fxzw4z13btHtNBd7iXtcMXfUkn%2bqn8ucAVX0oXyjjIqOw%3d%3d)
   1. Downlaod [Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/8a26c76e-5a63-42d5-9f7d-df053c273363?P1=1670124447&P2=404&P3=2&P4=SOgVXaRGFTkCWtPYEwF6eXQpfKSIOAjRs%2fQotvgUTkTYMgooAxXVu0P8UWsKEWpMlhln5s6BwkIIlM7sdle5ew%3d%3d)
   1. Download [Windows Terminal(latest)](https://github.com/microsoft/terminal/releases?WT.mc_id=modinfra-26926-thmaure)
   1. Go to download folder 
      ```
       Add-AppxPackage -Path C:\setup\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.Appx
       Add-AppxPackage -Path C:\setup\Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.Appx
       Add-AppxPackage -Path C:\setup\Microsoft.WindowsTerminal_Win11_1.15.2875.0_8wekyb3d8bbwe.msixbundle
      ```
1. how to get temperature 
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





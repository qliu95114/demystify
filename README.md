# Demystify things and share ideas I am working with Everyday

## Things are related to Azure Platform 

1. How do network packets travel between the internet and Azure VMs, between Azure VMs, and between Azure VMs and on-prem networks? 
1. AzureSpeedStorage: Terraform sample for creating storage accounts in different Azure regions. 
1. PS_Azure: Random PowerShell script. 
1. How can ADX be used to analyze Storage Analytics logs in a few clicks (gather logs from customers and others without configuring LA)? 
1. How can ADX be used to analyze Network trace PCAPs (gather network traces from customers)? 
1. How can ADX be used to analyze NSGFlowLogV2 (get raw JSON logs from customers and others without configuring LA)?
1. How can ADX be used to analyze random text logs (Linux secure logs, random DNS fail logs, etc.)?
1. Linux_bash: Post-boot script for Azure VMs.
1. network\pcap2kusto\pcap2kusto.ps1 : import PCAP to Kusto
1. network\pcap2kusto\mergecapfiles.ps1 : merge all pcap files under one folder to one pcap file

## Things are NOT related to Azure Platform 

1. connectivityscript : Script library of connectivity testing
1. ps_mediaencoder : Powershell script with ffmpeg 
1. How to install Windows Terminal on Windows Server 2022/2019
   1. Go to [MS STORE link](https://store.rg-adguard.net/)
   1. Search Microsoft.UI.Xaml.2.7_8wekyb3d8bbwe and Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe
   1. Download [Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.appx](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/cadae296-3389-40c2-b927-605f7b399b78?P1=1670124102&P2=404&P3=2&P4=erd0dYktWppM%2bMNpZjs1V%2btMPjunra8%2fvJmZxF1JM%2fxzw4z13btHtNBd7iXtcMXfUkn%2bqn8ucAVX0oXyjjIqOw%3d%3d)
   1. Downlaod [Microsoft.VCLibs.140.00.UWPDesktop_8wekyb3d8bbwe](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/8a26c76e-5a63-42d5-9f7d-df053c273363?P1=1670124447&P2=404&P3=2&P4=SOgVXaRGFTkCWtPYEwF6eXQpfKSIOAjRs%2fQotvgUTkTYMgooAxXVu0P8UWsKEWpMlhln5s6BwkIIlM7sdle5ew%3d%3d)
   1. Download [Windows Terminal(latest)](https://github.com/microsoft/terminal/releases?WT.mc_id=modinfra-26926-thmaure)
   1. Go to download folder 
      ```
       Add-AppxPackage -Path C:\setup\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.Appx
       Add-AppxPackage -Path C:\setup\Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.Appx
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





rem help me write batch file that take %1 as username %2 as password and modify the registery key and windows server for auto login 999 times

@echo off
set "user=%~1"
set "pass=%~2"
set pingmesh_powershell="https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/pingmesh/pingmesh_bootstrap.ps1"
rem set pingmesh_config="https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/pingmesh/config.json"
set "pingmesh_config=%~3"
rem if %~3 is empty then use default config
if "%~3"=="" set pingmesh_config="https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/pingmesh/config.json"

echo "%date% %time% %computername%\%user%" >> c:\pingmesh_bootloader_log.txt

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d "%user%" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "%pass%" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /t REG_SZ /d "%COMPUTERNAME%" /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /t REG_DWORD /d 999 /f

echo "%date% %time% update AutoAdminLogin Success!" >> c:\pingmesh_bootloader_log.txt

ren please add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\pingmesh_bootloader.bat
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v pingmesh /t REG_SZ /d "powershell -ExecutionPolicy Unrestricted \"iex (new-object net.webclient).downloadstring('%pingmesh_powershell%')\ -configjson %pingmesh_config%"" /f

echo "%date% %time% add powershell pingmesh_bootstrap Success!" >> c:\pingmesh_bootloader_log.txt

rem enable firewall allow icmp in  
netsh advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol=icmpv4:8,any dir=in action=allow

rem enable firewall allow rdp in   
netsh advfirewall firewall add rule name="RDP Allow incoming V4" protocol=TCP dir=in localport=3389 action=allow

rem enable firewall allow smb in
netsh advfirewall firewall add rule name="SMB file share" protocol=TCP dir=in localport=445 action=allow

shutdown -r -t 5 -f
echo "%date% %time% reboot %computename%" >> c:\pingmesh_bootloader_log.txt


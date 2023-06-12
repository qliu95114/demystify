# To use this program, ensure dotnet is installed on the machine 
# invoke-webrequest "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/websocket/server/ws_server.ps1" -OutFile "$env:temp\ws_server.ps1"; iex "$($env:temp)\ws_server.ps1"

# create dotnet project
mkdir C:\ws_server
Set-Location C:\ws_server
dotnet new web
delete c:\ws_server\program.cs

# download program.cs from github
(New-Object System.Net.WebClient).DownloadFile("https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/websocket/server/Program.cs", "C:\ws_server\program.cs")

# build and run
dotnet build
dotnet run

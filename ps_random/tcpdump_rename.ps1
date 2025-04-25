# 
# Parameter help description
# -Action: The action to perform. This is a mandatory parameter.

param (
    [switch]$action=$false
)

Write-host "This script will rename all files in the folder with the prefix of the folder name" -ForegroundColor Yellow
Write-host "It add the last 3 numbers of the file extension to the new name" -ForegroundColor Yellow
Write-host "This script has risk to crash the file name, use it at your own risk" -ForegroundColor Red
if ($action -eq $false) {Write-Host "Please specify -Action to make sure make it run"}

$folders=Get-ChildItem "10.*"

foreach ($folder in $folders) {
    # list all files in the folder
    $files = Get-ChildItem -Path $folder.FullName -File "*.pcap???"
    # get prefix from folder name first part of _
    $prefix = $folder.Name.Split("_")[0]
    # rename files in the folder and add prefix,
    foreach ($file in $files) {
        $newname = $prefix + "_" + $file.BaseName
        # get the last 3 numbers of file extension and add to the $newname with _ as separator
        if ($file.Extension.Length -gt 5) {
            # get the last xxx numbers of file extension, assumption is the extension is .pcap? or .pcap?? or .pcap??? or .pcap?????
            $ext = $file.Extension.Substring(5,$file.Extension.Length - 5)
            # only if $ext is not empty then add it to the $newname
            if ($ext -ne "") {
                $newname = $newname + "_" + $ext+ ".pcap"
                # print the new name and old name
                if ($action -eq $true) 
                {
                    Write-Host "(Action) Renaming $($file.FullName) to $newname" -ForegroundColor Yellow
                    Rename-Item -Path $file.FullName -NewName $newname
                }
                else {
                    Write-Host "(Preview-NoChange) Renaming $($file.FullName) to $newname"
                }
            }
            else {
                Write-Host "No extension found for $($file.FullName)"
            }
        }
        else {
            Write-Host "Rename is not needed for $($file.FullName)"
        }

    }
}
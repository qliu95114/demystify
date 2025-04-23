Write-host "This script will rename all files in the folder with the prefix of the folder name" -ForegroundColor Yellow
Write-host "It add the last 3 numbers of the file extension to the new name" -ForegroundColor Yellow
Write-host "This script has risk to crash the file name, use it at your own risk" -ForegroundColor Red
# 
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
            # get the last 3 numbers of file extension
            $ext = $file.Extension.Substring(5,3)
            # only if $ext is not empty then add it to the $newname
            if ($ext -ne "") {
                $newname = $newname + "_" + $ext+ ".pcap"
                # print the new name and old name
                Write-Host "Renaming $($file.FullName) to $newname"
                Rename-Item -Path $file.FullName -NewName $newname
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
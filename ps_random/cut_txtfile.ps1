# this powershell will cut the txt file to smaller 15000, rule for cutting is
# the output will be in the same folder with the same name but with _[increase number].txt
# we can use smaller file for gpt language translation with 32K model. 

# Parameter define the filename to split. 
Param(
    [Parameter(Mandatory=$true)][string]$filename
)

function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}


$lines = Get-Content $filename
# define an array to store the cursor position to cut the file

$cutlineposition = @()
$cutlineposition += 0 # add the first position to cut the file

# condition of file cut
# a. when size of line for add to 16000, cut the file - cut it
# b. find out continous 5 '\r\n" in the file - cut it - seems unneccessary at all

$linecount = $lines.Length
$size = 0
for ($i = 0; $i -lt $linecount; $i++) {
    #get size of one line
    $size += $lines[$i].Length
    if ($size -gt 15000) {
        $cutlineposition += $i-1
        $size = 0
    }
<#
    if ($lines[$i] -eq "") {
        $counter++
        if ($counter -eq 5) {
            $cutlineposition += $i+1-5
            $counter = 0
        }
    }
    else {
        $counter = 0 #clean up the counter if the line is not empty
    }
  #>  
}
write-host "total slice of file : $($cutlineposition.count+1)"
write-host "Position: $($cutlineposition)"

# cut the file and use the cursor in the array to cut the file
$cutlineposition += $linecount
$cutlineposition = $cutlineposition | Sort-Object
$cutlineposition
$cutfile = 0
for ($i = 0; $i -lt $cutlineposition.count-1; $i++) {
    $cutfile++
    $outputfile = $filename -replace ".txt", "_$cutfile.txt"
    $lines[$cutlineposition[$i]..$($cutlineposition[$i+1])] | Out-File $outputfile -Encoding utf8
    write-host "output file : '$outputfile'  , position : $($cutlineposition[$i]) - $($cutlineposition[$i+1])" 
}

# use GPT to translate the file to chinese
## $i=Get-ChildItem "*.txt"
## foreach ($file in $i) {gpt -contentFile "$($file.FullName)" -promptchoice common_translate_to_zh-cn -completionFile "$($file.FullName -replace '.txt', '_zh-cn.txt')"; sleep 60}



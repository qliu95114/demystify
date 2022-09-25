#requires -version 3
<#
    Get the named extended property(s) from the file or all available properties
    With code from https://rkeithhill.wordpress.com/2005/12/10/msh-get-extended-properties-of-a-file/
    @guyrleech 17/12/2019
#>

<#
.SYNOPSIS
Use FFMPG to remove header/trail of an video file 

.DESCRIPTION
Use FFMPG to remove header/trail of an video file 

.PARAMETER filename
The name of the file to retrieve the properties of

.PARAMETER startsecs
How much seconds we will cut from the beginning

.PARAMETER lastsecs
How much seconds we will cut from the end

.PARAMETER outputfolder
The Target folder we will save the cutted file

.PARAMETER lastsecs
How much seconds we will cut from the end

.EXAMPLE
#>

Param (
    [Parameter(Mandatory=$true)][string]$filename,
    [string]$outputfolder="g:\DOWNLOADS\transfer\ffmpeg",
    [int]$startsecs=0,
    [int]$lastsecs=0
)

Function Get-ExtendedProperties
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true,HelpMessage='File name to retrieve properties of')]
        [ValidateScript({Test-Path -Path $_})]
        [string]$fileName ,
        [AllowNull()]
        [string[]]$properties
    )

    [hashtable]$propertiesToIndex = @{}
    ## need to use absolute paths
    $fileName = Resolve-Path -Path $fileName | Select-Object -ExpandProperty Path
    $shellApp = New-Object -Com shell.application
    $myFolder = $shellApp.Namespace( (Split-Path -Path $fileName -Parent) )
    $myFile = $myFolder.Items().Item( (Split-Path -Path $fileName -Leaf) )

    0..500 | ForEach-Object `
    {
        If( $key = $myFolder.GetDetailsOf( $null , $_ ) )
        {
            Try
            {
                $propertiesToIndex.Add( $key , $_ )
            }
            Catch
            {
            }
        }
    }

    Write-Verbose "Got $($propertiesToIndex.Count) unique property names"

    If( ! $PSBoundParameters[ 'properties' ] -or ! $properties -or ! $properties.Count )
    {
        ForEach( $property in $propertiesToIndex.GetEnumerator() )
        {
            $thisProperty = $myFolder.GetDetailsOf( $myFile , $property.Value )
            If( ! [string]::IsNullOrEmpty( $thisProperty ) )
            {
                [pscustomobject]@{ 
                    'Property' = $property.Name
                    'Value' = $thisProperty
                }
            }
        }
    }
    Else
    {
        ForEach( $property in $properties )
        {
            $index = $propertiesToIndex[ $property ]
            If( $index -ne $null )
            {
                $myFolder.GetDetailsOf( $myFile , $index -as [int] )
            }
            Else
            {
                Write-Warning "No index for property `"$property`""
            }
        }
    }
}
Function Write-UTCLog ([string]$message,[string]$color="green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

if (($startsecs -ge 86400) -or ($lastsecs -ge 86400)) {Write-UTCLog "Start / Last Seconds cannot be greater than 86400 (1day)" "Red"; exit}

If ((Test-Path $filename) -and (Test-Path $outputfolder))
{
    $VideoLength=((Get-ExtendedProperties  $filename)| where {$_.Property -eq "Length"}).Value
    $videoduration=[int]$VideoLength.split(":")[0]*3600+[int]$VideoLength.split(":")[1]*60+[int]$VideoLength.split(":")[2]
    #Error handling
    if ($startsecs -ge $videoduration) { Write-UTCLog "Cut Start seconds cannot be greater than Vidoe Length!" "red"; exit}
    if ($lastsecs -ge $videoduration) { Write-UTCLog "Cut Last seconds cannot ber greater than Vidoe Length!" "red"; exit}
    if (($startsecs+$lastsecs) -ge $videoduration){ Write-UTCLog "Cut Start + Last seconds cannot be greater than Vidoe Length!" "red"; exit}

    $truename=$filename.split("\")[$filename.split("\").count-1]
    $outputfile=$outputfolder.TrimEnd("\")+"\"+$truename
    $logfile=$outputfolder.TrimEnd("\")+"\"+$truename.TrimEnd($truename.split(".")[$truename.split(".").count-1])+"cut.log" # remove file extension and append "cut.log"

    Write-UTCLog "Cut Start Seconds from the begin : $($startsecs)  -   Cut Last Seconds at the end : $($lastsecs)"  "Green"
    Write-UTCLog "Source Video ($($fileName)) : $($VideoLength) - $($videoduration) seconds"  "Green"

    $endsecs = $videoduration-$lastsecs
    $starttime=([timespan]::fromseconds($startsecs)).ToString().split(".")[0]
    $endtime = ([timespan]::fromseconds($endsecs)).ToString().split(".")[0]
    Write-UTCLog "Target Video ($($outputfile)): $($starttime) - $($endtime)  ; $($startsecs) - $($endsecs)"  "Green"

    #ffmpeg -y -i "D:\temp\xyz.s02e12.720p.mp4" -ss 00:01:54.000 -to 00:16:10.000 -c:v copy -map 0:v:0? -c:a copy -map 0:a? -c:s copy -map 0:s? -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 "D:\temp\s02\元龙.s02e12.720p_cut.mp4" 

    $ffcmd="ffmpeg.exe -y -i ""$($filename)"" -ss $($starttime).000 -to $($endtime).000  -c:v copy -map 0:v:0? -c:a copy -map 0:a? -c:s copy -map 0:s? -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
    Write-UTCLog "CMD: $($ffcmd)" "Yellow"
    Write-UTCLog "Begining Cut $($filename) " "Cyan"
    $st=Get-date
    Invoke-Expression $ffcmd
    $et=Get-date
    Write-UTCLog "Complete Cut $($outputfile) , time : $(($et-$st).TotalSeconds) (secs)" "Cyan"
}
else
{
    Write-UTCLog "File $($filename) or Folder $($outputfolder) does not exist, please recheck"  "Red"
}


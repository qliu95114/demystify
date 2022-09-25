<#
.SYNOPSIS

Determines if an IP is in range of a given CIDR range.

.DESCRIPTION

Determines if an IP is in range of a given CIDR range.

Author: Michael Lopez

UPDATES

2021-12-18 Initial Creation

.PARAMETER IP

The IP to check if it's in range.

.PARAMETER Range

A CIDR notation range to compare the IP against.

.INPUTS

None. This cmdlet does not support inputs (yet)

.OUTPUTS

This cmdlet will output the following information:

- IP: The IP given from the parameter
- Range: The Range given from the parameter
- Mask: The network mask
- Network: The starting address for the range.
- Broadcast: The ending address for the range.
- ExpandedRange: Represents the CIDR range in hypthenated notation.
- InRange: Represents if the given IP falls within the provided CIDR range.

.EXAMPLE

.\test-ipInRange -IP 192.168.0.1 -Range 192.168.0.0/24

.EXAMPLE

.\test-ipInRange -IP 2600:1700:1b20:f700::5 -Range 2600:1700:1b20:f700::/64

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position=0)]
    [System.Net.IPAddress]
    $IP,
    [Parameter(Mandatory,Position=1)]
    [ValidateScript({
        $vals = $_.Split("/")

        if($vals.Length -lt 2) {
            throw "$_ contains no forward slash to indicate there's a network mask."
        }
        elseif($vals.Length -gt 2) {
            throw "$_ contains multiple forward slashes, cannot dervive intended nerwork mask."
        }

        [System.Net.IPAddress]$RangeIP
        [Byte]$RangeMask
        try {
            $RangeIP = [System.Net.IPAddress]$vals[0]
        }
        catch {
            throw "The IP provided in the Range has an invalid format, $($vals[0]) cannot be parsed."
        }
        try {
            $RangeMask = [Byte]$vals[1]
        }
        catch {
            throw "The network mask $($vals[1]) cannot be parsed as an integer."
        }

        if($RangeMask -lt 0) {
            throw "The network mask $($RangeMask) is a negative number."
        }
        else
        {
            # IPv4, mask cannot be less than
            if($RangeIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
                if($RangeMask -gt 32) {
                    throw "The network mask $($RangeMask) cannot be more than 32 for an IPv4." 
                }
            }
            elseif($RangeIP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
                if($RangeMask -gt 128) {
                    throw "The network mask $($RangeMask) cannot be more than 128 for an IPv6." 
                }
            }
            else {
                throw "$($vals[0]) has an invalid IP type."
            }
        }

        $true
    })]
    [String]
    $Range
)

$values = $Range.Split("/") # Validation should have taken care of the Range parameter, assume at this point that the value is correct
$RangeIP = [System.Net.IPAddress]$values[0]
$RangeMask = [Byte]$values[1]

# Note, for IPv4, these will be 4 Byte, for IPv6 16
[Byte[]]$RangeIPBytes = $RangeIP.GetAddressBytes()
[Byte[]]$MaskBytes = [Byte[]]::new($RangeIPBytes.Length)
[Byte[]]$NetworkBytes = [Byte[]]::new($RangeIPBytes.Length)
[Byte[]]$BroadcastBytes = [Byte[]]::new($RangeIPBytes.Length)

$tempMask = $RangeMask
$i = [Int32]0
while($tempMask -gt 0) {
    $shift = ([Int](@($tempMask, 8) | Measure-Object -Minimum).Minimum)
    $MaskBytes[$i] = [Byte]([Byte]::MaxValue + (-bnot (0xFF -shr $shift))) + 1
    $NetworkBytes[$i] = $RangeIPBytes[$i] -band $MaskBytes[$i]
    $BroadcastBytes[$i] = $NetworkBytes[$i] -bor [Byte]([Byte]::MaxValue + (-bnot $MaskBytes[$i]) + 1)
    $i++
    $tempMask -= 8
}

while($i -lt $MaskBytes.Length) {
    $MaskBytes[$i] = 0
    $NetworkBytes[$i] = 0
    $BroadcastBytes[$i] = 0xFF
    $i++
}

[Byte[]]$ipInBytes = $IP.GetAddressBytes()
$inRange = $true

if($ipInBytes.Length -ne $RangeIPBytes.Length) {
    $inRange = $false # IPv4 compared to IPv6
}
else {
    for($i = 0; $i -lt $RangeIPBytes.Length; $i++) {
        if($ipInBytes[$i] -lt $NetworkBytes[$i] -or $BroadcastBytes[$i] -lt $ipInBytes[$i]) {
            $inRange = $false
            break
        }
    }
}

$networkStr = ([System.Net.IPAddress]$NetworkBytes).ToString()
$broadcastStr = ([System.Net.IPAddress]$BroadcastBytes).ToString()

[PSCustomObject]@{
    IP=$IP.ToString()
    Range=$Range
    Mask=([System.Net.IPAddress]$MaskBytes).ToString()
    Network=$networkStr
    Broadcast=$broadcastStr
    ExpandedRange="$networkStr - $broadcastStr"
    InRange=$inRange
}
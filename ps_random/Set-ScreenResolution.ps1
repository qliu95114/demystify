[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Position = 0)]
    [ValidateSet(3840, 2560, 1920)]
    [int]$Width,

    [Parameter(Position = 1)]
    [ValidateRange(1, 1000)]
    [int]$RefreshRate,

    [int]$DisplayIndex = 0
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$resolutionMap = @{
    3840 = @{ Width = 3840; Height = 2160 }
    2560 = @{ Width = 2560; Height = 1440 }
    1920 = @{ Width = 1920; Height = 1080 }
}

$resolution = $resolutionMap[$Width]

if (-not ('DisplayResolutionSettingsV2' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class DisplayResolutionSettingsV2
{
    private const int ENUM_CURRENT_SETTINGS = -1;
    private const int CDS_UPDATEREGISTRY = 0x01;
    private const int CDS_TEST = 0x02;
    private const int DISP_CHANGE_SUCCESSFUL = 0;
    private const int DISPLAY_DEVICE_ACTIVE = 0x1;
    private const int DISPLAY_DEVICE_PRIMARY_DEVICE = 0x4;
    private const int DM_PELSWIDTH = 0x00080000;
    private const int DM_PELSHEIGHT = 0x00100000;
    private const int DM_DISPLAYFREQUENCY = 0x00400000;

    public class DisplayDeviceInfo
    {
        public int Index;
        public string DeviceName;
        public string DeviceString;
        public int StateFlags;
        public bool IsActive;
        public bool IsPrimary;
    }

    public class DisplayModeInfo
    {
        public int Width;
        public int Height;
        public int Frequency;
        public int BitsPerPixel;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, int dwflags, IntPtr lParam);

    public static string GetDisplayDeviceName(int displayIndex)
    {
        DISPLAY_DEVICE displayDevice = new DISPLAY_DEVICE();
        displayDevice.cb = Marshal.SizeOf(displayDevice);

        if (!EnumDisplayDevices(null, (uint)displayIndex, ref displayDevice, 0))
        {
            throw new ArgumentException("Display index was not found: " + displayIndex);
        }

        return displayDevice.DeviceName;
    }

    public static DisplayDeviceInfo[] GetDisplayDevices()
    {
        System.Collections.Generic.List<DisplayDeviceInfo> devices = new System.Collections.Generic.List<DisplayDeviceInfo>();

        for (uint index = 0; ; index++)
        {
            DISPLAY_DEVICE displayDevice = new DISPLAY_DEVICE();
            displayDevice.cb = Marshal.SizeOf(displayDevice);

            if (!EnumDisplayDevices(null, index, ref displayDevice, 0))
            {
                break;
            }

            devices.Add(new DisplayDeviceInfo
            {
                Index = (int)index,
                DeviceName = displayDevice.DeviceName,
                DeviceString = displayDevice.DeviceString,
                StateFlags = displayDevice.StateFlags,
                IsActive = (displayDevice.StateFlags & DISPLAY_DEVICE_ACTIVE) == DISPLAY_DEVICE_ACTIVE,
                IsPrimary = (displayDevice.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) == DISPLAY_DEVICE_PRIMARY_DEVICE
            });
        }

        return devices.ToArray();
    }

    public static DisplayModeInfo GetCurrentMode(string deviceName)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(devMode);

        if (!EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref devMode))
        {
            throw new InvalidOperationException("Could not read current display settings for " + deviceName);
        }

        return new DisplayModeInfo
        {
            Width = devMode.dmPelsWidth,
            Height = devMode.dmPelsHeight,
            Frequency = devMode.dmDisplayFrequency,
            BitsPerPixel = devMode.dmBitsPerPel
        };
    }

    public static DisplayModeInfo[] GetSupportedModes(string deviceName)
    {
        System.Collections.Generic.List<DisplayModeInfo> modes = new System.Collections.Generic.List<DisplayModeInfo>();

        for (int modeIndex = 0; ; modeIndex++)
        {
            DEVMODE devMode = new DEVMODE();
            devMode.dmSize = (short)Marshal.SizeOf(devMode);

            if (!EnumDisplaySettings(deviceName, modeIndex, ref devMode))
            {
                break;
            }

            modes.Add(new DisplayModeInfo
            {
                Width = devMode.dmPelsWidth,
                Height = devMode.dmPelsHeight,
                Frequency = devMode.dmDisplayFrequency,
                BitsPerPixel = devMode.dmBitsPerPel
            });
        }

        return modes.ToArray();
    }

    public static int TestResolution(string deviceName, int width, int height, int frequency)
    {
        return ChangeResolutionInternal(deviceName, width, height, frequency, CDS_TEST);
    }

    public static int ChangeResolution(string deviceName, int width, int height, int frequency)
    {
        return ChangeResolutionInternal(deviceName, width, height, frequency, CDS_UPDATEREGISTRY);
    }

    private static int ChangeResolutionInternal(string deviceName, int width, int height, int frequency, int flags)
    {
        DEVMODE devMode = new DEVMODE();
        devMode.dmSize = (short)Marshal.SizeOf(devMode);

        if (!EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref devMode))
        {
            throw new InvalidOperationException("Could not read current display settings for " + deviceName);
        }

        devMode.dmPelsWidth = width;
        devMode.dmPelsHeight = height;
        devMode.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT;

        if (frequency > 0)
        {
            devMode.dmDisplayFrequency = frequency;
            devMode.dmFields = devMode.dmFields | DM_DISPLAYFREQUENCY;
        }

        return ChangeDisplaySettingsEx(deviceName, ref devMode, IntPtr.Zero, flags, IntPtr.Zero);
    }

    public static bool IsSuccessful(int result)
    {
        return result == DISP_CHANGE_SUCCESSFUL;
    }

    public static string GetChangeResultMessage(int result)
    {
        switch (result)
        {
            case 0:
                return "The settings change was successful.";
            case 1:
                return "The computer must be restarted for the settings to work.";
            case -1:
                return "The display driver failed the requested graphics mode.";
            case -2:
                return "The graphics mode is not supported.";
            case -3:
                return "The graphics mode was not written to the registry.";
            case -4:
                return "An invalid parameter was passed.";
            case -5:
                return "The caller does not have permission to change the graphics mode.";
            case -6:
                return "The settings change failed because another user session owns the display.";
            default:
                return "Windows returned display-change code " + result + ".";
        }
    }
}
'@
}

function Format-Mode {
    param(
        [Parameter(Mandatory = $true)]
        $Mode
    )

    return "$($Mode.Width)x$($Mode.Height) @ $($Mode.Frequency)Hz, $($Mode.BitsPerPixel)bpp"
}

function Get-UtcTimestamp {
    return [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'")
}

function Write-LogMessage {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $color = switch ($Level) {
        'INFO' { [ConsoleColor]::Green }
        'WARNING' { [ConsoleColor]::Yellow }
        'ERROR' { [ConsoleColor]::Red }
    }
    $line = "$(Get-UtcTimestamp) [$Level] $Message"
    $previousColor = [Console]::ForegroundColor

    try {
        [Console]::ForegroundColor = $color

        if ($Level -eq 'ERROR') {
            [Console]::Error.WriteLine($line)
            return
        }

        [Console]::Out.WriteLine($line)
    }
    finally {
        [Console]::ForegroundColor = $previousColor
    }
}

function Write-TreeLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [switch]$Cyan
    )

    if ($Cyan) {
        Write-Host $Text -ForegroundColor Cyan
        return
    }

    Write-Output $Text
}

function Test-SameMode {
    param(
        [Parameter(Mandatory = $true)]
        $Left,

        [Parameter(Mandatory = $true)]
        $Right
    )

    return $Left.Width -eq $Right.Width `
        -and $Left.Height -eq $Right.Height `
        -and $Left.Frequency -eq $Right.Frequency `
        -and $Left.BitsPerPixel -eq $Right.BitsPerPixel
}

function Get-ActiveDisplayDevice {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $device = @([DisplayResolutionSettingsV2]::GetDisplayDevices() | Where-Object { $_.IsActive -and $_.Index -eq $Index }) | Select-Object -First 1

    if (-not $device) {
        $activeIndexes = @([DisplayResolutionSettingsV2]::GetDisplayDevices() | Where-Object { $_.IsActive } | ForEach-Object { $_.Index })
        $activeLabel = if ($activeIndexes.Count -gt 0) { $activeIndexes -join ', ' } else { 'none' }
        throw "Display index $Index is not an active display. Active display indexes: $activeLabel. Run this script without arguments to list displays."
    }

    return $device
}

function Get-SupportedModeSuggestion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceName,

        [Parameter(Mandatory = $true)]
        [int]$TargetWidth,

        [Parameter(Mandatory = $true)]
        [int]$TargetHeight
    )

    $sameResolutionModes = @(
        [DisplayResolutionSettingsV2]::GetSupportedModes($DeviceName) |
            Where-Object { $_.Width -eq $TargetWidth -and $_.Height -eq $TargetHeight } |
            Sort-Object Frequency, BitsPerPixel -Descending -Unique
    )

    if ($sameResolutionModes.Count -gt 0) {
        $refreshRates = @($sameResolutionModes | Select-Object -ExpandProperty Frequency -Unique | Sort-Object -Descending)
        return "Supported refresh rate(s) for $TargetWidth`x$TargetHeight on $DeviceName`: $($refreshRates -join ', ')Hz."
    }

    $nearbyModes = @(
        [DisplayResolutionSettingsV2]::GetSupportedModes($DeviceName) |
            Sort-Object Width, Height, Frequency, BitsPerPixel -Descending -Unique |
            Select-Object -First 8
    )

    $modeList = ($nearbyModes | ForEach-Object { Format-Mode -Mode $_ }) -join '; '
    return "Resolution $TargetWidth`x$TargetHeight is not advertised by $DeviceName. Highest supported mode(s): $modeList."
}

function Resolve-DisplayMode {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceName,

        [Parameter(Mandatory = $true)]
        [int]$TargetWidth,

        [Parameter(Mandatory = $true)]
        [int]$TargetHeight,

        [int]$TargetRefreshRate
    )

    $currentMode = [DisplayResolutionSettingsV2]::GetCurrentMode($DeviceName)
    $matchingModes = @(
        [DisplayResolutionSettingsV2]::GetSupportedModes($DeviceName) |
            Where-Object {
                $_.Width -eq $TargetWidth -and
                $_.Height -eq $TargetHeight -and
                (-not $TargetRefreshRate -or $_.Frequency -eq $TargetRefreshRate)
            } |
            Sort-Object Frequency, BitsPerPixel -Descending
    )

    if ($matchingModes.Count -eq 0) {
        $refreshLabel = if ($TargetRefreshRate) { " @ ${TargetRefreshRate}Hz" } else { '' }
        $suggestion = Get-SupportedModeSuggestion -DeviceName $DeviceName -TargetWidth $TargetWidth -TargetHeight $TargetHeight
        throw "Display mode $TargetWidth`x$TargetHeight$refreshLabel is not advertised as supported by $DeviceName. $suggestion"
    }

    if (-not $TargetRefreshRate) {
        $currentRefreshMode = @($matchingModes | Where-Object { $_.Frequency -eq $currentMode.Frequency } | Sort-Object BitsPerPixel -Descending | Select-Object -First 1)

        if ($currentRefreshMode.Count -gt 0) {
            return $currentRefreshMode[0]
        }
    }

    return ($matchingModes | Select-Object -First 1)
}

function Test-DisplayModeBeforeApply {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceName,

        [Parameter(Mandatory = $true)]
        $Mode
    )

    $testResult = [DisplayResolutionSettingsV2]::TestResolution($DeviceName, $Mode.Width, $Mode.Height, $Mode.Frequency)

    if (-not [DisplayResolutionSettingsV2]::IsSuccessful($testResult)) {
        $message = [DisplayResolutionSettingsV2]::GetChangeResultMessage($testResult)
        throw "Windows rejected preflight test for $(Format-Mode -Mode $Mode) on $DeviceName. $message"
    }
}

function Show-DisplayTree {
    $devices = @([DisplayResolutionSettingsV2]::GetDisplayDevices())
    $activeDevices = @($devices | Where-Object { $_.IsActive })
    $displayCount = $activeDevices.Count

    Write-TreeLine 'Displays'
    Write-TreeLine "+---TotalScreens: $displayCount"

    for ($deviceIndex = 0; $deviceIndex -lt $activeDevices.Count; $deviceIndex++) {
        $device = $activeDevices[$deviceIndex]
        $isLastDevice = $deviceIndex -eq ($activeDevices.Count - 1)
        $deviceBranch = if ($isLastDevice) { '\---' } else { '+---' }
        $childPrefix = if ($isLastDevice) { '    ' } else { '|   ' }
        $primaryLabel = if ($device.IsPrimary) { ' primary' } else { '' }

        Write-TreeLine "$deviceBranch[$($device.Index)] $($device.DeviceName) - $($device.DeviceString)$primaryLabel"

        $currentMode = [DisplayResolutionSettingsV2]::GetCurrentMode($device.DeviceName)
        Write-TreeLine "$childPrefix+---Current: $(Format-Mode -Mode $currentMode)" -Cyan
        Write-TreeLine "$childPrefix\---SupportedResolutions"

        $modes = @(
            [DisplayResolutionSettingsV2]::GetSupportedModes($device.DeviceName) |
                Sort-Object Width, Height, Frequency, BitsPerPixel -Descending -Unique
        )

        for ($modeIndex = 0; $modeIndex -lt $modes.Count; $modeIndex++) {
            $mode = $modes[$modeIndex]
            $modeBranch = if ($modeIndex -eq ($modes.Count - 1)) { '\---' } else { '+---' }
            Write-TreeLine "$childPrefix    $modeBranch$(Format-Mode -Mode $mode)" -Cyan:(Test-SameMode -Left $mode -Right $currentMode)
        }
    }
}

try {
    if (-not $PSBoundParameters.ContainsKey('Width')) {
        Show-DisplayTree
        exit 0
    }

    $resolution = $resolutionMap[$Width]
    $device = Get-ActiveDisplayDevice -Index $DisplayIndex
    $deviceName = $device.DeviceName
    $targetMode = Resolve-DisplayMode -DeviceName $deviceName -TargetWidth $resolution.Width -TargetHeight $resolution.Height -TargetRefreshRate $RefreshRate
    Test-DisplayModeBeforeApply -DeviceName $deviceName -Mode $targetMode

    $targetDescription = "$(Format-Mode -Mode $targetMode) on display $DisplayIndex ($deviceName)"
    if ($WhatIfPreference) {
        Write-LogMessage -Level 'WARNING' -Message "WHATIF: Would change display resolution to $targetDescription."
        exit 0
    }

    if (-not $PSCmdlet.ShouldProcess($targetDescription, 'Change display resolution')) {
        Write-LogMessage -Level 'WARNING' -Message "Display resolution change was cancelled for $targetDescription."
        exit 0
    }

    $result = [DisplayResolutionSettingsV2]::ChangeResolution($deviceName, $targetMode.Width, $targetMode.Height, $targetMode.Frequency)

    if (-not [DisplayResolutionSettingsV2]::IsSuccessful($result)) {
        $message = [DisplayResolutionSettingsV2]::GetChangeResultMessage($result)
        throw "Failed to change resolution to $(Format-Mode -Mode $targetMode). $message"
    }

    Write-LogMessage -Level 'INFO' -Message "Changed display $DisplayIndex ($deviceName) to $(Format-Mode -Mode $targetMode)."
}
catch {
    Write-LogMessage -Level 'ERROR' -Message $_.Exception.Message
    exit 1
}

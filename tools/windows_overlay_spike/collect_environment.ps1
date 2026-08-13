[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$OutputPath = (Join-Path $PSScriptRoot "../../docs/evidence/windows-overlay/environment.windows.json")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "docs/evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedOutput.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_PATH_MUST_BE_UNDER_DOCS_EVIDENCE: $resolvedOutput"
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "BLOCKED_NOT_WINDOWS: collect_environment.ps1 requires Windows PowerShell or PowerShell on Windows."
}
if (-not [Environment]::UserInteractive) {
    throw "BLOCKED_NOT_INTERACTIVE: an interactive desktop session is required."
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "GODOT_NOT_FOUND: $GodotPath"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KoalaWindowsEnvironmentNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] public static extern uint SHAppBarMessage(uint message, ref APPBARDATA data);
    [DllImport("shcore.dll")] public static extern int GetDpiForMonitor(IntPtr hMonitor, int type, out uint dpiX, out uint dpiY);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromPoint(POINT point, uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    public static object GetTaskbar() {
        var data = new APPBARDATA();
        data.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
        var positionResult = SHAppBarMessage(5, ref data);
        var stateData = new APPBARDATA();
        stateData.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
        var state = SHAppBarMessage(4, ref stateData);
        return new object[] { positionResult != 0, (int)data.uEdge, data.rc.Left, data.rc.Top, data.rc.Right - data.rc.Left, data.rc.Bottom - data.rc.Top, (int)state };
    }
    public static object GetDpiForPoint(int x, int y) {
        var point = new POINT { X = x, Y = y };
        var monitor = MonitorFromPoint(point, 2);
        uint dpiX;
        uint dpiY;
        var hr = GetDpiForMonitor(monitor, 0, out dpiX, out dpiY);
        return new object[] { hr, (int)dpiX, (int)dpiY };
    }
}
"@

[KoalaWindowsEnvironmentNative]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$videoControllers = @(Get-CimInstance -ClassName Win32_VideoController | ForEach-Object {
    [ordered]@{
        name = $_.Name
        driver_version = $_.DriverVersion
        current_horizontal_resolution = $_.CurrentHorizontalResolution
        current_vertical_resolution = $_.CurrentVerticalResolution
        current_refresh_rate = $_.CurrentRefreshRate
    }
})
$screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    $centerX = $_.Bounds.X + [int]($_.Bounds.Width / 2)
    $centerY = $_.Bounds.Y + [int]($_.Bounds.Height / 2)
    $dpi = [KoalaWindowsEnvironmentNative]::GetDpiForPoint($centerX, $centerY)
    [ordered]@{
        device_name = $_.DeviceName
        primary = $_.Primary
        bounds = @($_.Bounds.X, $_.Bounds.Y, $_.Bounds.Width, $_.Bounds.Height)
        working_area = @($_.WorkingArea.X, $_.WorkingArea.Y, $_.WorkingArea.Width, $_.WorkingArea.Height)
        dpi_query_hresult = $dpi[0]
        dpi_x = $dpi[1]
        dpi_y = $dpi[2]
        scale_percent = [int]($dpi[1] * 100 / 96)
    }
})
$godotVersion = (& $GodotPath --version | Select-Object -First 1).Trim()
$taskbar = [KoalaWindowsEnvironmentNative]::GetTaskbar()

$environment = [ordered]@{
    schema_version = 1
    captured_at_utc = [DateTime]::UtcNow.ToString("o")
    host_id = "windows-interactive-candidate"
    classification = "interactive_windows"
    user_interactive = [Environment]::UserInteractive
    remote_session = [System.Windows.Forms.SystemInformation]::TerminalServerSession
    os = [ordered]@{
        caption = $operatingSystem.Caption
        version = $operatingSystem.Version
        build_number = $operatingSystem.BuildNumber
        architecture = $operatingSystem.OSArchitecture
    }
    hardware = [ordered]@{
        manufacturer = $computerSystem.Manufacturer
        model = $computerSystem.Model
        logical_processors = $computerSystem.NumberOfLogicalProcessors
        total_physical_memory_bytes = [uint64]$computerSystem.TotalPhysicalMemory
    }
    godot = [ordered]@{
        executable_name = [IO.Path]::GetFileName((Resolve-Path -LiteralPath $GodotPath).Path)
        version = $godotVersion
    }
    graphics = $videoControllers
    screens = $screens
    taskbar = [ordered]@{
        query_succeeded = [bool]$taskbar[0]
        edge = @("left", "top", "right", "bottom")[[int]$taskbar[1]]
        bounds = @($taskbar[2], $taskbar[3], $taskbar[4], $taskbar[5])
        auto_hide = (([int]$taskbar[6] -band 1) -ne 0)
        always_on_top = (([int]$taskbar[6] -band 2) -ne 0)
    }
}

$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($environment | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "Environment evidence written: $resolvedOutput"

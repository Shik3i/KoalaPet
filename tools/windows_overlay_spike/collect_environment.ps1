[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,

    [string]$OutputPath = (Join-Path $PSScriptRoot "../../docs/evidence/windows-overlay/environment.windows.json")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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
    [ordered]@{
        device_name = $_.DeviceName
        primary = $_.Primary
        bounds = @($_.Bounds.X, $_.Bounds.Y, $_.Bounds.Width, $_.Bounds.Height)
        working_area = @($_.WorkingArea.X, $_.WorkingArea.Y, $_.WorkingArea.Width, $_.WorkingArea.Height)
    }
})
$godotVersion = (& $GodotPath --version | Select-Object -First 1).Trim()

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
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$environment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8
Write-Host "Environment evidence written: $resolvedOutput"

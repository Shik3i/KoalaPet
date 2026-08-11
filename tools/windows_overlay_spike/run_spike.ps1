[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [switch]$SkipPlatformNeutralTests,
    [switch]$SkipEnvironmentCapture
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "BLOCKED_NOT_WINDOWS: run_spike.ps1 requires Windows 10 or Windows 11."
}
if (-not [Environment]::UserInteractive) {
    throw "BLOCKED_NOT_INTERACTIVE: a real interactive Windows desktop is required."
}
if ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Administrator privileges are unnecessary; use a normal user session when possible."
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command "godot4", "godot", "Godot.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        $GodotPath = $command.Source
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "GODOT_NOT_FOUND: pass -GodotPath with the exact Godot 4.7.1 executable."
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
$gamePath = Join-Path $repositoryRoot "game"
$scenePath = "res://scenes/spikes/windows_overlay_spike.tscn"
$testPath = "res://tests/platform/run_all.gd"
$godotVersion = (& $GodotPath --version | Select-Object -First 1).Trim()
if ($godotVersion -ne "4.7.1.stable.official.a13da4feb") {
    throw "GODOT_VERSION_MISMATCH: expected 4.7.1.stable.official.a13da4feb, got $godotVersion"
}

if (-not $SkipPlatformNeutralTests) {
    & $GodotPath --headless --path $gamePath --script $testPath
    if ($LASTEXITCODE -ne 0) {
        throw "PLATFORM_NEUTRAL_TESTS_FAILED: exit code $LASTEXITCODE"
    }
}
if (-not $SkipEnvironmentCapture) {
    & (Join-Path $PSScriptRoot "collect_environment.ps1") -GodotPath $GodotPath
}

Write-Host "Launching: $GodotPath --path $gamePath --scene $scenePath"
& $GodotPath --path $gamePath --scene $scenePath
exit $LASTEXITCODE

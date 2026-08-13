[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$SaveName,
    [string]$Mode = "expanded",
    [string]$Actions = "",
    [string]$EvidenceGroup = "visual-rebuild",
    [string]$PreferencesName = "review-preferences",
    [switch]$Desktop,
    [int]$StartupMilliseconds = 1800,
    [int]$DiagnosticsDelayMilliseconds = -1
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$godot = "C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
$safeSegment = '^[A-Za-z0-9][A-Za-z0-9._-]*$'
if ($Name -notmatch $safeSegment -or $SaveName -notmatch $safeSegment -or $EvidenceGroup -notmatch $safeSegment -or $PreferencesName -notmatch $safeSegment) {
    throw "REVIEW_NAME_CONTAINS_PATH_COMPONENT"
}
if ($StartupMilliseconds -lt 0 -or $StartupMilliseconds -gt 30000 -or $DiagnosticsDelayMilliseconds -gt 30000) {
    throw "REVIEW_DELAY_OUT_OF_RANGE"
}
$evidenceBase = [IO.Path]::GetFullPath((Join-Path $repoRoot "docs\evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $evidenceBase "$EvidenceGroup\windows"))
if (-not ($evidenceRoot + [IO.Path]::DirectorySeparatorChar).StartsWith($evidenceBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "EVIDENCE_PATH_ESCAPES_ROOT: $evidenceRoot"
}
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$output = Join-Path $evidenceRoot "$Name.png"
$diagnostics = Join-Path $evidenceRoot "$Name.json"
$savePath = "user://evidence/$SaveName.json"
$preferencesPath = "user://evidence/$PreferencesName.json"
$resolvedDiagnosticsDelay = if ($DiagnosticsDelayMilliseconds -ge 0) { $DiagnosticsDelayMilliseconds } else { $StartupMilliseconds }
$diagnosticsDelayArgument = [Math]::Max(0, $resolvedDiagnosticsDelay - 250)
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
if (Test-Path -LiteralPath $diagnostics) { Remove-Item -LiteralPath $diagnostics -Force }

foreach ($existing in Get-Process -Name "Godot_v4.7.1-stable_win64" -ErrorAction SilentlyContinue) {
    if ($existing.MainWindowTitle -eq "KoalaPet (DEBUG)") {
        $existing.CloseMainWindow() | Out-Null
    }
}
Start-Sleep -Milliseconds 300

$arguments = @(
    "--path", (Join-Path $repoRoot "game"),
    "--",
    "--save-path=$savePath",
    "--preferences-path=$preferencesPath",
    "--mode=$Mode",
	"--diagnostics-path=$diagnostics",
	"--diagnostics-delay-ms=$diagnosticsDelayArgument"
)
if (-not [string]::IsNullOrWhiteSpace($Actions)) {
    $arguments += "--review-actions=$Actions"
}

$process = Start-Process -FilePath $godot -ArgumentList $arguments -PassThru
$deadline = [DateTime]::UtcNow.AddSeconds(8)
do {
    Start-Sleep -Milliseconds 100
$captureProcess = Get-Process | Where-Object { $_.MainWindowTitle -eq "KoalaPet (DEBUG)" } | Sort-Object StartTime -Descending | Select-Object -First 1
} while ($null -eq $captureProcess -and [DateTime]::UtcNow -lt $deadline)
if ($null -eq $captureProcess) {
    throw "WINDOW_HANDLE_NOT_FOUND: launcher PID $($process.Id)"
}
Start-Sleep -Milliseconds $StartupMilliseconds

$captureScript = Join-Path $repoRoot "tools\windows_overlay_spike\capture_interactive.ps1"
if ($Desktop) {
    & $captureScript -OutputPath $output -WindowTitle "KoalaPet (DEBUG)" -ProcessId $captureProcess.Id -WaitMilliseconds 100
}
else {
    & $captureScript -OutputPath $output -WindowTitle "KoalaPet (DEBUG)" -ProcessId $captureProcess.Id -WaitMilliseconds 100 -PrintWindow
}

$diagnosticsDeadline = [DateTime]::UtcNow.AddSeconds(3)
while (-not (Test-Path -LiteralPath $diagnostics) -and [DateTime]::UtcNow -lt $diagnosticsDeadline) {
    Start-Sleep -Milliseconds 100
}

$captureProcess.Refresh()
if (-not $captureProcess.HasExited) {
    $captureProcess.CloseMainWindow() | Out-Null
    $captureProcess.WaitForExit(3000) | Out-Null
}
if (-not (Test-Path -LiteralPath $diagnostics)) {
    throw "DIAGNOSTICS_NOT_WRITTEN: $diagnostics"
}
Get-Item -LiteralPath $output | Select-Object FullName, Length

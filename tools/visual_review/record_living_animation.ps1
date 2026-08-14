[CmdletBinding()]
param(
	[ValidateSet("care-sleep", "combat", "minimal", "reduced-motion", "ambient", "sleep-habitat", "sleep-minimal")]
    [string]$Scenario,
    [string]$OutputPath,
    [int]$Fps = 12,
    [int]$DurationSeconds = 0,
    [string]$GodotPath = "C:\Users\s3ish\Documents\Workspace\Godot\Godot_v4.7.1-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($Fps -lt 1 -or $Fps -gt 30) { throw "FPS_OUT_OF_RANGE: $Fps" }
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "docs\evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
if (-not $resolvedOutput.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "OUTPUT_PATH_MUST_BE_UNDER_DOCS_EVIDENCE: $resolvedOutput" }
if ([IO.Path]::GetExtension($resolvedOutput) -ne ".avi") { throw "OUTPUT_MUST_BE_AVI: $resolvedOutput" }
$godot = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "GODOT_NOT_FOUND: $godot" }
$duration = if ($DurationSeconds -gt 0) { $DurationSeconds } elseif ($Scenario -eq "care-sleep") { 34 } elseif ($Scenario -eq "combat") { 28 } else { 14 }
if ($duration -lt 3 -or $duration -gt 120) { throw "DURATION_OUT_OF_RANGE: $duration" }
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($resolvedOutput)) -Force | Out-Null
if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput -Force }
$logPath = [IO.Path]::ChangeExtension($resolvedOutput, ".log")
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
foreach ($existing in Get-Process -Name "Godot_v4.7.1-stable_win64" -ErrorAction SilentlyContinue) {
    if ($existing.MainWindowTitle -eq "KoalaPet (DEBUG)") { $existing.CloseMainWindow() | Out-Null }
}
$frameCount = $duration * $Fps
$arguments = @(
    "--path", (Join-Path $repoRoot "game"),
    "--write-movie", $resolvedOutput,
    "--fixed-fps", "$Fps",
    "--quit-after", "$frameCount",
    "--log-file", $logPath,
    "--",
    "--save-path=user://evidence/living-video-$Scenario.json",
    "--preferences-path=user://evidence/living-video-$Scenario-preferences.json",
    "--mode=small",
    "--living-animation-demo=$Scenario"
)
$process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "GODOT_MOVIE_FAILED: exit=$($process.ExitCode) log=$logPath" }
if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf)) { throw "MOVIE_NOT_WRITTEN: $resolvedOutput" }
$logText = Get-Content -Raw -LiteralPath $logPath
if ($logText -match "SCRIPT ERROR:|ERROR:") { throw "GODOT_MOVIE_LOG_HAS_ERRORS: $logPath" }
Get-Item -LiteralPath $resolvedOutput | Select-Object FullName, Length

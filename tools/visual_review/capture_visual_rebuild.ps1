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
	[string]$GodotPath = "C:\Users\s3ish\Documents\Workspace\Godot\Godot_v4.7.1-stable_win64.exe",
    [switch]$Desktop,
    [int]$StartupMilliseconds = 1800,
    [int]$DiagnosticsDelayMilliseconds = -1
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$godot = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "GODOT_NOT_FOUND: $godot" }
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

# Vulkan-backed Godot windows can make PrintWindow report success while
# returning an effectively blank frame. Reject it instead of preserving false
# visual evidence; native Movie Writer capture is the deterministic fallback.
Add-Type -AssemblyName System.Drawing
$captureBitmap = [System.Drawing.Bitmap]::FromFile($output)
try {
	$sampleColors = New-Object System.Collections.Generic.HashSet[string]
	foreach ($sampleX in @(0, [int]($captureBitmap.Width / 2), $captureBitmap.Width - 1)) {
		foreach ($sampleY in @(0, [int]($captureBitmap.Height / 2), $captureBitmap.Height - 1)) {
			$sampleColors.Add($captureBitmap.GetPixel($sampleX, $sampleY).ToArgb().ToString()) | Out-Null
		}
	}
	if ($sampleColors.Count -le 2) { throw "CAPTURE_APPEARS_BLANK: $output" }
}
finally {
	$captureBitmap.Dispose()
}
Get-Item -LiteralPath $output | Select-Object FullName, Length

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FramesPath,
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [int]$Fps = 8,
    [int]$DurationSeconds = 23
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($Fps -lt 1 -or $Fps -gt 60) { throw "FPS_OUT_OF_RANGE: $Fps" }
if ($DurationSeconds -lt 1 -or $DurationSeconds -gt 300) { throw "DURATION_OUT_OF_RANGE: $DurationSeconds" }
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "docs\evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$resolvedLog = [IO.Path]::GetFullPath($LogPath)
if (-not $resolvedLog.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "LOG_PATH_MUST_BE_UNDER_DOCS_EVIDENCE: $resolvedLog"
}
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KoalaPolishVideoWin32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
"@

[KoalaPolishVideoWin32]::SetProcessDpiAwarenessContext([IntPtr]::new(-4)) | Out-Null
$process = Get-Process | Where-Object { $_.MainWindowTitle -eq "KoalaPet (DEBUG)" } | Sort-Object StartTime -Descending | Select-Object -First 1
if ($null -eq $process -or $process.MainWindowHandle -eq [IntPtr]::Zero) { throw "KOALAPET_WINDOW_NOT_FOUND" }

$resolvedFrames = [IO.Path]::GetFullPath($FramesPath)
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedFrames.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or $resolvedFrames.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -eq $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) {
    throw "FRAMES_PATH_MUST_BE_TEMP_SUBDIRECTORY: $resolvedFrames"
}
if (Test-Path -LiteralPath $resolvedFrames) { Remove-Item -LiteralPath $resolvedFrames -Recurse -Force }
New-Item -ItemType Directory -Path $resolvedFrames -Force | Out-Null
$captureWidth = 1600
$captureHeight = 1000
$bitmap = New-Object System.Drawing.Bitmap($captureWidth, $captureHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$background = [System.Drawing.Color]::FromArgb(17, 28, 36)
$events = New-Object System.Collections.Generic.List[object]
$lastMode = ""
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$nextFrame = 0.0
try {
    while ($stopwatch.Elapsed.TotalSeconds -lt $DurationSeconds -and -not $process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        $elapsed = $stopwatch.Elapsed.TotalSeconds
        if ($elapsed -ge $nextFrame) {
            $rect = New-Object KoalaPolishVideoWin32+RECT
            [KoalaPolishVideoWin32]::GetWindowRect($process.MainWindowHandle, [ref]$rect) | Out-Null
            $width = $rect.Right - $rect.Left
            $height = $rect.Bottom - $rect.Top
            $graphics.Clear($background)
            $x = [Math]::Max(0, $captureWidth - $width - 24)
            $y = [Math]::Max(0, $captureHeight - $height - 24)
            $graphics.CopyFromScreen($rect.Left, $rect.Top, $x, $y, (New-Object System.Drawing.Size($width, $height)), [System.Drawing.CopyPixelOperation]::SourceCopy)
            if ($width -le 320) { $mode = "minimal" }
            elseif ($width -ge 1000) { $mode = "expanded" }
            else { $mode = "small" }
            if ($mode -ne $lastMode) {
                $events.Add([ordered]@{ event = "mode_$mode"; seconds = [Math]::Round($elapsed, 2); window_size = @($width, $height) })
                $lastMode = $mode
            }
            $framePath = Join-Path $resolvedFrames ("frame-{0:D4}.jpg" -f ([int][Math]::Round($nextFrame * $Fps)))
            $bitmap.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $nextFrame += 1.0 / $Fps
        }
        Start-Sleep -Milliseconds 5
    }
}
finally {
    $stopwatch.Stop()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$payload = [ordered]@{
    schema_version = 1
    fps = $Fps
    duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    frame_size = @($captureWidth, $captureHeight)
    events = $events
    scenarios = @("ambient_roaming_and_turn", "walk_to_feed_and_eat", "walk_to_training", "walk_to_bed_and_sleep", "small_to_expanded", "live_ui_scale_125", "expanded_to_minimal")
    koalapet_process_id = $process.Id
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedLog) -Force | Out-Null
[IO.File]::WriteAllText($resolvedLog, (($payload | ConvertTo-Json -Depth 6) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Get-Content -LiteralPath $resolvedLog

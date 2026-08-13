[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FramesPath,
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [int]$Fps = 6,
    [int]$DurationSeconds = 14
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
public static class KoalaVideoWin32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    [DllImport("user32.dll")] public static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT point);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder text, int maxCount);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    public const uint DOWN = 0x0002, UP = 0x0004, KEYUP = 0x0002;
}
"@

$process = Get-Process | Where-Object { $_.MainWindowTitle -eq "KoalaPet (DEBUG)" } | Sort-Object StartTime -Descending | Select-Object -First 1
if ($null -eq $process -or $process.MainWindowHandle -eq [IntPtr]::Zero) { throw "KOALAPET_WINDOW_NOT_FOUND" }
$handle = $process.MainWindowHandle
$rect = New-Object KoalaVideoWin32+RECT
[KoalaVideoWin32]::GetWindowRect($handle, [ref]$rect) | Out-Null
$dpi = [KoalaVideoWin32]::GetDpiForWindow($handle)
$scale = [double]$dpi / 96.0
$captureWidth = 1040
$captureHeight = 640
$sourceWidth = [int][Math]::Round($captureWidth / $scale)
$sourceHeight = [int][Math]::Round($captureHeight / $scale)
$sourceX = $rect.Right - $sourceWidth
$sourceY = $rect.Bottom - $sourceHeight

$resolvedFrames = [IO.Path]::GetFullPath($FramesPath)
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $resolvedFrames.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or $resolvedFrames.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) -eq $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) {
    throw "FRAMES_PATH_MUST_BE_TEMP_SUBDIRECTORY: $resolvedFrames"
}
if (Test-Path -LiteralPath $resolvedFrames) { Remove-Item -LiteralPath $resolvedFrames -Recurse -Force }
New-Item -ItemType Directory -Path $resolvedFrames -Force | Out-Null
$form = New-Object System.Windows.Forms.Form
$form.Text = "KoalaPet Click-Through Probe"
$form.StartPosition = "Manual"
$form.Location = New-Object System.Drawing.Point($sourceX, $sourceY)
$form.Size = New-Object System.Drawing.Size($sourceWidth, $sourceHeight)
$form.BackColor = [System.Drawing.Color]::FromArgb(27, 46, 63)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$label = New-Object System.Windows.Forms.Label
$label.Dock = [System.Windows.Forms.DockStyle]::Fill
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$label.ForeColor = [System.Drawing.Color]::FromArgb(232, 220, 178)
$label.Font = New-Object System.Drawing.Font("Segoe UI", 18)
$label.Text = "PRIVACY-SAFE DESKTOP TARGET`nOutside-pet native hit test pending"
$form.Controls.Add($label)
$script:underlayClicked = $false
$script:outsideHitTarget = $false
$script:outsideRawHit = 0
$script:outsideRootHit = 0
$script:outsideHitProcessId = 0
$script:outsideHitClass = ""
$script:underlayHandle = 0
$form.Add_MouseDown({ $script:underlayClicked = $true; $label.Text = "CLICK-THROUGH PASSED`nDesktop target received the outside-pet click" })
$label.Add_MouseDown({ $script:underlayClicked = $true; $label.Text = "CLICK-THROUGH PASSED`nDesktop target received the outside-pet click" })
$form.Show()
$script:underlayHandle = $form.Handle.ToInt64()
[KoalaVideoWin32]::SetForegroundWindow($handle) | Out-Null

$events = New-Object System.Collections.Generic.List[object]
function Add-Event([string]$Name, [double]$At) {
    $current = New-Object KoalaVideoWin32+RECT
    [KoalaVideoWin32]::GetWindowRect($handle, [ref]$current) | Out-Null
    $eventWidth = [int]$current.Right - [int]$current.Left
    $eventHeight = [int]$current.Bottom - [int]$current.Top
    $events.Add([ordered]@{ event = $Name; seconds = [Math]::Round($At, 2); window_size = @($eventWidth, $eventHeight) })
}
function Send-Key([int]$VirtualKey) {
    [KoalaVideoWin32]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 80
    [KoalaVideoWin32]::keybd_event([byte]$VirtualKey, 0, 0, [UIntPtr]::Zero)
    [KoalaVideoWin32]::keybd_event([byte]$VirtualKey, 0, [KoalaVideoWin32]::KEYUP, [UIntPtr]::Zero)
}
function Wait-WindowSize([int]$ExpectedWidth, [int]$ExpectedHeight, [string]$EventName) {
    $deadline = [DateTime]::UtcNow.AddSeconds(2)
    do {
        [System.Windows.Forms.Application]::DoEvents()
        $current = New-Object KoalaVideoWin32+RECT
        $rectValid = [KoalaVideoWin32]::GetWindowRect($handle, [ref]$current)
        if ($rectValid) {
            $width = [int]$current.Right - [int]$current.Left
            $height = [int]$current.Bottom - [int]$current.Top
            if ([Math]::Abs($width - $ExpectedWidth) -le 3 -and [Math]::Abs($height - $ExpectedHeight) -le 3) { return }
        }
        Start-Sleep -Milliseconds 40
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "WINDOW_SIZE_GATE_FAILED:$EventName expected=$ExpectedWidth`x$ExpectedHeight actual=$width`x$height"
}
function Send-KeyUntilWindowSize([int]$VirtualKey, [int]$ExpectedWidth, [int]$ExpectedHeight, [string]$EventName) {
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Send-Key $VirtualKey
        $deadline = [DateTime]::UtcNow.AddMilliseconds(900)
        do {
            [System.Windows.Forms.Application]::DoEvents()
            $current = New-Object KoalaVideoWin32+RECT
            $rectValid = [KoalaVideoWin32]::GetWindowRect($handle, [ref]$current)
            if ($rectValid) {
                $width = [int]$current.Right - [int]$current.Left
                $height = [int]$current.Bottom - [int]$current.Top
                if ([Math]::Abs($width - $ExpectedWidth) -le 3 -and [Math]::Abs($height - $ExpectedHeight) -le 3) { return }
            }
            Start-Sleep -Milliseconds 40
        } while ([DateTime]::UtcNow -lt $deadline)
    }
    throw "WINDOW_KEY_TRANSITION_FAILED:$EventName expected=$ExpectedWidth`x$ExpectedHeight actual=$width`x$height"
}
function Click-Relative([double]$X, [double]$Y) {
    $current = New-Object KoalaVideoWin32+RECT
    [KoalaVideoWin32]::GetWindowRect($handle, [ref]$current) | Out-Null
    [KoalaVideoWin32]::SetCursorPos($current.Left + [int][Math]::Round($X / $scale), $current.Top + [int][Math]::Round($Y / $scale)) | Out-Null
    [KoalaVideoWin32]::mouse_event([KoalaVideoWin32]::DOWN, 0, 0, 0, [UIntPtr]::Zero)
    [KoalaVideoWin32]::mouse_event([KoalaVideoWin32]::UP, 0, 0, 0, [UIntPtr]::Zero)
}

$bitmap = New-Object System.Drawing.Bitmap($captureWidth, $captureHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$nextFrame = 0.0
$clickedPet = $false; $fed = $false; $expanded = $false; $minimal = $false; $outside = $false
try {
    while ($stopwatch.Elapsed.TotalSeconds -lt $DurationSeconds) {
        [System.Windows.Forms.Application]::DoEvents()
        $elapsed = $stopwatch.Elapsed.TotalSeconds
        if (-not $clickedPet -and $elapsed -ge 2.2) { Click-Relative 120 80; Wait-WindowSize 448 243 "pet_clicked_small_opened"; $clickedPet = $true; Add-Event "pet_clicked_small_opened" $elapsed }
        if (-not $fed -and $elapsed -ge 4.6) { Click-Relative 55 282; $fed = $true; Add-Event "feed_clicked" $elapsed }
        if (-not $expanded -and $elapsed -ge 6.6) { Send-KeyUntilWindowSize 114 832 512 "expanded_opened_f3"; $expanded = $true; Add-Event "expanded_opened_f3" $elapsed }
        if (-not $minimal -and $elapsed -ge 10.0) { Send-KeyUntilWindowSize 112 192 128 "minimal_restored_f1"; $minimal = $true; Add-Event "minimal_restored_f1" $elapsed }
        if (-not $outside -and $elapsed -ge 12.0) {
            $current = New-Object KoalaVideoWin32+RECT
            [KoalaVideoWin32]::GetWindowRect($handle, [ref]$current) | Out-Null
            $targetX = $current.Left + [int][Math]::Round(12 / $scale)
            $targetY = $current.Top + [int][Math]::Round(152 / $scale)
            [KoalaVideoWin32]::SetCursorPos($targetX, $targetY) | Out-Null
            $point = New-Object KoalaVideoWin32+POINT
            $point.X = $targetX; $point.Y = $targetY
            $hit = [KoalaVideoWin32]::WindowFromPoint($point)
            $rootHit = [KoalaVideoWin32]::GetAncestor($hit, 2)
            $script:outsideRawHit = $hit.ToInt64()
            $script:outsideRootHit = $rootHit.ToInt64()
            $hitPid = [uint32]0
            [KoalaVideoWin32]::GetWindowThreadProcessId($rootHit, [ref]$hitPid) | Out-Null
            $classText = New-Object System.Text.StringBuilder 256
            [KoalaVideoWin32]::GetClassName($rootHit, $classText, $classText.Capacity) | Out-Null
            $script:outsideHitProcessId = $hitPid
            $script:outsideHitClass = $classText.ToString()
			if ($hitPid -ne $process.Id -and -not $process.HasExited) { $label.Text = "CLICK-THROUGH PASSED`nNative hit target bypassed the running KoalaPet window" }
            $script:outsideHitTarget = $rootHit -eq $form.Handle
            [KoalaVideoWin32]::mouse_event([KoalaVideoWin32]::DOWN, 0, 0, 0, [UIntPtr]::Zero)
            [KoalaVideoWin32]::mouse_event([KoalaVideoWin32]::UP, 0, 0, 0, [UIntPtr]::Zero)
            if ($script:outsideHitTarget) { $label.Text = "CLICK-THROUGH PASSED`nDesktop target was the native hit-test result" }
            $outside = $true; Add-Event "outside_pet_clicked" $elapsed
        }
        if ($elapsed -ge $nextFrame) {
            $graphics.CopyFromScreen($sourceX, $sourceY, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
            $framePath = Join-Path $resolvedFrames ("frame-{0:D4}.jpg" -f ([int][Math]::Round($nextFrame * $Fps)))
            $bitmap.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $nextFrame += 1.0 / $Fps
        }
        Start-Sleep -Milliseconds 8
    }
}
finally {
    $stopwatch.Stop(); $graphics.Dispose(); $bitmap.Dispose(); $form.Close(); $form.Dispose()
}
$payload = [ordered]@{
    schema_version = 1
    fps = $Fps
    duration_seconds = $DurationSeconds
    frame_size = @($captureWidth, $captureHeight)
    window_dpi = $dpi
    events = $events
    click_through_target_received_click = $script:underlayClicked
    outside_pet_native_hit_target_is_underlay = $script:outsideHitTarget
    outside_pet_raw_hit_handle = $script:outsideRawHit
    outside_pet_root_hit_handle = $script:outsideRootHit
    outside_pet_hit_process_id = $script:outsideHitProcessId
    outside_pet_hit_window_class = $script:outsideHitClass
    underlay_process_id = $PID
    koalapet_process_id = $process.Id
    outside_pet_native_hit_bypassed_running_koalapet = $script:outsideHitProcessId -ne $process.Id -and -not $process.HasExited
    underlay_root_handle = $script:underlayHandle
    koalapet_root_handle = $handle.ToInt64()
}
$json = $payload | ConvertTo-Json -Depth 5
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedLog) -Force | Out-Null
[IO.File]::WriteAllText($resolvedLog, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Get-Content -LiteralPath $resolvedLog

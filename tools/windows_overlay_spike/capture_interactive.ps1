[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [string]$WindowTitle = "KoalaPet (DEBUG)",
    [string]$Key = "",
    [int]$VirtualKey = -1,
    [int]$ClickX = -1,
    [int]$ClickY = -1,
    [int]$WaitMilliseconds = 600,
    [switch]$PrintWindow,
    [switch]$WindowMessageInput
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class KoalaInteractiveWin32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint message, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extraInfo);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int maxCount);
    public static IntPtr FindWindowForProcess(uint processId) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            uint owner;
            GetWindowThreadProcessId(hWnd, out owner);
            if (owner == processId && found == IntPtr.Zero) found = hWnd;
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP = 0x0101;
    public const uint MK_LBUTTON = 0x0001;
}
"@

$process = Get-Process | Where-Object { $_.MainWindowTitle -eq $WindowTitle } | Select-Object -First 1
if ($null -eq $process) {
	$process = Get-Process -Name 'Godot_v4.7.1-stable_win64' -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending | Select-Object -First 1
}
if ($null -eq $process) {
    throw "WINDOW_NOT_FOUND: $WindowTitle"
}

$windowHandle = $process.MainWindowHandle
if ($windowHandle -eq [IntPtr]::Zero) {
	$windowHandle = [KoalaInteractiveWin32]::FindWindowForProcess([uint32]$process.Id)
}
if ($windowHandle -eq [IntPtr]::Zero) {
	throw "WINDOW_HANDLE_NOT_FOUND: PID $($process.Id)"
}

[KoalaInteractiveWin32]::SetForegroundWindow($windowHandle) | Out-Null
Start-Sleep -Milliseconds 150

if (-not [string]::IsNullOrWhiteSpace($Key)) {
    [System.Windows.Forms.SendKeys]::SendWait($Key)
}
if ($VirtualKey -ge 0) {
    [KoalaInteractiveWin32]::PostMessage($windowHandle, [KoalaInteractiveWin32]::WM_KEYDOWN, [UIntPtr]::new([uint32]$VirtualKey), [IntPtr]::Zero) | Out-Null
    [KoalaInteractiveWin32]::PostMessage($windowHandle, [KoalaInteractiveWin32]::WM_KEYUP, [UIntPtr]::new([uint32]$VirtualKey), [IntPtr]::Zero) | Out-Null
}
if ($ClickX -ge 0 -and $ClickY -ge 0) {
    $rect = New-Object KoalaInteractiveWin32+RECT
    if (-not [KoalaInteractiveWin32]::GetWindowRect($windowHandle, [ref]$rect)) {
        throw "WINDOW_RECT_FAILED"
    }
    $screenX = $rect.Left + $ClickX
    $screenY = $rect.Top + $ClickY
    if ($WindowMessageInput) {
        $clientOrigin = New-Object KoalaInteractiveWin32+POINT
        [KoalaInteractiveWin32]::ClientToScreen($windowHandle, [ref]$clientOrigin) | Out-Null
        $clientX = $screenX - $clientOrigin.X
        $clientY = $screenY - $clientOrigin.Y
        $lParam = [IntPtr]((($clientY -band 0xffff) -shl 16) -bor ($clientX -band 0xffff))
        [KoalaInteractiveWin32]::PostMessage($windowHandle, [KoalaInteractiveWin32]::WM_LBUTTONDOWN, [UIntPtr]::new([KoalaInteractiveWin32]::MK_LBUTTON), $lParam) | Out-Null
        [KoalaInteractiveWin32]::PostMessage($windowHandle, [KoalaInteractiveWin32]::WM_LBUTTONUP, [UIntPtr]::Zero, $lParam) | Out-Null
    }
    else {
        [KoalaInteractiveWin32]::SetCursorPos($screenX, $screenY) | Out-Null
        [KoalaInteractiveWin32]::mouse_event([KoalaInteractiveWin32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        [KoalaInteractiveWin32]::mouse_event([KoalaInteractiveWin32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    }
}
Start-Sleep -Milliseconds $WaitMilliseconds

$windowRect = New-Object KoalaInteractiveWin32+RECT
if (-not [KoalaInteractiveWin32]::GetWindowRect($windowHandle, [ref]$windowRect)) {
    throw "WINDOW_RECT_FAILED"
}
$width = $windowRect.Right - $windowRect.Left
$height = $windowRect.Bottom - $windowRect.Top
if ($width -le 0 -or $height -le 0) {
    throw "WINDOW_SIZE_INVALID: ${width}x${height}"
}
$bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    if ($PrintWindow) {
        $dc = $graphics.GetHdc()
        try {
            if (-not [KoalaInteractiveWin32]::PrintWindow($windowHandle, $dc, 2)) {
                throw "PRINT_WINDOW_FAILED"
            }
        }
        finally {
            $graphics.ReleaseHdc($dc)
        }
    }
    else {
        $graphics.CopyFromScreen($windowRect.Left, $windowRect.Top, 0, 0, $bitmap.Size, [System.Drawing.CopyPixelOperation]::SourceCopy)
    }
    $resolved = [IO.Path]::GetFullPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path -Parent $resolved) -Force | Out-Null
    $bitmap.Save($resolved, [System.Drawing.Imaging.ImageFormat]::Png)
    $captureMode = if ($PrintWindow) { "PrintWindow" } else { "CopyFromScreen" }
    [ordered]@{
        captured_at_utc = [DateTime]::UtcNow.ToString("o")
        window_title = $WindowTitle
        window_rect = @($windowRect.Left, $windowRect.Top, $width, $height)
        output = $resolved
        key = $Key
        click_relative = @($ClickX, $ClickY)
        capture_mode = $captureMode
        input_mode = if ($WindowMessageInput) { "WindowMessage" } else { "DesktopMouse" }
    } | ConvertTo-Json -Compress
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

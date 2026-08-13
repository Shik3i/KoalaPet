[CmdletBinding()]
param(
    [string]$OutputPath = "docs\evidence\animation-polish\performance.json",
    [int]$SampleSeconds = 4
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ($SampleSeconds -lt 1 -or $SampleSeconds -gt 60) { throw "SAMPLE_SECONDS_OUT_OF_RANGE: $SampleSeconds" }
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "docs\evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $resolved.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_PATH_MUST_BE_UNDER_DOCS_EVIDENCE: $resolved"
}
$godot = "C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
$logicalProcessors = [Environment]::ProcessorCount
$scenarios = @(
    @{ name = "minimal_roaming"; mode = "minimal"; actions = "choose:moss,hatch,mode:minimal" },
    @{ name = "minimal_stationary"; mode = "minimal"; actions = "choose:moss,hatch,roaming:off,mode:minimal" },
    @{ name = "small_idle"; mode = "small"; actions = "choose:moss,hatch,mode:small,roaming:off" },
    @{ name = "small_ambient_walk"; mode = "small"; actions = "choose:moss,hatch,mode:small" },
    @{ name = "small_action_animation"; mode = "small"; actions = "choose:moss,hatch,mode:small,feed" },
    @{ name = "expanded_idle"; mode = "expanded"; actions = "choose:moss,hatch,mode:expanded,roaming:off" },
    @{ name = "minimal_moving_hit_region"; mode = "minimal"; actions = "choose:moss,hatch,mode:minimal" }
)
$results = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
    foreach ($existing in Get-Process -Name "Godot_v4.7.1-stable_win64" -ErrorAction SilentlyContinue) {
        if ($existing.MainWindowTitle -eq "KoalaPet (DEBUG)") { $existing.CloseMainWindow() | Out-Null }
    }
    Start-Sleep -Milliseconds 250
    $slug = $scenario.name
    $args = @(
        "--path", (Join-Path $repoRoot "game"), "--",
        "--save-path=user://evidence/perf-$slug.json",
        "--preferences-path=user://evidence/perf-$slug-preferences.json",
        "--mode=$($scenario.mode)",
        "--review-actions=$($scenario.actions)"
    )
    $launcher = Start-Process -FilePath $godot -ArgumentList $args -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        Start-Sleep -Milliseconds 100
        $game = Get-Process | Where-Object { $_.MainWindowTitle -eq "KoalaPet (DEBUG)" } | Sort-Object StartTime -Descending | Select-Object -First 1
    } while ($null -eq $game -and [DateTime]::UtcNow -lt $deadline)
    if ($null -eq $game) { throw "WINDOW_HANDLE_NOT_FOUND: $slug launcher=$($launcher.Id)" }
    Start-Sleep -Milliseconds 700
    $game.Refresh()
    $startCpu = $game.TotalProcessorTime.TotalSeconds
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $memory = New-Object System.Collections.Generic.List[double]
    while ($clock.Elapsed.TotalSeconds -lt $SampleSeconds -and -not $game.HasExited) {
        $game.Refresh()
        $memory.Add([Math]::Round($game.WorkingSet64 / 1MB, 2))
        Start-Sleep -Milliseconds 200
    }
    $clock.Stop()
    $game.Refresh()
    $cpuPercent = (($game.TotalProcessorTime.TotalSeconds - $startCpu) / [Math]::Max(0.1, $clock.Elapsed.TotalSeconds) / $logicalProcessors) * 100.0
    $results.Add([ordered]@{
        scenario = $slug
        sample_seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 2)
        cpu_percent_total_capacity = [Math]::Round($cpuPercent, 3)
        working_set_mb_average = [Math]::Round(($memory | Measure-Object -Average).Average, 2)
        working_set_mb_peak = [Math]::Round(($memory | Measure-Object -Maximum).Maximum, 2)
        samples = $memory.Count
    })
    if (-not $game.HasExited) {
        $game.CloseMainWindow() | Out-Null
        $game.WaitForExit(3000) | Out-Null
    }
}

$payload = [ordered]@{
    schema_version = 1
    measured_at_utc = [DateTime]::UtcNow.ToString("o")
    host = [ordered]@{
        os = [Environment]::OSVersion.VersionString
        logical_processors = $logicalProcessors
        godot = "4.7.1 stable"
        rendering_method = "gl_compatibility"
        gpu_counter = "not available through this deterministic harness"
    }
    results = $results
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolved) -Force | Out-Null
[IO.File]::WriteAllText($resolved, (($payload | ConvertTo-Json -Depth 7) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Get-Content -LiteralPath $resolved

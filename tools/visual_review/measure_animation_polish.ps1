[CmdletBinding()]
param(
    [string]$OutputPath = "docs\evidence\animation-polish\performance.json",
    [int]$SampleSeconds = 4,
    [string]$GodotPath = "C:\Users\s3ish\Documents\Workspace\Godot\Godot_v4.7.1-stable_win64.exe"
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
$godot = [IO.Path]::GetFullPath($GodotPath)
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "GODOT_NOT_FOUND: $godot" }
$logicalProcessors = [Environment]::ProcessorCount
$runId = [DateTime]::UtcNow.ToString("yyyyMMddHHmmssfff")
$diagnosticsDelayMilliseconds = [Math]::Max(1200, [Math]::Min(2500, ($SampleSeconds * 1000) - 500))
$scenarios = @(
    @{ name = "minimal_stationary"; mode = "minimal"; actions = "choose:moss,hour,hatch,roaming:off,mode:minimal" },
    @{ name = "minimal_roaming"; mode = "minimal"; actions = "choose:moss,hour,hatch,mode:minimal" },
    @{ name = "minimal_special_idle"; mode = "minimal"; actions = "choose:moss,hour,hatch,mode:minimal,minimal:playful" },
    @{ name = "small_habitat_idle"; mode = "small"; actions = "choose:moss,hour,hatch,mode:small,roaming:off" },
    @{ name = "small_care_action"; mode = "small"; actions = "choose:moss,hour,hatch,mode:small,demo:care" },
    @{ name = "battle_exchange"; mode = "small"; actions = "choose:moss,hour,hatch,mode:small,demo:combat" },
    @{ name = "expanded_idle"; mode = "expanded"; actions = "choose:moss,hour,hatch,mode:expanded,roaming:off" },
    @{ name = "sleep_loop"; mode = "small"; actions = "choose:moss,hour,hatch,sleep,mode:small" }
)
$results = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
    foreach ($existing in Get-Process -Name "Godot_v4.7.1-stable_win64" -ErrorAction SilentlyContinue) {
        if ($existing.MainWindowTitle -eq "KoalaPet (DEBUG)") { $existing.CloseMainWindow() | Out-Null }
    }
    Start-Sleep -Milliseconds 250
    $slug = $scenario.name
	$diagnostics = Join-Path ([IO.Path]::GetDirectoryName($resolved)) "$slug-diagnostics.json"
	if (Test-Path -LiteralPath $diagnostics) { Remove-Item -LiteralPath $diagnostics -Force }
    $args = @(
        "--path", (Join-Path $repoRoot "game"), "--",
		"--save-path=user://evidence/perf-$runId-$slug.json",
		"--preferences-path=user://evidence/perf-$runId-$slug-preferences.json",
        "--mode=$($scenario.mode)",
		"--diagnostics-path=$diagnostics",
		"--diagnostics-delay-ms=$diagnosticsDelayMilliseconds",
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
		diagnostics = if (Test-Path -LiteralPath $diagnostics) { Get-Content -Raw -LiteralPath $diagnostics | ConvertFrom-Json } else { $null }
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

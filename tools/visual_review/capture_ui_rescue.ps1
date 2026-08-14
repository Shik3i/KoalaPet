<#
.SYNOPSIS
Captures the Prompt 4.9 UI-rescue evidence set from the real native Windows client.

.DESCRIPTION
Every image is produced by the application's own in-engine viewport read-back
(`--capture-path`), never by a screen grab. A screen grab of a transparent,
always-on-top window captures whatever sits behind it, which is both unreliable
and a privacy risk; the viewport read-back can only ever contain KoalaPet's own
rendered frame.

Each scenario runs the pinned Godot build against a disposable save,
preferences and placement file, so no player data is touched.
#>
[CmdletBinding()]
param(
    [string]$Godot = "C:\tmp\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe",
    [string]$OutputRoot
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$game = Join-Path $repoRoot "game"
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot "docs\evidence\ui-rescue\screenshots"
}
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot "docs\evidence")).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
if (-not $resolvedOutput.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_MUST_BE_UNDER_DOCS_EVIDENCE: $resolvedOutput"
}
if (-not (Test-Path -LiteralPath $Godot)) { throw "GODOT_NOT_FOUND: $Godot" }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$work = Join-Path ([IO.Path]::GetTempPath()) ("koalapet-ui-rescue-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $work | Out-Null

# name | launch mode | headless setup actions | extra runtime arguments
$scenarios = @(
    @{ name = "01-starter-selection";     mode = "expanded"; setup = "";                                          extra = @() },
    @{ name = "02-egg-waiting";           mode = "small";    setup = "choose:moss";                               extra = @() },
    @{ name = "03-small-care-default";    mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @() },
    @{ name = "04-small-care-english";    mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @("--locale=en") },
    @{ name = "05-small-urgent-hunger";   mode = "small";    setup = "choose:moss,hour,hatch,hour,hour,hour,hour,hour,hour"; extra = @() },
    @{ name = "06-small-sick";            mode = "small";    setup = "choose:moss,hour,hatch,sick";               extra = @() },
    @{ name = "07-small-sleeping";        mode = "small";    setup = "choose:moss,hour,hatch,sleep";              extra = @() },
    @{ name = "08-small-more-page";       mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "page:more" },
    @{ name = "09-small-adventure-page";  mode = "small";    setup = "choose:moss,hour,hatch,good,good,good";     extra = @(); actions = "page:adventure" },
    @{ name = "10-small-minimum-size";    mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "size:750x475" },
    @{ name = "11-small-large-size";      mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "size:1400x860" },
    @{ name = "12-small-ui-100";          mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "ui:100" },
    @{ name = "13-small-ui-150";          mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "ui:150" },
    @{ name = "14-small-ui-200";          mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "ui:200" },
    @{ name = "15-small-text-150";        mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "text:150" },
    @{ name = "16-expanded-overview";     mode = "expanded"; setup = "choose:moss,hour,hatch";                    extra = @() },
    @{ name = "17-expanded-english";      mode = "expanded"; setup = "choose:moss,hour,hatch";                    extra = @("--locale=en") },
    @{ name = "18-expanded-battle";       mode = "expanded"; setup = "choose:moss,hour,hatch,good,good,good";     extra = @(); actions = "tab:battle" },
    @{ name = "19-expanded-dungeon";      mode = "expanded"; setup = "choose:moss,hour,hatch,good,good,good,dungeon_unlock"; extra = @(); actions = "tab:dungeon" },
    @{ name = "20-expanded-inventory";    mode = "expanded"; setup = "choose:moss,hour,hatch,good,good,good";     extra = @(); actions = "tab:inventory" },
    @{ name = "21-expanded-evolution";    mode = "expanded"; setup = "choose:moss,hour,hatch,good,good,good";     extra = @(); actions = "tab:evolution" },
    @{ name = "22-expanded-large-size";   mode = "expanded"; setup = "choose:moss,hour,hatch";                    extra = @(); actions = "size:1900x1180" },
    @{ name = "23-settings";              mode = "small";    setup = "choose:moss,hour,hatch";                    extra = @(); actions = "settings" },
    @{ name = "24-blocked-action";        mode = "small";    setup = "choose:moss,hour,hatch,sleep";              extra = @(); actions = "train" }
)

$records = New-Object System.Collections.Generic.List[object]
foreach ($scenario in $scenarios) {
    $slot = Join-Path $work $scenario.name
    New-Item -ItemType Directory -Force -Path $slot | Out-Null
    $common = @("--save-path=$slot/save.json", "--preferences-path=$slot/prefs.json", "--placement-path=$slot/placement.json")
    if ($scenario.setup -ne "") {
        & $Godot (@("--headless", "--path", $game, "--quit-after", "900", "res://scenes/pet_game.tscn", "--") + $common + @("--review-actions=$($scenario.setup)")) 2>&1 | Out-Null
    }
    $capture = Join-Path $slot "capture.png"
    $diagnostics = Join-Path $slot "diagnostics.json"
    $runtime = @("--path", $game, "--quit-after", "300", "res://scenes/pet_game.tscn", "--") + $common +
        @("--mode=$($scenario.mode)", "--capture-path=$capture", "--diagnostics-path=$diagnostics") + $scenario.extra
    if ($scenario.ContainsKey("actions") -and $scenario.actions -ne "") {
        $runtime += "--review-actions=$($scenario.actions)"
        $runtime += "--diagnostics-delay-ms=800"
    }
    $log = & $Godot $runtime 2>&1 | Out-String
    if ($log -match "SCRIPT ERROR|ERROR:") { throw "ENGINE_ERROR_IN_SCENARIO $($scenario.name):`n$log" }
    if (-not (Test-Path -LiteralPath $capture)) { throw "CAPTURE_MISSING: $($scenario.name)" }
    $target = Join-Path $resolvedOutput ($scenario.name + ".png")
    Copy-Item $capture $target -Force
    $diagnosticsTarget = Join-Path $resolvedOutput ($scenario.name + ".json")
    if (Test-Path -LiteralPath $diagnostics) { Copy-Item $diagnostics $diagnosticsTarget -Force }
    $image = [System.Drawing.Image]::FromFile($target)
    $records.Add([ordered]@{
        name = $scenario.name
        mode = $scenario.mode
        setup = $scenario.setup
        runtime_actions = if ($scenario.ContainsKey("actions")) { $scenario.actions } else { "" }
        image = ($scenario.name + ".png")
        pixels = @($image.Width, $image.Height)
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    })
    $image.Dispose()
    Write-Host "captured $($scenario.name)"
}

Remove-Item -Recurse -Force $work -EA SilentlyContinue
$index = [ordered]@{
    schema_version = 1
    generator = "tools/visual_review/capture_ui_rescue.ps1"
    capture_method = "in_engine_viewport_readback"
    godot = (& $Godot --version) -join ""
    scenarios = $records
}
$indexPath = Join-Path $resolvedOutput "index.json"
[IO.File]::WriteAllText($indexPath, (($index | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "wrote $indexPath"

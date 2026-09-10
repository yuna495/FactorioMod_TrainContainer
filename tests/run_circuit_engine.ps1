param([string]$Factorio = 'D:/Games/steam/steamapps/common/Factorio/bin/x64/factorio.exe')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskWork = Join-Path $taskRoot '.verify-circuit'
$taskVersion = (Get-Content -LiteralPath (Join-Path $taskRoot 'info.json') -Raw | ConvertFrom-Json).version
$taskMod = Join-Path $taskWork ('mods/TrainContainer_' + $taskVersion)
New-Item -ItemType Directory -Force -Path $taskMod, (Join-Path $taskWork 'write') | Out-Null
foreach ($taskDirectory in @('scripts', 'graphics', 'locale', 'tests', 'prototypes')) {
    Copy-Item -LiteralPath (Join-Path $taskRoot $taskDirectory) -Destination $taskMod -Recurse -Force
}
Get-ChildItem -LiteralPath $taskRoot -File | Where-Object { $_.Extension -eq '.lua' -or $_.Name -eq 'info.json' } |
    Copy-Item -Destination $taskMod -Force
# Test hook exists solely in the isolated copy, never the installed mod.
$taskTransfer = Join-Path $taskMod 'scripts/train_transfer.lua'
$taskText = [IO.File]::ReadAllText($taskTransfer)
$taskEnd = $taskText.LastIndexOf('return train_transfer')
$taskText = $taskText.Insert($taskEnd, "train_transfer._test_process_group = process_group`n")
[IO.File]::WriteAllText($taskTransfer, $taskText)
Add-Content -LiteralPath (Join-Path $taskMod 'control.lua') -Value "`nrequire('tests.circuit_engine')"
Add-Content -LiteralPath (Join-Path $taskMod 'control.lua') -Value "`nrequire('tests.circuit_signal_timing')"
$taskData = Join-Path (Split-Path (Split-Path (Split-Path $Factorio -Parent) -Parent) -Parent) 'data'
$taskConfig = Join-Path $taskWork 'config.ini'
[IO.File]::WriteAllText($taskConfig, "[path]`nread-data=$taskData`nwrite-data=$(Join-Path $taskWork 'write')`n[other]`ncheck-updates=false`n")
[IO.File]::WriteAllText((Join-Path $taskWork 'mods/mod-list.json'), '{"mods":[{"name":"base","enabled":true},{"name":"quality","enabled":false},{"name":"elevated-rails","enabled":false},{"name":"space-age","enabled":false},{"name":"TrainContainer","enabled":true}]}')
$taskSave = Join-Path $taskWork 'write/circuit-test.zip'
function Invoke-TestFactorio([string[]]$TaskArguments) {
    $taskQuoted = $TaskArguments | ForEach-Object { '"' + $_ + '"' }
    $taskProcess = Start-Process -FilePath $Factorio -ArgumentList $taskQuoted -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $taskWork 'stdout.log') -RedirectStandardError (Join-Path $taskWork 'stderr.log')
    Get-Content -LiteralPath (Join-Path $taskWork 'stdout.log') -Tail 10
    Get-Content -LiteralPath (Join-Path $taskWork 'stderr.log') -Tail 10
    if ($taskProcess.ExitCode -ne 0) { throw "Factorio test exited $($taskProcess.ExitCode); inspect .verify-circuit/write/factorio-current.log" }
}
Invoke-TestFactorio @('--config', $taskConfig, '--mod-directory', (Join-Path $taskWork 'mods'), '--create', $taskSave)
Invoke-TestFactorio @('--config', $taskConfig, '--mod-directory', (Join-Path $taskWork 'mods'), '--benchmark', $taskSave, '--benchmark-ticks', '70', '--benchmark-runs', '1', '--disable-audio')
$taskLog = Join-Path $taskWork 'write/factorio-current.log'
if (-not (Select-String -LiteralPath $taskLog -Pattern 'CIRCUIT_ENGINE_PASS' -Quiet)) { throw 'Circuit engine assertions did not complete' }
if (-not (Select-String -LiteralPath $taskLog -Pattern 'CIRCUIT_SIGNAL_TIMING_PASS' -Quiet)) { throw 'Signal timing assertions did not complete' }

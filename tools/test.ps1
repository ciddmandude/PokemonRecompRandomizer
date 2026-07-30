param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$luaCommand = Get-Command lua -ErrorAction SilentlyContinue
$luacCommand = Get-Command luac -ErrorAction SilentlyContinue
$luaPath = if ($luaCommand) { $luaCommand.Source } else { $null }
$luacPath = if ($luacCommand) { $luacCommand.Source } else { $null }
$fallback = if ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA 'Programs\Lua\5.1.5'
} else {
  $null
}

if (-not $luaPath -and $fallback `
    -and (Test-Path -LiteralPath (Join-Path $fallback 'lua.exe'))) {
  $luaPath = Join-Path $fallback 'lua.exe'
}
if (-not $luacPath -and $fallback `
    -and (Test-Path -LiteralPath (Join-Path $fallback 'luac.exe'))) {
  $luacPath = Join-Path $fallback 'luac.exe'
}
if (-not $luaPath -or -not $luacPath) {
  throw 'Lua 5.1 and luac are required'
}

$luaFiles = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File `
  -Filter '*.lua' | Sort-Object FullName
foreach ($file in $luaFiles) {
  & $luacPath -p $file.FullName
  if ($LASTEXITCODE -ne 0) {
    throw "Lua syntax failed: $($file.FullName)"
  }
}

Push-Location $ProjectRoot
try {
  & $luaPath 'tests/foundation_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'foundation_test failed' }
  & $luaPath 'tests/scaffold_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'scaffold_test failed' }
  & $luaPath 'tests/bootstrap_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'bootstrap_test failed' }
  & $luaPath 'tests/species_manifest_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'species_manifest_test failed' }
  & $luaPath 'tests/save_state_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'save_state_test failed' }
  & $luaPath 'tests/options_ui_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'options_ui_test failed' }
  & $luaPath 'tests/general_settings_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'general_settings_test failed' }
  & $luaPath 'tests/matching_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'matching_test failed' }
  & $luaPath 'tests/generator_golden_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'generator_golden_test failed' }
  & $luaPath 'tests/generator_property_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'generator_property_test failed' }
  & $luaPath 'tests/wild_global_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'wild_global_test failed' }
  & $luaPath 'tests/wild_m8_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'wild_m8_test failed' }
  & $luaPath 'tests/progression_m9_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'progression_m9_test failed' }
  & $luaPath 'tests/starter_seam_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'starter_seam_test failed' }
  & $luaPath 'tests/starter_m10_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'starter_m10_test failed' }
  & $luaPath 'tests/static_gift_m11_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'static_gift_m11_test failed' }
  & $luaPath 'tests/static_gift_safety_m10_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'static_gift_safety_m10_test failed' }
  & $luaPath 'tests/trade_prize_m12_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'trade_prize_m12_test failed' }
  & $luaPath 'tests/trainer_m13_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'trainer_m13_test failed' }
  & $luaPath 'tests/spoiler_validation_test.lua'
  if ($LASTEXITCODE -ne 0) { throw 'spoiler_validation_test failed' }
  & (Join-Path $ProjectRoot 'tools/validate-scaffold.ps1')
  & (Join-Path $ProjectRoot 'tools/package-test.ps1')
} finally {
  Pop-Location
}

Write-Output "test: ok ($($luaFiles.Count) Lua files)"

param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$luaCommand = Get-Command lua -ErrorAction SilentlyContinue
$luacCommand = Get-Command luac -ErrorAction SilentlyContinue
$luaPath = if ($luaCommand) { $luaCommand.Source } else { $null }
$luacPath = if ($luacCommand) { $luacCommand.Source } else { $null }
$fallback = Join-Path $env:LOCALAPPDATA 'Programs\Lua\5.1.5'

if (-not $luaPath -and (Test-Path -LiteralPath (Join-Path $fallback 'lua.exe'))) {
  $luaPath = Join-Path $fallback 'lua.exe'
}
if (-not $luacPath -and (Test-Path -LiteralPath (Join-Path $fallback 'luac.exe'))) {
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
  & (Join-Path $ProjectRoot 'tools/validate-scaffold.ps1')
} finally {
  Pop-Location
}

Write-Output "test: ok ($($luaFiles.Count) Lua files)"

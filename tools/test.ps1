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

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
. (Join-Path $PSScriptRoot 'test-discovery.ps1')

$luaFiles = [string[]]@(
  Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File `
    -Filter '*.lua' | ForEach-Object { $_.FullName }
)
[Array]::Sort($luaFiles, [StringComparer]::Ordinal)
foreach ($file in $luaFiles) {
  & $luacPath -p $file
  if ($LASTEXITCODE -ne 0) {
    throw "Lua syntax failed: $file"
  }
}

$testFiles = @(Get-DiscoveredLuaTests `
  -TestsRoot (Join-Path $ProjectRoot 'tests'))
& (Join-Path $PSScriptRoot 'test-discovery-self-test.ps1') `
  -LuaPath $luaPath
& (Join-Path $PSScriptRoot 'portability-test.ps1') `
  -ProjectRoot $ProjectRoot

Push-Location $ProjectRoot
try {
  Invoke-DiscoveredLuaTests -LuaPath $luaPath -TestPaths $testFiles
  & (Join-Path $ProjectRoot 'tools/validate-scaffold.ps1')
  & (Join-Path $ProjectRoot 'tools/package-test.ps1')
} finally {
  Pop-Location
}

Write-Output (
  "test: ok ($($testFiles.Count) tests discovered, " +
  "$($luaFiles.Count) Lua files syntax-checked)")

param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputPath,
  [Parameter(Mandatory = $true)]
  [string]$EngineRoot
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$EngineRoot = (Resolve-Path -LiteralPath $EngineRoot).Path
$manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot 'manifest.json') `
  -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutputPath) {
  $OutputPath = Join-Path $ProjectRoot (
    'dist\{0}-{1}.zip' -f $manifest.id, $manifest.version)
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

foreach ($required in @(
    'src/script/ScriptRunner.lua',
    'tests/modkit/init.lua'
  )) {
  if (-not (Test-Path -LiteralPath (Join-Path $EngineRoot $required))) {
    throw "Recomp fixture checkout is missing $required"
  }
}

$luaCommand = Get-Command lua -ErrorAction SilentlyContinue
$luaPath = if ($luaCommand) { $luaCommand.Source } else { $null }
$fallback = if ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA 'Programs\Lua\5.1.5\lua.exe'
} else {
  $null
}
if (-not $luaPath -and $fallback -and (Test-Path -LiteralPath $fallback)) {
  $luaPath = $fallback
}
if (-not $luaPath) { throw 'Lua 5.1 is required for release qualification' }

& (Join-Path $PSScriptRoot 'test.ps1') -ProjectRoot $ProjectRoot
if ($LASTEXITCODE -ne 0) { throw 'complete release test suite failed' }

& (Join-Path $PSScriptRoot 'package.ps1') `
  -ProjectRoot $ProjectRoot -OutputPath $OutputPath | Out-Null
& (Join-Path $PSScriptRoot 'validate-package.ps1') `
  -ArchivePath $OutputPath | Out-Null

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'pokemon-randomizer-release-' + [Guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
  Expand-Archive -LiteralPath $OutputPath -DestinationPath $fixtureRoot
  Push-Location $EngineRoot
  try {
    & $luaPath (Join-Path $ProjectRoot 'tools/engine-trainer-integration.lua') `
      $fixtureRoot '0.1.38' ([string]$manifest.version)
    if ($LASTEXITCODE -ne 0) {
      throw 'Recomp 0.1.38 ROM-free fixture rejected the exact archive'
    }
  } finally {
    Pop-Location
  }
} finally {
  if (Test-Path -LiteralPath $fixtureRoot) {
    $resolvedFixture = (Resolve-Path -LiteralPath $fixtureRoot).Path
    $tempRoot = ([IO.Path]::GetFullPath(
      [IO.Path]::GetTempPath())).TrimEnd(
        [IO.Path]::DirectorySeparatorChar)
    if (-not $resolvedFixture.StartsWith(
        $tempRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) `
        -or -not ([IO.Path]::GetFileName($resolvedFixture)).StartsWith(
          'pokemon-randomizer-release-', [StringComparison]::Ordinal)) {
      throw 'Release fixture cleanup target mismatch'
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  }
}

$artifact = Get-Item -LiteralPath $OutputPath
$hash = Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256
Write-Output (
  'release: ok ({0}, SHA-256 {1})' -f $artifact.Name, $hash.Hash)
$artifact

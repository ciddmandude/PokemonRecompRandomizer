param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$requiredFiles = @(
  'manifest.json',
  'main.lua',
  'README.md',
  'src/constants.lua',
  'src/contracts.lua',
  'src/generator.lua',
  'src/bootstrap.lua',
  'src/uint32.lua',
  'src/seed.lua',
  'src/hash128.lua',
  'src/rng.lua',
  'src/stable_sort.lua',
  'tests/scaffold_test.lua',
  'tests/bootstrap_test.lua',
  'tests/foundation_test.lua',
  'tests/golden_vectors.lua',
  'tools/test.ps1',
  'docs/determinism-v1.md',
  'docs/randomizer-spec.md'
)

foreach ($relative in $requiredFiles) {
  $path = Join-Path $ProjectRoot $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing required file: $relative"
  }
}

$manifestPath = Join-Path $ProjectRoot 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 |
  ConvertFrom-Json

if ($manifest.id -ne 'pokemon_randomizer') {
  throw "manifest id must be pokemon_randomizer"
}
if ($manifest.api -ne 2) {
  throw "manifest api must be 2"
}
if ($manifest.game_version -ne '>=1.0.0 <2.0.0') {
  throw "unexpected game_version range"
}
if ($manifest.entry -ne 'main.lua') {
  throw "manifest entry must be main.lua"
}
if (@($manifest.permissions).Count -ne 0) {
  throw "milestone 1 must not request permissions"
}

$constants = Get-Content -LiteralPath (Join-Path $ProjectRoot 'src/constants.lua') `
  -Raw -Encoding UTF8
if ($manifest.version -ne '0.2.0') {
  throw "manifest version must be 0.2.0 for milestone 2"
}
if ($constants -notmatch 'MOD_VERSION\s*=\s*"0\.2\.0"') {
  throw "constants MOD_VERSION must match manifest version 0.2.0"
}
if ($constants -notmatch 'MOD_API\s*=\s*2') {
  throw "constants MOD_API must match manifest api 2"
}
if ($constants -notmatch 'GAME_VERSION_RANGE\s*=\s*">=1\.0\.0 <2\.0\.0"') {
  throw "constants GAME_VERSION_RANGE must match manifest"
}
if ($constants -notmatch 'HASH_VERSION\s*=\s*"fnv1a32x4-v1"') {
  throw "unexpected hash version"
}
if ($constants -notmatch 'PRNG_VERSION\s*=\s*"xoshiro128ss-v1"') {
  throw "unexpected PRNG version"
}

$milestones = @(
  Select-String -LiteralPath (Join-Path $ProjectRoot 'docs/randomizer-spec.md') `
    -Pattern '^(?:[1-9]|1[0-5])\. \*\*'
)
if ($milestones.Count -ne 15) {
  throw "spec must contain exactly 15 milestones"
}

Write-Output 'validate-scaffold: ok'

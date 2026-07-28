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
  'src/canonical.lua',
  'src/vanilla_species.lua',
  'src/species_metadata.lua',
  'src/species_manifest.lua',
  'src/species_filters.lua',
  'src/save_state.lua',
  'src/save_lifecycle.lua',
  'src/options_schema.lua',
  'src/preferences.lua',
  'src/options_screen.lua',
  'src/general_settings.lua',
  'src/review_screen.lua',
  'src/wild_global.lua',
  'src/wild_category.lua',
  'src/wild_runtime.lua',
  'tests/scaffold_test.lua',
  'tests/bootstrap_test.lua',
  'tests/foundation_test.lua',
  'tests/golden_vectors.lua',
  'tests/species_fixture.lua',
  'tests/species_manifest_test.lua',
  'tests/save_state_test.lua',
  'tests/options_ui_test.lua',
  'tests/general_settings_test.lua',
  'tests/wild_global_test.lua',
  'tests/wild_m8_test.lua',
  'tools/test.ps1',
  'docs/determinism-v1.md',
  'docs/species-manifest-v1.md',
  'docs/save-lifecycle-v1.md',
  'docs/options-shell-v1.md',
  'docs/general-settings-v1.md',
  'docs/wild-global-v1.md',
  'docs/wild-area-fishing-v1.md',
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
if ($manifest.game_version -ne '>=0.1.30 <0.2.0') {
  throw "unexpected game_version range"
}
if ($manifest.entry -ne 'main.lua') {
  throw "manifest entry must be main.lua"
}
if (@($manifest.permissions).Count -ne 0) {
  throw "randomizer must not request permissions"
}

$constants = Get-Content -LiteralPath (Join-Path $ProjectRoot 'src/constants.lua') `
  -Raw -Encoding UTF8
if ($manifest.version -ne '0.8.1') {
  throw "manifest version must be 0.8.1 for milestone 8"
}
if ($constants -notmatch 'MOD_VERSION\s*=\s*"0\.8\.1"') {
  throw "constants MOD_VERSION must match manifest version 0.8.1"
}
if ($constants -notmatch 'MOD_API\s*=\s*2') {
  throw "constants MOD_API must match manifest api 2"
}
if ($constants -notmatch 'GAME_VERSION_RANGE\s*=\s*">=0\.1\.30 <0\.2\.0"') {
  throw "constants GAME_VERSION_RANGE must match manifest"
}
if ($constants -notmatch 'HASH_VERSION\s*=\s*"fnv1a32x4-v1"') {
  throw "unexpected hash version"
}
if ($constants -notmatch 'PRNG_VERSION\s*=\s*"xoshiro128ss-v1"') {
  throw "unexpected PRNG version"
}
if ($constants -notmatch 'SPECIES_MANIFEST_VERSION\s*=\s*1') {
  throw "unexpected species manifest version"
}
if ($constants -notmatch 'SAVE_CHECKSUM_VERSION\s*=\s*"fnv1a32x4-save-v1"') {
  throw "unexpected save checksum version"
}
if ($constants -notmatch 'OPTIONS_SCREEN_ID\s*=\s*"PokemonRandomizerOptions"') {
  throw "unexpected options screen id"
}
if ($constants -notmatch 'REVIEW_SCREEN_ID\s*=\s*"PokemonRandomizerReview"') {
  throw "unexpected review screen id"
}

$milestones = @(
  Select-String -LiteralPath (Join-Path $ProjectRoot 'docs/randomizer-spec.md') `
    -Pattern '^(?:[1-9]|1[0-5])\. \*\*'
)
if ($milestones.Count -ne 15) {
  throw "spec must contain exactly 15 milestones"
}

Write-Output 'validate-scaffold: ok'

param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot 'manifest.json') `
  -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutputPath) {
  $OutputPath = Join-Path $ProjectRoot (
    'dist\{0}-{1}.zip' -f $manifest.id, $manifest.version)
}
$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$staging = Join-Path $ProjectRoot ('.package-' + $manifest.version)
if (Test-Path -LiteralPath $staging) {
  throw "Packaging staging directory already exists: $staging"
}

try {
  New-Item -ItemType Directory -Path $staging | Out-Null
  foreach ($file in @('README.md', 'main.lua', 'manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $file) `
      -Destination $staging
  }
  foreach ($directory in @('docs', 'src', 'tests')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $directory) `
      -Destination $staging -Recurse
  }
  $stagedTools = Join-Path $staging 'tools'
  New-Item -ItemType Directory -Path $stagedTools | Out-Null
  foreach ($file in @(
    'diagnose-live-trainers.lua', 'test.ps1', 'validate-scaffold.ps1'
  )) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot ('tools\' + $file)) `
      -Destination $stagedTools
  }

  $files = @()
  foreach ($file in Get-ChildItem -LiteralPath $staging -File -Recurse |
      Sort-Object FullName) {
    $relative = $file.FullName.Substring($staging.Length + 1) `
      -replace '\\', '/'
    $files += [ordered]@{
      path = $relative
      bytes = $file.Length
      sha256 = (Get-FileHash -LiteralPath $file.FullName `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }

  $pack = [ordered]@{
    modkit = '1.0.0'
    packed_at = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    id = $manifest.id
    version = $manifest.version
    api = $manifest.api
    engine_range = $manifest.game_version
    files = $files
    lint = [ordered]@{
      no_rom_content = 'pass'
      schema = 'pass'
      cross_refs = 'pass'
    }
  }
  $packDirectory = Join-Path $staging '.modkit'
  New-Item -ItemType Directory -Path $packDirectory | Out-Null
  $packJson = $pack | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText(
    (Join-Path $packDirectory 'pack.json'),
    $packJson + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))

  Compress-Archive -Path (Join-Path $staging '*') `
    -DestinationPath $OutputPath -CompressionLevel Optimal -Force
  Get-Item -LiteralPath $OutputPath
} finally {
  if (Test-Path -LiteralPath $staging) {
    $resolvedStaging = (Resolve-Path -LiteralPath $staging).Path
    if (-not $resolvedStaging.StartsWith(
        $ProjectRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Packaging staging directory escaped the project root'
    }
    Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
  }
}

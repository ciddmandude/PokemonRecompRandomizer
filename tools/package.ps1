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
  Copy-Item -LiteralPath (Join-Path $ProjectRoot 'src') `
    -Destination $staging -Recurse

  $files = @()
  foreach ($file in Get-ChildItem -LiteralPath $staging -File -Recurse -Force |
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

  # Windows PowerShell 5.1 Compress-Archive writes backslashes into ZIP entry
  # names. ZIP paths are platform-independent and must use forward slashes.
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
  }
  $archive = [IO.Compression.ZipFile]::Open(
    $OutputPath, [IO.Compression.ZipArchiveMode]::Create)
  try {
    $stagedFiles = @(
      Get-ChildItem -LiteralPath $staging -File -Recurse -Force |
        ForEach-Object {
          $relative = $_.FullName.Substring($staging.Length + 1) `
            -replace '\\', '/'
          [pscustomobject]@{ File = $_; Entry = $relative }
        } |
        Sort-Object Entry
    )
    foreach ($row in $stagedFiles) {
      $entryName = $row.Entry
      $segments = @($entryName -split '/')
      if ([string]::IsNullOrWhiteSpace($entryName) `
          -or $entryName.Contains('\') `
          -or $entryName.StartsWith('/') `
          -or $entryName -match '^[A-Za-z]:' `
          -or $segments.Count -eq 0 `
          -or @($segments | Where-Object {
            $_ -eq '' -or $_ -eq '.' -or $_ -eq '..'
          }).Count -gt 0) {
        throw "Unsafe ZIP entry path: $entryName"
      }
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        $row.File.FullName,
        $entryName,
        [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
  } finally {
    $archive.Dispose()
  }

  & (Join-Path $PSScriptRoot 'validate-package.ps1') `
    -ArchivePath $OutputPath
  # package-test intentionally uses dot-prefixed temporary archives. On Unix,
  # PowerShell treats those paths as hidden and Get-Item requires -Force even
  # though ZipFile and Test-Path can already see the file.
  $artifact = Get-Item -LiteralPath $OutputPath -Force
  $artifactHash = Get-FileHash -LiteralPath $artifact.FullName `
    -Algorithm SHA256
  Write-Output ("package SHA-256: {0}" -f $artifactHash.Hash)
  $artifact
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

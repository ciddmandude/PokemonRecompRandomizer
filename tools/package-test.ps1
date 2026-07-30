param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$dist = Join-Path $ProjectRoot 'dist'
if (-not (Test-Path -LiteralPath $dist)) {
  New-Item -ItemType Directory -Path $dist | Out-Null
}
$archives = @(
  Join-Path $dist (
    '.package-validation-' + [Guid]::NewGuid().ToString('N') + '.zip')
  Join-Path $dist (
    '.package-validation-' + [Guid]::NewGuid().ToString('N') + '.zip')
)

function Get-LedgerFilesJson {
  param([string]$ArchivePath)
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    $entry = $zip.GetEntry('.modkit/pack.json')
    if (-not $entry) { throw 'Package ledger is missing' }
    $stream = $entry.Open()
    try {
      $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
      try {
        $ledger = $reader.ReadToEnd() | ConvertFrom-Json
      } finally {
        $reader.Dispose()
      }
    } finally {
      $stream.Dispose()
    }
    return @($ledger.files) | ConvertTo-Json -Depth 8 -Compress
  } finally {
    $zip.Dispose()
  }
}

try {
  foreach ($archive in $archives) {
    & (Join-Path $PSScriptRoot 'package.ps1') `
      -ProjectRoot $ProjectRoot -OutputPath $archive | Out-Null
    & (Join-Path $PSScriptRoot 'validate-package.ps1') `
      -ArchivePath $archive | Out-Null
  }
  $firstFiles = Get-LedgerFilesJson $archives[0]
  $secondFiles = Get-LedgerFilesJson $archives[1]
  if ($firstFiles -cne $secondFiles) {
    throw 'Repeated packages have different payload paths or hashes'
  }
  Write-Output (
    'package-test: ok (hidden .modkit/pack.json ledger verified twice)')
} finally {
  foreach ($archive in $archives) {
    if (Test-Path -LiteralPath $archive) {
      $resolvedArchive = (Resolve-Path -LiteralPath $archive).Path
      $expectedArchive = [IO.Path]::GetFullPath($archive)
      if (-not $resolvedArchive.Equals(
          $expectedArchive, [StringComparison]::OrdinalIgnoreCase) `
          -or -not $resolvedArchive.StartsWith(
            $dist + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase) `
          -or -not ([IO.Path]::GetFileName($resolvedArchive)).StartsWith(
            '.package-validation-', [StringComparison]::Ordinal)) {
        throw 'Package-test cleanup target mismatch'
      }
      Remove-Item -LiteralPath $resolvedArchive -Force
    }
  }
}

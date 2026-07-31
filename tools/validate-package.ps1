param(
  [Parameter(Mandatory = $true)]
  [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'

$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-EntryText {
  param([IO.Compression.ZipArchiveEntry]$Entry)
  $stream = $Entry.Open()
  try {
    $reader = New-Object IO.StreamReader(
      $stream, [Text.Encoding]::UTF8, $true, 4096, $true)
    try {
      return $reader.ReadToEnd()
    } finally {
      $reader.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Get-EntrySha256 {
  param([IO.Compression.ZipArchiveEntry]$Entry)
  $stream = $Entry.Open()
  try {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
      $bytes = $sha.ComputeHash($stream)
      return ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
    } finally {
      $sha.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

$archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
  $entries = @($archive.Entries)
  if ($entries.Count -eq 0) {
    throw 'Package archive is empty'
  }

  $byName = @{}
  $caseFolded = @{}
  foreach ($entry in $entries) {
    $name = $entry.FullName
    $segments = @($name -split '/')
    if ([string]::IsNullOrWhiteSpace($name)) {
      throw 'Package contains an empty entry name'
    }
    if ($name.Contains('\')) {
      throw "Package entry uses a backslash: $name"
    }
    if ($name.StartsWith('/') -or $name -match '^[A-Za-z]:') {
      throw "Package entry is absolute: $name"
    }
    if (@($segments | Where-Object {
        $_ -eq '' -or $_ -eq '.' -or $_ -eq '..'
      }).Count -gt 0) {
      throw "Package entry has an unsafe path segment: $name"
    }
    if ($entry.Name -eq '') {
      throw "Package contains an unnecessary directory entry: $name"
    }
    if ($byName.ContainsKey($name)) {
      throw "Package contains a duplicate entry: $name"
    }
    $folded = $name.ToLowerInvariant()
    if ($caseFolded.ContainsKey($folded)) {
      throw "Package contains a case-colliding entry: $name"
    }
    $byName[$name] = $entry
    $caseFolded[$folded] = $true

    if ($name -ne '.modkit/pack.json' `
        -and $name -ne 'README.md' `
        -and $name -ne 'main.lua' `
        -and $name -ne 'manifest.json' `
        -and $name -notmatch '^src/[^/]+\.lua$') {
      throw "Package contains a development-only or unexpected entry: $name"
    }
  }

  foreach ($required in @(
      '.modkit/pack.json',
      'README.md',
      'main.lua',
      'manifest.json',
      'src/bootstrap.lua',
      'src/constants.lua',
      'src/generator.lua'
    )) {
    if (-not $byName.ContainsKey($required)) {
      throw "Package is missing required entry: $required"
    }
  }

  $manifest = Get-EntryText $byName['manifest.json'] | ConvertFrom-Json
  $ledger = Get-EntryText $byName['.modkit/pack.json'] | ConvertFrom-Json
  if ($ledger.id -ne $manifest.id `
      -or $ledger.version -ne $manifest.version `
      -or $ledger.api -ne $manifest.api) {
    throw 'Package ledger does not match the packaged manifest'
  }

  $ledgerFiles = @($ledger.files)
  if ($ledgerFiles.Count -ne $entries.Count - 1) {
    throw 'Package ledger file count does not match the archive'
  }
  $ledgerNames = @{}
  foreach ($row in $ledgerFiles) {
    $name = [string]$row.path
    if ($ledgerNames.ContainsKey($name)) {
      throw "Package ledger contains a duplicate path: $name"
    }
    $ledgerNames[$name] = $true
    if (-not $byName.ContainsKey($name)) {
      throw "Package ledger references a missing entry: $name"
    }
    $entry = $byName[$name]
    if ([long]$row.bytes -ne [long]$entry.Length) {
      throw "Package ledger byte count mismatch: $name"
    }
    $actualHash = Get-EntrySha256 $entry
    if ($actualHash -ne ([string]$row.sha256).ToLowerInvariant()) {
      throw "Package ledger SHA-256 mismatch: $name"
    }
  }
  foreach ($entry in $entries) {
    if ($entry.FullName -ne '.modkit/pack.json' `
        -and -not $ledgerNames.ContainsKey($entry.FullName)) {
      throw "Package entry is absent from the ledger: $($entry.FullName)"
    }
  }

  Write-Output (
    'validate-package: ok ({0} entries, forward-slash paths, ledger verified)' `
      -f $entries.Count)
} finally {
  $archive.Dispose()
}

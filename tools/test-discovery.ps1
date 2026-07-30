function Get-DiscoveredLuaTests {
  param(
    [string]$TestsRoot,
    [string[]]$CandidatePaths
  )

  if (-not $PSBoundParameters.ContainsKey('CandidatePaths')) {
    if (-not (Test-Path -LiteralPath $TestsRoot -PathType Container)) {
      throw "Lua test directory is missing: $TestsRoot"
    }
    $CandidatePaths = @(
      Get-ChildItem -LiteralPath $TestsRoot -File |
        Where-Object {
          $_.Name.EndsWith(
            '_test.lua', [StringComparison]::Ordinal)
        } |
        ForEach-Object { $_.FullName }
    )
  }

  $paths = [string[]]@($CandidatePaths)
  if ($paths.Count -eq 0) {
    throw 'No Lua tests were discovered'
  }
  [Array]::Sort($paths, [StringComparer]::Ordinal)

  $caseFolded = @{}
  foreach ($path in $paths) {
    $name = [IO.Path]::GetFileName($path)
    $folded = $name.ToLowerInvariant()
    if ($caseFolded.ContainsKey($folded)) {
      throw "Lua test paths collide under case-folding: " +
        "$($caseFolded[$folded]) and $name"
    }
    $caseFolded[$folded] = $name
  }
  return $paths
}

function Invoke-DiscoveredLuaTests {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LuaPath,
    [Parameter(Mandatory = $true)]
    [string[]]$TestPaths
  )

  foreach ($testPath in $TestPaths) {
    & $LuaPath $testPath
    if ($LASTEXITCODE -ne 0) {
      throw "Lua test failed: $([IO.Path]::GetFileName($testPath))"
    }
  }
}

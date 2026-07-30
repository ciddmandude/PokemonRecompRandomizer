param(
  [Parameter(Mandatory = $true)]
  [string]$LuaPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-discovery.ps1')

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$name = 'pokemon-randomizer-discovery-' + [Guid]::NewGuid().ToString('N')
$fixture = [IO.Path]::GetFullPath((Join-Path $tempBase $name))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
  $sentinel = Join-Path $fixture 'sentinel_test.lua'
  $helper = Join-Path $fixture 'sentinel_helper.lua'
  [IO.File]::WriteAllText($sentinel, @'
local file = assert(io.open("sentinel-ran.txt", "wb"))
file:write("ok")
file:close()
print("discovery_sentinel_test: ok")
'@, (New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($helper, 'error("helper must not run")',
    (New-Object Text.UTF8Encoding($false)))

  $found = @(Get-DiscoveredLuaTests -TestsRoot $fixture)
  if ($found.Count -ne 1 -or $found[0] -ne $sentinel) {
    throw 'Discovery did not select exactly the temporary sentinel test'
  }
  Push-Location $fixture
  try {
    Invoke-DiscoveredLuaTests -LuaPath $LuaPath -TestPaths $found
  } finally {
    Pop-Location
  }
  if (-not (Test-Path -LiteralPath (
      Join-Path $fixture 'sentinel-ran.txt') -PathType Leaf)) {
    throw 'Automatically discovered sentinel did not execute'
  }

  $failure = Join-Path $fixture 'failure_test.lua'
  [IO.File]::WriteAllText($failure, 'os.exit(7)',
    (New-Object Text.UTF8Encoding($false)))
  $nonzeroFailed = $false
  try {
    Invoke-DiscoveredLuaTests -LuaPath $LuaPath -TestPaths @($failure)
  } catch {
    $nonzeroFailed = $_.Exception.Message -like '*failure_test.lua*'
  }
  if (-not $nonzeroFailed) {
    throw 'Nonzero discovered test did not fail'
  }
  Remove-Item -LiteralPath $failure -Force

  $emptyFailed = $false
  try {
    Get-DiscoveredLuaTests -CandidatePaths @() | Out-Null
  } catch {
    $emptyFailed = $_.Exception.Message -like '*No Lua tests*'
  }
  if (-not $emptyFailed) {
    throw 'Empty discovery did not fail'
  }

  $collisionFailed = $false
  try {
    Get-DiscoveredLuaTests -CandidatePaths @(
      'Alpha_test.lua', 'alpha_test.lua') | Out-Null
  } catch {
    $collisionFailed =
      $_.Exception.Message -like '*collide under case-folding*'
  }
  if (-not $collisionFailed) {
    throw 'Case-folded discovery collision did not fail'
  }

  Write-Output 'test-discovery-self-test: ok'
} finally {
  if (Test-Path -LiteralPath $fixture) {
    $resolved = (Resolve-Path -LiteralPath $fixture).Path
    if (-not $resolved.StartsWith(
        $tempBase, [StringComparison]::OrdinalIgnoreCase) `
        -or -not ([IO.Path]::GetFileName($resolved)).StartsWith(
          'pokemon-randomizer-discovery-',
          [StringComparison]::Ordinal)) {
      throw 'Discovery self-test cleanup target mismatch'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}

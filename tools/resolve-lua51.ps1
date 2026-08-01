function Resolve-Lua51Executable {
  param([switch]$Compiler)

  $name = if ($Compiler) { 'luac' } else { 'lua' }
  $candidates = [Collections.Generic.List[string]]::new()
  if ($env:LOCALAPPDATA) {
    $bundled = Join-Path $env:LOCALAPPDATA (
      'Programs\Lua\5.1.5\{0}.exe' -f $name)
    if (Test-Path -LiteralPath $bundled) { $candidates.Add($bundled) }
  }
  $command = Get-Command $name -ErrorAction SilentlyContinue
  if ($command -and -not $candidates.Contains($command.Source)) {
    $candidates.Add($command.Source)
  }

  foreach ($candidate in $candidates) {
    try {
      $reported = if ($Compiler) {
        (& $candidate -v 2>&1 | Out-String).Trim()
      } else {
        (& $candidate -e 'io.write(_VERSION)' 2>&1 | Out-String).Trim()
      }
      if ($LASTEXITCODE -eq 0 -and $reported -match '^Lua 5\.1(?:\.|$)') {
        return $candidate
      }
    } catch {
      # Continue through the candidates; the caller receives one clear error.
    }
  }

  throw "Lua 5.1 $name is required"
}

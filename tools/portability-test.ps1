param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'validate-scaffold.ps1'
& $validator -ProjectRoot $ProjectRoot `
  -GitIgnoreContentOverride "/dist/*.zip`n" | Out-Null
& $validator -ProjectRoot $ProjectRoot `
  -GitIgnoreContentOverride "/dist/*.zip`r`n" | Out-Null
Write-Output 'portability-test: ok (LF and CRLF .gitignore)'

param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Get-RelativePath([string]$BasePath, [string]$FullPath) {
  $base = [System.Uri]((Resolve-Path $BasePath).Path.TrimEnd('\') + '\')
  $full = [System.Uri]((Resolve-Path $FullPath).Path)
  return $base.MakeRelativeUri($full).ToString().Replace('\','/')
}

$luaRoot = Join-Path $RepoRoot "igs-core\lua"
if (!(Test-Path -LiteralPath $luaRoot)) {
  throw "Lua root not found: $luaRoot"
}

# Build superfile mount: key = path relative to igs-core/lua, value = file contents
$mount = [ordered]@{}

$files = Get-ChildItem -LiteralPath $luaRoot -Recurse -File -Filter "*.lua" |
  Sort-Object FullName

foreach ($f in $files) {
  $rel = Get-RelativePath $luaRoot $f.FullName

  # Normalize newlines to LF so JSON escapes are consistent (\n)
  $content = Get-Content -LiteralPath $f.FullName -Raw
  $content = $content -replace "`r`n", "`n"
  $content = $content -replace "`r", "`n"

  $mount[$rel] = $content
}

$json = $mount | ConvertTo-Json -Depth 3

# Make it one line like upstream superfile.json
$json = $json -replace "\r?\n\s*", ""

$out1 = Join-Path $RepoRoot "superfile.json"
$out2 = Join-Path $RepoRoot "igs-core\superfile.json"

Set-Content -LiteralPath $out1 -Value $json -NoNewline -Encoding UTF8
Set-Content -LiteralPath $out2 -Value $json -NoNewline -Encoding UTF8

Write-Host "Generated:"
Write-Host " - $out1"
Write-Host " - $out2"


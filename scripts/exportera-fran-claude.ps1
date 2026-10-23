<#
  Körs på laptopen. Kopierar dina Claude-skills, regler (CLAUDE.md) och
  Data Academy-skills in i valvet och pushar. Speldatorn hämtar dem
  automatiskt nästa gång kollegan startar.

  Kör:  powershell -ExecutionPolicy Bypass -File .\scripts\exportera-fran-claude.ps1
#>
param(
  [string]$Valv = "$env:USERPROFILE\Documents\GitHub\ai-valv",
  [switch]$IngenPush
)
$ErrorActionPreference = 'Stop'
$Claude = "$env:USERPROFILE\.claude"
$Mal = Join-Path $Valv 'skills'
$MaxBytes = 1MB
# Anthropics inbyggda skills får bara användas i Claude, så de följer inte med.
$Inbyggda = 'docx','pdf','pptx','xlsx','docs','built-in-browser','chrome-browser','computer-use','google-workspace','import-memory','morning','learn','deep-research','design-director','skill-creator'

if (-not (Test-Path $Valv)) { throw "Hittar inte valvet: $Valv" }

function Kopiera($fran, $till) {
  if (-not (Test-Path (Join-Path $fran 'SKILL.md'))) { return }
  if (Test-Path $till) { Remove-Item $till -Recurse -Force }
  New-Item -ItemType Directory -Force $till | Out-Null
  Get-ChildItem $fran -Recurse -File |
    Where-Object { $_.Length -le $MaxBytes -and $_.Name -notmatch '^\.env|\.key$|\.pem$|id_rsa|id_ed25519' -and $_.FullName -notmatch '\\(node_modules|\.git|__pycache__)\\' } |
    ForEach-Object {
      $rel = $_.FullName.Substring($fran.Length).TrimStart('\')
      $dest = Join-Path $till $rel
      New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
      Copy-Item $_.FullName $dest
    }
  $script:antal++
}
$antal = 0

# 1. Egna skills i ~/.claude/skills
Get-ChildItem "$Claude\skills" -Directory | Where-Object Name -ne 'synced' | ForEach-Object {
  Kopiera $_.FullName (Join-Path $Mal "claude\$($_.Name)")
}
# 2. Kontoskills som synkats från claude.ai (utom Anthropics inbyggda)
Get-ChildItem "$Claude\skills\synced" -Recurse -Filter SKILL.md -ErrorAction SilentlyContinue |
  Where-Object { $Inbyggda -notcontains $_.Directory.Name } |
  ForEach-Object { Kopiera $_.Directory.FullName (Join-Path $Mal "konto\$($_.Directory.Name)") }
# 3. Utvecklingsskills från pluginet superpowers (MIT)
$sp = Get-ChildItem "$Claude\plugins\cache\claude-plugins-official\superpowers" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($sp) { Get-ChildItem "$($sp.FullName)\skills" -Directory | ForEach-Object { Kopiera $_.FullName (Join-Path $Mal "utveckling\$($_.Name)") } }
# 4. Data Academy (30 skills)
$da = "$env:USERPROFILE\Documents\GitHub\claude-data-academy\skills"
if (Test-Path $da) { Get-ChildItem $da -Directory | ForEach-Object { Kopiera $_.FullName (Join-Path $Mal "data-academy\$($_.Name)") } }
# 5. Regler
New-Item -ItemType Directory -Force "$Valv\regler" | Out-Null
if (Test-Path "$Claude\CLAUDE.md") { Copy-Item "$Claude\CLAUDE.md" "$Valv\regler\CLAUDE.md" -Force }

Write-Host "$antal skills exporterade till $Mal" -ForegroundColor Green

if (-not $IngenPush) {
  git -C $Valv add -A
  if (git -C $Valv status --porcelain) {
    git -C $Valv commit -q -m "Exportera skills och regler från Claude ($(Get-Date -Format 'yyyy-MM-dd'))"
    git -C $Valv push -q
    Write-Host 'Pushat till ai-valv.' -ForegroundColor Green
  } else { Write-Host 'Inga ändringar att pusha.' }
}

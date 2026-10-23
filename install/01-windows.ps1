<#
  trygg-ai-kollega, steg 1 av 2: körs på speldatorn i PowerShell som administratör.

  Gör en egen, avskild WSL-dator ("hermes") åt kollegan, slår på brandväggen
  och installerar Tailscale. Varje steg frågar först. Inget körs tyst.

  Kör:  powershell -ExecutionPolicy Bypass -File .\install\01-windows.ps1
#>
$ErrorActionPreference = 'Stop'
$Distro = 'hermes'

function Fraga($text) {
  $svar = Read-Host "$text [j/N]"
  return $svar -match '^(j|ja|y|yes)$'
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Starta PowerShell som administratör och kör skriptet igen.' -ForegroundColor Yellow
  exit 1
}

Write-Host "`n== 1. Brandvägg ==" -ForegroundColor Cyan
$av = Get-NetFirewallProfile | Where-Object { -not $_.Enabled }
if ($av) {
  Write-Host ("Brandväggen är AV för: " + ($av.Name -join ', ')) -ForegroundColor Yellow
  if (Fraga 'Slå på brandväggen för alla profiler?') { Set-NetFirewallProfile -All -Enabled True; Write-Host 'Brandväggen är på.' }
} else { Write-Host 'Brandväggen är redan på för alla profiler.' }

Write-Host "`n== 2. Nvidia-drivrutin (GPU i WSL) ==" -ForegroundColor Cyan
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($smi) { & nvidia-smi --query-gpu=name,memory.total,power.limit --format=csv }
else { Write-Host 'nvidia-smi hittades inte. Installera senaste Nvidia-drivrutinen först (GeForce Experience eller nvidia.com).' -ForegroundColor Yellow }

Write-Host "`n== 3. Egen WSL-dator: $Distro ==" -ForegroundColor Cyan
$finns = (wsl -l -q 2>$null) -replace "`0", '' | Where-Object { $_.Trim() -eq $Distro }
if ($finns) { Write-Host "WSL-datorn '$Distro' finns redan." }
elseif (Fraga "Skapa en ny Ubuntu 24.04 som heter '$Distro'? (påverkar inte dina andra WSL-installationer)") {
  wsl --update
  wsl --install -d Ubuntu-24.04 --name $Distro
  Write-Host "Välj ett användarnamn och lösenord för Linux när du blir tillfrågad. Använd INTE samma lösenord som till Windows." -ForegroundColor Yellow
}

Write-Host "`n== 4. Tailscale ==" -ForegroundColor Cyan
if (Get-Command tailscale -ErrorAction SilentlyContinue) { Write-Host 'Tailscale finns redan.' }
elseif (Fraga 'Installera Tailscale via winget?') {
  winget install --id Tailscale.Tailscale -e --accept-source-agreements
  Write-Host 'Logga in i Tailscale-appen själv. Lägg sedan till din laptop och mobil i samma tailnet.' -ForegroundColor Yellow
}

Write-Host "`n== 5. GPU-effektgräns (valfritt, skonar kortet) ==" -ForegroundColor Cyan
Write-Host 'RTX 3060 drar ~170 W. 70 % (~120 W) ger nästan samma fart för språkmodeller men mindre värme.'
if ($smi -and (Fraga 'Sätt effektgräns 120 W nu? (nollställs vid omstart)')) { & nvidia-smi -pl 120 }
Write-Host 'Permanent gräns: använd MSI Afterburner (Power Limit 70 %) i stället.'

Write-Host "`nKlart med Windows-delen. Nästa steg:" -ForegroundColor Green
Write-Host "  wsl -d $Distro"
Write-Host '  git clone https://github.com/andersvlindberg/trygg-ai-kollega.git && cd trygg-ai-kollega && bash install/02-wsl.sh'

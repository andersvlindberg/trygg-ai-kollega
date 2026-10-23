<#
  Spelläge: stänger av kollegan helt så grafikkortet och minnet blir lediga.
  Valvet är redan sparat i Git, så inget arbete försvinner.
  Starta igen:  wsl -d hermes   och sedan   bash ~/trygg-ai-kollega/scripts/starta.sh
#>
wsl --terminate hermes
Write-Host 'Kollegan är pausad. GPU och RAM är lediga för spel.' -ForegroundColor Green

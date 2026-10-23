---
name: lamna-taktpinnen
description: Skriv en överlämning till valvet så att nästa AI (Claude eller Hermes) kan fortsätta exakt där arbetet slutade. Använd när ett arbetspass tar slut, när tokens håller på att ta slut, eller när Anders säger "lämna över", "taktpinnen" eller "spara läget".
version: 1.0.0
metadata:
  hermes:
    tags: [handoff, minne, valv]
---

# Lämna taktpinnen

Målet är att nästa AI ska kunna fortsätta utan att Anders behöver förklara något igen.

## Steg

1. **Samla läget.** Gå igenom arbetspasset och ta fram:
   - vad Anders ville (med hans egna ord om möjligt)
   - vad som är klart, med sökvägar eller länkar
   - vad som pågår och exakt nästa steg
   - beslut som tagits och varför
   - öppna frågor till Anders
   - uppgifter som är för svåra för Hermes och bör vänta på Claude
2. **Skriv `00-start/HANDOFF.md`** i valvet (`~/ai-valv` hos Hermes, `Documents\GitHub\ai-valv` på laptopen). Skriv över filen, men flytta först den gamla versionens innehåll till `logg/AAAA-MM-DD-HHMM.md` så historiken finns kvar. Använd mallen nedan.
3. **Uppdatera minnet** om Anders sagt något varaktigt nytt (mål, preferens, projektbeslut). Lägg det i rätt fil under `minne/` eller `projekt/`, en rad per fakta. Skriv aldrig in lösenord, nycklar, kort- eller personnummer.
4. **Committa och pusha** valvet med meddelandet `Handoff: <en rad om läget>`. Fråga Anders först om du inte redan har fått ja i passet.
5. **Säg till Anders** i en mening att taktpinnen är lämnad och vad nästa steg är.

## Mall för HANDOFF.md

```markdown
# Handoff
Senast uppdaterad: AAAA-MM-DD HH:MM av <Claude|Hermes>

## Mål
<vad Anders vill uppnå just nu>

## Klart
- <sak> → <sökväg/länk>

## Pågår, nästa steg
1. <exakt nästa steg>

## Beslut
- <beslut> (varför)

## Frågor till Anders
- <fråga>

## Till Claude (för svårt för Hermes)
- <uppgift>

## Filer som berörs
- <sökväg>
```

## Om du inte kommer åt valvet
Skriv innehållet i chatten som ett kodblock med rubriken `HANDOFF.md` och be Anders spara det i `ai-valv/00-start/`.

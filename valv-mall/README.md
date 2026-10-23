# ai-valv (mall)

Delat minne för Claude och din självhostade kollega (Hermes). Öppna mappen som ett valv i Obsidian, så kan du läsa och redigera allt själv.

**Gör valvet PRIVAT på GitHub.** Det innehåller anteckningar om dig och dina projekt.

| Mapp | Innehåll |
|---|---|
| `00-start/LÄS-FÖRST.md` | Vem du är och hur du vill ha det. Läses först av båda AI:erna. |
| `00-start/HANDOFF.md` | Var arbetet står just nu. Skrivs av skillen `lamna-taktpinnen`. |
| `minne/` | Varaktiga fakta, en fil per ämne, en rad per fakta |
| `projekt/` | En fil per projekt: mål, status, beslut, länkar |
| `logg/` | Gamla handoffs, en fil per överlämning |
| `skills/` | Exporterade skills (fylls av `exportera-fran-claude.ps1`) |
| `regler/` | Dina regler, till exempel CLAUDE.md |

Skriv aldrig lösenord, nycklar, kort- eller personnummer här. `audit.py` letar efter sådant och larmar.

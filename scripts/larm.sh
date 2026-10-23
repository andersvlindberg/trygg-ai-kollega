#!/usr/bin/env bash
# Bevakar kollegans loggar och skickar push-larm till mobilen (ntfy) direkt
# när något misstänkt händer: okänd avsändare, blockerat kommando,
# blockerad fil (möjlig prompt injection), skill i karantän.
# Startas av scripts/starta.sh. Kan också köras själv: bash scripts/larm.sh
set -uo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
LOGG="${LOGG:-$HERMES_HOME/kollega-gateway.log}"
TOPIC="$(grep -s '^NTFY_TOPIC=' "$HERMES_HOME/.env" | cut -d= -f2)"
MONSTER='unauthori[sz]ed|not allowed|pairing request|\[BLOCKED|blocked|denied|quarantin|dangerous|injection|hardline|ssrf|private url'

skicka() {
  [ -n "$TOPIC" ] || { echo "LARM (ingen NTFY_TOPIC): $1"; return; }
  curl -fsS -m 10 -H "Title: Kollegan: något misstänkt" -H "Priority: high" -H "Tags: rotating_light" \
       -d "$1" "https://ntfy.sh/$TOPIC" >/dev/null || echo "Kunde inte skicka larm: $1"
}

touch "$LOGG"
echo "Bevakar $LOGG (larm till ntfy-ämnet ${TOPIC:+som finns i .env})"
senast=0
tail -n0 -F "$LOGG" 2>/dev/null | while IFS= read -r rad; do
  if echo "$rad" | grep -Eiq "$MONSTER"; then
    nu=$(date +%s)
    # max ett larm per 30 sekunder så mobilen inte spammas
    if (( nu - senast >= 30 )); then
      skicka "$(echo "$rad" | cut -c1-300)"
      senast=$nu
    fi
  fi
done

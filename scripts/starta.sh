#!/usr/bin/env bash
# Startar kollegan i tmux: hämtar senaste valvet, kör säkerhetskontrollen,
# startar Telegram-gatewayen och larmbevakningen.
#   bash scripts/starta.sh        starta
#   tmux attach -t kollega        titta in (lämna med Ctrl+B, D)
#   tmux kill-session -t kollega  stoppa
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
VALV_DIR="$HOME/ai-valv"

if tmux has-session -t kollega 2>/dev/null; then
  echo "Kollegan kör redan. Titta in med: tmux attach -t kollega"; exit 0
fi

if [ -d "$VALV_DIR/.git" ]; then
  echo "Hämtar senaste valvet (minne, skills, HANDOFF.md)…"
  git -C "$VALV_DIR" pull --ff-only --quiet || echo "Kunde inte hämta valvet. Fortsätter med lokal kopia."
fi

echo "Säkerhetskontroll…"
if ! python3 "$REPO_DIR/scripts/audit.py" --larm; then
  read -r -p "Kontrollen har röda punkter. Starta ändå? [j/N] " s
  [[ "$s" =~ ^(j|ja)$ ]] || exit 1
fi

curl -fsS -m 3 http://127.0.0.1:11434/api/tags >/dev/null || echo "OBS: Ollama svarar inte. Starta med: sudo systemctl start ollama"

tmux new-session -d -s kollega -n gateway "cd '$VALV_DIR' 2>/dev/null || cd ~; hermes gateway 2>&1 | tee -a '$HERMES_HOME/kollega-gateway.log'"
tmux new-window -t kollega -n larm "bash '$REPO_DIR/scripts/larm.sh'"
echo "Kollegan är igång och svarar bara dig på Telegram. Titta in: tmux attach -t kollega"

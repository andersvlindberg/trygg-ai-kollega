#!/usr/bin/env bash
# trygg-ai-kollega, steg 2 av 2: körs inne i WSL-datorn "hermes".
# Installerar Ollama och Hermes, härdar allt och kopplar in valvet.
# Varje steg frågar först.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
VALV_DIR="$HOME/ai-valv"
VALV_REPO="${VALV_REPO:-git@github.com:andersvlindberg/ai-valv.git}"
MODELL="${MODELL:-hermes3:8b}"

blue() { printf '\n\033[36m== %s ==\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
fraga() { local s; read -r -p "$1 [j/N] " s; [[ "$s" =~ ^(j|ja|y|yes)$ ]]; }

blue "1. Stäng dörren till Windows"
if grep -q '^\[automount\]' /etc/wsl.conf 2>/dev/null && grep -q '^enabled *= *false' /etc/wsl.conf; then
  echo "wsl.conf är redan härdad."
elif fraga "Ta bort åtkomsten till Windows-diskarna och Windows-program från den här WSL-datorn?"; then
  sudo tee /etc/wsl.conf >/dev/null <<'EOF'
# trygg-ai-kollega: kollegan ska inte se eller starta något på Windows-sidan.
[boot]
systemd=true

[automount]
enabled=false
mountFsTab=false

[interop]
enabled=false
appendWindowsPath=false
EOF
  warn "Klart. Gäller efter omstart: kör 'wsl --terminate hermes' i PowerShell och öppna WSL igen."
fi

blue "2. Grundpaket"
if fraga "Installera git, curl, tmux och python3-yaml med apt?"; then
  sudo apt-get update -y
  sudo apt-get install -y git curl tmux python3 python3-yaml ca-certificates iproute2
fi

blue "3. Ollama (lokal modell på grafikkortet)"
if ! command -v ollama >/dev/null && fraga "Installera Ollama?"; then
  tmp="$(mktemp)"; curl -fsSL https://ollama.com/install.sh -o "$tmp"
  echo "Installationsskriptet ligger i $tmp ($(sha256sum "$tmp" | cut -c1-16)…). Läs det gärna först."
  fraga "Kör Ollamas installationsskript?" && sh "$tmp"
fi
if command -v systemctl >/dev/null && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  sudo mkdir -p /etc/systemd/system/ollama.service.d
  sudo tee /etc/systemd/system/ollama.service.d/trygg.conf >/dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_KEEP_ALIVE=10m"
EOF
  sudo systemctl daemon-reload && sudo systemctl restart ollama || true
  echo "Ollama lyssnar bara på 127.0.0.1, har 32K kontext och släpper grafikkortet efter 10 min utan jobb."
fi
if command -v ollama >/dev/null && fraga "Ladda ner modellen $MODELL (~5 GB)?"; then
  ollama pull "$MODELL"
fi

blue "4. Hermes Agent"
if ! command -v hermes >/dev/null && fraga "Installera Hermes Agent med det officiella skriptet?"; then
  tmp="$(mktemp)"; curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$tmp"
  echo "Installationsskriptet ligger i $tmp ($(sha256sum "$tmp" | cut -c1-16)…)."
  fraga "Kör Hermes installationsskript?" && bash "$tmp"
  # shellcheck disable=SC1090
  [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" || true
fi

blue "5. Härdade inställningar"
mkdir -p "$HERMES_HOME"; chmod 700 "$HERMES_HOME"
python3 "$REPO_DIR/scripts/merge_config.py" "$REPO_DIR/config/hardening.yaml" "$HERMES_HOME/config.yaml"
if [ -f "$HERMES_HOME/SOUL.md" ] && ! cmp -s "$REPO_DIR/config/SOUL.md" "$HERMES_HOME/SOUL.md"; then
  cp "$HERMES_HOME/SOUL.md" "$HERMES_HOME/SOUL.md.bak"; warn "Gammal SOUL.md sparad som SOUL.md.bak."
fi
cp "$REPO_DIR/config/SOUL.md" "$HERMES_HOME/SOUL.md"

blue "6. Hemligheter (.env)"
ENV="$HERMES_HOME/.env"
[ -f "$ENV" ] || cp "$REPO_DIR/config/env.example" "$ENV"
chmod 600 "$ENV"
satt() { grep -q "^$1=" "$ENV" && sed -i "s|^$1=.*|$1=$2|" "$ENV" || echo "$1=$2" >> "$ENV"; }
if ! grep -q '^TELEGRAM_BOT_TOKEN=.\+' "$ENV" && fraga "Lägga in Telegram-uppgifterna nu?"; then
  read -r -s -p "Bot-token från @BotFather (syns inte när du skriver): " tok; echo
  read -r -p "Ditt numeriska Telegram-ID (från @userinfobot): " uid
  [[ "$uid" =~ ^[0-9]+$ ]] || { warn "ID:t ska bara vara siffror. Hoppar över."; uid=""; }
  [ -n "$tok" ] && satt TELEGRAM_BOT_TOKEN "$tok"
  [ -n "$uid" ] && satt TELEGRAM_ALLOWED_USERS "$uid"
fi
satt GATEWAY_ALLOW_ALL_USERS false
if ! grep -q '^NTFY_TOPIC=.\+' "$ENV"; then
  satt NTFY_TOPIC "kollega-$(head -c 18 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 22)"
  echo "Larmämne skapat. Prenumerera i ntfy-appen på: $(grep '^NTFY_TOPIC=' "$ENV" | cut -d= -f2)"
fi

blue "7. Valvet (delat minne med Claude)"
if [ ! -d "$VALV_DIR/.git" ] && fraga "Koppla in ditt privata valv-repo med en egen nyckel som BARA gäller det repot?"; then
  mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
  KEY="$HOME/.ssh/ai_valv"
  [ -f "$KEY" ] || ssh-keygen -t ed25519 -N "" -C "hermes-ai-valv" -f "$KEY" >/dev/null
  cat > "$HOME/.ssh/config" <<EOF
Host github.com
  IdentityFile $KEY
  IdentitiesOnly yes
EOF
  chmod 600 "$HOME/.ssh/config"
  echo; echo "Lägg till den här nyckeln som Deploy key (Allow write access) på"
  echo "https://github.com/andersvlindberg/ai-valv/settings/keys/new :"; echo
  cat "$KEY.pub"; echo
  read -r -p "Tryck Enter när nyckeln är tillagd… " _
  git clone "$VALV_REPO" "$VALV_DIR"
fi
[ -d "$VALV_DIR" ] && git -C "$VALV_DIR" config user.name "Hermes (kollegan)" && git -C "$VALV_DIR" config user.email "hermes@localhost"

blue "8. Kontroll"
python3 "$REPO_DIR/scripts/audit.py" || true

cat <<EOF

Klart. Så här använder du kollegan:
  Starta:        bash $REPO_DIR/scripts/starta.sh
  Kontrollera:   python3 $REPO_DIR/scripts/audit.py
  Pausa (spel):  kör pausa-kollegan.ps1 i Windows, eller 'wsl --terminate hermes'
EOF

#!/usr/bin/env python3
"""Säkerhetskontroll för trygg-ai-kollega.

Läser bara, ändrar inget. Kör den efter installation, efter uppdateringar
och gärna varje vecka. Avslutar med kod 1 om något är RÖTT.

  python3 scripts/audit.py            # vanlig kontroll
  python3 scripts/audit.py --larm     # skicka push-larm om något är rött
"""
import os
import re
import shutil
import stat
import subprocess
import sys
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Saknar python3-yaml: sudo apt-get install -y python3-yaml")

REPO = Path(__file__).resolve().parent.parent
HOME = Path.home()
HERMES = Path(os.environ.get("HERMES_HOME", HOME / ".hermes"))
VALV = Path(os.environ.get("VALV_DIR", HOME / "ai-valv"))
WSL_CONF = Path(os.environ.get("WSL_CONF", "/etc/wsl.conf"))

results = []  # (nivå, text)


def ok(t): results.append(("OK", t))
def gul(t): results.append(("GUL", t))
def rod(t): results.append(("RÖD", t))


def get(d, dotted):
    for part in dotted.split("."):
        if not isinstance(d, dict) or part not in d:
            return None
        d = d[part]
    return d


def flatten(d, prefix=""):
    for k, v in d.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            yield from flatten(v, key + ".")
        else:
            yield key, v


def read_env(path):
    env = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env


def mode(path):
    return stat.S_IMODE(path.stat().st_mode)


def check_permissions():
    if not HERMES.exists():
        rod(f"{HERMES} finns inte. Är Hermes installerat?")
        return
    if mode(HERMES) & 0o077:
        rod(f"{HERMES} kan läsas av andra (rättigheter {oct(mode(HERMES))}). Kör: chmod 700 {HERMES}")
    else:
        ok("Hermes-mappen är privat (700).")
    for name in (".env", "config.yaml"):
        p = HERMES / name
        if p.exists() and mode(p) & 0o077:
            rod(f"{p} kan läsas av andra. Kör: chmod 600 {p}")
        elif p.exists():
            ok(f"{name} är privat (600).")


def check_config():
    cfg_path = HERMES / "config.yaml"
    if not cfg_path.exists():
        rod("config.yaml saknas. Kör install/02-wsl.sh.")
        return
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    hard = yaml.safe_load((REPO / "config" / "hardening.yaml").read_text(encoding="utf-8"))
    skip = {"model.default", "compression.enabled", "compression.threshold", "compression.target_ratio", "skills.external_dirs"}
    avvik = []
    for key, want in flatten(hard):
        if key in skip:
            continue
        have = get(cfg, key)
        if isinstance(want, list):
            if not isinstance(have, list) or not set(want) <= set(have):
                avvik.append(f"{key} saknar värden")
        elif have != want:
            avvik.append(f"{key} = {have!r} (ska vara {want!r})")
    if avvik:
        for a in avvik:
            rod(f"Inställning ändrad: {a}")
    else:
        ok("Alla härdade inställningar gäller (godkännanden, minne, skills, nätverk).")
    url = str(get(cfg, "model.base_url") or "")
    if url and not re.match(r"https?://(127\.0\.0\.1|localhost)[:/]", url) and get(cfg, "model.provider") == "custom":
        gul(f"Modellen nås via {url}, inte localhost. Är det meningen?")


def check_env():
    env = read_env(HERMES / ".env")
    if os.environ.get("HERMES_YOLO_MODE") or env.get("HERMES_YOLO_MODE"):
        rod("HERMES_YOLO_MODE är satt. Då frågar kollegan inte innan farliga kommandon.")
    if str(env.get("GATEWAY_ALLOW_ALL_USERS", "false")).lower() == "true":
        rod("GATEWAY_ALLOW_ALL_USERS=true. Vem som helst kan skriva till kollegan.")
    allow = [k for k in env if k.endswith("_ALLOW_ALL_USERS") and k != "GATEWAY_ALLOW_ALL_USERS" and env[k].lower() == "true"]
    for k in allow:
        rod(f"{k}=true släpper in alla på den plattformen.")
    users = env.get("TELEGRAM_ALLOWED_USERS", "")
    if env.get("TELEGRAM_BOT_TOKEN") and not users:
        rod("Telegram-bot finns men TELEGRAM_ALLOWED_USERS är tom.")
    elif users:
        ids = [u for u in re.split(r"[,\s]+", users) if u]
        if len(ids) > 1:
            gul(f"{len(ids)} Telegram-ID:n har åtkomst. Ska det bara vara du?")
        elif not all(i.isdigit() for i in ids):
            rod("TELEGRAM_ALLOWED_USERS ska vara numeriska ID:n, inte namn.")
        else:
            ok("Bara ett Telegram-ID får prata med kollegan.")
    if not env.get("NTFY_TOPIC"):
        gul("NTFY_TOPIC saknas, så inga larm kan skickas till mobilen.")


def check_wsl():
    if not WSL_CONF.exists():
        gul("Ingen /etc/wsl.conf. Kör steg 1 i install/02-wsl.sh.")
        return
    text = WSL_CONF.read_text(encoding="utf-8")
    sec = {}
    current = None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("["):
            current = line.strip("[]").lower()
        elif "=" in line and current:
            k, v = line.split("=", 1)
            sec[f"{current}.{k.strip()}"] = v.strip().lower()
    if sec.get("automount.enabled") == "false":
        ok("Windows-diskarna är inte monterade i WSL.")
    else:
        rod("Kollegan kan läsa dina Windows-filer (/mnt/c). Sätt [automount] enabled=false.")
    if sec.get("interop.enabled") == "false":
        ok("Kollegan kan inte starta Windows-program.")
    else:
        rod("Kollegan kan starta Windows-program. Sätt [interop] enabled=false.")
    if Path("/mnt/c/Windows").exists():
        gul("/mnt/c syns fortfarande. Starta om WSL: wsl --terminate hermes")


def check_ports():
    if not shutil.which("ss"):
        gul("Kommandot 'ss' saknas, kan inte kontrollera öppna portar.")
        return
    out = subprocess.run(["ss", "-ltnH"], capture_output=True, text=True).stdout
    open_ = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            local = parts[3]
            host = local.rsplit(":", 1)[0]
            if host in ("0.0.0.0", "*", "[::]", "::"):
                open_.append(local)
    if open_:
        rod("Något lyssnar på alla nätverk: " + ", ".join(open_) + ". Bind till 127.0.0.1.")
    else:
        ok("Inget lyssnar utåt. Allt är bundet till localhost.")


SECRET_PATTERNS = {
    "API-nyckel (sk-)": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    "GitHub-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}"),
    "Telegram-bottoken": re.compile(r"\b\d{8,10}:[A-Za-z0-9_-]{35}\b"),
    "Privat nyckel": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "Lösenord i klartext": re.compile(r"(?i)\b(lösenord|password|passwd)\s*[:=]\s*\S{4,}"),
    "Personnummer": re.compile(r"\b(19|20)?\d{6}[-+]\d{4}\b"),
}


def luhn(num):
    digits = [int(c) for c in num][::-1]
    total = sum(d if i % 2 == 0 else (d * 2 - 9 if d * 2 > 9 else d * 2) for i, d in enumerate(digits))
    return total % 10 == 0


def check_vault():
    if not VALV.exists():
        gul(f"Valvet {VALV} finns inte än.")
        return
    hits = []
    card = re.compile(r"\b(?:\d[ -]?){13,19}\b")
    for p in VALV.rglob("*"):
        if ".git" in p.parts or not p.is_file() or p.stat().st_size > 2_000_000:
            continue
        if p.suffix.lower() not in {".md", ".txt", ".json", ".yaml", ".yml", ".env", ".sh", ".py", ".ps1", ".csv"}:
            continue
        text = p.read_text(encoding="utf-8", errors="ignore")
        for name, pat in SECRET_PATTERNS.items():
            if pat.search(text):
                hits.append(f"{name} i {p.relative_to(VALV)}")
        for m in card.finditer(text):
            d = re.sub(r"\D", "", m.group())
            if 13 <= len(d) <= 19 and luhn(d):
                hits.append(f"Möjligt kortnummer i {p.relative_to(VALV)}")
                break
    if hits:
        for h in sorted(set(hits)):
            rod(f"Hemlighet i valvet: {h}")
    else:
        ok("Inga lösenord, nycklar, kortnummer eller personnummer hittades i valvet.")


def check_hermes_tools():
    if not shutil.which("hermes"):
        gul("Kommandot 'hermes' hittades inte i PATH.")
        return
    r = subprocess.run(["hermes", "skills", "audit"], capture_output=True, text=True, timeout=300)
    text = (r.stdout + r.stderr).lower()
    if r.returncode != 0 or "dangerous" in text:
        rod("hermes skills audit hittade problem. Kör kommandot och läs utskriften.")
    else:
        ok("hermes skills audit: inga farliga skills.")


def larm(text):
    topic = read_env(HERMES / ".env").get("NTFY_TOPIC")
    if not topic:
        return
    req = urllib.request.Request(f"https://ntfy.sh/{topic}", data=text.encode("utf-8"),
                                 headers={"Title": "Kollegan: säkerhetskontroll", "Priority": "high", "Tags": "warning"})
    try:
        urllib.request.urlopen(req, timeout=10)
    except OSError as e:
        print(f"Kunde inte skicka larm: {e}")


def main():
    for check in (check_permissions, check_config, check_env, check_wsl, check_ports, check_vault, check_hermes_tools):
        try:
            check()
        except Exception as e:  # en trasig kontroll ska inte stoppa resten
            gul(f"{check.__name__} kunde inte köras: {e}")
    colors = {"OK": "\033[32m", "GUL": "\033[33m", "RÖD": "\033[31m"}
    for level, text in results:
        print(f"{colors[level]}{level:>3}\033[0m  {text}")
    red = [t for lvl, t in results if lvl == "RÖD"]
    print(f"\n{len(red)} röda, {sum(1 for l, _ in results if l == 'GUL')} gula, {sum(1 for l, _ in results if l == 'OK')} ok.")
    if red and "--larm" in sys.argv:
        larm("Röda punkter:\n" + "\n".join(red[:8]))
    sys.exit(1 if red else 0)


if __name__ == "__main__":
    main()

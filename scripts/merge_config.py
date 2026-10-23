#!/usr/bin/env python3
"""Slår ihop config/hardening.yaml med ~/.hermes/config.yaml.

Härdningsvärdena vinner alltid. Övriga inställningar du har gjort ligger kvar.
En säkerhetskopia sparas som config.yaml.bak innan något skrivs.
"""
import shutil
import sys
from pathlib import Path

import yaml


def merge(base: dict, hard: dict) -> dict:
    out = dict(base)
    for key, value in hard.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = value
    return out


def main(hard_path: str, target_path: str) -> None:
    hard = yaml.safe_load(Path(hard_path).read_text(encoding="utf-8")) or {}
    target = Path(target_path).expanduser()
    base = {}
    if target.exists():
        base = yaml.safe_load(target.read_text(encoding="utf-8")) or {}
        shutil.copy2(target, target.with_suffix(".yaml.bak"))
    merged = merge(base, hard)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(yaml.safe_dump(merged, sort_keys=False, allow_unicode=True), encoding="utf-8")
    target.chmod(0o600)
    print(f"Härdade inställningar skrivna till {target}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Användning: merge_config.py hardening.yaml ~/.hermes/config.yaml")
    main(sys.argv[1], sys.argv[2])

---
name: projektstart
description: Starta och bygga ett nytt kodprojekt i små, säkra steg - från idé till fungerande repo med README. Använd när Anders vill skapa något nytt, till exempel "bygg", "skapa ett projekt", "gör en app/ett skript" eller "nytt repo".
version: 1.0.0
metadata:
  hermes:
    tags: [utveckling, projekt, git]
---

# Projektstart

Skriven för en lokal modell: hellre många små steg som fungerar än ett stort som går sönder.

## 1. Förstå (innan någon kod)
Ställ högst tre frågor, en i taget, bara om svaret ändrar vad du bygger:
- Vad ska det göra, för vem?
- Vilket språk eller vilken stack? (Standard för Anders: Python för data, SQL/dbt för modellering, HTML/JS för små verktyg.)
- Ska det upp på GitHub, publikt eller privat?

Skriv sedan en plan på max sju punkter i `projekt/<namn>.md` i valvet och visa den. Vänta på ja.

## 2. Bygg i små steg
För varje punkt i planen:
1. Skriv den minsta koden som löser punkten.
2. Kör den. Visa utskriften. Om det blir fel: läs felet, gör en ändring i taget, kör igen. Efter tre misslyckade försök, stoppa och skriv upp problemet under "Till Claude" i HANDOFF.md.
3. Bocka av punkten i planen.

Regler:
- Projekt skapas under `~/projekt/<namn>`, aldrig någon annanstans.
- Installera bara paket från pip, npm eller apt, och fråga först.
- Inga hemligheter i kod. Använd en `.env` som ligger i `.gitignore`.

## 3. Gör klart
- `README.md` på svenska: vad det är, hur man kör det, vad som är kvar. Inga personuppgifter i publika repon.
- `.gitignore` för språket.
- `git init` och en commit. Att skapa ett repo på GitHub och pusha gör Anders själv. Skriv kommandona åt honom.
- Avsluta med skillen `lamna-taktpinnen`.

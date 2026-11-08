# Goldweaver (Projektordner `Auctionator`)

WoW-Addon für **World of Warcraft: Forever** (Interface 16001): Berufe, Post-Pipeline Main→Twink und Auktionshaus als eine Entscheidungskette für Gold, günstiges Leveln und profitable Herstellung, für alle zwölf Berufe.

## Dokumente
- `docs/01-KONZEPT.md` – Analyse, Produktkonzept, Architektur, offene Fragen
- `docs/02-ROADMAP.md` – Phasen, Arbeitspakete mit Dateibesitz, Definition of Done
- `docs/03-RECHERCHE-QUELLEN.md` – Fakten mit Quellen und Vertrauensgrad
- `docs/04-COMPLIANCE.md` – Blizzard-Richtlinien, ToU, Lizenzen, Checkliste
- `CLAUDE.md` – Regeln für alle Entwicklungs-Sessions

## Struktur
```
Goldweaver/        das Addon (Ordnername = TOC-Name)
tools/             Prüfskripte und Headless-Tests
docs/              Konzept, Roadmap, Recherche, Compliance
```

## Entwicklung
1. Junction in den Forever-AddOns-Ordner legen (Ordnername des Clients prüfen):
   `mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Goldweaver" "D:\Development\WoW-Addon\Auctionator\Goldweaver"`
2. Im Spiel `/console scriptErrors 1`, dann `/gw` für die Befehlsliste und `/gw probe` für die API-Verifikation.
3. Vor jedem Abschluss `tools/check.ps1` ausführen. Werkzeuge: LuaJIT (`winget install --id DEVCOM.LuaJIT`, Lua-5.1-kompatibel) und die eigenständige `luacheck.exe` aus den GitHub-Releases von lunarmodules/luacheck unter `%LOCALAPPDATA%\Programs\luacheck`.

Lizenz: MIT (siehe `LICENSE`).

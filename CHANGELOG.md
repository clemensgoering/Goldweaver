# Changelog

## Unreleased
- Projekt angelegt: Konzept, Roadmap, Recherche, Compliance, Addon-Gerüst (TOC, Core-Bootstrap, Event-Bus mit Secret-Guard, SavedVariables, Stubs).
- Phase 0: `/gw probe [items|prof|ah|replicate|mail|secure]` zur API-Verifikation im Spiel, Ergebnisvorlage `docs/05-PROBE-ERGEBNISSE.md`, Schnittstellen-Doku `docs/06-SCHNITTSTELLEN.md`, CI (GitHub Actions: Lua 5.1 + luacheck + Tests), Release-Workflow mit BigWigs-Packager, `.pkgmeta`.
- Core: Preis-Engine mit Quellenkette (Auctionator-API, TSM, eigene Beobachtungen, Vendor) und Vendor-Deckel, Umwandlungs-Graph, Charakter-Registry mit Rollen und Markt-Key (`/gw role`, `/gw chars`, `/gw market`).
- Daten: Entzaubertabelle (Forever-Levelbereiche, Wahrscheinlichkeiten), Kisten-Bündel und Favor-Sätze (unbestätigt), Vendor-Reagenzien, Schmelz- und Bolzen-Umwandlungen als Startwerte.
- Advisor: Bewertungsformel für Vendor / AH / Umwandeln / Kiste / Behalten mit Cut, Einzahlungsrisiko und Postkosten (reine Logik, headless getestet).
- Berufe: Profil-Registry mit Rängen, Skill-Line-IDs und Seed-Pfad-Kosten; Profile Schneiderei und Verzauberkunst mit Beta-Leveling-Routen als Startwerte.

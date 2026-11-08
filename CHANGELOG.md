# Changelog

## Unreleased
- Kompatibilitätsschicht: `ns.API` (Wrapper mit Fähigkeitsprüfung, normalisierte Rückgaben, Fehlerzähler), `ns.Features` (Funktionsgruppen mit API-Anforderungen, `/gw feature`), Fehlerisolierung pro Event-Handler (Abschaltung nach fünf Fehlern), Schema-Versionierung mit Migrationen, Patch-Erkennung beim Login.
- Debug-Bericht `/gw debug run`: Selbsttest aller Module, Features, Daten, Events, Fehler, kontextabhängige Probes, Debug-Log; kopierbares Fenster, Bericht in SavedVariables.
- Dokumente: `10-KOMPATIBILITAET.md` (Strategie und Patch-Routine), `11-ASSETS.md` (Grafik-Aufträge für Codex).
- Erster vollständiger Durchstich (0.1.0-dev, 08.11.2026): Tooltip-Zeile mit bester Verwendung, Shift-Details und Bestand (Bank, Twinks); Briefkasten-Knöpfe „Anhängen/Senden" nach Regeln und „Alles abholen" mit Verkaufs-Ledger; Entzauber-Queue mit Secure-Button (`/gw de`); Berufs-Adapter mit Rezept-Cache, Skill-up-Planer, Profit-Ranking, Berufs-Vergleich; Berufe-Leitfaden mit Icons (Status, nächster Skill-up mit Einkaufsliste und Aktionen, lohnt sich, noch nicht gelernt); AH-Preis-Mitlesen und Verkaufsvorschlag mit Vorbelegung; HUD-Zeile; Erstlauf-Karte; Trade-Contacts-Rekorder für Lehrer und Händler; Heute-Tab mit Empfehlungen und Verkäufen; Fenster auf 720×580 vergrößert.
- Projekt angelegt: Konzept, Roadmap, Recherche, Compliance, Addon-Gerüst (TOC, Core-Bootstrap, Event-Bus mit Secret-Guard, SavedVariables, Stubs).
- Phase 0: `/gw probe [items|prof|ah|replicate|mail|secure]` zur API-Verifikation im Spiel, Ergebnisvorlage `docs/05-PROBE-ERGEBNISSE.md`, Schnittstellen-Doku `docs/06-SCHNITTSTELLEN.md`, CI (GitHub Actions: Lua 5.1 + luacheck + Tests), Release-Workflow mit BigWigs-Packager, `.pkgmeta`.
- Core: Preis-Engine mit Quellenkette (Auctionator-API, TSM, eigene Beobachtungen, Vendor) und Vendor-Deckel, Umwandlungs-Graph, Charakter-Registry mit Rollen und Markt-Key (`/gw role`, `/gw chars`, `/gw market`).
- Daten: Entzaubertabelle (Forever-Levelbereiche, Wahrscheinlichkeiten), Kisten-Bündel und Favor-Sätze (unbestätigt), Vendor-Reagenzien, Schmelz- und Bolzen-Umwandlungen als Startwerte.
- Advisor: Bewertungsformel für Vendor / AH / Umwandeln / Kiste / Behalten mit Cut, Einzahlungsrisiko und Postkosten (reine Logik, headless getestet).
- Berufe: Profil-Registry mit Rängen, Skill-Line-IDs und Seed-Pfad-Kosten; Profile Schneiderei und Verzauberkunst mit Beta-Leveling-Routen als Startwerte.

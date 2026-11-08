# Goldweaver – Richtlinien- und Lizenz-Check

Stand: 08.11.2026. Gilt für jede Session, die Code schreibt. Bei Unsicherheit: Feature weglassen und Frage in `02-ROADMAP.md` unter „Offene Fragen" eintragen.

## 1. Blizzard UI Add-On Development Policy (8 Regeln)

Quelle: US-Forum „UI Add-On Development Policy" (Erstveröffentlichung 20.03.2009, Thread vom 19.11.2018, bis heute die einzige formale Richtlinie). Stand 10/2026: Blizzard hat zu Paid-Addons (RestedXP, Journey) nicht erneut Stellung genommen; die Regeln gelten unverändert.

| # | Regel | Umsetzung in Goldweaver |
|---|---|---|
| 1 | Add-ons must be free of charge | Kostenlos, keine Premium-Version, keine bezahlten Dienste. |
| 2 | Add-on code must be completely visible | Reines Lua/XML, keine Obfuskation, MIT-Lizenz, öffentliches Repo vor Veröffentlichung. |
| 3 | Must not negatively impact realms or players | Keine Query-Schleifen, eine AH-Anfrage pro Klick, `IsThrottledMessageSystemReady()` vor Anfragen, Vollscan opt-in mit persistierter 15-Min-Sperre, keine Chat-Nachrichten, kein `OnUpdate`-Polling, große Datenmengen in Batches über Frames. |
| 4 | May not include advertisements | Keine Werbung, keine Shop-Links. Fremd-Addons (Auctionator, Questie, GatherMate2) nur funktional nennen. |
| 5 | May not solicit donations | Kein Spendenhinweis im Spiel. Erlaubt nur auf der Download-Seite. |
| 6 | Must not contain offensive material | Texte neutral, „T"-Rating. |
| 7 | Must abide by WoW ToU and EULA | Abschnitt 2. |
| 8 | Blizzard may disable functionality | Jedes Feature einzeln abschaltbar; API-Ausfälle werden abgefangen, nie umgangen. |

## 2. Terms of Use / EULA: Automatisierung und Kampfvorteil

- **Keine Automatisierung.** Jede geschützte Aktion (Posten, Kaufen, Abbrechen, Post senden, Herstellen, Entzaubern) wird genau einmal pro Hardware-Event ausgelöst. Keine Queues, die ohne Klick weiterlaufen. Keine Timer, die Aktionen auslösen; Timer dürfen nur Anzeigen aktualisieren.
- **Keine Umgehung von Throttles oder Secret Values.** Kein Vergleich, keine Arithmetik, kein Speichern geheimer Werte; `issecretvalue()` vor jeder Verwendung von Event-Argumenten. Kein Rekonstruieren von Kampfinformationen.
- **Kein Kampfvorteil.** Goldweaver liest keine Unit-, Auren-, Cooldown- oder Combat-Log-Daten. Blizzards Grundsatz, für Forever bestätigt am 15.09.2026: „Addons should no longer offer a competitive advantage in WoW combat".
- **Kein Echtgeld-Bezug.** Kein GDKP-Feature (auf NA/EU-Forever untersagt), kein Gold-Verkauf, keine Boost-Vermittlung.
- **Nur Daten des eigenen Accounts** und öffentliche AH-Listungen. Keine Daten über andere Spieler.

## 3. Technische Pflichten pro Datei (Review-Checkliste)

1. `## Interface: 16001` (nach jedem Patch mit `/dump select(4, GetBuildInfo())` prüfen).
2. Nur `C_Item.*`, `C_Spell.*`, `C_Container.*`, `C_TradeSkillUI.*`, `C_AuctionHouse.*`, `C_TooltipInfo.*`. Alte Globals (`GetItemInfo`, `GetSpellInfo`) existieren nicht.
3. Keine Nutzung von `COMBAT_LOG_EVENT_UNFILTERED`, `CombatLogGetCurrentEventInfo`, `UnitHealth` fremder Units, Auren, Cooldowns.
4. Jeder Event-Handler über `ns.Events` (Secret-Guard). `pcall` macht geschützte Aufrufe **nicht** sicher.
5. Keine geschützten Frame-Änderungen im Kampf: `InCombatLockdown()` prüfen, bei `PLAYER_REGEN_ENABLED` nachholen.
6. SavedVariables nur in `ADDON_LOADED` initialisieren; nie Secrets speichern (werden zu `nil`).
7. Kein `WOW_PROJECT_ID`-Branching als einziger Test; Fähigkeiten per `if C_X and C_X.Y then` prüfen.
8. Lua 5.1: kein `goto`, keine Bit-Operatoren, kein `io`/`os`.
9. Keine Berufs-Sonderfälle in Engine-Code; alles Berufsspezifische gehört in `Professions/<Beruf>.lua`.

## 4. Lizenzen und Fremdcode

| Quelle | Lizenz | Erlaubt |
|---|---|---|
| Eigener Code | MIT (`LICENSE` im Repo) | – |
| **ForeverArtisan** | „All rights reserved": lesen ja, Code/Daten/Name/Artwork **nicht** wiederverwenden, nicht weiterverteilen | Nur Lernen von Konzepten (API-Fallback-Reihenfolge, Secret-Guard-Idee). **Keine Zeile kopieren, keine Datentabellen übernehmen.** |
| **Auctionator** | MIT (laut Org-Listing), Repo derzeit nicht erreichbar | Nutzung über `Auctionator.API.v1` als optionale Abhängigkeit. Kein Code-Kopieren nötig; falls doch, MIT-Hinweis beilegen. |
| TradeSkillMaster | proprietär | Nur `TSM_API` optional lesen, kein Code. |
| Syndicator, GatherMate2 | Open Source (jeweilige Lizenz prüfen) | Nur öffentliche API/Tabellen lesen, kein Code. |
| Ace3, LibStub, LibDataBroker, LibDBIcon | BSD/Public Domain | Erlaubt, Trunk-Version mit 16001. Im MVP nicht nötig. |
| Guides (wow-professions, Mobalytics, Zockify u. a.) | Text urheberrechtlich geschützt | Fakten (Rezeptnamen, Materialmengen) dürfen genutzt werden, keine Textübernahme. Skill-up-Pfade werden ohnehin live berechnet. |
| Blizzard-Spieldaten (Item-IDs, Rezeptnamen) | Blizzard | Übliche Addon-Praxis, erlaubt. |

## 5. Namensrecht
- Addon heißt **nicht** `Auctionator` (bestehendes Addon, Ordner-Kollision, Verwechslung). Arbeitstitel „Goldweaver"; CurseForge-Suche am 08.11.2026 ohne Treffer. Vor Release erneut prüfen (CurseForge, Wago, GitHub).
- Keine Blizzard-Marken im Namen; „for WoW: Forever" in der Beschreibung ist üblich.

## 6. Veröffentlichung
- Packager: BigWigsMods/packager v2.6+ erkennt Forever (CurseForge-Game-Type 88568). WoWInterface unterstützt Forever derzeit nicht.
- Vor jedem Release: Definition of Done in `02-ROADMAP.md` und Abschnitt 3 pro geänderter Datei.

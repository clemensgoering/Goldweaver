# Goldweaver – Roadmap und Arbeitspakete

Stand: 08.11.2026. Zeitangaben sind Kalenderwochen ab Montag, 10.11.2026, bei nebenläufiger Entwicklung in 2–3 Sessions. Jede Phase endet mit einem in-game geprüften Stand.

## Phasenübersicht

| Phase | Zeitraum | Ergebnis | Freigabekriterium |
|---|---|---|---|
| **0 Fundament und Verifikation** | KW 46 (10.–16.11.) | Addon lädt auf Forever, Probe-Befehl beantwortet die offenen Fragen F1–F11, Core-Gerüst, Test-Harness | `/gw probe` liefert Protokoll; alle Fragen in Abschnitt „Offene Fragen" haben Antwort oder Fallback |
| **1 MVP Durchstich (Schneiderei + Verzauberkunst)** | KW 47–48 (17.–30.11.) | Preis-Engine, Umwandlungs-Graph, Advisor-Tooltip, Entzaubertabelle, Post-Pipeline, Zerlegen-Queue | Main sammelt → ein Klick pro Brief → Twink sieht Empfehlungen → entzaubert per Klick. Täglich benutzbar |
| **2 Berufe-Engine für alle 12** | KW 49–50 (01.–14.12.) | Adapter, Planer, Craft-Profit, zwölf Profile, Sammel-Sicht im HUD, Berufs-Vergleich | Planer liefert für jeden geöffneten Beruf Pfad + Einkaufsliste; Vergleich zeigt Kosten bis 300 für alle Berufe |
| **3 Auktionshaus** | KW 51–52 (15.–28.12.) | Post-Helfer, beobachtete Preise, Einkaufslisten, opt-in Vollscan (falls F1 positiv), Unterbietungs-Check, Ledger | Posten mit Vorschlag in einem Klick; Preise altern korrekt; kein Throttle-Hinweis |
| **4 HUD und Dashboard** | KW 1–2 2027 (29.12.–11.01.) | HUD-Feinschliff, Dashboard, Favor-Tracker, Tagesplan, Kalibrierung aus Logs | Session-Gold und Verkäufe stimmen mit Ledger überein |
| **5 Politur und Veröffentlichung** | KW 3 2027 (12.–18.01.) | Lokalisierung deDE/enUS, Einstellungen, Packager, CurseForge/Wago-Seite, LICENSE, README | Checkliste `04-COMPLIANCE.md` Abschnitt 3 pro Datei; Release 1.0.0 |

Nach 1.0: Camp-Buffs auswerten, GatherMate2-Routen, Writs-Planer, Raid-Nachfrage-Signale (ab 09.12.2026), Export der Preis-DB.

---

## Phase 0: Fundament und Verifikation (KW 46)

**Ziel:** Nichts Fachliches bauen, bevor die API-Fragen geklärt sind.

Arbeitspakete:
- **WP0.1 Gerüst** (`Goldweaver.toc`, `Core/Init.lua`, `Core/Events.lua`, `Core/Secret.lua`, `Core/DB.lua`, `Core/Util.lua`): Namespace, Event-Bus mit Secret-Guard, SavedVariables-Init in `ADDON_LOADED`, Slash `/gw`, Logging `/gw log`.
- **WP0.2 Probe** (`Core/Probe.lua`): `/gw probe` schreibt in `GoldweaverDB.probe` und in den Chat:
  - Build/Interface (`GetBuildInfo`), `WOW_PROJECT_ID`
  - Existenz: `C_TradeSkillUI.GetAllRecipeIDs`, `GetTradeSkillInfo`, `GetCraftInfo`, `C_AuctionHouse.ReplicateItems`, `TooltipDataProcessor`, `C_TooltipInfo.GetBagItem`, `C_Container.UseContainerItem`, `SendMail`, `GetInboxInvoiceInfo`, `GetProfessions`
  - Identität: `UnitFullName("player")`, `GetNormalizedRealmName()`, `GetRealmName()`, `UnitFactionGroup`
  - Am AH (`/gw probe ah`): `IsThrottledMessageSystemReady`, Laufzeit-Enum, eine `SendSearchQuery`-Probe mit Zeitmessung, optional `ReplicateItems`-Versuch mit Zeitstempel (nur auf ausdrücklichen Befehl `/gw probe replicate`)
  - Im Berufefenster (`/gw probe prof`): welche API antwortet, Felder eines Rezepts, Farbe, Reagenzien, Werkzeuge; für Verzauberkunst zusätzlich Craft-Fenster
  - Am Briefkasten (`/gw probe mail`): Felder von `GetInboxHeaderInfo`/`GetInboxInvoiceInfo` einer echten AH-Rechnung
  - Secure-Test (`/gw probe secure`): erzeugt einen `SecureActionButtonTemplate`-Button mit `macrotext` außerhalb des Kampfs und meldet Fehler
- **WP0.3 Werkzeuge** (`tools/`): `.luacheckrc` mit WoW-Globals, `tools/tests/run.lua` (Lua 5.1 Harness mit Stubs für `C_Item`, `C_TradeSkillUI`, `issecretvalue`), `tools/check.ps1` (luac -p + luacheck + Tests), Junction-Anleitung in `README.md` (`mklink /J "<AddOns>\Goldweaver" "<Repo>\Goldweaver"`).

**Abnahme:** Protokoll in `docs/05-PROBE-ERGEBNISSE.md` mit Antworten zu F1–F11; Entscheidungen (z. B. Vollscan ja/nein, Tooltip-Pfad) in `01-KONZEPT.md` nachgetragen.

**Phase 0 abgenommen am 08.11.2026** (drei Probe-Läufe im Spiel, Fenster und Rollenpflege vom Nutzer bestätigt). Offen bleiben nur F6 (Einzahlungsformel), F7 (Favor je Kiste), F10 (Post-Empfängerformat) und F11 (Skill-up-Wahrscheinlichkeiten), die sich im Spielbetrieb klären. Nächster Einstieg: Phase 1, Session A = WP1.4 Bestand + WP1.6 Zerlegen-Queue, Session B = WP1.3 Tooltip + WP1.5 Post.

**Stand 08.11.2026:** WP0.1, WP0.2 und WP0.3 sind implementiert (Code, CI, Junction in `_forever_`). Offen ist nur noch das Ausführen der Probe im Spiel und das Eintragen der Ergebnisse. Aus Phase 1 sind die rein logischen Teile fertig und headless getestet: WP1.1 Preis-Engine, WP1.2 Graph + Daten, WP1.3 Advisor-Formel (ohne Tooltip/Overlay), Registry + Profile Schneiderei/Verzauberkunst aus WP1.8, Charakter-Registry aus WP1.1. Offen in Phase 1: WP1.4 Bestand, WP1.5 Post, WP1.6 Zerlegen-Queue, WP1.7 UI-Kit, Tooltip-Anbindung des Advisors.

---

## Phase 1: MVP Durchstich (KW 47–48)

| WP | Inhalt | Dateien (Besitz) | Hängt ab von |
|---|---|---|---|
| WP1.1 Preis-Engine | Quellenkette Auctionator-API → eigene Beobachtung → Vendor; Markt-Key; Alterung; `ns.Price.Get` | `Core/Price.lua`, `Core/Chars.lua` | WP0.1 |
| WP1.2 Umwandlungs-Graph + Daten | `ns.Graph`, Entzaubertabelle, Kisten-Bündel, Vendor-Reagenzien | `Core/Graph.lua`, `Data/*.lua` | WP0.1 |
| WP1.3 Advisor | Bewertungsformel, Optionen, Begründung, Konfidenz; Tooltip-Zeilen; Taschen-Overlay | `Modules/Advisor.lua`, `UI/Tooltip.lua` | WP1.1, WP1.2 |
| WP1.4 Bestand | Taschen/Bank/Post je Charakter, optional Syndicator | `Core/Inventory.lua` | WP0.1 |
| WP1.5 Post | Sende-Listen je Zielcharakter, ein Klick pro Brief, Abholen, Ledger | `Modules/Mail.lua` | WP1.3, WP1.4 |
| WP1.6 Zerlegen-Queue | Sortierte Liste, Secure-Button, Loot-Log zur Kalibrierung | `Modules/Destroy.lua` | WP1.3, Ergebnis F4 |
| WP1.7 UI-Kit | Tooltip-Zeile, Taschen-Overlay, Knopf-Vorlage „Verb + Objekt + Zahl", Seitenleisten-Container für Blizzard-Fenster, ein `/gw`-Fenster mit vier Tabs (Heute · Berufe · Charaktere · Einstellungen). Vorgaben: `08-UX.md` | `UI/Kit.lua`, `UI/Minimap.lua` | WP0.1 |
| WP1.8 Profile Schneiderei/Verzauberkunst (Startwerte) | Rang-Anforderungen, Vendor-Reagenzien, Standardpfad, Kisten-Kategorien | `Professions/Tailoring.lua`, `Professions/Enchanting.lua`, `Professions/Registry.lua` | WP1.2 |
| WP1.9 Onboarding | Erstlauf-Karte (eine Frage: Rolle), `/gw`-Kurzhilfe mit vier Zeilen, Hinweis bei fehlender Preisquelle | `Modules/Onboarding.lua` | WP1.7, Chars |

**Abnahmetest für jede Ansicht (aus `08-UX.md`):** eine Person ohne Vorwissen versteht in 30 Sekunden, was sie tun soll. Post (WP1.5) als Knöpfe im Blizzard-Briefkasten, Berufe (WP2.x) als Seitenleiste am Berufefenster, AH (WP3.x) im MVP nur Preisvorschlag im Verkaufen-Tab. WP4.2 Dashboard entfällt zugunsten des Tabs „Heute".

**Abnahme:** Eine echte Sammelrunde mit dem Main, Versand an den Twink, Verarbeitung mit Empfehlungen. Headless-Tests für Preis-Engine, Graph, Advisor-Formel und DE-Erwartungswert grün.

---

## Phase 2: Berufe-Engine für alle zwölf (KW 49–50)

| WP | Inhalt | Dateien (Besitz) | Hängt ab von |
|---|---|---|---|
| WP2.1 Adapter | Fallback-Kette, normierte Rezepte, Events, Werkzeuge/Stationen, Sammelberufe | `Professions/Adapter.lua` | Ergebnis F2 |
| WP2.2 Planer | Zielrang → günstigster Pfad, Alternativenvergleich, Bestand abziehen, Einkaufsliste, Sammelberufe als Zonenfolge | `Modules/Planner.lua` | WP2.1, WP1.1 |
| WP2.3 Craft-Profit | Ranking, Marktbreite, „jetzt herstellen" | `Modules/CraftProfit.lua` | WP2.1 |
| WP2.4 Zehn weitere Profile | Schmiedekunst, Lederverarbeitung, Alchemie, Ingenieurskunst, Kochkunst, Erste Hilfe, Angeln, Kräuterkunde, Bergbau, Kürschnerei | `Professions/<Beruf>.lua` | WP1.8 als Vorlage |
| WP2.5 Berufs-Vergleich | Kosten bis 300 je Beruf, Top-Crafts, Synergie mit Bestand und vorhandenen Berufen | `Modules/Compare.lua` | WP2.2, WP2.4 |
| WP2.6 Sammel-Sicht im HUD | Zonenwert, Skill-Fenster, GatherMate2 lesen | `Modules/HUD.lua` (Abschnitt Sammeln) | WP1.1, WP2.4 |

**Abnahme:** Mit mindestens drei verschiedenen Berufen (ein Herstellungs-, ein Sammel-, ein Sekundärberuf) geprüft. Planer-Pfad gegen Guide-Pfad zu aktuellen Preisen verglichen und dokumentiert.

---

## Phase 3: Auktionshaus (KW 51–52)

| WP | Inhalt | Dateien (Besitz) |
|---|---|---|
| WP3.1 Beobachtete Preise | Hook auf Suchergebnisse, Übernahme in Preis-DB ohne Zusatzanfragen | `Modules/Auction.lua` (Teil Observe) |
| WP3.2 Post-Helfer | Preisvorschlag, Unterbieten, Stückelung, Einzahlung/Cut, ein Klick pro Posten | `Modules/Auction.lua` (Teil Sell) |
| WP3.3 Einkaufslisten | Aus Planer, Suche per Klick, Rohstoff vs. Zwischenprodukt | `Modules/Auction.lua` (Teil Shop) |
| ~~WP3.4 Vollscan (opt-in)~~ | **Entfällt** (F1/F13: `ReplicateItems` liefert auf Forever keine Daten). Ersatz: Auctionator-API als Massenquelle, WP3.1 für eigene Beobachtungen | – |
| WP3.5 Unterbietungs-Check | Eigene Auktionen, eine Suche pro Item, Klick zum Abbrechen | `Modules/Auction.lua` (Teil Undercut) |
| WP3.6 Ledger | Verkäufe/Einzahlungen/Cuts aus Rechnungen, pro Charakter und Markt | `Modules/Ledger.lua` |

Hinweis: `Auction.lua` wird groß; wenn zwei Sessions parallel arbeiten, in `Auction/Observe.lua`, `Auction/Sell.lua` usw. aufteilen und die TOC anpassen.

---

## Phase 4: HUD und Dashboard (KW 1–2 2027)
- WP4.1 HUD-Feinschliff (Regeln-Editor, Zielcharakter je Materialtyp, Loot-Hinweis).
- WP4.2 Dashboard (`Modules/Dashboard.lua`): Gold-Verlauf, Quellen, Favor, Tagesplan.
- WP4.3 Kalibrierung: Skill-up-Wahrscheinlichkeiten und DE-Ausbeuten aus eigenen Logs in die Daten zurückspielen (F11).

## Phase 5: Politur und Veröffentlichung (KW 3 2027)
- WP5.1 Lokalisierung deDE/enUS, Einstellungen-Panel, Hilfe `/gw help`.
- WP5.2 Packaging: `.pkgmeta`, GitHub Actions mit BigWigs-Packager, CurseForge/Wago-IDs, README, LICENSE (MIT), CHANGELOG.
- WP5.3 Compliance-Review jeder Datei nach `04-COMPLIANCE.md` Abschnitt 3.

---

## Parallele Sessions: Spielregeln

1. **Eine Session = ein oder mehrere WPs mit exklusivem Dateibesitz** laut Tabellen oben. Fremde Dateien nur lesen. Gemeinsame Schnittstellen (`ns.Price`, `ns.Graph`, `ns.Events`, `ns.Recipes`, `ns.UI`) werden in `docs/06-SCHNITTSTELLEN.md` dokumentiert, bevor zwei Sessions davon abhängen.
2. **TOC-Änderungen** (neue Dateien) nur durch die Session, die Core/WP0.1 besitzt, oder nach kurzer Absprache; neue Datei wird mit Stub angelegt, bevor andere sie referenzieren.
3. **Empfohlene Verteilung Phase 1:** Session A = WP1.1, 1.2, 1.4, 1.8 (Daten und Engine). Session B = WP1.7, 1.3, 1.5, 1.6 (UI und Module). Höchstens zwei bis drei Sessions gleichzeitig.
4. **Vor dem Coden:** `CLAUDE.md`, `01-KONZEPT.md` Abschnitte 4–5, `04-COMPLIANCE.md` Abschnitt 3 und das eigene WP lesen.
5. **Nach dem Coden:** `tools/check.ps1` grün, Eintrag unter „Unreleased" in `CHANGELOG.md`, kurze Notiz zu offenen Fragen hier unten.
6. **Versionskontrolle:** Git-Repo `https://github.com/clemensgoering/Goldweaver.git`, Hauptbranch `main` (seit 08.11.2026). Ein Branch pro WP (`wp1.1-price-engine`), Merge nach grünem `tools/check.ps1`. Commits enden mit der Co-Authored-By-Zeile der jeweiligen Session.

## Definition of Done (jedes WP)
- `luac -p` und `luacheck` ohne Fehler; Headless-Tests für reine Logik grün.
- In-game geladen ohne Lua-Fehler, einmal mit `/console scriptErrors 1`.
- Keine geschützte Aktion ohne Klick; Secret-Guard an jedem Event-Handler.
- Berufsspezifisches nur in `Professions/`, nichts davon in Engine-Code.
- Tooltip/Anzeige nennt Quelle und Alter jedes Preises.
- CHANGELOG-Eintrag, offene Fragen notiert.

## Offene Fragen (laufend gepflegt)
| # | Frage | Status | Antwort / Entscheidung |
|---|---|---|---|
| F1 | `ReplicateItems` auf 1.60 | **beantwortet: nein** | API existiert, Aufruf wirft keinen Fehler, liefert aber nie Daten (siehe F13) |
| F2 | Berufe-API je Beruf | **beantwortet** | Nur `C_TradeSkillUI` (Kochkunst 132, Lederverarbeitung 592 Rezepte). `GetRecipeInfo` liefert `name`, `difficulty` als Zahl (Enum.TradeskillRelativeDifficulty), `learned`; `GetRecipeSchematic` liefert `reagentSlotSchematics`, `quantityMin/Max`. `GetRecipeTools` fehlt. Verzauberkunst noch zu bestätigen, aber keine Legacy-API vorhanden |
| F3 | Namensformat, Realm-Funktionen, Regelsatz | **beantwortet** | `UnitFullName` = Vorname, Nachname. Realmname „CAMWOW EU4 Realm 5 PvE" → Markt-Key `EU-PvE-Horde`. Key „Vorname Nachname" |
| F4 | Secure-Button mit `macrotext` | **beantwortet: ja** | Lauf 3: `/dance` im Makrotext eines `SecureActionButtonTemplate`-Buttons wird ausgeführt. Zerlegen-Queue kann `/cast Entzaubern` + Item-Ziel nutzen |
| F5 | `TooltipDataProcessor` | **beantwortet** | vorhanden |
| F6 | Laufzeiten und Einzahlung | **teilweise beantwortet** | 2 / 8 / 24 h. Einzahlung 1 Silber pauschal für 1× Leinenstoff; Formel über Rechnung prüfen |
| F7 | Favor pro Kiste, Bündel je Kategorie | offen | |
| F8 | Interface 16001 nach Patch | **beantwortet** | Live-Build 70862 nutzt 16001 |
| F9 | AH-Budget pro Minute | offen, kein Fix erwartet | Konservatives Design |
| F10 | Post nach Vorname | offen | Testsendung vor erster echter Sendung |
| F11 | Skill-up-Wahrscheinlichkeiten | offen | Kalibrierung in Phase 4 |
| F12 | Ist `/run` in Makrotext eines Secure-Buttons auf Forever erlaubt? | **beantwortet: nein** | `/run print` ohne Wirkung, `/dance` läuft. Nie `/run` oder `/script` in Makrotext verwenden |
| F13 | `REPLICATE_ITEM_LIST_UPDATE` nach `ReplicateItems()` | **beantwortet: kommt nicht** | Lauf 3: AH offen, Throttle bereit, nach 90 s kein Event und `GetNumReplicateItems() = 0`. **Entscheidung: WP3.4 Vollscan entfällt.** Massenpreise nur aus Auctionator-API; eigene Preise aus mitgelesenen Suchseiten (WP3.1) |

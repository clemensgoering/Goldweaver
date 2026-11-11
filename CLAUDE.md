# Goldweaver – Projektregeln für alle Sessions

Projekt: WoW-Addon **Goldweaver** für World of Warcraft: Forever (Interface 16001). Zweck: Berufe, Post-Pipeline Main→Twink und Auktionshaus als eine Entscheidungskette für maximalen Gold-Ertrag, günstigstes Leveln und profitable Herstellung, für **alle zwölf Berufe**.

Der Projektordner heißt historisch `Auctionator`; das Addon heißt **Goldweaver** und liegt in `Goldweaver/`. Nie `Auctionator` als Addon-Name verwenden.

## Pflichtlektüre vor dem Coden
1. `docs/01-KONZEPT.md` Abschnitte 4 (Module), 5 (Architektur), 7 (offene Fragen)
2. `docs/02-ROADMAP.md`: eigenes Arbeitspaket (WP) und Dateibesitz
3. `docs/04-COMPLIANCE.md` Abschnitt 3: Checkliste pro Datei
b. `docs/14-UI-FUEHRUNG.md`: Reiter Leitfaden · Unterwegs · Berufe · Team, Schrittkarte mit genau einem Aktionsknopf, Blizzard-Templates nur über `UI.SafeCreate`, Einstellungen im Blizzard-Optionsmenü
4. `docs/03-RECHERCHE-QUELLEN.md` nur bei Bedarf (Fakten und Vertrauensgrad)

## Harte Regeln
- **Client:** Forever ist Mainline-API (Retail-Stil), kein Classic. Nur `C_Item`, `C_Spell`, `C_Container`, `C_TradeSkillUI`, `C_AuctionHouse`, `C_TooltipInfo`. `GetItemInfo`/`GetSpellInfo` existieren nicht. Lua 5.1 (kein `goto`, keine Bit-Operatoren, kein `io`/`os`).
- **Secret Values:** Jeder Event-Handler über `ns.Events:On(...)` (Secret-Guard). Vor Vergleich, Tabellen-Key oder Speichern: `ns.Secret.IsSecret(v)`. Nie Kampf-, Auren-, Cooldown- oder Combat-Log-Daten lesen.
- **Keine Automatisierung:** Posten, Kaufen, Abbrechen, Senden, Herstellen, Entzaubern nur im Klick-Handler eines Buttons, eine Aktion pro Klick. Timer nur für Anzeigen. `C_AuctionHouse.IsThrottledMessageSystemReady()` vor jeder AH-Anfrage.
- **Berufsneutral:** Engine-Code (`Core/`, `Modules/`) kennt keine Berufsnamen. Alles Berufsspezifische steht in `Professions/<Beruf>.lua` und wird über `ns.Professions:Register(profile)` eingebunden.
- **Fremdcode:** Kein Code, keine Daten, keine Texte aus ForeverArtisan (proprietär). Andere Addons (Auctionator, RestedXP) nur über `ns.API.External` in `Core/API.lua` lesen: dort wird zuerst geprüft, ob Funktion oder Tabelle wie erwartet vorliegt, sonst erfolgt kein Zugriff. Immer optional, nur lesend, nichts davon speichern.
- **Keine Netzwerk-, Chat- oder Werbefunktionen.** Keine Spendenhinweise im Spiel.
- **Datenschutz:** In SavedVariables landen nur Daten des eigenen Accounts (eigene Charaktere, eigene Verkäufe, gesehene Preise). Nie Namen anderer Spieler speichern (AH-Verkäufer, Käufer aus Rechnungen nur als „vorhanden ja/nein").
- **Vor Veröffentlichung:** Repo auf public stellen (Richtlinie „Code vollständig sichtbar"), Audit-Checkliste in `docs/07-AUDIT.md` erneut durchgehen.
- **Dateibesitz:** Nur die Dateien des eigenen WP ändern. Neue Dateien: erst als Stub anlegen und in `Goldweaver.toc` eintragen (Besitzer Core), dann füllen. Schnittstellen in `docs/06-SCHNITTSTELLEN.md` eintragen, bevor andere darauf aufbauen.

## Architektur und Datensicherheit (docs/13-ARCHITEKTUR.md)
- Modul-Vertrag: `ns:RegisterModule(name, { Init, SelfTest })`, öffentliche Funktionen nur unter `ns.<Modul>`, Dateikopf mit Zweck/API/Datenpfad.
- Erweiterungen über Registries (Preisquellen, Advisor-Provider, Post-Regeln, Prüfungen, Features, Profile, Tabs), nicht durch Umbauen bestehender Funktionen.
- **Nutzerdaten nie zurücksetzen.** Strukturänderungen nur als nummerierte, additive Migration in `Core/DB.lua` mit Test in `tools/tests/migration_test.lua`; vor jeder Migration entsteht automatisch ein Backup (`GoldweaverBackupDB`).

## Kompatibilität (docs/10-KOMPATIBILITAET.md)
- Spiel-APIs über `ns.API` oder nach `ns.API.Has(...)`-Prüfung aufrufen; neue Abhängigkeiten in `Features.Define` eintragen. Nie auf Build, Interface-Nummer oder `WOW_PROJECT_ID` verzweigen.
- `ns.Events:On(event, fn, "Modulname")` immer mit Modulname; jedes Modul liefert `SelfTest()` für `/gw debug run`.
- SavedVariables-Strukturänderungen nur mit neuer `SCHEMA`-Nummer und Migration in `Core/DB.lua`.
- Frame-Template-Kinder (z. B. `.Inset`) nie voraussetzen; eigene Frames bauen.

## Konventionen
- Dateikopf: `local ADDON, ns = ...`. Nur ein Global: `Goldweaver` (einzige Ausnahme: die vom Spiel vorgegebenen Tastenbelegungs-Texte `BINDING_HEADER_GOLDWEAVER`/`BINDING_NAME_GOLDWEAVER_*`).
- SavedVariables: `GoldweaverDB` (Account), `GoldweaverCharDB` (Charakter). Init nur in `ADDON_LOADED`. Preise unter `GoldweaverDB.prices[marketKey][itemID]`, `marketKey` = Regelsatz + Fraktion (Fallback Realm), nie `Name-Realm` für Charaktere ohne Prüfung des Namensformats (F3).
- Geld immer in Kupfer (Integer); Formatierung über `ns.Util.Money(copper)`.
- Preise tragen `{copper, source, age, confidence}`; Anzeige nennt Quelle und Alter.
- Texte über `ns.L["English text"]`: der englische Text im Code ist der Schlüssel, die deutsche Übersetzung steht in `Locales/deDE.lua` (Platzhalter gleich und in gleicher Reihenfolge). `ns.L` nie beim Laden der Datei auswerten (Konstanten, Tab-Titel, Slash-Hilfe behalten den englischen Schlüssel und werden bei der Anzeige übersetzt). Text, der mit Spieltext verglichen wird, bleibt unübersetzt und trägt den Kommentar `-- locale-ok`. `tools/tests/locale_test.lua` und der Simulator prüfen beides automatisch.
- Chat-Ausgaben über `ns.Print(...)`, Debug über `ns.Log(...)` (nur mit `/gw debug on`).
- Kein `OnUpdate`-Polling; Batches großer Datenmengen über `C_Timer.After`/Frames.
- Geschützte Frame-Änderungen: `InCombatLockdown()` prüfen, bei `PLAYER_REGEN_ENABLED` nachholen.

## Prüfen
- `tools/check.ps1` (Syntax über LuaJIT auf alle Dateien, luacheck, Headless-Tests in `tools/tests/`). Muss grün sein, bevor ein WP als fertig gilt. Toolchain ist installiert: LuaJIT unter `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `luacheck.exe` unter `%LOCALAPPDATA%\Programs\luacheck` (beide im Benutzer-PATH).
- UI-Änderungen: Layout-Prüfung läuft im Simulator mit; `tools/preview.ps1` zeichnet jeden Reiter als Bild nach `scratch/preview` (ohne Spiel). Neue Grafiken nur über `tools/assets/make_assets.py`.
- In-game: `/console scriptErrors 1`, `/gw probe` nach jedem Patch (Interface-Nummer), `/reload` nach Änderungen.
- Dev-Setup: Junction `mklink /J "<WoW>\_forever_\Interface\AddOns\Goldweaver" "<Repo>\Goldweaver"` (Ordnername des Forever-Clients beim ersten Start prüfen; in der Beta hieß er `_classic_beta_`).

## Abschluss eines WP
- `CHANGELOG.md` unter „Unreleased" ergänzen: Englisch, aus Spielersicht, nur was sich für Spieler ändert (wird auf CurseForge gezeigt). Interne Details gehören in die Commit-Nachricht.
- Offene Fragen in `docs/02-ROADMAP.md` aktualisieren.
- Checkliste `docs/04-COMPLIANCE.md` Abschnitt 3 für jede geänderte Datei durchgehen.

## Sprache
Dokumente und Chat Deutsch (Ausnahme: alles, was veröffentlicht wird, ist Englisch: `README.md`, `CHANGELOG.md`, `docs/16-PROJECT-PAGE.md`), Code-Bezeichner und Kommentare Englisch, Spielbegriffe in Lokalisierungsdateien.

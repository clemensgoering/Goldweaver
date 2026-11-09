# Goldweaver – Architektur und Erweiterungsleitfaden

Stand: 08.11.2026. Für jede Session, die Code anfasst. Ergänzt `06-SCHNITTSTELLEN.md` (Signaturen) und `10-KOMPATIBILITAET.md` (API-Schutz).

## 1. Schichten und Laderegel

```
Locales/      enUS.lua: Sprachkern (ns.L, ns.Locale, Schlüssel = englischer Text); deDE.lua: deutsche Tabelle
Core/         Init · Util · Secret · Events · API · DB · Chars · Inventory · Price · Graph · Probe
Data/         statische Tabellen: Entzaubern, Kisten, Händler-Reagenzien, Umwandlungen
Professions/  Registry (Profile) · Adapter (Spiel-API → Rezeptbuch) · ein Profil je Beruf
UI/           Kit (Widgets, Fenster) · MainWindow (Tabs) · Tooltip · Minimap
Modules/      Checks · Learn · Advisor · HUD · Mail · Destroy · Planner · CraftProfit · Compare · Auction · Ledger · Dashboard · Onboarding · Contacts · Debug
```
Die TOC-Reihenfolge ist die Abhängigkeitsrichtung: Eine Schicht benutzt nur Schichten oberhalb von sich. `Modules/` dürfen untereinander nur über die in `06-SCHNITTSTELLEN.md` dokumentierten Funktionen sprechen und prüfen die Existenz (`if ns.Learn then …`), weil Module einzeln abschaltbar sind.

## 2. Modul-Vertrag
```lua
local ADDON, ns = ...
local Thing = {}
ns.Thing = Thing                     -- öffentliche Funktionen nur hier
ns:RegisterModule("Thing", {
  Init = function() ... end,         -- nach ADDON_LOADED, ns.db bereit; Events und Hooks hier anmelden
  SelfTest = function() return { { name = "...", ok = true, warn = false, detail = "..." } } end,
})
```
- Dateikopf: Zweck, öffentliche API, Datenpfad in `GoldweaverDB`, Besonderheiten.
- Events über `ns.Events:On(event, fn, "Thing")`; der Name wird sonst aus dem Dateinamen abgeleitet.
- Spiel-APIs über `ns.API` oder nach `ns.API.Has`-Prüfung; neue Abhängigkeiten in `Features.Define`.
- Reine Logik (Formeln, Tabellen) ohne Spiel-API, damit sie headless testbar ist; Spiel-Zugriffe in dünnen Adaptern.
- Fehler nie unterdrücken, sondern `ns.Health.Record(where, err)`, damit sie im Bericht erscheinen.

## 3. Erweiterungspunkte (Registries)

| Was hinzufügen | Wo | Wie |
|---|---|---|
| Neuer Beruf | `Professions/<Beruf>.lua` | `ns.Professions:Register{ key, name, skillLineID, category, crateCategories, vendorReagents, trainers, seedPath, notes }`; TOC-Eintrag |
| Neue Preisquelle | beliebiges Modul | `ns.Price.RegisterSource(name, priority, fn(itemID) → copper, age, count)` |
| Neue Advisor-Option | beliebiges Modul | `ns.Advisor.RegisterProvider(name, fn(item, ctx, helpers) → option | {options})` |
| Neue Post-Regel | beliebiges Modul | `ns.Mail.AddRule(name, fn(item, info, me, processors) → rec, reason | false, reason | nil, position?)` |
| Neue Umwandlung | `Data/Conversions.lua` oder live | `ns.Graph.Add{ id, kind, profession, inputs, outputs, source }` |
| Neue Prüfung | `Modules/Checks.lua` | `Checks.Define(id, { group, title, hint })`, bestanden per `ns.Checks.Pass(id, detail)` am Ort des Beweises |
| Neue Lernfrage | `Modules/Learn.lua` | Beobachter-Funktion + Eintrag in `Learn.Status()`; Ergebnis in `GoldweaverDB.learned` |
| Neues Feature-Gate | `Core/API.lua` | `Features.Define(name, { label, requires = { "C_X.Y" } })`; im Modul `Features.Available(name)` |
| Neuer Fenster-Tab | `UI/MainWindow.lua` oder eigenes Modul | `ns.UI.RegisterTab(key, title, builder(frame) → { Refresh = fn })` (Regel: höchstens vier Tabs, `08-UX.md`) |
| Neuer Slash-Befehl | eigenes Modul | `ns.Slash.Register(cmd, fn(rest), help)` |
| Neue Einstellung | `Core/DB.lua` DEFAULTS + Einstellungen-Tab | nur mit funktionierendem Standard; höchstens zehn sichtbare Schalter |

## 4. Datensicherheit bei Updates (verbindlich)
1. **Nie zurücksetzen.** `applyDefaults` ergänzt nur fehlende Schlüssel; vorhandene Werte und unbekannte Schlüssel bleiben. Kein Code darf `GoldweaverDB` oder Untertabellen leeren, außer der Nutzer befiehlt es (`/gw checks reset`, `/gw restore confirm`).
2. **Schema-Migrationen** in `Core/DB.lua`: nummeriert, additiv (umbenennen, verschieben, ergänzen; nie löschen), idempotent, jeweils ein Test in `tools/tests/migration_test.lua`, der eine alte Datenbank durch die Migration schickt und prüft, dass nichts fehlt.
3. **Backup vor jeder Migration** nach `GoldweaverBackupDB` (eigene SavedVariable, eine Generation). `/gw backup` manuell, `/gw restore confirm` stellt wieder her. Der Debug-Bericht zeigt Alter und Grund des Backups.
4. **Aufbewahrung:** Charaktere, Rollen, Berufe, Rezeptbücher, Gelerntes, Kontakte, Händlerpreise, Prüfungen und Kisten-Tooltips werden unbegrenzt aufbewahrt. Begrenzt sind nur Preis-Tageshistorie (`settings.priceHistoryDays`, Standard 30, das aktuelle Minimum bleibt), Debug-Log (200 Zeilen), Fehler (50), Ledger-Einträge (2000), Entzauber-Beobachtungen (500), Einzahlungsproben (30).
5. **Vorwärtskompatibel:** Ein älteres Addon, das auf eine neuere Datenbank trifft, lässt unbekannte Felder stehen und arbeitet mit den bekannten.
6. **Keys stabil halten:** Charaktere unter „Vorname Nachname", Märkte unter „Region-Regelsatz-Fraktion". Änderungen daran nur per Migration mit Umschlüsselung (Vorbild `Chars.Migrate`).

## 5. Testen
- `tools/check.ps1` / `tools/check.sh`: Syntax (LuaJIT, 5.1-kompatibel), luacheck, Headless-Tests (`tools/tests/*_test.lua`, Stub-Umgebung in `run.lua`).
- Headless getestet sind: Util, Secret, Events (Isolierung), API/Features, DB (Defaults, Migration, Backup), Chars (Namen, Markt, Migration), Price, Graph, Entzaubern, Kisten, Advisor, Planer, Profit, Vergleich, Checks, Learn, Post-Regeln.
- Im Spiel prüft `Modules/Checks.lua` automatisch; `/gw debug run` ist der Übergabe-Bericht.

## 6. Stil
- Deutsch für Nutzertexte (Lokalisierung als Backlog B10), Englisch für Bezeichner und Kommentare.
- Eine Datei, ein Zweck; Datei > 400 Zeilen aufteilen (Kandidat: `UI/MainWindow.lua` → ein Tab je Datei).
- Keine Magic Numbers ohne Namen (Skill-Lines, Klassen-IDs, Spell-IDs als benannte Konstanten).
- Jede Zahl, die ein Nutzer sieht, trägt Quelle und Alter (`08-UX.md` Regel 6).

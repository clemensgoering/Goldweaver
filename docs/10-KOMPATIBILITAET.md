# Goldweaver – Langfristige Kompatibilität

Stand: 08.11.2026. Forever ist ein junger Client: Die Beta hat die API mehrfach geändert, Midnight-Regeln kommen nach, Interface-Nummer und Frame-Templates können mit jedem Patch wechseln. Diese Maßnahmen sorgen dafür, dass Goldweaver bei Änderungen **leise degradiert** statt zu brechen, und dass wir in Minuten wissen, was zu reparieren ist.

## 1. Fähigkeiten prüfen, nie Versionen
- Kein Branching auf `WOW_PROJECT_ID`, Build oder Interface-Nummer. Jede Funktion wird vor Gebrauch auf Existenz geprüft: `ns.API.Has("C_Item.GetItemInfo")`.
- **Kompatibilitätsschicht `Core/API.lua`:** Zugriffe auf Items, Taschen und weitere Spiel-APIs laufen über `ns.API.*`. Die Wrapper normalisieren Rückgabewerte in Tabellen (`API.ItemInfo(id).sellPrice`), sodass eine geänderte Signatur an genau einer Stelle angepasst wird. Fehlgeschlagene Aufrufe liefern `nil` und werden in `ns.API.failures` gezählt.
- **Features `ns.Features`:** Jede Funktionsgruppe deklariert, welche APIs sie braucht (`tooltip`, `mail`, `professions`, `craft`, `disenchant`, `auction`, `auctionSell`, `contacts`, `minimap`, …). Fehlt eine API, bleibt das Feature schlafend und der Debug-Bericht nennt die fehlende Funktion. Der Nutzer kann Features mit `/gw feature <name> off` abschalten.

## 2. Fehler isolieren
- Jeder Event-Handler läuft in `pcall` mit Secret-Guard. Nach fünf Fehlern wird genau dieser Handler abgehängt und gemeldet; der Rest des Addons läuft weiter (`Core/Events.lua`).
- Jedes Modul startet in `pcall`; ein Modul, das nicht startet, wird im Chat und im Bericht genannt, die anderen laufen.
- Fehler landen in `ns.Health.errors` und `GoldweaverDB.debug.errors` (letzte 50) und erscheinen im Debug-Bericht mit Ereignis, Modul und Meldung.

## 3. Daten versionieren
- `GoldweaverDB.schema` mit Migrationsliste in `Core/DB.lua`. Jede Strukturänderung bekommt eine Nummer und eine Migrationsfunktion; alte SavedVariables werden beim Laden nachgezogen, nie verworfen.
- Charakter- und Markt-Keys werden durch `Chars.Migrate` normalisiert (Beispiel 08.11.: „Cupedos-Grel" → „Cupedos Grel", Realm-Key → `EU-PvE-Horde`).
- Daten aus Guides tragen `verified = false` bzw. `~` in der Anzeige, bis sie im Spiel bestätigt sind.

## 4. Patch erkennen
- `ns.INTERFACE` (16001) wird beim Login mit `GetBuildInfo()` verglichen. Weicht der Client ab, erscheint ein Hinweis mit der Bitte, `/gw debug run` auszuführen und den Bericht weiterzugeben. Ein neuer Build wird einmalig gemeldet.
- `/gw probe` bleibt als tiefer API-Check erhalten und ist Teil des Berichts.

## 5. Debug-Bericht (`/gw debug run`)
Führt alles aus, was im aktuellen Kontext möglich ist, und öffnet ein Fenster mit kopierbarem Text („Alles markieren", dann Strg+C). Inhalt:
1. Client (Version, Build, Interface, Locale, Charakter, andere Addons)
2. Features mit fehlenden APIs, API-Fehlschläge
3. Selbsttest jedes Moduls (`SelfTest()` liefert Zeilen mit ok / Warnung / Fehler)
4. Daten (Charaktere, Berufe, Rezeptbücher, Preise, Einstellungen, Graph)
5. Events, Secret-Guard-Zähler, abgehängte Handler
6. Fehler der Sitzung
7. Kontextabhängige Probes (Berufefenster, AH, Briefkasten, wenn offen)
8. Gespeicherte Probe-Ergebnisse inklusive aller Rezeptfelder
9. Debug-Log (Ringpuffer, immer aktiv, 200 Zeilen)

Der Bericht liegt zusätzlich in `GoldweaverDB.debug.report`. Ein Fehlerbericht an die Entwicklung besteht aus diesem Text plus einem Satz, was erwartet wurde.

## 6. Regeln für neue Module (für alle Sessions)
1. Spiel-APIs nur über `ns.API` oder nach `ns.API.Has`-Prüfung; neue Abhängigkeiten in `Features.Define` eintragen.
2. `ns.Events:On(event, fn, "Modulname")` mit Modulnamen, damit Fehler zugeordnet werden.
3. Jedes Modul liefert `SelfTest()` mit mindestens einer aussagekräftigen Zeile.
4. Frame-Templates nie als gegeben voraussetzen: Kinder wie `.Inset` prüfen, sonst eigene Frames (Beispiel: Fensterkörper).
5. Strukturänderungen an SavedVariables nur mit neuer `SCHEMA`-Nummer und Migration.
6. Beobachtungen vor Annahmen: Lieber Daten im Spiel sammeln (Contacts, Observations) als Tabellen hartkodieren.

## 7. Prüfroutine nach jedem Patch
1. `/reload`, Chat auf Interface-Hinweis prüfen.
2. `/gw debug run`, Bericht lesen: fehlende APIs in „Features", rote Zeilen in „Module".
3. Berufefenster, AH und Briefkasten öffnen, `/gw debug run` erneut (kontextabhängige Probes).
4. Bericht in ein Issue oder an die Entwicklungs-Session geben; dort gezielt die betroffenen Wrapper anpassen; `tools/check.ps1` grün; Release.

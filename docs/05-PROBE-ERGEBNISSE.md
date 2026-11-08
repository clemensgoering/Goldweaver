# Phase 0 – Probe-Ergebnisse (in-game)

Stand: noch nicht ausgeführt. Ablauf: im Spiel `/console scriptErrors 1`, dann die Befehle unten in dieser Reihenfolge ausführen, Chat-Ausgabe hier eintragen (oder nach `/reload` aus `WTF\Account\<Account>\SavedVariables\Goldweaver.lua` den Block `probe` kopieren).

| Schritt | Befehl | Wo | Beantwortet |
|---|---|---|---|
| 1 | `/gw probe` | überall | F3 (Namensformat, Realm-Funktionen), F5 (TooltipDataProcessor), F8 (Interface), API-Verfügbarkeit |
| 2 | `/gw probe items` (zweimal, mit 5 s Abstand) | überall | Item-IDs der Datentabellen stimmen (MISMATCH-Zeilen) |
| 3 | `/gw probe prof` | im geöffneten Berufefenster, je Beruf einmal, Verzauberkunst zusätzlich | F2 |
| 4 | `/gw probe ah` | am Auktionshaus | F6 (Laufzeiten, Einzahlung), Throttle-Status, Suchlatenz |
| 5 | `/gw probe replicate` | am Auktionshaus, einmal | F1 |
| 6 | `/gw probe mail` | am Briefkasten mit einer AH-Rechnung im Posteingang | Rechnungsfelder, Einzahlungsrückerstattung |
| 7 | `/gw probe secure` | außerhalb des Kampfs | F4 |
| 8 | Kiste öffnen, Tooltip ablesen | Waylaid Crate | F7 (Bündelgrößen, Favor) |

## Ergebnisse

### 1 Allgemein
```
(Chat-Ausgabe hier einfügen)
```
Entscheidungen: Markt-Key = … · Namensformat = … · Tooltip-Pfad = …

### 2 Items
```
```

### 3 Berufe
| Beruf | API, die antwortet | Rezeptfelder | Bemerkung |
|---|---|---|---|
| Schneiderei | | | |
| Verzauberkunst | | | |

### 4 Auktionshaus
```
```
Laufzeiten: … · Einzahlung 1× Leinenstoff: … · Suchlatenz: …

### 5 Replicate
```
```
Entscheidung Vollscan (WP3.4): ja / nein, Begründung: …

### 6 Post
```
```

### 7 Secure
```
```
Entscheidung Zerlegen-Queue (WP1.6): Secure-Button / Fallback: …

### 8 Kisten
| Kategorie | Rang | Bündel | Favor |
|---|---|---|---|
| | | | |

## Übertrag in die Dokumente
- [ ] `02-ROADMAP.md` Tabelle „Offene Fragen" ausgefüllt
- [ ] `01-KONZEPT.md` Abschnitt 5.1 Status-Spalte aktualisiert
- [ ] `Data/*.lua` `verified = true` gesetzt, wo bestätigt

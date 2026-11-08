# Phase 0 – Probe-Ergebnisse (in-game)

Stand: erster Lauf am 08.11.2026 auf Build 1.60.1.70862 (deDE, Horde, „CAMWOW EU4 Realm 5 PvE"). Ergebnisse unten; offen sind noch Berufefenster-Dump, Replicate, Post mit AH-Rechnung, Secure-Button, Kisten.

**Ergebnisse Lauf 1**
- Interface 16001 live bestätigt, `WOW_PROJECT_ID` 18. Addon lädt ohne Fehler, 245 kB Speicher. → F8 beantwortet.
- `UnitFullName("player")` = Vorname, Nachname („Cupedos", „Grel"). `GetRealmName()` = „CAMWOW EU4 Realm 5 PvE", `GetNormalizedRealmName()` = „CAMWOWEU4Realm5PvE", `GetAutoCompleteRealms()` leer. Region und Regelsatz stehen im Realmnamen. → F3 beantwortet: Registry-Key „Vorname Nachname", Markt-Key „EU-PvE-Horde". Postempfänger-Format noch zu prüfen (F10).
- Fehlende APIs: `C_TradeSkillUI.GetRecipeTools`, alle Legacy-Berufe-APIs (`GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillReagentInfo`, `DoTradeSkill`, `GetNumCrafts`, `GetCraftInfo`, `GetCraftReagentInfo`, `DoCraft`), `C_RestrictedActions.IsRestricted`. Vorhanden: `TooltipDataProcessor.AddTooltipPostCall`, `C_TooltipInfo`, `C_AuctionHouse.ReplicateItems`, Post-APIs, `GetProfessions`. → F2: nur `C_TradeSkillUI`, keine Fallback-Kette nötig. F5: TooltipDataProcessor ja.
- `GetProfessions`/`GetProfessionInfo` liefern Name, Rang, Maximum und Skill-Line (165, 393, 129, 356, 185 bestätigt).
- Items: alle 95 IDs lösen auf (deutsche Namen, IDs korrekt).
- AH: Throttle bereit, Laufzeiten **2 / 8 / 24 Stunden** (`AUCTION_DURATION_*`), Time-Left-Bands Short 0 · Medium 1 · Long 2 · VeryLong 3. Einzahlung 1× Leinenstoff = **1 Silber** für alle drei Laufzeiten (pauschales Minimum, bekannter Beta-Befund). → F6 teilweise: Laufzeiten ja, Einzahlungsformel durch echte Rechnung prüfen.
- Berufefenster-Dump war leer: `C_TradeSkillUI.GetAllRecipeIDs` liefert erst Daten, wenn ein konkreter Beruf geöffnet ist. Probe wartet jetzt auf `TRADE_SKILL_LIST_UPDATE`.
- Secure-Button erschien nicht sichtbar (Ursache offen, vermutlich kein Button-Artwork). Probe zeigt jetzt einen großen Button mit PreClick/PostClick-Meldungen.

**Ergebnisse Lauf 2 und 3 (08.11.2026)**
- Berufefenster: `C_TradeSkillUI.GetAllRecipeIDs` liefert 132 (Kochkunst), 592 (Lederverarbeitung), 471 (Schneiderei) Rezept-IDs. `GetRecipeInfo` → `name`, `difficulty` (Zahl), `learned`; `GetRecipeSchematic` → 3 Reagenz-Slots, `quantityMin/Max`. → F2 beantwortet.
- Secure: `/run print(...)` im Makrotext ohne Wirkung, `/dance` wird ausgeführt (Charakter tanzt). → F4 ja, F12 `/run` gesperrt.
- Replicate: AH offen, Throttle bereit, Aufruf ohne Fehler, nach 15/45/90 s kein `REPLICATE_ITEM_LIST_UPDATE`, `GetNumReplicateItems() = 0`. → F1/F13: kein Vollscan auf Forever, WP3.4 gestrichen.
- Fenster: `BasicFrameTemplateWithInset` hat kein nutzbares `.Inset`; eigener Body-Frame eingebaut. Ablauf: im Spiel `/console scriptErrors 1`, dann die Befehle unten in dieser Reihenfolge ausführen, Chat-Ausgabe hier eintragen (oder nach `/reload` aus `WTF\Account\<Account>\SavedVariables\Goldweaver.lua` den Block `probe` kopieren).

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

## Abnahme 0.1.0 (Abend 08.11.2026)

Reihenfolge für den Test, pro Punkt ein Häkchen oder eine Notiz:

| # | Schritt | Erwartung | Ergebnis |
|---|---|---|---|
| A1 | `/reload`, Main einloggen | Keine Lua-Fehler, Minimap-Button, HUD-Zeile oben („Für Cupedos Bank: …") | |
| A2 | Items in der Tasche anschauen | Goldene Goldweaver-Zeile mit „an Cupedos Bank schicken → …" bei Material/Grünen; mit Shift alle Optionen und Preisquelle | |
| A3 | Briefkasten öffnen | Knopf „Anhängen für Cupedos Bank: N von M Items (Wert)"; Klick füllt Empfänger und Anhänge; zweiter Klick „Senden an …" sendet | |
| A4 | Twink einloggen, Post abholen | „Alles abholen" leert Post mit Anhängen/Geld; Zeile „Heute verkauft …" | |
| A5 | Berufefenster Schneiderei öffnen, dann `/gw` → Berufe | Status mit Skill/Rang/Lehrer, Nächster Skill-up mit Icons und Einkaufsliste, Lohnt sich, Noch nicht gelernt; „Herstellen ×N" aktiv bei offenem Fenster | |
| A6 | `/gw probe prof` bei offenem Fenster | Zwei Zeilen „learned recipe … / unlearned recipe …" mit allen Feldern (für `sourceType`/Skill-Anforderung) → hier eintragen | |
| A7 | `/gw de` beim Twink mit grünen Items | Liste und Button „Entzaubern: <Item> (≈…)"; Klick entzaubert genau ein Item | |
| A8 | AH: Leinenstoff suchen, dann Leinenstoff in den Verkaufen-Tab legen | Unter dem AH-Fenster die Vorschlagszeile, Preis vorbelegt; Tooltip zeigt danach „selbst gesehen" als Quelle | |
| A9 | Lehrer und einen Händler besuchen, `/gw contacts` | Beide gelistet mit Zone und Koordinaten | |
| A10 | `/gw` → Heute | Bis zu drei Empfehlungen, klickbar; Verkäufe/Session-Gold | |
| A11 | Einstellungen | Sechs Schalter wirken sofort (Minimap, HUD, Tooltip, AH-Vorbelegung, eigene Materialien, Debug) | |

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

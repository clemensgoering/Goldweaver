# Goldweaver – Der Leitfaden (Berufe-Tab und seine Datenquellen)

Stand: 08.11.2026 (Version 0.1.0-dev, erster vollständiger Durchstich). Ergänzt `08-UX.md`; wo beide abweichen, gilt dieses Dokument für den Berufe-Tab.

## 1. Anspruch
Das Fenster ist kein Einstellungsdialog, sondern ein **Leitfaden**, der pro Charakter und Beruf vier Fragen beantwortet:
1. **Was soll ich als Nächstes herstellen**, um günstig weiterzukommen, und was fehlt mir dafür?
2. **Was lohnt sich** mit dem, was ich schon kann?
3. **Was kann ich noch lernen**, und wo bekomme ich es?
4. **Wann und wo** lerne ich den nächsten Rang?

Dazu die Querschnittsfragen auf dem Main: *Was schicke ich wem?* (Tooltip, Briefkasten, HUD) und beim Verarbeiter: *Was entzaubere ich, was verkaufe ich?* (Entzauber-Queue, AH-Vorschlag).

## 2. Was die Galerien der Vergleichs-Addons zeigen

| Addon | Muster, das wir übernehmen | Muster, das wir vermeiden |
|---|---|---|
| ForeverArtisan (24 Screenshots) | „Cheapest to level": Rezepte, die noch Skill-ups geben, nach Kosten pro Punkt. „Plan + Shopping list": Zielskill eingeben, Crafts und bepreiste Einkaufsliste. „Recipe book": Hover auf unbekanntes Rezept zeigt, wer es verkauft. „Time to train": am Cap sagt es das und plant den nächsten Rang. | 14 Module, 14 Slash-Aliasse, je Beruf ein eigenes Fenster mit vier Tabs. |
| TSM Crafting | Rezeptliste mit Profit-Spalte, Queue, „Gathering"-Liste. | Gruppen/Operationen als Voraussetzung. |
| Skillet | Skill-up-Farbe und Prozentchance pro Rezept, Einkaufsliste, Händler-Integration. | Ersetzt das Blizzard-Berufefenster komplett. |
| Auctionator | Ein Tab im Blizzard-Fenster, Tooltip-Preise. | – |
| Gold Forever | Crafting-Hub mit Queue, Ledger, einzeiliges HUD. | Eigene AH-Panels doppelt zu Auctionator. |

Konsequenz: **Ein** Berufe-Tab mit Berufsauswahl oben, darunter vier feste Blöcke mit Item-Icons. Keine Unterfenster, keine Untermenüs, Dropdowns nur, wenn mehr als sechs Berufe gewählt werden könnten (derzeit Buttons).

## 3. Aufbau des Berufe-Tabs (umgesetzt)

```
[Schneiderei] [Verzauberkunst] [Kochkunst] …                              [Vergleich]
┌ STATUS ──────────────────────────────────────────────────────────────────────────┐
│ Schneiderei 53 / 75 · Lehrling → Geselle ab Skill 50 und Level 10 (jetzt lernbar!)│
│ Lernen bei: Magar (Orgrimmar), Rhiannon Davis (Undercity), …                     │
│ Rezepte: 12 von 471 gelernt · Fenster zuletzt gelesen vor 3 min                  │
└──────────────────────────────────────────────────────────────────────────────────┘
┌ NÄCHSTER SKILL-UP ───────────────────────────────────────────────────────────────┐
│ [icon] Leinengürtel ×20                                    ≈ 1s 60c je Punkt      │
│        Skill-up-Chance 100 % · Materialkosten 1s 60c je Stück · Produkt ≈ 3s 80c  │
│ [icon] Leinenbolzen            fehlen 20 · 30s          [Herstellen ×20]          │
│        brauche 20 · habe 0 (Taschen 0, Bank 0)          [Fehlendes im AH suchen]  │
│ [icon] Grober Faden            vorhanden                                          │
│ Alternativen: Leinenbolzen (2s 85c/Pkt) · …                                       │
└──────────────────────────────────────────────────────────────────────────────────┘
┌ LOHNT SICH (nach AH-Cut) ──────────────┐ ┌ NOCH NICHT GELERNT (459) ─────────────┐
│ [icon] Leinenbeutel          +12s 40c  │ │ [icon] Wollener Umhang   Quelle …      │
│        Kosten 48s → Erlös 60s 40c      │ │        1× Wollbolzen, 1× Feiner Faden  │
│ …                                       │ │ …                                      │
└────────────────────────────────────────┘ └────────────────────────────────────────┘
```
- **Berufsauswahl:** ein Button je Beruf des eingeloggten Charakters; „Vergleich" zeigt stattdessen die Tabelle „Welcher Beruf lohnt sich als Nächstes" (Kosten bis 300 aus Startpfaden, davon schon im Besitz, Status).
- **Status:** Skill, Rang, Bedingungen des nächsten Rangs, Lehrer-Hinweis (aus dem Profil, später aus besuchten Lehrern), Rezeptzähler und Alter der Daten.
- **Nächster Skill-up:** bestes Rezept nach erwarteten Kosten pro Skillpunkt (Materialkosten minus Produktwert, geteilt durch Skill-up-Chance), Reagenzien mit habe/brauche über Taschen, Bank und Twinks, zwei Aktionen: *Herstellen* (nur bei offenem Berufefenster, ein Klick) und *Fehlendes im AH suchen* (füllt die Suche, ohne Anfrage zu senden).
- **Lohnt sich:** gelernte Rezepte mit Marge nach Cut.
- **Noch nicht gelernt:** ungelernte Rezepte des Buchs mit Reagenzien; die Quelle (Lehrer, Händler, Drop) kommt aus dem Feld `sourceType`, sobald die Probe es bestätigt, sonst aus dem Trade-Contacts-Rekorder.

## 4. Datenquellen und ihr Stand

| Frage | Quelle | Stand |
|---|---|---|
| Rezepte, Farbe, Reagenzien, gelernt/ungelernt | `C_TradeSkillUI` beim Öffnen eines Berufs; Cache in `GoldweaverDB.recipes[skillLine]`, gelernte IDs je Charakter | umgesetzt (Adapter) |
| Skill-up-Chance je Farbe | Faustwerte 100/75/35 %, Kalibrierung aus eigenen Craft-Logs (F11) | Faustwerte |
| Preise | Auctionator-API → selbst gesehene AH-Seiten (werden beim Suchen mitgelesen) → Händlerpreis | umgesetzt |
| Bestand | Taschen live, Bank beim Bankbesuch, Twinks aus deren Snapshots | umgesetzt |
| Rang-Bedingungen | Profil (75/150/225/300; Skill 50/125/200; Level 10/20/35) | Startwerte, Probe im Spiel beim Lehrer |
| Wo lerne ich den Rang | Profil-Text aus Beta-Guides; besuchte Lehrer aus dem Rekorder (`/gw contacts`) | Schneiderei/Verzauberkunst mit Text, Rekorder umgesetzt |
| Wo gibt es ein Rezept | `sourceType` (zu prüfen) + Händler-Rekorder (limitierte Bestände markiert) | teilweise |
| Wertvolle Rezepte in der Welt | kuratierte Liste je Profil (`profile.notableRecipes`) | noch nicht, siehe Abschnitt 6 |

## 5. Querschnitt: Tooltip, Post, Entzaubern, AH (umgesetzt)
- **Tooltip:** `Goldweaver: an Nerion schicken → Bolzen ≈ 1g 42s`, mit Shift alle Optionen und Preisquelle, dazu Bestandszeile (Taschen, Bank, Twinks), wenn etwas jenseits der Taschen liegt.
- **Briefkasten:** `Anhängen für Nerion: 12 von 17 Items (5g 10s)` → `Senden an Nerion (12 Anhänge)`; `Alles abholen` liest Rechnungen ins Ledger. Regeln: Handwerksmaterial zum Verarbeiter, der den passenden Beruf hat; Materialien eigener Berufe bleiben (abschaltbar); grüne Ausrüstung zum Verzauberer; Rezepte zum passenden Beruf.
- **Entzaubern (`/gw de`):** Liste der Items, bei denen Entzaubern mehr bringt als Verkaufen; ein Secure-Button je Klick (`/cast Entzaubern` + `/use Tasche Platz`); Ergebnisse werden für die Kalibrierung geloggt.
- **AH:** jede gesehene Suchseite füllt die Preis-DB; im Verkaufen-Tab erscheint unter dem Fenster der Vorschlag mit Unterbietung, Einzahlung und Erlös nach Cut, der Preis wird vorbelegt (abschaltbar).
- **HUD:** eine Zeile für Mains: `Für Nerion: 4g 32s (17) · Session +2g 10s`.
- **Heute:** bis zu drei Empfehlungen aus Rollen, Post, Entzaubern, Skill-up und bestem Craft; Verkäufe heute/7 Tage, Session-Gold.

## 6. Nächste Ausbaustufen (nach Abnahme)
1. **Rezeptquellen anzeigen:** `sourceType` aus der Probe auswerten (`/gw probe prof` druckt jetzt alle Felder eines gelernten und eines ungelernten Rezepts); Händler mit limitiertem Bestand aus dem Rekorder in „Noch nicht gelernt" einblenden; Waypoint per Klick (`C_Map.SetUserWaypoint`), wenn Position bekannt.
2. **Kuratierte Highlights je Profil:** 5–10 wertvolle Rezepte pro Beruf mit Fundort-Typ (Drop/Vendor/Quest), als `notableRecipes` im Profil, gekennzeichnet als unbestätigt.
3. **Zehn weitere Profile** (WP2.4) mit Rang-Lehrern und Startpfaden; Sammelberufe mit Zonen-Sicht.
4. **Lernen am Lehrer:** am geöffneten Lehrerfenster den nächsten Rang und die günstigsten Rezepte markieren (`BuyTrainerService` nur per Klick).
5. **Kaufen im AH:** Einkaufsliste aus dem Plan als Auctionator-Shopping-Liste exportieren (API `CreateShoppingList`), ohne eigenen Kaufautomatismus.
6. **Kalibrierung:** Skill-up-Chancen und Entzauber-Ausbeuten aus `GoldweaverDB.observations` zurückrechnen.

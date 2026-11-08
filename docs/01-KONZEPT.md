# Goldweaver – Konzept (WoW: Forever)

Stand: 08.11.2026 · Status: Entwurf zur Freigabe · Zielclient: World of Warcraft: Forever 1.60.x (Interface 16001)

> Arbeitstitel **Goldweaver**. Der Ordnername `Auctionator` dieses Repos ist nur der Projektordner.
> Das Addon selbst darf **nicht** `Auctionator` heißen: Der Addon-Ordner muss dem TOC-Namen entsprechen und würde mit dem echten
> Auctionator in `Interface\AddOns` kollidieren, das wir optional als Preisquelle nutzen. Vor Veröffentlichung Namensprüfung auf CurseForge/Wago.

> **Geltungsbereich:** Goldweaver ist von Anfang an für **alle zwölf Berufe** (plus Camping-/Favor-System) ausgelegt. Schneiderei und
> Verzauberkunst sind nur der erste Durchstich, weil der Twink damit startet. Die Engine kennt keine Beruf-Sonderfälle; jeder Beruf ist ein
> Datenprofil (Abschnitt 4.3). Berufswechsel oder zusätzliche Berufe erfordern keine Codeänderung.

---

## 1. Ausgangslage: Was WoW: Forever für dieses Addon bedeutet

Recherchiert am 08.11.2026 (Quellen und Vertrauensgrad in `03-RECHERCHE-QUELLEN.md`).

| Thema | Befund | Konsequenz für Goldweaver |
|---|---|---|
| Was ist Forever | Offizieller dritter Blizzard-Zweig neben Retail und Classic, Launch 04./05.11.2026. Level 60, Vanilla-Welt mit neuen Inhalten, kein Flying, kein WoW-Token, kein bezahlter Boost. Frischer Start am 04.11.2026. | Junge Wirtschaft, Preise volatil, Vendor setzt anfangs den Preisboden. Eigene Preishistorie ist wertvoll, weil es noch kaum welche gibt. |
| Client/API | Mainline-Codefamilie („die allermeisten APIs von 12.1.5"). `WOW_PROJECT_ID = 18` (`WOW_PROJECT_CAMELOT`). Alte Globals wie `GetItemInfo`, `GetSpellInfo` fehlen, stattdessen `C_Item.*`, `C_Spell.*`. Lua 5.1. | Code ist Retail-Stil, **nicht** Classic-Stil. Classic-Era-Addons laden nicht. |
| TOC | `## Interface: 16001` (Beta-Wert, gilt als Launch-Wert, in-game prüfen mit `/dump select(4, GetBuildInfo())`). Suffixe `_Camelot.toc` und `_Forever.toc`; `## AllowLoadGameType: camelot`. BigWigs-Packager v2.6+ und CurseForge erkennen 16xxx automatisch. | Eine TOC ohne Suffix mit 16001. Keine Classic-Interface-Nummern beilegen. |
| Secret Values | Midnight-Restriktionen gelten auch auf Forever: Kampfwerte (Health, Auren, Cooldowns, Unit-Namen in Instanzen) sind für Addons „geheim". Kein Combat-Log für Addons. Vergleich/Arithmetik auf Secrets wirft Fehler. SavedVariables können keine Secrets speichern. | Goldweaver ist ein Nicht-Kampf-Addon und inhaltlich nicht betroffen. Trotzdem alle Event-Argumente mit `issecretvalue()` absichern, bevor sie verglichen, als Tabellen-Key benutzt oder gespeichert werden. |
| Auktionshaus | Realmlos. **Ein AH pro Regelsatz (Normal/PvP/RP/RP-PvP) × Fraktion × Region.** Modernes AH-Fenster und `C_AuctionHouse` (Auctionator setzt `IsForever` für Builds 16000–19999). Faction-AH 5 % Cut, Goblin-AH 15 %. Laufzeiten laut Auctionator-Quelle 2/8/24 h (eine Fan-Seite nennt 12/24/48 h, widersprüchlich). Einzahlung wird bei Verkauf erstattet. | Preisdaten nach **Regelsatz + Fraktion** schlüsseln, nicht nach Realm. Alle Preisrechnungen mit 5 % Cut und Einzahlungsrisiko. Laufzeiten in-game verifizieren. |
| AH-Scan-Limits | `ReplicateItems` (Vollscan) hat auf Retail 15 Min Account-Cooldown. Ob er auf 1.60 funktioniert, ist **unbestätigt**. Blizzard hat seit 8.3 ein „Aktions-Budget pro Minute" pro Spieler, Cancel-Throttle nach ca. 50 Cancels. Auctionator begrenzt Vollscans selbst auf 15 Min. | Eigene Scans nur opt-in, throttle-bewusst (`C_AuctionHouse.IsThrottledMessageSystemReady()`), zuerst Auctionator als Preisquelle nutzen. |
| Post | Post zwischen eigenen Charakteren kommt **sofort** an. 30 Kupfer pro Sendung mit Anhang. Keine Post über Fraktion, Regelsatz oder Region hinweg. Namen sind regionsweit eindeutig mit Nachnamen; Beta-Bug: Zustellung nur nach Vornamen. | Main→Twink-Pipeline funktioniert ohne Wartezeit. Charaktere **nicht** als `Name-Realm` schlüsseln; Namensformat in-game prüfen. |
| Berufe allgemein | Skill 1–300 in vier Rängen (Lehrling bis 75, Geselle 150, Experte 225, Meister 300; Lehrling ohne Levelanforderung). 859 neue Rezepte, 298 davon für Merchant's Favor kaufbar. Viele Rezepte in Schneiderei, Schmiedekunst, Lederverarbeitung werden 25–45 Punkte früher grau als in Classic; Ingenieurskunst und Alchemie weitgehend wie Classic. Heiltränke wanderten von Alchemie zu Erste Hilfe. Berufe-UI: `C_TradeSkillUI` vorhanden (Wiki taggt „forever"); ForeverArtisan probiert `C_TradeSkillUI` → `GetTradeSkillInfo` → `GetCraftInfo` (Verzauberkunst nutzt das Craft-Fenster). | Skill-up-Pfade **nicht** aus Classic-Guides hartkodieren, sondern aus Rezeptfarben des Fensters berechnen und mit Live-Preisen bewerten. API-Adapter mit Fallback-Kette, berufsunabhängig. |
| Sammelberufe | Kräuterkunde, Bergbau, Kürschnerei mit Classic-Skillbereichen; neue Schmelzen (Azerothium, Heavy Thorium). Kräutersamen am Camp (Gardening), Kürschnerei mit Gerbfenster. Angeln mit „Find Fish" und eigenem Fenster. | Sammelberufe brauchen eigene Sicht: Wert pro Node/Zone aus Preisen, Skill-Fenster pro Node, Routenbewertung. |
| Merchant's Favor | Handelswährung: Waylaid Crates (ab Level 10) oder Writs mit genau **einem Bündel** füllen und beim Handelsvertreter abgeben (Allianz: Azeroth Commerce Authority, Redridge; Horde: Durotar Supply and Logistics, Crossroads). Bündel gibt es für Stoff, Erz/Barren, Leder, Kräuter, Essen, Curiosities (Entzauber-Mats) usw. Favor-Auszahlung pro Kiste **widersprüchlich** (5/10/15 vs. 10/10/20/35). Muster 30–360 Favor, Zertifikat 1.000, Packmule Treat 1.500. | Eigene Entscheidungsoption „in Kiste stecken" mit Favor-Wert für **jeden** Beruf. Favor-Sätze konfigurierbar, in-game nachmessen. |
| Entzaubern | Ab Skill 1 für alle Itemstufen, liegt im Berufefenster statt im Zauberbuch. Tabelle nach „Benötigt Stufe" (1–10 Strange Dust … 56–60 Illusion Dust/Nexus Crystal). Grüne Rüstung ~75 % Staub, grüne Waffen ~75 % Essenz, blaue immer Splitter. Camp-Buff „Arcane Salvager" verbessert Entzaubern. | Erwartungswert pro Item berechenbar. Tabelle als Daten-Datei, versioniert, durch eigene Loot-Beobachtung kalibriert. |
| Verkauf | Vendorpreise vieler Craft-Items wurden gesenkt; Zauberstäbe schwankten stark. Dungeon-Blues bringen im AH mehr als beim Händler. Beutel verkaufen sich an jede Klasse, Barren und mittleres Leder waren Schnelldreher, Essen (Well Fed +5 % XP) läuft bis 60, Tränke/Flasks ab Raidstart 09.12.2026. Die meisten Beta-Rezepte waren knapp an der Null. | Der Advisor muss „roh verkaufen" ehrlich gegen „verarbeiten" rechnen, für jedes Zwischenprodukt (Stoff→Bolzen, Erz→Barren, Leder→Gegerbt). |

---

## 2. Dein Workflow: Ist und Ziel

**Ist (ohne Addon)**
1. Main reist, questet, sammelt (Stoff, Erz, Kräuter, Leder, grüne/blaue BoE-Items, Baumaterial, Überschuss).
2. Main schickt alles per Post an einen Twink in der Hauptstadt (aktuell Schneiderei + Verzauberkunst, später beliebig).
3. Twink entscheidet manuell: verkaufen, entzaubern/verarbeiten, behalten.
4. Twink stellt ins AH, ohne sichere Rechnung, welcher Weg mehr Gold bringt oder welcher Skill-up am günstigsten ist.

**Ziel (mit Goldweaver)**
- **Main unterwegs:** Jeder Loot zeigt sofort den **besten Verwendungsweg** und den erwarteten Wert. Ein HUD zeigt den „Twink-Wert" der Taschen und bei Sammelberufen den Wert der aktuellen Zone. Am Briefkasten reicht **ein Klick pro Brief**.
- **Twink/Verarbeiter:** Posteingang abholen, dann eine **Arbeitsliste**: verarbeiten (jede Umwandlung mit Gewinnrechnung), entzaubern (Queue mit Button), Kisten füllen (Favor), verkaufen (Preisvorschlag, Cut, Einzahlung) oder behalten (für den nächsten Skill-up).
- **Berufe, alle:** Ein **Skill-up-Planer** berechnet aus Rezeptfarben und Live-Preisen den günstigsten Weg zum nächsten Rang, für jeden geöffneten Beruf. Ein **Craft-Profit-Ranking** zeigt, was sich herzustellen lohnt. Ein **Berufs-Vergleich** zeigt, welcher zusätzliche oder alternative Beruf mit deinem Bestand und dem aktuellen Markt am meisten bringt.
- **Dashboard:** Gold pro Session, Verkäufe aus AH-Rechnungen, Favor-Fortschritt, Tagesplan.

---

## 3. Markt: Was es schon gibt und wo die Lücke ist

| Addon | Forever-Status | Stärken | Lücke für deinen Workflow | Lizenz / Nutzbarkeit |
|---|---|---|---|---|
| **Auctionator** | Forever-Build seit Sept./Okt. 2026 | Preisdatenbank, Shopping-Listen, Posten, Tooltip-Preise, öffentliche `Auctionator.API.v1` | Keine Entscheidungslogik, keine Berufsplanung, keine Post-Pipeline | MIT. GitHub-Repo aktuell nicht erreichbar (404); Nutzung als **optionale Abhängigkeit** über seine API |
| **TradeSkillMaster 4.15** | Forever seit 05.11.2026 | Alles (Auctioning, Crafting, Mailing, Destroying, Desktop-App) | Sehr komplex, Desktop-App nötig, keine Favor/Kisten-Logik, kein Berufsvergleich | Proprietär; nur Konkurrenzreferenz |
| **ForeverArtisan** | Für Forever gebaut (0.9.35 vom 07.11.2026) | Alle 12 Berufe, „Make now", Pläne, Einkaufslisten, Trade Contacts, nutzt Auctionator-Preise | Kein AH-Modul, keine Post-Pipeline, keine Main→Twink-Entscheidung, kein Profit-Ranking über Berufe hinweg | **Alle Rechte vorbehalten**: Lesen erlaubt, **Code/Daten/Name nicht wiederverwenden**. Nur Architektur-Lernquelle |
| **Gold Forever** | Für Forever | AH-Werte im Tooltip, Gold/Stunde | Keine Berufe, keine Entscheidung | – |
| Profit Forge, DisenchantValue, Crafty, LilSparky's Workshop | TBC/Retail | Craft-Profit, DE-Tooltip | Nicht für Forever, kein Gesamtfluss | – |

**Die Lücke:** Kein Addon verbindet *Loot auf dem Main → Post → Verarbeitung auf dem Twink → AH* zu einer Entscheidungskette, und keines bewertet **alle Berufe gleich** gegen Live-Preise: Herstellen, Leveln und Gold verdienen als ein Optimierungsproblem. Das ist Goldweavers Kern.

---

## 4. Produktkonzept

### 4.1 Leitprinzipien
1. **Entscheidung statt Daten.** Jede Anzeige endet in einer Empfehlung mit Zahl: „Entzaubern (erw. 1g 20s) statt AH (95s nach Cut)".
2. **Ehrliche Rechnung.** Immer mit AH-Cut 5 %, Postkosten 30 Kupfer, Einzahlungsrisiko, Materialpreis zu Marktwert (nicht „umsonst, weil gesammelt"), optional Zeitwert pro Stunde.
3. **Ein Klick pro geschützter Aktion.** Keine Automatisierung: Posten, Senden, Kaufen, Herstellen und Entzaubern brauchen je ein Hardware-Event. ToU-Pflicht und Schutz vor Throttling.
4. **Preisquelle gestuft.** Auctionator-API, wenn installiert → eigene beobachtete Preise (was der Spieler im AH gesehen hat) → eigener opt-in Scan → Vendorpreis als Boden.
5. **Berufsneutral.** Die Engine kennt Rezepte, Reagenzien, Umwandlungen, Quellen und Farben; was „Schneiderei" ist, steht in einem Datenprofil.
6. **Forever-first.** Nur Interface 16001, nur `C_`-APIs, Secret-Guards überall, keine Classic-Altlasten.

### 4.2 Module

**M0 Core**
- Namespace, Event-Bus (ein Frame, Handler-Tabelle, kein `OnUpdate`-Polling), SavedVariables-Verwaltung, Secret-Guard, Logging, Slash `/gw`.
- Charakter-Registry: Rollen **Main / Verarbeiter / Bank**, pro Regelsatz + Fraktion. Berufe jedes Charakters werden beim Öffnen des Berufefensters erfasst (Beruf, Skill, bekannte Rezepte, Werkzeuge).
- Preis-Engine `ns.Price.Get(itemID)` → `{copper, source, age, confidence}`.
- Bestands-Engine: Taschen, Bank, Post (eigene Erfassung; optional Syndicator-API) pro Charakter, damit Planer „schon vorhanden" abziehen.

**M1 Item-Wissen (Daten)**
- **Umwandlungs-Graph** (berufsneutral): Knoten = Items, Kanten = Umwandlungen mit Beruf, Skill, Mengen, Wahrscheinlichkeit. Quellen der Kanten: (a) live aus dem Berufefenster (Rezepte), (b) statische Daten für nicht-rezeptbasierte Umwandlungen: Entzaubern (Tabelle), Schmelzen, Gerben, Kochen über Camp, Vendor-Kauf.
- Entzaubertabelle (Levelbereich → Mats, Mengen, Wahrscheinlichkeiten), kalibriert durch eigene Beobachtungen.
- Kisten-Bündel je Kategorie (Stoff, Erz/Barren, Leder, Kräuter, Essen, Curiosities …) und Favor-Sätze (konfigurierbar, Default „unbestätigt").
- Vendor-Only-Reagenzien (Faden, Farbstoffe, Fläschchen, Ruten, Kohle, Salz …) mit Vendor-Preisen.

**M2 Advisor (Entscheidungsmaschine)**
Für jedes Item in Tasche/Post/Loot, über den Umwandlungs-Graph bis Tiefe 3:
```
Optionen = { Vendor, AH_roh, Umwandeln(k)→Produkt_verkaufen, Umwandeln(k)→Produkt_behalten,
             Kiste(Favor × Favorwert_in_Gold), Behalten_für_Skillup(Beruf, Pfad) }
Wert(Option) = Erlös − Cut − Einzahlungsrisiko − Post − Materialkosten_zu_Marktwert − Zeitwert
Empfehlung = argmax Wert, mit Begründung, Konfidenz (Datenalter, Beobachtungen) und „wer kann das": welcher eigene Charakter die Umwandlung beherrscht
```
- „Behalten für Skill-up" wird vom Planer (M5) gespeist, für jeden Beruf jedes Charakters.
- Favorwert in Gold ist eine Einstellung, weil Favor Muster kauft, die es sonst nicht gibt.
- Ausgabe: Tooltip-Zeilen, Taschen-Overlay, Listen in den Modulen.

**M3 HUD (Main unterwegs)**
- Verschiebbares Fenster: Twink-Wert in den Taschen, markierte Items, letzter Loot mit Empfehlung, Gold/Session.
- **Sammel-Sicht** (wenn der Charakter einen Sammelberuf hat): Wert der Nodes dieser Zone zu aktuellen Preisen, Skill-up-Chance pro Node, „lohnt sich diese Zone gegenüber Zone X". Node-Positionen optional aus GatherMate2 (lesen), keine eigene Datenbank.
- Regeln: „Stoff/Erz/Kräuter/Leder immer zum Verarbeiter", „Grüne ab Stufe 15 zum Verzauberer", „Graue vendorn". Ziel-Charakter pro Materialtyp wählbar, weil verschiedene Twinks verschiedene Berufe haben können.

**M4 Post**
- Beim Öffnen des Briefkastens: Listen „Für <Charakter>" je Zielcharakter laut Regeln und Advisor. Button „Nächsten Brief füllen und senden" (ein Klick = ein Brief, Anhänge über `C_Container.UseContainerItem` auf das offene Sendefenster, `SendMail` im Klick-Handler).
- Posteingang: „Alles abholen" als Schrittkette mit Klick je Schritt oder Throttle-Pause, Verkaufs-Ledger aus `GetInboxInvoiceInfo`.
- Zustellung: vollständiger Name inkl. Nachname aus der Registry, Warnung bei Namensdoppelung (Beta-Bug).

**M5 Berufe (generische Engine + Profile)**
- **API-Adapter** mit Fallback-Kette `C_TradeSkillUI` → `GetTradeSkillInfo` → `GetCraftInfo`; liefert normiert `ns.Recipes[professionID]` = {recipeID, name, farbe, reagenzien[], produkt, anzahl, werkzeuge, station}.
- **Skill-up-Planer (jeder Beruf):** Zielrang → günstigster Pfad aus Rezeptfarben (orange/gelb/grün mit Skill-up-Wahrscheinlichkeit, Grau-Schätzung) und Live-Preisen; vergleicht Alternativen (Rohstoff vs. Zwischenprodukt kaufen, Staub- vs. Essenz-Route); zieht Bestand ab; weiß, welche Rezepte Ausbilder/Vendor/Favor liefern (Rezeptquelle, sofern aus dem Fenster oder Profil bekannt). Sammelberufe: Plan als Zonenfolge nach Skill-Fenstern.
- **Craft-Profit-Ranking:** Pro Rezept Materialkosten vs. Erlös (nach Cut), Marktbreite (Anzahl Angebote), „jetzt herstellen"-Button (Klick → `C_TradeSkillUI.CraftRecipe` oder `DoTradeSkill`). Berücksichtigt Mehrfachausbeute und Camp-Buffs, soweit lesbar.
- **Zerlegen-Queue (Destroy):** Entzaubern heute, strukturell offen für weitere Zerlege-Umwandlungen; ein Secure-Button, ein Klick pro Item; Ergebnis via `LOOT_OPENED` geloggt zur Kalibrierung.
- **Berufs-Vergleich:** Für jeden der zwölf Berufe: Kosten bis 300 zu aktuellen Preisen (aus Profil-Pfaden, wo kein Fenster offen ist), Top-5 profitable Rezepte, Synergie mit bereits vorhandenen Berufen und Bestand (z. B. „du hast 400 Erz in der Bank, Bergbau→Schmiedekunst spart 12g"). Antwort auf „soll ich wechseln oder dazulernen".
- **Profile** `Professions/<Beruf>.lua`: Kategorie (Herstellung/Sammeln/Sekundär), Umwandlungstypen, Kisten-Kategorien, Vendor-Reagenzien, Werkzeuge/Stationen, Rang-Ausbilder-Anforderungen, Standard-Skill-up-Pfad als Startwert bis Live-Daten vorliegen, Besonderheiten (z. B. Verzauberkunst: Ruten, Craft-Fenster; Ingenieurskunst: Classic-Skillbereiche; Erste Hilfe: Heiltränke).

**M6 Auktionshaus**
- Post-Helfer im Verkaufen-Tab: Preisvorschlag, Unterbieten konfigurierbar, Stückelung in Rezeptgrößen (Käufer können Stacks nicht teilen), Einzahlung/Cut-Vorschau, ein Klick = ein Posten.
- Einkaufslisten aus dem Planer: Suche per Klick, Preisvergleich Rohstoff vs. Zwischenprodukt.
- Beobachtete Preise: jede angezeigte Suchseite wird in die eigene Preis-DB übernommen (keine zusätzlichen Anfragen).
- Opt-in Vollscan über `ReplicateItems`, falls auf Forever verfügbar: 15-Min-Sperre persistiert, Batches über Frames, Abbruch beim Schließen.
- Unterbietungs-Check für eigene Auktionen: eine Suche pro Item, throttle-bewusst, Klick zum Abbrechen.

**M7 Dashboard**
- Gold-Verlauf pro Charakter und gesamt, Einnahmen nach Quelle, Favor-Zähler, offene Kisten, „heute empfohlen" (Top-Crafts über alle Berufe, Top-Zerlege-Kandidaten, nächster Skill-up-Schritt je Beruf, lohnendste Sammelzone).

### 4.3 Berufsprofile: Abdeckung
| Beruf | Typ | Umwandlungen im Graph | Besonderheit im Profil |
|---|---|---|---|
| Schneiderei | Herstellung | Stoff→Bolzen→Kleidung/Beutel | Beutel-Nachfrage, Writs, Zertifikat, früheres Grau |
| Verzauberkunst | Herstellung/Zerlegen | Item→Staub/Essenz/Splitter; Mats→Verzauberung/Öl/Stab | Craft-Fenster-API, Ruten, Zauberstab-Vendorpreise, Arcane Salvager |
| Schmiedekunst | Herstellung | Barren→Rüstung/Waffe/Schleifsteine | Amboss/Schmiede als Station, früheres Grau |
| Lederverarbeitung | Herstellung | Leder→Gegerbt→Rüstung/Rüstungssets | Gerbfenster/Camp, früheres Grau |
| Alchemie | Herstellung | Kräuter+Fläschchen→Trank/Elixier/Flask, Transmutation | Raid-Nachfrage ab 09.12.2026, Cooldowns |
| Ingenieurskunst | Herstellung | Barren/Stein→Teile→Geräte | Classic-Skillbereiche, viele Vendor-Reagenzien |
| Kochkunst | Sekundär | Fleisch/Fisch→Essen (Well Fed +5 % XP) | Camp-Rezepte, Lagerfeuer |
| Erste Hilfe | Sekundär | Stoff→Verbände, Heiltränke | Konkurriert mit Schneiderei um Stoff |
| Angeln | Sekundär/Sammeln | Node→Fisch | Zonen-/Pool-Wert, Find Fish |
| Kräuterkunde | Sammeln | Node→Kräuter, Samen am Camp | Zonenwert, Skill-Fenster, GatherMate2-Lesen |
| Bergbau | Sammeln/Umwandeln | Node→Erz→Barren (Schmelzen) | Schmelzen als Umwandlung, Azerothium/Heavy Thorium |
| Kürschnerei | Sammeln | Mob→Leder/Schuppen | Gerbfenster, Mob-Level→Lederstufe |

### 4.4 Nicht-Ziele
- Kein Kampf-, Boss- oder Aura-Feature (Secret Values, kein Combat-Log).
- Kein Auto-Kauf, kein Sniping, keine Cancel-Schleifen, keine Chat-Werbung.
- Keine Item-/NPC-/Node-Datenbank (Wowhead, Questie, GatherMate2 lesen wir nur). Keine externe Netzwerkverbindung (in Lua nicht möglich).
- Kein Ersatz für Auctionator oder TSM; wir ergänzen und nutzen ihre Daten, wenn vorhanden.

---

## 5. Architektur

```
Goldweaver/                      Addon-Ordner (muss so heißen wie die TOC)
  Goldweaver.toc                 Interface 16001, Ladeliste = Modulreihenfolge
  Core/        Init.lua, Events.lua, Secret.lua, DB.lua, Chars.lua, Inventory.lua, Price.lua, Util.lua
  Data/        Disenchant.lua, Crates.lua, VendorReagents.lua, Conversions.lua
  Professions/ Registry.lua, Adapter.lua, Tailoring.lua, Enchanting.lua, Blacksmithing.lua, Leatherworking.lua,
               Alchemy.lua, Engineering.lua, Cooking.lua, FirstAid.lua, Fishing.lua, Herbalism.lua, Mining.lua, Skinning.lua
  Modules/     Advisor.lua, HUD.lua, Mail.lua, Planner.lua, CraftProfit.lua, Destroy.lua, Compare.lua, Auction.lua, Dashboard.lua
  UI/          Kit.lua, Tooltip.lua, Minimap.lua
  Locales/     enUS.lua, deDE.lua
```

- **Namespace:** jede Datei beginnt mit `local ADDON, ns = ...`; Module registrieren sich mit `ns:RegisterModule(name, tbl)`; nur ein Global `Goldweaver` für Slash und optionale API.
- **Events:** ein Frame, `ns.Events:On("EVENT", fn)`; jeder Handler läuft durch den Secret-Guard.
- **SavedVariables:** `GoldweaverDB` (Account: Preise, Registry, Berufe je Charakter, Einstellungen, Kalibrierdaten) und `GoldweaverCharDB` (Charakter: Session, Ledger). Preise unter `DB.prices[<marketKey>][itemID]` mit `marketKey = ruleset .. "-" .. faction` (Regelsatz-Ermittlung offene Frage, Fallback `GetNormalizedRealmName()`). Initialisierung in `ADDON_LOADED`.
- **Preisdaten:** pro Item `min`, mengengewichteter `avg`, `count`, Tageshistorie, Pruning nach N Tagen; Ausreißer über Median oder „günstigste 15 % der Einheiten".
- **Umwandlungs-Graph:** `ns.Graph:AddEdge{from, to, qty, prob, profession, skill, source}`; Live-Rezepte überschreiben Profil-Startwerte gleicher ID. Advisor und Planer arbeiten nur auf dem Graph, nie auf Berufs-Sonderfällen.
- **Abhängigkeiten:** keine harten. `## OptionalDeps: Auctionator, Syndicator, GatherMate2, TradeSkillMaster`. Keine Ace3 im MVP; LibDataBroker/LibDBIcon später optional (Ace3-Trunk listet 16001).
- **UI:** eigenes schlankes Kit auf `BackdropTemplate`; geschützte Frame-Änderungen nur außerhalb von Kampf.
- **Tests:** `luac -p` auf jede Datei, `luacheck` mit WoW-Globals, Headless-Tests (reines Lua, Stub-Harness unter `tools/tests/`) für Preis-Engine, Graph, Advisor-Formeln, Entzauber-Erwartungswert, Planer.

### 5.1 API-Inventar (zu verifizieren in Phase 0)

| Bereich | API | Status |
|---|---|---|
| Items | `C_Item.GetItemInfo`, `GetItemInfoInstant`, `RequestLoadItemDataByID`, `ITEM_DATA_LOAD_RESULT`, `Item:CreateFromItemID():ContinueOnItemLoad` | Forever bestätigt (Community) |
| Taschen | `C_Container.GetContainerNumSlots/GetContainerItemInfo/UseContainerItem`, `BAG_UPDATE_DELAYED` | Retail-Standard, prüfen |
| Tooltip | `TooltipDataProcessor.AddTooltipPostCall`, `C_TooltipInfo` | ForeverArtisan nutzt `C_TooltipInfo`; PostCall prüfen |
| Berufe | `C_TradeSkillUI.*` (`GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeSchematic`, `GetProfessionInfoBySkillLineID`, `GetRecipeTools`, `CraftRecipe`), Fallback `GetTradeSkillInfo`/`GetCraftInfo`, `GetProfessions`/`GetProfessionInfo`, Events `TRADE_SKILL_SHOW/LIST_UPDATE`, `CRAFT_SHOW/UPDATE`, `SKILL_LINES_CHANGED` | Wiki taggt C_TradeSkillUI „forever"; Kette pro Beruf prüfen |
| AH | `C_AuctionHouse.SendBrowseQuery/SendSearchQuery`, `GetCommoditySearchResultInfo`, `GetItemSearchResultInfo`, `PostCommodity/PostItem`, `GetOwnedAuctions`, `ReplicateItems`, `IsThrottledMessageSystemReady`, Events `AUCTION_HOUSE_SHOW`, `COMMODITY_SEARCH_RESULTS_UPDATED`, `ITEM_SEARCH_RESULTS_UPDATED`, `REPLICATE_ITEM_LIST_UPDATE`, `AUCTION_HOUSE_AUCTION_CREATED` | C_AuctionHouse bestätigt; Replicate und Throttles offen |
| Post | `SendMail`, `GetInboxNumItems`, `GetInboxHeaderInfo`, `GetInboxInvoiceInfo`, `TakeInboxItem`, `AutoLootMailItem`, `MAIL_SHOW`, `MAIL_INBOX_UPDATE`, `MAIL_SEND_SUCCESS` | Retail-Standard, prüfen (Namensformat) |
| Charakter | `UnitName("player")`, `UnitFullName`, `UnitFactionGroup`, `GetNormalizedRealmName` | Realm-Funktionen auf realmlosem Client offen |
| Zerlegen | `SecureActionButtonTemplate` mit `type="macro"`, `macrotext`; `UNIT_SPELLCAST_SUCCEEDED`, `LOOT_OPENED` | Beta-Report: Snippets kompilierten nicht; verifizieren |

---

## 6. Richtlinien-Konformität (Kurzfassung, Details in `04-COMPLIANCE.md`)

Blizzards UI Add-On Development Policy (2009, 2018 erneut veröffentlicht, weiterhin einzige formale Grundlage) und ToU/EULA werden erfüllt durch: kostenlos, Quellcode offen (MIT), keine Werbung, keine Spenden-Aufrufe im Spiel, kein Schaden für Realms (keine Query-Schleifen, Throttles respektieren, keine Chat-Nutzung), keine Automatisierung (jede geschützte Aktion durch Klick), kein Kampfvorteil, keine Secrets speichern. Zusätzlich: kein Code aus ForeverArtisan (proprietär), Auctionator nur über seine öffentliche API, Addon-Name ohne Markenkonflikt.

---

## 7. Risiken und offene Fragen (Phase 0 klärt sie in-game)

| # | Frage | Warum wichtig | Plan |
|---|---|---|---|
| F1 | Läuft `ReplicateItems` auf 1.60, Throttle 15 Min pro Account oder Charakter? | Eigener Vollscan vs. Auctionator-Abhängigkeit | Probe am AH mit Logging |
| F2 | Welche Berufe-API liefert welcher Beruf (Craft-Fenster für Verzauberkunst?) und wie sehen Sammelberufe im Fenster aus? | Adapter, Planer | `/dump` je Beruf, Fallback-Kette |
| F3 | Format von Charakternamen mit Nachnamen (`UnitFullName`, Post-Empfängerfeld), `GetNormalizedRealmName()` auf realmlosem Client, Regelsatz-Ermittlung | Registry, Post-Zustellung, Markt-Key | Probe, ggf. manuelles Nachnamen-/Regelsatzfeld |
| F4 | Funktioniert `SecureActionButtonTemplate` mit `macrotext` für Entzaubern? | Zerlegen-Queue | Probe außerhalb Kampf |
| F5 | Ist `TooltipDataProcessor` vorhanden? | Tooltip-Integration | Probe, sonst `GameTooltip`-Hook mit pcall |
| F6 | Auktionslaufzeiten 2/8/24 vs. 12/24/48 h und Einzahlungssätze | Einzahlungsrisiko | Am AH ablesen, aus echter Rechnung bestätigen |
| F7 | Favor pro Kiste und Bündelgrößen je Kategorie | Kisten-Option | Einstellbar, Default „unbestätigt", messen |
| F8 | Ändert sich 16001 zum Launch-Patch? | Addon „veraltet" | `/dump select(4, GetBuildInfo())` nach jedem Patch |
| F9 | Blizzards AH-Aktionsbudget pro Minute (Zahl unbekannt) | Scan- und Unterbietungs-Design | Konservativ: eine Anfrage pro Klick, Vollscan opt-in |
| F10 | Beta-Bug: Post nach Vorname | Fehlzustellung | Namensprüfung + Warnung, erst Testsendung |
| F11 | Skill-up-Wahrscheinlichkeiten pro Farbe auf Forever (Classic: orange 100 %, gelb/grün abnehmend) und Legacy-Perk „Working Overtime" | Planer-Genauigkeit | Aus eigenen Craft-Logs kalibrieren |

---

## 8. Erfolgskriterien
- Nach einer Sammelrunde zeigt das HUD den Twink-Wert, und der Postversand braucht höchstens einen Klick pro Brief.
- Der Verarbeiter sieht für jedes Item eine Empfehlung mit Zahl, die Zerlegen-Queue läuft mit einem Klick pro Item.
- Der Planer liefert für **jeden geöffneten Beruf** zum nächsten Rang eine Einkaufsliste, die zu aktuellen Preisen günstiger ist als der Classic-Guide-Pfad.
- Der Berufs-Vergleich beantwortet „welchen Beruf dazu/wechseln" mit Kosten bis 300 und Top-Crafts.
- Kein Throttle-Hinweis, kein Lua-Fehler durch Secrets, Addon lädt ohne „veraltet"-Markierung.

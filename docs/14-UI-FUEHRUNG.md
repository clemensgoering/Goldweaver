# Goldweaver – Führung, vertrautes Design, Zonenbezug und Automatik

Stand: 09.11.2026. Ergebnis der Evaluation der drei Stränge aus dem Spieltest vom 08.11.: (1) Einrichtung und Tests unsichtbar automatisieren, (2) UI, das führt und sich vertraut anfühlt, (3) Informationen nach Level und Gebiet, auch für Spieler, die einem RestedXP-Guide folgen. Ersetzt `08-UX.md` dort, wo es widerspricht (Reiter, Seitenpanel, Einstellungen).

## 1. Evaluation: was andere gut machen

| Addon | Download-Größe | Muster | Übernommen |
|---|---|---|---|
| RestedXP (lokal installiert, v4.11.33, Forever-TOC 16001) | Top-2 Leveling-Guide | Seitenfenster mit **aktuellem Schritt**, Ziel-Icon, Wegpunkt, nächste Schritte; Guide-Zustand im globalen `RXP`-Objekt, Schritt-Elemente tragen `zone` als uiMapID | Schrittkarte „Jetzt" + „Danach"; **lesender Zugriff** auf `RXP.currentGuide.steps[RXPCData.currentStep…].elements[].zone` für die Route. Lizenz CC BY-NC-SA 4.0: kein Code übernommen. |
| Zygor Gold & Professions | kommerziell | Sammelziele **nach Berufsskill gefiltert**, nach AH-Wert sortiert, Reiseführung zum Spot | Unterwegs-Liste nach Skill-Farbe und Wert; „Beste Zonen für deine Skills" |
| GatherMate2 | 35,5 Mio. | Fundorte aus eigenem Sammeln, optional Datenpakete | Eigene Funde je Zone (`learned.zoneGathers`) überschreiben/ergänzen die Startdaten |
| Blizzard-Fenster (Charakter, Berufe, Abenteuerführer) | – | Porträtrahmen, **Reiter unten**, Inset-Panels, Navigationsliste mit Icon + Skillbalken, Einstellungen unter Optionen → AddOns | Hauptfenster mit `PortraitFrameTemplate` und `PanelTabButtonTemplate`, Berufe-Navigation links, Einstellungen im Blizzard-Optionsmenü |
| Questverfolgung (Objective Tracker) | – | Halbtransparente Liste am Bildschirmrand, einklappbare Kopfzeile | Seitenpanel „Unterwegs" |

## 2. Strang 1: Automatik ohne manuelle Schritte

| Was | Wie | Abschaltbar |
|---|---|---|
| Rollen | `Modules/Autopilot.lua`: ohne Main wird der Charakter mit dem höchsten Level Main; Charaktere mit Herstellungsberuf werden Verarbeiter. Vom Spieler gewählte Rollen werden nie überschrieben (`roleSource = "manual"`). | Rolle einmal anklicken |
| Rezeptbücher | Beim Login (12 s, außerhalb des Kampfs, wenn kein anderes Fenster offen ist) öffnet der Autopilot jeden Herstellungsberuf unsichtbar (Alpha 0), liest ihn und schließt ihn. Täglich erneuert. Blockiert der Client (`ADDON_ACTION_BLOCKED`), schaltet er sich für die Sitzung ab und meldet es. | Einstellung „Berufe beim Login im Hintergrund einlesen" |
| Selbsttest | 15 s nach dem Login: alle Features und Modul-Selbsttests. Nur Probleme erscheinen im Chat; Minimap-Badge „!"; Ergebnis im Leitfaden und im Team-Reiter. | – |
| Abnahme | Die 32 Prüfungen bestehen weiter durch Spielereignisse; neu: Hintergrund-Lesen, Zone erkannt, Sammelfund zugeordnet. | – |
| Lernen | Sammelfunde je Zone, Einzahlung, Postformat, Skill-up-Raten, Lehrer, Händler (wie bisher). | – |

Nicht automatisierbar (braucht einen Besuch im Spiel): Bankinhalt, Lehrer- und Händlerdaten, AH-Preise ohne Auctionator.

## 3. Strang 2: UI, das führt

**Fenster** (`/gw`, Minimap-Linksklick): Stil „Forever modern“ (Vorbild: moderne Forever-Addons wie OneForAll, nur als Inspiration, kein Code und keine Grafik übernommen, da GPL): dunkle warme Flächen, 1-px-Rahmen, goldene Eckakzente, Kopfband mit Logo und Untertitel, vier Reiter oben im Browser-Stil mit Symbol, Karten statt Insets, goldene Knöpfe, Schalter statt Häkchen. Alles aus Farbtexturen (`UI.Skin`), daher unabhängig von Blizzard-Templates. Reiter, Schrittkarte und Abläufe bleiben unverändert.
1. **Leitfaden** – Schrittkarte „JETZT · SCHRITT 1 VON N" mit großem Icon, Titel, einem Satz, Wert und **einem** Aktionsknopf (z. B. „Entzaubern", „Rezepte laden", „Im AH suchen", „Wegpunkt"). Darunter „DANACH" mit bis zu sechs Schritten, jeder mit eigenem kleinen Knopf. Rechts: Unterwegs-Kurzfassung, RestedXP-Route, Heute. Unten: Funktionsstatus („Alles bereit" oder „1 Funktion eingeschränkt").
2. **Unterwegs** – Zone mit Stufenband und Passung zum Level; „Hier sammeln" mit Item-Icons, Skill-Farbe (orange/gelb/grün/grau wie im Spiel), Preis oder „gefragt ×N"; Gegner (Stoff, Leder, Häuten bis Level X); „Beste Zonen für deine Skills"; RestedXP-Route. Jede Zone ist per „Ansehen" durchblätterbar.
3. **Berufe** – links Navigationsliste mit Berufsicon und Skillbalken, rechts Status (Rang, Lehrer, „Rezepte laden"), nächster Skill-up mit Material-Icons, habe/brauche und „Im AH suchen" je Zeile, „Lohnt sich", „Noch nicht gelernt". Unten links „Welcher Beruf lohnt sich?".
4. **Team** – Charaktere mit Rollen-Icon, Level, Berufen und Rollenknöpfen; Funktionsstatus mit „Einstellungen", „Debug-Bericht", „Backup anlegen".

**Seitenpanel „Unterwegs"** (`/gw panel`): Kopfzeile mit Zone (Linksklick klappt ein, Rechtsklick öffnet Details, Shift+Ziehen verschiebt), darunter der aktuelle Schritt und bis zu fünf Dinge, die sich hier lohnen, plus die nächsten Zonen der RestedXP-Route. Im Kampf halbtransparent.

**Einstellungen**: Esc → Optionen → AddOns → Goldweaver (neun Schalter), Ersatzfenster, falls die Settings-API fehlt.

**Tooltip**: zusätzlich „Gefragt: Cupedos braucht 20 (Leinengürtel)", wenn der Verarbeiter das Item für seinen Plan braucht.

Blizzard-Templates nur noch, wo nötig (Schließen-Knopf, sichere Knöpfe), über `UI.SafeCreate` mit Ersatz ohne Template.

## 4. Strang 3: Level und Gebiet

| Frage | Quelle | Anzeige |
|---|---|---|
| Was wächst hier, kann ich es sammeln? | `Data/Zones.lua` (40 Zonen, Classic-uiMapIDs, Stufenband, Kräuter/Erze), `Data/Gathering.lua` (Skill je Kraut/Erz, Farbregeln), eigene Funde | Unterwegs, Seitenpanel, Leitfaden-Schritt „X sammeln" |
| Was braucht mein Verarbeiter? | `Modules/Demand.lua`: Einkaufslisten aller Verarbeiter-Pläne, eine Stufe den Umwandlungsgraphen hinunter (Leinengürtel → Leinenstoffbolzen → Leinenstoff) | „gefragt ×N" in Listen, Tooltip, Leitfaden |
| Welche Gegner lohnen? | Stoff nach Humanoiden-Level, Leder nach Wildtier-Level, Häut-Grenze aus dem Kürschnerei-Skill | Unterwegs „Gegner hier" |
| Wo levle ich meinen Sammelberuf? | Zonen im eigenen Levelband (±6) mit den meisten orangen/gelben Nodes | „Beste Zonen für deine Skills" |
| Wohin führt mich RestedXP? | `RXP`/`RXPCData` lesend, 40 Schritte voraus, eindeutige Zonen | Leitfaden rechts, Unterwegs, Seitenpanel |

Datenqualität: Zonenlisten sind Classic-Daten und als unbestätigt markiert; jeder eigene Fund bestätigt oder ergänzt sie dauerhaft. Spätere Ausbaustufe: optionaler Import aus GatherMate2 (Node-Koordinaten) und Questie (Gegnerlevel je Zone), beide nur lesend.

## 5. Offene Punkte
- Im Spiel prüfen: `PortraitFrameTemplate`/`PanelTabButtonTemplate` vorhanden? (Bericht „UI: Fenster-Template"), Hintergrund-Lesen nicht blockiert? (Prüfung „autoRead"), Settings-Kategorie sichtbar?
- Lokalisierung der Zonennamen: Anzeige nutzt `C_Map.GetMapInfo` (Client-Sprache), die Tabelle nur als Fallback.
- Angeln je Zone und Sammelrouten (GatherMate2) als nächste Ausbaustufe.

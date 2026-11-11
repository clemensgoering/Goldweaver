# Richtlinien- und Qualitäts-Audit Goldweaver

Letzter Durchlauf: 11.11.2026, Stand nach Commit `a0254b1`. Geprüft wurden alle Lua-Dateien, TOC, Workflows, Dokumente und die Zugriffe auf fremde Addons. Methode: Suche nach geschützten Aktionen, Timern, Event-Handlern, Schreibstellen in den SavedVariables, Vorlagen-Abhängigkeiten und Fremd-Addon-Zugriffen; dazu Durchsicht der häufig laufenden Pfade (Tooltip, Taschen-Events, Briefkasten, Auktionshaus).

## Ergebnis in einem Satz
Der Stand verletzt keine Blizzard-Richtlinie und keine Fremdlizenz. Der Durchlauf fand acht Mängel (Abschnitt 4), die alle behoben sind; vor der Veröffentlichung bleiben die Schritte in Abschnitt 5.

## 1. Blizzard UI Add-On Development Policy

| Regel | Befund | Status |
|---|---|---|
| Kostenlos | Keine Bezahlfunktion, MIT-Lizenz | erfüllt |
| Code vollständig sichtbar | Reines Lua, keine Obfuskation; das Paket enthält den gesamten Code | erfüllt, Repo vor Release öffentlich stellen |
| Kein Schaden für Realms/Spieler | Keine Schleifen über Server-Anfragen, kein dauerhaftes `OnUpdate` (nur während des Ziehens am Minimap-Knopf) | erfüllt |
| Keine Werbung, keine Spendenaufrufe | Keine Links im Spiel; optionale Addons werden nur mit Status genannt | erfüllt |
| Blizzard darf abschalten | APIs laufen über `ns.API` oder eine Existenzprüfung; unbekannte Events werden übersprungen statt Fehler zu werfen | erfüllt |

## 2. Automatisierung, Throttles, Secret Values

| Aktion | Wo | Befund |
|---|---|---|
| Material kaufen (AH) | `Modules/Auction.lua` | Drei Klicks je Material (Suchen, Kaufen, Bestätigen), jeder im Klick-Handler; `IsThrottledMessageSystemReady()` vor Suche und Kaufstart; Abbruch bei Preissprung über 15 % |
| Verkaufsvorschlag (AH) | `Modules/Auction.lua` | Füllt nur das Preisfeld; gepostet wird mit Blizzards Knopf |
| Post senden | `Modules/Mail.lua` | Erster Klick hängt bis zu 12 Items an (keine Server-Aktion), zweiter Klick sendet genau eine Post |
| Händler | `Modules/Merchant.lua` | Ein Kauf, ein Verkauf oder eine Reparatur pro Klick |
| Bank | `Modules/Bank.lua` | Ein Stapel pro Klick |
| Herstellen | `UI/TabProfessions.lua` → `Adapter.Craft` | Nur im Klick-Handler |
| Entzaubern | `Modules/Destroy.lua` | Secure-Button mit Makrotext `/cast` + `/use`, ein Item pro Klick, im Kampf gesperrt |
| Timer | alle Module | Lösen nur Anzeigen, Bestandsaufnahmen und das Lesen bereits vorhandener Daten aus, nie eine der Aktionen oben |
| Berufe im Hintergrund lesen | `Modules/Autopilot.lua` | Standard aus. Forever blockiert das Öffnen ohne Klick; das Addon merkt sich die Blockade dauerhaft und versucht es nicht erneut. Empfehlung: Schalter in einer späteren Version entfernen |
| Secret Values | `Core/Events.lua` | Jeder Handler läuft über `ns.Events` und wird übersprungen, wenn ein Argument geheim ist. `UNIT_*`-Events sind nur für den eigenen Charakter registriert (eigene Sammel-, Herstell- und Entzauber-Zauber). Keine Auren-, Cooldown- oder Combat-Log-Daten |
| Chat und Netzwerk | alle Module | Kein `SendChatMessage`, kein `SendAddonMessage` |

## 3. Lizenzen und Fremdcode

| Quelle | Befund |
|---|---|
| Eigener Code | MIT, `LICENSE` vorhanden, `X-License: MIT` in der TOC |
| ForeverArtisan (proprietär) | Kein Code, keine Daten, keine Bezeichner übernommen |
| Auctionator | Nur `Auctionator.API.v1.GetAuctionPriceByItemID` und `GetAuctionAgeByItemID` mit eigener Aufrufer-Kennung, immer optional |
| RestedXP | Nur lesend, wenn aktiv: `Field.Route` liest die globalen Tabellen `RXP.currentGuide` und `RXPCData.currentStep` (Zonen der nächsten Schritte), mit `pcall` abgesichert. RestedXP bietet dafür **keine öffentliche API**; siehe Abschnitt 6 |
| TradeSkillMaster, GatherMate2, Syndicator | Kein Zugriff mehr. `Core/Probe.lua` prüft lediglich, ob die Syndicator-Funktion existiert |
| Grafik | Eigenes Grafikset (`tools/assets/make_assets.py`), Logo und Banner per Bildgenerator ohne Spielgrafik; Bannerschrift STIX (SIL Open Font License, Lizenztext liegt bei) |
| Spieldaten (Item-IDs, Rezeptnamen, Zonen) | Fakten aus Classic-Leitfäden, keine Texte übernommen |

## 4. Im Audit gefunden und behoben (11.11.2026)

| Nr. | Mangel | Folge | Behebung |
|---|---|---|---|
| 1 | Das Verkaufsbuch erkannte Rechnungen an der Restlaufzeit der Post. Die ändert sich laufend | Derselbe Verkauf wurde mehrfach gezählt, sobald der Briefkasten länger offen war oder erneut geöffnet wurde | Rechnungen werden je Item, Preis und Menge gezählt; neuer Test in `tools/tests/mail_test.lua` |
| 2 | `/gw probe mail` speicherte Absender und Käufer der ersten Post | Verstoß gegen die eigene Datenschutz-Regel | Nur noch „vorhanden / leer" |
| 3 | Jeder Tooltip meldete eine bestandene Prüfung und löste damit ein Neuzeichnen des offenen Fensters aus | Unnötige Last und Speicherverbrauch bei jedem Überfahren eines Items | `Checks` schreibt und zeichnet nur noch bei geändertem Status |
| 4 | Die Tooltip-Zeilen wurden bei jedem Aufruf neu berechnet; das Spiel ruft sie mehrmals pro Sekunde auf | Speicherverbrauch beim Verweilen auf einem Item | Ergebnis wird eine Sekunde wiederverwendet |
| 5 | Der Kisten-Erkenner kopierte bei jedem Tooltip alle Zeilen | Speicherverbrauch | Kopiert nur noch bei echten Kisten |
| 6 | `UNIT_SPELLCAST_SUCCEEDED` war für alle Einheiten registriert | In Gruppen und Schlachtzügen sehr viele unnötige Aufrufe | Nur noch für den eigenen Charakter |
| 7 | Die Teamansicht rechnete den Plan bei jedem einzelnen Taschen-Event neu | Last beim Plündern | Ein Durchlauf je Event-Schub |
| 8 | Die Einkaufsliste blieb bei „Warte auf den Preis…" hängen, wenn der Server keinen Preis lieferte | Knopf bis zum Schließen des Auktionshauses gesperrt | `COMMODITY_PRICE_UNAVAILABLE` führt zurück zur Suche |

Zusätzlich entfernt: die Vorlage `BackdropTemplate` an vier Fenstern (seit dem eigenen Grafikset ungenutzt, eine Abhängigkeit weniger).

## 5. Vor der Veröffentlichung zu erledigen
- Die Änderungen aus Abschnitt 4 und das neue Aussehen im Spiel testen (Tooltip, Briefkasten mit Verkaufsrechnungen, Einkaufsliste im Auktionshaus).
- Repo auf **public** stellen.
- Addon-Namen erneut auf CurseForge, Wago und GitHub prüfen (Stand 08.11.2026: „Goldweaver" frei).
- Drei Screenshots im Spiel aufnehmen (`16-PROJECT-PAGE.md`).
- Schritte für den Kontoinhaber in `12-CURSEFORGE.md` Abschnitt 4.

## 6. Bekannte Grenzen (kein Mangel, aber offen zu sagen)
- **RestedXP ohne öffentliche API:** Die Projektregel verlangt Zugriffe nur über öffentliche APIs. Für RestedXP gibt es keine; gelesen werden interne Tabellen, nichts davon wird kopiert oder gespeichert. Technisch harmlos (bei einer Umbenennung verschwindet nur die Routenzeile), aber eine bewusste Ausnahme von der Regel. Entscheidung offen: so lassen oder die RestedXP-Anbindung entfernen.
- Teile der Berufsdaten (Lehrernamen, Levelpfade, Sammelzonen) stammen aus Classic-Wissen und sind auf Forever nicht vollständig bestätigt; das Addon korrigiert sie durch eigene Beobachtung. README und Projektseite sagen das.
- Ein Kauf beim Händler wird beim Klick als Einkaufspreis gemerkt, auch wenn der Kauf danach scheitert (zum Beispiel volle Taschen). Der Preis selbst stimmt; nur die gemerkte Menge kann abweichen.
- Der Speicherbedarf der gespeicherten Daten ist begrenzt: Preise 30 Tage, Verkaufsbuch 2000 Einträge je Charakter, Fundorte 40 je Item und Zone, Fehlerliste 50, Debug-Log 200 Zeilen.

## 7. Nicht-WoW-Richtlinien
- **GitHub:** keine Secrets im Repo (Packager-Schlüssel nur als GitHub Secrets).
- **CurseForge/Wago:** Open Source, keine Werbung, keine externen Downloads im Addon.
- **Datenschutz:** SavedVariables enthalten nur eigene Charaktere, gesehene Preise, eigene Verkäufe und eigene Fundorte. Keine Namen anderer Spieler. Keine Daten verlassen den Rechner.

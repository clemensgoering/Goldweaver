# Richtlinien-Audit Goldweaver

Letzter Durchlauf: 08.11.2026, Commit nach `4f29e8c`. Geprüft wurden alle Lua-Dateien, TOC, Workflows, Dokumente und die Fremdcode-Nutzung. Methode: Grep nach geschützten Aktionen, Timern, Kampf-APIs, globalen Schreibzugriffen, Fremd-Addon-Zugriffen; Abgleich der Bezeichner mit ForeverArtisan; Sichtung der Lizenzdateien der installierten Addons.

## Ergebnis in einem Satz
Der aktuelle Stand verletzt keine Blizzard-Richtlinie und keine Fremdlizenz. Zwei Punkte wurden im Zuge des Audits vorsorglich geändert (Abschnitt 4), zwei Punkte sind vor der Veröffentlichung zu erledigen (Abschnitt 5).

## 1. Blizzard UI Add-On Development Policy

| Regel | Befund | Status |
|---|---|---|
| Kostenlos | Keine Bezahlfunktion, keine Premium-Variante, MIT-Lizenz | erfüllt |
| Code vollständig sichtbar | Reines Lua, keine Obfuskation. Das GitHub-Repo ist derzeit **privat**; für eine Veröffentlichung muss es öffentlich sein oder das Release-Zip den vollständigen Quellcode enthalten (tut es, Lua ist Klartext) | erfüllt, Repo vor Release öffentlich stellen |
| Kein Schaden für Realms/Spieler | Keine Schleifen über AH-Anfragen, kein `OnUpdate`, ein `C_Timer.After` nur zum Ausblenden eines Testbuttons. Probe sendet höchstens eine Suche und einen Vollscan, jeweils nur auf expliziten Befehl | erfüllt |
| Keine Werbung | Keine Links, keine Produktnennungen außer funktionaler Nennung optionaler Addons in TOC `OptionalDeps` | erfüllt |
| Keine Spendenaufrufe | Keine im Code, keine in Texten | erfüllt |
| Kein anstößiger Inhalt | Nur technische Texte | erfüllt |
| ToU/EULA | Abschnitt 2 | erfüllt |
| Blizzard darf abschalten | Jede API wird vor Aufruf auf Existenz geprüft, Fehler werden abgefangen, nichts wird umgangen | erfüllt |

## 2. Nutzungsbedingungen: Automatisierung, Throttles, Secret Values

| Prüfpunkt | Befund |
|---|---|
| Geschützte Aktionen nur per Hardware-Event | Im Code gibt es noch keine Post-, Kauf-, Herstell- oder Entzauber-Aktion. Die einzigen Server-Anfragen (`SendSearchQuery`, `ReplicateItems`, `RequestLoadItemDataByID`) laufen ausschließlich im Slash-Handler von `/gw probe`, also auf eine Tastatureingabe hin, genau einmal pro Aufruf |
| Throttle | `SendSearchQuery` wird nur gesendet, wenn `IsThrottledMessageSystemReady()` wahr ist. `ReplicateItems` nur auf den eigenen Unterbefehl `replicate` |
| Timer lösen keine Aktionen aus | Einziger Timer blendet nach 20 s den Testbutton aus, geschützt durch `InCombatLockdown()` |
| Secret Values | Kein Zugriff auf Kampf-, Auren-, Cooldown- oder Combat-Log-APIs (Grep leer). Alle Event-Handler laufen über `ns.Events` mit Secret-Guard. Probe gibt Werte nur über `show()` aus, das Secrets als `<secret>` maskiert |
| Kein Kampfvorteil | Das Addon enthält keine Kampffunktion |
| Kein Echtgeld-Bezug, kein GDKP | nichts dergleichen |
| Addon-Kommunikation/Chat | Keine `SendChatMessage`, keine `SendAddonMessage`; Ausgaben nur lokal in den Chatframe |
| Makros | Der Secure-Test nutzt `/run print(...)`. Ob `/run` in Makrotext auf Forever noch erlaubt ist, ist offen (F12); die spätere Zerlegen-Queue braucht nur `/cast` |

## 3. Lizenzen und Fremdcode

| Quelle | Befund |
|---|---|
| Eigener Code | MIT, `LICENSE` vorhanden, `X-License: MIT` in der TOC |
| ForeverArtisan („All rights reserved") | Kein Code, keine Datentabelle, keine Bezeichner übernommen (Grep auf `FA.`, `GuardEvents`, `RegisterMarket`, `PickNext`, `CharRec`, `SourceFor`, `GrayAt`, `Matsledger` ohne Treffer). Architektur-Ideen (API-Fallback-Reihenfolge, Secret-Guard) sind nicht schutzfähig |
| Auctionator („All Rights Reserved", externe API ausdrücklich für Fremd-Addons) | Nur `Auctionator.API.v1.GetAuctionPriceByItemID` und `GetAuctionAgeByItemID` werden aufgerufen, mit `callerID = "Goldweaver"` wie von der API verlangt. Keine internen Tabellen, keine SavedVariables |
| TradeSkillMaster (proprietär) | Nur `TSM_API.GetCustomPriceValue`, die öffentliche API |
| Syndicator, GatherMate2 | Noch kein Zugriff im Code. Vor WP1.4/WP2.6 Lizenz prüfen; Laufzeit-Lesen öffentlicher Tabellen ist keine Codeübernahme |
| Guides (wow-professions, Mobalytics u. a.) | Nur Fakten übernommen (Rezeptnamen, Materialmengen, Levelbereiche), keine Texte. Fakten sind nicht urheberrechtlich geschützt |
| Blizzard-Spieldaten (Item-IDs, Rezeptnamen, Skill-Line-IDs) | Übliche, geduldete Addon-Praxis |
| BigWigs-Packager, GitHub Actions (leafo/gh-actions-lua) | Open Source, Standardwerkzeuge |

## 4. Im Audit geändert
1. **Probe speicherte den Verkäufernamen** eines Replicate-Beispiels in den SavedVariables. Geändert auf „Feld vorhanden ja/nein", weil Goldweaver keine Namen anderer Spieler speichern soll (Datenschutz-Regel in `CLAUDE.md` ergänzt).
2. **Secure-Test** meldet jetzt getrennt, ob der Klick ankommt (PreClick) und ob der Makrotext läuft, damit F12 (`/run` in Makros) sauber beantwortet wird.

## 5. Vor der Veröffentlichung zu erledigen
- Repo auf **public** stellen oder sicherstellen, dass das Release-Zip den gesamten Quellcode enthält (Regel „Code sichtbar"); Packager-Zip enthält ohnehin nur Klartext-Lua.
- Addon-Namen erneut auf CurseForge/Wago/GitHub prüfen (Stand 08.11.2026: „Goldweaver" frei).
- Dieses Audit erneut durchführen, sobald WP1.5 (Post), WP1.6 (Zerlegen), WP3.x (AH) Code enthalten: dort entstehen die ersten echten geschützten Aktionen. Prüfpunkte: ein Klick pro Aktion, kein Fortschalten per Timer, `IsThrottledMessageSystemReady()` vor jeder AH-Anfrage, keine Käufernamen aus Rechnungen speichern.

## 6. Nicht-WoW-Richtlinien
- **GitHub:** MIT-Lizenz, keine Secrets im Repo (Packager-Keys nur als GitHub Secrets), `.gitignore` schließt lokale Einstellungen aus.
- **CurseForge/Wago-Regeln:** Open Source, keine Werbung, keine externen Downloads im Addon. Erfüllt.
- **Datenschutz:** SavedVariables enthalten nur eigene Charaktere, eigene Preise und Probe-Ergebnisse. Keine Daten verlassen den Rechner (Lua hat keinen Netzwerkzugriff).

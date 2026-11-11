# Goldweaver – Grafik-Aufträge (für Codex oder einen Grafiker)

Stand: 11.11.2026. **Erledigt:** A1 und A2 (Logo `Goldweaver/Media/logo.tga` und `logo64.tga`, CurseForge-Logo und Banner unter `tools/assets/brand/`) sowie A5 (ersetzt durch das eigene Grafikset aus `tools/assets/make_assets.py`). Offen und optional: A3, A4, A6, A7. Jeder Auftrag ist eigenständig umsetzbar. Ergebnisse kommen nach `Goldweaver/Media/` und werden im Code referenziert (Pfade unten). Lizenz: eigene Werke, im Repo unter MIT; keine Blizzard-Grafiken kopieren, keine Markenlogos.

## Technische Vorgaben für alle Texturen
- Format **TGA 32-Bit unkomprimiert mit Alphakanal** (sicherste Wahl für den WoW-Client) oder PNG (Mainline unterstützt PNG; TGA bevorzugen).
- Kantenlängen **Zweierpotenzen** (16, 32, 64, 128, 256, 512). Nicht-quadratisch ist erlaubt (z. B. 256×64).
- Transparenter Hintergrund, keine Schlagschatten außerhalb des Motivs, 2 px Sicherheitsrand.
- Farbwelt: Gold-Akzent `#D4A94E`, dunkles Braun `#2B2218`, Elfenbein `#F1E6C8`, Aktionsfarben Grün `#7FD17F` (Gewinn), Rot `#D9534F` (Verlust), Lila `#B48CFF` (Entzaubern). Flach, hoher Kontrast, lesbar bei 16 px.
- Motivwelt: Weberei, Garnrolle, Nadel, Goldmünze, Stoffbahn. Kein Text in Icons.
- Dateinamen klein, ohne Leerzeichen; jede Datei auch als PNG-Vorschau mitliefern.

## A1 Addon-Icon (TOC `## IconTexture`, Addon-Liste) und CurseForge-Logo
- Datei `Goldweaver/Media/icon.tga`, 64×64 für die Addon-Liste. Zusätzlich **`docs/assets/logo-400.png`, 400×400, PNG (kein WebP), 1:1** als CurseForge-Projektlogo: muss ein Originalmotiv sein, keine Einfarbfläche, kein Blizzard-Artwork (CurseForge-Moderationsregel).
- Motiv: Garnrolle mit goldenem Faden, der zu einer Münze ausläuft. Runde Silhouette, dunkler Innenkreis, goldener Rand 3 px.
- Einbau: `## IconTexture: Interface\AddOns\Goldweaver\Media\icon` in `Goldweaver.toc` (ersetzt `INV_Misc_Coin_01`).

## A2 Minimap-Button
- Datei `Goldweaver/Media/minimap.tga`, 32×32, Motiv wie A1 ohne Rand (der Rand kommt vom Spiel-Tracking-Border).
- Einbau: `ICON` in `UI/Minimap.lua`.

## A3 Rollen-Icons (Fenster „Charaktere", Erstlauf-Karte, HUD)
- Dateien `Goldweaver/Media/role_main.tga`, `role_processor.tga`, `role_bank.tga`, je 32×32.
- Main: Rucksack mit Kräuterzweig. Verarbeiter: Amboss mit Nadel. Bank: Truhe mit Münzschlitz.
- Einbau: `Chars.ROLE_ICONS` (neu) in `Core/Chars.lua`, verwendet in `UI/MainWindow.lua` und `Modules/Onboarding.lua`.

## A4 Aktions-Glyphen für Taschen-Overlay und Listen
- Dateien `Goldweaver/Media/glyph_send.tga` (Pfeil nach oben in Goldkreis), `glyph_disenchant.tga` (lila Funken), `glyph_keep.tga` (goldenes Schloss), `glyph_vendor.tga` (graue Münze), `glyph_crate.tga` (Kiste), je 16×16 und 32×32.
- Einbau: Taschen-Overlay (geplant, `Modules/BagOverlay.lua`) und Spalte „Empfehlung" in Listen.

## A5 Gruppen-Rahmen und Fensterhintergrund (optional)
- `Goldweaver/Media/frame_edge.tga` 256×16 (kachelbar, dünne goldene Linie mit Webmuster), `frame_bg.tga` 256×256 (sehr dunkles, kaum sichtbares Stoffmuster, Alpha 60 %).
- Einbau: `UI.Group` in `UI/Kit.lua` (ersetzt `UI-Tooltip-Border` und `ChatFrameBackground`).

## A6 CurseForge-Galerie
- `social.png` 1200×630: Logo links, rechts drei Zeilen Nutzen („Was schicke ich wem? Was stelle ich her? Was lohnt sich?"), gleiche Farbwelt.
- Drei Screenshots kommen aus dem Spiel (Tooltip, Briefkasten-Knopf, Berufe-Leitfaden) und werden mit einem Satz Bildunterschrift versehen; dafür ist kein Grafikauftrag nötig.

## A7 Statusfarben-Legende (Dokumentation, kein Spiel-Asset)
- Eine kleine Grafik 600×200 für README/CurseForge: die fünf Aktionsfarben mit Bedeutung.

## Abnahme pro Asset
1. Datei liegt unter `Goldweaver/Media/`, Größe ist Zweierpotenz, Alpha korrekt (im Spiel kein schwarzer Kasten).
2. Im Spiel bei 100 % UI-Skalierung erkennbar; Minimap-Icon auch bei 0,8.
3. `tools/check.ps1` bleibt grün (keine Lua-Änderung außer Pfaden).
4. Eintrag in `CHANGELOG.md`.

## Auftragstext für Codex (Vorlage)
> Erstelle das Asset **A1 Addon-Icon** nach `docs/11-ASSETS.md`: 64×64 TGA 32-Bit mit Alpha, Motiv Garnrolle mit goldenem Faden zu Münze, Palette `#D4A94E/#2B2218/#F1E6C8`, transparenter Hintergrund, 2 px Rand, zusätzlich 256×256 PNG. Speichere unter `Goldweaver/Media/icon.tga` und `docs/assets/icon-256.png`, trage den Pfad in `Goldweaver/Goldweaver.toc` (`## IconTexture`) ein und ergänze `CHANGELOG.md`. Keine Blizzard-Grafiken, kein Text im Icon.

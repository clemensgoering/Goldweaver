# Veröffentlichung auf CurseForge (und Wago)

Stand: 11.11.2026. Recherchiert gegen die CurseForge-Hilfe („Creating and submitting a project", „Project Submission Guide and Tips", „Moderation Policies"), den BigWigs-Packager (README, Wiki, release.sh) und die TOC-Dokumentation. Alles, was das Repo betrifft, ist umgesetzt; die Schritte in Abschnitt 4 kann nur der Kontoinhaber ausführen.

## 1. Was CurseForge verlangt und wie das Repo es erfüllt

| Anforderung (CurseForge) | Umsetzung |
|---|---|
| Projektname eindeutig, **auf Englisch**, ohne Spielname/Versionsnummer | „Goldweaver" (08.11.2026 auf CurseForge, Wago und GitHub frei) |
| Summary: ein Satz, was das Projekt tut, nicht wer es gemacht hat | Abschnitt 3 |
| Beschreibung: **Englisch zuerst**, funktional, grammatisch korrekt, keine Fremd-Downloads, Spenden-/Website-Links nur unten und klein | Abschnitt 3; keine Downloads, keine Werbung |
| Lizenz aus der Liste | MIT (`LICENSE` im Repo, `## X-License: MIT`) |
| Logo mind. 400×400 px, PNG, Original, keine Einfarbfläche, kein Spiel-Artwork, kein WebP | `tools/assets/brand/logo_400.png` (eigenes Motiv: goldener Faden um eine Münze) |
| Zip mit **genau einem Wurzelordner**, dessen Name der TOC entspricht | Packager mit `package-as: Goldweaver` und `move-folders` (Addon liegt im Repo unter `Goldweaver/`) |
| Release-Typ „Release" für Sichtbarkeit in der App, Changelog pro Datei | Packager: Tag ohne „beta/alpha" = Release; `manual-changelog: CHANGELOG.md` (Markdown) |
| Spielversion Forever | automatisch aus `## Interface: 16001` (Packager erkennt `16???` als Forever) |
| Kein obfuskierter Code, Code sichtbar (Blizzard-Richtlinie) | Klartext-Lua; Repo vor Release auf public |
| Screenshots: In-Game, mit aktiviertem Addon | drei Screenshots mit Bildunterschrift laut `16-PROJECT-PAGE.md` (noch aufzunehmen) |
| Änderungen echter Natur (kein Re-Upload-Spam) | Releases nur mit Changelog-Eintrag |

## 2. Technik im Repo (fertig)
- `.pkgmeta`: `package-as`, `move-folders: Goldweaver/Goldweaver: Goldweaver`, `ignore` für docs/tools/README/CHANGELOG/CLAUDE.md, `manual-changelog` mit Markdown.
- `Goldweaver.toc`: `## Version: @project-version@` (wird durch den Tag ersetzt; im Spiel ohne Paket „dev"), `## Notes` englisch zuerst plus `## Notes-deDE`, `## Category: Professions`, `## X-License`, `## X-Website`, `## IconTexture` zeigt auf das eigene Logo (`Media\logo64`). Die Zeilen `## X-Curse-Project-ID` und `## X-Wago-ID` fehlen noch und kommen in Schritt 5 dazu.
- `.github/workflows/release.yml`: läuft bei Tag `v*`, prüft Lua/Tests, paketiert, erstellt GitHub-Release, lädt zu CurseForge/Wago hoch, sobald die Secrets gesetzt sind. Beide Token-Namen (`CF_API_KEY`/`CF_API_TOKEN`, `GITHUB_OAUTH`/`GH_API_TOKEN`) werden gesetzt, weil der Packager sie im Lauf der Zeit umbenannt hat. `-w 0` deaktiviert WoWInterface (unterstützt Forever nicht).
- CI (`check.yml`) prüft jeden Push: Syntax, luacheck, Headless-Tests und Simulator mit Layout-Prüfung.

## 3. Texte für die Projektseite
Die fertigen englischen Texte (Name, Summary, Kategorien, Beschreibung, Bildunterschriften) stehen kopierbereit in `16-PROJECT-PAGE.md`. Das Changelog für Spieler ist `CHANGELOG.md` im Repo-Wurzelordner (Englisch); der Packager lädt es bei jedem Release mit hoch. Der interne deutsche Verlauf liegt in `15-ENTWICKLUNGSLOG.md`.

## 4. Schritte für den Kontoinhaber (einmalig)
1. CurseForge: Projekt anlegen (Spiel World of Warcraft, Klasse Addons, Kategorie Professions, Zusatz Auction & Economy), Name „Goldweaver", Summary und Description aus `16-PROJECT-PAGE.md`, Lizenz MIT, Logo `tools/assets/brand/logo_400.png`, Banner `banner_1600x500_text.png` oben in die Beschreibung. Projekt-ID notieren.
2. CurseForge: unter Account → API Tokens einen Token erzeugen.
3. Wago (optional): Projekt anlegen, ID notieren, API-Key erzeugen.
4. GitHub: Repository → Settings → Secrets and variables → Actions: `CF_API_KEY`, optional `WAGO_API_TOKEN`. Settings → Actions → General → Workflow permissions auf „Read and write" stellen (für den GitHub-Release).
5. TOC: `## X-Curse-Project-ID: <ID>` und `## X-Wago-ID: <ID>` eintragen, committen.
6. Repo auf **public** stellen.
7. Release: in `CHANGELOG.md` die Überschrift `## Unreleased` in `## 0.1.0` ändern, committen, annotierten Tag setzen und pushen:
   ```
   git tag -a v0.1.0 -m "0.1.0"
   git push origin v0.1.0
   ```
   Der Workflow erstellt das Zip `Goldweaver-v0.1.0.zip`, den GitHub-Release und den CurseForge-Upload (Status „Under Review", Freigabe durch Moderation).
8. Nach Freigabe: drei In-Game-Screenshots in die Galerie, je ein Satz Bildunterschrift.

## 5. Testbuild ohne Upload (jederzeit)
Lokal in Git Bash im Repo-Root:
```
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -d -z
```
`-d` kein Upload, `-z` kein Zip; das Ergebnis liegt in `.release/Goldweaver/` und zeigt, ob der Wurzelordner, die TOC-Version und der Changelog stimmen. (`.release/` ist in `.gitignore`.)

## 6. Richtlinien-Fallen, die vermieden sind
- Keine Links zu externen Downloads, keine Werbung, keine Spendenaufrufe im Spiel.
- Keine Blizzard-Grafik als Logo: Logo, Banner und das Symbol in der Addon-Liste sind eigene Werke.
- Kein Fremdcode (ForeverArtisan proprietär, Auctionator nur API), Lizenz eindeutig MIT.
- Name ohne „WoW", „Forever" oder Versionsnummer.

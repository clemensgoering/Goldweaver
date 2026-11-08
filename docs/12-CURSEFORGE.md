# Veröffentlichung auf CurseForge (und Wago)

Stand: 08.11.2026. Recherchiert gegen die CurseForge-Hilfe („Creating and submitting a project", „Project Submission Guide and Tips", „Moderation Policies"), den BigWigs-Packager (README, Wiki, release.sh) und die TOC-Dokumentation. Alles, was das Repo betrifft, ist umgesetzt; die Schritte in Abschnitt 4 kann nur der Kontoinhaber ausführen.

## 1. Was CurseForge verlangt und wie das Repo es erfüllt

| Anforderung (CurseForge) | Umsetzung |
|---|---|
| Projektname eindeutig, **auf Englisch**, ohne Spielname/Versionsnummer | „Goldweaver" (08.11.2026 auf CurseForge, Wago und GitHub frei) |
| Summary: ein Satz, was das Projekt tut, nicht wer es gemacht hat | Abschnitt 3 |
| Beschreibung: **Englisch zuerst**, funktional, grammatisch korrekt, keine Fremd-Downloads, Spenden-/Website-Links nur unten und klein | Abschnitt 3; keine Downloads, keine Werbung |
| Lizenz aus der Liste | MIT (`LICENSE` im Repo, `## X-License: MIT`) |
| Logo mind. 400×400 px, PNG, Original, keine Einfarbfläche, kein Spiel-Artwork, kein WebP | Auftrag A1 in `11-ASSETS.md` (angepasst auf 400×400 PNG) |
| Zip mit **genau einem Wurzelordner**, dessen Name der TOC entspricht | Packager mit `package-as: Goldweaver` und `move-folders` (Addon liegt im Repo unter `Goldweaver/`) |
| Release-Typ „Release" für Sichtbarkeit in der App, Changelog pro Datei | Packager: Tag ohne „beta/alpha" = Release; `manual-changelog: CHANGELOG.md` (Markdown) |
| Spielversion Forever | automatisch aus `## Interface: 16001` (Packager erkennt `16???` als Forever) |
| Kein obfuskierter Code, Code sichtbar (Blizzard-Richtlinie) | Klartext-Lua; Repo vor Release auf public |
| Screenshots: In-Game, mit aktiviertem Addon | drei Screenshots laut `08-UX.md` Abschnitt 5 |
| Änderungen echter Natur (kein Re-Upload-Spam) | Releases nur mit Changelog-Eintrag |

## 2. Technik im Repo (fertig)
- `.pkgmeta`: `package-as`, `move-folders: Goldweaver/Goldweaver: Goldweaver`, `ignore` für docs/tools/README/CHANGELOG/CLAUDE.md, `manual-changelog` mit Markdown.
- `Goldweaver.toc`: `## Version: @project-version@` (wird durch den Tag ersetzt; im Spiel ohne Paket „dev"), `## Notes` englisch zuerst plus `## Notes-deDE`, `## Category: Professions`, `## X-License`, `## X-Website`, Platzhalter `## X-Curse-Project-ID: 0` und `## X-Wago-ID:`.
- `.github/workflows/release.yml`: läuft bei Tag `v*`, prüft Lua/Tests, paketiert, erstellt GitHub-Release, lädt zu CurseForge/Wago hoch, sobald die Secrets gesetzt sind. Beide Token-Namen (`CF_API_KEY`/`CF_API_TOKEN`, `GITHUB_OAUTH`/`GH_API_TOKEN`) werden gesetzt, weil der Packager sie im Lauf der Zeit umbenannt hat. `-w 0` deaktiviert WoWInterface (unterstützt Forever nicht).
- CI (`check.yml`) prüft jeden Push: Syntax, luacheck, 218 Tests.

## 3. Texte für die Projektseite (Englisch zuerst, wie verlangt)

**Summary (one line):**
> Tells you what to do with every item, what to craft, how to level each profession cheapest and what earns gold on WoW: Forever.

**Description:**
> **Goldweaver** turns professions, mail and the auction house into one decision engine for WoW: Forever.
>
> - **Tooltip:** one line per item with the best use and its value: send to your crafter, disenchant, craft, sell, put in a Waylaid Crate or keep for a skill-up. Shift shows all options and the price source. A stock line shows what your bank and alts already hold.
> - **Mailbox:** one button attaches everything your crafter should get, one button sends. "Open all" empties the inbox and records your sales.
> - **Profession guide (/gw):** for every profession you have: next skill-up with the cheapest recipe per point, shopping list with have/need across characters, what is worth crafting after the auction house cut, recipes you have not learned and where we have seen them (trainers and vendors you visited), when and where to train the next rank.
> - **Disenchant queue:** lists items where disenchanting beats selling; one click per item.
> - **Auction house:** reads the search pages you look at into a price database and suggests an undercut price with deposit and net proceeds when you sell. Works with Auctionator prices when installed.
> - **Self-checking:** the addon verifies its own features while you play and learns server rules (deposits, mail formats, skill-up chances) from observation.
>
> No automation: every post, send, craft or disenchant is one click. No ads, no donations in game. Open source (MIT).
>
> German and English clients; interface texts are German first, English localisation in progress.
>
> Feedback: GitHub issues (link at the bottom).

**Changelog:** aus `CHANGELOG.md`, Abschnitt der Version.

## 4. Schritte für den Kontoinhaber (einmalig)
1. CurseForge: Projekt anlegen (Spiel World of Warcraft, Klasse Addons, Kategorie Professions, Zusatz Auction & Economy), Name „Goldweaver", Summary und Description aus Abschnitt 3, Lizenz MIT, Logo 400×400 PNG (A1). Projekt-ID notieren.
2. CurseForge: unter Account → API Tokens einen Token erzeugen.
3. Wago (optional): Projekt anlegen, ID notieren, API-Key erzeugen.
4. GitHub: Repository → Settings → Secrets and variables → Actions: `CF_API_KEY`, optional `WAGO_API_TOKEN`. Settings → Actions → General → Workflow permissions auf „Read and write" stellen (für den GitHub-Release).
5. TOC: `## X-Curse-Project-ID: <ID>` und `## X-Wago-ID: <ID>` eintragen, committen.
6. Repo auf **public** stellen.
7. Release: `CHANGELOG.md` Abschnitt `## 0.1.0` anlegen, committen, annotierten Tag setzen und pushen:
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
- Keine Blizzard-Grafik als Logo (das eingebaute Münz-Icon ist nur die In-Game-Vorschau in der Addon-Liste, nicht das CurseForge-Logo).
- Kein Fremdcode (ForeverArtisan proprietär, Auctionator nur API), Lizenz eindeutig MIT.
- Name ohne „WoW", „Forever" oder Versionsnummer.

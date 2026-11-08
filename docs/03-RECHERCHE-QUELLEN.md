# Recherche-Notizen und Quellen

Stand: 08.11.2026. Vertrauensgrad: **A** = offiziell/Primärquelle oder Quellcode, **B** = mehrere unabhängige Community-Quellen, **C** = einzelne Fan-Seite oder Beta-Stand, widersprüchlich oder unbestätigt.

## WoW: Forever allgemein
| Fakt | Grad | Quelle |
|---|---|---|
| Offizieller dritter Zweig, Launch 04.11.2026 (NA) / 05.11.2026 00:00 CET (EU), Level 60, kein Flying, kein WoW-Token | B | [Blizzard Watch](https://blizzardwatch.com/2026/11/04/world-warcraft-forever-servers-yet-absolutely-not/), [Mein-MMO](https://mein-mmo.de/en/wow-forever-release-in-the-live-ticker-time-status-queues-and-more,1594825/), [Wikipedia](https://en.wikipedia.org/wiki/World_of_Warcraft), [G2A News](https://www.g2a.com/news/upcoming-game-releases/world-of-warcraft-forever-explained/) |
| Raids öffnen 09.12.2026 | C | [LFCarry](https://lfcarry.com/guides/wow-forever-gold-economy) |
| Fan-Server „Forever WoW" (255 Funserver) ist etwas anderes | A | [foreverwow.org](https://www.foreverwow.org/) |

## Addon-API und TOC
| Fakt | Grad | Quelle |
|---|---|---|
| Interface 16001, Client 1.60.1, Suffixe `_Camelot.toc`/`_Forever.toc`, `AllowLoadGameType: camelot/forever`, Mehrfach-Interface-Zeile | A | [Warcraft Wiki TOC format](https://warcraft.wiki.gg/wiki/TOC_format) |
| `WOW_PROJECT_CAMELOT = 18`; Packager v2.6+; CurseForge Game-Type 88568; WoWInterface ohne Forever; Ace3-Trunk listet 16001 | B | [bff-wow Issue #3](https://github.com/Shtian/bff-wow/issues/3) |
| Mainline-UI-Architektur, „vast majority of APIs available in 12.1.5", Secret Values gelten, Combat-Log nicht verfügbar | B | [ForeverMeta](https://forevermeta.me/en/guides/wow-forever-addons-interface), [Warperia](https://warperia.com/wow-forever-inherits-midnights-addon-changes/) |
| Secret-Values-Mechanik im Detail, `C_RestrictedActions`, SavedVariables ohne Secrets | A | [Warcraft Wiki Patch 12.0.0 API changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes) |
| Fehlende Globals (`GetItemInfo`, `GetSpellInfo`), `C_Item`/`C_Spell`, Secure-Snippets kompilierten auf Beta-Build 69913 nicht, `/dump select(4, GetBuildInfo())` | C | [wowforeverguides.com Developer Guide](https://wowforeverguides.com/addons/developers) |
| `C_TradeSkillUI`-Funktionen sind im Wiki mit „forever" 1.60.1 getaggt | B | [C_TradeSkillUI.GetTradeSkillListLink](https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetTradeSkillListLink), [GetChildProfessionInfo](https://warcraft.wiki.gg/wiki/API_C_TradeSkillUI.GetChildProfessionInfo) |
| ForeverArtisan: API-Reihenfolge `C_TradeSkillUI` → `GetTradeSkillInfo` → `GetCraftInfo`; Auctionator API v1 als Preisquelle; „never send AH queries"; Secret-Guard pro Event-Frame; Lizenz „All rights reserved" | A (Quellcode) | [ForeverArtisan Repo](https://github.com/ForeverArtisan/ForeverArtisan) (README, docs/ARCHITECTURE.md, LICENSE, Tailoring.lua) |
| Auctionator nutzt `C_AuctionHouse`, setzt `IsForever` für Builds 16000–19999, 15-Min-Eigensperre für Vollscans, Laufzeiten 2/8/24 h | B (Analyse des Auctionator-Quellcodes durch Dritte) | [wow-artisan Issue #1](https://github.com/edloidas/wow-artisan/issues/1) |
| `ReplicateItems`: 15-Min-Account-Throttle auf Retail, Disconnect-Risiko bei >80k Auktionen; ob auf 1.60 lauffähig: offen | A/C | [Warcraft Wiki ReplicateItems](https://warcraft.wiki.gg/wiki/API:C_AuctionHouse.ReplicateItems), [WowVision Issue #91](https://github.com/wow-vision/WowVision/issues/91) |
| Blizzard AH-„Budget" pro Minute (8.3, Juni 2020), später gelockert außer Cancel; TSM: ~50 Cancels dann 60 s Verzögerung | A/B | [Wowhead](https://www.wowhead.com/news=316512/blizzard-significantly-reduces-auction-house-throttling), [Blizzard-Forum](https://us.forums.blizzard.com/en/wow/t/auction-house-much-slower-today-june-16/556722/13), [TSM Support](https://support.tradeskillmaster.com/en_US/addon/why-are-my-cancel-scans-very-slow) |

## Richtlinien
| Fakt | Grad | Quelle |
|---|---|---|
| UI Add-On Development Policy, 8 Regeln | A | [Blizzard-Forum](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534) |
| „Addons should no longer offer a competitive advantage in WoW combat", für Forever bestätigt 15.09.2026; GDKP in Forever untersagt; Paid-Addon-Debatte offen | B | [ForeverMeta](https://forevermeta.me/en/guides/wow-forever-addons-interface) |
| Auctionator-Lizenz MIT | C (Org-Listing, Repo 404) | [GitHub Auctionator Org](https://github.com/orgs/Auctionator/repositories?type=all) |

## Wirtschaft, AH, Post
| Fakt | Grad | Quelle |
|---|---|---|
| AH pro Regelsatz × Fraktion × Region, 24 AHs weltweit, Rulesets teilen kein AH | B | [AHledger](https://ahledger.com/wow-forever/auction-house), [Forever Guides](https://theforeverguides.com/gold-making/auction-house/), [WoW Campfire](https://wowcampfire.com/articles/cross-ruleset-mail-and-auction-house-question) |
| 5 % Cut Fraktions-AH, 15 % Goblin-AH, Einzahlung bei Verkauf erstattet | B | [LFCarry](https://lfcarry.com/guides/wow-forever-gold-economy), [Forever Guides](https://theforeverguides.com/gold-making/auction-house/) |
| Laufzeiten 2/8/24 h vs. 12/24/48 h | C (widersprüchlich) | wow-artisan Issue #1 vs. AHledger |
| Post an eigene Charaktere sofort, 30 Kupfer, nicht über Fraktion/Regelsatz/Region, 30+30 Tage Haltefrist | B | [Method](https://www.method.gg/wow-forever/bank-alts-in-wow-forever-do-you-need-one-what-is-it-for) |
| Beta-Bug: Post nach Vorname zugestellt | C | [PewPewShop](https://pewpewshop.pro/wow-boost/blog~wow-forever-beta-mail-going-to-the-wrong-character) |
| Vendorpreise für Craft-Items gesenkt, Beutel/Barren/Leder/Essen Schnelldreher, Rezepte oft knapp an Null | C | [LFCarry](https://lfcarry.com/guides/wow-forever-gold-economy) |
| TSM 4.15 mit Forever-Support ab 04./05.11.2026, Desktop-App | A | [TSM News](https://tradeskillmaster.com/news/tsm-4-15-brings-wow-forever-support-plus-new-desktop-app-1180) |
| Auctionator Forever-Build seit Sept./Okt. 2026 | B | [wowforeveraddons.com](https://wowforeveraddons.com/addons/auctionator), [mmonster](https://mmonster.co/wow-forever/guides/addons/auctionator) |
| Gold Forever (Tooltip-Werte, Gold/h) | B | [CurseForge](https://www.curseforge.com/wow/addons/gold-forever) |

## Berufe
| Fakt | Grad | Quelle |
|---|---|---|
| Ränge 75/150/225/300, Anforderungen Skill 50/125/200 und Level 10/20/35, Lehrling ohne Level | B | [Mobalytics](https://mobalytics.gg/wow-forever/guides/tailoring-profession-guide), [wow-professions Tailoring](https://www.wow-professions.com/forever/tailoring-leveling-guide) |
| 859 neue Rezepte, 298 für Favor; viele Rezepte 25–35 Punkte früher grau; Heiltränke zu Erste Hilfe; Legacy-Perks (Working Overtime, Dedicated Study, Performance Bonus) | C | [classicwowforever.com](https://classicwowforever.com/professions/) |
| Schneiderei: 180 neue Muster, Raid-Sets, Reagenzbeutel, Zertifikat 1.000 Favor, Legacy Points bei 150/225/300 | C | [Zockify](https://www.zockify.com/forever/professions/tailoring/) |
| Schneiderei 1–265 Route und Materialmengen (225–300 ungetestet) | C (Beta) | [wow-professions Tailoring](https://www.wow-professions.com/forever/tailoring-leveling-guide) |
| Verzauberkunst 1–300 Route, Ruten, Annora in Uldaman als einziger Meister-Lehrer | C (Beta) | [wow-professions Enchanting](https://www.wow-professions.com/forever/enchanting-leveling-guide), [Mobalytics](https://mobalytics.gg/wow-forever/guides/enchanting-profession-guide) |
| Entzaubern ab Skill 1, im Berufefenster, Ergebnistabelle nach „Benötigt Stufe", Wahrscheinlichkeiten | B | [wow-professions Disenchanting](https://www.wow-professions.com/forever/disenchanting-guide), Mobalytics, [Icy Veins](https://www.icy-veins.com/wow-forever/professions-overview) |
| Merchant's Favor, Waylaid Crates, Curiosities-Bündel (20 Staub / 4 Greater Essence / 6 kleine / 2 große Splitter), Favor pro Kiste widersprüchlich | B/C | [wow-professions Favor](https://www.wow-professions.com/forever/merchants-favor-durotar-supply-azeroth-commerce), [Forever Guides](https://theforeverguides.com/professions/merchants-favor/), [Forevermastery](https://forevermastery.com/en/guides/wow-forever-merchants-favor), [urgametips](https://urgametips.com/wow-forever/waylaid-crates/) |
| ForeverArtisan deckt 12 Berufe + Camping + Trade Contacts ab | A | [Wago](https://addons.wago.io/addons/foreverartisan), [foreverartisan.app](https://foreverartisan.app/) |

## Nicht erreichbar oder nicht gefunden (08.11.2026)
- Auctionator GitHub (TheMouseNest/Auctionator, Auctionator/Auctionator): 404. API-Dokumentation (`Auctionator.API.v1`) muss aus dem installierten Addon (`Source/API/`) gelesen werden.
- Icy Veins Berufe-Übersicht und Blizzard-AH-Hotfix-Thread: 403 für den Abruf; Fakten über andere Quellen bestätigt.
- Offizielle Zahl des AH-Aktionsbudgets pro Minute: nicht veröffentlicht.

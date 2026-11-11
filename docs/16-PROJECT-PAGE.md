# Project page texts (CurseForge, Wago)

Copy-ready English texts for the project pages. Images: `tools/assets/brand/logo_400.png` (project logo, 400×400) and `tools/assets/brand/banner_1600x500_text.png` (banner at the top of the description). Steps for creating the project are in `12-CURSEFORGE.md`.

## Name

Goldweaver

## Summary (one line)

Tells you what to do with every item, what to craft, how to level each profession at the lowest cost and what earns gold on WoW: Forever.

## Categories

Professions (main), Auction & Economy, Mail, Bags & Inventory (one main category, three of at most four additional ones)

## Project settings

- Comments: allowed.
- Experimental: off.
- License: MIT License.
- Issues tracker and Source: the GitHub repository (`https://github.com/clemensgoering/Goldweaver`), once it is public.
- Donation method: none.

## Description

Paste this into the **Markdown** editor (choose Markdown instead of WYSIWYG when creating the project). Put the banner image above the first line.

**Goldweaver** connects professions, mail and the auction house on WoW: Forever. It works for a single character and for a team: one character gathers and mails materials, another one crafts.

### Why I built it

I play with two characters: my main gathers on the way, my alt crafts. Every item raised the same question: vendor, auction house, mail it to the alt, disenchant it or keep it for a skill point? The game answers that in five different windows. Goldweaver answers it in one line.

### What you get

- **A tooltip line on every item** with its best use and value: send to your crafter, disenchant, craft, sell on the auction house, sell to a vendor, put in a Waylaid Crate or keep for a skill-up. Hold Shift for the other options and the price source. A second line shows what your bank, mailbox and other characters hold.
- **A guide window (`/gw`)** with four tabs:
  - **Guide:** the most useful next step with one button, and a shared gathering list for gatherer and crafter.
  - **Field:** what to gather in the current zone for your skill, your remembered herb and ore spots, the best zones for your level.
  - **Professions:** all twelve professions. The cheapest next skill-up with a shopping list across your characters, what is worth crafting after the auction house cut, recipes you have not learned yet, when and where to train the next rank.
  - **Team:** the roles of your characters and a self-check.
- **Helpers at the game's own windows.** Small tabs under the mailbox, merchant, bank, auction house and trainer:
  - Mailbox: attach everything your crafter should get, then send.
  - Merchant: buy what the plan is missing, sell junk, repair.
  - Bank: take the stacks the plan needs, store what nobody needs right now.
  - Auction house: a shopping list in three clicks per material (search, buy, confirm) that stops when the price jumped.
  - Trainer: next rank and recipes with profit per craft.
- **Selling help.** Every search result you look at is remembered as a price. When you sell, a line suggests a price and shows deposit, proceeds and your break-even.
- **A disenchant queue (`/gw de`)** with the items where disenchanting beats selling.

### Getting started

1. Install Goldweaver and log in. It assigns the roles of your characters by itself (gatherer or crafter); you can change them in the Team tab.
2. Open each profession once so Goldweaver can read its recipes.
3. Open the window with `/gw` or the minimap button and follow the step card.
4. For prices, search the auction house as usual or install Auctionator.

### How it behaves

- **No automation.** Every purchase, sale, mail, craft and disenchant is one click on a button.
- **No required addons.** Auctionator prices are used when it is installed. A RestedXP route is read when RestedXP is active.
- **Your data stays on your computer.** Only your own characters, prices and sales are saved, never the names of other players.
- **Your data is never reset.** A backup is written before every data change (`/gw backup`, `/gw restore confirm`).
- **English and German,** switchable in the settings.

### Status

This is an early version. The decision logic, the mail flow and the auction house helpers are tested in game. Parts of the profession data (trainer names, levelling paths, gathering zones) come from Classic-era knowledge and are corrected by what the addon observes while you play.

### Feedback

Please report problems in the comments or as an issue (see the Issues link of this project) and attach the report from `/gw debug run`. Open source under the MIT license.

## Image captions (gallery)

Three in-game screenshots, taken with the addon active:

1. Tooltip: "One line per item: best use and value. Shift shows every option."
2. Guide window, Professions tab: "Cheapest next skill-up with a shopping list across your characters."
3. Mailbox with the Goldweaver tab: "Attach everything your crafter needs, then send. One click each."

## Short text for the addon list (TOC `## Notes`)

Professions, mail pipeline and auction house as one decision engine: what to craft, how to level cheapest, what earns gold. Built for WoW: Forever.

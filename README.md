# Goldweaver

![Goldweaver: professions, mail and auction house](tools/assets/brand/banner_1600x500_text.png)

Goldweaver is an addon for **World of Warcraft: Forever** that connects professions, mail and the auction house. It tells you what to do with every item, what to craft, how to level each profession at the lowest cost and what earns gold. It covers all twelve professions and works for a single character or for a gatherer who mails materials to a crafter.

## What it does

- **Tooltip:** one line on every item with its best use and value: send to your crafter, disenchant, craft, sell on the auction house, sell to a vendor, put in a Waylaid Crate or keep for a skill-up. Hold Shift for the other options and the price source. A second line shows what your bank, mailbox and other characters hold.
- **Guide window (`/gw`):** four tabs.
  - *Guide* shows the most useful next step with one button, and the team view of gatherer and crafter with a shared gathering list.
  - *Field* shows what to gather in the current zone and remembers your herb and ore spots.
  - *Professions* shows the cheapest next skill-up with a shopping list, what is worth crafting, unlearned recipes and the next trainer rank.
  - *Team* holds the roles of your characters and the self-check.
- **Helpers at game windows:** small tabs under the mailbox, merchant, bank, auction house and trainer windows. Attach and send materials, buy what the plan is missing, sell junk, take and store bank stacks, work through a shopping list, learn recipes.
- **Auction house:** every search result you look at is remembered as a price. When you sell, a line suggests a price and shows deposit, proceeds and your break-even.
- **Disenchant queue (`/gw de`):** lists items where disenchanting beats selling.

## How it behaves

- **No automation.** Every purchase, sale, mail, craft and disenchant is one click on a button. Timers only update what is shown.
- **No required dependencies.** [Auctionator](https://www.curseforge.com/wow/addons/auctionator) prices are used when it is installed. A RestedXP route is read when RestedXP is active.
- **Your data stays yours.** Saved data holds only your own characters, prices you have seen and your own sales. Names of other players are never stored. Nothing leaves your computer.
- **Your data is never reset.** Structure changes are additive migrations, and a backup is written before each one (`/gw backup`, `/gw restore confirm`).
- **English and German,** switchable in the settings or with `/gw lang en|de|auto`.

## Install

Copy the `Goldweaver` folder into `World of Warcraft/_forever_/Interface/AddOns/` and restart the game. Open the window with `/gw` or the minimap button.

## Commands

| Command | Effect |
|---|---|
| `/gw` | Open the guide window; `/gw help` lists every command |
| `/gw de` | Disenchant queue |
| `/gw mail` | Explain what would be mailed and why the rest stays |
| `/gw panel` | Show or hide the side panel (`/gw panel reset` moves it back) |
| `/gw tooltip on\|off` | Tooltip lines on or off |
| `/gw lang en\|de\|auto` | Language |
| `/gw backup`, `/gw restore confirm` | Back up and restore saved data |
| `/gw debug run` | Self-check with a report you can copy |

## Status

This is an early version. The decision logic, the mail flow and the auction house helpers are tested in game. Parts of the profession data (trainer names, levelling paths, gathering zones) come from Classic-era knowledge and are corrected by what the addon observes while you play. If something is wrong, please open an issue and attach the report from `/gw debug run`.

## Development

The addon lives in `Goldweaver/`; `tools/` holds the checks, the simulator and the script that generates the art set.

1. Link the addon into the game: `mklink /J "<WoW>\_forever_\Interface\AddOns\Goldweaver" "<repo>\Goldweaver"`.
2. Run `tools/check.ps1` (Windows) or `tools/check.sh` before every commit. It runs a syntax check with LuaJIT, luacheck, the headless tests and a simulator that plays complete sessions through every module and checks the layout in both languages.
3. `tools/preview.ps1` renders every tab as an image without the game.
4. In game: `/console scriptErrors 1`, then `/gw debug run`.

Rules for contributions: Mainline API only (no Classic calls), one action per click and never from a timer, no stored names of other players, user data is never reset (additive migrations only), every text through `ns.L` with a German translation.

## License

MIT, see [LICENSE](LICENSE). Logo and banner in `tools/assets/brand/` are original works under the same license.

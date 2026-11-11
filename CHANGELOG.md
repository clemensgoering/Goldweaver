# Changelog

## Unreleased

First public version.

**Decisions**
- Tooltip line on every item with its best use and value: send to your crafter, disenchant, craft, sell on the auction house, sell to a vendor, put in a Waylaid Crate or keep for a skill-up. Hold Shift for the other options and the price source.
- Stock line in the tooltip: what your bank, your mailbox and your other characters hold.

**Guide window (`/gw`)**
- Guide: one step card with the most useful next action and one button, plus the team view of gatherer and crafter with a shared gathering list.
- Field: what to gather in the current zone for your skill, remembered herb and ore spots with a waypoint to the next one, best zones for your level.
- Professions: all twelve professions. Cheapest next skill-up with a shopping list across your characters, what is worth crafting after the auction house cut, recipes you have not learned yet, when and where to train the next rank.
- Team: roles per character (gatherer, crafter and bank, inactive), self-check and backup status.

**Helpers at game windows, one action per click**
- Mailbox: attach everything your crafter should get, then send. Sales are recorded from auction house invoices.
- Merchant: buy what the plan is missing, sell junk one item per click, repair.
- Bank: take the stacks the plan needs, store materials nobody needs right now.
- Auction house: prices of every search you look at are remembered; a suggested price with deposit, proceeds and break-even when you sell; a shopping list in three clicks per material (search, buy, confirm) that stops when the price jumped.
- Trainer: next rank and recipes with profit per craft.
- Profession window: profit tag on every recipe row.
- Disenchant queue (`/gw de`): items where disenchanting beats selling, one item per click.

**General**
- English and German, switchable in the settings.
- No required dependencies. Auctionator prices are used when it is installed; a RestedXP route is read when it is active.
- Your data is never reset: structure changes are additive migrations with an automatic backup (`/gw backup`, `/gw restore confirm`).
- Self-check and diagnosis (`/gw debug run`) with a report you can copy into an issue.

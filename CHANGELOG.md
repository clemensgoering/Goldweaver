# Changelog

## Unreleased

First public version.

**Decisions**
- Tooltip line on every item with its best use and value: send to your crafter, disenchant, craft, sell on the auction house, sell to a vendor, put in a Waylaid Crate or keep for a skill-up. Hold Shift for the other options and the price source.
- Stock line in the tooltip: what your bank, your mailbox and your other characters hold.

**Guide window (`/gw`)**
- Guide: one step card with the most useful next action and one button, plus the team view of gatherer and crafter with a shared gathering list.
- Field: what to gather in the current zone for your skill, remembered herb and ore spots with a waypoint to the next one, best zones for your level.
- Gold: budget, gold support, costs by level, level gates and ways to make gold (see above).
- Professions: all twelve professions. Cheapest next skill-up with a shopping list across your characters, what is worth crafting after the auction house cut, recipes you have not learned yet, when and where to train the next rank.
- Team: roles per character (gatherer, crafter and bank, inactive), self-check and backup status.

**Gold tab**
- Budget: what is due now and in the next ten levels (class skills, profession ranks, riding at 40, materials for the next skill-ups) against the gold of all your characters. Class skill costs are read from your own class trainer; until then a typical curve is used.
- Gold support in three strengths. When gold is short, selling wins over disenchanting, crafting and crates unless they earn clearly more, and the mailbox keeps sellable gear (light) or everything no plan needs (strong). When something is due now and the character cannot pay it, support is always strong. Can be switched off.
- Costs by level for every character, in bands of ten levels.
- Level gates: profession ranks that need a higher character level (crafting: Journeyman 10, Expert 20, Artisan 35; gathering: Expert 10, Artisan 25), shown early, with what to collect for that profession while levelling.
- Ways to make gold for your character, ranked by what they should earn: sell your bags, gather in the best zone for your skill, cloth from humanoids, profitable crafts of your team, profession tips. Estimates use your own prices and your own gathering pace.

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

-- Goldweaver: general ways to make gold that need no profession (Modules/Earn.lua). English keys, shown through ns.L.
-- Sources: GameLeap and Leprestore Forever guides (11/2026); facts only, no texts copied.
--   ns.Data.EarnTips = { { title, detail, minLevel?, maxLevel?, effort, icon? } }
local ADDON, ns = ...

ns.Data.EarnTips = {
  { title = "Loot and vendor everything", minLevel = 1, maxLevel = 20, effort = "low", icon = "Interface\\Icons\\INV_Misc_Coin_01",
    detail = "Grey items and early drops are most of the gold before level 20. Skip expensive bags and detours." },
  { title = "Sell low materials raw", minLevel = 1, maxLevel = 30, effort = "low", icon = "Interface\\Icons\\INV_Fabric_Linen_01",
    detail = "New crafters buy Linen Cloth, Copper Ore and Peacebloom; raw stacks often beat crafting them yourself." },
  { title = "Quests pay gold from level 48", minLevel = 45, effort = "medium", icon = "Interface\\Icons\\INV_Misc_Note_02",
    detail = "Most quests from level 48 reward gold on Forever. Turn them in as you go; there is no XP-to-gold at 60." },
  { title = "Craftsman's Writs", minLevel = 20, effort = "medium", icon = "Interface\\Icons\\INV_Scroll_03",
    detail = "Rare drops, tradeable: sell them on the AH or turn one in per day for reputation and a Coin Pouch." },
}

-- Goldweaver: ways to make gold, ranked for this character. Each way says what to do, where, what it needs, how much
-- effort it is and what it should earn. Estimates use the player's own prices and, for gathering, the own pace
-- (Field.GatherPace); without own data they use cautious defaults and say so.
--
-- Public API (ns.Earn)
--   RegisterSource(name, fn(ctx) -> { way }) ★   ctx = { me, level, market }
--   List(rec?) -> { way }   sorted: estimated ways by score, then tips (cached a few seconds)
--   way = { id, icon?, item?, title, detail, perHour?, perCraft?, total?, minutes?, effort = "low"|"medium"|"high",
--           own? (estimate from own data), action = { label, fn }?, score }
-- Profession-specific ways come from profile.earn (Professions/*.lua), general tips from ns.Data.EarnTips.
local ADDON, ns = ...
local L = ns.L

local Earn = { sources = {}, order = {} }
ns.Earn = Earn

local CACHE = 5
local CLOTH_PER_HOUR, SKINS_PER_HOUR = 20, 25 -- cautious defaults: drops while questing or farming at the right level
local CRAFT_SALES_PER_HOUR = 6                  -- how many crafted items of one kind the AH takes, roughly

function Earn.RegisterSource(name, fn)
  assert(type(name) == "string" and type(fn) == "function", "RegisterSource(name, fn)")
  if not Earn.sources[name] then Earn.order[#Earn.order + 1] = name end
  Earn.sources[name] = fn
end

local function price(itemID) return itemID and ns.Price.Copper(itemID) or nil end
-- zone name in the game's language (map API), the English data name only as a fallback
local function zoneName(id, fallback)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
  return info and info.name or L[fallback]
end
local function itemName(id) return ns.UI and ns.UI.ItemName and ns.UI.ItemName(id) or tostring(id) end
local function skillOf(rec, skillLine)
  local p = rec and rec.professions and rec.professions[skillLine]
  return p and not p.former and (p.rank or 0) or nil
end

-- 1. Sell what you carry ------------------------------------------------------------------------------------
-- Everything in the bags whose best use is selling and that no plan needs: the fastest gold there is.
function Earn.SellList()
  local list = {}
  local ctx = ns.Advisor.LiveContext({ cashFirst = true, needsMail = false })
  for _, it in ipairs(ns.Inventory.BagItems()) do
    local info = not it.isLocked and ns.API.ItemInfo(it.itemID)
    if info and not (ns.Demand and ns.Demand.For(it.itemID)) then
      local best = ns.Advisor.Best({ id = it.itemID, quantity = it.count, reqLevel = info.reqLevel, quality = info.quality,
        isWeapon = info.classID == 2, vendorSell = info.sellPrice, soulbound = it.isBound }, ctx)
      if best and (best.action == "auction" or best.action == "vendor") and best.value > 0 then
        list[#list + 1] = { item = it.itemID, count = it.count, action = best.action, value = best.value }
      end
    end
  end
  table.sort(list, function(a, b) return a.value > b.value end)
  return list
end

Earn.RegisterSource("sellNow", function()
  local list = Earn.SellList()
  if #list == 0 then return nil end
  local ah, ahValue, vendor, vendorValue = 0, 0, 0, 0
  for _, e in ipairs(list) do
    if e.action == "auction" then ah, ahValue = ah + 1, ahValue + e.value else vendor, vendorValue = vendor + 1, vendorValue + e.value end
  end
  local minutes = math.max(2, math.ceil(2 + ah * 0.5))
  return { {
    id = "sellNow", icon = "Interface\\Icons\\INV_Misc_Bag_10", title = (L["Sell your bags (%d)"]):format(#list),
    detail = (L["%d to the AH (%s), %d to a vendor (%s). Nothing a plan needs."]):format(ah, ns.Util.Money(ahValue), vendor, ns.Util.Money(vendorValue)),
    total = ahValue + vendorValue, minutes = minutes, effort = "low", own = true,
    action = { label = L["List"], fn = function()
      for i, e in ipairs(list) do
        if i > 12 then ns.Print((L["… and %d more"]):format(#list - 12)); break end
        ns.Print(("%s ×%d: %s %s"):format(itemName(e.item), e.count, e.action == "auction" and L["AH"] or L["Vendor"], ns.Util.Money(e.value)))
      end
    end },
  } }
end)

-- 2. Gather and sell ----------------------------------------------------------------------------------------
Earn.RegisterSource("gather", function(ctx)
  local G = ns.Data.Gathering
  local out = {}
  local nodesPerHour, perNode, own = ns.Field.GatherPace()
  local best = ns.Field.BestZones(ctx.me)
  for kind, skillLine in pairs(G.KIND_SKILL) do
    local skill = skillOf(ctx.me, skillLine)
    local zone = best[kind]
    if skill and zone then
      local z = ns.Data.Zones.list[zone.id]
      local sum, n, names = 0, 0, {}
      for _, itemID in ipairs(kind == "herb" and z.herbs or z.ores or {}) do
        local node = G.nodes[itemID]
        local p = price(itemID)
        if node and node.skill <= skill and p then sum, n = sum + p, n + 1; names[#names + 1] = itemName(itemID) end
      end
      if n > 0 then
        local perHour = math.floor(nodesPerHour * perNode * (sum / n) * (1 - (ns.db.settings.ahCut or 0.05)))
        out[#out + 1] = {
          id = "gather" .. kind, icon = kind == "herb" and "Interface\\Icons\\INV_Misc_Herb_07" or "Interface\\Icons\\INV_Ore_Copper_01",
          title = (L["%s in %s"]):format(L[kind == "herb" and "Herbalism" or "Mining"], zoneName(zone.id, z.name)),
          detail = (L["%s · sell on the AH · %s"]):format(table.concat(names, ", "), own and L["pace from your own farming"] or L["pace estimated"]),
          perHour = perHour, effort = "medium", own = own,
          action = { label = L["Map"], fn = function() if OpenWorldMap then pcall(OpenWorldMap, zone.id) end end },
        }
      end
    end
  end
  local skin = skillOf(ctx.me, G.SKINNING)
  if skin and best.skin then
    local z = ns.Data.Zones.list[best.skin.id]
    local leather = z and G.LeatherFor(math.floor((z.min + z.max) / 2))
    local p = price(leather)
    if p then
      out[#out + 1] = { id = "skin", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        title = (L["%s in %s"]):format(L["Skinning"], zoneName(best.skin.id, z.name)),
        detail = (L["%s from beasts you kill anyway · pace estimated"]):format(itemName(leather)),
        perHour = math.floor(SKINS_PER_HOUR * p * (1 - (ns.db.settings.ahCut or 0.05))), effort = "medium",
        action = { label = L["Map"], fn = function() if OpenWorldMap then pcall(OpenWorldMap, best.skin.id) end end } }
    end
  end
  return out
end)

-- 3. Cloth from humanoids (any character) -------------------------------------------------------------------
Earn.RegisterSource("cloth", function(ctx)
  local cloth = ns.Data.Gathering.ClothFor(ctx.level)
  local p = price(cloth)
  if not p then return nil end
  return { { id = "cloth", item = cloth, title = (L["%s from humanoids"]):format(itemName(cloth)),
    detail = (L["Humanoids around level %d drop it; sell it or keep it for the tailor · pace estimated"]):format(ctx.level),
    perHour = math.floor(CLOTH_PER_HOUR * p * (1 - (ns.db.settings.ahCut or 0.05))), effort = "medium" } }
end)

-- 4. Profitable crafts of the whole team --------------------------------------------------------------------
Earn.RegisterSource("crafts", function(ctx)
  local out = {}
  for _, rec in ipairs(ns.Chars.All(ctx.market)) do
    for skillLine, p in pairs(rec.professions or {}) do
      if not p.former and ns.Adapter.Book(skillLine) then
        for _, e in ipairs(ns.Planner.Profitable(skillLine, rec, 2)) do
          if e.margin > 0 and e.coverage >= 1 then
            local mine = rec == ctx.me
            out[#out + 1] = {
              id = "craft" .. e.recipe.id, icon = e.recipe.icon, item = e.recipe.outputItemID,
              title = (L["Craft and sell: %s"]):format(e.recipe.name),
              detail = (L["%s on %s · materials %s · sells for %s"]):format(p.name or "?", rec.name, ns.Util.Money(e.cost), ns.Util.Money(math.floor(e.value))),
              perCraft = e.margin, perHour = e.margin * CRAFT_SALES_PER_HOUR, effort = "low", own = true,
              action = mine and { label = L["Open recipe"], fn = function() ns.Adapter.Open(skillLine, e.recipe.id) end } or nil,
            }
          end
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.perCraft > b.perCraft end)
  while #out > 3 do table.remove(out) end
  return out
end)

-- 5. Tips: profession ways of the team (profile.earn) and general tips (ns.Data.EarnTips) ----------------------
Earn.RegisterSource("tips", function(ctx)
  local out, seen = {}, {}
  local function add(tip, key, who)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = { id = key, icon = tip.icon or "Interface\\Icons\\INV_Misc_Note_01", title = L[tip.title],
      detail = who and (("%s · %s"):format(L[tip.detail], who)) or L[tip.detail], effort = tip.effort or "medium" }
  end
  for _, rec in ipairs(ns.Chars.All(ctx.market)) do
    for skillLine, p in pairs(rec.professions or {}) do
      local profile = not p.former and ns.Professions:BySkillLine(skillLine)
      for i, tip in ipairs(profile and profile.earn or {}) do
        if (p.rank or 0) >= (tip.minSkill or 0) and (rec.level or 1) >= (tip.minLevel or 0) then
          add(tip, profile.key .. i, rec.name)
        end
      end
    end
  end
  for i, tip in ipairs(ns.Data.EarnTips or {}) do
    if ctx.level >= (tip.minLevel or 0) and ctx.level <= (tip.maxLevel or 60) then add(tip, "tip" .. i) end
  end
  return out
end)

-- Ranking ------------------------------------------------------------------------------------------------------
local cache, cacheAt, cacheFor = nil, 0, nil

function Earn.List(rec)
  rec = rec or ns.Chars.Current()
  if not rec then return {} end
  local now = GetTime and GetTime() or 0
  if cache and cacheFor == rec and now - cacheAt < CACHE then return cache end
  local ctx = { me = rec, level = rec.level or 1, market = ns.Chars.MarketKey() }
  local out = {}
  for _, name in ipairs(Earn.order) do
    local ok, list = pcall(Earn.sources[name], ctx)
    if not ok then ns.Health.Record("earn " .. name, list)
    else
      for _, w in ipairs(list or {}) do
        -- gold per hour decides; a one-off amount counts per its minutes; tips without numbers come last
        w.score = w.perHour or (w.total and w.minutes and w.total / w.minutes * 60) or -1
        out[#out + 1] = w
      end
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return (a.title or "") < (b.title or "")
  end)
  cache, cacheAt, cacheFor = out, now, rec
  return out
end

function Earn.Invalidate() cache = nil end

-- "≈ 2g/h", "+35s each", "≈ 4g · 10 min" or the effort for tips.
function Earn.ValueText(w)
  if w.perCraft then return (L["+%s each"]):format(ns.Util.Money(w.perCraft)) end
  if w.perHour then return (L["≈ %s/h"]):format(ns.Util.Money(w.perHour)) end
  if w.total then return (L["≈ %s · %d min"]):format(ns.Util.Money(w.total), w.minutes or 0) end
  return L[({ low = "little effort", medium = "some effort", high = "much effort" })[w.effort or "medium"]]
end

ns:RegisterModule("Earn", {
  Init = function()
    ns.Events:On("BAG_UPDATE_DELAYED", Earn.Invalidate, "Earn")
  end,
  SelfTest = function()
    local list = Earn.List()
    return { { name = L["Ways to make gold"], ok = true, detail = #list > 0 and (("%d · %s"):format(#list, list[1].title)) or L["none yet"] } }
  end,
})

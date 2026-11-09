-- Goldweaver: "Unterwegs" - what is worth gathering or killing here, for this character's level and skills.
-- Sources, best first: own gathering observations in this zone (GoldweaverDB.learned.zoneGathers), the static zone
-- table (Data/Zones.lua, Classic data), the gathering facts (Data/Gathering.lua), the team's demand (Modules/Demand.lua),
-- prices (Core/Price.lua) and, when RestedXP is installed, the zones the current guide visits next.
--
-- Public API (ns.Field)
--   CurrentZone() -> zoneID, rawMapID, name                       resolves subzones/cities to the table's zone
--   Analyze(zoneID?, rec?) -> report (see below)
--   Route() -> { guide, zones = { {id, name} } } | nil              RestedXP look-ahead (read only)
--   BestZones(rec?) -> { [kind] = { id, name, count } }            where to level each gathering skill
--   SetWaypoint(mapID, x, y, label) -> ok                          map pin + super track
-- report = { id, name, zone, level, fit, gather = { rows }, mobs = { cloth, leather, skin }, route, best }
-- row    = { item, kind, required, color, chance, price, demand, observed, profession }
local ADDON, ns = ...

local Field = {}
ns.Field = Field

local G -- ns.Data.Gathering, set lazily (Data loads before Modules)

local GATHER_SPELLS = {
  [2366] = "herb", [2368] = "herb", [3570] = "herb", [11993] = "herb",
  [2575] = "ore", [2576] = "ore", [3564] = "ore", [10248] = "ore",
  [8613] = "skin", [8617] = "skin", [8618] = "skin", [10768] = "skin",
  [7620] = "fish", [7731] = "fish", [7732] = "fish", [18248] = "fish",
}

local function zones() return ns.Data.Zones.list end

function Field.CurrentZone()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local raw = C_Map.GetBestMapForUnit("player")
  if not raw or ns.Secret.IsSecret(raw) then return nil end
  local id, guard = raw, 0
  while id and not zones()[id] and guard < 6 do
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    id = info and info.parentMapID or nil
    guard = guard + 1
  end
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id or raw)
  local name = info and info.name or (id and zones()[id] and zones()[id].name) or "?"
  return id, raw, name
end

local function skillOf(rec, skillLine)
  local p = rec and rec.professions and rec.professions[skillLine]
  if not p or p.former then return nil end
  return p.rank or 0
end

-- RestedXP: read the current guide and the zones of the next steps. Optional and read-only.
function Field.Route(lookahead)
  local rxp = _G.RXP
  local data = _G.RXPCData
  if type(rxp) ~= "table" or type(data) ~= "table" then return nil end
  local ok, route = pcall(function()
    local guide = rxp.currentGuide
    if type(guide) ~= "table" or type(guide.steps) ~= "table" then return nil end
    local start = tonumber(data.currentStep) or 1
    local out, seen = {}, {}
    for s = start, math.min(#guide.steps, start + (lookahead or 40)) do
      local step = guide.steps[s]
      for _, el in ipairs(type(step) == "table" and step.elements or {}) do
        local z = type(el) == "table" and tonumber(el.zone)
        if z and not seen[z] then
          seen[z] = true
          local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(z)
          out[#out + 1] = { id = z, name = info and info.name or tostring(z), step = s }
        end
      end
    end
    return { guide = guide.displayname or guide.name or "?", step = start, zones = out }
  end)
  if ok then return route end
  ns.Health.Record("Field.Route (RestedXP)", route)
  return nil
end

-- Record what a gathering spell yielded in this zone (called on LOOT_OPENED after a gather cast).
function Field.RecordGather(kind, items, zoneID)
  if not zoneID then return end
  ns.db.learned.zoneGathers = ns.db.learned.zoneGathers or {}
  local z = ns.db.learned.zoneGathers[zoneID] or {}
  for _, it in ipairs(items) do
    local key = it.item
    local e = z[key] or { kind = kind, count = 0 }
    e.count = e.count + (it.qty or 1)
    e.last = time()
    z[key] = e
  end
  ns.db.learned.zoneGathers[zoneID] = z
  if ns.Checks then ns.Checks.Pass("fieldObserve", ("%s: %d Item(s) in Zone %s"):format(kind, #items, tostring(zoneID))) end
end

local function rowFor(itemID, kind, rec, observed)
  local node = G.nodes[itemID]
  local skillLine = node and G.KIND_SKILL[node.kind] or (kind == "skin" and G.SKINNING) or (kind == "fish" and G.FISHING) or nil
  local skill = skillLine and skillOf(rec, skillLine)
  local required = node and node.skill or nil
  local color = (skill and required) and G.ColorFor(skill, required) or nil
  local demand = ns.Demand and ns.Demand.For(itemID)
  return {
    item = itemID, kind = node and node.kind or kind, required = required, color = color,
    chance = color and G.ChanceFor(color) or 0, price = ns.Price.Copper(itemID), demand = demand,
    observed = observed, profession = skillLine, hasProfession = skill ~= nil,
  }
end

local COLOR_RANK = { orange = 1, yellow = 2, green = 3, grey = 4, red = 5 }

-- Order: items the team needs first, then what still gives skill-ups, then value.
local function sortRows(rows)
  table.sort(rows, function(a, b)
    local ad, bd = a.demand and 1 or 0, b.demand and 1 or 0
    if ad ~= bd then return ad > bd end
    local ah, bh = a.hasProfession and 1 or 0, b.hasProfession and 1 or 0
    if ah ~= bh then return ah > bh end
    local ac, bc = COLOR_RANK[a.color or "red"] or 6, COLOR_RANK[b.color or "red"] or 6
    if ac ~= bc then return ac < bc end
    return (a.price or 0) > (b.price or 0)
  end)
end

function Field.Analyze(zoneID, rec)
  G = G or ns.Data.Gathering
  rec = rec or ns.Chars.Current()
  local name
  if not zoneID then
    local current, _, currentName = Field.CurrentZone()
    zoneID, name = current, currentName
  end
  local z = zoneID and zones()[zoneID]
  local level = (rec and rec.level) or (UnitLevel and UnitLevel("player")) or 1
  local report = { id = zoneID, name = name or (z and z.name) or "?", zone = z, level = level, gather = {} }

  if z and not z.city then
    if level < z.min - 2 then report.fit = "high" elseif level > z.max + 3 then report.fit = "low" else report.fit = "ok" end
  end

  -- gatherable items: static lists plus own observations, without duplicates
  local seen = {}
  local observed = ns.db.learned.zoneGathers and zoneID and ns.db.learned.zoneGathers[zoneID] or {}
  for itemID, e in pairs(observed) do
    if e.kind == "herb" or e.kind == "ore" or e.kind == "fish" then
      seen[itemID] = true
      report.gather[#report.gather + 1] = rowFor(itemID, e.kind, rec, e.count)
    end
  end
  if z then
    for _, list in ipairs({ z.herbs or {}, z.ores or {} }) do
      for _, itemID in ipairs(list) do
        if not seen[itemID] then
          seen[itemID] = true
          report.gather[#report.gather + 1] = rowFor(itemID, nil, rec, nil)
        end
      end
    end
  end
  sortRows(report.gather)

  -- mobs: cloth from humanoids and leather from beasts at the zone's level range
  if z and not z.city then
    local mid = math.floor((z.min + z.max) / 2)
    local cloth = G.ClothFor(math.max(z.min, math.min(level, z.max)))
    local leather = G.LeatherFor(mid)
    local skin = skillOf(rec, G.SKINNING)
    report.mobs = {
      cloth = cloth, clothDemand = cloth and ns.Demand and ns.Demand.For(cloth), clothPrice = cloth and ns.Price.Copper(cloth),
      leather = leather, leatherPrice = leather and ns.Price.Copper(leather),
      skinMax = skin and G.SkinningMaxLevel(skin) or nil, skinRequiredTop = G.SkinningRequired(z.max),
      min = z.min, max = z.max,
    }
  end

  report.route = Field.Route()
  report.best = Field.BestZones(rec)
  return report
end

-- Where each gathering skill levels best within the character's level band (±6).
function Field.BestZones(rec)
  G = G or ns.Data.Gathering
  rec = rec or ns.Chars.Current()
  local level = (rec and rec.level) or 1
  local out = {}
  for kind, skillLine in pairs(G.KIND_SKILL) do
    local skill = skillOf(rec, skillLine)
    if skill then
      local best
      for _, entry in ipairs(ns.Data.Zones.ForLevel(level)) do
        if entry.distance <= 6 then
          local count = 0
          local list = kind == "herb" and entry.zone.herbs or entry.zone.ores
          for _, itemID in ipairs(list or {}) do
            local node = G.nodes[itemID]
            local color = node and G.ColorFor(skill, node.skill)
            if color == "orange" or color == "yellow" then count = count + 1 end
          end
          if count > 0 and (not best or count > best.count) then best = { id = entry.id, name = entry.zone.name, count = count } end
        end
      end
      out[kind] = best
    end
  end
  local skin = skillOf(rec, G.SKINNING)
  if skin then
    local maxLevel = G.SkinningMaxLevel(skin)
    local best
    for _, entry in ipairs(ns.Data.Zones.ForLevel(math.min(level, maxLevel))) do
      if entry.zone.max <= maxLevel + 2 and entry.zone.max >= maxLevel - 8 then best = { id = entry.id, name = entry.zone.name, count = 1 }; break end
    end
    out.skin = best
  end
  return out
end

function Field.SetWaypoint(mapID, x, y, label)
  if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok and label then ns.Print("Wegpunkt gesetzt: " .. label) end
  return ok
end

-- Gather observation: remember the last gathering cast, then read the loot window.
local lastGather
ns:RegisterModule("Field", {
  Init = function()
    G = ns.Data.Gathering
    ns.Events:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
      if unit == "player" and GATHER_SPELLS[spellID] then lastGather = { kind = GATHER_SPELLS[spellID], t = GetTime() } end
    end, "Field")
    ns.Events:On("LOOT_OPENED", function()
      if not lastGather or GetTime() - lastGather.t > 4 then return end
      if not (GetNumLootItems and GetLootSlotLink) then return end
      local items = {}
      for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        local id = link and tonumber(link:match("item:(%d+)"))
        local _, _, qty = GetLootSlotInfo(i)
        if id and not ns.Secret.Any(id, qty) then items[#items + 1] = { item = id, qty = qty or 1 } end
      end
      local zoneID = Field.CurrentZone()
      Field.RecordGather(lastGather.kind, items, zoneID)
      lastGather = nil
    end, "Field")
  end,
  SelfTest = function()
    local id, raw, name = Field.CurrentZone()
    local route = Field.Route()
    local rows = {
      { name = "Zone erkannt", ok = id ~= nil, warn = true, detail = ("%s (Karte %s, Tabelle %s)"):format(tostring(name), tostring(raw), tostring(id)) },
      { name = "RestedXP-Route", ok = true, detail = route and ("%s, Schritt %d, %d Zonen voraus"):format(route.guide, route.step, #route.zones) or "RestedXP nicht aktiv" },
    }
    local learnedZones = 0
    for _ in pairs(ns.db.learned.zoneGathers or {}) do learnedZones = learnedZones + 1 end
    rows[#rows + 1] = { name = "Eigene Sammeldaten", ok = true, detail = learnedZones .. " Zone(n)" }
    if ns.Checks and id then ns.Checks.Pass("fieldZone", tostring(name)) end
    return rows
  end,
})

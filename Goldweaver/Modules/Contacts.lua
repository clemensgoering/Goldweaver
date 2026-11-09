-- Goldweaver: trade contacts recorder. Remembers profession trainers and merchants this account has visited
-- (name, zone, map position, what they sold at which price). Own observations only; no shipped NPC database.
-- GoldweaverDB.contacts[npcName] = { kind = "trainer"|"merchant", zone, mapID, x, y, when, items = {[itemID] = buyPrice} }
local ADDON, ns = ...

local Contacts = {}
ns.Contacts = Contacts

local function position()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local zone = info and info.name or nil
  if pos then return mapID, zone, math.floor(pos.x * 1000 + 0.5) / 10, math.floor(pos.y * 1000 + 0.5) / 10 end
  return mapID, zone
end

local function npcName()
  local name = UnitName and UnitName("npc")
  if not name or ns.Secret.IsSecret(name) then return nil end
  return name
end

local function record(kind)
  local name = npcName()
  if not name then return nil end
  ns.db.contacts = ns.db.contacts or {}
  local c = ns.db.contacts[name] or { items = {} }
  c.kind = kind
  c.mapID, c.zone, c.x, c.y = position()
  c.when = time()
  c.faction = UnitFactionGroup and select(1, UnitFactionGroup("player")) or nil
  ns.db.contacts[name] = c
  return c
end

-- Merchant item: Forever/Mainline use C_MerchantFrame.GetItemInfo(index) -> table; older clients the global.
local function merchantItem(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
    if ok and type(info) == "table" then return info.price, info.numAvailable, info.spellID end
    return nil
  end
  if GetMerchantItemInfo then
    local _, _, price, _, numAvailable = GetMerchantItemInfo(i)
    return price, numAvailable, nil
  end
  return nil
end

local function recordMerchant()
  local name = npcName()
  local c = name and record("merchant")
  if not (c and GetMerchantNumItems) then return end
  local n = GetMerchantNumItems() or 0
  ns.db.vendors = ns.db.vendors or {}
  for i = 1, n do
    local link = GetMerchantItemLink and GetMerchantItemLink(i)
    local id = link and tonumber(link:match("item:(%d+)"))
    local price, numAvailable = merchantItem(i)
    if id and price and not ns.Secret.Any(id, price, numAvailable) then
      c.items[id] = price
      -- vendor price registry used as a ceiling by the price engine; limited stock items (recipes) are flagged
      local v = ns.db.vendors[id] or {}
      if not v.buy or price < v.buy then v.buy = price; v.npc = name end
      v.limited = (numAvailable or -1) >= 0
      v.when = time()
      -- recipe scrolls teach a spell whose ID is the recipe ID: that links the vendor to "Noch nicht gelernt"
      if C_Item and C_Item.GetItemSpell then
        local okSpell, _, spellID = pcall(C_Item.GetItemSpell, id)
        if okSpell and type(spellID) == "number" then v.teaches = spellID end
      end
      ns.db.vendors[id] = v
    end
  end
  if ns.Checks then ns.Checks.Pass("contacts", ("Händler %s, %d Waren"):format(name, n)) end
end

local function recordTrainer()
  local name = npcName()
  local c = name and record("trainer")
  if not c then return end
  if ns.Checks then ns.Checks.Pass("contacts", "Lehrer " .. name) end
  if ns.Learn then C_Timer.After(0.3, function() pcall(ns.Learn.TrainerServices, name) end) end
end

local function recordMerchantSafe()
  local ok, err = pcall(recordMerchant)
  if not ok then ns.Log("merchant record failed", err) end
end

-- Where to buy an item according to our own visits: { npc, zone, buy } or nil.
function Contacts.VendorFor(itemID)
  local v = ns.db.vendors and ns.db.vendors[itemID]
  if not v then return nil end
  local c = v.npc and ns.db.contacts and ns.db.contacts[v.npc]
  return { npc = v.npc, zone = c and c.zone, buy = v.buy, limited = v.limited }
end

-- Trainers we met, optionally filtered by zone text.
function Contacts.Trainers()
  local list = {}
  for name, c in pairs(ns.db.contacts or {}) do
    if c.kind == "trainer" then list[#list + 1] = { name = name, zone = c.zone, x = c.x, y = c.y, when = c.when } end
  end
  table.sort(list, function(a, b) return (a.when or 0) > (b.when or 0) end)
  return list
end

ns:RegisterModule("Contacts", {
  SelfTest = function()
    local trainers, merchants, vendors = 0, 0, 0
    for _, c in pairs(ns.db.contacts or {}) do if c.kind == "trainer" then trainers = trainers + 1 else merchants = merchants + 1 end end
    for _ in pairs(ns.db.vendors or {}) do vendors = vendors + 1 end
    local mapID, zone = position()
    return {
      { name = "Position lesbar", ok = mapID ~= nil, detail = tostring(zone) .. " (" .. tostring(mapID) .. ")" },
      { name = "Kontakte", ok = true, detail = ("%d Lehrer, %d Händler, %d Händlerpreise"):format(trainers, merchants, vendors) },
    }
  end,
  Init = function()
    ns.Events:On("TRAINER_SHOW", function() pcall(recordTrainer) end, "Contacts")
    ns.Events:On("TRAINER_UPDATE", function() local n = npcName() if n and ns.Learn then pcall(ns.Learn.TrainerServices, n) end end, "Contacts")
    ns.Events:On("MERCHANT_SHOW", function() C_Timer.After(0.3, recordMerchantSafe) end, "Contacts")
  end,
})

ns.Slash.Register("contacts", function()
  local n = 0
  for name, c in pairs(ns.db.contacts or {}) do
    n = n + 1
    if n <= 15 then ns.Print(("%s (%s) %s %s"):format(name, c.kind or "?", c.zone or "?", c.x and (c.x .. ", " .. c.y) or "")) end
  end
  ns.Print(n .. " Kontakte gespeichert (Lehrer und Händler, die du besucht hast)")
end, "list visited trainers and merchants")

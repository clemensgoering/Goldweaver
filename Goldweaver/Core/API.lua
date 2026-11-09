-- Goldweaver: compatibility layer. Every game API the addon depends on is reached through ns.API, which
--   1. checks that the function exists (capability probe, never a version check),
--   2. normalises return values into plain tables so a changed signature breaks exactly one place,
--   3. never raises: a missing or failing API yields nil and is counted in ns.API.failures.
-- Features (ns.Features) group the APIs a module needs; a module whose feature is unavailable stays dormant and
-- says so in /gw debug, instead of throwing errors all session long. See docs/10-KOMPATIBILITAET.md.
local ADDON, ns = ...

local API = { failures = {} }
ns.API = API

-- Resolves "C_Item.GetItemInfo" to the function or nil.
function API.Resolve(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
    if cur == nil then return nil end
  end
  return cur
end

function API.Has(path) return API.Resolve(path) ~= nil end

-- Calls a path safely. Returns ok, results...
function API.Call(path, ...)
  local fn = API.Resolve(path)
  if type(fn) ~= "function" then
    API.failures[path] = (API.failures[path] or 0) + 1
    return false, "missing"
  end
  local results = { pcall(fn, ...) }
  if not results[1] then
    API.failures[path] = (API.failures[path] or 0) + 1
    ns.Log("API error", path, results[2])
    return false, results[2]
  end
  return unpack(results)
end

-- Items ----------------------------------------------------------------------------------------
-- Returns a table or nil (nil also while the item is not cached yet; call ns.API.RequestItem to load it).
function API.ItemInfo(itemID)
  local ok, name, link, quality, itemLevel, reqLevel, itemType, itemSubType, stackCount, equipLoc, icon, sellPrice, classID, subclassID, bindType = API.Call("C_Item.GetItemInfo", itemID)
  if not ok or not name then return nil end
  if ns.Secret.Any(name, quality, reqLevel, sellPrice, classID, subclassID, bindType) then return nil end
  return {
    id = itemID, name = name, link = link, quality = quality, itemLevel = itemLevel, reqLevel = reqLevel or 1,
    itemType = itemType, itemSubType = itemSubType, stackCount = stackCount, equipLoc = equipLoc, icon = icon,
    sellPrice = sellPrice or 0, classID = classID, subclassID = subclassID, bindType = bindType,
  }
end

-- Always available data (no server round trip): classID, subclassID, equipLoc, icon.
function API.ItemInfoInstant(itemID)
  local ok, id, itemType, itemSubType, equipLoc, icon, classID, subclassID = API.Call("C_Item.GetItemInfoInstant", itemID)
  if not ok or not id then return nil end
  if ns.Secret.Any(classID, subclassID) then return nil end
  return { id = id, itemType = itemType, itemSubType = itemSubType, equipLoc = equipLoc, icon = icon, classID = classID, subclassID = subclassID }
end

function API.RequestItem(itemID) API.Call("C_Item.RequestLoadItemDataByID", itemID) end
function API.ItemName(itemID) local ok, n = API.Call("C_Item.GetItemNameByID", itemID) return ok and not ns.Secret.IsSecret(n) and n or nil end
function API.ItemIcon(itemID) local ok, i = API.Call("C_Item.GetItemIconByID", itemID) return ok and i or nil end
function API.ItemCount(itemID, includeBank) local ok, n = API.Call("C_Item.GetItemCount", itemID, includeBank and true or false) return ok and tonumber(n) or 0 end

-- Containers -----------------------------------------------------------------------------------
function API.NumSlots(bag) local ok, n = API.Call("C_Container.GetContainerNumSlots", bag) return ok and tonumber(n) or 0 end
function API.FreeSlots(bag) local ok, n = API.Call("C_Container.GetContainerNumFreeSlots", bag) return ok and tonumber(n) or 0 end

-- Normalised container item: { itemID, count, quality, isBound, isLocked, link } or nil for an empty slot.
function API.ContainerItem(bag, slot)
  local ok, info = API.Call("C_Container.GetContainerItemInfo", bag, slot)
  if not ok or type(info) ~= "table" or not info.itemID then return nil end
  if ns.Secret.Any(info.itemID, info.stackCount, info.quality, info.isBound, info.isLocked) then return nil end
  return { itemID = info.itemID, count = info.stackCount or 1, quality = info.quality, isBound = info.isBound and true or false, isLocked = info.isLocked and true or false, link = info.hyperlink }
end

function API.UseContainerItem(bag, slot) return (API.Call("C_Container.UseContainerItem", bag, slot)) end

-- Features -------------------------------------------------------------------------------------
local Features = { defs = {}, order = {} }
ns.Features = Features

-- Features.Define("tooltip", { label = "Tooltip-Zeilen", requires = { "TooltipDataProcessor.AddTooltipPostCall" } })
function Features.Define(name, def)
  def.name = name
  def.requires = def.requires or {}
  Features.defs[name] = def
  Features.order[#Features.order + 1] = name
end

-- Missing API paths for a feature (empty when all present). A requirement may be a list of alternatives
-- ({ "C_MerchantFrame.GetItemInfo", "GetMerchantItemInfo" }): one of them is enough.
function Features.Missing(name)
  local def = Features.defs[name]
  local missing = {}
  if not def then return missing end
  for _, req in ipairs(def.requires) do
    if type(req) == "table" then
      local any = false
      for _, alt in ipairs(req) do if API.Has(alt) then any = true break end end
      if not any then missing[#missing + 1] = table.concat(req, "|") end
    elseif not API.Has(req) then
      missing[#missing + 1] = req
    end
  end
  return missing
end

function Features.Disabled(name)
  local d = ns.db and ns.db.settings and ns.db.settings.disabledFeatures
  return d and d[name] and true or false
end

-- Available = all required APIs exist and the user has not switched it off.
function Features.Available(name)
  if Features.Disabled(name) then return false, "abgeschaltet" end
  local missing = Features.Missing(name)
  if #missing > 0 then return false, "fehlt: " .. table.concat(missing, ", ") end
  return true
end

function Features.SetEnabled(name, enabled)
  ns.db.settings.disabledFeatures = ns.db.settings.disabledFeatures or {}
  ns.db.settings.disabledFeatures[name] = (not enabled) and true or nil
end

-- Status rows for the debug report: { name, label, ok, detail }
function Features.Status()
  local rows = {}
  for _, name in ipairs(Features.order) do
    local def = Features.defs[name]
    local ok, why = Features.Available(name)
    rows[#rows + 1] = { name = name, label = def.label or name, ok = ok, detail = ok and "ok" or why }
  end
  return rows
end

Features.Define("items", { label = "Item-Daten", requires = { "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.GetItemCount" } })
Features.Define("bags", { label = "Taschen lesen", requires = { "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo" } })
Features.Define("tooltip", { label = "Tooltip-Zeilen", requires = { "TooltipDataProcessor.AddTooltipPostCall", "C_Item.GetItemInfo" } })
Features.Define("mail", { label = "Post-Pipeline", requires = { "SendMail", "C_Container.UseContainerItem", "GetInboxNumItems", "GetInboxHeaderInfo", "AutoLootMailItem" } })
Features.Define("ledger", { label = "Verkaufs-Ledger", requires = { "GetInboxInvoiceInfo" } })
Features.Define("professions", { label = "Berufe lesen", requires = { "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetRecipeSchematic", "C_TradeSkillUI.GetBaseProfessionInfo" } })
Features.Define("craft", { label = "Herstellen-Knopf", requires = { "C_TradeSkillUI.CraftRecipe", "C_TradeSkillUI.IsTradeSkillReady" } })
Features.Define("disenchant", { label = "Entzauber-Queue", requires = { "C_Spell.GetSpellName", "CreateFrame" } })
Features.Define("auction", { label = "AH-Preise mitlesen", requires = { "C_AuctionHouse.GetNumCommoditySearchResults", "C_AuctionHouse.GetCommoditySearchResultInfo", "C_AuctionHouse.GetBrowseResults" } })
Features.Define("auctionSell", { label = "AH-Verkaufsvorschlag", requires = { "C_AuctionHouse.CalculateCommodityDeposit" } })
Features.Define("contacts", { label = "Lehrer/Händler merken", requires = { "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "GetMerchantNumItems", { "C_MerchantFrame.GetItemInfo", "GetMerchantItemInfo" } } })
Features.Define("openProfession", { label = "Beruf per Knopf öffnen", requires = { "C_TradeSkillUI.OpenTradeSkill" } })
Features.Define("minimap", { label = "Minimap-Button", requires = { "Minimap" } })

ns.Slash.Register("feature", function(arg)
  local name, state = arg:match("^(%S+)%s*(%S*)$")
  if not name or not Features.defs[name] then
    for _, row in ipairs(Features.Status()) do ns.Print(("%s: %s"):format(row.name, row.detail)) end
    return ns.Print("usage: /gw feature <name> on|off")
  end
  if state == "on" or state == "off" then
    Features.SetEnabled(name, state == "on")
    ns.Print(("Feature %s %s (wirkt nach /reload)"):format(name, state == "on" and "an" or "aus"))
  else
    local ok, why = Features.Available(name)
    ns.Print(("%s: %s"):format(name, ok and "ok" or why))
  end
end, "list features or switch one on|off")

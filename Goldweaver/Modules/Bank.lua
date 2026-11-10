-- Goldweaver: bank helper (B16). Two tabs under the bank frame, each click moves one stack:
--   "Take 20 × Linen Cloth"   a stack the plan needs in the bags: the crafter's own plan, or as main what the twink
--                              needs (taken out to go with the next mail)
--   "Store 20 × Copper Ore"   trade goods in the bags that no plan needs and that do not travel by mail
--
-- Public API (ns.Bank)
--   Wanted(itemID) -> count   how many of an item the plans want in this character's bags
--   TakeList(), StoreList()   -> { { bag, slot, item, count } }
local ADDON, ns = ...
local L = ns.L

local Bank = {}
ns.Bank = Bank

local TRADE_GOODS = 7
local tabs

local function wantedMap()
  local want = {}
  local me = ns.Chars.Current()
  local view = ns.Coop.Needs()
  if view and me == view.gatherer then
    -- what still has to reach the crafter
    for _, r in ipairs(view.rows) do
      local toSend = r.need - r.crafter - r.mail
      if toSend > 0 and r.source ~= "vendor" then want[r.item] = toSend end
    end
  elseif view and me == view.crafter then
    for _, r in ipairs(view.rows) do want[r.item] = r.need end
  else
    for _, row in ipairs(ns.Coop.Shopping()) do want[row.item] = row.need end
  end
  return want
end

function Bank.Wanted(itemID) return wantedMap()[itemID] or 0 end

function Bank.TakeList()
  local out = {}
  local want = wantedMap()
  local inBags = {}
  for _, it in ipairs(ns.Inventory.BagItems()) do inBags[it.itemID] = (inBags[it.itemID] or 0) + it.count end
  for _, it in ipairs(ns.Inventory.BankItems()) do
    local w = want[it.itemID]
    if w and (inBags[it.itemID] or 0) < w and not it.isLocked then
      out[#out + 1] = { bag = it.bag, slot = it.slot, item = it.itemID, count = it.count }
      inBags[it.itemID] = (inBags[it.itemID] or 0) + it.count -- one stack per item and click is enough to plan
    end
  end
  return out
end

function Bank.StoreList()
  local out = {}
  local want = wantedMap()
  for _, it in ipairs(ns.Inventory.BagItems()) do
    if not it.isLocked and not it.isBound and not want[it.itemID] then
      local info = ns.API.ItemInfoInstant(it.itemID)
      local travels = ns.Mail.TargetFor and ns.Mail.TargetFor({ itemID = it.itemID, quality = it.quality, isBound = it.isBound })
      if info and info.classID == TRADE_GOODS and not travels then
        out[#out + 1] = { bag = it.bag, slot = it.slot, item = it.itemID, count = it.count }
      end
    end
  end
  return out
end

local function refresh()
  if not (tabs and BankFrame and BankFrame:IsShown()) then return end
  local take = Bank.TakeList()
  if #take > 0 then
    local t = take[1]
    tabs[2]:Set((L["Take %d × %s"]):format(t.count, ns.UI.ItemName(t.item)),
      (L["Moves one stack the plan needs into your bags. %d stack(s) waiting."]):format(#take),
      function() ns.API.UseContainerItem(t.bag, t.slot); if ns.Checks then ns.Checks.Pass("bankHelp", "take") end end)
  else
    tabs[2]:Clear()
  end
  local store = Bank.StoreList()
  if #store > 0 then
    local s = store[1]
    tabs[1]:Set((L["Store %d × %s"]):format(s.count, ns.UI.ItemName(s.item)),
      (L["Moves one stack of materials nobody needs right now into the bank. %d stack(s) in the bags."]):format(#store),
      function() ns.API.UseContainerItem(s.bag, s.slot); if ns.Checks then ns.Checks.Pass("bankHelp", "store") end end)
  else
    tabs[1]:Clear()
  end
end
Bank.Refresh = refresh

ns:RegisterModule("Bank", {
  Init = function()
    ns.Events:On("BANKFRAME_OPENED", function()
      if not tabs and BankFrame then tabs = ns.UI.FrameTabs(BankFrame, 2) end
      C_Timer.After(0.6, function() pcall(refresh) end)
    end, "Bank")
    ns.Events:On("BAG_UPDATE_DELAYED", function() if BankFrame and BankFrame:IsShown() then C_Timer.After(0.3, function() pcall(refresh) end) end end, "Bank")
    ns.Events:On("PLAYERBANKSLOTS_CHANGED", function() if BankFrame and BankFrame:IsShown() then C_Timer.After(0.3, function() pcall(refresh) end) end end, "Bank")
  end,
  SelfTest = function()
    return { { name = L["Bank tabs"], ok = true, warn = tabs == nil, detail = tabs and L["built"] or L["only after the first bank visit"] } }
  end,
})

-- Goldweaver: merchant helper (B15). Three tabs under the merchant frame, each click one action:
--   "Buy 12 × Coarse Thread"  vendor reagents the plan still lacks (only the missing amount, bundle sizes respected,
--                              as main also for the twink's plan: buy here, mail it with the next mail)
--   "Sell 1/7: Item"           the next junk item (grey, or white gear the advisor would vendor); 7 clicks empty it
--   "Repair 1g 2s"             one repair of all equipment
-- No timers, no loops over purchases: every purchase, sale and repair is a separate click (docs/04-COMPLIANCE.md).
--
-- Public API (ns.Merchant)
--   BuyList() -> { { index, item, qty, cost, forRec } }   reagents this merchant sells that the plan lacks
--   SellList() -> { { bag, slot, item, count, value } }     junk in the bags, most valuable first
local ADDON, ns = ...
local L = ns.L

local Merchant = {}
ns.Merchant = Merchant

local tabs

local function merchantItemID(i)
  if GetMerchantItemID then
    local ok, id = pcall(GetMerchantItemID, i)
    if ok and type(id) == "number" then return id end
  end
  local link = GetMerchantItemLink and GetMerchantItemLink(i)
  return link and tonumber(link:match("item:(%d+)")) or nil
end

local function merchantInfo(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
    if ok and type(info) == "table" then return info.price, math.max(1, info.stackCount or 1), info.numAvailable end
  end
  if GetMerchantItemInfo then
    local _, _, price, stack, numAvailable = GetMerchantItemInfo(i)
    return price, math.max(1, stack or 1), numAvailable
  end
  return nil
end

function Merchant.BuyList()
  local out = {}
  if not GetMerchantNumItems then return out end
  local want = {}
  for _, row in ipairs(ns.Coop.Shopping()) do want[row.item] = row end
  for i = 1, GetMerchantNumItems() or 0 do
    local id = merchantItemID(i)
    local row = id and want[id]
    if row and row.missing > 0 then
      local price, stack, available = merchantInfo(i)
      if price and price > 0 and not ns.Secret.Any(price, stack, available) then
        local qty = math.ceil(row.missing / stack) * stack
        local maxStack = GetMerchantItemMaxStack and GetMerchantItemMaxStack(i) or qty
        if type(maxStack) == "number" and maxStack > 0 then qty = math.min(qty, math.max(stack, maxStack)) end
        if available and available >= 0 then qty = math.min(qty, available * stack) end
        if qty > 0 then
          out[#out + 1] = { index = i, item = id, qty = qty, cost = price * qty / stack, forRec = row.forRec }
        end
      end
    end
  end
  return out
end

-- Junk: grey items with a vendor price, and white weapons/armour the advisor would sell to the vendor anyway.
local GEAR = { [2] = true, [4] = true }
function Merchant.SellList()
  local out = {}
  for _, it in ipairs(ns.Inventory.BagItems()) do
    if not it.isLocked then
      local info = ns.API.ItemInfo(it.itemID)
      local sell = info and info.sellPrice or 0
      local junk = false
      if info and sell > 0 then
        if it.quality == 0 then junk = true
        elseif it.quality == 1 and GEAR[info.classID] and not ns.Demand.For(it.itemID) then
          local best = ns.Advisor.Best({ id = it.itemID, quantity = it.count, quality = 1, vendorSell = sell, soulbound = it.isBound,
            reqLevel = info.reqLevel, isWeapon = info.classID == 2 }, ns.Advisor.LiveContext())
          junk = best ~= nil and best.action == "vendor"
        end
      end
      if junk then out[#out + 1] = { bag = it.bag, slot = it.slot, item = it.itemID, count = it.count, value = sell * it.count } end
    end
  end
  table.sort(out, function(a, b) return a.value > b.value end)
  return out
end

local function first(rec) return rec and (rec.firstName or rec.name) or "" end

local function refresh()
  if not tabs then return end
  if not (MerchantFrame and MerchantFrame:IsShown()) then return end
  -- repair
  local canRepair = CanMerchantRepair and CanMerchantRepair()
  local cost = canRepair and GetRepairAllCost and GetRepairAllCost() or 0
  if canRepair and type(cost) == "number" and cost > 0 then
    tabs[1]:Set((L["Repair %s"]):format(ns.Util.Money(cost)), L["Repairs all equipment (one click)."], function()
      if RepairAllItems then RepairAllItems() end
      if ns.Checks then ns.Checks.Pass("merchantHelp", "repair") end
      C_Timer.After(0.5, refresh)
    end, (GetMoney and GetMoney() or 0) >= cost)
  else
    tabs[1]:Clear()
  end
  -- sell
  local sell = Merchant.SellList()
  if #sell > 0 then
    local total = 0
    for _, s in ipairs(sell) do total = total + s.value end
    local s = sell[1]
    tabs[2]:Set((L["Sell 1/%d: %s"]):format(#sell, ns.UI.ItemName(s.item)),
      (L["Sells one junk item per click (%s). All %d together: %s."]):format(ns.Util.Money(s.value), #sell, ns.Util.Money(total)),
      function()
        ns.API.UseContainerItem(s.bag, s.slot)
        if ns.Checks then ns.Checks.Pass("merchantHelp", "sell") end
      end)
  else
    tabs[2]:Clear()
  end
  -- buy
  local buy = Merchant.BuyList()
  if #buy > 0 then
    local b = buy[1]
    local forText = b.forRec and b.forRec ~= ns.Chars.Current() and (" " .. (L["for %s"]):format(first(b.forRec))) or ""
    tabs[3]:Set((L["Buy %d × %s"]):format(b.qty, ns.UI.ItemName(b.item)),
      (L["Missing for the plan%s: %d × %s for %s. %d more item(s) on the list."]):format(forText, b.qty, ns.UI.ItemName(b.item), ns.Util.Money(b.cost), #buy - 1),
      function()
        if BuyMerchantItem then BuyMerchantItem(b.index, b.qty) end
        if ns.Ledger and ns.Ledger.RecordPurchase then ns.Ledger.RecordPurchase(b.item, b.qty, b.cost) end
        if ns.Checks then ns.Checks.Pass("merchantHelp", "buy") end
      end, (GetMoney and GetMoney() or 0) >= b.cost)
  else
    tabs[3]:Clear()
  end
end
Merchant.Refresh = refresh

ns:RegisterModule("Merchant", {
  Init = function()
    ns.Events:On("MERCHANT_SHOW", function()
      if not tabs and MerchantFrame then tabs = ns.UI.FrameTabs(MerchantFrame, 3) end
      C_Timer.After(0.4, function() pcall(refresh) end)
    end, "Merchant")
    ns.Events:On("BAG_UPDATE_DELAYED", function() if MerchantFrame and MerchantFrame:IsShown() then C_Timer.After(0.3, function() pcall(refresh) end) end end, "Merchant")
    ns.Events:On("UPDATE_INVENTORY_DURABILITY", function() if MerchantFrame and MerchantFrame:IsShown() then pcall(refresh) end end, "Merchant")
  end,
  SelfTest = function()
    return { { name = L["Merchant tabs"], ok = true, warn = tabs == nil, detail = tabs and L["built"] or L["only after the first merchant visit"] } }
  end,
})

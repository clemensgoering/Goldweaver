-- Goldweaver: inventory snapshots per character (bags always, bank while the bank is open).
-- Snapshots live in GoldweaverDB.chars[name].inventory = { bags = {[itemID]=count}, bank = {[itemID]=count}, when = time }.
-- ns.Inventory.Count(itemID, { bank = true, alts = true }) answers "how many do we have" for planner and advisor.
local ADDON, ns = ...
local L = ns.L

local Inventory = {}
ns.Inventory = Inventory

local BAGS = { 0, 1, 2, 3, 4 }
local BANK = { -1, 5, 6, 7, 8, 9, 10, 11 }

local function scan(containers)
  local counts = {}
  if not (C_Container and C_Container.GetContainerNumSlots) then return counts end
  for _, bag in ipairs(containers) do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and not ns.Secret.Any(info.itemID, info.stackCount) then
        counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return counts
end

-- Full list of bag items with location, for mail planning and the disenchant queue.
function Inventory.BagItems()
  local items = {}
  if not (C_Container and C_Container.GetContainerNumSlots) then return items end
  for _, bag in ipairs(BAGS) do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and not ns.Secret.Any(info.itemID, info.stackCount, info.quality, info.isBound, info.isLocked) then
        items[#items + 1] = {
          bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
          quality = info.quality, isBound = info.isBound and true or false, isLocked = info.isLocked and true or false,
          link = info.hyperlink,
        }
      end
    end
  end
  return items
end

function Inventory.FreeBagSlots()
  local free = 0
  if not (C_Container and C_Container.GetContainerNumFreeSlots) then return 0 end
  for _, bag in ipairs(BAGS) do
    local n = C_Container.GetContainerNumFreeSlots(bag)
    free = free + (tonumber(n) or 0)
  end
  return free
end

local function record()
  local rec = ns.Chars.Current()
  if not rec then return end
  rec.inventory = rec.inventory or { bags = {}, bank = {} }
  rec.inventory.bags = scan(BAGS)
  rec.inventory.when = time()
  Inventory.dirty = false
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
  if ns.HUD and ns.HUD.Refresh then ns.HUD.Refresh() end
end

local function recordBank()
  local rec = ns.Chars.Current()
  if not rec then return end
  rec.inventory = rec.inventory or { bags = {}, bank = {} }
  rec.inventory.bank = scan(BANK)
  rec.inventory.bankWhen = time()
end

-- Count across own bags (live), optionally this character's bank snapshot and other characters' snapshots.
-- Returns total, breakdown { bags, bank, alts = { {name, count} } }.
function Inventory.Count(itemID, opts)
  opts = opts or {}
  local breakdown = { bags = 0, bank = 0, alts = {} }
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, itemID, false)
    breakdown.bags = ok and tonumber(n) or 0
  end
  local total = breakdown.bags
  local me = ns.Chars.Current()
  if opts.bank ~= false and me and me.inventory and me.inventory.bank then
    breakdown.bank = me.inventory.bank[itemID] or 0
    total = total + breakdown.bank
  end
  -- mail: the own inbox snapshot and what was sent to a character but not seen yet (Modules/Coop.lua)
  local function mailed(inv)
    local n = inv.mail and inv.mail[itemID] or 0
    if inv.incoming and inv.incoming.items then n = n + (inv.incoming.items[itemID] or 0) end
    return n
  end
  breakdown.mail = 0
  if opts.mail ~= false and me and me.inventory then
    breakdown.mail = mailed(me.inventory)
    total = total + breakdown.mail
  end
  if opts.alts and me then
    for _, rec in pairs(ns.db.chars) do
      if rec ~= me and rec.market == me.market and rec.inventory then
        local inv = rec.inventory
        local n = (inv.bags and inv.bags[itemID] or 0) + (inv.bank and inv.bank[itemID] or 0) + (opts.mail ~= false and mailed(inv) or 0)
        if n > 0 then
          breakdown.alts[#breakdown.alts + 1] = { name = rec.name, count = n }
          total = total + n
        end
      end
    end
  end
  return total, breakdown
end

ns:RegisterModule("Inventory", {
  SelfTest = function()
    local me = ns.Chars.Current()
    local inv = me and me.inventory
    local n = 0
    for _ in pairs(inv and inv.bags or {}) do n = n + 1 end
    return {
      { name = L["Bag snapshot"], ok = inv ~= nil and inv.when ~= nil, detail = inv and inv.when and (L["%d item types, %d s old"]):format(n, time() - inv.when) or L["no snapshot yet"] },
      { name = L["Bank snapshot"], ok = inv ~= nil and inv.bankWhen ~= nil, warn = true, detail = inv and inv.bankWhen and (L["%d s old"]):format(time() - inv.bankWhen) or L["bank not visited yet"] },
      { name = L["Free bag slots"], ok = true, detail = tostring(Inventory.FreeBagSlots()) },
    }
  end,
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(3, record) end)
    ns.Events:On("BAG_UPDATE_DELAYED", function()
      -- coalesce bursts: one snapshot per second at most
      if Inventory.dirty then return end
      Inventory.dirty = true
      C_Timer.After(1, record)
    end)
    ns.Events:On("BANKFRAME_OPENED", function() C_Timer.After(0.5, recordBank) end)
    ns.Events:On("PLAYERBANKSLOTS_CHANGED", function() if BankFrame and BankFrame:IsShown() then recordBank() end end)
  end,
})

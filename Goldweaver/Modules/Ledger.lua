-- Goldweaver: sales ledger from auction house invoices in the mailbox. Stores only own data: item, quantity, price,
-- deposit, cut, time. Never the buyer's name (docs/04-COMPLIANCE.md, privacy).
-- GoldweaverCharDB.ledger = { entries = { {t, kind, item, count, price, deposit, cut} }, gold = { [dayKey] = {start, last} } }
local ADDON, ns = ...

local Ledger = {}
ns.Ledger = Ledger

local DAY = 86400

local function store()
  ns.cdb.ledger = ns.cdb.ledger or { entries = {}, gold = {} }
  return ns.cdb.ledger
end

-- Reads invoice `index` of the inbox and records it when it is a sale. Returns the entry or nil.
function Ledger.RecordInvoice(index)
  if not GetInboxInvoiceInfo then return nil end
  local invoiceType, itemName, _, bid, buyout, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(index)
  if ns.Secret.Any(invoiceType, itemName, bid, buyout, deposit, consignment, count) then return nil end
  if invoiceType ~= "seller" then return nil end
  local price = (buyout and buyout > 0) and buyout or bid or 0
  local entry = { t = time(), kind = "sale", item = itemName, count = count or 1, price = price, deposit = deposit or 0, cut = consignment or 0 }
  local l = store()
  l.entries[#l.entries + 1] = entry
  -- keep the ledger bounded
  while #l.entries > 2000 do table.remove(l.entries, 1) end
  return entry
end

-- Passive inbox scan: Forever's mailbox has its own "Open all". We read every invoice while the inbox is shown
-- and record a sale once its mail disappears (looted or deleted). Keyed by item, price, count and arrival time.
local seenInvoices = {}
function Ledger.ScanInbox()
  if not (GetInboxNumItems and GetInboxHeaderInfo and GetInboxInvoiceInfo) then return end
  local n = GetInboxNumItems() or 0
  local current = {}
  for i = 1, n do
    local _, _, _, _, _, _, daysLeft = GetInboxHeaderInfo(i)
    local invoiceType, itemName, _, bid, buyout, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
    if invoiceType == "seller" and not ns.Secret.Any(itemName, bid, buyout, deposit, consignment, count, daysLeft) then
      local price = (buyout and buyout > 0) and buyout or bid or 0
      local key = ("%s|%d|%d|%.3f"):format(tostring(itemName), price, count or 1, daysLeft or 0)
      current[key] = true
      if not seenInvoices[key] then
        seenInvoices[key] = { item = itemName, count = count or 1, price = price, deposit = deposit or 0, cut = consignment or 0 }
      end
    end
  end
  local recorded = 0
  for key, inv in pairs(seenInvoices) do
    if not current[key] then
      local l = store()
      l.entries[#l.entries + 1] = { t = time(), kind = "sale", item = inv.item, count = inv.count, price = inv.price, deposit = inv.deposit, cut = inv.cut }
      while #l.entries > 2000 do table.remove(l.entries, 1) end
      seenInvoices[key] = nil
      recorded = recorded + 1
      if ns.Checks then
        ns.Checks.Pass("ledger", ("%s x%d for %s"):format(tostring(inv.item), inv.count, ns.Util.Money(inv.price)))
        ns.Checks.Pass("mailOpen", "invoices recorded when opening")
      end
    end
  end
  return recorded
end

-- Totals for the last `days` days: { sales, count, deposits, cut }
-- Purchase prices (B23): what the account paid per unit, a running average that favours recent buys.
-- GoldweaverDB.costs[itemID] = { unit, qty, when }
function Ledger.RecordPurchase(itemID, qty, totalCopper)
  if not (itemID and qty and qty > 0 and totalCopper and totalCopper >= 0) then return end
  ns.db.costs = ns.db.costs or {}
  local c = ns.db.costs[itemID] or { unit = 0, qty = 0 }
  local weight = math.min(c.qty, 200)
  c.unit = math.floor((c.unit * weight + totalCopper) / (weight + qty) + 0.5)
  c.qty = weight + qty
  c.when = time()
  ns.db.costs[itemID] = c
end

-- Cost basis per unit: own purchase price, else the material cost of crafting it (cheapest known recipe).
-- Returns copper, source ("bought" | "crafted") or nil.
function Ledger.UnitCost(itemID)
  local c = ns.db.costs and ns.db.costs[itemID]
  if c and c.unit and c.unit > 0 then return c.unit, "bought" end
  local best
  for _, book in pairs(ns.db.recipes or {}) do
    for _, r in ipairs(book.list or {}) do
      if r.outputItemID == itemID then
        local ok, cost, coverage = pcall(ns.Planner.CraftCost, r)
        if ok and cost and (coverage == nil or coverage >= 1) then
          local per = cost / math.max(1, ((r.qtyMin or 1) + (r.qtyMax or 1)) / 2)
          if not best or per < best then best = per end
        end
      end
    end
  end
  if best then return math.floor(best + 0.5), "crafted" end
  return nil
end

-- Lowest unit price that loses nothing after the AH cut and the deposit share.
function Ledger.BreakEven(itemID, quantity, deposit)
  local unit = Ledger.UnitCost(itemID)
  if not unit then return nil end
  local cut = ns.db.settings.ahCut or 0.05
  return math.ceil((unit + (deposit or 0) / math.max(1, quantity or 1)) / (1 - cut))
end

function Ledger.Totals(days)
  local l = store()
  local since = time() - (days or 1) * DAY
  local t = { sales = 0, count = 0, deposits = 0, cut = 0 }
  for _, e in ipairs(l.entries) do
    if e.t >= since and e.kind == "sale" then
      t.sales = t.sales + e.price
      t.count = t.count + 1
      t.deposits = t.deposits + (e.deposit or 0)
      t.cut = t.cut + (e.cut or 0)
    end
  end
  return t
end

-- Gold per day (first and last seen money of the day) for the seven-day line.
function Ledger.TrackGold()
  if not GetMoney then return end
  local money = GetMoney()
  if ns.Secret.IsSecret(money) then return end
  local l = store()
  local day = math.floor(time() / DAY)
  local g = l.gold[day] or { start = money }
  g.last = money
  l.gold[day] = g
  for k in pairs(l.gold) do if k < day - 14 then l.gold[k] = nil end end
end

function Ledger.GoldDelta(day)
  local l = store()
  local g = l.gold[day or math.floor(time() / DAY)]
  if not g then return nil end
  return (g.last or g.start) - g.start
end

function Ledger.SessionDelta()
  if not (GetMoney and Ledger.sessionStart) then return 0 end
  local m = GetMoney()
  if ns.Secret.IsSecret(m) then return 0 end
  return m - Ledger.sessionStart
end

ns:RegisterModule("Ledger", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function()
      if GetMoney then
        local m = GetMoney()
        if not ns.Secret.IsSecret(m) then Ledger.sessionStart = m end
      end
      Ledger.TrackGold()
    end)
    ns.Events:On("PLAYER_MONEY", function()
      Ledger.TrackGold()
      if ns.HUD and ns.HUD.Refresh then ns.HUD.Refresh() end
    end, "Ledger")
    ns.Events:On("MAIL_SHOW", function() C_Timer.After(0.5, Ledger.ScanInbox) end, "Ledger")
    ns.Events:On("MAIL_INBOX_UPDATE", function() Ledger.ScanInbox() end, "Ledger")
    ns.Events:On("MAIL_CLOSED", function() Ledger.ScanInbox() end, "Ledger")
  end,
})

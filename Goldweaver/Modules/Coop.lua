-- Goldweaver: main and twink as one team. The gatherer (main) levels and collects on the side exactly what the
-- crafter (processor) needs for the next skill points; this module joins both sides: who the partner is, what the
-- crafter's skill-up plans still need and where each piece is (gatherer, mail, crafter), whether it grows in the
-- current zone, how many skill points the materials cover, mail in transit and the "gathered for X" notice.
-- Two clients cannot talk to each other (no network, SavedVariables are written on logout/reload), so the other
-- character's side is always the state of its last session.
--
-- Public API (ns.Coop)
--   Partner(rec?) -> rec | nil             main: the processor with the most professions; processor: the main
--   Team() -> gatherer, crafter            either may be nil
--   Needs() -> view | nil                  cached 5 s, see below
--   RecordSent(rec, items)                 items = { [itemID] = count }; called on MAIL_SEND_SUCCESS
--   ScanInbox()                            snapshot of the items in the own inbox
--   Invalidate()
--   Shopping() -> { { item, need, have, missing, source, forRec } }  what the plan lacks (team list or own plan)
--   session = { items, value, points, start, login }, SessionLine()  session tally for the gatherer (B17)
-- view = { gatherer, crafter, rows = { row }, plans = { {skillLine, name, from, to} }, points, fromGatherer, fromMail }
-- row  = { item, need, have, gatherer, mail, crafter, here, source = "here"|"gatherer"|"vendor"|"elsewhere", via }
--
-- Data: GoldweaverDB.chars[name].inventory.mail     = { [itemID] = count }  items in that character's inbox
--       GoldweaverDB.chars[name].inventory.incoming = { items = { [itemID] = count }, when }  sent to it, not seen yet
local ADDON, ns = ...
local L = ns.L

local Coop = {}
ns.Coop = Coop

local TTL = 5
local cache, cacheWhen = nil, 0

function Coop.Invalidate() cache = nil end

local function activeProfessions(rec)
  local n = 0
  for _, p in pairs(rec and rec.professions or {}) do if not p.former then n = n + 1 end end
  return n
end

function Coop.Partner(rec)
  rec = rec or ns.Chars.Current()
  if not rec then return nil end
  local want = rec.role == "processor" and "main" or "processor"
  local best
  for _, other in ipairs(ns.Chars.ByRole(want, rec.market)) do
    if other ~= rec and (not best or activeProfessions(other) > activeProfessions(best)) then best = other end
  end
  return best
end

function Coop.Team()
  local me = ns.Chars.Current()
  if not me then return nil, nil end
  if me.role == "processor" then return Coop.Partner(me), me end
  if me.role == "main" then return me, Coop.Partner(me) end
  return nil, nil
end

-- Items of a character: bags + bank (live bags for the current character), and its mail (inbox + in transit).
local function held(rec, itemID)
  if not rec then return 0 end
  if rec == ns.Chars.Current() then
    local _, b = ns.Inventory.Count(itemID, { bank = true })
    return (b.bags or 0) + (b.bank or 0)
  end
  local inv = rec.inventory or {}
  return (inv.bags and inv.bags[itemID] or 0) + (inv.bank and inv.bank[itemID] or 0)
end

local function mailOf(rec, itemID)
  local inv = rec and rec.inventory or {}
  local n = inv.mail and inv.mail[itemID] or 0
  if inv.incoming and inv.incoming.items then n = n + (inv.incoming.items[itemID] or 0) end
  return n
end

local function zoneItems(me, gatherer)
  local set = {}
  if not gatherer or me ~= gatherer then return set end
  local ok, report = pcall(ns.Field.Analyze)
  if not (ok and report) then return set end
  for _, r in ipairs(report.gather or {}) do if r.hasProfession then set[r.item] = true end end
  if report.mobs then
    if report.mobs.cloth then set[report.mobs.cloth] = true end
    if report.mobs.leather then set[report.mobs.leather] = true end
  end
  return set
end

local function canGather(rec, itemID)
  local G = ns.Data.Gathering
  local node = G and G.nodes[itemID]
  local skillLine = node and G.KIND_SKILL[node.kind]
  return skillLine ~= nil and rec ~= nil and rec.professions ~= nil and rec.professions[skillLine] ~= nil
end

-- Expected skill points the plan's materials cover. minus(itemID) removes a share (e.g. what the gatherer holds) to
-- tell how much of it that share is responsible for. Vendor reagents count as available: the crafter buys them.
local function coverPoints(plan, minus)
  local best = plan.best
  if not (best and plan.crafts) then return 0 end
  local crafts = plan.crafts
  for _, r in ipairs(best.recipe.reagents or {}) do
    if not ns.Data.VendorReagents[r.item] then
      local have = ns.Inventory.Count(r.item, { bank = true, alts = true }) - (minus and minus(r.item) or 0)
      crafts = math.min(crafts, math.floor(math.max(0, have) / math.max(1, r.qty)))
    end
  end
  return crafts * (best.chance or 1)
end

local function build()
  local me = ns.Chars.Current()
  local gatherer, crafter = Coop.Team()
  if not (gatherer and crafter) then return nil end
  local view = { gatherer = gatherer, crafter = crafter, rows = {}, plans = {}, points = 0, fromGatherer = 0, fromMail = 0 }
  local byItem = {}
  local function add(itemID, need, via)
    if not itemID or need <= 0 then return end
    local row = byItem[itemID]
    if not row then
      row = { item = itemID, need = 0, via = via }
      byItem[itemID] = row
      view.rows[#view.rows + 1] = row
    end
    row.need = row.need + need
  end
  for skillLine, p in pairs(crafter.professions or {}) do
    if not p.former and ns.Adapter.Book(skillLine) then
      local ok, plan = pcall(ns.Planner.Plan, skillLine, crafter)
      if ok and plan and plan.best and plan.shopping then
        local skill = plan.rank and plan.rank.skill or p.rank or 0
        view.plans[#view.plans + 1] = { skillLine = skillLine, name = p.name or "?", from = skill,
          to = math.floor(skill + plan.crafts * (plan.best.chance or 1)) }
        for _, s in ipairs(plan.shopping) do
          add(s.item, s.need)
          -- raw material one step down the graph (Linen Cloth for a needed Bolt of Linen Cloth)
          if s.buy > 0 then
            for _, conv in ipairs(ns.Graph.ForOutput(s.item)) do
              if conv.kind == "craft" or conv.kind == "smelt" then
                local perRun = conv.outputs[1] and conv.outputs[1].qty or 1
                local runs = math.ceil(s.buy / math.max(perRun, 0.0001))
                for _, inp in ipairs(conv.inputs) do add(inp.item, inp.qty * runs, s.item) end
                break
              end
            end
          end
        end
        view.points = view.points + coverPoints(plan)
        view.fromGatherer = view.fromGatherer + coverPoints(plan) - coverPoints(plan, function(item) return held(gatherer, item) end)
        view.fromMail = view.fromMail + coverPoints(plan) - coverPoints(plan, function(item) return mailOf(crafter, item) end)
      end
    end
  end
  local here = zoneItems(me, gatherer)
  for _, row in ipairs(view.rows) do
    row.gatherer, row.mail, row.crafter = held(gatherer, row.item), mailOf(crafter, row.item), held(crafter, row.item)
    row.have = math.max(row.gatherer + row.mail + row.crafter, (ns.Inventory.Count(row.item, { bank = true, alts = true })))
    if ns.Data.VendorReagents[row.item] then row.source = "vendor"
    elseif here[row.item] then row.here = true; row.source = "here"
    elseif canGather(gatherer, row.item) then row.source = "gatherer"
    else row.source = "elsewhere" end
  end
  local ORDER = { here = 1, gatherer = 2, elsewhere = 3, vendor = 4 }
  table.sort(view.rows, function(a, b)
    local ad, bd = a.have >= a.need and 1 or 0, b.have >= b.need and 1 or 0
    if ad ~= bd then return ad < bd end
    if ORDER[a.source] ~= ORDER[b.source] then return ORDER[a.source] < ORDER[b.source] end
    return (a.need - a.have) > (b.need - b.have)
  end)
  view.points, view.fromGatherer, view.fromMail = math.floor(view.points), math.floor(view.fromGatherer), math.floor(view.fromMail)
  return view
end

function Coop.Needs()
  if cache == nil or time() - cacheWhen > TTL then
    local ok, view = pcall(build)
    if not ok then ns.Health.Record("Coop.build", view); view = nil end
    cache, cacheWhen = view or false, time()
  end
  return cache or nil
end

-- What the plan still lacks, for the helpers at merchant, bank and auction house: the team's gather list when a
-- main/processor pair exists, else this character's own skill-up plans.
-- -> { { item, need, have, missing, source, forRec } }  (forRec = the character the materials are for)
function Coop.Shopping()
  local out = {}
  local view = Coop.Needs()
  if view then
    for _, r in ipairs(view.rows) do
      if r.have < r.need then
        out[#out + 1] = { item = r.item, need = r.need, have = r.have, missing = r.need - r.have, source = r.source, forRec = view.crafter }
      end
    end
    return out
  end
  local me = ns.Chars.Current()
  local byItem = {}
  for skillLine, p in pairs(me and me.professions or {}) do
    if not p.former and ns.Adapter.Book(skillLine) then
      local ok, plan = pcall(ns.Planner.Plan, skillLine, me)
      if ok and plan and plan.shopping then
        for _, s in ipairs(plan.shopping) do
          if s.buy > 0 then
            local row = byItem[s.item]
            if not row then
              row = { item = s.item, need = 0, have = s.have, missing = 0, forRec = me,
                source = ns.Data.VendorReagents[s.item] and "vendor" or "elsewhere" }
              byItem[s.item] = row
              out[#out + 1] = row
            end
            row.need, row.missing = row.need + s.need, row.missing + s.buy
          end
        end
      end
    end
  end
  return out
end

-- Session tally for the gatherer: what was picked up for the crafter since login (B17).
Coop.session = { items = 0, value = 0, points = 0, start = nil, login = nil }

-- "Session +1g 18s (2g 40s/h)" plus, for the gatherer, "for Grel: 34 items · +6 skill".
function Coop.SessionLine()
  local delta = ns.Ledger.SessionDelta()
  local s = Coop.session
  local hours = math.max(0.25, (time() - (s.login or time())) / 3600)
  local line = (L["Session %s (%s/h)"]):format((delta >= 0 and "+" or "-") .. ns.Util.Money(math.abs(delta)),
    ns.Util.Money(math.max(0, math.floor(delta / hours))))
  local view = Coop.Needs()
  if s.items > 0 and view then
    line = line .. " · " .. (L["for %s: %d items · +%d skill"]):format(view.crafter.firstName or view.crafter.name, s.items, s.points)
  end
  return line
end

-- Mail ------------------------------------------------------------------------------------------

function Coop.RecordSent(rec, items)
  if not (rec and items and next(items)) then return end
  rec.inventory = rec.inventory or { bags = {}, bank = {} }
  local inc = rec.inventory.incoming or { items = {} }
  for itemID, n in pairs(items) do inc.items[itemID] = (inc.items[itemID] or 0) + n end
  inc.when = time()
  rec.inventory.incoming = inc
  Coop.Invalidate()
end

-- Counts the items in the own inbox. The inbox replaces "in transit": everything sent has arrived by now.
function Coop.ScanInbox()
  local me = ns.Chars.Current()
  if not (me and GetInboxNumItems and GetInboxItem) then return end
  local ok, n = pcall(GetInboxNumItems)
  if not ok or ns.Secret.IsSecret(n) then return end
  local counts = {}
  for i = 1, tonumber(n) or 0 do
    for j = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
      local okItem, _, itemID, _, count = pcall(GetInboxItem, i, j)
      if okItem and itemID and not ns.Secret.Any(itemID, count) then counts[itemID] = (counts[itemID] or 0) + (count or 1) end
    end
  end
  me.inventory = me.inventory or { bags = {}, bank = {} }
  me.inventory.mail = counts
  me.inventory.incoming = nil
  Coop.Invalidate()
end

-- Notice "+3 Linen Cloth for Grel · 35 / 60" -------------------------------------------------------

local toast, toastHide = nil, 0
local lastCounts

local function showToast(line1, line2)
  if not toast then
    toast = CreateFrame("Frame", nil, UIParent)
    toast:SetSize(320, 44)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
    toast:SetFrameStrata("MEDIUM")
    ns.UI.Skin(toast, "hl")
    toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.text:SetPoint("TOP", 0, -8)
    toast.sub = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toast.sub:SetPoint("TOP", toast.text, "BOTTOM", 0, -3)
  end
  toast.text:SetText(line1)
  toast.sub:SetText(line2 or "")
  toast:SetHeight(line2 and 44 or 28)
  toast:Show()
  toastHide = GetTime() + 4
  C_Timer.After(4.1, function() if toast and GetTime() >= toastHide then toast:Hide() end end)
end

local function busy()
  return (MailFrame and MailFrame:IsShown()) or (BankFrame and BankFrame:IsShown()) or (MerchantFrame and MerchantFrame:IsShown())
    or (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (TradeFrame and TradeFrame:IsShown())
end

local function onBags()
  Coop.Invalidate()
  local me = ns.Chars.Current()
  local view = Coop.Needs()
  if not (view and me == view.gatherer) then lastCounts = nil; return end
  local counts = {}
  for _, row in ipairs(view.rows) do counts[row.item] = row.gatherer end
  local before, prevPoints = lastCounts, Coop.lastPoints
  lastCounts, Coop.lastPoints = counts, view.fromGatherer
  if not before or busy() then return end
  local s = Coop.session
  for _, row in ipairs(view.rows) do
    local gained = row.gatherer - (before[row.item] or row.gatherer)
    if gained > 0 and row.source ~= "vendor" then
      s.start = s.start or time()
      s.items = s.items + gained
      s.value = s.value + gained * (ns.Price.Copper(row.item) or 0)
      if prevPoints and view.fromGatherer > prevPoints then s.points = s.points + (view.fromGatherer - prevPoints) end
    end
  end
  if ns.db.settings.coopToast == false then return end
  for _, row in ipairs(view.rows) do
    local gained = row.gatherer - (before[row.item] or row.gatherer)
    if gained > 0 and row.source ~= "vendor" then
      local who = view.crafter.firstName or view.crafter.name
      local line2
      if prevPoints and view.fromGatherer > prevPoints then
        line2 = (L["enough for +%d skill points for %s"]):format(view.fromGatherer, who)
      end
      showToast((L["+%d %s for %s · %d / %d"]):format(gained, ns.UI.ItemName(row.item), who, math.min(row.have, row.need), row.need), line2)
      if ns.Checks then ns.Checks.Pass("coopGather", ("%d × %s"):format(gained, tostring(row.item))) end
      return
    end
  end
end

ns:RegisterModule("Coop", {
  Init = function()
    -- coalesce bursts: looting fires this several times in a row and onBags runs the planner
    local pending = false
    ns.Events:On("BAG_UPDATE_DELAYED", function()
      if pending then return end
      pending = true
      C_Timer.After(0.3, function() pending = false; pcall(onBags) end)
    end, "Coop")
    ns.Events:On("MAIL_INBOX_UPDATE", Coop.ScanInbox, "Coop")
    ns.Events:On("PLAYER_LOGIN", function()
      Coop.session.login = time()
      C_Timer.After(8, function() pcall(onBags) end)
    end, "Coop")
  end,
  SelfTest = function()
    local gatherer, crafter = Coop.Team()
    local view = Coop.Needs()
    return {
      { name = L["Team"], ok = true, warn = not (gatherer and crafter),
        detail = (gatherer and crafter) and ("%s » %s"):format(gatherer.name, crafter.name) or L["no main/processor pair yet"] },
      { name = L["Gather list"], ok = true, detail = view and (L["%d item(s), %d skill point(s) covered"]):format(#view.rows, view.points) or "-" },
    }
  end,
})

-- Goldweaver: budget. What the team will have to pay (class skills, profession ranks, riding, materials for the
-- next skill-ups) against the gold of all own characters on this market, and how strongly Goldweaver should push
-- for gold. Costs differ a lot by class and profession, so the support has three strengths:
--   covered  gold covers the next HORIZON levels: advice as usual
--   light    gold covers at least half: selling wins over disenchanting/crafting/crates unless they earn 15 % more
--   strong   less than half: selling wins unless the other use earns 50 % more; the guide leads with making gold
-- The Advisor and the mailbox follow this (Modules/Advisor.lua, Modules/Mail.lua).
--
-- Public API (ns.Budget)
--   RegisterExpense(name, fn(rec) -> { expense }) ★   expense = { id, label, copper|nil, level, kind, estimate?, icon? }
--   Expenses(rec) -> { expense }        everything a character will pay from now to 60, by level
--   Summary(market?) -> { cash, due, gap, strength, items, later, perChar, byKind = { [kind] = copper },
--                         nowDue, nowCash, nowGap, nowItems }   (cached a few seconds)
--   KINDS = { "class", "rank", "riding", "materials" }   display order of the cost kinds
--   Strength() -> "covered" | "light" | "strong";  NeedsCash() -> boolean (light or strong, setting on)
--   CashMargin() -> factor a non-cash use must beat selling by (1 when covered)
--   Timeline(rec) -> { { from, to, class, ranks, riding, materials, materialsPriced, total } }   bands of ten levels
-- Data (own characters only): chars[name].money, .ridingKnown, .classTraining = { byTrainer = { [npc] = { when,
-- services = { {name, levelReq, cost, available} } } } }. A trainer lists only what is not learned yet (verified
-- 14.11.2026): "available" is due now, "unavailable" later. The newest visit of a trainer group replaces older lists.
local ADDON, ns = ...
local L = ns.L

local Budget = { expenses = {}, order = {} }
ns.Budget = Budget
Budget.KINDS = { "class", "rank", "riding", "materials" }

local HORIZON = 10
local CACHE = 5
local MARGIN = { covered = 1, light = 1.15, strong = 1.5 }
local RIDING_LEVEL, RIDING_COST = 40, 1200000 -- 100 g training + 20 g mount (Method, Warcraft Tavern, 11/2026)
local RIDING_FREE = { PALADIN = true, WARLOCK = true } -- class mount quest instead of buying
local RIDING_SPELL = 33388   -- Apprentice Riding

-- Class skill costs per level until the own class trainer was visited. 26-60: a Forever hunter trainer
-- (Ormak Grimshot, read by Goldweaver on 14.11.2026, 180 g in total); below 26: estimated with the same rise.
-- Classes learn different numbers of skills per level, so this is a typical value, not a promise.
local CLASS_COST = {
  [4] = 100, [6] = 300, [8] = 600, [10] = 1500, [12] = 2500, [14] = 3500, [16] = 5000, [18] = 6000, [20] = 10000,
  [22] = 12000, [24] = 15000, [26] = 26640, [28] = 33750, [30] = 41040, [32] = 36000, [34] = 29700, [36] = 70200,
  [38] = 27000, [40] = 144000, [42] = 39600, [44] = 103500, [46] = 100800, [48] = 130500, [50] = 162000, [52] = 97200,
  [54] = 66600, [56] = 136800, [58] = 210600, [60] = 340200,
}
Budget.CLASS_COST = CLASS_COST

function Budget.RegisterExpense(name, fn)
  assert(type(name) == "string" and type(fn) == "function", "RegisterExpense(name, fn)")
  if not Budget.expenses[name] then Budget.order[#Budget.order + 1] = name end
  Budget.expenses[name] = fn
end

-- Highest skill a character can train to at a level (rank caps unlocked by level only).
local function capAtLevel(profile, level)
  local cap = 0
  for _, r in ipairs(profile.ranks or {}) do if (r.reqLevel or 0) <= level then cap = r.max end end
  return cap
end

-- Built-in expenses -------------------------------------------------------------------------------------

-- Every rank still to train, at the level it unlocks (or now, when the level is already there).
Budget.RegisterExpense("professionRanks", function(rec)
  local out = {}
  for skillLine, p in pairs(rec.professions or {}) do
    local profile = not p.former and ns.Professions:BySkillLine(skillLine)
    if profile then
      for _, r in ipairs(profile.ranks or {}) do
        if r.max > (p.maxRank or 0) and (r.cost or 0) > 0 then
          local seenLevel, seenCost = ns.Learn.RankRequirement(skillLine, r.reqSkill)
          out[#out + 1] = { id = "rank" .. skillLine .. r.name, kind = "rank", icon = ns.Steps.ICON.train,
            label = ("%s %s"):format(L[r.name], p.name or "?"), copper = seenCost or r.cost,
            level = math.max(rec.level or 1, seenLevel or r.reqLevel or 0), estimate = seenCost == nil }
        end
      end
    end
  end
  return out
end)

Budget.RegisterExpense("riding", function(rec)
  if RIDING_FREE[rec.class or ""] or rec.ridingKnown or (rec.level or 1) > RIDING_LEVEL then return nil end
  return { { id = "riding", kind = "riding", icon = "Interface\\Icons\\Ability_Mount_RidingHorse", label = L["Riding and mount"],
    copper = RIDING_COST, level = RIDING_LEVEL, estimate = true } }
end)

-- Class skills: own trainer data when there is some, else the typical curve. One entry per level.
Budget.RegisterExpense("classSkills", function(rec)
  local level = rec.level or 1
  local byLevel, own = {}, false
  local t = rec.classTraining
  if t and t.byTrainer and next(t.byTrainer) then
    own = true
    for _, visit in pairs(t.byTrainer) do
      for _, s in ipairs(visit.services or {}) do
        -- available = learnable now: due at the current level even if it was unlocked earlier
        local lv = s.available and level or s.levelReq
        if s.cost and s.cost > 0 and lv then byLevel[lv] = (byLevel[lv] or 0) + s.cost end
      end
    end
  else
    for lv, copper in pairs(CLASS_COST) do if lv > level then byLevel[lv] = copper end end
  end
  local out = {}
  for lv, copper in pairs(byLevel) do
    out[#out + 1] = { id = "class" .. lv, kind = "class", icon = "Interface\\Icons\\INV_Misc_Book_11", label = L["Class skills"],
      copper = copper, level = math.max(lv, level), estimate = not own }
  end
  return out
end)

Budget.RegisterExpense("skillUpMaterials", function(rec)
  local out = {}
  for skillLine, p in pairs(rec.professions or {}) do
    if not p.former and ns.Adapter.Book(skillLine) then
      local ok, plan = pcall(ns.Planner.Plan, skillLine, rec)
      if ok and plan and plan.best and (plan.shoppingCost or 0) > 0 then
        out[#out + 1] = { id = "mats" .. skillLine, kind = "materials", item = plan.shopping[1] and plan.shopping[1].item,
          label = (L["Materials: %s"]):format(p.name or "?"), copper = plan.shoppingCost, level = rec.level or 1 }
      end
    end
  end
  return out
end)

-- Evaluation -------------------------------------------------------------------------------------------

function Budget.Expenses(rec)
  local out = {}
  for _, name in ipairs(Budget.order) do
    local ok, list = pcall(Budget.expenses[name], rec)
    if not ok then ns.Health.Record("budget " .. name, list)
    else for _, e in ipairs(list or {}) do e.rec = rec; out[#out + 1] = e end end
  end
  table.sort(out, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return (a.copper or 0) > (b.copper or 0)
  end)
  return out
end

local cache, cacheAt = nil, 0
function Budget.Invalidate() cache = nil end

function Budget.Summary(market)
  local now = GetTime and GetTime() or 0
  if cache and not market and now - cacheAt < CACHE then return cache end
  local s = { cash = 0, due = 0, items = {}, later = {}, perChar = {}, byKind = {}, nowDue = 0, nowCash = 0, nowItems = {} }
  local me = ns.Chars.Current()
  for _, rec in ipairs(ns.Chars.All(market or ns.Chars.MarketKey())) do
    if rec.role ~= "none" then
      s.cash = s.cash + (rec.money or 0)
      s.perChar[rec.name] = rec.money or 0
      local level = rec.level or 1
      for _, e in ipairs(Budget.Expenses(rec)) do
        -- due right now for the character at the keyboard: paid from its own bags, not the team's
        if rec == me and e.copper and e.level <= level then s.nowDue = s.nowDue + e.copper; s.nowItems[#s.nowItems + 1] = e end
        if e.copper then
          if e.level <= level + HORIZON then
            s.items[#s.items + 1] = e; s.due = s.due + e.copper
            s.byKind[e.kind] = (s.byKind[e.kind] or 0) + e.copper
          else s.later[#s.later + 1] = e end
        end
      end
    end
  end
  -- biggest first within the horizon, so the four visible rows explain most of the money
  table.sort(s.items, function(a, b) return a.copper > b.copper end)
  s.gap = s.due - s.cash
  s.nowCash = me and me.money or 0
  s.nowGap = s.nowDue - s.nowCash
  -- what is due now and cannot be paid always means strong support (example: level 28, skills for 75 s each)
  if s.nowGap > 0 then s.strength = "strong"
  elseif s.due <= 0 or s.cash >= s.due then s.strength = "covered"
  elseif s.cash >= s.due / 2 then s.strength = "light"
  else s.strength = "strong" end
  if not market then cache, cacheAt = s, now end
  return s
end

function Budget.Strength()
  if ns.db.settings.cashFirst == false then return "covered" end
  local ok, s = pcall(Budget.Summary)
  return ok and s.strength or "covered"
end

function Budget.NeedsCash() return Budget.Strength() ~= "covered" end
function Budget.CashMargin() return MARGIN[Budget.Strength()] or 1 end

-- Costs by band of ten levels from the current level to 60. Materials are what the seed path would cost if
-- everything were bought (gathered materials make it cheaper); materialsPriced is the share with a known price.
function Budget.Timeline(rec)
  local level = rec.level or 1
  local expenses = Budget.Expenses(rec)
  local bands = {}
  local from = level
  while from < 60 do
    local to = math.min(60, (math.floor(from / 10) + 1) * 10)
    local b = { from = from, to = to, class = 0, ranks = 0, riding = 0, materials = 0, materialsPriced = 1 }
    for _, e in ipairs(expenses) do
      local inBand = (e.level > from or (from == level and e.level <= level)) and e.level <= to
      if inBand and e.copper then
        if e.kind == "class" then b.class = b.class + e.copper
        elseif e.kind == "rank" then b.ranks = b.ranks + e.copper
        elseif e.kind == "riding" then b.riding = b.riding + e.copper end
      end
    end
    local priced, steps = 0, 0
    for skillLine, p in pairs(rec.professions or {}) do
      local profile = not p.former and ns.Professions:BySkillLine(skillLine)
      if profile and profile.category ~= "gathering" then
        local startSkill = math.max(p.rank or 0, from == level and 0 or capAtLevel(profile, from))
        local endSkill = capAtLevel(profile, to)
        if endSkill > startSkill then
          local cost, coverage = ns.Professions.SeedCost(profile, startSkill, endSkill, ns.Price.Copper)
          b.materials = b.materials + cost
          priced, steps = priced + coverage, steps + 1
        end
      end
    end
    b.materialsPriced = steps > 0 and priced / steps or 1
    b.total = b.class + b.ranks + b.riding + b.materials
    bands[#bands + 1] = b
    from = to
  end
  return bands
end

-- Own data ---------------------------------------------------------------------------------------------

local function recordMoney()
  local rec = ns.Chars.Current()
  if not (rec and GetMoney) then return end
  local m = GetMoney()
  if ns.Secret.IsSecret(m) then return end
  rec.money, rec.moneyWhen = m, time()
  if IsSpellKnown and not rec.ridingKnown then
    local ok, known = pcall(IsSpellKnown, RIDING_SPELL)
    if ok and known == true then rec.ridingKnown = true end
  end
  Budget.Invalidate()
end
Budget.RecordMoney = recordMoney

-- A class or pet trainer of the own character: not a profession trainer, and at least three services with a level
-- requirement (profession trainers list recipes at level 0; a riding trainer teaches one or two things).
-- GetTrainerServiceInfo returns name, type ("available" | "unavailable" | "used" | "header"), icon on Forever.
-- Trainers of one group (two class trainers in different cities) share service names; the newest visit replaces the
-- older lists of its group, so learned skills drop out and nothing counts twice. Pet trainers form their own group.
function Budget.ReadClassTrainer()
  if not (GetNumTrainerServices and GetTrainerServiceInfo and GetTrainerServiceCost and GetTrainerServiceLevelReq) then return nil end
  if IsTradeskillTrainer and IsTradeskillTrainer() then return nil end
  local found, names, n = {}, {}, GetNumTrainerServices() or 0
  for i = 1, n do
    local name, kind = GetTrainerServiceInfo(i)
    if type(name) == "string" and not ns.Secret.Any(name, kind) and kind ~= "header" and kind ~= "used" then
      local cost = ns.Learn.FirstNumber(pcall(GetTrainerServiceCost, i))
      local levelReq = ns.Learn.FirstNumber(pcall(GetTrainerServiceLevelReq, i))
      if levelReq and levelReq > 1 then
        found[#found + 1] = { name = name, levelReq = levelReq, cost = cost, available = kind == "available" }
        names[name] = true
      end
    end
  end
  if #found < 3 then return nil end
  local rec = ns.Chars.Current()
  if not rec then return nil end
  local npc = (UnitName and UnitName("npc")) or "?"
  if ns.Secret.IsSecret(npc) then npc = "?" end
  rec.classTraining = rec.classTraining or {}
  rec.classTraining.byTrainer = rec.classTraining.byTrainer or {}
  for other, visit in pairs(rec.classTraining.byTrainer) do
    for _, s in ipairs(visit.services or {}) do
      if names[s.name] then rec.classTraining.byTrainer[other] = nil; break end
    end
  end
  rec.classTraining.byTrainer[npc] = { when = time(), services = found }
  Budget.Invalidate()
  if ns.Checks then ns.Checks.Pass("classTrainer", ("%d services"):format(#found)) end
  return rec.classTraining
end

local function moneyStep(add)
  local s = Budget.Summary()
  local top = ns.Earn and ns.Earn.List()[1]
  local missing = s.nowGap > 0 and s.nowGap or s.gap
  add({ id = "budget", icon = "Interface\\Icons\\INV_Misc_Coin_02", category = L["Gold"], value = -missing,
    title = s.nowGap > 0 and (L["%s missing for what is due now"]):format(ns.Util.Money(s.nowGap)) or (L["%s gold missing"]):format(ns.Util.Money(s.gap)),
    detail = top and (L["Best way now: %s"]):format(top.title) or L["Sell what no plan needs; the Gold tab shows how."],
    actionLabel = L["Gold tab"], action = function() ns.UI.Open("gold") end })
end
-- strong support leads the guide; light support comes after the profession steps
ns.Steps.RegisterSource("budgetStrong", 20, function(add) if Budget.Strength() == "strong" then moneyStep(add) end end)
ns.Steps.RegisterSource("budgetLight", 60, function(add) if Budget.Strength() == "light" then moneyStep(add) end end)

ns.Checks.Define("classTrainer", { group = "B", title = "Class trainer costs read", hint = "Open your class trainer once." })

ns:RegisterModule("Budget", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(2, recordMoney) end, "Budget")
    ns.Events:On("PLAYER_MONEY", recordMoney, "Budget")
    ns.Events:On("PLAYER_LEVEL_UP", Budget.Invalidate, "Budget")
    ns.Events:On("SKILL_LINES_CHANGED", Budget.Invalidate, "Budget")
    ns.Events:On("TRAINER_SHOW", function() C_Timer.After(0.4, function() pcall(Budget.ReadClassTrainer) end) end, "Budget")
  end,
  SelfTest = function()
    local s = Budget.Summary()
    return {
      { name = L["Budget"], ok = true, detail = (L["gold %s, due %s, %s"]):format(ns.Util.Money(s.cash), ns.Util.Money(s.due),
        s.gap > 0 and (L["missing %s"]):format(ns.Util.Money(s.gap)) or L["covered"]) },
      { name = L["Gold support"], ok = true, detail = L[Budget.Strength()] },
    }
  end,
})

-- Goldweaver: the guide's step list (docs/08-UX.md 4.7, docs/14-UI-FUEHRUNG.md). Builds an ordered list of concrete
-- next steps for THIS character, RestedXP-style: one current step with one action button, then the next few.
--
-- Public API
--   ns.Steps.Build(limit?) -> { step }       step = { id, icon?, item?, category, title, detail, value, actionLabel, action }
--                                            icon = texture path or fileID; item = itemID (item icon + quality border wins)
--   ns.Dashboard.Recommendations(limit)      compatibility wrapper: { {text, value, action, color} }
-- Extension point: ns.Steps.RegisterSource(name, priority, fn(add, ctx))  ★  add(step) appends a step.
local ADDON, ns = ...
local L = ns.L

local Steps = { sources = {} }
ns.Steps = Steps
local Dashboard = {}
ns.Dashboard = Dashboard

local function itemName(id)
  if ns.UI and ns.UI.ItemName then return ns.UI.ItemName(id) end
  return ns.API.ItemName(id) or (ns.Data.ExpectedName(id) or ("Item " .. tostring(id)))
end

local ICON = {
  roles = "Interface\\Icons\\INV_Misc_GroupNeedMore",
  mail = "Interface\\Icons\\INV_Letter_15",
  disenchant = "Interface\\Icons\\INV_Enchant_Disenchant",
  train = "Interface\\Icons\\INV_Misc_Book_11",
  book = "Interface\\Icons\\INV_Misc_Book_09",
  gather = "Interface\\Icons\\INV_Misc_Herb_07",
  bank = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
}
Steps.ICON = ICON

function Steps.RegisterSource(name, priority, fn)
  Steps.sources[#Steps.sources + 1] = { name = name, priority = priority, fn = fn }
  table.sort(Steps.sources, function(a, b) return a.priority < b.priority end)
end

local function openGuide(skillLine)
  ns.UI.Open("berufe")
  if ns.UI.SelectProfession then ns.UI.SelectProfession(skillLine) end
end

-- 10: setup gaps (roles, books that were never read)
Steps.RegisterSource("setup", 10, function(add, ctx)
  if ns.Chars.Unassigned() > 0 then
    add({ id = "roles", icon = ICON.roles, category = L["Setup"], title = L["Set roles"],
      detail = (L["%d character(s) without a role. Main gathers, processor crafts."]):format(ns.Chars.Unassigned()),
      actionLabel = L["Open Team"], action = function() ns.UI.Open("team") end })
  end
  for _, missing in ipairs(ns.Adapter.MissingBooks(ctx.me)) do
    local p = ctx.me.professions[missing.skillLine]
    add({ id = "book" .. missing.skillLine, icon = p and p.icon or ICON.book, category = L["Setup"],
      title = (L["Read %s"]):format(missing.name or L["Profession"]),
      detail = L["Open it once and Goldweaver knows recipes, colours and materials."],
      actionLabel = L["Load recipes"], action = function() ns.Adapter.Open(missing.skillLine) end })
  end
end)

-- 20: mail for gatherers
Steps.RegisterSource("mail", 20, function(add, ctx)
  if ctx.me.role ~= "main" then return end
  local count, value, target = ns.Mail.Pending()
  if count > 0 and target then
    add({ id = "mail", icon = ICON.mail, category = L["Mail"], value = value,
      title = (L["Send %d item(s) to %s"]):format(count, target.firstName or target.name),
      detail = L["At the next mailbox: 'Attach', then 'Send'."], })
  end
end)

-- 30: disenchant queue for enchanters
Steps.RegisterSource("disenchant", 30, function(add)
  if not (ns.Destroy and ns.Destroy.CanDisenchant()) then return end
  local queue = ns.Destroy.Queue()
  if #queue == 0 then return end
  local gain = 0
  for _, q in ipairs(queue) do gain = gain + q.gain end
  add({ id = "disenchant", icon = ICON.disenchant, category = L["Process"], value = gain,
    title = (L["Disenchant %d item(s)"]):format(#queue),
    detail = (L["Yields ≈ %s more than selling."]):format(ns.Util.Money(gain)),
    actionLabel = L["Disenchant"], action = function() ns.Destroy.Show() end })
end)

-- 40: per profession: train the next rank, buy missing reagents, craft the next skill-up
Steps.RegisterSource("professions", 40, function(add, ctx)
  for skillLine, p in pairs(ctx.me.professions or {}) do
    if not p.former and ns.Adapter.Book(skillLine) then
      local plan = ns.Planner.Plan(skillLine, ctx.me)
      local rank = plan.rank
      if rank and rank.next and rank.canTrain then
        local npc, contact = ns.Learn.TrainerContact(skillLine, rank.next.reqSkill)
        add({ id = "train" .. skillLine, icon = ICON.train, category = p.name or L["Profession"],
          title = (L["Learn %s: %s"]):format(L[rank.next.name], p.name or "?"),
          detail = rank.trainer and (L["At %s"]):format(rank.trainer) or L["At the profession trainer in the capital."],
          actionLabel = contact and contact.x and L["Waypoint"] or nil,
          action = contact and contact.x and function() ns.Field.SetWaypoint(contact.mapID, contact.x, contact.y, npc) end or nil })
      end
      if plan.best and not (rank and rank.capped) then
        local missing, missingCost, firstMissing = 0, 0, nil
        for _, s in ipairs(plan.shopping or {}) do
          if s.buy > 0 then missing = missing + s.buy; missingCost = missingCost + (s.cost or 0); firstMissing = firstMissing or s end
        end
        local r = plan.best.recipe
        if firstMissing then
          add({ id = "buy" .. skillLine, item = firstMissing.item, category = p.name or L["Profession"], value = -missingCost,
            title = (L["Get %d× %s"]):format(firstMissing.buy, itemName(firstMissing.item)),
            detail = (L["For %s ×%d. At the AH or a vendor."]):format(r.name, plan.crafts or 1),
            actionLabel = L["Search AH"],
            action = function()
              if not ns.Auction.SearchFor(firstMissing.item) then ns.Print(L["Open the auction house, then click again."]) end
            end })
        end
        add({ id = "craft" .. skillLine, icon = r.icon, item = r.outputItemID, category = p.name or L["Profession"],
          title = (L["Craft %s ×%d"]):format(r.name, plan.crafts or 1),
          detail = (L["%s %d » %d · ≈ %s per point"]):format(p.name or "", p.rank or 0, math.min(p.maxRank or 0, (p.rank or 0) + (plan.crafts or 1)), ns.Util.Money(plan.best.costPerPoint)),
          actionLabel = L["Open recipe"], action = function()
            -- lands on this recipe in the profession window; our Professions tab only if the game refuses
            if not ns.Adapter.Open(skillLine, r.id) then openGuide(skillLine) end
          end })
      elseif rank and rank.capped and rank.next and not rank.canTrain then
        add({ id = "cap" .. skillLine, icon = p.icon or ICON.train, category = p.name or L["Profession"],
          title = (L["%s at its cap (%d)"]):format(p.name or "?", p.rank or 0),
          detail = (L["Next rank %s from level %d."]):format(L[rank.next.name], rank.next.reqLevel) })
      end
    end
  end
end)

-- 50: gather here (current zone) what the team needs or what levels a gathering skill
Steps.RegisterSource("gather", 50, function(add)
  local ok, report = pcall(ns.Field.Analyze)
  if not ok or not report then return end
  for _, row in ipairs(report.gather) do
    if row.demand or (row.hasProfession and (row.color == "orange" or row.color == "yellow")) then
      local who = row.demand and next(row.demand.by) or nil
      add({ id = "gather", item = row.item, category = (L["On the road · %s"]):format(report.name), value = row.price,
        title = (L["Gather %s"]):format(itemName(row.item)),
        detail = row.demand and (L["%s needs %d"]):format(who or L["Team"], row.demand.qty) or (L["Skill-up chance %d %%"]):format(math.floor(row.chance * 100)),
        actionLabel = L["On the road"], action = function() ns.UI.Open("field") end })
      return
    end
  end
end)

-- 60: best profit craft
Steps.RegisterSource("profit", 60, function(add)
  local top = ns.CraftProfit.Top(1)[1]
  if top and top.margin > 0 then
    add({ id = "profit", icon = top.recipe.icon, item = top.recipe.outputItemID, category = L["Gold"], value = top.margin,
      title = (L["Craft and sell %s"]):format(top.recipe.name),
      detail = (L["+%s each after AH cut (%s)"]):format(ns.Util.Money(top.margin), L[top.professionName or ""]),
      actionLabel = L["To profession"], action = function() openGuide(top.skillLine) end })
  end
end)

function Steps.Build(limit)
  local me = ns.Chars.Current()
  if not me then return {} end
  local out, seen = {}, {}
  local ctx = { me = me }
  local function add(step)
    if step.id and seen[step.id] then return end
    if step.id then seen[step.id] = true end
    out[#out + 1] = step
  end
  for _, src in ipairs(Steps.sources) do
    local ok, err = pcall(src.fn, add, ctx)
    if not ok then ns.Health.Record("steps " .. src.name, err) end
  end
  if limit then while #out > limit do table.remove(out) end end
  return out
end

-- Compatibility for callers of the first version.
function Dashboard.Recommendations(limit)
  local out = {}
  for _, s in ipairs(Steps.Build(limit)) do
    out[#out + 1] = { text = s.title .. (s.detail and (" – " .. s.detail) or ""), value = s.value, action = s.action, color = { 1, 1, 1 } }
  end
  return out
end

ns:RegisterModule("Dashboard", {
  SelfTest = function()
    local steps = Steps.Build(6)
    return { { name = "Guide steps", ok = true, detail = #steps .. " step(s): " .. (steps[1] and steps[1].title or "-") } }
  end,
})

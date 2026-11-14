-- Goldweaver: level gates. A profession rank needs a character level (Journeyman 10, Expert 20, Artisan 35 for
-- crafting; Expert 10, Artisan 25 for gathering; what a trainer showed wins). This module finds every gate the team
-- will hit, early: "Grel needs level 10 for Journeyman Tailoring, 4 levels to go; Tailoring stops at 75 until then".
--
-- Public API (ns.Gates)
--   List(market?) -> { gate }   all characters of the market, most urgent first
--   For(rec) -> { gate }        one character
--   gate = { rec, skillLine, profession, rank, reqLevel, needLevel, skill, cap, pointsLeft, severity }
--     severity: "blocked" (at the cap, cannot train), "soon" (POINTS_SOON or fewer points to the cap), "later"
-- Steps: a guide step for this character's own gates, and one per blocked gate of a team member.
local ADDON, ns = ...
local L = ns.L

local Gates = {}
ns.Gates = Gates

local POINTS_SOON = 15
local ORDER = { blocked = 1, soon = 2, later = 3 }

function Gates.For(rec)
  local out = {}
  for skillLine, p in pairs(rec and rec.professions or {}) do
    if not p.former then
      local info = ns.Planner.NextRank(skillLine, rec)
      if info and info.next and (info.needLevel or 0) > 0 then
        local pointsLeft = math.max(0, (info.maxSkill or 0) - (info.skill or 0))
        local severity = info.capped and "blocked" or (pointsLeft <= POINTS_SOON and "soon" or "later")
        out[#out + 1] = {
          rec = rec, skillLine = skillLine, profession = p.name or "?", rank = info.next.name,
          reqLevel = info.reqLevel, needLevel = info.needLevel, skill = info.skill, cap = info.maxSkill,
          pointsLeft = pointsLeft, severity = severity,
        }
      end
    end
  end
  table.sort(out, function(a, b)
    if ORDER[a.severity] ~= ORDER[b.severity] then return ORDER[a.severity] < ORDER[b.severity] end
    return a.pointsLeft < b.pointsLeft
  end)
  return out
end

function Gates.List(market)
  market = market or ns.Chars.MarketKey()
  local out = {}
  for _, rec in ipairs(ns.Chars.All(market)) do
    if rec.role ~= "none" then
      for _, g in ipairs(Gates.For(rec)) do out[#out + 1] = g end
    end
  end
  table.sort(out, function(a, b)
    if ORDER[a.severity] ~= ORDER[b.severity] then return ORDER[a.severity] < ORDER[b.severity] end
    return a.pointsLeft < b.pointsLeft
  end)
  return out
end

-- One line for lists and steps: "Journeyman Tailoring from level 10 · 4 levels to go".
function Gates.Title(g)
  return (L["%s %s from level %d"]):format(L[g.rank], g.profession, g.reqLevel)
end

-- What the character can collect for this profession on the way to the gate: profile text plus the cloth or leather
-- of its current level (Data.Gathering), or nil.
function Gates.WhileLevelling(g)
  local profile = ns.Professions:BySkillLine(g.skillLine)
  local hint = profile and profile.levelling
  if not hint then return nil end
  local level = g.rec.level or 1
  local G = ns.Data.Gathering
  local item = hint.drops == "cloth" and G.ClothFor(level) or (hint.drops == "leather" and G.LeatherFor(level)) or nil
  local name = item and ((ns.UI and ns.UI.ItemName) and ns.UI.ItemName(item) or ns.API.ItemName(item) or ns.Data.ExpectedName(item) or tostring(item))
  if name then return ("%s (%s)"):format(L[hint.text], name) end
  return L[hint.text]
end

function Gates.Detail(g)
  if g.severity == "blocked" then
    return (L["%s stops at %d until level %d (%d levels to go). Gather or quest to level up; materials for later can wait."]):format(g.profession, g.cap, g.reqLevel, g.needLevel)
  end
  return (L["%d levels to go; %s stops at %d (%d points left)."]):format(g.needLevel, g.profession, g.cap, g.pointsLeft)
end

ns.Steps.RegisterSource("gates", 45, function(add, ctx)
  for _, g in ipairs(Gates.For(ctx.me)) do
    if g.severity ~= "later" then
      add({ id = "gate" .. g.skillLine, icon = ns.Steps.ICON.train, category = g.profession,
        title = (L["Reach level %d"]):format(g.reqLevel), detail = Gates.WhileLevelling(g) or Gates.Detail(g) })
    end
  end
  -- team members who are stuck: the gatherer should know why the crafter's list stops growing
  for _, g in ipairs(Gates.List()) do
    if g.rec ~= ctx.me and g.severity == "blocked" then
      local who = g.rec.firstName or g.rec.name
      add({ id = "gateTeam" .. g.skillLine .. who, icon = ns.Steps.ICON.roles, category = L["Team"],
        title = (L["%s needs level %d"]):format(who, g.reqLevel),
        detail = (L["%s stops at %d until then (%d levels to go). Play %s a little."]):format(g.profession, g.cap, g.needLevel, who) })
    end
  end
end)

ns:RegisterModule("Gates", {
  SelfTest = function()
    local list = Gates.List()
    return { { name = L["Level gates"], ok = true, detail = #list > 0 and Gates.Title(list[1]) or L["none ahead"] } }
  end,
})

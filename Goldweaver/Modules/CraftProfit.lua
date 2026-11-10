-- Goldweaver: craft profit. (1) Ranking across all cached professions of this character (feeds the guide).
-- (2) Profit tag on every recipe row of Blizzard's profession window (B24): green "+12s" or red "-3s" after the AH
-- cut, so the ranking is visible without opening Goldweaver. Skipped when the CraftProfit addon already tags rows.
--
-- Public API (ns.CraftProfit)
--   Top(limit) -> { { recipe, margin, skillLine, professionName } }
--   Of(recipe) -> copper (profit per craft after the cut) | nil when a price is missing
local ADDON, ns = ...

local CraftProfit = {}
ns.CraftProfit = CraftProfit

-- Best crafts of this character across professions: { recipe, margin, skillLine, professionName }
function CraftProfit.Top(limit)
  local rec = ns.Chars.Current()
  local out = {}
  if not (rec and rec.professions) then return out end
  for skillLine, p in pairs(rec.professions) do
    for _, entry in ipairs(ns.Planner.Profitable(skillLine, rec, limit)) do
      entry.skillLine = skillLine
      entry.professionName = p.name
      out[#out + 1] = entry
    end
  end
  table.sort(out, function(a, b) return a.margin > b.margin end)
  while #out > (limit or 5) do table.remove(out) end
  return out
end

function CraftProfit.Of(recipe)
  if not (recipe and recipe.outputItemID) then return nil end
  local ok, cost, coverage = pcall(ns.Planner.CraftCost, recipe)
  local unit = ns.Price.Copper(recipe.outputItemID)
  if not (ok and cost and unit) or (coverage and coverage < 1) then return nil end
  local qty = ((recipe.qtyMin or 1) + (recipe.qtyMax or 1)) / 2
  return math.floor(unit * qty * (1 - (ns.db.settings.ahCut or 0.05)) - cost)
end

-- Row tags ----------------------------------------------------------------------------------------
local tagged = false

local function recipeByID(id)
  for _, book in pairs(ns.db.recipes or {}) do
    local r = book.byID and book.byID[id]
    if r then return r end
  end
  return nil
end

-- Short money: "+1g20", "+35s", "-8c"
local function short(copper)
  local sign = copper < 0 and "-" or "+"
  local c = math.abs(copper)
  if c >= 10000 then return ("%s%dg%02d"):format(sign, math.floor(c / 10000), math.floor((c % 10000) / 100)) end
  if c >= 100 then return ("%s%ds"):format(sign, math.floor(c / 100)) end
  return ("%s%dc"):format(sign, c)
end

local function tagRow(frame, elementData)
  local data = elementData and elementData.GetData and elementData:GetData()
  local info = data and data.recipeInfo
  if not frame.gwProfit then
    frame.gwProfit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.gwProfit:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
  end
  local recipe = info and info.recipeID and not ns.Secret.IsSecret(info.recipeID) and recipeByID(info.recipeID)
  local profit = recipe and CraftProfit.Of(recipe)
  if profit then
    frame.gwProfit:SetText(short(profit))
    if profit >= 0 then frame.gwProfit:SetTextColor(0.4, 1, 0.4) else frame.gwProfit:SetTextColor(1, 0.45, 0.35) end
  else
    frame.gwProfit:SetText("")
  end
end

local function otherTagger()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
  return loaded and (loaded("CraftProfit") or loaded("ForeverRecipes")) or false
end

local function hookRows()
  if tagged or otherTagger() then return end
  local list = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList
  local box = list and list.ScrollBox
  if not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then return end
  local ok = pcall(ScrollUtil.AddInitializedFrameCallback, box, function(_, frame, elementData) pcall(tagRow, frame, elementData) end, CraftProfit)
  tagged = ok
  if ok and ns.Checks then ns.Checks.Pass("profitTags", "recipe list tagged") end
end

ns:RegisterModule("CraftProfit", {
  Init = function()
    ns.Events:On("TRADE_SKILL_SHOW", function() C_Timer.After(0.3, function() pcall(hookRows) end) end, "CraftProfit")
  end,
  SelfTest = function()
    return { { name = ns.L["Profit tags in the profession window"], ok = true, warn = not tagged,
      detail = tagged and ns.L["active"] or (otherTagger() and ns.L["another addon shows profit"] or ns.L["only after opening a profession"]) } }
  end,
})

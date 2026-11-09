-- Goldweaver: profession window adapter. Forever 1.60.1 exposes only C_TradeSkillUI (verified 08.11.2026).
-- Whenever a profession window loads its recipe list, the adapter normalises every recipe into
-- GoldweaverDB.recipes[skillLine] (account-wide, recipes are the same for everyone) and records this character's
-- learned set and skill in GoldweaverDB.chars[name].professions[skillLine]. Live craft conversions go into ns.Graph.
--
-- Normalised recipe: { id, name, icon, outputItemID, qtyMin, qtyMax, reagents = {{item, qty}}, difficulty (0 optimal,
--   1 medium, 2 easy, 3 trivial, or nil when unknown), learned (per character, see chars), sourceType, numSkillUps }
local ADDON, ns = ...
local L = ns.L

local Adapter = { current = nil }
ns.Adapter = Adapter

local DIFFICULTY_NAMES = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }
Adapter.DIFFICULTY_NAMES = DIFFICULTY_NAMES
-- Approximate skill-up chance per difficulty (Classic rule of thumb; calibrated later from own craft logs, F11).
Adapter.SKILLUP_CHANCE = { [0] = 1.0, [1] = 0.75, [2] = 0.35, [3] = 0 }

-- Skill-up chance: observed rate when enough own crafts exist (Learn, F11), else the rule of thumb.
function Adapter.ChanceFor(difficulty)
  if difficulty == nil then return nil end
  if ns.Learn and ns.Learn.SkillupChance then
    local observed = ns.Learn.SkillupChance(difficulty)
    if observed then return observed end
  end
  return Adapter.SKILLUP_CHANCE[difficulty]
end

local function difficultyOf(info)
  local d = info.relativeDifficulty
  if d == nil then d = info.difficulty end
  if type(d) == "table" then d = d.value end
  if type(d) == "string" then
    local map = { optimal = 0, medium = 1, easy = 2, trivial = 3 }
    d = map[d:lower()]
  end
  return tonumber(d)
end

local function readSchematic(recipeID)
  if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return nil end
  local ok, schem = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
  if not ok or type(schem) ~= "table" then return nil end
  local reagents = {}
  for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
    local first = slot.reagents and slot.reagents[1]
    local itemID = first and first.itemID
    local qty = slot.quantityRequired or 1
    -- only basic/required reagents count (Mainline: Enum.CraftingReagentType.Basic); Forever recipes have no optional slots
    local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
    if itemID and (slot.reagentType == nil or slot.reagentType == basic) then
      reagents[#reagents + 1] = { item = itemID, qty = qty }
    end
  end
  return {
    outputItemID = schem.outputItemID, qtyMin = schem.quantityMin or 1, qtyMax = schem.quantityMax or schem.quantityMin or 1,
    reagents = reagents, icon = schem.icon, name = schem.name,
  }
end

-- Reads the open profession. Returns skillLine, professionName or nil when nothing is open.
function Adapter.Read()
  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then return nil end
  local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
  if type(base) ~= "table" then return nil end
  local skillLine = base.professionID or base.skillLineID
  if not skillLine or skillLine == 0 or ns.Secret.Any(skillLine, base.skillLevel, base.maxSkillLevel, base.professionName) then return nil end
  local ids = C_TradeSkillUI.GetAllRecipeIDs() or {}
  if #ids == 0 then return nil end

  ns.db.recipes = ns.db.recipes or {}
  local book = ns.db.recipes[skillLine] or { list = {}, byID = {} }
  book.name = base.professionName
  book.skillLine = skillLine
  book.when = time()
  book.list, book.byID = {}, {}

  local learnedSet, learnedCount = {}, 0
  local fieldsRecorded = false
  for _, recipeID in ipairs(ids) do
    local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
    if okInfo and type(info) == "table" and info.name and not ns.Secret.Any(info.name, info.learned) then
      local schem = readSchematic(recipeID)
      if not fieldsRecorded and ns.Learn then
        fieldsRecorded = true
        local okS, rawSchem = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
        pcall(ns.Learn.RecipeFields, info, okS and rawSchem or nil)
      end
      local rec = {
        id = recipeID, name = info.name, icon = info.icon or (schem and schem.icon),
        outputItemID = schem and schem.outputItemID, qtyMin = schem and schem.qtyMin or 1, qtyMax = schem and schem.qtyMax or 1,
        reagents = schem and schem.reagents or {},
        difficulty = difficultyOf(info), numSkillUps = info.numSkillUps,
        -- Forever 1.60.1 RecipeInfo (verified 08.11.2026): no sourceType; maxTrivialLevel = skill at which the recipe
        -- turns grey, canSkillUp = still gives points at the current skill
        maxTrivialLevel = info.maxTrivialLevel, canSkillUp = info.canSkillUp,
        craftable = info.craftable, disabled = info.disabled, hyperlink = info.hyperlink,
        isEnchant = info.isEnchantingRecipe or (schem and schem.outputItemID == nil) or false,
        isSalvage = info.isSalvageRecipe or false, isGathering = info.isGatheringRecipe or false,
      }
      book.list[#book.list + 1] = rec
      book.byID[recipeID] = rec
      if info.learned then learnedSet[recipeID] = true; learnedCount = learnedCount + 1 end
      -- live conversion for the graph (crafts with an item output only)
      if info.learned and rec.outputItemID and #rec.reagents > 0 then
        local inputs = {}
        for _, r in ipairs(rec.reagents) do inputs[#inputs + 1] = { item = r.item, qty = r.qty } end
        local profile = ns.Professions:BySkillLine(skillLine)
        ns.Graph.Add({
          id = "craft:" .. rec.outputItemID, kind = "craft", profession = profile and profile.key or tostring(skillLine),
          source = "live", recipeID = recipeID, name = rec.name,
          inputs = inputs, outputs = { { item = rec.outputItemID, qty = (rec.qtyMin + rec.qtyMax) / 2, prob = 1 } },
        })
      end
    end
  end
  table.sort(book.list, function(a, b) return a.name < b.name end)
  ns.db.recipes[skillLine] = book

  local me = ns.Chars.Current()
  if me then
    me.professions = me.professions or {}
    local p = me.professions[skillLine] or {}
    p.name = base.professionName
    p.rank = base.skillLevel
    p.maxRank = base.maxSkillLevel
    p.learned = learnedSet
    p.learnedCount = learnedCount
    p.recipeCount = #book.list
    p.when = time()
    me.professions[skillLine] = p
  end
  Adapter.current = skillLine
  Adapter.lastSkill = base.skillLevel
  ns.Log("adapter read", base.professionName, #book.list, "recipes,", learnedCount, "learned")
  if ns.Checks then
    ns.Checks.Pass("book", ("%s: %d Rezepte, %d gelernt"):format(tostring(base.professionName), #book.list, learnedCount))
    if ns.Planner then
      local okPlan, plan = pcall(ns.Planner.Plan, skillLine, me)
      if okPlan and plan and plan.best then ns.Checks.Pass("plan", ("%s ×%d"):format(plan.best.recipe.name, plan.crafts or 1)) end
    end
  end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
  if ns.Destroy and ns.Destroy.Refresh then ns.Destroy.Refresh() end
  return skillLine, base.professionName
end

function Adapter.Book(skillLine)
  return ns.db.recipes and ns.db.recipes[skillLine] or nil
end

-- Recipes this character knows for a skill line (from the cached learned set).
function Adapter.Learned(skillLine, rec)
  rec = rec or ns.Chars.Current()
  local book = Adapter.Book(skillLine)
  local p = rec and rec.professions and rec.professions[skillLine]
  local out = {}
  if not (book and p and p.learned) then return out end
  for _, r in ipairs(book.list) do if p.learned[r.id] then out[#out + 1] = r end end
  return out
end

function Adapter.Unlearned(skillLine, rec)
  rec = rec or ns.Chars.Current()
  local book = Adapter.Book(skillLine)
  local p = rec and rec.professions and rec.professions[skillLine]
  local out = {}
  if not book then return out end
  for _, r in ipairs(book.list) do if not (p and p.learned and p.learned[r.id]) then out[#out + 1] = r end end
  return out
end

function Adapter.IsOpen()
  return C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() or false
end

-- Opens a profession window from a click handler so the book can be read without hunting for the spellbook.
-- Returns true when the request was sent; the TRADE_SKILL_LIST_UPDATE handler then reads the recipes.
function Adapter.Open(skillLine)
  if not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then return false, L["OpenTradeSkill missing"] end
  local ok, err = pcall(C_TradeSkillUI.OpenTradeSkill, skillLine)
  return ok, err
end

-- Skill lines of this character that have no cached book yet (crafting/secondary only; gathering has no recipes to plan).
local NO_RECIPES = { [182] = true, [393] = true, [356] = true } -- herbalism, skinning, fishing
function Adapter.MissingBooks(rec)
  rec = rec or ns.Chars.Current()
  local out = {}
  for skillLine, p in pairs(rec and rec.professions or {}) do
    -- no book yet, or a book but this character's learned recipes were never recorded
    if not p.former and not NO_RECIPES[skillLine] and (not Adapter.Book(skillLine) or not p.learned) then out[#out + 1] = { skillLine = skillLine, name = p.name } end
  end
  table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
  return out
end

-- Crafts a recipe `count` times. Must be called from a click handler while the profession window is open.
function Adapter.Craft(recipeID, count)
  if not (C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) then return false, L["CraftRecipe missing"] end
  if not Adapter.IsOpen() then return false, L["Profession window is not open"] end
  local ok, err = pcall(C_TradeSkillUI.CraftRecipe, recipeID, count or 1)
  return ok, err
end

-- Rebuilds live craft conversions from the cached books so the Advisor knows what ANY character on this market can
-- craft, even when that character is not logged in. Called once after login.
function Adapter.RebuildGraph()
  if not ns.db.recipes then return 0 end
  local market = ns.Chars.MarketKey()
  local added = 0
  for skillLine, book in pairs(ns.db.recipes) do
    local profile = ns.Professions:BySkillLine(skillLine)
    local learnedAnywhere = {}
    for _, rec in pairs(ns.db.chars) do
      local p = rec.market == market and rec.professions and rec.professions[skillLine]
      if p and p.learned then for id in pairs(p.learned) do learnedAnywhere[id] = true end end
    end
    for _, r in ipairs(book.list or {}) do
      if learnedAnywhere[r.id] and r.outputItemID and #(r.reagents or {}) > 0 then
        local inputs = {}
        for _, rg in ipairs(r.reagents) do inputs[#inputs + 1] = { item = rg.item, qty = rg.qty } end
        ns.Graph.Add({
          id = "craft:" .. r.outputItemID, kind = "craft", profession = profile and profile.key or tostring(skillLine),
          skillLine = skillLine, source = "live", recipeID = r.id, name = r.name,
          inputs = inputs, outputs = { { item = r.outputItemID, qty = (r.qtyMin + r.qtyMax) / 2, prob = 1 } },
        })
        added = added + 1
      end
    end
  end
  return added
end

ns:RegisterModule("Adapter", {
  SelfTest = function()
    local results = {}
    local books = 0
    for sl, book in pairs(ns.db.recipes or {}) do
      books = books + 1
      results[#results + 1] = { name = (L["Recipe book %s"]):format(tostring(book.name)), ok = #(book.list or {}) > 0,
        detail = L["%d recipes, line %s, read %d s ago"]:format(#(book.list or {}), tostring(sl), time() - (book.when or time())) }
    end
    if books == 0 then results[#results + 1] = { name = L["Recipe books"], ok = false, warn = true, detail = L["none yet (open a profession window)"] } end
    results[#results + 1] = { name = L["Profession window open"], ok = Adapter.IsOpen(), warn = true, detail = Adapter.current and ((L["skill line %s"]):format(Adapter.current)) or L["no"] }
    results[#results + 1] = { name = L["Legacy profession API"], ok = GetTradeSkillInfo == nil, detail = GetTradeSkillInfo and L["present (unexpected)"] or L["absent as expected"] }
    return results
  end,
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(2, function() pcall(Adapter.RebuildGraph) end) end)
    local pending = false
    local function schedule()
      if pending then return end
      pending = true
      C_Timer.After(0.3, function() pending = false; pcall(Adapter.Read) end)
    end
    ns.Events:On("TRADE_SKILL_LIST_UPDATE", schedule, "Adapter")
    ns.Events:On("TRADE_SKILL_SHOW", schedule, "Adapter")
    ns.Events:On("TRADE_SKILL_DATA_SOURCE_CHANGED", schedule, "Adapter")
    ns.Events:On("NEW_RECIPE_LEARNED", schedule, "Adapter")
    ns.Events:On("TRADE_SKILL_CLOSE", function() Adapter.current = nil end, "Adapter")
    -- F11: count crafts (recipe IDs are spell IDs) and attribute skill-ups to the last craft's colour
    ns.Events:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
      if unit ~= "player" or not Adapter.current or not ns.Learn then return end
      local book = Adapter.Book(Adapter.current)
      local r = book and book.byID and book.byID[spellID]
      if r and r.difficulty then
        ns.Learn.Craft(r.difficulty, Adapter.lastSkill)
        C_Timer.After(0.5, function()
          local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
          local now = type(base) == "table" and base.skillLevel or nil
          if now and not ns.Secret.IsSecret(now) then
            ns.Learn.SkillChanged(now)
            Adapter.lastSkill = now
          end
        end)
      end
    end, "Adapter")
  end,
})

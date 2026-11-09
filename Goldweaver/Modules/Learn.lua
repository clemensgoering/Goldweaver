-- Goldweaver: learns the open questions from gameplay instead of manual probing, evaluates them and feeds the
-- results back into the calculations. Everything lives in GoldweaverDB.learned.
--   deposit   (F6)  samples from the sell frame -> flat amount or rate, applied to the Advisor
--   crates    (F7)  tooltip lines of Waylaid Crates -> bundle sizes and favor, applied to Data.Crates when parsed
--   mail      (F10) which recipient format the server accepts -> used by Chars.MailName
--   skillups  (F11) crafts and skill-ups per recipe colour -> replaces the rule-of-thumb chances
--   recipes         which fields GetRecipeInfo has (sourceType etc.) and the enum behind them
--   trainers        services, skill/level requirements and costs read at profession trainers
local ADDON, ns = ...

local Learn = {}
ns.Learn = Learn

local function L()
  ns.db.learned = ns.db.learned or {}
  return ns.db.learned
end

-- F6 deposit --------------------------------------------------------------------------------------
function Learn.DepositSample(itemID, quantity, vendorSell, deposits)
  if not (vendorSell and deposits and deposits[1]) then return end
  local l = L()
  l.deposit = l.deposit or { samples = {} }
  l.deposit.samples[#l.deposit.samples + 1] = { item = itemID, qty = quantity, vendor = vendorSell, d = deposits, t = time() }
  while #l.deposit.samples > 30 do table.remove(l.deposit.samples, 1) end
  Learn.EvaluateDeposit()
end

function Learn.EvaluateDeposit()
  local l = L()
  local s = l.deposit and l.deposit.samples or {}
  if #s < 1 then return end
  local allFlat, flatValue = true, s[1].d[1]
  local rates = { 0, 0, 0 }
  local rateSamples = 0
  for _, smp in ipairs(s) do
    for d = 1, 3 do if smp.d[d] ~= flatValue then allFlat = false end end
    if smp.vendor > 0 and smp.qty > 0 then
      rateSamples = rateSamples + 1
      for d = 1, 3 do rates[d] = rates[d] + (smp.d[d] or 0) / (smp.vendor * smp.qty) end
    end
  end
  if allFlat then
    l.deposit.model = "flat"; l.deposit.flat = flatValue
    ns.db.settings.depositFlat = flatValue
  elseif rateSamples > 0 then
    for d = 1, 3 do rates[d] = rates[d] / rateSamples end
    l.deposit.model = "rate"; l.deposit.rates = rates
    ns.db.settings.depositFlat = nil
    ns.db.settings.depositRate = rates[2] -- 8 h as the default duration
  end
  l.deposit.samplesCount = #s
  if ns.Checks and #s >= 3 then
    ns.Checks.Pass("f6deposit", l.deposit.model == "flat" and ("pauschal " .. ns.Util.Money(flatValue)) or ("Sätze %.1f/%.1f/%.1f %% des Händlerpreises"):format(rates[1] * 100, rates[2] * 100, rates[3] * 100))
  end
end

-- F7 crates -----------------------------------------------------------------------------------------
-- Called from the tooltip hook with the TooltipData lines of an item. Captures anything that mentions favor.
function Learn.CrateTooltip(itemID, name, lines)
  -- Only real crates: the name or a line must name a crate AND a line must mention favor. (First run matched
  -- "Magiepartikel ... Verfügbar bei Händlern", so the word "Händler" alone is not enough.)
  local text = {}
  local mentionsFavor, mentionsCrate = false, false
  for _, line in ipairs(lines or {}) do
    local left = line.leftText
    if type(left) == "string" and not ns.Secret.IsSecret(left) then
      text[#text + 1] = left
      if left:find("Favor") or left:find("Gunst") then mentionsFavor = true end
      if left:find("Crate") or left:find("Kiste") or left:find("Waylaid") or left:find("Lieferung") or left:find("Bündel") then mentionsCrate = true end
    end
  end
  if not (mentionsFavor and mentionsCrate) then return end
  local l = L()
  l.crates = l.crates or {}
  local entry = { name = name, lines = text, t = time(), bundles = {}, favor = nil }
  for _, left in ipairs(text) do
    local favor = left:match("(%d+)%s*[^%d]*Favor") or left:match("(%d+)%s*[^%d]*Gunst")
    if favor then entry.favor = tonumber(favor) end
    local qty, what = left:match("^%s*(%d+)%s*[x×]?%s+(.+)$")
    if qty and what then entry.bundles[#entry.bundles + 1] = { qty = tonumber(qty), text = what } end
  end
  l.crates[itemID] = entry
  if ns.Checks and (entry.favor or #entry.bundles > 0) then
    ns.Checks.Pass("f7crate", ("%s: %d Bündelzeilen, Favor %s"):format(tostring(name), #entry.bundles, tostring(entry.favor or "?")))
  end
end

-- F10 mail format ------------------------------------------------------------------------------------
-- variant: "full" (Vorname Nachname) or "first" (nur Vorname)
function Learn.MailResult(variant, success)
  local l = L()
  l.mail = l.mail or {}
  l.mail[variant] = success and "ok" or "fail"
  if success then
    l.mail.preferred = variant
    if ns.Checks then ns.Checks.Pass("f10mail", variant == "full" and "Vorname Nachname funktioniert" or "nur Vorname funktioniert"); ns.Checks.Pass("mailSend", variant) end
  elseif l.mail.full == "fail" and l.mail.first == "fail" and ns.Checks then
    ns.Checks.Fail("f10mail", "beide Formate abgelehnt")
  end
end

function Learn.MailVariant()
  local l = L()
  if l.mail and l.mail.preferred then return l.mail.preferred end
  if l.mail and l.mail.full == "fail" then return "first" end
  return "full"
end

-- F11 skill-ups ---------------------------------------------------------------------------------------
function Learn.Craft(difficulty, skillBefore)
  local l = L()
  l.skillups = l.skillups or {}
  local key = tostring(difficulty)
  l.skillups[key] = l.skillups[key] or { crafts = 0, ups = 0 }
  l.skillups[key].crafts = l.skillups[key].crafts + 1
  l.lastCraft = { difficulty = difficulty, skill = skillBefore, t = time() }
end

function Learn.SkillChanged(skillNow)
  local l = L()
  local last = l.lastCraft
  if not last or time() - last.t > 10 then return end
  if skillNow and last.skill and skillNow > last.skill then
    local key = tostring(last.difficulty)
    if l.skillups and l.skillups[key] then l.skillups[key].ups = l.skillups[key].ups + 1 end
    if ns.Checks then ns.Checks.Pass("craft", "Skill-up beobachtet") end
  end
  l.lastCraft = nil
  local total = 0
  for _, v in pairs(l.skillups or {}) do total = total + v.crafts end
  if total >= 15 and ns.Checks then
    local parts = {}
    for k, v in pairs(l.skillups) do parts[#parts + 1] = ("%s: %d/%d"):format(ns.Adapter.DIFFICULTY_NAMES[tonumber(k)] or k, v.ups, v.crafts) end
    ns.Checks.Pass("f11skillup", table.concat(parts, ", "))
  end
end

-- Observed chance for a difficulty when enough samples exist, else nil.
function Learn.SkillupChance(difficulty)
  local l = L()
  local v = l.skillups and l.skillups[tostring(difficulty)]
  if v and v.crafts >= 15 then return v.ups / v.crafts, v.crafts end
  return nil
end

-- recipe fields ------------------------------------------------------------------------------------------
function Learn.RecipeFields(info, schematic)
  local l = L()
  if l.recipeFields then return end
  local keys = {}
  for k in pairs(info or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  local skeys = {}
  for k in pairs(schematic or {}) do skeys[#skeys + 1] = k end
  table.sort(skeys)
  l.recipeFields = { info = keys, schematic = skeys, t = time() }
  -- enums that may explain numeric fields such as sourceType
  l.enums = {}
  if type(Enum) == "table" then
    for name, tbl in pairs(Enum) do
      if type(name) == "string" and type(tbl) == "table" and (name:find("Recipe") or name:find("Tradeskill") or name:find("TradeSkill")) then
        local copy = {}
        for k, v in pairs(tbl) do if type(v) == "number" then copy[k] = v end end
        l.enums[name] = copy
      end
    end
  end
  if ns.Checks then
    local has = {}
    for _, k in ipairs(keys) do if k == "sourceType" or k == "learned" or k == "relativeDifficulty" or k == "difficulty" or k == "numSkillUps" then has[#has + 1] = k end end
    ns.Checks.Pass("recipeFields", ("Felder: %s"):format(table.concat(has, ", ")))
  end
end

-- Name of an enum member for a value, searching enums whose name matches `pattern`.
function Learn.EnumName(value, pattern)
  local l = L()
  for name, tbl in pairs(l.enums or {}) do
    if name:find(pattern) then
      for k, v in pairs(tbl) do if v == value then return k end end
    end
  end
  return nil
end

-- trainers ----------------------------------------------------------------------------------------------
-- Reads the open trainer window. Stores services with skill/level requirements and costs.
function Learn.TrainerServices(npc)
  if not (npc and GetNumTrainerServices and GetTrainerServiceInfo) then return end
  local l = L()
  l.trainers = l.trainers or {}
  local entry = l.trainers[npc] or {}
  entry.services = {}
  entry.t = time()
  local n = GetNumTrainerServices() or 0
  for i = 1, n do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name and category ~= "header" and not ns.Secret.Any(name, rank, category) then
      local skillReq, levelReq, cost
      if GetTrainerServiceSkillReq then local ok, s = pcall(GetTrainerServiceSkillReq, i) if ok then skillReq = tonumber(s) end end
      if GetTrainerServiceLevelReq then local ok, lv = pcall(GetTrainerServiceLevelReq, i) if ok then levelReq = tonumber(lv) end end
      if GetTrainerServiceCost then local ok, c = pcall(GetTrainerServiceCost, i) if ok then cost = tonumber(c) end end
      entry.services[#entry.services + 1] = { name = name, rank = rank, category = category, skillReq = skillReq, levelReq = levelReq, cost = cost }
    end
  end
  -- which profession: match service names against cached recipe books
  local bySkill = {}
  for skillLine, book in pairs(ns.db.recipes or {}) do
    local names = {}
    for _, r in ipairs(book.list or {}) do names[r.name] = true end
    for _, s in ipairs(entry.services) do if names[s.name] then bySkill[skillLine] = (bySkill[skillLine] or 0) + 1 end end
  end
  local bestLine, bestCount = nil, 0
  for sl, c in pairs(bySkill) do if c > bestCount then bestLine, bestCount = sl, c end end
  entry.skillLine = bestLine
  -- rank requirements: services with a skill requirement at the known thresholds and a level requirement
  entry.ranks = {}
  for _, s in ipairs(entry.services) do
    if s.skillReq and s.levelReq and s.levelReq > 0 and (s.skillReq == 50 or s.skillReq == 125 or s.skillReq == 200) then
      entry.ranks[#entry.ranks + 1] = { name = s.name, skillReq = s.skillReq, levelReq = s.levelReq, cost = s.cost }
    end
  end
  l.trainers[npc] = entry
  if ns.Checks then
    if #entry.ranks > 0 then ns.Checks.Pass("trainerRanks", ("%s: %d Rangstufen gelesen"):format(npc, #entry.ranks)) end
    if #entry.services > 0 and bestLine then ns.Checks.Pass("recipeSources", ("%s lehrt %d Rezepte (line %s)"):format(npc, bestCount, tostring(bestLine))) end
  end
  return entry
end

-- Where an unlearned recipe comes from, according to what we have seen: text or nil.
function Learn.RecipeSource(recipe)
  local l = L()
  for npc, t in pairs(l.trainers or {}) do
    for _, s in ipairs(t.services or {}) do
      if s.name == recipe.name then
        local c = ns.db.contacts and ns.db.contacts[npc]
        return ("Lehrer %s%s%s"):format(npc, c and c.zone and (" (" .. c.zone .. ")") or "", s.skillReq and (" ab Skill " .. s.skillReq) or ""), "trainer"
      end
    end
  end
  for itemID, v in pairs(ns.db.vendors or {}) do
    if v.teaches == recipe.id then
      local c = v.npc and ns.db.contacts and ns.db.contacts[v.npc]
      return ("Händler %s%s, %s%s"):format(tostring(v.npc), c and c.zone and (" (" .. c.zone .. ")") or "", ns.Util.Money(v.buy or 0), v.limited and ", limitiert" or ""), "vendor", itemID
    end
  end
  -- Forever's RecipeInfo has no source field (verified 08.11.2026); only own visits can answer this.
  return nil
end

-- Trainer text for the next rank from what we saw, else nil.
function Learn.TrainerFor(skillLine, reqSkill)
  local l = L()
  for npc, t in pairs(l.trainers or {}) do
    if t.skillLine == skillLine then
      for _, r in ipairs(t.ranks or {}) do
        if r.skillReq == reqSkill then
          local c = ns.db.contacts and ns.db.contacts[npc]
          return ("%s%s, %s, ab Level %d"):format(npc, c and c.zone and (" (" .. c.zone .. ")") or "", ns.Util.Money(r.cost or 0), r.levelReq or 0)
        end
      end
    end
  end
  return nil
end

-- Trainer we met who teaches the rank with this skill requirement: npcName, contact {zone, mapID, x, y} or nil.
function Learn.TrainerContact(skillLine, reqSkill)
  local l = L()
  for npc, t in pairs(l.trainers or {}) do
    if t.skillLine == skillLine then
      for _, r in ipairs(t.ranks or {}) do
        if r.skillReq == reqSkill then return npc, ns.db.contacts and ns.db.contacts[npc], r end
      end
    end
  end
  return nil
end

-- Summary rows for the debug report
function Learn.Status()
  local l = L()
  local rows = {}
  local depositText = "keine Proben"
  if l.deposit and l.deposit.model == "flat" then
    depositText = ("pauschal %s aus %d Proben"):format(ns.Util.Money(l.deposit.flat), l.deposit.samplesCount or 0)
  elseif l.deposit and l.deposit.model == "rate" then
    local r = l.deposit.rates
    depositText = ("Sätze %.1f/%.1f/%.1f %% aus %d Proben"):format((r[1] or 0) * 100, (r[2] or 0) * 100, (r[3] or 0) * 100, l.deposit.samplesCount or 0)
  end
  rows[#rows + 1] = { "F6 Einzahlung", depositText }
  local crates = 0
  for _ in pairs(l.crates or {}) do crates = crates + 1 end
  rows[#rows + 1] = { "F7 Kisten", crates > 0 and (crates .. " Kisten-Tooltips erfasst") or "keine" }
  rows[#rows + 1] = { "F10 Post-Format", l.mail and (l.mail.preferred and ("bevorzugt " .. l.mail.preferred) or ("full=" .. tostring(l.mail.full) .. " first=" .. tostring(l.mail.first))) or "noch nicht gesendet" }
  local parts = {}
  for k, v in pairs(l.skillups or {}) do parts[#parts + 1] = ("%s %d/%d"):format(ns.Adapter and ns.Adapter.DIFFICULTY_NAMES[tonumber(k)] or k, v.ups, v.crafts) end
  rows[#rows + 1] = { "F11 Skill-ups", #parts > 0 and table.concat(parts, ", ") or "keine Crafts beobachtet" }
  rows[#rows + 1] = { "Rezeptfelder", l.recipeFields and table.concat(l.recipeFields.info, ",") or "noch kein Berufefenster" }
  local enums = {}
  for name in pairs(l.enums or {}) do enums[#enums + 1] = name end
  table.sort(enums)
  rows[#rows + 1] = { "Enums", #enums > 0 and table.concat(enums, ", ") or "-" }
  local trainers = 0
  for _ in pairs(l.trainers or {}) do trainers = trainers + 1 end
  rows[#rows + 1] = { "Lehrer gelesen", tostring(trainers) }
  return rows
end

ns:RegisterModule("Learn", {
  SelfTest = function()
    local rows = {}
    for _, r in ipairs(Learn.Status()) do rows[#rows + 1] = { name = r[1], ok = true, detail = r[2] } end
    return rows
  end,
})

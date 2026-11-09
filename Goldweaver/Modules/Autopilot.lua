-- Goldweaver: Autopilot - setup and health checks that run for every user without any manual step.
--   1. Roles: guesses main/processor for characters without a role (highest level = main, crafter = processor).
--      A role the player chose (UI or /gw role) is never overridden.
--   2. Profession books: reads every crafting profession once per day in the background by opening it invisibly
--      (alpha 0) out of combat and closing it again. Disables itself for the session if the client blocks it.
--   3. Health: a silent self test 15 s after login; only problems reach the chat, and the minimap badge shows "!".
--
-- Public API (ns.Autopilot)
--   GuessRole(rec, market) -> role | nil
--   QuickHealth() -> { red = n, warn = n, rows = {...} }
--   ReadQueue() -> { skillLine... } books that are missing or older than STALE
--   status = { roles, books, health, blocked }
local ADDON, ns = ...

local Autopilot = { status = {} }
ns.Autopilot = Autopilot

local STALE = 20 * 3600
-- gathering-only professions have no recipe book worth reading
local NO_BOOK = { [182] = true, [393] = true, [356] = true }

-- Roles ------------------------------------------------------------------------------------------
local function isCrafter(rec)
  for skillLine, p in pairs(rec.professions or {}) do
    if not NO_BOOK[skillLine] and skillLine ~= 129 and skillLine ~= 185 and not p.former then return true end
  end
  return false
end

function Autopilot.GuessRole(rec, market)
  if not rec or rec.roleSource == "manual" or (rec.role and rec.role ~= "none") then return nil end
  local others = ns.Chars.All(market)
  local hasMain = #ns.Chars.ByRole("main", market) > 0
  local maxLevel = 0
  for _, o in ipairs(others) do if o ~= rec and (o.level or 0) > maxLevel then maxLevel = o.level or 0 end end
  if not hasMain and (rec.level or 0) >= maxLevel then return "main" end
  if isCrafter(rec) then return "processor" end
  return nil
end

local function autoRoles()
  local me = ns.Chars.Current()
  if not me then return end
  local role = Autopilot.GuessRole(me, ns.Chars.MarketKey())
  if role then
    ns.Chars.SetRole(me.name, role, "auto")
    me.onboarded = true
    ns.Print(("%s ist als %s eingestuft. Ändern: Fenster → Team."):format(me.name, ns.Chars.ROLE_LABELS[role]))
    Autopilot.status.roles = "auto: " .. role
  end
end

-- Background profession reading -------------------------------------------------------------------
local queue, reading, blocked = {}, nil, false

function Autopilot.ReadQueue(rec)
  rec = rec or ns.Chars.Current()
  local out = {}
  for skillLine, p in pairs(rec and rec.professions or {}) do
    if not NO_BOOK[skillLine] and not p.former then
      local book = ns.Adapter.Book(skillLine)
      local fresh = book and p.when and (time() - p.when) < STALE
      if not fresh then out[#out + 1] = skillLine end
    end
  end
  table.sort(out)
  return out
end

local function busy()
  if InCombatLockdown() then return true end
  for _, f in ipairs({ MailFrame, AuctionHouseFrame, MerchantFrame, BankFrame, ClassTrainerFrame, ProfessionsFrame }) do
    if f and f:IsShown() and not (f == ProfessionsFrame and reading) then return true end
  end
  return false
end

local function finishRead(success)
  if not reading then return end
  local skillLine = reading.skillLine
  if ProfessionsFrame then
    if C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill) end
    if HideUIPanel then pcall(HideUIPanel, ProfessionsFrame) end
    ProfessionsFrame:SetAlpha(1)
  end
  reading = nil
  if success then
    Autopilot.status.books = (Autopilot.status.books or 0) + 1
    if ns.Checks then ns.Checks.Pass("autoRead", "Beruf " .. tostring(skillLine) .. " im Hintergrund gelesen") end
  end
  C_Timer.After(1.5, Autopilot.ReadNext)
end

function Autopilot.ReadNext()
  if blocked or reading or ns.db.settings.autoReadProfessions == false then return end
  if not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then return end
  if #queue == 0 then return end
  if busy() then C_Timer.After(10, Autopilot.ReadNext); return end
  local skillLine = table.remove(queue, 1)
  reading = { skillLine = skillLine, t = GetTime() }
  local ok = pcall(C_TradeSkillUI.OpenTradeSkill, skillLine)
  if not ok then reading = nil; C_Timer.After(1, Autopilot.ReadNext); return end
  C_Timer.After(6, function() if reading and reading.skillLine == skillLine then finishRead(false) end end)
end

-- Forever blocks opening a profession without a hardware click (ADDON_ACTION_BLOCKED, verified 09.11.2026).
-- Background reading is therefore opt-in and never retried once the client blocked it; by default books are read
-- when the player opens a profession or clicks "Rezepte laden" in the guide.
function Autopilot.StartReading()
  if ns.db.settings.autoReadProfessions ~= true or ns.db.learned.autoReadBlocked then
    if ns.Checks then ns.Checks.Skip("autoRead", "vom Spiel nicht erlaubt; Bücher werden beim Öffnen des Berufs gelesen") end
    return
  end
  queue = Autopilot.ReadQueue()
  Autopilot.ReadNext()
end

-- Health -----------------------------------------------------------------------------------------
function Autopilot.QuickHealth()
  local result = { red = 0, warn = 0, rows = {} }
  for _, row in ipairs(ns.Features.Status()) do
    if not row.ok and not ns.Features.Disabled(row.name) then
      result.red = result.red + 1
      result.rows[#result.rows + 1] = row.label .. ": " .. row.detail
    end
  end
  ns:EachModule(function(name, m)
    if type(m.SelfTest) == "function" then
      local ok, rows = pcall(m.SelfTest, m)
      if not ok then
        result.red = result.red + 1
        result.rows[#result.rows + 1] = name .. ": " .. tostring(rows)
      else
        for _, r in ipairs(rows or {}) do
          if not r.ok and not r.warn then result.red = result.red + 1; result.rows[#result.rows + 1] = name .. ": " .. r.name
          elseif not r.ok then result.warn = result.warn + 1 end
        end
      end
    end
  end)
  result.red = result.red + #ns.Health.detached
  return result
end

local function healthCheck()
  local h = Autopilot.QuickHealth()
  Autopilot.status.health = h
  ns.db.debug.health = { when = time(), red = h.red, warn = h.warn, rows = h.rows }
  if ns.Minimap and ns.Minimap.SetAlert then ns.Minimap.SetAlert(h.red > 0) end
  if h.red > 0 then
    ns.Print(("%d Funktion(en) eingeschränkt: %s. Details: /gw debug run"):format(h.red, h.rows[1] or "?"))
    if ns.Checks then ns.Checks.Fail("selftest", h.rows[1]) end
  elseif ns.Checks then
    ns.Checks.Pass("selftest", "automatisch beim Login")
  end
end

ns:RegisterModule("Autopilot", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function()
      C_Timer.After(3, autoRoles)
      C_Timer.After(12, Autopilot.StartReading)
      C_Timer.After(15, healthCheck)
    end, "Autopilot")
    ns.Events:On("SKILL_LINES_CHANGED", function() C_Timer.After(5, function() if not reading then Autopilot.StartReading() end end) end, "Autopilot")
    -- invisible while we read; the Adapter reads on TRADE_SKILL_LIST_UPDATE, then we close
    ns.Events:On("TRADE_SKILL_SHOW", function() if reading and ProfessionsFrame then ProfessionsFrame:SetAlpha(0) end end, "Autopilot")
    ns.Events:On("TRADE_SKILL_LIST_UPDATE", function()
      if not reading then return end
      C_Timer.After(0.8, function()
        if reading and ns.Adapter.current == reading.skillLine then finishRead(true) end
      end)
    end, "Autopilot")
    -- if the client ever blocks us, stop for this session and say so once
    local function onBlocked(_, addon)
      if addon ~= ADDON or blocked then return end
      blocked = true
      Autopilot.status.blocked = true
      if reading then finishRead(false) end
      -- a known client limit, not a fault: remember it for good and never try again
      ns.db.learned.autoReadBlocked = true
      ns.Log("background profession reading blocked by the client; disabled permanently")
      if ns.Checks then ns.Checks.Skip("autoRead", "vom Spiel nicht erlaubt; Bücher werden beim Öffnen gelesen") end
    end
    ns.Events:On("ADDON_ACTION_BLOCKED", onBlocked, "Autopilot")
    ns.Events:On("ADDON_ACTION_FORBIDDEN", onBlocked, "Autopilot")
  end,
  SelfTest = function()
    local off = blocked or ns.db.learned.autoReadBlocked or ns.db.settings.autoReadProfessions ~= true
    local detail = off and "aus (Spiel erlaubt es nicht); Bücher beim Öffnen"
      or ((Autopilot.status.books or 0) .. " gelesen, " .. #Autopilot.ReadQueue() .. " offen")
    return {
      { name = "Rollen-Automatik", ok = true, detail = Autopilot.status.roles or "nichts zu tun" },
      { name = "Berufe im Hintergrund", ok = true, detail = detail },
    }
  end,
})

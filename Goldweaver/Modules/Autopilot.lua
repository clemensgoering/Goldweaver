-- Goldweaver: Autopilot - setup and health checks that run for every user without any manual step.
--   1. Roles: guesses main/processor for characters without a role (highest level = main, crafter = processor).
--      A role the player chose (UI or /gw role) is never overridden.
--   2. Health: a silent self test 15 s after login; only problems reach the chat, and the minimap badge shows "!".
--
-- Public API (ns.Autopilot)
--   GuessRole(rec, market) -> role | nil
--   QuickHealth() -> { red = n, warn = n, rows = {...} }
--   status = { roles, health }
-- Recipe books are read when the player opens a profession (Professions/Adapter.lua); the client does not allow
-- opening one without a click.
local ADDON, ns = ...
local L = ns.L

local Autopilot = { status = {} }
ns.Autopilot = Autopilot

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
    ns.Print((L["%s is classified as %s. Change: Window » Team."]):format(me.name, L[ns.Chars.ROLE_LABELS[role]]))
    Autopilot.status.roles = "auto: " .. role
  end
end

-- Health -----------------------------------------------------------------------------------------
function Autopilot.QuickHealth()
  local result = { red = 0, warn = 0, rows = {} }
  for _, row in ipairs(ns.Features.Status()) do
    if not row.ok and not ns.Features.Disabled(row.name) then
      result.red = result.red + 1
      result.rows[#result.rows + 1] = L[row.label] .. ": " .. row.detail
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
    ns.Print((L["%d feature(s) restricted: %s. Details: /gw debug run"]):format(h.red, h.rows[1] or "?"))
    if ns.Checks then ns.Checks.Fail("selftest", h.rows[1]) end
  elseif ns.Checks then
    ns.Checks.Pass("selftest", "automatic at login")
  end
end

ns:RegisterModule("Autopilot", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function()
      C_Timer.After(3, autoRoles)
      C_Timer.After(15, healthCheck)
    end, "Autopilot")
  end,
  SelfTest = function()
    return {
      { name = L["Role automation"], ok = true, detail = Autopilot.status.roles or L["nothing to do"] },
    }
  end,
})

-- Goldweaver: character registry. Roles: main (gathers), processor (crafts/disenchants/sells), bank.
--
-- Verified on Forever 1.60.1 build 70862 (probe 08.11.2026):
--   UnitFullName("player") returns FIRST NAME and SURNAME ("Cupedos", "Grel"), not the realm.
--   GetRealmName() is a shard name such as "CAMWOW EU4 Realm 5 PvE": region and ruleset are encoded in it.
--   The auction house is shared per region + ruleset + faction, so the market key is "EU-PvE-Horde".
local ADDON, ns = ...
local L = ns.L

local Chars = {}
ns.Chars = Chars

-- "bank" was merged into "processor" (one twink stores AND processes; user decision 09.11.2026, schema 4)
local ROLES = { main = true, processor = true, none = true }
Chars.ROLES = ROLES
Chars.ROLE_LABELS = { main = "Main (gathers)", processor = "Processor & bank", none = "Inactive" } -- English keys, shown through L[...]
Chars.ROLE_ORDER = { "main", "processor", "none" }

-- Returns firstName, surname (surname may be nil). Secrets are never returned.
function Chars.Names()
  if not UnitFullName then return "Unknown", nil end
  local first, second = UnitFullName("player")
  if ns.Secret.Any(first, second) then return "Unknown", nil end
  if second == "" then second = nil end
  -- on a classic-style client the second value would be the realm; treat it as a surname only if it differs
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or nil
  if second and realm and second == realm then second = nil end
  return first, second
end

-- Short display name: the first name, or the full name when another own character on the market has the same
-- first name ("Cupedos Grel" and "Cupedos Bank").
function Chars.ShortName(rec)
  if not rec then return "?" end
  local first = rec.firstName
  if not first then return rec.name or "?" end
  for _, other in pairs(ns.db and ns.db.chars or {}) do
    if other ~= rec and other.firstName == first and other.market == rec.market then return rec.name or first end
  end
  return first
end

-- Registry key and display name: "Cupedos Grel".
function Chars.FullName()
  local first, surname = Chars.Names()
  if surname then return first .. " " .. surname end
  return first
end

-- Recipient string for the mailbox. The accepted format is learned from the first sends (Modules/Learn.lua, F10):
-- "Vorname Nachname" first; if the server rejects it, the first name alone.
function Chars.MailName(rec)
  rec = rec or Chars.Current()
  if not rec then return Chars.FullName() end
  local variant = ns.Learn and ns.Learn.MailVariant() or "full"
  if variant == "first" and rec.firstName then return rec.firstName end
  return rec.name
end

-- Parses "CAMWOW EU4 Realm 5 PvE" -> "EU", "PvE". Returns nil when the pattern is unknown.
function Chars.ParseRealm(realmName)
  if type(realmName) ~= "string" then return nil end
  local region = realmName:match("%f[%a](EU)%d*%f[%A]") or realmName:match("%f[%a](US)%d*%f[%A]")
    or realmName:match("%f[%a](KR)%d*%f[%A]") or realmName:match("%f[%a](TW)%d*%f[%A]") or realmName:match("%f[%a](CN)%d*%f[%A]")
  local ruleset
  if realmName:match("RP%s*PvP") then ruleset = "RPPvP"
  elseif realmName:match("%f[%a]RP%f[%A]") then ruleset = "RP"
  elseif realmName:match("PvP") then ruleset = "PvP"
  elseif realmName:match("PvE") then ruleset = "PvE" end
  if region and ruleset then return region, ruleset end
  return nil
end

function Chars.MarketKey()
  local settings = ns.db and ns.db.settings
  if settings and settings.marketKey then return settings.marketKey end
  local faction = UnitFactionGroup and UnitFactionGroup("player") or "faction"
  local realmName = GetRealmName and GetRealmName() or nil
  if ns.Secret.Any(faction, realmName) then return "unknown" end
  local region, ruleset = Chars.ParseRealm(realmName)
  if region then return region .. "-" .. ruleset .. "-" .. tostring(faction) end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or "realm"
  if ns.Secret.IsSecret(realm) then return "unknown" end
  return tostring(realm) .. "-" .. tostring(faction)
end

function Chars.Current()
  return ns.db.chars[Chars.FullName()]
end

-- Converts a pre-08.11 market key such as "CAMWOWEU4Realm5PvE-Horde" into "EU-PvE-Horde". Returns the input when it
-- already has the new form or cannot be parsed.
function Chars.NormalizeMarket(market)
  if type(market) ~= "string" then return market end
  if market:match("^%u%u%-%a+%-%a+$") then return market end
  local realmPart, faction = market:match("^(.-)%-([^%-]+)$")
  if not realmPart then return market end
  local region = realmPart:match("EU") or realmPart:match("US") or realmPart:match("KR") or realmPart:match("TW") or realmPart:match("CN")
  local ruleset
  if realmPart:match("RP%s*PvP") then ruleset = "RPPvP"
  elseif realmPart:match("PvP") then ruleset = "PvP"
  elseif realmPart:match("PvE") then ruleset = "PvE"
  elseif realmPart:match("RP") then ruleset = "RP" end
  if region and ruleset then return region .. "-" .. ruleset .. "-" .. faction end
  return market
end

-- One-time cleanup of records written before the name/market format was verified in game.
function Chars.Migrate()
  -- On Forever every "First-Second" key written by the old code is "First Second" (second part = surname).
  local onForever = Chars.ParseRealm(GetRealmName and GetRealmName() or nil) ~= nil
  if onForever then
    for key, rec in pairs(ns.db.chars) do
      local first, second = key:match("^([^%-%s]+)%-([^%-%s]+)$")
      if first and second then
        local newKey = first .. " " .. second
        if not ns.db.chars[newKey] then
          rec.name, rec.firstName, rec.surname = newKey, first, second
          ns.db.chars[newKey] = rec
        end
        ns.db.chars[key] = nil
        ns.Log("migrated character key", key, "->", newKey)
      end
    end
  end
  for _, rec in pairs(ns.db.chars) do
    local normalized = Chars.NormalizeMarket(rec.market)
    if normalized ~= rec.market then
      if ns.db.prices[rec.market] and not ns.db.prices[normalized] then
        ns.db.prices[normalized] = ns.db.prices[rec.market]
        ns.db.prices[rec.market] = nil
      end
      rec.market = normalized
    end
  end
end

function Chars.Register()
  Chars.Migrate()
  local name = Chars.FullName()
  local first, surname = Chars.Names()
  local rec = ns.db.chars[name] or { role = "none" }
  rec.name = name
  rec.firstName, rec.surname = first, surname
  rec.market = Chars.MarketKey()
  rec.faction = UnitFactionGroup and select(1, UnitFactionGroup("player")) or nil
  rec.class = UnitClassBase and UnitClassBase("player") or nil
  rec.level = UnitLevel and UnitLevel("player") or nil
  rec.lastSeen = time()
  rec.professions = rec.professions or {}
  ns.db.chars[name] = rec
  Chars.UpdateProfessions()
  Chars.Changed()
  return rec
end

-- Reads the character's professions (index list from GetProfessions, details from GetProfessionInfo).
function Chars.UpdateProfessions()
  if not (GetProfessions and GetProfessionInfo) then return end
  local rec = Chars.Current()
  if not rec then return end
  -- Merge into the existing entries: the Adapter stores learned recipes, counts and timestamps there and they
  -- must survive a SKILL_LINES_CHANGED refresh (bug found in the first in-game report, 08.11.2026).
  rec.professions = rec.professions or {}
  local seen = {}
  for _, idx in ipairs({ GetProfessions() }) do
    if idx then
      local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
      if not ns.Secret.Any(name, rank, maxRank, skillLine) and skillLine then
        local p = rec.professions[skillLine] or {}
        p.name, p.rank, p.maxRank = name, rank, maxRank
        if icon and not ns.Secret.IsSecret(icon) then p.icon = icon end
        rec.professions[skillLine] = p
        seen[skillLine] = true
      end
    end
  end
  -- professions the character no longer has (unlearned) are kept for 30 days as "former" to avoid losing data by accident
  for skillLine, p in pairs(rec.professions) do
    if not seen[skillLine] then
      p.former = p.former or time()
      if time() - p.former > 30 * 86400 then rec.professions[skillLine] = nil end
    else
      p.former = nil
    end
  end
end

-- source = "auto" for the Autopilot's guess; anything else (UI, slash) marks the role as chosen by the player,
-- which the Autopilot never overrides.
function Chars.SetRole(name, role, source)
  if role == "bank" then role = "processor" end
  assert(ROLES[role], "unknown role: " .. tostring(role))
  local rec = ns.db.chars[name]
  if not rec then return false end
  rec.role = role
  rec.roleSource = source == "auto" and "auto" or "manual"
  Chars.Changed()
  return true
end

function Chars.ByRole(role, market)
  local list = {}
  for _, rec in pairs(ns.db.chars) do
    if rec.role == role and (market == nil or rec.market == market) then list[#list + 1] = rec end
  end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  return list
end

function Chars.All(market)
  local list = {}
  for _, rec in pairs(ns.db.chars) do
    if market == nil or rec.market == market then list[#list + 1] = rec end
  end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  return list
end

-- Characters on this market that have the given profession skill line.
function Chars.WithProfession(skillLine, market)
  local list = {}
  for _, rec in pairs(ns.db.chars) do
    if (market == nil or rec.market == market) and rec.professions and rec.professions[skillLine] then list[#list + 1] = rec end
  end
  return list
end

-- Number of known characters without a role: shown as the minimap badge until everyone is assigned.
function Chars.Unassigned()
  local n = 0
  for _, rec in pairs(ns.db.chars) do
    if (rec.role or "none") == "none" then n = n + 1 end
  end
  return n
end

-- Notifies UI parts (minimap badge, window) after any registry change.
function Chars.Changed()
  if ns.Minimap and ns.Minimap.SetBadge then ns.Minimap.SetBadge(Chars.Unassigned()) end
  if ns.Checks then
    local me = Chars.Current()
    if me then ns.Checks.Pass("char", me.name .. " @ " .. (me.market or "?")) end
    local market = Chars.MarketKey()
    if #Chars.ByRole("main", market) > 0 and #Chars.ByRole("processor", market) > 0 then
      ns.Checks.Pass("roles", ("%d main, %d processor"):format(#Chars.ByRole("main", market), #Chars.ByRole("processor", market)))
    end
  end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

ns:RegisterModule("Chars", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() Chars.Register() end, "Chars")
    ns.Events:On("SKILL_LINES_CHANGED", function() Chars.UpdateProfessions() end, "Chars")
    ns.Events:On("PLAYER_LEVEL_UP", function() local rec = Chars.Current() if rec then rec.level = UnitLevel("player") end end, "Chars")
  end,
  SelfTest = function()
    local me = Chars.Current()
    local first, surname = Chars.Names()
    local region = Chars.ParseRealm(GetRealmName and GetRealmName() or nil)
    return {
      { name = L["Character registered"], ok = me ~= nil, detail = me and me.name or L["missing (PLAYER_LOGIN has not run yet?)"] },
      { name = L["Name format first name + surname"], ok = surname ~= nil, warn = true, detail = tostring(first) .. " / " .. tostring(surname) },
      { name = L["Market key from realm name"], ok = region ~= nil or ns.db.settings.marketKey ~= nil, detail = Chars.MarketKey() },
      { name = L["Processor on this market"], ok = #Chars.ByRole("processor", Chars.MarketKey()) > 0, warn = true, detail = #Chars.ByRole("processor", Chars.MarketKey()) .. " " .. L["character(s)"] },
      { name = L["Characters without a role"], ok = Chars.Unassigned() == 0, warn = true, detail = tostring(Chars.Unassigned()) },
    }
  end,
})

ns.Slash.Register("role", function(arg)
  local role, who = arg:match("^(%S+)%s*(.-)$")
  if role == "bank" then role = "processor" end
  if not role or not ROLES[role] then return ns.Print(L["usage: /gw role main|processor|none [full name]"]) end
  who = (who ~= "" and who) or Chars.FullName()
  if Chars.SetRole(who, role) then ns.Print((L["%s is now %s"]):format(who, role)) else ns.Print((L["unknown character: %s"]):format(who)) end
end, "set this character's role (main|processor|bank)")

ns.Slash.Register("chars", function()
  for _, rec in ipairs(Chars.All()) do
    local profs = {}
    for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank) end
    ns.Print(("%s [%s] %s: %s"):format(rec.name, rec.role or "none", rec.market or "?", table.concat(profs, ", ")))
  end
end, "list known characters")

ns.Slash.Register("market", function(arg)
  if arg == "" then return ns.Print((L["market key: %s (set with /gw market <region-ruleset-faction>, clear with /gw market auto)"]):format(Chars.MarketKey())) end
  ns.db.settings.marketKey = (arg ~= "auto") and arg or nil
  ns.Print((L["market key: %s"]):format(Chars.MarketKey()))
end, "show or set the market key (region-ruleset-faction)")

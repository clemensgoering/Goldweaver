-- Goldweaver: character registry. Roles: main (gathers), processor (crafts/disenchants/sells), bank.
--
-- Verified on Forever 1.60.1 build 70862 (probe 08.11.2026):
--   UnitFullName("player") returns FIRST NAME and SURNAME ("Cupedos", "Grel"), not the realm.
--   GetRealmName() is a shard name such as "CAMWOW EU4 Realm 5 PvE": region and ruleset are encoded in it.
--   The auction house is shared per region + ruleset + faction, so the market key is "EU-PvE-Horde".
local ADDON, ns = ...

local Chars = {}
ns.Chars = Chars

local ROLES = { main = true, processor = true, bank = true, none = true }
Chars.ROLES = ROLES
Chars.ROLE_LABELS = { main = "Main (sammelt)", processor = "Verarbeiter", bank = "Bank", none = "keine Rolle" }

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

-- Registry key and display name: "Cupedos Grel".
function Chars.FullName()
  local first, surname = Chars.Names()
  if surname then return first .. " " .. surname end
  return first
end

-- Recipient string for the mailbox. Forever beta routed by first name only (F10); the surname form is the safe one
-- until /gw probe mail confirms otherwise.
function Chars.MailName(rec)
  return rec and rec.name or Chars.FullName()
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
  local first, surname = Chars.Names()
  local newKey = Chars.FullName()
  local oldKey = surname and (first .. "-" .. surname) or nil
  if oldKey and ns.db.chars[oldKey] and not ns.db.chars[newKey] then
    ns.db.chars[newKey] = ns.db.chars[oldKey]
    ns.db.chars[oldKey] = nil
    ns.Log("migrated character key", oldKey, "->", newKey)
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
  local profs = {}
  for _, idx in ipairs({ GetProfessions() }) do
    if idx then
      local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
      if not ns.Secret.Any(name, rank, maxRank, skillLine) and skillLine then
        profs[skillLine] = { name = name, rank = rank, maxRank = maxRank }
      end
    end
  end
  rec.professions = profs
end

function Chars.SetRole(name, role)
  assert(ROLES[role], "unknown role: " .. tostring(role))
  local rec = ns.db.chars[name]
  if not rec then return false end
  rec.role = role
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
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

ns:RegisterModule("Chars", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() Chars.Register() end)
    ns.Events:On("SKILL_LINES_CHANGED", function() Chars.UpdateProfessions() end)
    ns.Events:On("PLAYER_LEVEL_UP", function() local rec = Chars.Current() if rec then rec.level = UnitLevel("player") end end)
  end,
})

ns.Slash.Register("role", function(arg)
  local role, who = arg:match("^(%S+)%s*(.-)$")
  if not role or not ROLES[role] then return ns.Print("usage: /gw role main|processor|bank|none [full name]") end
  who = (who ~= "" and who) or Chars.FullName()
  if Chars.SetRole(who, role) then ns.Print(who .. " is now " .. role) else ns.Print("unknown character: " .. who) end
end, "set this character's role (main|processor|bank)")

ns.Slash.Register("chars", function()
  for _, rec in ipairs(Chars.All()) do
    local profs = {}
    for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank) end
    ns.Print(("%s [%s] %s: %s"):format(rec.name, rec.role or "none", rec.market or "?", table.concat(profs, ", ")))
  end
end, "list known characters")

ns.Slash.Register("market", function(arg)
  if arg == "" then return ns.Print("market key: " .. Chars.MarketKey() .. " (set with /gw market <region-ruleset-faction>, clear with /gw market auto)") end
  ns.db.settings.marketKey = (arg ~= "auto") and arg or nil
  ns.Print("market key: " .. Chars.MarketKey())
end, "show or set the market key (region-ruleset-faction)")

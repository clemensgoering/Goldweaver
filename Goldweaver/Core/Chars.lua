-- Goldweaver: character registry. Roles: main (gathers), processor (crafts/disenchants/sells), bank.
-- Characters are keyed by their full name as the client reports it (F3: format with surname to be verified by /gw probe).
-- Market key = ruleset + faction. The ruleset cannot be read from the API yet, so it is a setting (/gw market <name>)
-- with the normalized realm name as fallback.
local ADDON, ns = ...

local Chars = {}
ns.Chars = Chars

local ROLES = { main = true, processor = true, bank = true, none = true }

function Chars.FullName()
  if not UnitFullName then return "Unknown" end
  local name, realm = UnitFullName("player")
  if ns.Secret.Any(name, realm) then return "Unknown" end
  if realm and realm ~= "" then return name .. "-" .. realm end
  return name
end

function Chars.MarketKey()
  local settings = ns.db and ns.db.settings
  if settings and settings.marketKey then return settings.marketKey end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or "realm"
  local faction = UnitFactionGroup and UnitFactionGroup("player") or "faction"
  if ns.Secret.Any(realm, faction) then return "unknown" end
  return tostring(realm) .. "-" .. tostring(faction)
end

function Chars.Current()
  return ns.db.chars[Chars.FullName()]
end

function Chars.Register()
  local name = Chars.FullName()
  local rec = ns.db.chars[name] or { role = "none" }
  rec.name = name
  rec.market = Chars.MarketKey()
  rec.faction = UnitFactionGroup and select(1, UnitFactionGroup("player")) or nil
  rec.class = UnitClassBase and UnitClassBase("player") or nil
  rec.level = UnitLevel and UnitLevel("player") or nil
  rec.lastSeen = time()
  rec.professions = rec.professions or {}
  ns.db.chars[name] = rec
  Chars.UpdateProfessions()
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

-- Characters on this market that have the given profession skill line.
function Chars.WithProfession(skillLine, market)
  local list = {}
  for _, rec in pairs(ns.db.chars) do
    if (market == nil or rec.market == market) and rec.professions and rec.professions[skillLine] then list[#list + 1] = rec end
  end
  return list
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
  for _, rec in pairs(ns.db.chars) do
    local profs = {}
    for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank) end
    ns.Print(("%s [%s] %s: %s"):format(rec.name, rec.role or "none", rec.market or "?", table.concat(profs, ", ")))
  end
end, "list known characters")

ns.Slash.Register("market", function(arg)
  if arg == "" then return ns.Print("market key: " .. Chars.MarketKey() .. " (set with /gw market <ruleset-faction>, clear with /gw market auto)") end
  ns.db.settings.marketKey = (arg ~= "auto") and arg or nil
  ns.Print("market key: " .. Chars.MarketKey())
end, "show or set the market key (ruleset-faction)")

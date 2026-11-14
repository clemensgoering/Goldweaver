-- Level gates and milestones (Modules/Gates.lua), short names (Core/Chars.lua) and the Forever trainer return shape
-- (Modules/Learn.lua). Team: a level 6 mage twink stuck at 75 Tailoring/Enchanting and a level 28 hunter main.
local ns, eq = ...

local saved = { chars = ns.db.chars, trainers = ns.db.learned.trainers }
ns.db.chars, ns.db.learned.trainers = {}, nil
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end

UnitFullName = function() return "Cupedos", "Bank" end
UnitLevel = function() return 6 end
local twink = ns.Chars.Register()
twink.role, twink.level, twink.class = "processor", 6, "MAGE"
twink.professions[197] = { name = "Tailoring", rank = 75, maxRank = 75 }
twink.professions[333] = { name = "Enchanting", rank = 60, maxRank = 75 }

UnitFullName = function() return "Cupedos", "Grel" end
UnitLevel = function() return 28 end
local main = ns.Chars.Register()
main.role, main.level, main.class = "main", 28, "HUNTER"
main.professions[393] = { name = "Skinning", rank = 183, maxRank = 225 }
main.professions[165] = { name = "Leatherworking", rank = 106, maxRank = 150 }
ns.Budget.Invalidate()

-- short names stay unique when two characters share a first name ------------------------------------------------------
eq(ns.Chars.ShortName(main), "Cupedos Grel", "shared first name: full name")
eq(ns.Chars.ShortName({ firstName = "Thrall", name = "Thrall Doomhammer", market = "x" }), "Thrall", "unique first name: short")
eq(ns.Chars.ShortName(nil), "?", "no character")

-- gates: severity and order -----------------------------------------------------------------------------------------------
local g = ns.Gates.For(twink)
eq(#g, 2, "two gates for the twink")
eq(g[1].skillLine, 197, "the profession at its cap comes first")
eq(g[1].severity, "blocked", "at the cap: blocked")
eq(g[2].severity, "soon", "15 points or fewer to the cap: soon")
eq(ns.Gates.Title(g[1]):find("10") ~= nil, true, "title names the level")
eq(ns.Gates.Detail(g[1]):find("75") ~= nil, true, "detail names the cap")
local hint = ns.Gates.WhileLevelling(g[1])
eq(hint ~= nil and hint:find("%(") ~= nil, true, "tailoring: hint names the cloth of the level")
eq(ns.Gates.WhileLevelling({ skillLine = 999, rec = twink }), nil, "unknown profession: no hint")
local all = ns.Gates.List()
eq(#all, 2, "team list: the main has no gate (Expert reached, Artisan Skinning at 25)")

-- milestones: every unlock level from now to 60 ---------------------------------------------------------------------------
local ms = ns.Gates.Milestones(twink)
eq(ms[1].level, 10, "first milestone at 10")
eq(#ms[1].professions, 2, "both professions unlock Journeyman at 10")
eq(ms[#ms].level, 35, "last crafting milestone at 35 (no riding for the processor)")
local mm = ns.Gates.Milestones(main)
local levels = {}
for _, m in ipairs(mm) do levels[#levels + 1] = m.level end
eq(table.concat(levels, ","), "35,40", "main: Artisan Leatherworking at 35, riding at 40")
eq(mm[2].riding, true, "riding milestone marked")

-- a trainer that showed other values wins over the guide -----------------------------------------------------------------
ns.db.learned.trainers = { Magar = { skillLine = 197, ranks = { { skillReq = 50, levelReq = 12, cost = 700 } } } }
local nr = ns.Planner.NextRank(197, twink)
eq(nr.reqLevel, 12, "level requirement seen at the trainer")
eq(nr.cost, 700, "cost seen at the trainer")
eq(nr.costSeen, true, "marked as seen")
eq(ns.Gates.For(twink)[1].reqLevel, 12, "gates follow the trainer")
ns.db.learned.trainers = nil

-- Forever: GetTrainerServiceSkillReq returns the skill name first; the rank is still recognised ----------------------------
GetNumTrainerServices = function() return 2 end
GetTrainerServiceInfo = function(i) return i == 1 and "Journeyman" or "Linen Belt", i == 1 and "available" or "unavailable", 132000 end
GetTrainerServiceSkillReq = function(i) return "Tailoring", i == 1 and 50 or 30, true end
GetTrainerServiceLevelReq = function(i) return i == 1 and 10 or 0 end
GetTrainerServiceCost = function() return 500 end
local entry = ns.Learn.TrainerServices("Magar")
eq(entry.services[1].skillReq, 50, "skill requirement read from the second return value")
eq(#entry.ranks, 1, "rank tier recognised")
eq(entry.ranks[1].levelReq, 10, "rank level requirement")
GetNumTrainerServices, GetTrainerServiceInfo, GetTrainerServiceSkillReq, GetTrainerServiceLevelReq, GetTrainerServiceCost = nil, nil, nil, nil, nil

-- steps: the twink at the keyboard gets "reach level 10"; the main sees that the twink is stuck ----------------------------
ns.db.learned.trainers = nil
local steps = ns.Steps.Build(20)
local ids = {}
for _, s in ipairs(steps) do ids[s.id or "?"] = true end
eq(ids["gateTeam197Cupedos Bank"], true, "main: team step for the blocked twink")

-- cleanup
ns.db.chars, ns.db.learned.trainers = saved.chars, saved.trainers
ns.Budget.Invalidate()

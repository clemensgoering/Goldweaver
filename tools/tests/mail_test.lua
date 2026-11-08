-- Mail routing rules with stubbed item classes.
local ns, eq = ...
local Mail = ns.Mail

local CLASSES = {
  [2589] = { 7, 5 },   -- Linen Cloth: tradegoods / cloth
  [2770] = { 7, 7 },   -- Copper Ore: tradegoods / metal & stone
  [5555] = { 4, 1 },   -- green armor
  [6666] = { 2, 7 },   -- green weapon
  [7777] = { 9, 2 },   -- tailoring pattern
  [8888] = { 0, 0 },   -- consumable
}
C_Item.GetItemInfoInstant = function(id)
  local c = CLASSES[id]
  if not c then return nil end
  return id, "type", "subtype", "", 1, c[1], c[2]
end

ns.db.chars = {}
UnitFullName = function() return "Cupedos", "Grel" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
local me = ns.Chars.Register()
me.role = "main"
me.professions = { [165] = { name = "Leder", rank = 81, maxRank = 150 }, [393] = { name = "Kürschner", rank = 142, maxRank = 225 } }
ns.db.chars["Cupedos Bank"] = { name = "Cupedos Bank", firstName = "Cupedos", surname = "Bank", role = "processor", market = me.market, professions = { [197] = { name = "Schneiderei", rank = 53 }, [333] = { name = "Verzauberkunst", rank = 25 } } }

local target, reason = Mail.TargetFor({ itemID = 2589, quality = 1, isBound = false })
eq(target and target.name, "Cupedos Bank", "cloth goes to the tailor")
eq(reason, "Material für Cupedos Bank", "reason names the processor")

target, reason = Mail.TargetFor({ itemID = 2770, quality = 1, isBound = false })
eq(target and target.name, "Cupedos Bank", "ore goes to the only processor even without a matching profession")
eq(reason, "Material", "generic material reason")

target, reason = Mail.TargetFor({ itemID = 5555, quality = 2, isBound = false })
eq(target and target.name, "Cupedos Bank", "green armor goes to the enchanter")
eq(reason:find("entzaubern") ~= nil, true, "disenchant reason")

target, reason = Mail.TargetFor({ itemID = 6666, quality = 1, isBound = false })
eq(target, nil, "white weapon stays")

target, reason = Mail.TargetFor({ itemID = 5555, quality = 2, isBound = true })
eq(target, nil, "bound items stay")
eq(reason, "gebunden", "bound reason")

target, reason = Mail.TargetFor({ itemID = 7777, quality = 1, isBound = false })
eq(target and target.name, "Cupedos Bank", "tailoring pattern goes to the tailor")

target, reason = Mail.TargetFor({ itemID = 8888, quality = 0, isBound = false })
eq(target, nil, "grey items stay")
eq(reason, "Händler", "vendor reason")

-- own-profession materials stay when the setting is on; leather subclass 6 -> leatherworking 165
CLASSES[2318] = { 7, 6 }
target, reason = Mail.TargetFor({ itemID = 2318, quality = 1, isBound = false })
eq(target, nil, "leather stays with the leatherworker")
eq(reason, "eigener Beruf", "own profession reason")
ns.db.settings.keepOwnMaterials = false
target = Mail.TargetFor({ itemID = 2318, quality = 1, isBound = false })
eq(target and target.name, "Cupedos Bank", "with the setting off, leather travels too")
ns.db.settings.keepOwnMaterials = nil

-- a processor never mails to itself
me.role = "processor"
target, reason = Mail.TargetFor({ itemID = 2589, quality = 1, isBound = false })
eq(target, nil, "processor keeps everything")
eq(reason, "hier verarbeiten", "processor reason")
me.role = "main"

-- custom rule inserted first wins
Mail.AddRule("test-first", function(item) if item.itemID == 2589 then return false, "Testregel" end end, 1)
target, reason = Mail.TargetFor({ itemID = 2589, quality = 1, isBound = false })
eq(reason, "Testregel", "custom rule applied")
table.remove(Mail.rules, 1)

-- cleanup
ns.db.chars = {}
C_Item.GetItemInfoInstant = function() return nil end
UnitFullName = function() return "Testchar", "" end
GetRealmName = nil
UnitFactionGroup = function() return "Alliance", "Alliance" end

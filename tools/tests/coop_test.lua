-- Team view (Modules/Coop.lua): main gathers, the processor's plan defines the gather list; materials in the main's
-- bags, the mail and the processor's bags all count; skill points and each side's share follow from them.
local ns, eq = ...

ns.db.chars = {}
UnitFullName = function() return "Grel", "Main" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitLevel = function() return 24 end
local main = ns.Chars.Register()
ns.Chars.SetRole(main.name, "main")
local crafter = { name = "Cupedos-Bank", firstName = "Cupedos", role = "processor", market = main.market, level = 12, lastSeen = time() - 7200,
  professions = { [197] = { name = "Schneiderei", rank = 40, maxRank = 75, learned = { [101] = true } } },
  inventory = { bags = { [2589] = 4 }, bank = {}, incoming = { items = { [2589] = 6 }, when = time() } } }
ns.db.chars[crafter.name] = crafter
ns.db.recipes = { [197] = { name = "Schneiderei", skillLine = 197, when = time(), byID = {},
  list = { { id = 101, name = "Bolt of Linen Cloth", icon = 1, outputItemID = 2996, qtyMin = 1, qtyMax = 1, reagents = { { item = 2589, qty = 2 } }, difficulty = 0 } } } }
ns.db.recipes[197].byID[101] = ns.db.recipes[197].list[1]

local getCount = C_Item.GetItemCount
C_Item.GetItemCount = function(itemID) return itemID == 2589 and 10 or 0 end

local gatherer, team2 = ns.Coop.Team()
eq(gatherer, main, "main is the gatherer")
eq(team2, crafter, "processor is the crafter")
eq(ns.Coop.Partner(), crafter, "partner of the main")

ns.Coop.Invalidate()
local view = ns.Coop.Needs()
eq(view ~= nil, true, "view built")
local row = view.rows[1]
eq(row.item, 2589, "linen on the list")
eq(row.need, 40, "20 bolts need 40 linen")
eq(row.gatherer, 10, "main's bags")
eq(row.mail, 6, "in the mail")
eq(row.crafter, 4, "processor's bags")
eq(row.have, 20, "everything counted once")
eq(view.points, 10, "20 linen = 10 bolts = 10 points")
eq(view.fromGatherer, 5, "main's 10 linen = 5 points")
eq(view.fromMail, 3, "6 linen in the mail = 3 points")
eq(view.plans[1].from, 40, "plan starts at the current skill")

-- inventory counts mail for alts; sending adds to the recipient's incoming items
eq((ns.Inventory.Count(2589, { bank = true, alts = true })), 20, "Count includes the alt's incoming mail")
ns.Coop.RecordSent(crafter, { [2589] = 4 })
eq(crafter.inventory.incoming.items[2589], 10, "sent items add up")
ns.Coop.Invalidate()
eq(ns.Coop.Needs().rows[1].mail, 10, "view follows the mail")

-- the processor's own inbox replaces "in transit"
local me = ns.Chars.Current()
GetInboxNumItems = function() return 1, 1 end
GetInboxItem = function(_, j) if j == 1 then return "Linen Cloth", 2589, 1, 7 end end
ns.Coop.ScanInbox()
eq(me.inventory.mail[2589], 7, "inbox snapshot")
eq(me.inventory.incoming, nil, "in transit cleared by the inbox")
GetInboxNumItems, GetInboxItem = nil, nil
me.inventory.mail = nil

C_Item.GetItemCount = getCount
ns.Coop.Invalidate()

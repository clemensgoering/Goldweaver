-- Goldweaver: zones with level range and the herbs/ores that grow there (Classic data, uiMapIDs of the Mainline
-- client; Orgrimmar 1454 verified on Forever). Marked unverified: own gathering observations in
-- GoldweaverDB.learned.zoneGathers confirm and extend these lists (Modules/Field.lua).
--
-- Public API (ns.Data.Zones)
--   list[uiMapID] = { name, min, max, faction?, herbs = {itemID}, ores = {itemID}, city? }
--   ForLevel(level) -> zones whose range contains the level, sorted by closeness
local ADDON, ns = ...

local Data = ns.Data
local Z = { verified = false }
Data.Zones = Z

-- herb IDs
local PEACE, SILVER, EARTH, MAGE, BRIAR, KELP, BRUISE, STEEL, MOSS, KINGS = 2447, 765, 2449, 785, 2450, 3820, 2453, 3355, 3369, 3356
local LIFE, FADE, GOLDT, KHAD, WINTER, FIRE, LOTUS, ARTHAS, SUN, BLIND = 3357, 3818, 3821, 3358, 3819, 4625, 8831, 8836, 8838, 8839
local GHOST, GROMS, SANSAM, DREAM, SAGE, PLAGUE, ICECAP, BLACKLOTUS = 8845, 8846, 13464, 13463, 13465, 13466, 13467, 13468
-- ore IDs
local COPPER, TIN, SILV, IRON, GOLD, MITH, TRUE, DARK, THOR = 2770, 2771, 2775, 2772, 2776, 3858, 7911, 11370, 10620

Z.list = {
  [1411] = { name = "Durotar", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = { COPPER } },
  [1412] = { name = "Mulgore", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = { COPPER } },
  [1420] = { name = "Tirisfal Glades", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = { COPPER } },
  [1429] = { name = "Elwynn Forest", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = { COPPER } },
  [1426] = { name = "Dun Morogh", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = { COPPER } },
  [1438] = { name = "Teldrassil", min = 1, max = 10, herbs = { PEACE, SILVER, EARTH }, ores = {} },
  [1413] = { name = "The Barrens", min = 10, max = 25, herbs = { PEACE, SILVER, EARTH, MAGE, BRIAR, KELP, BRUISE }, ores = { COPPER, TIN, SILV } },
  [1421] = { name = "Silverpine Forest", min = 10, max = 20, herbs = { PEACE, SILVER, EARTH, MAGE, BRIAR, KELP }, ores = { COPPER, TIN } },
  [1436] = { name = "Westfall", min = 10, max = 20, herbs = { PEACE, SILVER, EARTH, MAGE, BRIAR, KELP }, ores = { COPPER, TIN } },
  [1432] = { name = "Loch Modan", min = 10, max = 20, herbs = { SILVER, EARTH, MAGE, BRIAR }, ores = { COPPER, TIN } },
  [1439] = { name = "Darkshore", min = 10, max = 20, herbs = { SILVER, EARTH, MAGE, BRIAR, KELP }, ores = { COPPER, TIN } },
  [1433] = { name = "Redridge Mountains", min = 15, max = 25, herbs = { MAGE, BRIAR, BRUISE, KELP }, ores = { COPPER, TIN, SILV } },
  [1442] = { name = "Stonetalon Mountains", min = 15, max = 27, herbs = { MAGE, BRIAR, BRUISE, STEEL, KINGS }, ores = { COPPER, TIN, SILV } },
  [1440] = { name = "Ashenvale", min = 18, max = 30, herbs = { MAGE, BRIAR, BRUISE, STEEL, KINGS, KELP }, ores = { COPPER, TIN, SILV, IRON } },
  [1431] = { name = "Duskwood", min = 18, max = 30, herbs = { BRIAR, BRUISE, MOSS, KINGS }, ores = { COPPER, TIN, SILV, IRON, GOLD } },
  [1424] = { name = "Hillsbrad Foothills", min = 20, max = 30, herbs = { BRIAR, BRUISE, KINGS, LIFE, STEEL }, ores = { TIN, SILV, IRON } },
  [1437] = { name = "Wetlands", min = 20, max = 30, herbs = { BRUISE, KINGS, LIFE, MOSS, KELP, STEEL }, ores = { TIN, SILV, IRON } },
  [1441] = { name = "Thousand Needles", min = 25, max = 35, herbs = { STEEL, KINGS, LIFE }, ores = { TIN, SILV, IRON, GOLD } },
  [1416] = { name = "Alterac Mountains", min = 30, max = 40, herbs = { KINGS, LIFE, STEEL }, ores = { SILV, IRON, GOLD } },
  [1417] = { name = "Arathi Highlands", min = 30, max = 40, herbs = { STEEL, KINGS, LIFE, FADE, GOLDT, KHAD }, ores = { IRON, GOLD, MITH } },
  [1443] = { name = "Desolace", min = 30, max = 40, herbs = { STEEL, KINGS, LIFE, GOLDT }, ores = { IRON, GOLD, MITH } },
  [1434] = { name = "Stranglethorn Vale", min = 30, max = 45, herbs = { LIFE, KINGS, FADE, GOLDT, KHAD, LOTUS, STEEL }, ores = { TIN, SILV, IRON, GOLD, MITH, TRUE } },
  [1445] = { name = "Dustwallow Marsh", min = 35, max = 45, herbs = { LIFE, FADE, KINGS, GOLDT, KHAD }, ores = { IRON, GOLD, MITH } },
  [1418] = { name = "Badlands", min = 35, max = 45, herbs = { STEEL, KINGS, GOLDT, LOTUS }, ores = { IRON, GOLD, MITH, TRUE } },
  [1435] = { name = "Swamp of Sorrows", min = 35, max = 45, herbs = { FADE, GOLDT, KINGS, KHAD, LIFE, BLIND }, ores = { IRON, GOLD, MITH } },
  [1425] = { name = "The Hinterlands", min = 40, max = 50, herbs = { GOLDT, KHAD, LOTUS, SUN, FADE }, ores = { GOLD, MITH, TRUE } },
  [1444] = { name = "Feralas", min = 40, max = 50, herbs = { GOLDT, KHAD, LOTUS, SUN, FADE }, ores = { IRON, GOLD, MITH, TRUE } },
  [1446] = { name = "Tanaris", min = 40, max = 50, herbs = { FIRE, LOTUS }, ores = { IRON, GOLD, MITH, TRUE } },
  [1427] = { name = "Searing Gorge", min = 43, max = 50, herbs = { FIRE }, ores = { IRON, GOLD, MITH, TRUE, DARK, THOR } },
  [1447] = { name = "Azshara", min = 45, max = 55, herbs = { LOTUS, SUN, SANSAM, DREAM, SAGE }, ores = { MITH, TRUE, THOR } },
  [1419] = { name = "Blasted Lands", min = 45, max = 55, herbs = { FIRE, SUN, GROMS }, ores = { MITH, TRUE, THOR } },
  [1449] = { name = "Un'Goro Crater", min = 48, max = 55, herbs = { SANSAM, DREAM, SAGE, SUN, BLIND }, ores = { MITH, TRUE, THOR } },
  [1448] = { name = "Felwood", min = 48, max = 55, herbs = { GROMS, PLAGUE, SANSAM, DREAM, SUN, ARTHAS }, ores = { MITH, TRUE, THOR } },
  [1428] = { name = "Burning Steppes", min = 50, max = 58, herbs = { FIRE, SUN, SANSAM, DREAM, SAGE }, ores = { THOR, TRUE, DARK } },
  [1422] = { name = "Western Plaguelands", min = 51, max = 58, herbs = { ARTHAS, SUN, SANSAM, PLAGUE }, ores = { THOR, TRUE, MITH } },
  [1423] = { name = "Eastern Plaguelands", min = 53, max = 60, herbs = { ARTHAS, PLAGUE, SUN, SANSAM, DREAM, SAGE }, ores = { THOR, TRUE } },
  [1452] = { name = "Winterspring", min = 53, max = 60, herbs = { ICECAP, SANSAM, DREAM, SAGE, BLACKLOTUS }, ores = { THOR, TRUE, MITH } },
  [1451] = { name = "Silithus", min = 55, max = 60, herbs = { SANSAM, DREAM, SAGE, BLACKLOTUS }, ores = { THOR, TRUE } },
  [1430] = { name = "Deadwind Pass", min = 55, max = 60, herbs = { GHOST }, ores = {} },
  -- cities (no nodes; the field view shows the processor's needs instead)
  [1454] = { name = "Orgrimmar", city = true, min = 1, max = 60, herbs = {}, ores = {} },
  [1456] = { name = "Thunder Bluff", city = true, min = 1, max = 60, herbs = {}, ores = {} },
  [1458] = { name = "Undercity", city = true, min = 1, max = 60, herbs = {}, ores = {} },
  [1453] = { name = "Stormwind City", city = true, min = 1, max = 60, herbs = {}, ores = {} },
  [1455] = { name = "Ironforge", city = true, min = 1, max = 60, herbs = {}, ores = {} },
  [1457] = { name = "Darnassus", city = true, min = 1, max = 60, herbs = {}, ores = {} },
}
-- Wintersbite grows only in Alterac Mountains (Classic)
table.insert(Z.list[1416].herbs, WINTER)

-- Zones around a character level, nearest range first (cities excluded).
function Z.ForLevel(level)
  local out = {}
  for id, z in pairs(Z.list) do
    if not z.city then
      local dist = 0
      if level < z.min then dist = z.min - level elseif level > z.max then dist = level - z.max end
      out[#out + 1] = { id = id, zone = z, distance = dist }
    end
  end
  table.sort(out, function(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    return a.zone.min < b.zone.min
  end)
  return out
end

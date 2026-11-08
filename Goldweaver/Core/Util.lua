-- Goldweaver: small shared helpers. Pure Lua where possible so the headless tests can load this file.
local ADDON, ns = ...

ns.Util = {}

-- Formats copper as "12g 34s 56c". Pure function, used by tests.
function ns.Util.Money(copper)
  copper = math.floor(tonumber(copper) or 0)
  local neg = copper < 0
  if neg then copper = -copper end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local out
  if g > 0 then out = string.format("%dg %02ds %02dc", g, s, c)
  elseif s > 0 then out = string.format("%ds %02dc", s, c)
  else out = string.format("%dc", c) end
  return neg and ("-" .. out) or out
end

-- Net proceeds after the auction house cut (default 5 %).
function ns.Util.AfterCut(copper, cut)
  cut = cut or (ns.db and ns.db.settings.ahCut) or 0.05
  return math.floor((tonumber(copper) or 0) * (1 - cut))
end

function ns.Util.Round(x, digits)
  local m = 10 ^ (digits or 0)
  return math.floor(x * m + 0.5) / m
end

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

-- Short form for overviews: "151g", "12g 30s", "75s", "40c". Pure function, used by tests.
function ns.Util.MoneyShort(copper)
  copper = math.floor(tonumber(copper) or 0)
  local neg = copper < 0
  if neg then copper = -copper end
  local g, s = math.floor(copper / 10000), math.floor((copper % 10000) / 100)
  local out
  if g >= 100 or (g > 0 and s == 0) then out = g .. "g"
  elseif g > 0 then out = ("%dg %ds"):format(g, s)
  elseif s > 0 then out = s .. "s"
  else out = (copper % 100) .. "c" end
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

-- "just now", "12 min ago", "3 h ago", "2 days ago" (translated); nil time = "never".
function ns.Util.Ago(t)
  local L = ns.L
  if not t then return L["never"] end
  local d = time() - t
  if d < 90 then return L["just now"] end
  if d < 3600 then return (L["%d min ago"]):format(math.floor(d / 60)) end
  if d < 86400 then return (L["%d h ago"]):format(math.floor(d / 3600)) end
  return (L["%d days ago"]):format(math.floor(d / 86400))
end

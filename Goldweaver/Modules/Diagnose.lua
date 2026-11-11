-- Goldweaver: automatic diagnosis. Turns raw signals (errors, detached handlers, missing APIs, data gaps, checks)
-- into plain-language findings with a fix. Fixes that are safe run by themselves; the rest get a button.
-- Runs 20 s after login, after any recorded error (debounced) and before every debug report, so neither the player
-- nor the developer has to read logs. The latest result is stored in GoldweaverDB.debug.diagnosis.
--
-- Public API (ns.Diagnose)
--   Run() -> findings                finding = { id, severity = "error"|"warn"|"info", title, detail, fixLabel?, fix?, fixed? }
--                                    rules pass English keys (title, detail, fixLabel) with optional format arguments targs/dargs
--                                    (an argument { key } is translated); Run() returns them translated, the stored copy stays English
--   Latest() -> findings
--   RegisterRule(id, fn(add))  ★     add{...} appends a finding (id, severity, title, detail, targs, dargs, fixLabel, fix, fixed)
local ADDON, ns = ...
local L = ns.L

local Diagnose = { rules = {}, latest = {} }
ns.Diagnose = Diagnose

local SEVERITY = { error = 1, warn = 2, info = 3 }

function Diagnose.RegisterRule(id, fn)
  Diagnose.rules[#Diagnose.rules + 1] = { id = id, fn = fn }
end

local R = Diagnose.RegisterRule

R("errors", function(add)
  if #ns.Health.detached > 0 then
    add({ id = "detached", severity = "error", title = "%d function(s) disabled after errors", targs = { #ns.Health.detached },
      detail = "%s. Restarts on the next /reload; the error text is in the report.", dargs = { table.concat(ns.Health.detached, ", ") },
      fixLabel = "Reload", fix = function() if ReloadUI then ReloadUI() end end })
  elseif #ns.Health.errors > 0 then
    local e = ns.Health.errors[#ns.Health.errors]
    add({ id = "error", severity = "warn", title = "An error was caught", detail = e.where .. ": " .. e.err })
  end
end)

R("interface", function(add)
  local _, _, _, interface = GetBuildInfo()
  if interface and not ns.Secret.IsSecret(interface) and interface ~= ns.INTERFACE then
    add({ id = "interface", severity = "warn", title = "New game patch detected",
      detail = "Client %s, Goldweaver built for %s. Features whose game API is missing switch off silently.", dargs = { tostring(interface), tostring(ns.INTERFACE) } })
  end
end)

R("features", function(add)
  for _, row in ipairs(ns.Features.Status()) do
    if not row.ok and not ns.Features.Disabled(row.name) then
      add({ id = "feature-" .. row.name, severity = "warn", title = "%s not available", targs = { { row.label } }, detail = row.detail })
    end
  end
end)

R("roles", function(add)
  local market = ns.Chars.MarketKey()
  if #ns.Chars.ByRole("processor", market) == 0 then
    add({ id = "noProcessor", severity = "info", title = "No processor yet",
      detail = "When an alt with a crafting profession logs in, it becomes the processor automatically. Otherwise set it in the Team tab.",
      fixLabel = "Open Team", fix = function() ns.UI.Open("team") end })
  end
end)

R("books", function(add)
  local me = ns.Chars.Current()
  if not me then return end
  local missing = ns.Adapter.MissingBooks(me)
  if #missing > 0 then
    add({ id = "books", severity = "warn", title = "%d profession(s) not read", targs = { #missing },
      detail = "Goldweaver reads the recipes when a profession is opened. One click opens it once.",
      fixLabel = "Load recipes", fix = function() ns.Adapter.Open(missing[1].skillLine) end })
  end
end)

R("prices", function(add)
  local market = ns.db.prices[ns.Chars.MarketKey()]
  local hasOwn = market and next(market) ~= nil
  local hasAuctionator = ns.API.External.HasAuctionator()
  if not hasOwn and not hasAuctionator then
    add({ id = "prices", severity = "info", title = "No market prices yet",
      detail = "Search the auction house once or install Auctionator; until then Goldweaver uses vendor prices." })
  end
end)

-- safe automatic fix: a panel dragged off-screen comes back
R("panel", function(add)
  local f = _G.GoldweaverPanel
  if not (f and f.GetLeft and UIParent) then return end
  local left, top = f:GetLeft(), f:GetTop()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  if left and top and w and h and (left > w - 20 or top < 20 or left < -200 or top > h + 50) then
    ns.db.settings.panelPos = nil
    f:ClearAllPoints()
    f:SetPoint("RIGHT", UIParent, "RIGHT", -16, -150)
    add({ id = "panelPos", severity = "info", title = "Side panel was off-screen", detail = "Position reset.", fixed = true })
  end
end)

R("storage", function(add)
  local n = 0
  for _, market in pairs(ns.db.prices) do for _ in pairs(market) do n = n + 1 end end
  if n > 20000 then
    ns.Price.Prune(math.max(7, (ns.db.settings.priceHistoryDays or 30) - 10))
    add({ id = "storage", severity = "info", title = "Price data trimmed", detail = "%d entries; old daily values trimmed, current prices stay.", dargs = { n }, fixed = true })
  end
end)

-- Finding text: key + optional format arguments; an argument { key } is itself a key and is translated.
local function render(key, args, translate)
  if not key then return nil end
  local text = translate and L[key] or key
  if not args then return text end
  local shown = {}
  for i, a in ipairs(args) do
    if type(a) == "table" then shown[i] = translate and L[a[1]] or a[1] else shown[i] = a end
  end
  return text:format(unpack(shown))
end

function Diagnose.Run()
  local findings = {}
  local function add(f) findings[#findings + 1] = f end
  for _, rule in ipairs(Diagnose.rules) do
    local ok, err = pcall(rule.fn, add)
    if not ok then findings[#findings + 1] = { id = "rule-" .. rule.id, severity = "warn", title = "Diagnosis rule %s failed", targs = { rule.id }, detail = tostring(err) } end
  end
  table.sort(findings, function(a, b) return (SEVERITY[a.severity] or 9) < (SEVERITY[b.severity] or 9) end)
  local stored = {}
  for _, f in ipairs(findings) do
    stored[#stored + 1] = { id = f.id, severity = f.severity, title = render(f.title, f.targs, false), detail = render(f.detail, f.dargs, false), fixed = f.fixed }
    f.title = render(f.title, f.targs, true)
    f.detail = render(f.detail, f.dargs, true)
    if f.fixLabel then f.fixLabel = L[f.fixLabel] end
  end
  Diagnose.latest = findings
  ns.db.debug.diagnosis = { when = time(), findings = stored }
  if ns.Minimap and ns.Minimap.SetAlert then
    local red = false
    for _, f in ipairs(findings) do if f.severity == "error" then red = true end end
    ns.Minimap.SetAlert(red or (ns.Autopilot and ns.Autopilot.status.health and ns.Autopilot.status.health.red > 0))
  end
  return findings
end

function Diagnose.Latest() return Diagnose.latest end

-- Debounced run after errors: the player sees one clear line instead of a stack trace.
local pending = false
function Diagnose.OnError()
  if pending or not ns.db then return end
  pending = true
  C_Timer.After(3, function()
    pending = false
    local findings = Diagnose.Run()
    local top = findings[1]
    if top and top.severity == "error" and not Diagnose.announced then
      Diagnose.announced = true
      ns.Print((L["%s. Details in the guide below (automatic report saved)."]):format(top.title))
      if ns.Debug and ns.Debug.Build then pcall(ns.Debug.Build) end
    end
  end)
end

ns:RegisterModule("Diagnose", {
  Init = function()
    local record = ns.Health.Record
    ns.Health.Record = function(where, err)
      record(where, err)
      if Diagnose.OnError then Diagnose.OnError() end
    end
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(20, function() pcall(Diagnose.Run) end) end, "Diagnose")
  end,
  SelfTest = function()
    local n = #Diagnose.latest
    return { { name = L["Diagnosis"], ok = true, detail = n == 0 and L["no findings"] or (L["%d finding(s): %s"]):format(n, Diagnose.latest[1].title) } }
  end,
})

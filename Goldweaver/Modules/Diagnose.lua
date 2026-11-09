-- Goldweaver: automatic diagnosis. Turns raw signals (errors, detached handlers, missing APIs, data gaps, checks)
-- into plain-language findings with a fix. Fixes that are safe run by themselves; the rest get a button.
-- Runs 20 s after login, after any recorded error (debounced) and before every debug report, so neither the player
-- nor the developer has to read logs. The latest result is stored in GoldweaverDB.debug.diagnosis.
--
-- Public API (ns.Diagnose)
--   Run() -> findings                finding = { id, severity = "error"|"warn"|"info", title, detail, fixLabel?, fix?, fixed? }
--   Latest() -> findings
--   RegisterRule(id, fn(add))  ★     add{...} appends a finding
local ADDON, ns = ...

local Diagnose = { rules = {}, latest = {} }
ns.Diagnose = Diagnose

local SEVERITY = { error = 1, warn = 2, info = 3 }

function Diagnose.RegisterRule(id, fn)
  Diagnose.rules[#Diagnose.rules + 1] = { id = id, fn = fn }
end

local R = Diagnose.RegisterRule

R("errors", function(add)
  if #ns.Health.detached > 0 then
    add({ id = "detached", severity = "error", title = ("%d Funktion(en) nach Fehlern abgeschaltet"):format(#ns.Health.detached),
      detail = table.concat(ns.Health.detached, ", ") .. ". Startet beim nächsten /reload neu; der Fehlertext liegt im Bericht.",
      fixLabel = "Neu laden", fix = function() if ReloadUI then ReloadUI() end end })
  elseif #ns.Health.errors > 0 then
    local e = ns.Health.errors[#ns.Health.errors]
    add({ id = "error", severity = "warn", title = "Ein Fehler wurde abgefangen", detail = e.where .. ": " .. e.err })
  end
end)

R("interface", function(add)
  local _, _, _, interface = GetBuildInfo()
  if interface and not ns.Secret.IsSecret(interface) and interface ~= ns.INTERFACE then
    add({ id = "interface", severity = "warn", title = "Neuer Spiel-Patch erkannt",
      detail = ("Client %s, Goldweaver für %s gebaut. Funktionen, deren Spiel-API fehlt, schalten sich still ab."):format(tostring(interface), tostring(ns.INTERFACE)) })
  end
end)

R("features", function(add)
  for _, row in ipairs(ns.Features.Status()) do
    if not row.ok and not ns.Features.Disabled(row.name) then
      add({ id = "feature-" .. row.name, severity = "warn", title = row.label .. " nicht verfügbar", detail = row.detail })
    end
  end
end)

R("roles", function(add)
  local market = ns.Chars.MarketKey()
  if #ns.Chars.ByRole("processor", market) == 0 then
    add({ id = "noProcessor", severity = "info", title = "Noch kein Verarbeiter",
      detail = "Loggt ein Twink mit Herstellungsberuf ein, wird er automatisch Verarbeiter. Sonst im Team-Reiter festlegen.",
      fixLabel = "Team öffnen", fix = function() ns.UI.Open("team") end })
  end
end)

R("books", function(add)
  local me = ns.Chars.Current()
  if not me then return end
  local missing = ns.Adapter.MissingBooks(me)
  local blocked = ns.Autopilot and ns.Autopilot.status.blocked
  if #missing > 0 and blocked then
    add({ id = "books", severity = "warn", title = ("%d Beruf(e) nicht eingelesen"):format(#missing),
      detail = "Das Hintergrund-Lesen wurde vom Spiel blockiert. Ein Klick öffnet den Beruf einmal.",
      fixLabel = "Rezepte laden", fix = function() ns.Adapter.Open(missing[1].skillLine) end })
  end
end)

R("prices", function(add)
  local market = ns.db.prices[ns.Chars.MarketKey()]
  local hasOwn = market and next(market) ~= nil
  local hasAuctionator = Auctionator and Auctionator.API and Auctionator.API.v1
  if not hasOwn and not hasAuctionator then
    add({ id = "prices", severity = "info", title = "Noch keine Marktpreise",
      detail = "Einmal im Auktionshaus suchen oder Auctionator installieren; bis dahin rechnet Goldweaver mit Händlerpreisen." })
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
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -280)
    add({ id = "panelPos", severity = "info", title = "Seitenpanel war außerhalb des Bildschirms", detail = "Position zurückgesetzt.", fixed = true })
  end
end)

R("storage", function(add)
  local n = 0
  for _, market in pairs(ns.db.prices) do for _ in pairs(market) do n = n + 1 end end
  if n > 20000 then
    ns.Price.Prune(math.max(7, (ns.db.settings.priceHistoryDays or 30) - 10))
    add({ id = "storage", severity = "info", title = "Preisdaten verkleinert", detail = ("%d Einträge; alte Tageswerte gekürzt, aktuelle Preise bleiben."):format(n), fixed = true })
  end
end)

function Diagnose.Run()
  local findings = {}
  local function add(f) findings[#findings + 1] = f end
  for _, rule in ipairs(Diagnose.rules) do
    local ok, err = pcall(rule.fn, add)
    if not ok then findings[#findings + 1] = { id = "rule-" .. rule.id, severity = "warn", title = "Diagnoseregel " .. rule.id .. " fehlgeschlagen", detail = tostring(err) } end
  end
  table.sort(findings, function(a, b) return (SEVERITY[a.severity] or 9) < (SEVERITY[b.severity] or 9) end)
  Diagnose.latest = findings
  local stored = {}
  for _, f in ipairs(findings) do stored[#stored + 1] = { id = f.id, severity = f.severity, title = f.title, detail = f.detail, fixed = f.fixed } end
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
      ns.Print(top.title .. ". Details im Leitfaden unten (automatischer Bericht gespeichert).")
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
    return { { name = "Diagnose", ok = true, detail = n == 0 and "keine Befunde" or (n .. " Befund(e): " .. Diagnose.latest[1].title) } }
  end,
})

-- Goldweaver: single event frame with a handler table, a secret-value guard and error isolation.
-- Usage: ns.Events:On("BAG_UPDATE_DELAYED", function(event, ...) end, "Inventory")
-- Handlers are skipped when any event argument is a secret value (counted in ns.Events.skipped).
-- A handler that errors is counted; after MAX_ERRORS it is detached so one broken module cannot spam the session.
-- Errors are kept in ns.Health.errors (and GoldweaverDB.debug.errors) for the debug report.
local ADDON, ns = ...

local frame = CreateFrame("Frame")
local handlers = {}
local MAX_ERRORS = 5

ns.Events = { frame = frame, skipped = 0 }
ns.Health = { errors = {}, detached = {} }

function ns.Health.Record(where, err)
  local entry = { t = time and time() or 0, where = where, err = tostring(err) }
  table.insert(ns.Health.errors, entry)
  while #ns.Health.errors > 30 do table.remove(ns.Health.errors, 1) end
  if ns.db then
    ns.db.debug = ns.db.debug or {}
    ns.db.debug.errors = ns.db.debug.errors or {}
    table.insert(ns.db.debug.errors, entry)
    while #ns.db.debug.errors > 50 do table.remove(ns.db.debug.errors, 1) end
  end
end

function ns.Events:On(event, fn, owner)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], { fn = fn, owner = owner or "?", errors = 0 })
end

function ns.Events:Off(event, fn)
  local list = handlers[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].fn == fn then table.remove(list, i) end
  end
  if #list == 0 then
    handlers[event] = nil
    frame:UnregisterEvent(event)
  end
end

-- Registered events with handler counts, for the debug report.
function ns.Events:Summary()
  local rows = {}
  for event, list in pairs(handlers) do rows[#rows + 1] = { event = event, handlers = #list } end
  table.sort(rows, function(a, b) return a.event < b.event end)
  return rows
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  if ns.Secret.Any(...) then
    ns.Events.skipped = ns.Events.skipped + 1
    return
  end
  for i = #list, 1, -1 do
    local h = list[i]
    local ok, err = pcall(h.fn, event, ...)
    if not ok then
      h.errors = h.errors + 1
      ns.Health.Record(event .. " (" .. h.owner .. ")", err)
      if h.errors == 1 then ns.Print("Fehler in " .. event .. " (" .. h.owner .. "): " .. tostring(err)) end
      if h.errors >= MAX_ERRORS then
        table.remove(list, i)
        ns.Health.detached[#ns.Health.detached + 1] = event .. " (" .. h.owner .. ")"
        ns.Print(("Handler für %s (%s) nach %d Fehlern abgeschaltet. /gw debug run zeigt Details."):format(event, h.owner, MAX_ERRORS))
      end
    end
  end
end)

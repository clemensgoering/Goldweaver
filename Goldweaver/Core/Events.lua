-- Goldweaver: single event frame with a handler table, a secret-value guard and error isolation.
--
-- Public API
--   ns.Events:On(event, fn, owner?)   register fn(event, ...); owner = module name for error reports (defaults to the
--                                     registering file, taken from the call stack)
--   ns.Events:Off(event, fn)          remove a handler
--   ns.Events:Summary()               { {event, handlers} } for the debug report
--   ns.Events.skipped                 how many deliveries the secret-value guard skipped
--   ns.Health.Record(where, err)      store an error (session list + GoldweaverDB.debug.errors)
--   ns.Health.errors / .detached      error entries / handlers detached after MAX_ERRORS failures
--
-- Rules: handlers are skipped when any event argument is a secret value; a handler that fails MAX_ERRORS times is
-- detached so one broken module cannot spam the session. Handlers run newest-first (reverse registration order).
local ADDON, ns = ...
local L = ns.L

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

-- Owner name from the call stack when none is given: "Modules/Mail.lua" -> "Mail".
local function inferOwner()
  local stack = debugstack and debugstack(3, 1, 0) or (debug and debug.traceback and debug.traceback("", 3)) or ""
  local file = stack:match("Goldweaver[/\\]([%w_/\\]+)%.lua")
  if file then return (file:match("([%w_]+)$")) end
  return "?"
end

-- Returns true when registered. An event unknown to this client (renamed or removed by a patch) is recorded in
-- ns.Health and skipped instead of raising, so the registering module still starts (verified need: Forever has no
-- BROWSE_SEARCH_RESULTS_UPDATED).
function ns.Events:On(event, fn, owner)
  assert(type(event) == "string" and type(fn) == "function", "Events:On(event, fn, owner?)")
  owner = owner or inferOwner()
  if not handlers[event] then
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    if not ok then
      ns.Health.Record("RegisterEvent " .. event .. " (" .. owner .. ")", err)
      ns.Events.unknown = ns.Events.unknown or {}
      ns.Events.unknown[#ns.Events.unknown + 1] = event .. " (" .. owner .. ")"
      return false
    end
    handlers[event] = {}
  end
  table.insert(handlers[event], { fn = fn, owner = owner, errors = 0 })
  return true
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
      if h.errors == 1 then ns.Print((L["Error in %s (%s): %s"]):format(event, h.owner, tostring(err))) end
      if h.errors >= MAX_ERRORS then
        table.remove(list, i)
        ns.Health.detached[#ns.Health.detached + 1] = event .. " (" .. h.owner .. ")"
        ns.Print(L["Handler for %s (%s) disabled after %d errors. /gw debug run shows details."]:format(event, h.owner, MAX_ERRORS))
      end
    end
  end
end)

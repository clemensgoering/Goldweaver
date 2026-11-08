-- Goldweaver: single event frame with a handler table and a secret-value guard.
-- Usage: ns.Events:On("BAG_UPDATE_DELAYED", function(event, ...) end)
-- Handlers are skipped when any event argument is a secret value (counted in ns.Events.skipped).
local ADDON, ns = ...

local frame = CreateFrame("Frame")
local handlers = {}

ns.Events = { frame = frame, skipped = 0 }

function ns.Events:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end

function ns.Events:Off(event, fn)
  local list = handlers[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == fn then table.remove(list, i) end
  end
  if #list == 0 then
    handlers[event] = nil
    frame:UnregisterEvent(event)
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  if ns.Secret.Any(...) then
    ns.Events.skipped = ns.Events.skipped + 1
    return
  end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then ns.Print("error in " .. event .. ": " .. tostring(err)) end
  end
end)

-- Goldweaver: side panel "Unterwegs" - a compact tracker docked at the screen edge like the quest objective tracker
-- or the RestedXP guide frame (docs/14-UI-FUEHRUNG.md). Shows the zone, the current guide step and the top items
-- to gather or loot here, coloured by skill. Click the header to collapse, drag to move, /gw panel to toggle.
--
-- Public API (ns.Panel): Refresh(), Toggle()
local ADDON, ns = ...

local Panel = {}
ns.Panel = Panel

local WIDTH, ROWS = 250, 5
local frame, header, collapse, stepRow, rows, routeText
local pending = false

local function create()
  if frame then return end
  frame = CreateFrame("Frame", "GoldweaverPanel", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, 60)
  -- default: right edge below the middle, clear of the quest tracker under the minimap (playtest 09.11.2026)
  frame:SetPoint("RIGHT", UIParent, "RIGHT", -16, -150)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  local function startMove() frame:StartMoving() end
  local function stopMove()
    frame:StopMovingOrSizing()
    local point, _, rel, x, y = frame:GetPoint()
    ns.db.settings.panelPos = { point, rel, x, y }
  end
  frame:SetScript("OnDragStart", startMove)
  frame:SetScript("OnDragStop", stopMove)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    frame:SetBackdropColor(0, 0, 0, 0.35)
  end
  local pos = ns.db.settings.panelPos
  if pos then frame:ClearAllPoints(); frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) end

  header = CreateFrame("Button", nil, frame)
  header:SetSize(WIDTH, 22)
  header:SetPoint("TOPLEFT")
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header.text:SetPoint("LEFT", 8, 0); header.text:SetJustifyH("LEFT"); header.text:SetWidth(WIDTH - 40)
  collapse = header:CreateTexture(nil, "OVERLAY")
  collapse:SetSize(14, 14); collapse:SetPoint("RIGHT", -6, 0)
  header:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.UI.Open("field"); return end
    ns.db.settings.panelCollapsed = not ns.db.settings.panelCollapsed
    Panel.Refresh()
  end)
  header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  -- the header covers the frame, so it must carry the drag itself (Shift+drag on the frame never reached it)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", startMove)
  header:SetScript("OnDragStop", stopMove)
  header:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Goldweaver · Unterwegs", 1, 0.82, 0)
    GameTooltip:AddLine("Klick: ein-/ausklappen · Rechtsklick: Details · Ziehen: verschieben · /gw panel reset: Startposition", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  header:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local holder = CreateFrame("Frame", nil, frame)
  holder:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -2)
  holder:SetSize(WIDTH - 8, 10)
  holder.pad, holder.top = 0, 0
  frame.holder = holder
  stepRow = ns.UI.IconRows(holder, 1, WIDTH - 8, 0, 36)
  rows = ns.UI.IconRows(holder, ROWS, WIDTH - 8, -38, 26)
  routeText = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  routeText:SetJustifyH("LEFT"); routeText:SetWidth(WIDTH - 12); routeText:SetWordWrap(true)
end

function Panel.ShouldShow()
  if ns.db.settings.panelHidden then return false end
  local me = ns.Chars.Current()
  return me ~= nil
end

function Panel.Refresh()
  if not Panel.ShouldShow() then if frame then frame:Hide() end return end
  create()
  frame:Show()
  local collapsed = ns.db.settings.panelCollapsed
  collapse:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
  local ok, report = pcall(ns.Field.Analyze)
  if not ok or not report then return end
  header.text:SetText(("Unterwegs · %s"):format(report.name))
  if collapsed then frame.holder:Hide(); frame:SetHeight(22); return end
  frame.holder:Show()

  local step = ns.Steps.Build(1)[1]
  if step then
    stepRow:Set({ { icon = step.icon, item = step.item, text = step.title, sub = step.detail, color = { 1, 0.82, 0 },
      onClick = step.action or function() ns.UI.Open("guide") end } })
  else
    stepRow:Set({ { icon = "Interface\\Icons\\Achievement_General", text = "Nichts Dringendes", sub = "Spielen und sammeln.", color = { 0.7, 0.7, 0.7 } } })
  end

  local data = {}
  for _, r in ipairs(report.gather) do
    if #data >= ROWS - 1 then break end
    if r.hasProfession or r.demand then
      local color = r.color and ns.Data.Gathering.COLORS[r.color] or { 0.9, 0.9, 0.9 }
      data[#data + 1] = { item = r.item, text = ns.UI.ItemName(r.item), color = color,
        right = r.demand and ("|cffffd100×%d|r"):format(r.demand.qty) or (r.price and ns.UI.Money(r.price) or "") }
    end
  end
  if report.mobs and report.mobs.cloth and #data < ROWS then
    local m = report.mobs
    data[#data + 1] = { item = m.cloth, text = ns.UI.ItemName(m.cloth), color = { 0.9, 0.9, 0.9 },
      right = m.clothDemand and ("|cffffd100×%d|r"):format(m.clothDemand.qty) or (m.clothPrice and ns.UI.Money(m.clothPrice) or "") }
  end
  rows:Set(data)

  local routeLine = ""
  if report.route and report.route.zones[1] then
    local names = {}
    for i = 1, math.min(3, #report.route.zones) do names[#names + 1] = report.route.zones[i].name end
    routeLine = "Route: " .. table.concat(names, " » ")
  elseif report.zone and report.fit == "low" then
    routeLine = "Zu leicht für dich. Bessere Zonen: Rechtsklick auf die Kopfzeile."
  end
  routeText:ClearAllPoints()
  routeText:SetPoint("TOPLEFT", frame.holder, "TOPLEFT", 2, -38 - #data * 28 - 2)
  routeText:SetText(routeLine)
  frame:SetHeight(22 + 2 + 38 + #data * 28 + (routeLine ~= "" and 26 or 4))
end

function Panel.Toggle()
  ns.db.settings.panelHidden = not ns.db.settings.panelHidden
  Panel.Refresh()
end

local function schedule()
  if pending then return end
  pending = true
  C_Timer.After(1, function() pending = false; pcall(Panel.Refresh) end)
end

ns:RegisterModule("Panel", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(6, schedule) end, "Panel")
    for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED" }) do
      ns.Events:On(e, schedule, "Panel")
    end
    ns.Events:On("PLAYER_REGEN_DISABLED", function() if frame then frame:SetAlpha(0.4) end end, "Panel")
    ns.Events:On("PLAYER_REGEN_ENABLED", function() if frame then frame:SetAlpha(1) end end, "Panel")
  end,
  SelfTest = function()
    return { { name = "Seitenpanel", ok = true, detail = Panel.ShouldShow() and (frame and frame:IsShown() and "sichtbar" or "wird aufgebaut") or "ausgeblendet" } }
  end,
})

ns.Slash.Register("panel", function(arg)
  if arg == "reset" then
    ns.db.settings.panelPos = nil
    if frame then frame:ClearAllPoints(); frame:SetPoint("RIGHT", UIParent, "RIGHT", -16, -150) end
    return ns.Print("Seitenpanel auf Startposition gesetzt.")
  end
  Panel.Toggle()
end, "toggle the side panel (reset = back to the start position)")

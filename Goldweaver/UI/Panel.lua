-- Goldweaver: side panel "On the road" - a compact tracker docked at the screen edge like the quest objective tracker
-- or the RestedXP guide frame (docs/14-UI-FUEHRUNG.md). Shows the zone, the current guide step and the top items
-- to gather or loot here, coloured by skill. Click the header to collapse, drag to move, /gw panel to toggle.
--
-- Public API (ns.Panel): Refresh(), Toggle()
local ADDON, ns = ...
local L = ns.L

local Panel = {}
ns.Panel = Panel

local WIDTH, ROWS = 250, 5
local frame, header, collapse, stepRow, rows, coopRows, routeText
local pending = false

local function create()
  if frame then return end
  frame = CreateFrame("Frame", "GoldweaverPanel", UIParent)
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
  ns.UI.Skin(frame, "tracker")
  local pos = ns.db.settings.panelPos
  if pos then frame:ClearAllPoints(); frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) end

  header = CreateFrame("Button", nil, frame)
  header:SetSize(WIDTH, 22)
  header:SetPoint("TOPLEFT")
  header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header.text:SetPoint("LEFT", 8, 0); header.text:SetJustifyH("LEFT"); header.text:SetWidth(WIDTH - 40); header.text:SetWordWrap(false)
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
    GameTooltip:AddLine("Goldweaver · " .. L["On the road"], 1, 0.82, 0)
    GameTooltip:AddLine(L["Click: collapse/expand · Right-click: details · Drag: move · /gw panel reset: start position"], 1, 1, 1, true)
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
  coopRows = ns.UI.ProgressRows(holder, ROWS - 1, WIDTH - 8, -38, 28)
  routeText = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  routeText:SetJustifyH("LEFT"); routeText:SetWidth(WIDTH - 12); routeText:SetWordWrap(true)
  if routeText.SetMaxLines then routeText:SetMaxLines(2) end -- the frame reserves two lines; longer routes end with "…"
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
  header.text:SetText((L["On the road · %s"]):format(report.name))
  if collapsed then frame.holder:Hide(); frame:SetHeight(22); return end
  frame.holder:Show()

  local step = ns.Steps.Build(1)[1]
  if step then
    stepRow:Set({ { icon = step.icon, item = step.item, text = step.title, sub = step.detail, color = { 1, 0.82, 0 },
      onClick = step.action or function() ns.UI.Open("guide") end } })
  else
    stepRow:Set({ { icon = "Interface\\Icons\\Achievement_General", text = L["Nothing urgent"], sub = L["Play and gather."], color = { 0.7, 0.7, 0.7 } } })
  end

  -- main with a twink: the gather order (what the twink still needs, gatherable here first) instead of the zone list
  local view = ns.Coop and ns.Coop.Needs()
  local me = ns.Chars.Current()
  if view and me == view.gatherer then
    local who = view.crafter.firstName or view.crafter.name
    header.text:SetText((L["Gather for %s · %s"]):format(who, report.name))
    local data, hereNames = {}, {}
    for _, r in ipairs(view.rows) do
      if r.source ~= "vendor" and r.have < r.need then
        if #data < ROWS - 1 then
          data[#data + 1] = { item = r.item, text = ns.UI.ItemName(r.item), have = r.have, need = r.need, mail = r.mail,
            note = r.here and { L["here"], 0.37, 0.83, 0.37 } or nil }
        end
        if r.here and #hereNames < 2 then hereNames[#hereNames + 1] = ns.UI.ItemName(r.item) end
      end
    end
    rows:Set({})
    coopRows:Set(data)
    local line = (L["You carry: +%d skill points for %s"]):format(view.fromGatherer, who)
    if #hereNames > 0 then line = (L["Here: %s"]):format(table.concat(hereNames, ", ")) .. " · " .. line end
    local sess = ns.Coop.session
    if sess.items > 0 then line = line .. "\n" .. (L["This session: %d items · +%d skill · %s"]):format(sess.items, sess.points, ns.Util.Money(sess.value)) end
    routeText:ClearAllPoints()
    routeText:SetPoint("TOPLEFT", frame.holder, "TOPLEFT", 2, -38 - #data * 28 - 2)
    routeText:SetText("|cffffd27a" .. line .. "|r")
    frame:SetHeight(22 + 2 + 38 + #data * 28 + (sess.items > 0 and 44 or 30))
    return
  end
  coopRows:Set({})

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
    routeLine = (L["Route: %s"]):format(table.concat(names, " » "))
  elseif report.zone and report.fit == "low" then
    routeLine = L["Too easy for you. Better zones: right-click the header."]
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
    return { { name = "Side panel", ok = true, detail = Panel.ShouldShow() and (frame and frame:IsShown() and "visible" or "being built") or "hidden" } }
  end,
})

ns.Slash.Register("panel", function(arg)
  if arg == "reset" then
    ns.db.settings.panelPos = nil
    if frame then frame:ClearAllPoints(); frame:SetPoint("RIGHT", UIParent, "RIGHT", -16, -150) end
    return ns.Print(L["Side panel reset to its start position."])
  end
  Panel.Toggle()
end, "toggle the side panel (reset = back to the start position)")

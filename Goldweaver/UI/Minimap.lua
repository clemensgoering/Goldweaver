-- Goldweaver: minimap button with a badge. Left click opens the Goldweaver window, right click opens the
-- Unterwegs tab. Drag to move around the minimap (angle saved). No library dependency.
local ADDON, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_

local ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local button, badgeText, badgeBg

local function angleFromSettings()
  return (ns.db and ns.db.settings and ns.db.settings.minimapAngle) or 200
end

local function place(angle)
  if not button or not Minimap then return end
  local rad = math.rad(angle)
  local radius = (Minimap:GetWidth() / 2) + 6
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

-- Runs only while the button is being dragged (bounded OnUpdate, cleared on drag stop).
local function onDragUpdate()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  local angle = math.deg(math.atan2(cy - my, cx - mx))
  if angle < 0 then angle = angle + 360 end
  ns.db.settings.minimapAngle = angle
  place(angle)
end

local badgeCount, alert = 0, false

local function renderBadge()
  if not badgeText then return end
  if alert then
    badgeText:SetText("!")
    badgeBg:SetColorTexture(0.9, 0.45, 0.1, 0.95)
    badgeBg:Show(); badgeText:Show()
  elseif badgeCount > 0 then
    badgeText:SetText(badgeCount > 99 and "99+" or tostring(badgeCount))
    badgeBg:SetColorTexture(0.75, 0.15, 0.15, 0.95)
    badgeBg:Show(); badgeText:Show()
  else
    badgeBg:Hide(); badgeText:Hide()
  end
end

-- Count badge: characters without a role.
function Minimap_.SetBadge(n)
  badgeCount = tonumber(n) or 0
  renderBadge()
end

-- Alert badge "!" from the login self test (Modules/Autopilot.lua).
function Minimap_.SetAlert(on)
  alert = on and true or false
  renderBadge()
end

function Minimap_.SetShown(shown)
  if not button then return end
  if shown then button:Show() else button:Hide() end
end

local function tooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("Goldweaver", 0.83, 0.66, 0.31)
  GameTooltip:AddLine("Linksklick: Fenster öffnen", 1, 1, 1)
  GameTooltip:AddLine("Rechtsklick: Unterwegs (diese Zone)", 1, 1, 1)
  GameTooltip:AddLine("Ziehen: Button verschieben", 0.7, 0.7, 0.7)
  local unassigned = ns.Chars and ns.Chars.Unassigned and ns.Chars.Unassigned() or 0
  if unassigned > 0 then
    GameTooltip:AddLine(("%d Charakter(e) ohne Rolle"):format(unassigned), 1, 0.5, 0.2)
  end
  -- explain the "!" badge right here: the top finding of the automatic diagnosis
  local finding = alert and ns.Diagnose and ns.Diagnose.Latest()[1]
  if finding then
    GameTooltip:AddLine("! " .. finding.title, 1, 0.5, 0.2, true)
    if finding.detail then GameTooltip:AddLine(finding.detail, 0.8, 0.8, 0.8, true) end
  end
  if ns.Chars and ns.Chars.MarketKey then
    GameTooltip:AddLine("Markt: " .. ns.Chars.MarketKey(), 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end

local function create()
  if button or not Minimap then return end
  button = CreateFrame("Button", "GoldweaverMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local overlay = button:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetTexture(ICON)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetPoint("TOPLEFT", 7, -6)

  badgeBg = button:CreateTexture(nil, "OVERLAY", nil, 1)
  badgeBg:SetSize(16, 16)
  badgeBg:SetColorTexture(0.75, 0.15, 0.15, 0.95)
  badgeBg:SetPoint("BOTTOMRIGHT", -2, 2)
  badgeText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  badgeText:SetPoint("CENTER", badgeBg, "CENTER", 0, 0)
  badgeText:SetTextColor(1, 1, 1)
  badgeBg:Hide(); badgeText:Hide()

  button:SetScript("OnEnter", tooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnClick", function(_, mouseButton)
    if not (ns.UI and ns.UI.Toggle) then return ns.Print("window not loaded") end
    if mouseButton == "RightButton" then ns.UI.Open("field") else ns.UI.Toggle() end
  end)

  place(angleFromSettings())
  if ns.db.settings.minimapHidden then button:Hide() end
end

ns:RegisterModule("Minimap", {
  Init = function()
    create()
    if ns.Chars and ns.Chars.Unassigned then Minimap_.SetBadge(ns.Chars.Unassigned()) end
  end,
  SelfTest = function()
    return {
      { name = "Button erzeugt", ok = button ~= nil, detail = button and (button:IsShown() and "sichtbar" or "versteckt") or "nein" },
      { name = "Winkel gespeichert", ok = true, detail = tostring(angleFromSettings()) },
    }
  end,
})

ns.Slash.Register("minimap", function(arg)
  if arg == "hide" or arg == "off" then ns.db.settings.minimapHidden = true; Minimap_.SetShown(false)
  elseif arg == "show" or arg == "on" then ns.db.settings.minimapHidden = false; Minimap_.SetShown(true)
  else ns.Print("usage: /gw minimap show|hide") end
end, "show or hide the minimap button")

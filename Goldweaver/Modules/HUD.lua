-- Goldweaver: one-line HUD (docs/08-UX.md 4.6). Shown for mains once a processor exists; click opens the window.
local ADDON, ns = ...

local HUD = {}
ns.HUD = HUD

local frame, text

local function create()
  if frame then return end
  frame = CreateFrame("Button", "GoldweaverHUD", UIParent, "BackdropTemplate")
  frame:SetSize(420, 22)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -4)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    ns.db.settings.hudPos = { point, rel, x, y }
  end)
  frame:SetClampedToScreen(true)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame:SetBackdropColor(0, 0, 0, 0.55)
    frame:SetBackdropBorderColor(0.5, 0.42, 0.25, 0.7)
  end
  text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  frame:SetScript("OnClick", function() if ns.UI then ns.UI.Open("heute") end end)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Goldweaver", 0.83, 0.66, 0.31)
    GameTooltip:AddLine("Klick: Fenster · Ziehen: verschieben · /gw hud off blendet aus", 1, 1, 1)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local pos = ns.db.settings.hudPos
  if pos then frame:ClearAllPoints(); frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) end
end

function HUD.ShouldShow()
  if ns.db.settings.hudOff then return false end
  if ns.db.settings.hudOn then return true end
  local me = ns.Chars.Current()
  return me ~= nil and me.role == "main"
end

function HUD.Refresh()
  if not HUD.ShouldShow() then if frame then frame:Hide() end return end
  create()
  local parts = {}
  local count, value, target = ns.Mail.Pending()
  if target then parts[#parts + 1] = ("Für %s: %s (%d)"):format(target.firstName or target.name, ns.Util.Money(value), count)
  else parts[#parts + 1] = "Kein Verarbeiter gesetzt" end
  local delta = ns.Ledger.SessionDelta()
  parts[#parts + 1] = ("Session %s%s"):format(delta >= 0 and "+" or "", ns.Util.Money(delta))
  text:SetText(table.concat(parts, "  ·  "))
  frame:SetWidth(math.max(220, text:GetStringWidth() + 24))
  frame:Show()
  if ns.Checks then ns.Checks.Pass("hud", table.concat(parts, " · ")) end
end

ns:RegisterModule("HUD", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(4, HUD.Refresh) end, "HUD")
  end,
  SelfTest = function()
    return { { name = "HUD", ok = true, detail = HUD.ShouldShow() and ("sichtbar: " .. (text and text:GetText() or "")) or "aus (nur für Mains oder /gw hud on)" } }
  end,
})

ns.Slash.Register("hud", function(arg)
  if arg == "off" then ns.db.settings.hudOff = true; ns.db.settings.hudOn = nil
  elseif arg == "on" then ns.db.settings.hudOn = true; ns.db.settings.hudOff = nil
  elseif arg == "auto" then ns.db.settings.hudOn = nil; ns.db.settings.hudOff = nil
  else return ns.Print("usage: /gw hud on|off|auto") end
  HUD.Refresh()
end, "HUD line on|off|auto (auto = shown for mains)")

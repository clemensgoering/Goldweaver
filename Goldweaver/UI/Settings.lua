-- Goldweaver: settings in the Blizzard options (Esc → Optionen → AddOns → Goldweaver), where players expect them.
-- Falls back to a small standalone window if the Settings API is missing. At most ten switches, all with defaults
-- that work (docs/08-UX.md rule 7).
--
-- Public API (ns.Settings): Open()
local ADDON, ns = ...

local Settings_ = {}
ns.Settings = Settings_

local panel, category

local function defs()
  local s = ns.db.settings
  return {
    { "Seitenpanel 'Unterwegs' anzeigen", function() return s.panelHidden ~= true end, function(on) s.panelHidden = not on; if ns.Panel then ns.Panel.Refresh() end end },
    { "Minimap-Button anzeigen", function() return not s.minimapHidden end, function(on) s.minimapHidden = not on; if ns.Minimap then ns.Minimap.SetShown(on) end end },
    { "Tooltip-Zeilen anzeigen", function() return not s.tooltipOff end, function(on) s.tooltipOff = not on end },
    { "HUD-Zeile (Session-Gold, Versand) oben anzeigen", function() return ns.HUD.ShouldShow() end, function(on) if on then s.hudOn = true; s.hudOff = nil else s.hudOff = true; s.hudOn = nil end; ns.HUD.Refresh() end },
    { "Berufe beim Login im Hintergrund einlesen", function() return s.autoReadProfessions ~= false end, function(on) s.autoReadProfessions = on end },
    { "AH-Preisvorschlag automatisch eintragen", function() return s.autofillPrice ~= false end, function(on) s.autofillPrice = on end },
    { "Materialien der eigenen Berufe behalten (nicht verschicken)", function() return s.keepOwnMaterials ~= false end, function(on) s.keepOwnMaterials = on end },
    { "Unbestätigte Kisten-Bündel in Empfehlungen nutzen", function() return s.unverifiedCrates == true end, function(on) s.unverifiedCrates = on and true or nil end },
    { "Debug-Ausgaben im Chat", function() return s.debug end, function(on) s.debug = on end },
  }
end

local function build(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Goldweaver")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Alle Einstellungen haben funktionierende Standards. Fenster: /gw · Bericht: /gw debug run")
  f.checks = {}
  for i, d in ipairs(defs()) do
    local c = ns.UI.Check(f, d[1], d[2](), d[3])
    c:SetPoint("TOPLEFT", 16, -60 - (i - 1) * 30)
    f.checks[i] = { check = c, get = d[2] }
  end
  local calc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  calc:SetPoint("TOPLEFT", 16, -60 - #f.checks * 30 - 12)
  calc:SetJustifyH("LEFT")
  f.calc = calc
  f:SetScript("OnShow", function(self)
    for _, c in ipairs(self.checks) do c.check:SetChecked(c.get() and true or false) end
    local s = ns.db.settings
    self.calc:SetText(("Wert je Favor: %s (/gw favor)  ·  Unterbieten um: %s (/gw undercut)  ·  Markt: %s (/gw market)"):format(
      ns.Util.Money(s.favorValueCopper or 500), ns.Util.Money(s.undercutCopper or 1), ns.Chars.MarketKey()))
  end)
  return f
end

function Settings_.Open()
  if category and Settings and Settings.OpenToCategory then
    local id = category.GetID and category:GetID() or category.ID
    if pcall(Settings.OpenToCategory, id) then return end
  end
  -- fallback: standalone window
  if not panel then
    panel = ns.UI.SafeCreate("Frame", UIParent, { "BasicFrameTemplateWithInset", "BackdropTemplate" }, "GoldweaverSettingsWindow")
    panel:SetSize(520, 420); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    tinsert(UISpecialFrames, "GoldweaverSettingsWindow")
    local body = build(panel)
    body:ClearAllPoints(); body:SetPoint("TOPLEFT", 4, -24); body:SetPoint("BOTTOMRIGHT", -4, 4)
  end
  panel:Show()
end

ns:RegisterModule("Settings", {
  Init = function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local ok, err = pcall(function()
      local canvas = CreateFrame("Frame")
      build(canvas)
      category = Settings.RegisterCanvasLayoutCategory(canvas, "Goldweaver")
      Settings.RegisterAddOnCategory(category)
    end)
    if not ok then ns.Health.Record("Settings.Register", err) end
  end,
  SelfTest = function()
    return { { name = "Blizzard-Optionen", ok = true, warn = category == nil, detail = category and "eingetragen" or "Ersatzfenster" } }
  end,
})

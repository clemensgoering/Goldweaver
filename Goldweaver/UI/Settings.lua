-- Goldweaver: settings in the Blizzard options (Esc → Optionen → AddOns → Goldweaver), where players expect them.
-- Falls back to a small standalone window if the Settings API is missing. At most ten switches, all with defaults
-- that work (docs/08-UX.md rule 7).
--
-- Public API (ns.Settings): Open(), AddonState(folder) -> "active" | "disabled" | "missing"
local ADDON, ns = ...

local Settings_ = {}
ns.Settings = Settings_

local panel, category

local function defs()
  local s = ns.db.settings
  local L = ns.L
  return {
    { L["Show the 'On the road' side panel"], function() return s.panelHidden ~= true end, function(on) s.panelHidden = not on; if ns.Panel then ns.Panel.Refresh() end end },
    { L["Show the minimap button"], function() return not s.minimapHidden end, function(on) s.minimapHidden = not on; if ns.Minimap then ns.Minimap.SetShown(on) end end },
    { L["Show tooltip lines"], function() return not s.tooltipOff end, function(on) s.tooltipOff = not on end },
    { L["Show the HUD line (session gold, mail) at the top"], function() return ns.HUD.ShouldShow() end, function(on) if on then s.hudOn = true; s.hudOff = nil else s.hudOff = true; s.hudOn = nil end; ns.HUD.Refresh() end },
    { L["Read professions in the background at login (Forever currently blocks this)"],
      function() return s.autoReadProfessions == true end,
      function(on) s.autoReadProfessions = on and true or nil; if on then ns.db.learned.autoReadBlocked = nil end end },
    { L["Fill in the suggested auction price automatically"], function() return s.autofillPrice ~= false end, function(on) s.autofillPrice = on end },
    { L["Keep materials for your own professions (do not mail them)"], function() return s.keepOwnMaterials ~= false end, function(on) s.keepOwnMaterials = on end },
    { L["Notice when you gather something the twink needs"], function() return s.coopToast ~= false end, function(on) s.coopToast = on end },
    { L["Use unconfirmed crate bundles in recommendations"], function() return s.unverifiedCrates == true end, function(on) s.unverifiedCrates = on and true or nil end },
    { L["Debug output in chat"], function() return s.debug end, function(on) s.debug = on end },
  }
end

-- Optional addons (docs/10-KOMPATIBILITAET.md): none is required. Auctionator adds full auction scans (Forever allows
-- no own full scan), RestedXP the levelling route. Everything else Goldweaver does itself (node memory, alt stock,
-- profit, shopping). { folder, title, what it adds (English key) }
local OPTIONAL = {
  { "Auctionator", "Auctionator", "Recommended: auction prices for every advice from its full scans." },
  { "RXPGuides", "RestedXP", "Optional: the guide shows the zones of your levelling route." },
}

-- "active" | "disabled" (installed, switched off) | "missing"
local function addonState(folder)
  local A = C_AddOns
  if not A then return "missing" end
  local ok, loaded = pcall(A.IsAddOnLoaded, folder)
  if ok and loaded then return "active" end
  if A.DoesAddOnExist then
    local okE, exists = pcall(A.DoesAddOnExist, folder)
    if okE and exists then return "disabled" end
  elseif A.GetAddOnInfo then
    local okI, _, _, _, _, reason = pcall(A.GetAddOnInfo, folder)
    if okI and reason ~= nil and reason ~= "MISSING" then return "disabled" end
  end
  return "missing"
end

local function optionalSection(f, top)
  local L = ns.L
  local head = ns.UI.Section(f, L["OPTIONAL ADDONS"], 560)
  head:SetPoint("TOPLEFT", 16, top)
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 16, top - 20); hint:SetWidth(560); hint:SetJustifyH("LEFT")
  hint:SetText(L["None is required: node memory, stock of your characters, profit and shopping lists are built in."])
  local rows = {}
  for i, a in ipairs(OPTIONAL) do
    local y = top - 42 - (i - 1) * 22
    local name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", 20, y); name:SetWidth(110); name:SetJustifyH("LEFT"); name:SetText(a[2])
    local state = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("LEFT", name, "RIGHT", 4, 0); state:SetWidth(150); state:SetJustifyH("LEFT")
    local what = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    what:SetPoint("LEFT", state, "RIGHT", 4, 0); what:SetWidth(300); what:SetJustifyH("LEFT"); what:SetWordWrap(false)
    what:SetText(L[a[3]])
    rows[i] = { folder = a[1], state = state }
  end
  function rows:Refresh()
    for _, r in ipairs(self) do
      local s = addonState(r.folder)
      if s == "active" then r.state:SetText("|cff60e060" .. L["active"] .. "|r")
      elseif s == "disabled" then r.state:SetText("|cffffd27a" .. L["installed, switched off"] .. "|r")
      else r.state:SetText("|cff9b9283" .. L["not installed"] .. "|r") end
    end
  end
  return rows
end
Settings_.AddonState = addonState

local function build(parent)
  -- the page scrolls: switches plus the optional addons do not fit the options canvas
  local scroll = ns.UI.SafeCreate("ScrollFrame", parent, { "UIPanelScrollFrameTemplate" })
  scroll:SetPoint("TOPLEFT", 0, 0); scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  local f = CreateFrame("Frame", nil, scroll)
  f:SetSize(600, 620)
  scroll:SetScrollChild(f)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Goldweaver")
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText(ns.L["All settings have working defaults. Window: /gw · Report: /gw debug run"])
  -- language: "Language" stays bilingual so a player who picked the wrong one still finds it
  local langLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  langLabel:SetPoint("TOPLEFT", 20, -66)
  langLabel:SetText(ns.Locale.active == "enUS" and "Language / Sprache" or ns.L["Language"] .. " / Language")
  local reload = ns.UI.Button(f, ns.L["Reload now"], 140, function() if ReloadUI then ReloadUI() end end)
  local lang = ns.UI.Dropdown(f, 220, ns.Locale.LANGUAGES, function(code)
    ns.db.settings.language = code ~= "auto" and code or nil
    -- switching live would mix both languages on screen; the new one starts with the reload
    reload:SetShown(ns.Locale.Resolve(code) ~= ns.Locale.active)
  end)
  lang:SetPoint("LEFT", langLabel, "LEFT", 150, 0)
  lang:SetValue(ns.db.settings.language or "auto")
  reload:SetPoint("LEFT", lang, "RIGHT", 10, 0)
  reload:Hide()
  -- window size (B22)
  local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  scaleLabel:SetPoint("TOPLEFT", 20, -100)
  scaleLabel:SetText(ns.L["Window size"])
  local scales = { { 0.8, "80 %" }, { 0.9, "90 %" }, { 1, "100 %" }, { 1.1, "110 %" }, { 1.2, "120 %" }, { 1.3, "130 %" } }
  local scale = ns.UI.Dropdown(f, 120, scales, function(v) ns.db.settings.windowScale = v ~= 1 and v or nil; ns.UI.ApplyScale() end)
  scale:SetPoint("LEFT", scaleLabel, "LEFT", 150, 0)
  scale:SetValue(ns.db.settings.windowScale or 1)

  f.checks = {}
  for i, d in ipairs(defs()) do
    local c = ns.UI.Check(f, d[1], d[2](), d[3])
    c:SetPoint("TOPLEFT", 16, -134 - (i - 1) * 30)
    f.checks[i] = { check = c, get = d[2] }
  end
  local calc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  calc:SetPoint("TOPLEFT", 16, -134 - #f.checks * 30 - 12)
  calc:SetJustifyH("LEFT")
  f.calc = calc
  f.addons = optionalSection(f, -134 - #f.checks * 30 - 48)
  scroll:SetScript("OnShow", function()
    local self = f
    self.addons:Refresh()
    for _, c in ipairs(self.checks) do c.check:SetChecked(c.get() and true or false) end
    local s = ns.db.settings
    self.calc:SetText(ns.L["Value per favor: %s (/gw favor)  ·  Undercut by: %s (/gw undercut)  ·  Market: %s (/gw market)"]:format(
      ns.Util.Money(s.favorValueCopper or 500), ns.Util.Money(s.undercutCopper or 1), ns.Chars.MarketKey()))
  end)
  return scroll
end

function Settings_.Open()
  if category and Settings and Settings.OpenToCategory then
    local id = category.GetID and category:GetID() or category.ID
    if pcall(Settings.OpenToCategory, id) then return end
  end
  -- fallback: standalone window
  if not panel then
    panel = ns.UI.SafeCreate("Frame", UIParent, { "BasicFrameTemplateWithInset", "BackdropTemplate" }, "GoldweaverSettingsWindow")
    panel:SetSize(660, 560); panel:SetPoint("CENTER"); panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    tinsert(UISpecialFrames, "GoldweaverSettingsWindow")
    local body = build(panel)
    body:ClearAllPoints(); body:SetPoint("TOPLEFT", 4, -24); body:SetPoint("BOTTOMRIGHT", -30, 4)
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
    return { { name = ns.L["Blizzard options"], ok = true, warn = category == nil, detail = category and ns.L["registered"] or ns.L["fallback window"] } }
  end,
})

ns.Slash.Register("lang", function(arg)
  local code = ({ de = "deDE", deDE = "deDE", en = "enUS", enUS = "enUS", auto = "auto" })[arg or ""]
  if not code then return ns.Print(ns.L["usage: /gw lang de|en|auto"]) end
  ns.db.settings.language = code ~= "auto" and code or nil
  ns.Print(ns.L["Takes effect after reloading the interface."] .. " /reload")
end, "language: de, en or auto (game language)")

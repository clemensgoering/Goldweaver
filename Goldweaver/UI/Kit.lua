-- Goldweaver: shared UI kit. One window, four tabs (docs/08-UX.md rule 4), plain Blizzard templates, no library.
-- Tabs register themselves with ns.UI.RegisterTab(key, title, builder) where builder(parentFrame) returns a
-- content object with :Refresh(). UI/MainWindow.lua builds the four standard tabs.
local ADDON, ns = ...

local UI = { tabs = {}, order = {} }
ns.UI = UI

local GOLD = { 0.83, 0.66, 0.31 }
UI.GOLD = GOLD

local window, tabButtons, activeKey

function UI.RegisterTab(key, title, builder)
  if UI.tabs[key] then return end
  UI.tabs[key] = { key = key, title = title, builder = builder }
  UI.order[#UI.order + 1] = key
end

-- Small widget helpers -------------------------------------------------------------------------

function UI.Text(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

function UI.Header(parent, text)
  local fs = UI.Text(parent, text, "GameFontNormal")
  fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  return fs
end

-- Button labelled "verb + object + number" (UX rule 5). onClick receives the button.
function UI.Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 120, 22)
  b:SetText(text or "")
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function UI.Check(parent, label, checked, onChange)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c.text = c.text or c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 0)
  c.text:SetText(label)
  c:SetChecked(checked and true or false)
  c:SetScript("OnClick", function(self) if onChange then onChange(self:GetChecked() and true or false) end end)
  return c
end

-- Window --------------------------------------------------------------------------------------

local function selectTab(key)
  local tab = UI.tabs[key]
  if not tab or not window then return end
  for k, t in pairs(UI.tabs) do
    if t.content then if k == key then t.content.frame:Show() else t.content.frame:Hide() end end
    local b = tabButtons[k]
    if b then if k == key then b:Disable() else b:Enable() end end
  end
  if not tab.content then
    -- Verified 08.11.2026: BasicFrameTemplateWithInset has no usable .Inset on Forever, so the window owns its
    -- own Body frame; every tab frame is parented to it and hides with the window.
    local frame = CreateFrame("Frame", nil, window.Body)
    frame:SetPoint("TOPLEFT", window.Body, "TOPLEFT", 10, -8)
    frame:SetPoint("BOTTOMRIGHT", window.Body, "BOTTOMRIGHT", -10, 8)
    tab.content = tab.builder(frame) or {}
    tab.content.frame = frame
    frame:Show()
  end
  activeKey = key
  if tab.content.Refresh then tab.content:Refresh() end
end

local function createWindow()
  if window then return window end
  window = CreateFrame("Frame", "GoldweaverMainWindow", UIParent, "BasicFrameTemplateWithInset")
  window:SetSize(620, 440)
  window:SetPoint("CENTER")
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetClampedToScreen(true)
  window:SetFrameStrata("HIGH")
  if window.TitleText then window.TitleText:SetText("Goldweaver " .. (ns.version or "")) end
  tinsert(UISpecialFrames, "GoldweaverMainWindow") -- Esc closes

  tabButtons = {}
  local x = 12
  for _, key in ipairs(UI.order) do
    local tab = UI.tabs[key]
    local b = UI.Button(window, tab.title, 110, function() selectTab(key) end)
    b:SetPoint("TOPLEFT", window, "TOPLEFT", x, -28)
    tabButtons[key] = b
    x = x + 114
  end
  -- content area below the tab row (own frame, independent of template internals)
  if window.Inset then window.Inset:Hide() end
  window.Body = CreateFrame("Frame", nil, window)
  window.Body:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -54)
  window.Body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)
  local bg = window.Body:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.35)
  window:Hide()
  return window
end

function UI.Open(key)
  createWindow()
  window:Show()
  selectTab(key or activeKey or UI.order[1])
end

function UI.Toggle(key)
  createWindow()
  if window:IsShown() and (key == nil or key == activeKey) then window:Hide() else UI.Open(key) end
end

function UI.IsOpen() return window and window:IsShown() end

-- Re-renders the active tab (called after data changes).
function UI.Refresh()
  if not window or not window:IsShown() or not activeKey then return end
  local tab = UI.tabs[activeKey]
  if tab and tab.content and tab.content.Refresh then tab.content:Refresh() end
end

ns.Slash.Register("show", function(arg) UI.Open(arg ~= "" and arg or nil) end, "open the Goldweaver window (heute|berufe|chars|settings)")

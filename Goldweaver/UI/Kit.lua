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

-- Group box with a gold title; content is anchored inside with 10 px padding. Uses BackdropTemplate (Mainline).
function UI.Group(parent, title, width, height)
  local g = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  g:SetSize(width, height)
  if g.SetBackdrop then
    g:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    g:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    g:SetBackdropBorderColor(0.5, 0.42, 0.25, 0.9)
  end
  g.title = UI.Header(g, title)
  g.title:SetPoint("TOPLEFT", 10, -8)
  g.pad = 10
  g.top = -26
  return g
end

-- A column of text lines that never overlap: each line is anchored below the previous one, wrapped text included.
function UI.Lines(parent, count, width, template, firstY)
  local lines = {}
  for i = 1, count do
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(width)
    fs:SetWordWrap(true)
    if i == 1 then fs:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.pad or 0, firstY or (parent.top or 0))
    else fs:SetPoint("TOPLEFT", lines[i - 1], "BOTTOMLEFT", 0, -4) end
    lines[i] = fs
  end
  function lines:Set(values)
    for i, fs in ipairs(self) do
      local v = values[i]
      if type(v) == "table" then fs:SetText(v[1] or ""); fs:SetTextColor(v[2] or 1, v[3] or 1, v[4] or 1)
      else fs:SetText(v or ""); fs:SetTextColor(1, 1, 1) end
    end
  end
  return lines
end

-- Label/value pairs ("Rolle:  Verarbeiter") inside a group.
function UI.Pairs(parent, count, labelWidth, valueWidth, firstY)
  local rows = {}
  for i = 1, count do
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    label:SetJustifyH("LEFT"); label:SetWidth(labelWidth)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetJustifyH("LEFT"); value:SetWidth(valueWidth); value:SetWordWrap(false)
    if i == 1 then label:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.pad or 0, firstY or (parent.top or 0))
    else label:SetPoint("TOPLEFT", rows[i - 1].label, "BOTTOMLEFT", 0, -6) end
    value:SetPoint("LEFT", label, "RIGHT", 6, 0)
    rows[i] = { label = label, value = value }
  end
  function rows:Set(values)
    for i, r in ipairs(self) do
      local v = values[i]
      r.label:SetText(v and v[1] or ""); r.value:SetText(v and v[2] or "")
    end
  end
  return rows
end

-- Table with fixed column x offsets. columns = { {title, x, width}, ... }. Returns object with :Set(rows).
function UI.Table(parent, columns, rowCount, firstY)
  local t = { columns = columns, rows = {} }
  local y = firstY or (parent.top or 0)
  t.header = {}
  for c, col in ipairs(columns) do
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.pad or 0) + col[2], y)
    fs:SetWidth(col[3]); fs:SetJustifyH("LEFT"); fs:SetText(col[1])
    t.header[c] = fs
  end
  for r = 1, rowCount do
    local cells = {}
    for c, col in ipairs(columns) do
      local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      fs:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.pad or 0) + col[2], y - 16 - (r - 1) * 18)
      fs:SetWidth(col[3]); fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
      cells[c] = fs
    end
    t.rows[r] = cells
  end
  function t:Set(data)
    for r, cells in ipairs(self.rows) do
      local row = data[r]
      for c, fs in ipairs(cells) do fs:SetText(row and row[c] or "") end
    end
  end
  return t
end

-- Rows with an item/recipe icon, a main text, a right-aligned value and an optional grey sub line.
-- rows:Set({ { icon = textureOrItemID, text, right, sub, color, itemID (hover tooltip), onClick } , ... })
function UI.IconRows(parent, count, width, firstY, rowHeight)
  rowHeight = rowHeight or 30
  local rows = {}
  for i = 1, count do
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, rowHeight - 2)
    if i == 1 then r:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.pad or 0, firstY or (parent.top or 0))
    else r:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2) end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.right:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -1)
    r.right:SetJustifyH("RIGHT"); r.right:SetWordWrap(false); r.right:SetWidth(150)
    r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -1)
    r.sub:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.highlight = r:CreateTexture(nil, "HIGHLIGHT")
    r.highlight:SetAllPoints(); r.highlight:SetColorTexture(1, 1, 1, 0.06)
    r:SetScript("OnEnter", function(self)
      if self.itemID then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
        GameTooltip:Show()
      elseif self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    r:Hide()
    rows[i] = r
  end
  function rows:Set(data)
    for i, r in ipairs(self) do
      local d = data[i]
      if d then
        r:Show()
        local icon = d.icon
        if type(icon) == "number" and C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(icon) end
        if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
        r.text:SetText(d.text or "")
        local c = d.color or { 1, 1, 1 }
        r.text:SetTextColor(c[1], c[2], c[3])
        r.right:SetText(d.right or "")
        if d.rightColor then r.right:SetTextColor(d.rightColor[1], d.rightColor[2], d.rightColor[3]) else r.right:SetTextColor(1, 1, 1) end
        r.sub:SetText(d.sub or "")
        r.itemID, r.tooltip, r.onClick = d.itemID, d.tooltip, d.onClick
      else
        r:Hide()
      end
    end
  end
  return rows
end

-- Item name with cache fallback: asks the server once and returns a placeholder.
function UI.ItemName(itemID)
  if not itemID then return "?" end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
  if name and not ns.Secret.IsSecret(name) then return name end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
  return ns.Data and ns.Data.ExpectedName and ns.Data.ExpectedName(itemID) or ("Item " .. itemID)
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
  window:SetSize(720, 580)
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

-- Goldweaver: UI kit in the "Forever modern" look (docs/14-UI-FUEHRUNG.md): a window with a header band and
-- browser-style tabs on top, cards instead of insets, gold plate buttons, switches, item buttons with quality
-- borders, skill bars. Built from colour textures only (UI.Skin), so a template change in a patch cannot break it;
-- Blizzard templates are used only where they are needed (close button, secure buttons) via SafeCreate.
--
-- Public API (ns.UI)
--   RegisterTab(key, title, builder(frame) -> { Refresh }) ★ (title = English key, translated when the tab button is built)   Open(key?), Toggle(key?), IsOpen(), Refresh()
--   SetSubtitle(text)                                            line under the title
--   SafeCreate(type, parent, templates) -> frame, template       first template that exists
--   Skin(frame, style) -> frame        styles: window, card, hl, tracker, menu, button, buttonOff, ghost, tab, tabOn
--   Button(parent, text, width, onClick, style?)   Inset(parent, w, h, style?)
--   Widgets: Text, Header, Button, Check, Group, Inset, Section, Lines, Pairs, Table, IconRows,
--            ItemButton, SkillBar, StepCard, StepList, ItemName, QualityColor, Money
local ADDON, ns = ...
local L = ns.L

local UI = { tabs = {}, order = {}, aliases = { heute = "guide", chars = "team", settings = "team" } }
ns.UI = UI

local GOLD = { 1, 0.82, 0 }
UI.GOLD = GOLD
local ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local window, activeKey

function UI.RegisterTab(key, title, builder)
  if UI.tabs[key] then return end
  UI.tabs[key] = { key = key, title = title, builder = builder }
  UI.order[#UI.order + 1] = key
end

function UI.SafeCreate(ftype, parent, templates, name)
  for _, t in ipairs(templates) do
    local ok, f = pcall(CreateFrame, ftype, nil, parent, t)
    if ok and f then
      if name then _G[name] = f end
      return f, t
    end
  end
  local f = CreateFrame(ftype, nil, parent)
  if name then _G[name] = f end
  return f, nil
end

function UI.Money(copper) return ns.Util.Money(copper or 0) end

-- Skin -------------------------------------------------------------------------------------------
-- "Forever modern" look (docs/14-UI-FUEHRUNG.md): dark warm surfaces, a 1 px edge, a faint sheen at the top and
-- short gold accents at two corners of highlighted frames. Colour textures only: no template, no art files, so it
-- looks the same on every client build.

local SKINS = {
  window    = { bg = { 0.055, 0.047, 0.038, 0.97 }, edge = { 0.42, 0.32, 0.17, 1 }, sheen = 0.025, accent = true },
  card      = { bg = { 0.090, 0.077, 0.060, 0.92 }, edge = { 0.23, 0.18, 0.12, 1 }, sheen = 0.02 },
  hl        = { bg = { 0.125, 0.092, 0.050, 0.95 }, edge = { 0.55, 0.42, 0.20, 1 }, sheen = 0.05, accent = true },
  tracker   = { bg = { 0.055, 0.045, 0.032, 0.80 }, edge = { 0.36, 0.27, 0.15, 0.9 }, sheen = 0.03 },
  menu      = { bg = { 0.060, 0.050, 0.040, 0.97 }, edge = { 0.55, 0.42, 0.20, 1 }, sheen = 0.02 },
  button    = { bg = { 0.300, 0.200, 0.070, 1 }, edge = { 0.78, 0.60, 0.29, 1 }, sheen = 0.10 },
  buttonOff = { bg = { 0.130, 0.120, 0.110, 1 }, edge = { 0.30, 0.28, 0.25, 1 }, sheen = 0.03 },
  ghost     = { bg = { 0.070, 0.060, 0.050, 0.9 }, edge = { 0.23, 0.18, 0.12, 1 }, sheen = 0.02 },
  tab       = { bg = { 0.080, 0.067, 0.050, 1 }, edge = { 0.23, 0.18, 0.12, 1 }, sheen = 0.02 },
  tabOn     = { bg = { 0.200, 0.140, 0.060, 1 }, edge = { 0.78, 0.60, 0.29, 1 }, sheen = 0.08 },
}
UI.SKINS = SKINS

local function colorTex(f, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub)
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

local function accent(f, point, x, y)
  local h, v = colorTex(f, "BORDER", 2), colorTex(f, "BORDER", 2)
  h:SetSize(18, 2); h:SetPoint(point, x, y)
  v:SetSize(2, 18); v:SetPoint(point, x, y)
  return h, v
end

-- Applies (or switches) a skin; safe to call again, e.g. for a disabled button or the active tab.
function UI.Skin(f, style)
  local s = SKINS[style] or SKINS.card
  local k = f.gwSkin
  if not k then
    k = {}
    k.bg = colorTex(f, "BACKGROUND", -8); k.bg:SetAllPoints()
    k.sheen = colorTex(f, "BACKGROUND", -7)
    k.sheen:SetPoint("TOPLEFT", 1, -1); k.sheen:SetPoint("TOPRIGHT", -1, -1); k.sheen:SetHeight(12)
    k.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
      local e = colorTex(f, "BORDER", 1)
      e:SetPoint(side[1]); e:SetPoint(side[2])
      if i <= 2 then e:SetHeight(1) else e:SetWidth(1) end
      k.edges[i] = e
    end
    f.gwSkin = k
  end
  k.bg:SetColorTexture(unpack(s.bg))
  k.sheen:SetColorTexture(1, 0.85, 0.45, s.sheen or 0)
  for _, e in ipairs(k.edges) do e:SetColorTexture(unpack(s.edge)) end
  if s.accent and not k.accents then
    k.accents = { accent(f, "TOPLEFT", 0, 0) }
    local h, v = accent(f, "BOTTOMRIGHT", 0, 0)
    k.accents[3], k.accents[4] = h, v
  end
  for _, a in ipairs(k.accents or {}) do a:SetColorTexture(1, 0.82, 0.45, s.accent and 0.7 or 0) end
  k.style = style
  return f
end

-- Basic widgets ----------------------------------------------------------------------------------

function UI.Text(parent, text, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

function UI.Header(parent, text)
  local fs = UI.Text(parent, text, "GameFontNormal")
  return fs
end

-- Gold plate button; style "ghost" for quiet secondary buttons (dropdowns). Disabled buttons turn grey.
function UI.Button(parent, text, width, onClick, style)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, 22)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("LEFT", 6, 0); fs:SetPoint("RIGHT", -6, 0); fs:SetWordWrap(false)
  b:SetFontString(fs)
  b:SetNormalFontObject("GameFontNormal")
  b:SetHighlightFontObject("GameFontHighlight")
  b:SetDisabledFontObject("GameFontDisable")
  b:SetPushedTextOffset(1, -1)
  b.gwStyle = style or "button"
  UI.Skin(b, b.gwStyle)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
  hl:SetColorTexture(1, 0.8, 0.4, 0.14)
  b:SetScript("OnEnable", function(self) UI.Skin(self, self.gwStyle) end)
  b:SetScript("OnDisable", function(self) UI.Skin(self, "buttonOff") end)
  b:SetText(text or "")
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- Switch (pill track with a knob) instead of a tick box; same API as a CheckButton (SetChecked/GetChecked).
-- The label is part of the click area.
function UI.Check(parent, label, checked, onChange)
  local c = CreateFrame("CheckButton", nil, parent)
  c:SetSize(34, 18)
  UI.Skin(c, "ghost")
  c.track = c:CreateTexture(nil, "ARTWORK")
  c.track:SetPoint("TOPLEFT", 1, -1); c.track:SetPoint("BOTTOMRIGHT", -1, 1)
  c.knob = c:CreateTexture(nil, "OVERLAY")
  c.knob:SetSize(14, 14)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.text:SetPoint("LEFT", c, "RIGHT", 8, 0)
  c.text:SetText(label)
  c:SetHitRectInsets(0, -math.min(400, (c.text:GetStringWidth() or 0) + 8), 0, 0)
  local function paint()
    local on = c:GetChecked() and true or false
    if on then c.track:SetColorTexture(0.62, 0.47, 0.22, 1); c.knob:SetColorTexture(1, 0.93, 0.78, 1)
    else c.track:SetColorTexture(0.20, 0.19, 0.18, 1); c.knob:SetColorTexture(0.58, 0.58, 0.60, 1) end
    c.knob:ClearAllPoints()
    c.knob:SetPoint(on and "RIGHT" or "LEFT", c, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
  end
  local setChecked = c.SetChecked
  function c:SetChecked(v) setChecked(self, v); paint() end
  c:SetChecked(checked and true or false)
  c:SetScript("OnClick", function(self)
    paint()
    if onChange then onChange(self:GetChecked() and true or false) end
  end)
  return c
end

-- Dropdown: a button showing the current value; a click opens a small list below it. Own implementation on
-- purpose (no dependency on Blizzard's changing menu API). options = { {value, English label key} }, onSelect(value).
local openMenu
function UI.Dropdown(parent, width, options, onSelect)
  local d = UI.Button(parent, "", width, nil, "ghost")
  local fs = d:GetFontString()
  fs:ClearAllPoints(); fs:SetPoint("LEFT", 8, 0); fs:SetPoint("RIGHT", -22, 0); fs:SetJustifyH("LEFT")
  d.arrow = d:CreateTexture(nil, "OVERLAY")
  d.arrow:SetSize(12, 12)
  d.arrow:SetPoint("RIGHT", -6, 0)
  d.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  d.menu = CreateFrame("Frame", nil, d)
  d.menu:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -2)
  d.menu:SetSize(width, #options * 22 + 8)
  d.menu:SetFrameStrata("FULLSCREEN_DIALOG")
  UI.Skin(d.menu, "menu")
  d.menu:Hide()
  for i, opt in ipairs(options) do
    local item = CreateFrame("Button", nil, d.menu)
    item:SetSize(width - 8, 22)
    item:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    item.text:SetPoint("LEFT", 8, 0)
    item.text:SetText(L[opt[2]])
    local hl = item:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 0.8, 0.4, 0.14)
    item:SetScript("OnClick", function()
      d.menu:Hide(); openMenu = nil
      d:SetValue(opt[1])
      if onSelect then onSelect(opt[1]) end
    end)
  end
  d:SetScript("OnClick", function()
    if d.menu:IsShown() then d.menu:Hide(); openMenu = nil; return end
    if openMenu and openMenu ~= d.menu then openMenu:Hide() end
    d.menu:Show(); openMenu = d.menu
  end)
  d:SetScript("OnHide", function() d.menu:Hide() end)
  function d:SetValue(value)
    self.value = value
    for _, opt in ipairs(options) do if opt[1] == value then self:SetText(L[opt[2]]) end end
  end
  return d
end

-- Card: the panel every tab is built from (was a Blizzard inset). style "hl" for the one thing that matters now.
function UI.Inset(parent, width, height, style)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height)
  UI.Skin(f, style or "card")
  f.pad = 10
  f.top = -10
  return f
end

-- Section title with a thin gold divider ("GameFontNormal" gold on dark).
function UI.Section(parent, text, width)
  local fs = UI.Text(parent, text, "GameFontNormal")
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(0.72, 0.50, 0.12, 0.45)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
  line:SetWidth(width or 200)
  fs.line = line
  return fs
end

-- Group = inset with a section title (kept for modules written against the first kit).
function UI.Group(parent, title, width, height)
  local g = UI.Inset(parent, width, height)
  g.title = UI.Section(g, title, width - 20)
  g.title:SetPoint("TOPLEFT", 10, -8)
  g.top = -28
  return g
end

-- oneLine = true: each line is cut with "..." instead of wrapping, so fixed-height boxes never overflow
function UI.Lines(parent, count, width, template, firstY, oneLine)
  local lines = {}
  for i = 1, count do
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetWidth(width)
    fs:SetWordWrap(not oneLine)
    if oneLine then fs:SetHeight(14) end
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

function UI.Pairs(parent, count, labelWidth, valueWidth, firstY)
  local rows = {}
  for i = 1, count do
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("LEFT"); label:SetWidth(labelWidth)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

function UI.Table(parent, columns, rowCount, firstY)
  local t = { columns = columns, rows = {} }
  local y = firstY or (parent.top or 0)
  t.header = {}
  for c, col in ipairs(columns) do
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", (parent.pad or 0) + col[2], y)
    fs:SetWidth(col[3]); fs:SetJustifyH("LEFT"); fs:SetText(col[1])
    t.header[c] = fs
  end
  for r = 1, rowCount do
    local cells = {}
    for c, col in ipairs(columns) do
      local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

-- Items ------------------------------------------------------------------------------------------

function UI.ItemName(itemID)
  if not itemID then return "?" end
  local name = ns.API.ItemName(itemID)
  if name then return name end
  ns.API.RequestItem(itemID)
  return ns.Data and ns.Data.ExpectedName and ns.Data.ExpectedName(itemID) or ("Item " .. itemID)
end

function UI.QualityColor(quality)
  if quality and C_Item and C_Item.GetItemQualityColor then
    local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
    if ok and r then return r, g, b end
  end
  local c = ITEM_QUALITY_COLORS and quality and ITEM_QUALITY_COLORS[quality]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-- Square item button: icon, quality border, optional count, item tooltip on hover.
function UI.ItemButton(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b.frame = b:CreateTexture(nil, "BACKGROUND")
  b.frame:SetPoint("TOPLEFT", -1, 1); b.frame:SetPoint("BOTTOMRIGHT", 1, -1)
  b.frame:SetColorTexture(0.30, 0.25, 0.18, 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  b.border:SetAllPoints()
  b.border:Hide()
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  b:SetScript("OnEnter", function(self)
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
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- icon: texture path/fileID; item: itemID (quality border, tooltip, icon fallback)
  function b:SetContent(icon, item, count)
    self.itemID = item
    local tex = icon
    if not tex and item then tex = ns.API.ItemIcon(item) end
    self.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local quality = item and ns.API.ItemInfo(item) and ns.API.ItemInfo(item).quality
    if quality and quality >= 2 then
      self.border:SetVertexColor(UI.QualityColor(quality))
      self.border:Show()
    else
      self.border:Hide()
    end
    self.count:SetText(count and count > 1 and tostring(count) or "")
  end
  return b
end

-- Skill bar like the profession bars in the character pane: "53 / 75".
function UI.SkillBar(parent, width, height)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(width, height or 12)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  bar:SetStatusBarColor(0.25, 0.62, 0.25)
  UI.Skin(bar, "ghost")
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER")
  function bar:SetSkill(rank, max, r, g, b)
    rank, max = rank or 0, math.max(1, max or 1)
    self:SetMinMaxValues(0, max)
    self:SetValue(rank)
    self.text:SetText(("%d / %d"):format(rank, max))
    if r then self:SetStatusBarColor(r, g, b) end
  end
  return bar
end

-- Rows with an item button, title, grey sub line, right value and an optional action button.
-- rows:Set({ { icon, item, text, sub, right, rightColor, color, onClick, button = {label, fn} } })
function UI.IconRows(parent, count, width, firstY, rowHeight)
  rowHeight = rowHeight or 32
  local rows = {}
  for i = 1, count do
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, rowHeight - 2)
    if i == 1 then r:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.pad or 0, firstY or (parent.top or 0))
    else r:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2) end
    local iconSize = math.min(rowHeight - 6, 28)
    r.item = UI.ItemButton(r, iconSize)
    r.item:SetPoint("LEFT", 0, 0)
    r.btn = UI.Button(r, "", 96, nil)
    r.btn:SetPoint("RIGHT", 0, 0)
    r.btn:SetHeight(20)
    r.btn:Hide()
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetJustifyH("RIGHT"); r.right:SetWordWrap(false)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("TOPLEFT", r.item, "TOPRIGHT", 6, 1)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -2)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.8, 0.4, 0.07)
    r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    r:SetScript("OnEnter", function(self) if self.item:GetScript("OnEnter") then self.item:GetScript("OnEnter")(self.item) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    rows[i] = r
  end
  function rows:Set(data)
    for i, r in ipairs(self) do
      local d = data[i]
      if d then
        r:Show()
        r.item:SetContent(d.icon, d.itemID or d.item, d.count)
        r.item.tooltip = d.tooltip
        r.text:SetText(d.text or "")
        local c = d.color or { 1, 1, 1 }
        r.text:SetTextColor(c[1], c[2], c[3])
        r.sub:SetText(d.sub or "")
        r.right:SetText(d.right or "")
        if d.rightColor then r.right:SetTextColor(d.rightColor[1], d.rightColor[2], d.rightColor[3]) else r.right:SetTextColor(1, 1, 1) end
        r.right:ClearAllPoints()
        if d.button then
          r.btn:SetText(d.button[1]); r.btn:SetScript("OnClick", d.button[2]); r.btn:Show()
          r.right:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
        else
          r.btn:Hide()
          r.right:SetPoint("RIGHT", r, "RIGHT", 0, 0)
        end
        r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
        r.sub:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
        r.onClick = d.onClick
      else
        r:Hide()
      end
    end
  end
  return rows
end

-- The current step, big: icon, category, title, detail, value, one primary action (RestedXP-style "Now").
function UI.StepCard(parent, width)
  local c = UI.Inset(parent, width, 104, "hl")
  c.icon = UI.ItemButton(c, 52)
  c.icon:SetPoint("TOPLEFT", 12, -14)
  c.counter = UI.Text(c, "", "GameFontNormalSmall")
  c.counter:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, 0)
  c.title = UI.Text(c, "", "GameFontNormalLarge")
  c.title:SetTextColor(1, 1, 1)
  c.title:SetPoint("TOPLEFT", c.counter, "BOTTOMLEFT", 0, -3)
  c.title:SetWidth(width - 230); c.title:SetWordWrap(false)
  c.detail = UI.Text(c, "", "GameFontHighlight")
  c.detail:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
  c.detail:SetWidth(width - 230)
  c.value = UI.Text(c, "", "GameFontNormal")
  c.value:SetPoint("TOPRIGHT", -14, -16); c.value:SetJustifyH("RIGHT")
  c.action = UI.Button(c, "", 150, nil)
  c.action:SetHeight(26)
  c.action:SetPoint("BOTTOMRIGHT", -12, 12)
  function c:SetStep(step, index, total)
    if not step then
      self.icon:SetContent("Interface\\Icons\\Achievement_General", nil)
      self.counter:SetText(L["ALL DONE"])
      self.title:SetText(L["Nothing urgent"])
      self.detail:SetText(L["Play, gather, open professions: new steps appear on their own."])
      self.value:SetText("")
      self.action:Hide()
      return
    end
    self.icon:SetContent(step.icon, step.item)
    self.counter:SetText((L["NOW · STEP %d OF %d · %s"]):format(index or 1, total or 1, (step.category or ""):upper()))
    self.title:SetText(step.title or "")
    self.detail:SetText(step.detail or "")
    if step.value and step.value ~= 0 then
      self.value:SetText((step.value > 0 and "≈ " or (L["Cost"] .. " ")) .. UI.Money(math.abs(step.value)))
      if step.value > 0 then self.value:SetTextColor(0.4, 1, 0.4) else self.value:SetTextColor(1, 0.6, 0.4) end
    else
      self.value:SetText("")
    end
    if step.action and step.actionLabel then
      self.action:SetText(step.actionLabel)
      self.action:SetScript("OnClick", step.action)
      self.action:Show()
    else
      self.action:Hide()
    end
  end
  return c
end

-- The following steps as compact rows with their own small action buttons.
function UI.StepList(parent, count, width, firstY)
  local rows = UI.IconRows(parent, count, width, firstY, 38)
  local set = rows.Set
  function rows:SetSteps(steps, offset)
    local data = {}
    for i = (offset or 0) + 1, #steps do
      local s = steps[i]
      local value = s.value and s.value ~= 0 and ((s.value > 0 and "≈ " or "−") .. UI.Money(math.abs(s.value))) or ""
      data[#data + 1] = {
        icon = s.icon, item = s.item, text = ("%d. %s"):format(i, s.title or ""), sub = (s.category and (s.category .. " · ") or "") .. (s.detail or ""),
        right = value, rightColor = s.value and s.value < 0 and { 1, 0.6, 0.4 } or { 0.4, 1, 0.4 },
        button = s.action and s.actionLabel and { s.actionLabel, s.action } or nil,
      }
    end
    set(self, data)
  end
  return rows
end

-- Window -----------------------------------------------------------------------------------------

-- Layout: header band (logo, title, subtitle, close) 50 px, tab strip 30 px, body below. The body keeps the
-- 752 x 500 content area the tabs are built for.
local HEAD_H, TABS_H = 50, 30
local TAB_ICONS = {
  guide = "Interface\\Icons\\INV_Misc_Book_09", field = "Interface\\Icons\\INV_Misc_Flower_02",
  berufe = "Interface\\Icons\\Trade_BlackSmithing", team = "Interface\\Icons\\INV_Letter_15",
}

local function selectTab(key)
  key = UI.aliases[key] or key
  local tab = UI.tabs[key]
  if not tab or not window then return end
  for k, t in pairs(UI.tabs) do
    if t.content then if k == key then t.content.frame:Show() else t.content.frame:Hide() end end
  end
  for k, b in pairs(window.tabButtons or {}) do b:SetActive(k == key) end
  if not tab.content then
    local frame = CreateFrame("Frame", nil, window.Body)
    frame:SetPoint("TOPLEFT", window.Body, "TOPLEFT", 8, -8)
    frame:SetPoint("BOTTOMRIGHT", window.Body, "BOTTOMRIGHT", -8, 8)
    tab.content = tab.builder(frame) or {}
    tab.content.frame = frame
    frame:Show()
  end
  activeKey = key
  if tab.content.Refresh then
    local ok, err = pcall(tab.content.Refresh, tab.content)
    if not ok then ns.Health.Record("UI tab " .. key, err) end
  end
end

function UI.SetSubtitle(text)
  if window and window.subtitle then window.subtitle:SetText(text or "") end
end

-- Browser-style tab: icon and name; the active one gets the warm gold plate and a gold line along its bottom.
local function tabButton(key, title)
  local b = CreateFrame("Button", nil, window)
  b:SetHeight(TABS_H - 3)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 10, 0)
  b.icon:SetTexture(TAB_ICONS[key] or ICON); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetText(L[title])
  b:SetWidth(math.max(90, (b.text:GetStringWidth() or 60) + 44))
  b.line = b:CreateTexture(nil, "OVERLAY")
  b.line:SetPoint("BOTTOMLEFT", 6, 0); b.line:SetPoint("BOTTOMRIGHT", -6, 0); b.line:SetHeight(2)
  b.line:SetColorTexture(1, 0.82, 0.45, 0.9)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1); hl:SetColorTexture(1, 0.8, 0.4, 0.08)
  function b:SetActive(on)
    UI.Skin(self, on and "tabOn" or "tab")
    self.line:SetShown(on)
    self.icon:SetDesaturated(not on)
    if on then self.text:SetTextColor(1, 0.82, 0.45) else self.text:SetTextColor(0.62, 0.57, 0.50) end
  end
  b:SetScript("OnClick", function()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    selectTab(key)
  end)
  b:SetActive(false)
  return b
end

local function buildTabs()
  window.tabButtons = {}
  window.Tabs = {}
  for i, key in ipairs(UI.order) do
    local t = UI.tabs[key]
    t.index = i
    local b = tabButton(key, t.title)
    if i == 1 then b:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -HEAD_H - 3)
    else b:SetPoint("TOPLEFT", window.Tabs[i - 1], "TOPRIGHT", 4, 0) end
    window.Tabs[i] = b
    window.tabButtons[key] = b
  end
end

local function buildHeader()
  local head = window:CreateTexture(nil, "BACKGROUND", nil, -6)
  head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(HEAD_H)
  head:SetColorTexture(0.085, 0.068, 0.045, 1)
  local strip = window:CreateTexture(nil, "BACKGROUND", nil, -6)
  strip:SetPoint("TOPLEFT", 1, -HEAD_H - 1); strip:SetPoint("TOPRIGHT", -1, -HEAD_H - 1); strip:SetHeight(TABS_H)
  strip:SetColorTexture(0.045, 0.038, 0.030, 1)
  local line = window:CreateTexture(nil, "BORDER")
  line:SetPoint("TOPLEFT", 1, -HEAD_H - TABS_H); line:SetPoint("TOPRIGHT", -1, -HEAD_H - TABS_H); line:SetHeight(1)
  line:SetColorTexture(0.42, 0.32, 0.17, 1)
  local ring = window:CreateTexture(nil, "ARTWORK")
  ring:SetSize(38, 38); ring:SetPoint("TOPLEFT", 12, -6)
  ring:SetColorTexture(0.78, 0.60, 0.29, 1)
  local logo = window:CreateTexture(nil, "OVERLAY")
  logo:SetPoint("TOPLEFT", ring, "TOPLEFT", 2, -2); logo:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -2, 2)
  logo:SetTexture(ICON); logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local title = UI.Text(window, "Goldweaver", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", ring, "TOPRIGHT", 10, -3)
  title:SetTextColor(1, 0.82, 0.45)
  window.subtitle = UI.Text(window, "", "GameFontHighlightSmall")
  window.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  window.subtitle:SetTextColor(0.62, 0.57, 0.50)
  local close, template = UI.SafeCreate("Button", window, { "UIPanelCloseButton" })
  if not template then
    UI.Skin(close, "ghost")
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetPoint("CENTER"); x:SetText("X")
  end
  close:SetSize(26, 26)
  close:SetPoint("TOPRIGHT", -8, -12)
  close:SetScript("OnClick", function() window:Hide() end)
end

local function buildWindow()
  if window then return window end
  window = CreateFrame("Frame", "GoldweaverMainWindow", UIParent)
  window:SetSize(780, 606)
  window:SetPoint("CENTER")
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetClampedToScreen(true)
  window:SetFrameStrata("HIGH")
  window:SetToplevel(true)
  UI.Skin(window, "window")
  tinsert(UISpecialFrames, "GoldweaverMainWindow")
  buildHeader()

  window.Body = CreateFrame("Frame", nil, window)
  window.Body:SetPoint("TOPLEFT", window, "TOPLEFT", 6, -HEAD_H - TABS_H - 4)
  window.Body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 6)

  buildTabs()
  window:Hide()
  return window
end

-- Builds the window once. A failure halfway (e.g. a template changed in a patch) must not leave a broken
-- half-built window behind: the frame is hidden, forgotten and the error recorded; the next call tries again.
local function createWindow()
  if window and window.Body and window.tabButtons then return window end
  if window then window:Hide(); window = nil end
  local ok, err = pcall(buildWindow)
  if not ok then
    if window then window:Hide() end
    window = nil
    ns.Health.Record("UI.createWindow", err)
    return nil
  end
  return window
end

function UI.Open(key)
  if not createWindow() then ns.Print(L["Window could not be built; details with /gw debug run."]); return end
  window:Show()
  local me = ns.Chars and ns.Chars.Current()
  if me then UI.SetSubtitle(("%s · %s · %s"):format(me.name, L[ns.Chars.ROLE_LABELS[me.role or "none"] or ""], me.market or "")) end
  selectTab(key or activeKey or UI.order[1])
end

function UI.Toggle(key)
  if not createWindow() then return UI.Open(key) end
  key = key and (UI.aliases[key] or key)
  if window:IsShown() and (key == nil or key == activeKey) then window:Hide() else UI.Open(key) end
end

function UI.IsOpen() return window and window:IsShown() end

function UI.Refresh()
  if not window or not window:IsShown() or not activeKey then return end
  local tab = UI.tabs[activeKey]
  if tab and tab.content and tab.content.Refresh then
    local ok, err = pcall(tab.content.Refresh, tab.content)
    if not ok then ns.Health.Record("UI tab " .. activeKey, err) end
  end
  if ns.Panel and ns.Panel.Refresh then ns.Panel.Refresh() end
end

ns.Slash.Register("show", function(arg) UI.Open(arg ~= "" and arg or nil) end, "open the window (guide|field|berufe|team)")

ns:RegisterModule("UI", {
  SelfTest = function()
    local t = {}
    for _, key in ipairs(UI.order) do t[#t + 1] = key end
    return {
      { name = "Tabs", ok = #UI.order >= 4, detail = table.concat(t, ", ") },
      { name = "Window", ok = true, detail = window and "built" or "not opened yet" },
    }
  end,
})

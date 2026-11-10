-- Goldweaver: UI kit in the look shared with ClassPages (docs/14-UI-FUEHRUNG.md): a window with a header and
-- browser-style tabs on top, cards instead of insets, gold plate buttons, switches, item buttons with quality
-- borders, skill bars. Built from the addon's own art set (Goldweaver/Media, white shapes tinted per style and
-- stretched as 9-slices), so a template change in a patch cannot break it; Blizzard templates are used only where
-- they are needed (secure buttons) via SafeCreate.
--
-- Public API (ns.UI)
--   RegisterTab(key, title, builder(frame) -> { Refresh }) ★ (title = English key, translated when the tab button is built)   Open(key?), Toggle(key?), IsOpen(), Refresh()
--   SetSubtitle(text), SetHeaderInfo(text)                       line under the title, line right in the header
--   SafeCreate(type, parent, templates) -> frame, template       first template that exists
--   Skin(frame, style) -> frame        styles: window, card, hl, tracker, menu, button, buttonOff, danger, ghost, row,
--                                      tab, tabOn, tabDown   (a frame keeps the shape of its first style)
--   Slice(frame, shape, corner, layer, sub, outset, flip)   Art(parent, name, layer, sub)   Round(owner, tex, mask)
--   Button(parent, text, width, onClick, style?) (:SetStyle)   IconButton(parent, icon, size, onClick, style?)
--   Inset(parent, w, h, style?)   Divider(parent)
--   Widgets: Text, Header, Button, Check, Group, Inset, Section, Lines, Pairs, Table, IconRows,
--            ItemButton, SkillBar, StepCard, StepList, ProgressRows, ItemName, QualityColor, Money
local ADDON, ns = ...
local L = ns.L

local UI = { tabs = {}, order = {}, aliases = { heute = "guide", chars = "team", settings = "team" } }
ns.UI = UI

local GOLD = { 1, 0.82, 0.45 }
UI.GOLD = GOLD
UI.DIM = { 0.62, 0.57, 0.50 }
UI.TEXT = { 0.93, 0.90, 0.85 }
UI.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local ICON = UI.MEDIA .. "logo"

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
-- Shared look with ClassPages (docs/14-UI-FUEHRUNG.md, values from ClassPages docs/07-DESIGN.md): dark warm
-- surfaces, a 1 px bronze ring, gold as the only accent, restrained rounding (5 px panels, 3 px controls, 4 px tabs).
-- Built from the addon's own art set (Goldweaver/Media, tools/assets/make_assets.py): white shapes tinted with
-- SetVertexColor and stretched as 9-slices, so no Blizzard template or art can change the look in a patch.

function UI.Art(parent, name, layer, sub)
  local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
  t:SetTexture(UI.MEDIA .. name)
  return t
end

-- shape = { texture size, margin in texels }
local SHAPES = { rr5 = { 16, 7 }, rr3 = { 16, 6 }, pill = { 32, 15 }, tab = { 16, 7 }, shadow = { 64, 24 } }
for _, name in ipairs({ "rr5", "rr3", "pill", "tab" }) do SHAPES[name .. "_ring"] = SHAPES[name] end

-- Nine textures that stretch a rounded shape over a frame of any size. corner = corner size on screen (px),
-- outset = how far the slice reaches beyond the frame (shadows), flip = upside down (tabs hanging below a frame).
function UI.Slice(f, shape, corner, layer, sub, outset, flip)
  local def = SHAPES[shape]
  local u = def[2] / def[1]
  local U = { 0, u, 1 - u, 1 }
  local c, o = corner, outset or 0
  local X = { { "LEFT", -o }, { "LEFT", c - o }, { "RIGHT", o - c }, { "RIGHT", o } }
  local Y = { { "TOP", o }, { "TOP", o - c }, { "BOTTOM", c - o }, { "BOTTOM", -o } }
  local s = { parts = {} }
  for row = 1, 3 do
    for col = 1, 3 do
      local t = f:CreateTexture(nil, layer, nil, sub)
      t:SetTexture(UI.MEDIA .. shape)
      if flip then t:SetTexCoord(U[col], U[col + 1], 1 - U[row], 1 - U[row + 1])
      else t:SetTexCoord(U[col], U[col + 1], U[row], U[row + 1]) end
      t:SetPoint("TOPLEFT", f, Y[row][1] .. X[col][1], X[col][2], Y[row][2])
      t:SetPoint("BOTTOMRIGHT", f, Y[row + 1][1] .. X[col + 1][1], X[col + 1][2], Y[row + 1][2])
      s.parts[#s.parts + 1] = t
    end
  end
  function s:SetColor(r, g, b, a) for _, t in ipairs(self.parts) do t:SetVertexColor(r, g, b, a or 1) end end
  function s:SetShown(on) for _, t in ipairs(self.parts) do t:SetShown(on) end end
  return s
end

local GOLD_EDGE = { 0.80, 0.62, 0.30, 1 }
local SKINS = {
  window    = { shape = "rr5", corner = 7, bg = { 0.063, 0.055, 0.047, 0.97 }, edge = { 0.52, 0.40, 0.21, 1 }, shadow = 0.65 },
  card      = { shape = "rr5", corner = 7, bg = { 0.100, 0.086, 0.068, 0.94 }, edge = { 0.29, 0.23, 0.16, 1 }, sheen = 0.035 },
  hl        = { shape = "rr5", corner = 7, bg = { 0.135, 0.100, 0.055, 0.96 }, edge = GOLD_EDGE, sheen = 0.06 },
  tracker   = { shape = "rr5", corner = 7, bg = { 0.063, 0.055, 0.047, 0.88 }, edge = { 0.40, 0.31, 0.17, 0.95 }, sheen = 0.03, shadow = 0.4 },
  menu      = { shape = "rr5", corner = 7, bg = { 0.075, 0.064, 0.052, 0.98 }, edge = GOLD_EDGE, sheen = 0.04, shadow = 0.7 },
  button    = { shape = "rr3", corner = 6, bg = { 0.36, 0.25, 0.09, 1 }, edge = { 0.86, 0.67, 0.33, 1 }, sheen = 0.14, text = GOLD },
  buttonOff = { shape = "rr3", corner = 6, bg = { 0.13, 0.12, 0.11, 1 }, edge = { 0.27, 0.25, 0.22, 1 }, sheen = 0.03, text = UI.DIM },
  danger    = { shape = "rr3", corner = 6, bg = { 0.30, 0.085, 0.06, 1 }, edge = { 0.78, 0.33, 0.24, 1 }, sheen = 0.10, text = { 1, 0.78, 0.72 } },
  ghost     = { shape = "rr3", corner = 6, bg = { 0.115, 0.098, 0.080, 0.95 }, edge = { 0.34, 0.27, 0.19, 1 }, sheen = 0.04, text = UI.TEXT },
  row       = { shape = "rr3", corner = 6, bg = { 0.085, 0.072, 0.056, 0.75 }, edge = { 0.20, 0.16, 0.11, 0.9 } },
  tab       = { shape = "tab", corner = 7, bg = { 0.090, 0.076, 0.060, 1 }, edge = { 0.27, 0.22, 0.15, 1 }, text = UI.DIM },
  tabOn     = { shape = "tab", corner = 7, bg = { 0.205, 0.150, 0.068, 1 }, edge = GOLD_EDGE, sheen = 0.08, glow = 0.9, text = GOLD },
  -- action tabs hanging below a Blizzard frame: the tab shape upside down, rounded at the bottom
  tabDown   = { shape = "tab", corner = 7, flip = true, bg = { 0.205, 0.150, 0.068, 1 }, edge = GOLD_EDGE, text = GOLD },
}
UI.SKINS = SKINS

-- Applies (or switches) a skin; safe to call again, e.g. for a disabled button or the active tab. A frame keeps
-- the shape of its first style; later calls only recolour.
function UI.Skin(f, style)
  local s = SKINS[style] or SKINS.card
  local k = f.gwSkin
  if not k then
    k = { shape = s.shape, corner = s.corner }
    k.fill = UI.Slice(f, k.shape, k.corner, "BACKGROUND", -6, nil, s.flip)
    k.ring = UI.Slice(f, k.shape .. "_ring", k.corner, "BORDER", 1, nil, s.flip)
    f.gwSkin = k
  end
  k.fill:SetColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
  k.ring:SetColor(s.edge[1], s.edge[2], s.edge[3], s.edge[4])
  if s.shadow and not k.shadow then k.shadow = UI.Slice(f, "shadow", 28, "BACKGROUND", -8, 14) end
  if k.shadow then k.shadow:SetColor(0, 0, 0, s.shadow or 0) end
  if s.sheen and not k.sheen then
    k.sheen = UI.Art(f, "fade_v", "BACKGROUND", -4)
    k.sheen:SetPoint("TOPLEFT", k.corner * 0.5, -1)
    k.sheen:SetPoint("TOPRIGHT", -k.corner * 0.5, -1)
    k.sheen:SetHeight(14)
  end
  if k.sheen then k.sheen:SetVertexColor(1, 0.86, 0.5, s.sheen or 0) end
  if s.glow and not k.glow then
    k.glow = UI.Art(f, "glow", "OVERLAY", 2)
    k.glow:SetBlendMode("ADD")
    k.glow:SetPoint("BOTTOMLEFT", 4, -5)
    k.glow:SetPoint("BOTTOMRIGHT", -4, -5)
    k.glow:SetHeight(12)
  end
  if k.glow then k.glow:SetVertexColor(1, 0.80, 0.38, s.glow or 0) end
  k.style = style
  return f
end

-- Rounds a texture's corners with a mask where the client supports it.
function UI.Round(owner, tex, maskName)
  if not (owner.CreateMaskTexture and tex.AddMaskTexture) then return end
  local mask = owner:CreateMaskTexture()
  mask:SetTexture(UI.MEDIA .. (maskName or "mask_rr"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(tex)
  tex:AddMaskTexture(mask)
  return mask
end

-- Thin line that fades out to both ends.
function UI.Divider(parent)
  local t = UI.Art(parent, "fade_h", "BORDER")
  t:SetHeight(1)
  t:SetVertexColor(0.55, 0.43, 0.24, 0.9)
  return t
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

-- Rounded plate button: gold for the one main action of an area, style "ghost" for quiet secondary buttons
-- (dropdowns, icon buttons). Disabled buttons turn grey; hover lightens the plate. Text colour comes from the style.
local function paintButton(b, style)
  local s = SKINS[style] or SKINS.button
  UI.Skin(b, style)
  local c = s.text or GOLD
  local fs = b:GetFontString()
  if fs then fs:SetTextColor(c[1], c[2], c[3]) end
  if b.iconTex then b.iconTex:SetVertexColor(c[1], c[2], c[3]) end
end

function UI.Button(parent, text, width, onClick, style)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, 22)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("LEFT", 6, 0); fs:SetPoint("RIGHT", -6, 0); fs:SetWordWrap(false)
  b:SetFontString(fs)
  b:SetPushedTextOffset(1, -1)
  b.gwStyle = style or "button"
  paintButton(b, b.gwStyle)
  local hl = UI.Slice(b, (SKINS[b.gwStyle] or SKINS.button).shape, 6, "HIGHLIGHT", nil, nil, (SKINS[b.gwStyle] or SKINS.button).flip)
  hl:SetColor(1, 0.86, 0.55, 0.12)
  b:SetScript("OnEnable", function(self) paintButton(self, self.gwStyle) end)
  b:SetScript("OnDisable", function(self) paintButton(self, "buttonOff") end)
  b:SetText(text or "")
  if onClick then b:SetScript("OnClick", onClick) end
  function b:SetStyle(st) self.gwStyle = st; paintButton(self, self:IsEnabled() and st or "buttonOff") end
  return b
end

-- Square ghost button with one of the art-set symbols (close, plus, minus, eye, chevron, check).
function UI.IconButton(parent, icon, size, onClick, style)
  local b = UI.Button(parent, "", size, onClick, style or "ghost")
  b:SetHeight(size)
  b.iconTex = UI.Art(b, icon, "OVERLAY")
  b.iconTex:SetPoint("CENTER")
  b.iconTex:SetSize(math.max(8, size - 10), math.max(8, size - 10))
  paintButton(b, b.gwStyle)
  return b
end

-- Switch (pill track with a knob) instead of a tick box; same API as a CheckButton (SetChecked/GetChecked).
-- The label is part of the click area.
function UI.Check(parent, label, checked, onChange)
  local c = CreateFrame("CheckButton", nil, parent)
  c:SetSize(30, 16)
  c.track = UI.Slice(c, "pill", 8, "BACKGROUND", -6)
  c.ringS = UI.Slice(c, "pill_ring", 8, "BORDER", 1)
  c.knob = UI.Art(c, "pill", "ARTWORK")
  c.knob:SetSize(12, 12)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.text:SetPoint("LEFT", c, "RIGHT", 7, 0)
  c.text:SetText(label)
  c:SetHitRectInsets(0, -math.min(400, (c.text:GetStringWidth() or 0) + 8), 0, 0)
  local function paint()
    local on = c:GetChecked() and true or false
    c.knob:ClearAllPoints()
    if on then
      c.knob:SetPoint("RIGHT", -2, 0)
      c.track:SetColor(GOLD_EDGE[1] * 0.55, GOLD_EDGE[2] * 0.55, GOLD_EDGE[3] * 0.55, 1)
      c.ringS:SetColor(GOLD_EDGE[1], GOLD_EDGE[2], GOLD_EDGE[3], 0.9)
      c.knob:SetVertexColor(1, 1, 1, 1)
    else
      c.knob:SetPoint("LEFT", 2, 0)
      c.track:SetColor(0.06, 0.055, 0.05, 1)
      c.ringS:SetColor(0.34, 0.28, 0.20, 1)
      c.knob:SetVertexColor(0.55, 0.52, 0.48, 1)
    end
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
  d.arrow = UI.Art(d, "chevron", "OVERLAY")
  d.arrow:SetSize(12, 12)
  d.arrow:SetPoint("RIGHT", -7, 0)
  d.arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
  d.menu = CreateFrame("Frame", nil, d)
  d.menu:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -3)
  d.menu:SetSize(width, #options * 22 + 10)
  d.menu:SetFrameStrata("FULLSCREEN_DIALOG")
  UI.Skin(d.menu, "menu")
  d.menu:Hide()
  for i, opt in ipairs(options) do
    local item = CreateFrame("Button", nil, d.menu)
    item:SetSize(width - 10, 22)
    item:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 22)
    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    item.text:SetPoint("LEFT", 8, 0)
    item.text:SetText(L[opt[2]])
    UI.Slice(item, "rr3", 6, "HIGHLIGHT"):SetColor(1, 0.8, 0.4, 0.14)
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

-- Section title in gold with a divider that fades out to both ends; the title is flush with the content.
function UI.Section(parent, text, width)
  local fs = UI.Text(parent, text, "GameFontNormal")
  fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local line = UI.Divider(parent)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
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
-- Track and fill with small rounded corners; the numbers use the compact number font of the game's own bars.
function UI.SkillBar(parent, width, height)
  height = height or 14
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(width, height)
  local corner = math.min(6, height / 2)
  bar.track = UI.Slice(bar, "rr3", corner, "BACKGROUND", -6)
  bar.track:SetColor(0.035, 0.032, 0.028, 0.95)
  bar.ringS = UI.Slice(bar, "rr3_ring", corner, "BORDER", 1)
  bar.ringS:SetColor(0.30, 0.25, 0.18, 1)
  bar.fillFrame = CreateFrame("Frame", nil, bar)
  bar.fillFrame:SetPoint("TOPLEFT", 1, -1)
  bar.fillFrame:SetPoint("BOTTOMLEFT", 1, 1)
  bar.fill = UI.Slice(bar.fillFrame, "rr3", math.max(1, corner - 1), "ARTWORK")
  -- the numbers live on a child of the fill frame, so they are drawn above the fill
  local over = CreateFrame("Frame", nil, bar.fillFrame)
  over:SetAllPoints(bar)
  bar.text = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  function bar:SetStatusBarColor(r, g, b) self.fill:SetColor(r, g, b, 1) end
  function bar:SetSkill(rank, max, r, g, b)
    rank, max = rank or 0, math.max(1, max or 1)
    local w = (width - 2) * math.min(1, rank / max)
    self.fillFrame:SetWidth(math.max(1, w))
    self.fill:SetShown(w >= 2)
    self.text:SetText(("%d / %d"):format(rank, max))
    if r then self:SetStatusBarColor(r, g, b) end
  end
  bar:SetStatusBarColor(0.25, 0.62, 0.25)
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
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.hl = UI.Slice(r, "rr3", 6, "HIGHLIGHT")
    r.hl:SetColor(1, 0.8, 0.4, 0.07)
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

-- Action tabs under a Blizzard frame (mailbox, merchant, bank, auction house, trainer): gold tabs at the bottom right,
-- opposite Blizzard's own tabs, each as wide as its label, chained right to left; hidden tabs close the gap.
-- One click = one action (docs/04-COMPLIANCE.md). tabs[i]:Set(label, tip, onClick, enabled) / :Clear()
function UI.FrameTabs(frame, count)
  local tabs = { frame = frame }
  local function layout()
    local prev
    for _, b in ipairs(tabs) do
      if b:IsShown() then
        b:ClearAllPoints()
        if prev then b:SetPoint("TOPRIGHT", prev, "TOPLEFT", -4, 0) else b:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -6, 2) end
        prev = b
      end
    end
  end
  for i = 1, count do
    local b = UI.Button(frame, "", 100, nil, "tabDown")
    b:SetHeight(28)
    b:SetScript("OnEnter", function(self)
      if not self.tip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:Set(label, tip, onClick, enabled)
      self:SetText(label or "")
      local fs = self:GetFontString()
      self:SetWidth(math.max(80, math.min(240, ((fs and fs:GetStringWidth()) or 80) + 28)))
      self.tip = tip
      self:SetScript("OnClick", onClick)
      if enabled == false then self:Disable() else self:Enable() end
      self:Show(); layout()
    end
    function b:Clear() self:Hide(); layout() end
    b:Hide()
    tabs[i] = b
  end
  return tabs
end

-- Gather-list rows: icon, name with a coloured note, a bar (gold = there, blue = in the mail, green = enough),
-- "have / need" on the right and, when rowHeight >= 34, a grey sub line under the bar.
-- rows:Set({ { item, icon, text, note = { text, r, g, b }, sub, have, need, mail, right } })
function UI.ProgressRows(parent, count, width, firstY, rowHeight)
  rowHeight = rowHeight or 40
  local compact = rowHeight < 34
  local iconSize = compact and 20 or 28
  local barW = width - iconSize - 8 - (compact and 52 or 76)
  local rows = {}
  for i = 1, count do
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, rowHeight - 2)
    if i == 1 then r:SetPoint("TOPLEFT", parent, "TOPLEFT", parent.pad or 0, firstY or (parent.top or 0))
    else r:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -2) end
    r.item = UI.ItemButton(r, iconSize)
    r.item:SetPoint("LEFT", 0, 0)
    r.text = r:CreateFontString(nil, "OVERLAY", compact and "GameFontHighlightSmall" or "GameFontHighlight")
    r.text:SetPoint("TOPLEFT", r.item, "TOPRIGHT", 8, compact and 1 or 0)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r.text:SetWidth(barW)
    r.right = r:CreateFontString(nil, "OVERLAY", compact and "GameFontHighlightSmall" or "GameFontNormal")
    r.right:SetPoint("TOPRIGHT", 0, compact and -1 or -2); r.right:SetJustifyH("RIGHT")
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
    r.bar:SetSize(barW, compact and 4 or 6)
    r.bar:SetColorTexture(0.04, 0.035, 0.03, 1)
    r.fill = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.fill:SetPoint("TOPLEFT", r.bar, "TOPLEFT")
    r.fill:SetHeight(compact and 4 or 6)
    r.mail = r:CreateTexture(nil, "ARTWORK", nil, 2)
    r.mail:SetPoint("TOPLEFT", r.fill, "TOPRIGHT")
    r.mail:SetHeight(compact and 4 or 6)
    r.mail:SetColorTexture(0.23, 0.47, 0.75, 1)
    if not compact then
      r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      r.sub:SetPoint("TOPLEFT", r.bar, "BOTTOMLEFT", 0, -3)
      r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false); r.sub:SetWidth(width - iconSize - 8)
    end
    r.hl = UI.Slice(r, "rr3", 6, "HIGHLIGHT")
    r.hl:SetColor(1, 0.8, 0.4, 0.07)
    r:SetScript("OnEnter", function(self) local f = self.item:GetScript("OnEnter"); if f then f(self.item) end end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:Hide()
    rows[i] = r
  end
  function rows:Set(data)
    for i, r in ipairs(self) do
      local d = data[i]
      if d then
        r:Show()
        r.item:SetContent(d.icon, d.item)
        local note = d.note and ("  |cff%02x%02x%02x%s|r"):format((d.note[2] or 1) * 255, (d.note[3] or 1) * 255, (d.note[4] or 1) * 255, d.note[1]) or ""
        r.text:SetText((d.text or "") .. note)
        local need = math.max(1, d.need or 1)
        local have, mail = math.min(d.have or 0, need), math.min(d.mail or 0, d.have or 0)
        local done = (d.have or 0) >= need
        local own = math.max(0, have - mail)
        r.fill:SetWidth(math.max(0.01, barW * own / need)); r.fill:SetShown(own > 0)
        if done then r.fill:SetColorTexture(0.30, 0.72, 0.30, 1) else r.fill:SetColorTexture(0.85, 0.66, 0.30, 1) end
        r.mail:SetWidth(math.max(0.01, barW * math.min(mail, need - own) / need)); r.mail:SetShown(mail > 0 and not done)
        r.right:SetText(d.right or ("%d / %d"):format(d.have or 0, need))
        if done then r.right:SetTextColor(0.4, 1, 0.4) else r.right:SetTextColor(1, 0.82, 0.45) end
        if r.sub then r.sub:SetText(d.sub or "") end
      else
        r:Hide()
      end
    end
  end
  return rows
end

-- The current step, big: icon, category, title, detail, value, one primary action (RestedXP-style "Now").
-- Narrow cards (< 420 px, e.g. beside the team view) stack: text full width, value bottom left beside the button.
function UI.StepCard(parent, width, height)
  local narrow = width < 420
  local c = UI.Inset(parent, width, height or 104, "hl")
  c.icon = UI.ItemButton(c, narrow and 40 or 52)
  c.icon:SetPoint("TOPLEFT", 12, -14)
  c.counter = UI.Text(c, "", "GameFontNormalSmall")
  c.counter:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
  c.title = UI.Text(c, "", narrow and "GameFontNormal" or "GameFontNormalLarge")
  c.title:SetTextColor(1, 1, 1)
  c.title:SetPoint("TOPLEFT", c.counter, "BOTTOMLEFT", 0, -3)
  c.title:SetWidth(width - (narrow and 76 or 230)); c.title:SetWordWrap(false)
  c.detail = UI.Text(c, "", narrow and "GameFontHighlightSmall" or "GameFontHighlight")
  c.detail:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
  c.detail:SetWidth(width - (narrow and 76 or 230))
  if narrow then c.detail:SetHeight(math.max(24, (height or 104) - 96)); c.detail:SetJustifyV("TOP") end
  c.value = UI.Text(c, "", "GameFontNormal")
  if narrow then c.value:SetPoint("BOTTOMLEFT", 14, 18)
  else c.value:SetPoint("TOPRIGHT", -14, -16); c.value:SetJustifyH("RIGHT") end
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

-- Layout (same as ClassPages): header 64 px (logo, title, subtitle, info, close), tab strip 30 px, 14 px from the
-- window edge to the content. The content area stays the 752 x 500 the tabs are built for.
local HEAD_H, TABS_H = 64, 30
local WIN_W, WIN_H = 780, 620
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

-- Window size from the settings (80-130 %).
function UI.ApplyScale()
  if window then window:SetScale(ns.db.settings.windowScale or 1) end
end

-- Short line at the right of the header band (session gold and the like).
function UI.SetHeaderInfo(text)
  if window and window.info then window.info:SetText(text or "") end
end

-- Browser-style tab: icon and name (one word); the active one gets the warm gold plate and a soft gold glow along
-- its bottom edge. Lives on the header frame, so it is drawn above the header plate.
local function tabButton(key, title)
  local b = CreateFrame("Button", nil, window.head)
  b:SetHeight(TABS_H - 2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 10, 0)
  b.icon:SetTexture(TAB_ICONS[key] or ICON); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetText(L[title])
  b:SetWidth(math.max(80, (b.text:GetStringWidth() or 60) + 42))
  UI.Slice(b, "tab", 7, "HIGHLIGHT"):SetColor(1, 0.86, 0.55, 0.08)
  function b:SetActive(on)
    UI.Skin(self, on and "tabOn" or "tab")
    self.icon:SetDesaturated(not on)
    local c = on and GOLD or UI.DIM
    self.text:SetTextColor(c[1], c[2], c[3])
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
    if i == 1 then b:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 14, -HEAD_H - TABS_H)
    else b:SetPoint("BOTTOMLEFT", window.Tabs[i - 1], "BOTTOMRIGHT", 3, 0) end
    window.Tabs[i] = b
    window.tabButtons[key] = b
  end
end

-- Header: a plate rounded like the window at the top, a soft gold gradient over the full width, the logo as a framed
-- square, title and subtitle, the info line and a close button. The tabs sit on a gold line that fades to both sides.
local function buildHeader()
  local head = CreateFrame("Frame", nil, window)
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(HEAD_H + TABS_H - 1)
  window.head = head
  UI.Slice(head, "tab", 7, "BACKGROUND", -5):SetColor(0.082, 0.066, 0.046, 1)
  -- gradient over the full width: the middle part starts at the top edge, the two edge strips below the plate's
  -- rounded corners; the corners themselves get the rounded corner of the plate shape in the same tint
  local TINT_H, CORNER = HEAD_H + TABS_H - 4, 5
  local function tintPart(left, right, top)
    local t = UI.Art(head, "fade_v", "BACKGROUND", -4)
    t:SetPoint("TOPLEFT", head, left[1], left[2], -top)
    t:SetPoint("BOTTOMRIGHT", head, right[1], right[2], -TINT_H)
    t:SetTexCoord(0, 1, top / TINT_H, 1)
    t:SetVertexColor(GOLD_EDGE[1], GOLD_EDGE[2], GOLD_EDGE[3], 0.10)
  end
  tintPart({ "TOPLEFT", CORNER }, { "TOPRIGHT", -CORNER }, 0)
  tintPart({ "TOPLEFT", 0 }, { "TOPLEFT", CORNER }, CORNER)
  tintPart({ "TOPRIGHT", -CORNER }, { "TOPRIGHT", 0 }, CORNER)
  local SHAPE = 16 -- texels of the "tab" shape, drawn 1:1
  for _, side in ipairs({ { "TOPLEFT", 0, CORNER / SHAPE }, { "TOPRIGHT", 1 - CORNER / SHAPE, 1 } }) do
    local c = UI.Art(head, "tab", "BACKGROUND", -4)
    c:SetSize(CORNER, CORNER)
    c:SetPoint(side[1], head, side[1], 0, 0)
    c:SetTexCoord(side[2], side[3], 0, CORNER / SHAPE)
    c:SetVertexColor(GOLD_EDGE[1], GOLD_EDGE[2], GOLD_EDGE[3], 0.095)
  end
  local line = UI.Divider(window)
  line:SetPoint("TOPLEFT", 2, -HEAD_H - TABS_H)
  line:SetPoint("TOPRIGHT", -2, -HEAD_H - TABS_H)
  line:SetVertexColor(GOLD_EDGE[1], GOLD_EDGE[2], GOLD_EDGE[3], 1)

  local logo = head:CreateTexture(nil, "ARTWORK")
  logo:SetSize(36, 36)
  logo:SetPoint("TOPLEFT", 16, -13)
  logo:SetTexture(ICON)
  UI.Round(head, logo, "mask_logo")
  local frame = CreateFrame("Frame", nil, head)
  frame:SetPoint("TOPLEFT", logo, "TOPLEFT", -1, 1)
  frame:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", 1, -1)
  UI.Slice(frame, "rr5_ring", 7, "OVERLAY"):SetColor(GOLD_EDGE[1], GOLD_EDGE[2], GOLD_EDGE[3], 1)
  local title = UI.Text(head, "Goldweaver", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -2)
  title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  window.subtitle = UI.Text(head, "", "GameFontHighlightSmall")
  window.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  window.subtitle:SetTextColor(UI.DIM[1], UI.DIM[2], UI.DIM[3])
  local close = UI.IconButton(head, "close", 24, function() window:Hide() end, "ghost")
  close:SetPoint("TOPRIGHT", -12, -19)
  window.info = UI.Text(head, "", "GameFontHighlightSmall")
  window.info:SetPoint("RIGHT", close, "LEFT", -12, 0)
  window.info:SetJustifyH("RIGHT")
end

local function buildWindow()
  if window then return window end
  window = CreateFrame("Frame", "GoldweaverMainWindow", UIParent)
  window:SetSize(WIN_W, WIN_H)
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
  window:SetScale(ns.db.settings.windowScale or 1)
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

-- Goldweaver: tab "Gold". Each block is drawn for what it says, not as a list:
--   Budget         does my gold cover what is due? one status number, one bar of the costs by kind with a marker
--                  for the team's gold, the strength of the gold support as a three-step scale
--   Costs to 60    when does it get expensive? a column chart per character, columns stacked by kind
--   Level gates    when does the level stop a profession? a level track 1-60 per character with the milestones
--   Make gold      what earns most? ranked ways with a large value and a relative bar; tips without numbers apart
-- Colours of the cost kinds are the same in every block (KIND_COLOR).
local ADDON, ns = ...
local L = ns.L

local UI = ns.UI
local W, LEFT = 752, 372
local RIGHT = W - LEFT - 10
local INNER = LEFT - 20
local KIND_COLOR = {
  class = { 0.40, 0.62, 0.95 }, rank = { 1, 0.78, 0.35 }, riding = { 0.72, 0.52, 0.95 }, materials = { 0.45, 0.80, 0.45 },
}
local KIND_LABEL = { class = "Class", rank = "Ranks", riding = "Riding", materials = "Materials" } -- English keys
local STRENGTHS = { "covered", "light", "strong" }
local STRENGTH_LABEL = { covered = "off", light = "light", strong = "strong" } -- English keys
local STRENGTH_HINT = {
  covered = "Your gold covers the next ten levels: advice as usual.",
  light = "Selling wins unless another use earns 15 % more; gear stays with the main to be sold.",
  strong = "Selling wins unless another use earns 50 % more; everything no plan needs stays to be sold.",
}

local function short(c) return ns.Util.MoneyShort(c) end
-- chart labels: whole gold from 1 g, else silver
local function tiny(c)
  c = math.floor(c or 0)
  if c >= 10000 then return math.floor(c / 10000 + 0.5) .. "g" end
  return math.floor(c / 100) .. "s"
end

local function rect(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

local function tip(frame, build)
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    build(GameTooltip)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

UI.RegisterTab("gold", "Gold", function(frame)
  local content = {}

  -- Budget -----------------------------------------------------------------------------------------------------
  local budget = UI.Inset(frame, LEFT, 150)
  budget:SetPoint("TOPLEFT", 0, 0)
  UI.Section(budget, L["BUDGET · NEXT TEN LEVELS"], INNER):SetPoint("TOPLEFT", 10, -8)
  local status = UI.Text(budget, "", "GameFontNormalLarge")
  status:SetPoint("TOPLEFT", 10, -30); status:SetWidth(190); status:SetWordWrap(false)
  local statusSub = UI.Text(budget, "", "GameFontDisableSmall")
  statusSub:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -3); statusSub:SetWidth(200); statusSub:SetWordWrap(false)

  -- three-step scale of the gold support; the switch turns it off
  local scale = CreateFrame("Frame", nil, budget)
  scale:SetSize(150, 16); scale:SetPoint("TOPRIGHT", -10, -30)
  local steps = {}
  for i, key in ipairs(STRENGTHS) do
    local cell = CreateFrame("Frame", nil, scale)
    cell:SetSize(48, 16); cell:SetPoint("LEFT", (i - 1) * 51, 0)
    cell.bg = rect(cell, "BACKGROUND", 0.2, 0.17, 0.13, 1); cell.bg:SetAllPoints()
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cell.text:SetPoint("CENTER"); cell.text:SetText(L[STRENGTH_LABEL[key]])
    tip(cell, function(t) t:AddLine(L["Gold support"], 1, 0.82, 0); t:AddLine(L[STRENGTH_HINT[key]], 1, 1, 1, true) end)
    steps[key] = cell
  end
  local switch = UI.Check(budget, L["Gold first"], ns.db.settings.cashFirst ~= false, function(on)
    ns.db.settings.cashFirst = on
    ns.Budget.Invalidate(); ns.Earn.Invalidate()
    content:Refresh()
  end)
  switch:SetPoint("TOPRIGHT", scale, "BOTTOMRIGHT", -78, -6)

  -- one bar: the costs by kind; a white marker where the team's gold ends
  local barY = -82
  local barTrack = rect(budget, "BACKGROUND", 0.05, 0.045, 0.04, 1)
  barTrack:SetPoint("TOPLEFT", 10, barY); barTrack:SetSize(INNER, 12)
  local segments = {}
  for _, kind in ipairs(ns.Budget.KINDS) do
    local seg = rect(budget, "ARTWORK", KIND_COLOR[kind][1], KIND_COLOR[kind][2], KIND_COLOR[kind][3], 0.9)
    seg:SetHeight(12); seg:Hide()
    segments[kind] = seg
  end
  local marker = rect(budget, "OVERLAY", 1, 1, 1, 1)
  marker:SetSize(2, 18)
  local legend = {}
  local CHIP_W = INNER / 5
  local function chip(i, r, g, b, w, h)
    local c = CreateFrame("Frame", nil, budget)
    c:SetSize(CHIP_W, 14); c:SetPoint("TOPLEFT", 10 + (i - 1) * CHIP_W, barY - 18)
    c.sq = rect(c, "ARTWORK", r, g, b, 1)
    c.sq:SetSize(w or 8, h or 8); c.sq:SetPoint("LEFT", 0, 0)
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetPoint("LEFT", c.sq, "RIGHT", 4, 0); c.text:SetWidth(CHIP_W - 14); c.text:SetWordWrap(false)
    return c
  end
  for i, kind in ipairs(ns.Budget.KINDS) do legend[kind] = chip(i, KIND_COLOR[kind][1], KIND_COLOR[kind][2], KIND_COLOR[kind][3]) end
  local goldChip = chip(5, 1, 1, 1, 2, 12)
  local nowLine = UI.Text(budget, "", "GameFontHighlightSmall")
  nowLine:SetPoint("TOPLEFT", 10, barY - 38); nowLine:SetWidth(INNER); nowLine:SetWordWrap(false)
  local nowHover = CreateFrame("Frame", nil, budget)
  nowHover:SetPoint("TOPLEFT", nowLine, "TOPLEFT"); nowHover:SetPoint("BOTTOMRIGHT", nowLine, "BOTTOMRIGHT")

  -- Costs to 60: a column chart per character ----------------------------------------------------------------------
  local chart = UI.Inset(frame, LEFT, 176)
  chart:SetPoint("TOPLEFT", budget, "BOTTOMLEFT", 0, -8)
  UI.Section(chart, L["COSTS UP TO LEVEL 60"], INNER):SetPoint("TOPLEFT", 10, -8)
  local MAX_CHARS, MAX_BANDS, BAR_MAX = 2, 6, 78
  local blockW = (INNER - 12) / MAX_CHARS
  local blocks = {}
  for c = 1, MAX_CHARS do
    local b = CreateFrame("Frame", nil, chart)
    b:SetSize(blockW, 140); b:SetPoint("TOPLEFT", 10 + (c - 1) * (blockW + 12), -28)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.name:SetPoint("TOPLEFT", 0, 0); b.name:SetWidth(blockW); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.base = rect(b, "BORDER", 0.45, 0.38, 0.28, 1)
    b.base:SetHeight(1); b.base:SetPoint("BOTTOMLEFT", 0, 16); b.base:SetPoint("BOTTOMRIGHT", 0, 16)
    b.cols = {}
    for i = 1, MAX_BANDS do
      local col = CreateFrame("Frame", nil, b)
      col.segs = {}
      for _, kind in ipairs(ns.Budget.KINDS) do
        local t = rect(col, "ARTWORK", KIND_COLOR[kind][1], KIND_COLOR[kind][2], KIND_COLOR[kind][3], 0.9)
        t:Hide(); col.segs[kind] = t
      end
      col.value = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      col.value:SetJustifyH("CENTER"); col.value:SetWordWrap(false)
      col.label = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      col.label:SetJustifyH("CENTER"); col.label:SetWordWrap(false)
      col:Hide(); col.value:Hide(); col.label:Hide()
      b.cols[i] = col
    end
    b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.empty:SetPoint("TOPLEFT", 0, -20); b.empty:SetWidth(blockW); b.empty:SetJustifyH("LEFT")
    blocks[c] = b
  end

  -- Level gates: a track 1-60 per character --------------------------------------------------------------------------
  local gates = UI.Inset(frame, LEFT, 10)
  gates:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -8)
  gates:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  UI.Section(gates, L["LEVEL GATES"], INNER):SetPoint("TOPLEFT", 10, -8)
  local MAX_MARKS = 6
  local tracks = {}
  for c = 1, MAX_CHARS do
    local t = CreateFrame("Frame", nil, gates)
    t:SetSize(INNER, 64); t:SetPoint("TOPLEFT", 10, -28 - (c - 1) * 68)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.name:SetPoint("TOPLEFT", 0, 0); t.name:SetWidth(INNER); t.name:SetJustifyH("LEFT"); t.name:SetWordWrap(false)
    t.track = rect(t, "BACKGROUND", 0.05, 0.045, 0.04, 1)
    t.track:SetPoint("TOPLEFT", 0, -20); t.track:SetSize(INNER, 6)
    t.fill = rect(t, "ARTWORK", 1, 0.78, 0.35, 0.85)
    t.fill:SetPoint("TOPLEFT", t.track, "TOPLEFT"); t.fill:SetHeight(6)
    t.marks = {}
    for i = 1, MAX_MARKS do
      local m = CreateFrame("Frame", nil, t)
      m:SetSize(14, 26)
      m.tick = rect(m, "OVERLAY", 1, 1, 1, 1)
      m.tick:SetSize(2, 12); m.tick:SetPoint("TOP", 0, 0)
      m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      m.text:SetPoint("TOP", m.tick, "BOTTOM", 0, -1)
      m:Hide()
      t.marks[i] = m
    end
    t.detail = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.detail:SetPoint("TOPLEFT", 0, -46); t.detail:SetWidth(INNER); t.detail:SetJustifyH("LEFT"); t.detail:SetWordWrap(false)
    t.hover = CreateFrame("Frame", nil, t)
    t.hover:SetAllPoints()
    t:Hide()
    tracks[c] = t
  end
  local noGates = UI.Text(gates, "", "GameFontDisableSmall")
  noGates:SetPoint("TOPLEFT", 10, -30); noGates:SetWidth(INNER)

  -- Make gold: ranked ways with a value and a relative bar; tips apart -------------------------------------------------
  local earn = UI.Inset(frame, RIGHT, 10)
  earn:SetPoint("TOPLEFT", budget, "TOPRIGHT", 10, 0)
  earn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local EW = RIGHT - 20
  UI.Section(earn, L["MAKE GOLD · WHAT EARNS MOST"], EW):SetPoint("TOPLEFT", 10, -8)
  local MAX_WAYS, WAY_H = 5, 50
  local ways = {}
  for i = 1, MAX_WAYS do
    local r = CreateFrame("Button", nil, earn)
    r:SetSize(EW, WAY_H - 4); r:SetPoint("TOPLEFT", 10, -28 - (i - 1) * WAY_H)
    r.icon = UI.ItemButton(r, 30); r.icon:SetPoint("TOPLEFT", 0, -2)
    r.value = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.value:SetPoint("TOPRIGHT", 0, -2); r.value:SetJustifyH("RIGHT"); r.value:SetWordWrap(false)
    r.title = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.title:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0); r.title:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3); r.sub:SetWidth(EW - 38 - 76)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r.btn = UI.Button(r, "", 70, nil)
    r.btn:SetHeight(20); r.btn:SetPoint("TOPRIGHT", r.value, "BOTTOMRIGHT", 0, -3)
    r.barTrack = rect(r, "BACKGROUND", 0.05, 0.045, 0.04, 1)
    r.barTrack:SetPoint("BOTTOMLEFT", 38, 0); r.barTrack:SetSize(EW - 38, 3)
    r.bar = rect(r, "ARTWORK", 1, 0.78, 0.35, 0.9)
    r.bar:SetPoint("BOTTOMLEFT", 38, 0); r.bar:SetHeight(3)
    r:Hide()
    ways[i] = r
  end
  -- tips start right below the last ranked way (placed in refreshEarn)
  local tipsTitle = UI.Section(earn, L["TIPS FOR YOUR TEAM"], EW)
  local MAX_TIPS, TIP_H = 10, 20
  local tips = {}
  for i = 1, MAX_TIPS do
    local r = CreateFrame("Frame", nil, earn)
    r:SetSize(EW, TIP_H - 2)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.effort = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.effort:SetPoint("RIGHT", 0, 0); r.effort:SetJustifyH("RIGHT")
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0); r.text:SetPoint("RIGHT", r.effort, "LEFT", -6, 0)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    r:Hide()
    tips[i] = r
  end

  -- Refresh --------------------------------------------------------------------------------------------------------------
  local function refreshBudget(s)
    local me = ns.Chars.Current()
    if s.nowGap > 0 then
      status:SetText(("|cffff6040%s %s|r"):format(L["Missing"], short(s.nowGap)))
      statusSub:SetText((L["due now %s, %s has %s"]):format(short(s.nowDue), me and me.name or "?", short(s.nowCash)))
    elseif s.gap > 0 then
      status:SetText(("|cffffb040%s %s|r"):format(L["Missing"], short(s.gap)))
      statusSub:SetText((L["due %s, team gold %s"]):format(short(s.due), short(s.cash)))
    else
      status:SetText(("|cff80ff80%s|r"):format(L["Covered"]))
      statusSub:SetText((L["due %s, team gold %s"]):format(short(s.due), short(s.cash)))
    end
    local active = ns.db.settings.cashFirst == false and "covered" or s.strength
    for key, cell in pairs(steps) do
      local on = key == active
      local c = on and (key == "strong" and { 0.75, 0.30, 0.22 } or (key == "light" and { 0.70, 0.52, 0.20 } or { 0.30, 0.50, 0.30 })) or { 0.16, 0.14, 0.11 }
      cell.bg:SetColorTexture(c[1], c[2], c[3], 1)
      cell.text:SetTextColor(on and 1 or 0.55, on and 1 or 0.52, on and 1 or 0.48)
    end
    switch:SetChecked(ns.db.settings.cashFirst ~= false)

    -- bar segments scaled to the larger of costs and gold, so the marker always fits
    local scaleMax = math.max(s.due, s.cash, 1)
    local x = 0
    for _, kind in ipairs(ns.Budget.KINDS) do
      local v = s.byKind[kind] or 0
      local seg = segments[kind]
      if v > 0 then
        local w = math.max(2, INNER * v / scaleMax)
        seg:ClearAllPoints(); seg:SetPoint("TOPLEFT", barTrack, "TOPLEFT", x, 0); seg:SetWidth(w); seg:Show()
        x = x + w
      else seg:Hide() end
      local entry = legend[kind]
      entry.text:SetText(("%s %s"):format(L[KIND_LABEL[kind]], v > 0 and tiny(v) or "–"))
      entry.text:SetTextColor(v > 0 and 1 or 0.5, v > 0 and 1 or 0.5, v > 0 and 1 or 0.5)
    end
    goldChip.text:SetText(("%s %s"):format(L["Gold"], tiny(s.cash)))
    marker:ClearAllPoints()
    marker:SetPoint("TOP", barTrack, "TOPLEFT", math.min(INNER - 1, INNER * s.cash / scaleMax), 3)

    if #s.nowItems > 0 then
      local names = {}
      for _, e in ipairs(s.nowItems) do names[#names + 1] = e.label end
      nowLine:SetText((L["Due now: %s"]):format(table.concat(names, ", ")))
    else
      nowLine:SetText(L["Nothing due now. Hover for the list."])
    end
    tip(nowHover, function(t)
      t:AddLine(L["Due in the next ten levels"], 1, 0.82, 0)
      for i, e in ipairs(s.items) do
        if i > 12 then break end
        t:AddDoubleLine(("%s · %s · %s"):format(e.label, e.rec.name, (L["level %d"]):format(e.level)), short(e.copper), 1, 1, 1, 1, 0.82, 0.45)
      end
    end)
  end

  local function refreshChart()
    local chars, maxTotal = {}, 1
    for _, rec in ipairs(ns.Chars.All(ns.Chars.MarketKey())) do
      if rec.role ~= "none" and #chars < MAX_CHARS then
        local bands = ns.Budget.Timeline(rec)
        for _, b in ipairs(bands) do if b.total > maxTotal then maxTotal = b.total end end
        chars[#chars + 1] = { rec = rec, bands = bands }
      end
    end
    for c, block in ipairs(blocks) do
      local entry = chars[c]
      block:SetShown(entry ~= nil)
      if entry then
        block.name:SetText(("%s · %s"):format(entry.rec.name, (L["level %d"]):format(entry.rec.level or 1)))
        local n = math.min(MAX_BANDS, #entry.bands)
        local slot = blockW / MAX_BANDS
        local colW = slot - 6
        block.empty:SetText(n == 0 and L["Level 60: nothing left to pay."] or "")
        for i, col in ipairs(block.cols) do
          local b = entry.bands[i]
          if b and i <= n then
            local x = (i - 1) * slot + 3
            col:ClearAllPoints(); col:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", x, 17); col:SetSize(colW, BAR_MAX)
            local y = 0
            for _, kind in ipairs(ns.Budget.KINDS) do
              local v = (kind == "class" and b.class) or (kind == "rank" and b.ranks) or (kind == "riding" and b.riding) or b.materials
              local t = col.segs[kind]
              if v > 0 then
                local h = math.max(1, BAR_MAX * v / maxTotal)
                t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, y); t:SetSize(colW, h); t:Show()
                y = y + h
              else t:Hide() end
            end
            col.value:ClearAllPoints(); col.value:SetPoint("BOTTOM", col, "BOTTOMLEFT", colW / 2, y + 2); col.value:SetWidth(slot)
            col.value:SetText(b.total > 0 and tiny(b.total) or "")
            col.label:ClearAllPoints(); col.label:SetPoint("TOP", col, "BOTTOM", 0, -3); col.label:SetWidth(slot)
            col.label:SetText(tostring(b.to))
            col:Show(); col.value:Show(); col.label:Show()
            tip(col, function(t)
              t:AddLine((L["%s, level %d to %d"]):format(entry.rec.name, b.from, b.to), 1, 0.82, 0)
              t:AddDoubleLine(L["Class"], short(b.class), 1, 1, 1, KIND_COLOR.class[1], KIND_COLOR.class[2], KIND_COLOR.class[3])
              t:AddDoubleLine(L["Ranks"], short(b.ranks), 1, 1, 1, KIND_COLOR.rank[1], KIND_COLOR.rank[2], KIND_COLOR.rank[3])
              t:AddDoubleLine(L["Riding"], short(b.riding), 1, 1, 1, KIND_COLOR.riding[1], KIND_COLOR.riding[2], KIND_COLOR.riding[3])
              t:AddDoubleLine(L["Materials"], short(b.materials), 1, 1, 1, KIND_COLOR.materials[1], KIND_COLOR.materials[2], KIND_COLOR.materials[3])
              t:AddLine((L["Materials as if bought; %d %% of them have a price."]):format(math.floor(b.materialsPriced * 100)), 0.7, 0.7, 0.7, true)
            end)
          else
            col:Hide(); col.value:Hide(); col.label:Hide()
          end
        end
      end
    end
  end

  local function refreshGates()
    local shown = 0
    for _, rec in ipairs(ns.Chars.All(ns.Chars.MarketKey())) do
      local marks = rec.role ~= "none" and ns.Gates.Milestones(rec) or {}
      if #marks > 0 and shown < MAX_CHARS then
        shown = shown + 1
        local t = tracks[shown]
        t:Show()
        local level = rec.level or 1
        local list = ns.Gates.For(rec)
        local first = list[1]
        t.name:SetText(("%s · %s"):format(rec.name, (L["level %d"]):format(level)))
        t.fill:SetWidth(math.max(1, INNER * (level - 1) / 59))
        for i, m in ipairs(t.marks) do
          local ms = marks[i]
          if ms then
            m:ClearAllPoints(); m:SetPoint("TOP", t.track, "TOPLEFT", INNER * (ms.level - 1) / 59, 3)
            -- the next rank gate that already stops a profession is red, the next one ahead gold, later ones grey
            local urgent = first and ms.level == first.reqLevel and first.severity ~= "later"
            local c = urgent and { 1, 0.4, 0.3 } or (i == 1 and { 1, 0.82, 0.45 } or { 0.62, 0.57, 0.50 })
            if ms.kind == "riding" and not next(ms.ranks) then c = KIND_COLOR.riding end
            m.tick:SetColorTexture(c[1], c[2], c[3], 1)
            m.text:SetText(tostring(ms.level)); m.text:SetTextColor(c[1], c[2], c[3])
            m:Show()
          else m:Hide() end
        end
        if first then
          t.detail:SetText((L["%s · %d levels to go"]):format(ns.Gates.Title(first), first.needLevel))
        else
          t.detail:SetText((L["Next: %s at level %d"]):format(marks[1].label, marks[1].level))
        end
        tip(t.hover, function(tt)
          tt:AddLine(rec.name, 1, 0.82, 0)
          for _, ms in ipairs(marks) do
            tt:AddDoubleLine((L["level %d"]):format(ms.level), ms.label .. (#ms.professions > 0 and (" · " .. table.concat(ms.professions, ", ")) or ""), 1, 1, 1, 1, 1, 1)
          end
          for _, g in ipairs(list) do
            local hint = ns.Gates.WhileLevelling(g)
            if hint then tt:AddLine(hint, 0.6, 0.85, 1, true) end
          end
        end)
      end
    end
    for c = shown + 1, MAX_CHARS do tracks[c]:Hide() end
    noGates:SetText(shown == 0 and L["No level gate ahead: every profession can reach its cap."] or "")
  end

  local function refreshEarn()
    local list = ns.Earn.List()
    local ranked, plain = {}, {}
    for _, w in ipairs(list) do
      if w.perHour or w.total or w.perCraft then ranked[#ranked + 1] = w else plain[#plain + 1] = w end
    end
    local top = ranked[1] and math.max(1, ranked[1].score or 1) or 1
    for i, r in ipairs(ways) do
      local w = ranked[i]
      if w then
        r:Show()
        r.icon:SetContent(w.icon, w.item)
        r.icon.tooltip = w.detail
        r.title:SetText(w.title)
        r.sub:SetText(w.detail)
        r.value:SetText(ns.Earn.ValueText(w))
        r.bar:SetWidth(math.max(2, (EW - 38) * math.max(0, w.score or 0) / top))
        if w.action then r.btn:SetText(w.action.label); r.btn:SetScript("OnClick", w.action.fn); r.btn:Show() else r.btn:Hide() end
        tip(r, function(t) t:AddLine(w.title, 1, 0.82, 0); t:AddLine(w.detail, 1, 1, 1, true) end)
      else r:Hide() end
    end
    local shownWays = math.max(1, math.min(MAX_WAYS, #ranked))
    local tipsY = -28 - shownWays * WAY_H - 6
    tipsTitle:ClearAllPoints(); tipsTitle:SetPoint("TOPLEFT", 10, tipsY)
    -- as many tips as fit above the bottom of the card (content area is 500 px high)
    local room = math.floor((500 + tipsY - 22 - 8) / TIP_H)
    if #ranked == 0 then
      ways[1]:Show(); ways[1].icon:SetContent("Interface\\Icons\\INV_Misc_Coin_01")
      ways[1].title:SetText(L["No estimate yet"]); ways[1].sub:SetText(L["Search the auction house once so Goldweaver knows prices."])
      ways[1].value:SetText(""); ways[1].bar:SetWidth(1); ways[1].btn:Hide()
    end
    for i, r in ipairs(tips) do
      local w = i <= room and plain[i] or nil
      if w then
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, tipsY - 22 - (i - 1) * TIP_H)
        r:Show()
        r.icon:SetTexture(w.icon or "Interface\\Icons\\INV_Misc_Note_01")
        r.text:SetText(w.title)
        r.effort:SetText(ns.Earn.ValueText(w))
        tip(r, function(t) t:AddLine(w.title, 1, 0.82, 0); t:AddLine(w.detail, 1, 1, 1, true) end)
      else r:Hide() end
    end
  end

  function content:Refresh()
    local s = ns.Budget.Summary()
    refreshBudget(s)
    refreshChart()
    refreshGates()
    refreshEarn()
  end
  return content
end)

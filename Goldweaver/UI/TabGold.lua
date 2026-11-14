-- Goldweaver: tab "Gold". Left: the budget (what is due now and in the next ten levels against the team's gold, the
-- strength of the gold support), costs by level for each character, and the level gates ahead. Right: ways to make
-- gold for this character, ranked by what they should earn, each with one button.
local ADDON, ns = ...
local L = ns.L

local UI = ns.UI
local W, LEFT = 752, 372
local RIGHT = W - LEFT - 10
local STRENGTH_TEXT = {
  covered = "Gold support: off · gold covers ten levels",
  light = "Gold support: light · sell first unless +15 %",
  strong = "Gold support: strong · sell first unless +50 %",
}
local KIND_TEXT = { class = "class", rank = "profession", riding = "riding", materials = "materials" } -- English keys

local function short(c) return ns.Util.MoneyShort(c) end

UI.RegisterTab("gold", "Gold", function(frame)
  local content = {}

  -- Budget ---------------------------------------------------------------------------------------------------
  local budget = UI.Inset(frame, LEFT, 250)
  budget:SetPoint("TOPLEFT", 0, 0)
  local budgetTitle = UI.Section(budget, L["BUDGET"], LEFT - 20)
  budgetTitle:SetPoint("TOPLEFT", 10, -8)
  local cashLine = UI.Text(budget, "", "GameFontHighlight")
  cashLine:SetPoint("TOPLEFT", 10, -30); cashLine:SetWidth(LEFT - 20); cashLine:SetWordWrap(false)
  local nowLine = UI.Text(budget, "", "GameFontHighlightSmall")
  nowLine:SetPoint("TOPLEFT", cashLine, "BOTTOMLEFT", 0, -4); nowLine:SetWidth(LEFT - 20); nowLine:SetWordWrap(false)
  local modeLine = UI.Text(budget, "", "GameFontDisableSmall")
  modeLine:SetPoint("TOPLEFT", nowLine, "BOTTOMLEFT", 0, -4); modeLine:SetWidth(LEFT - 70); modeLine:SetWordWrap(false)
  local modeSwitch = UI.Check(budget, "", ns.db.settings.cashFirst ~= false, function(on)
    ns.db.settings.cashFirst = on
    ns.Budget.Invalidate(); ns.Earn.Invalidate()
    content:Refresh()
  end)
  modeSwitch:SetPoint("TOPRIGHT", -12, -66)
  local dueRows = UI.IconRows(budget, 4, LEFT - 20, -92, 38)

  -- Costs by level --------------------------------------------------------------------------------------------
  local timeline = UI.Inset(frame, LEFT, 112)
  timeline:SetPoint("TOPLEFT", budget, "BOTTOMLEFT", 0, -8)
  local timelineTitle = UI.Section(timeline, L["COSTS BY LEVEL"], LEFT - 20)
  timelineTitle:SetPoint("TOPLEFT", 10, -8)
  local timelineLines = UI.Lines(timeline, 3, LEFT - 20, "GameFontHighlightSmall", -30, true)
  local timelineNote = UI.Text(timeline, L["Class skills, ranks, riding; materials as if bought. Hover for details."], "GameFontDisableSmall")
  timelineNote:SetPoint("BOTTOMLEFT", 10, 8); timelineNote:SetWidth(LEFT - 20); timelineNote:SetWordWrap(false)
  local timelineHover = CreateFrame("Frame", nil, timeline)
  timelineHover:SetPoint("TOPLEFT", 10, -28); timelineHover:SetPoint("BOTTOMRIGHT", -10, 24)
  timelineHover:EnableMouse(true)
  timelineHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Level gates -----------------------------------------------------------------------------------------------
  local gates = UI.Inset(frame, LEFT, 10)
  gates:SetPoint("TOPLEFT", timeline, "BOTTOMLEFT", 0, -8)
  gates:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local gatesTitle = UI.Section(gates, L["LEVEL GATES"], LEFT - 20)
  gatesTitle:SetPoint("TOPLEFT", 10, -8)
  local gateRows = UI.IconRows(gates, 2, LEFT - 20, -28, 38)

  -- Make gold -------------------------------------------------------------------------------------------------
  local earn = UI.Inset(frame, RIGHT, 10)
  earn:SetPoint("TOPLEFT", budget, "TOPRIGHT", 10, 0)
  earn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local earnTitle = UI.Section(earn, L["MAKE GOLD"], RIGHT - 20)
  earnTitle:SetPoint("TOPLEFT", 10, -8)
  local earnRows = UI.IconRows(earn, 9, RIGHT - 20, -30, 48)
  local earnNote = UI.Text(earn, "", "GameFontDisableSmall")
  earnNote:SetPoint("BOTTOMLEFT", 10, 8); earnNote:SetWidth(RIGHT - 20); earnNote:SetWordWrap(false)

  function content:Refresh()
    local s = ns.Budget.Summary()
    local me = ns.Chars.Current()
    cashLine:SetText((L["Team gold %s · due in the next ten levels %s"]):format(short(s.cash), short(s.due)))
    if s.nowDue > 0 then
      local who = me and me.name or "?"
      if s.nowGap > 0 then
        nowLine:SetText((L["|cffff6040Due now for %s: %s, you have %s|r"]):format(who, short(s.nowDue), short(s.nowCash)))
      else
        nowLine:SetText((L["|cff80ff80Due now for %s: %s, you have %s|r"]):format(who, short(s.nowDue), short(s.nowCash)))
      end
    elseif s.gap > 0 then
      nowLine:SetText((L["|cffffb040%s missing in the next ten levels|r"]):format(short(s.gap)))
    else
      nowLine:SetText((L["|cff80ff80Covered, %s to spare|r"]):format(short(-s.gap)))
    end
    modeSwitch:SetChecked(ns.db.settings.cashFirst ~= false)
    modeLine:SetText(ns.db.settings.cashFirst == false and L["Gold support switched off."] or L[STRENGTH_TEXT[s.strength]])

    local rows = {}
    local items = s.nowGap > 0 and s.nowItems or s.items
    for i = 1, math.min(4, #items) do
      local e = items[i]
      local who = e.rec.name
      local when = e.level <= (e.rec.level or 1) and L["now"] or (L["level %d"]):format(e.level)
      rows[#rows + 1] = { icon = e.icon, item = e.item, text = e.label,
        sub = ("%s · %s · %s%s"):format(who, when, L[KIND_TEXT[e.kind] or e.kind], e.estimate and (" · " .. L["estimate"]) or ""),
        right = short(e.copper) }
    end
    if #rows == 0 then rows[1] = { icon = "Interface\\Icons\\INV_Misc_Coin_01", text = L["Nothing due"], color = { 0.7, 0.7, 0.7 } } end
    dueRows:Set(rows)

    -- costs by level, one line per active character
    local lines, details = {}, {}
    for _, rec in ipairs(ns.Chars.All(ns.Chars.MarketKey())) do
      if rec.role ~= "none" and #lines < 3 then
        local parts = {}
        local bands = ns.Budget.Timeline(rec)
        for i = 1, math.min(4, #bands) do
          local b = bands[i]
          parts[#parts + 1] = ("%d–%d %s%s"):format(b.from, b.to, short(b.total), b.riding > 0 and "*" or "")
          details[#details + 1] = (L["%s %d–%d: class %s, ranks %s, riding %s, materials %s (%d %% priced)"]):format(rec.name,
            b.from, b.to, short(b.class), short(b.ranks), short(b.riding), short(b.materials), math.floor(b.materialsPriced * 100))
        end
        lines[#lines + 1] = { ("%s: %s"):format(rec.name, #parts > 0 and table.concat(parts, " · ") or L["level 60"]), 1, 1, 1 }
      end
    end
    timelineLines:Set(lines)
    timelineHover:SetScript("OnEnter", function(hover)
      GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L["Costs by level"], 1, 0.82, 0)
      for _, d in ipairs(details) do GameTooltip:AddLine(d, 1, 1, 1, true) end
      GameTooltip:AddLine(L["* includes riding at level 40."], 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end)

    local grows = {}
    for _, g in ipairs(ns.Gates.List()) do
      if #grows >= 2 then break end
      grows[#grows + 1] = { icon = ns.Steps.ICON.train, text = ("%s · %s"):format(g.rec.name, ns.Gates.Title(g)),
        sub = ns.Gates.Detail(g), tooltip = ns.Gates.Detail(g) .. (ns.Gates.WhileLevelling(g) and ("\n" .. ns.Gates.WhileLevelling(g)) or ""),
        color = g.severity == "blocked" and { 1, 0.45, 0.35 } or (g.severity == "soon" and { 1, 0.82, 0.3 } or { 1, 1, 1 }) }
    end
    if #grows == 0 then grows[1] = { icon = "Interface\\Icons\\Achievement_General", text = L["No level gate ahead"], color = { 0.7, 0.7, 0.7 } } end
    gateRows:Set(grows)

    local erows = {}
    local own = false
    for _, w in ipairs(ns.Earn.List()) do
      if #erows >= 9 then break end
      own = own or w.own
      erows[#erows + 1] = { icon = w.icon, item = w.item, text = w.title, sub = w.detail, tooltip = w.detail,
        right = ns.Earn.ValueText(w), rightColor = (w.perHour or w.total or w.perCraft) and { 1, 0.82, 0.3 } or { 0.6, 0.6, 0.6 },
        button = w.action and { w.action.label, w.action.fn } or nil }
    end
    if #erows == 0 then erows[1] = { icon = "Interface\\Icons\\INV_Misc_Coin_01", text = L["Search the auction house once so Goldweaver knows prices."], color = { 0.7, 0.7, 0.7 } } end
    earnRows:Set(erows)
    earnNote:SetText(L["Estimates from your own prices and gathering pace."])
  end
  return content
end)

-- Goldweaver: tab "Guide" (docs/14-UI-FUEHRUNG.md). RestedXP-style guidance: one big current step with one
-- action, the next steps below, and on the right what this zone offers right now.
local ADDON, ns = ...
local L = ns.L

local UI = ns.UI
local LEFT, RIGHT = 490, 252

UI.RegisterTab("guide", "Guide", function(frame)
  local content = {}

  local card = UI.StepCard(frame, LEFT)
  card:SetPoint("TOPLEFT", 0, 0)

  local after = UI.Inset(frame, LEFT, 300)
  after:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -8)
  local afterTitle = UI.Section(after, L["NEXT"], LEFT - 20)
  afterTitle:SetPoint("TOPLEFT", 10, -8)
  local list = UI.StepList(after, 6, LEFT - 20, -28)

  local health = UI.Inset(frame, LEFT, 80)
  health:SetPoint("TOPLEFT", after, "BOTTOMLEFT", 0, -8)
  health:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local healthIcon = health:CreateTexture(nil, "ARTWORK")
  healthIcon:SetSize(20, 20)
  healthIcon:SetPoint("TOPLEFT", 12, -12)
  local healthText = UI.Text(health, "", "GameFontHighlight")
  healthText:SetPoint("LEFT", healthIcon, "RIGHT", 8, 0)
  healthText:SetWidth(LEFT - 180)
  local healthSub = UI.Text(health, "", "GameFontDisableSmall")
  healthSub:SetPoint("TOPLEFT", healthIcon, "BOTTOMLEFT", 0, -6)
  healthSub:SetWidth(LEFT - 40)
  local reportButton = UI.Button(health, L["Report"], 110, function() ns.Debug.Run() end)
  reportButton:SetPoint("TOPRIGHT", -12, -10)

  -- right column: this zone right now
  local side = UI.Inset(frame, RIGHT, 10)
  side:SetPoint("TOPLEFT", card, "TOPRIGHT", 10, 0)
  side:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local zoneTitle = UI.Section(side, L["ON THE ROAD"], RIGHT - 20)
  zoneTitle:SetPoint("TOPLEFT", 10, -8)
  local zoneFit = UI.Text(side, "", "GameFontHighlightSmall")
  zoneFit:SetPoint("TOPLEFT", 10, -28); zoneFit:SetWidth(RIGHT - 20)
  local gatherRows = UI.IconRows(side, 4, RIGHT - 20, -46, 34)
  local routeTitle = UI.Section(side, L["ON YOUR ROUTE"], RIGHT - 20)
  routeTitle:SetPoint("TOPLEFT", 10, -192)
  local routeLines = UI.Lines(side, 3, RIGHT - 20, "GameFontHighlightSmall", -212)
  local todayTitle = UI.Section(side, L["TODAY"], RIGHT - 20)
  todayTitle:SetPoint("TOPLEFT", 10, -300)
  local todayPairs = UI.Pairs(side, 3, 90, RIGHT - 110, -320)
  local more = UI.Button(side, L["Everything about this zone"], RIGHT - 20, function() UI.Open("field") end)
  more:SetPoint("BOTTOMLEFT", 10, 10)

  function content:Refresh()
    local steps = ns.Steps.Build(7)
    card:SetStep(steps[1], 1, #steps)
    list:SetSteps(steps, 1)
    afterTitle:SetText(#steps > 1 and L["NEXT"] or L["NEXT · nothing more"])

    local s = ns.Checks.Summary()
    local finding = ns.Diagnose and ns.Diagnose.Latest()[1]
    reportButton:SetText(L["Report"])
    reportButton:SetScript("OnClick", function() ns.Debug.Run() end)
    if finding and finding.severity ~= "info" or (finding and finding.fix) then
      local isError = finding.severity == "error"
      healthIcon:SetTexture(isError and "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" or "Interface\\FriendsFrame\\InformationIcon")
      healthText:SetText(finding.title)
      if isError then healthText:SetTextColor(1, 0.5, 0.4) else healthText:SetTextColor(1, 0.82, 0) end
      healthSub:SetText(finding.detail or "")
      if finding.fix and finding.fixLabel then
        reportButton:SetText(finding.fixLabel)
        reportButton:SetScript("OnClick", function() finding.fix(); ns.Diagnose.Run(); content:Refresh() end)
      end
    else
      healthIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
      healthText:SetText(L["All ready"])
      healthText:SetTextColor(0.5, 1, 0.5)
      healthSub:SetText((L["Self-test at login · %d of %d features confirmed in game"]):format(s.pass, s.total))
    end

    local ok, report = pcall(ns.Field.Analyze)
    if ok and report then
      zoneTitle:SetText((L["ON THE ROAD · %s"]):format(report.name:upper()))
      if report.zone and report.zone.city then
        zoneFit:SetText(L["City: mail, auction house and trainers."])
      elseif report.zone then
        local fitText = report.fit == "ok" and L["fits your level"] or (report.fit == "low" and L["too easy for you"] or L["still too hard"])
        zoneFit:SetText((L["Level %d–%d · %s"]):format(report.zone.min, report.zone.max, fitText))
      else
        zoneFit:SetText(L["No zone data; finds are learned while gathering."])
      end
      local rows = {}
      for _, r in ipairs(report.gather) do
        if #rows >= 4 then break end
        if r.hasProfession or r.demand then
          local color = r.color and ns.Data.Gathering.COLORS[r.color] or { 1, 1, 1 }
          rows[#rows + 1] = {
            item = r.item, text = UI.ItemName(r.item), color = color,
            sub = r.demand and (L["wanted ×%d"]):format(r.demand.qty) or (r.required and (L["from skill %d"]):format(r.required) or ""),
            right = r.price and UI.Money(r.price) or "",
          }
        end
      end
      if report.mobs and report.mobs.cloth and #rows < 4 then
        rows[#rows + 1] = { item = report.mobs.cloth, text = UI.ItemName(report.mobs.cloth), sub = L["from humanoids"],
          right = report.mobs.clothPrice and UI.Money(report.mobs.clothPrice) or "" }
      end
      if #rows == 0 then rows[1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = L["Nothing suitable here"], sub = L["See 'Everything about this zone'"], color = { 0.7, 0.7, 0.7 } } end
      gatherRows:Set(rows)
      local route = report.route
      if route and #route.zones > 0 then
        local lines = {}
        for i = 1, math.min(3, #route.zones) do
          local z = route.zones[i]
          local zd = ns.Data.Zones.list[z.id]
          lines[i] = { ("%s%s"):format(z.name, zd and (" (%d–%d)"):format(zd.min, zd.max) or ""), 0.9, 0.9, 0.9 }
        end
        routeLines:Set(lines)
        routeTitle:SetText(L["ON YOUR ROUTE (RestedXP)"])
        routeTitle:Show(); routeTitle.line:Show()
        todayTitle:SetPoint("TOPLEFT", 10, -300); todayPairs[1].label:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -320)
      else
        -- RestedXP not installed or no guide active: the section is not shown at all
        routeLines:Set({})
        routeTitle:Hide(); routeTitle.line:Hide()
        todayTitle:SetPoint("TOPLEFT", 10, -192); todayPairs[1].label:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -212)
      end
    end

    local today = ns.Ledger.Totals(1)
    local delta = ns.Ledger.SessionDelta()
    todayPairs:Set({
      { L["Session"], (delta >= 0 and "+" or "") .. UI.Money(delta) },
      { L["Sold"], ("%s (%d)"):format(UI.Money(today.sales), today.count) },
      { L["Gold"], UI.Money(GetMoney and GetMoney() or 0) },
    })
  end
  return content
end)

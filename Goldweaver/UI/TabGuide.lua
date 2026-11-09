-- Goldweaver: tab "Leitfaden" (docs/14-UI-FUEHRUNG.md). RestedXP-style guidance: one big current step with one
-- action, the next steps below, and on the right what this zone offers right now.
local ADDON, ns = ...

local UI = ns.UI
local LEFT, RIGHT = 490, 252

UI.RegisterTab("guide", "Leitfaden", function(frame)
  local content = {}

  local card = UI.StepCard(frame, LEFT)
  card:SetPoint("TOPLEFT", 0, 0)

  local after = UI.Inset(frame, LEFT, 300)
  after:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -8)
  local afterTitle = UI.Section(after, "DANACH", LEFT - 20)
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
  local reportButton = UI.Button(health, "Bericht", 110, function() ns.Debug.Run() end)
  reportButton:SetPoint("TOPRIGHT", -12, -10)

  -- right column: this zone right now
  local side = UI.Inset(frame, RIGHT, 10)
  side:SetPoint("TOPLEFT", card, "TOPRIGHT", 10, 0)
  side:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local zoneTitle = UI.Section(side, "UNTERWEGS", RIGHT - 20)
  zoneTitle:SetPoint("TOPLEFT", 10, -8)
  local zoneFit = UI.Text(side, "", "GameFontHighlightSmall")
  zoneFit:SetPoint("TOPLEFT", 10, -28); zoneFit:SetWidth(RIGHT - 20)
  local gatherRows = UI.IconRows(side, 4, RIGHT - 20, -46, 34)
  local routeTitle = UI.Section(side, "AUF DEINER ROUTE", RIGHT - 20)
  routeTitle:SetPoint("TOPLEFT", 10, -192)
  local routeLines = UI.Lines(side, 3, RIGHT - 20, "GameFontHighlightSmall", -212)
  local todayTitle = UI.Section(side, "HEUTE", RIGHT - 20)
  todayTitle:SetPoint("TOPLEFT", 10, -300)
  local todayPairs = UI.Pairs(side, 3, 90, RIGHT - 110, -320)
  local more = UI.Button(side, "Alles zu dieser Zone", RIGHT - 20, function() UI.Open("field") end)
  more:SetPoint("BOTTOMLEFT", 10, 10)

  function content:Refresh()
    local steps = ns.Steps.Build(7)
    card:SetStep(steps[1], 1, #steps)
    list:SetSteps(steps, 1)
    afterTitle:SetText(#steps > 1 and "DANACH" or "DANACH · nichts weiter")

    local s = ns.Checks.Summary()
    local finding = ns.Diagnose and ns.Diagnose.Latest()[1]
    reportButton:SetText("Bericht")
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
      healthText:SetText("Alles bereit")
      healthText:SetTextColor(0.5, 1, 0.5)
      healthSub:SetText(("Selbstprüfung beim Login · %d von %d Funktionen im Spiel bestätigt"):format(s.pass, s.total))
    end

    local ok, report = pcall(ns.Field.Analyze)
    if ok and report then
      zoneTitle:SetText(("UNTERWEGS · %s"):format(report.name:upper()))
      if report.zone and report.zone.city then
        zoneFit:SetText("Stadt: Post, Auktionshaus und Lehrer.")
      elseif report.zone then
        local fitText = report.fit == "ok" and "passt zu deinem Level" or (report.fit == "low" and "zu leicht für dich" or "noch zu schwer")
        zoneFit:SetText(("Stufe %d–%d · %s"):format(report.zone.min, report.zone.max, fitText))
      else
        zoneFit:SetText("Keine Zonendaten; Funde werden beim Sammeln gelernt.")
      end
      local rows = {}
      for _, r in ipairs(report.gather) do
        if #rows >= 4 then break end
        if r.hasProfession or r.demand then
          local color = r.color and ns.Data.Gathering.COLORS[r.color] or { 1, 1, 1 }
          rows[#rows + 1] = {
            item = r.item, text = UI.ItemName(r.item), color = color,
            sub = r.demand and ("gefragt ×%d"):format(r.demand.qty) or (r.required and ("ab Skill %d"):format(r.required) or ""),
            right = r.price and UI.Money(r.price) or "",
          }
        end
      end
      if report.mobs and report.mobs.cloth and #rows < 4 then
        rows[#rows + 1] = { item = report.mobs.cloth, text = UI.ItemName(report.mobs.cloth), sub = "von Humanoiden",
          right = report.mobs.clothPrice and UI.Money(report.mobs.clothPrice) or "" }
      end
      if #rows == 0 then rows[1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = "Hier nichts Passendes", sub = "Siehe 'Alles zu dieser Zone'", color = { 0.7, 0.7, 0.7 } } end
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
        routeTitle:SetText("AUF DEINER ROUTE (RestedXP)")
      else
        routeLines:Set({ { "RestedXP nicht aktiv. Mit RestedXP zeigt Goldweaver hier die nächsten Zonen deines Guides.", 0.6, 0.6, 0.6 } })
        routeTitle:SetText("AUF DEINER ROUTE")
      end
    end

    local today = ns.Ledger.Totals(1)
    local delta = ns.Ledger.SessionDelta()
    todayPairs:Set({
      { "Session", (delta >= 0 and "+" or "") .. UI.Money(delta) },
      { "Verkauft", ("%s (%d)"):format(UI.Money(today.sales), today.count) },
      { "Gold", UI.Money(GetMoney and GetMoney() or 0) },
    })
  end
  return content
end)

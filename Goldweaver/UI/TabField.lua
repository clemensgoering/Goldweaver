-- Goldweaver: tab "Unterwegs" (docs/14-UI-FUEHRUNG.md). Everything about one zone for this character: what grows
-- here and whether the skill fits, what the mobs drop, the best zones to level each gathering skill, and the zones
-- the RestedXP guide visits next. Any zone can be browsed; "Aktuelle Zone" returns to where the player is.
local ADDON, ns = ...

local UI = ns.UI
local W, LEFT = 752, 470
local RIGHT = W - LEFT - 10
local PROF = { herb = "Kräuterkunde", ore = "Bergbau", skin = "Kürschnerei", fish = "Angeln" }
local COLOR_NAME = { orange = "orange", yellow = "gelb", green = "grün", grey = "grau", red = "Skill zu niedrig" }

local viewZone -- nil = current zone

UI.RegisterTab("field", "Unterwegs", function(frame)
  local content = {}

  local header = UI.Inset(frame, W, 56)
  header:SetPoint("TOPLEFT", 0, 0)
  local title = UI.Text(header, "", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -10)
  local sub = UI.Text(header, "", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetWidth(W - 300)
  local back = UI.Button(header, "Aktuelle Zone", 120, function() viewZone = nil; content:Refresh() end)
  back:SetPoint("TOPRIGHT", -12, -16)
  local mapButton = UI.Button(header, "Weltkarte", 100, nil)
  mapButton:SetPoint("RIGHT", back, "LEFT", -6, 0)

  local left = UI.Inset(frame, LEFT, 10)
  left:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local leftTitle = UI.Section(left, "HIER SAMMELN", LEFT - 20)
  leftTitle:SetPoint("TOPLEFT", 10, -8)
  local gatherRows = UI.IconRows(left, 10, LEFT - 20, -28, 40)

  local mobs = UI.Inset(frame, RIGHT, 130)
  mobs:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  local mobsTitle = UI.Section(mobs, "GEGNER HIER", RIGHT - 20)
  mobsTitle:SetPoint("TOPLEFT", 10, -8)
  local mobRows = UI.IconRows(mobs, 2, RIGHT - 20, -28, 40)
  local skinLine = UI.Text(mobs, "", "GameFontDisableSmall")
  skinLine:SetPoint("BOTTOMLEFT", 10, 8); skinLine:SetWidth(RIGHT - 20)

  local best = UI.Inset(frame, RIGHT, 140)
  best:SetPoint("TOPLEFT", mobs, "BOTTOMLEFT", 0, -8)
  local bestTitle = UI.Section(best, "BESTE ZONEN FÜR DEINE SKILLS", RIGHT - 20)
  bestTitle:SetPoint("TOPLEFT", 10, -8)
  local bestRows = UI.IconRows(best, 3, RIGHT - 20, -28, 34)

  local route = UI.Inset(frame, RIGHT, 10)
  route:SetPoint("TOPLEFT", best, "BOTTOMLEFT", 0, -8)
  route:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local routeTitle = UI.Section(route, "DEINE RESTEDXP-ROUTE", RIGHT - 20)
  routeTitle:SetPoint("TOPLEFT", 10, -8)
  local routeRows = UI.IconRows(route, 4, RIGHT - 20, -28, 30)

  local function browse(id) viewZone = id; content:Refresh() end

  function content:Refresh()
    local report = ns.Field.Analyze(viewZone)
    title:SetText(report.name)
    back:SetShown(viewZone ~= nil)
    if report.zone and report.zone.city then
      sub:SetText("Stadt · Hier lohnt: Post abholen, Auktionshaus, Lehrer besuchen.")
    elseif report.zone then
      local fit = report.fit == "ok" and "|cff80ff80passt zu Level " or (report.fit == "low" and "|cffaaaaaazu leicht für Level " or "|cffff8060zu schwer für Level ")
      sub:SetText(("Stufe %d–%d · %s%d|r · Classic-Daten, ergänzt um deine eigenen Funde"):format(report.zone.min, report.zone.max, fit, report.level))
    else
      sub:SetText("Keine Zonendaten hinterlegt. Was du hier sammelst, merkt sich Goldweaver.")
    end
    mapButton:SetScript("OnClick", function()
      if OpenWorldMap and report.id then pcall(OpenWorldMap, report.id) elseif ToggleWorldMap then ToggleWorldMap() end
    end)

    local rows = {}
    for _, r in ipairs(report.gather) do
      local color = r.color and ns.Data.Gathering.COLORS[r.color] or { 0.8, 0.8, 0.8 }
      local profName = PROF[r.kind] or ""
      local subText
      if r.hasProfession then
        subText = ("%s %d · %s"):format(profName, r.required or 0, COLOR_NAME[r.color] or "?")
      else
        subText = ("braucht %s %d"):format(profName, r.required or 0)
      end
      if r.observed then subText = subText .. (" · selbst gesammelt ×%d"):format(r.observed) end
      local right = r.price and UI.Money(r.price) or "kein Preis"
      if r.demand then
        local first = next(r.demand.by)
        local who = first and first:match("^(%S+)")
        right = ("|cffffd100gefragt ×%d|r (%s)"):format(r.demand.qty, who or "Team")
      end
      rows[#rows + 1] = { item = r.item, text = UI.ItemName(r.item), color = r.hasProfession and color or { 0.85, 0.85, 0.85 }, sub = subText, right = right }
      if #rows >= 10 then break end
    end
    if #rows == 0 then rows[1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = "Keine Kräuter oder Erze bekannt", sub = "Sammle etwas: die Zone wird gelernt.", color = { 0.7, 0.7, 0.7 } } end
    gatherRows:Set(rows)
    leftTitle:SetText(report.hidden > 0 and ("HIER SAMMELN (%d) · %d ohne passenden Beruf ausgeblendet"):format(#report.gather, report.hidden) or ("HIER SAMMELN (%d)"):format(#report.gather))

    local m = report.mobs
    if m then
      local mrows = {}
      if m.cloth then
        mrows[#mrows + 1] = { item = m.cloth, text = UI.ItemName(m.cloth), sub = "Humanoide · für Schneiderei/Erste Hilfe",
          right = m.clothDemand and ("|cffffd100gefragt ×%d|r"):format(m.clothDemand.qty) or (m.clothPrice and UI.Money(m.clothPrice) or "") }
      end
      if m.leather then
        mrows[#mrows + 1] = { item = m.leather, text = UI.ItemName(m.leather), sub = "Wildtiere häuten",
          right = m.leatherPrice and UI.Money(m.leatherPrice) or "" }
      end
      mobRows:Set(mrows)
      if m.skinMax then
        local okAll = m.skinMax >= m.max
        skinLine:SetText(("Kürschnerei: du häutest bis Level %d%s"):format(m.skinMax, okAll and " · alles hier möglich" or (" · für Level %d brauchst du %d"):format(m.max, m.skinRequiredTop)))
      else
        skinLine:SetText("")
      end
    else
      mobRows:Set({ { icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", text = "Keine Gegnerdaten", color = { 0.7, 0.7, 0.7 } } })
      skinLine:SetText("")
    end

    local brows = {}
    for kind, b in pairs(report.best or {}) do
      local zd = ns.Data.Zones.list[b.id]
      brows[#brows + 1] = {
        icon = kind == "herb" and "Interface\\Icons\\INV_Misc_Herb_07" or (kind == "ore" and "Interface\\Icons\\INV_Ore_Copper_01" or "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"),
        text = b.name, sub = ("%s%s"):format(PROF[kind] or kind, zd and (" · Stufe %d–%d"):format(zd.min, zd.max) or ""),
        button = { "Ansehen", function() browse(b.id) end },
      }
    end
    if #brows == 0 then brows[1] = { icon = "Interface\\Icons\\INV_Misc_Book_09", text = "Kein Sammelberuf auf diesem Charakter", color = { 0.7, 0.7, 0.7 } } end
    bestRows:Set(brows)

    local rrows = {}
    if report.route then
      routeTitle:SetText(("RESTEDXP: %s"):format(tostring(report.route.guide)))
      for i = 1, math.min(4, #report.route.zones) do
        local z = report.route.zones[i]
        local zd = ns.Data.Zones.list[z.id]
        rrows[#rrows + 1] = { icon = "Interface\\Icons\\INV_Misc_Map_01", text = z.name,
          sub = zd and ("Stufe %d–%d · ab Schritt %d"):format(zd.min, zd.max, z.step) or ("ab Schritt %d"):format(z.step),
          button = { "Ansehen", function() browse(z.id) end } }
      end
    end
    if #rrows == 0 then
      routeTitle:SetText("DEINE RESTEDXP-ROUTE")
      rrows[1] = { icon = "Interface\\Icons\\INV_Misc_QuestionMark", text = "RestedXP nicht aktiv", sub = "Mit RestedXP siehst du hier die nächsten Zonen.", color = { 0.7, 0.7, 0.7 } }
    end
    routeRows:Set(rrows)
  end
  return content
end)

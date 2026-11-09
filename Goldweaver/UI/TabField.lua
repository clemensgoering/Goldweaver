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
  -- Grouped grid (user decision 09.11.2026): one block per own profession, items as compact cells with a skill
  -- colour bar, a demand badge and the price; details (required skill, own finds) are in the item tooltip.
  local CELL_W, CELL_H, PER_ROW, MAX_GROUPS, MAX_CELLS = 70, 74, 6, 5, 12
  local groups = {}
  for g = 1, MAX_GROUPS do
    local block = CreateFrame("Frame", nil, left)
    block:SetSize(LEFT - 20, 20)
    block.title = UI.Text(block, "", "GameFontNormalSmall")
    block.title:SetPoint("TOPLEFT", 0, 0)
    block.meta = UI.Text(block, "", "GameFontDisableSmall")
    block.meta:SetPoint("TOPRIGHT", 0, 0); block.meta:SetJustifyH("RIGHT")
    block.empty = UI.Text(block, "", "GameFontDisableSmall")
    block.empty:SetPoint("TOPLEFT", 0, -18); block.empty:SetWidth(LEFT - 20)
    block.cells = {}
    for c = 1, MAX_CELLS do
      local cell = CreateFrame("Frame", nil, block)
      cell:SetSize(CELL_W, CELL_H)
      cell:SetPoint("TOPLEFT", ((c - 1) % PER_ROW) * CELL_W, -18 - math.floor((c - 1) / PER_ROW) * CELL_H)
      cell.button = UI.ItemButton(cell, 40)
      cell.button:SetPoint("TOP", 0, -4)
      cell.badge = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      cell.badge:SetPoint("TOPRIGHT", cell.button, "TOPRIGHT", 6, 6)
      cell.badge:SetTextColor(1, 0.82, 0)
      cell.bar = cell:CreateTexture(nil, "ARTWORK")
      cell.bar:SetSize(40, 3)
      cell.bar:SetPoint("TOP", cell.button, "BOTTOM", 0, -2)
      cell.label = UI.Text(cell, "", "GameFontHighlightSmall")
      cell.label:SetPoint("TOP", cell.bar, "BOTTOM", 0, -2)
      cell.label:SetWidth(CELL_W - 4); cell.label:SetJustifyH("CENTER"); cell.label:SetWordWrap(false)
      cell.price = UI.Text(cell, "", "GameFontDisableSmall")
      cell.price:SetPoint("TOP", cell.label, "BOTTOM", 0, -1)
      cell.price:SetWidth(CELL_W - 4); cell.price:SetJustifyH("CENTER")
      cell:Hide()
      block.cells[c] = cell
    end
    block:Hide()
    groups[g] = block
  end
  local hiddenNote = UI.Text(left, "", "GameFontDisableSmall")
  hiddenNote:SetPoint("BOTTOMLEFT", 10, 8); hiddenNote:SetWidth(LEFT - 20)

  -- data = { { title, meta, empty, cells = { { item, badge, color = {r,g,b}|nil, price } } } }
  local function setGroups(data)
    local y = -28
    for g, block in ipairs(groups) do
      local d = data[g]
      if d then
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT", left, "TOPLEFT", 10, y)
        block.title:SetText(d.title)
        block.meta:SetText(d.meta or "")
        block.empty:SetText(#d.cells == 0 and (d.empty or "") or "")
        for c, cell in ipairs(block.cells) do
          local cd = d.cells[c]
          if cd then
            cell.button:SetContent(nil, cd.item)
            cell.badge:SetText(cd.badge or "")
            if cd.color then cell.bar:SetColorTexture(cd.color[1], cd.color[2], cd.color[3], 1); cell.bar:Show() else cell.bar:Hide() end
            cell.label:SetText(UI.ItemName(cd.item))
            cell.price:SetText(cd.price or "")
            cell:Show()
          else
            cell:Hide()
          end
        end
        local rowsUsed = math.max(1, math.ceil(math.min(#d.cells, MAX_CELLS) / PER_ROW))
        local height = 18 + (#d.cells == 0 and 18 or rowsUsed * CELL_H) + 8
        block:SetHeight(height)
        block:Show()
        y = y - height
      else
        block:Hide()
      end
    end
  end

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

    -- one group per own gathering profession, then drops everyone can loot
    local G = ns.Data.Gathering
    local me = ns.Chars.Current()
    local function skill(line) local p = me and me.professions and me.professions[line] return p and not p.former and p.rank or nil end
    local function cellFor(r)
      return { item = r.item, badge = r.demand and ("×%d"):format(r.demand.qty) or nil,
        color = r.color and G.COLORS[r.color] or nil, price = r.price and UI.Money(r.price) or nil }
    end
    local data = {}
    for _, def in ipairs({ { "herb", G.HERBALISM }, { "ore", G.MINING }, { "fish", G.FISHING } }) do
      local rank = skill(def[2])
      if rank then
        local cells = {}
        for _, r in ipairs(report.gather) do if r.kind == def[1] then cells[#cells + 1] = cellFor(r) end end
        data[#data + 1] = { title = ("%s %d"):format(PROF[def[1]], rank), cells = cells,
          empty = def[1] == "fish" and "Noch keine eigenen Fänge hier. Wird gelernt, sobald du hier angelst." or "Hier wächst nichts für diesen Beruf." }
      end
    end
    local m = report.mobs
    local skin = skill(G.SKINNING)
    if skin and m then
      data[#data + 1] = { title = ("%s %d"):format(PROF.skin, skin),
        meta = ("Wildtiere Stufe %d–%d · %s"):format(m.min, m.max, COLOR_NAME[m.skinColor] or "?"),
        cells = m.leather and { { item = m.leather, color = m.skinColor and G.COLORS[m.skinColor],
          price = m.leatherPrice and UI.Money(m.leatherPrice) } } or {} }
    end
    if m and m.cloth then
      data[#data + 1] = { title = "Von Gegnern (alle)", meta = ("Humanoide Stufe %d–%d"):format(m.min, m.max),
        cells = { { item = m.cloth, badge = m.clothDemand and ("×%d"):format(m.clothDemand.qty) or nil, price = m.clothPrice and UI.Money(m.clothPrice) } } }
    end
    if #data == 0 then data[1] = { title = "Hier für dich", cells = {}, empty = "Kein Sammelberuf und keine Gegnerdaten für diese Zone." } end
    setGroups(data)
    leftTitle:SetText("HIER FÜR DICH")
    hiddenNote:SetText(report.hidden > 0 and ("%d ohne passenden Beruf ausgeblendet · gelbe Zahl = vom Verarbeiter gebraucht · Balken = Skill-Farbe"):format(report.hidden)
      or "Gelbe Zahl = vom Verarbeiter gebraucht · Balken = Skill-Farbe · Details im Tooltip")

    -- "Nächste Stufe": how long this zone still levels each own gathering skill, and where to go after
    -- (items themselves are in the grid on the left; no duplicates here)
    mobsTitle:SetText("NÄCHSTE STUFE")
    local nrows = {}
    if skin and m then
      local orangeUntil = G.SkinningRequired(m.max) + 25
      nrows[#nrows + 1] = { icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", text = ("Kürschnerei: bis Skill %d hier orange"):format(orangeUntil),
        sub = skin >= orangeUntil and ((report.best and report.best.skin) and ("weiter: " .. report.best.skin.name) or "nächste, höhere Zone suchen")
          or ("du häutest bis Level %d"):format(m.skinMax or 0) }
    end
    for _, def in ipairs({ { "herb", G.HERBALISM }, { "ore", G.MINING } }) do
      local rank = skill(def[2])
      local bestZone = report.best and report.best[def[1]]
      if rank and bestZone then
        nrows[#nrows + 1] = { icon = def[1] == "herb" and "Interface\\Icons\\INV_Misc_Herb_07" or "Interface\\Icons\\INV_Ore_Copper_01",
          text = ("%s %d: am meisten orange/gelb in"):format(PROF[def[1]], rank), sub = bestZone.name }
      end
    end
    if #nrows == 0 then nrows[1] = { icon = "Interface\\Icons\\INV_Misc_Book_09", text = "Kein Sammelberuf", sub = "Stoff droppt trotzdem von Humanoiden.", color = { 0.7, 0.7, 0.7 } } end
    mobRows:Set(nrows)
    skinLine:SetText("")

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

-- Goldweaver: the four tabs of the /gw window (docs/08-UX.md 4.7, docs/09-LEITFADEN.md).
-- Heute = recommendations · Berufe = per-profession guide with icons · Charaktere = roles · Einstellungen.
local ADDON, ns = ...

local UI = ns.UI
local Chars = ns.Chars

local W = 684 -- usable width inside the body (window 720 minus paddings)

local function money(copper) return ns.Util.Money(copper or 0) end

local function professionSummary(rec)
  local profs = {}
  for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank or 0) end
  table.sort(profs)
  return #profs > 0 and table.concat(profs, ", ") or "keine Berufe erfasst"
end

local function ago(t)
  if not t then return "nie" end
  local d = time() - t
  if d < 90 then return "gerade eben" end
  if d < 3600 then return ("vor %d min"):format(math.floor(d / 60)) end
  if d < 86400 then return ("vor %d h"):format(math.floor(d / 3600)) end
  return ("vor %d Tagen"):format(math.floor(d / 86400))
end

-- Heute --------------------------------------------------------------------------------------
UI.RegisterTab("heute", "Heute", function(frame)
  local content = {}

  local steps = UI.Group(frame, "NÄCHSTE SCHRITTE", W, 130)
  steps:SetPoint("TOPLEFT", 0, 0)
  local stepRows = UI.IconRows(steps, 3, W - 20, -28, 32)

  local me = UI.Group(frame, "DIESER CHARAKTER", 300, 128)
  me:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -10)
  local mePairs = UI.Pairs(me, 4, 70, 210)

  local team = UI.Group(frame, "TEAM AUF DIESEM MARKT", W - 310, 128)
  team:SetPoint("TOPLEFT", me, "TOPRIGHT", 10, 0)
  local teamTable = UI.Table(team, { { "Charakter", 0, 150 }, { "Rolle", 154, 90 }, { "Berufe", 248, 100 } }, 4)

  local sales = UI.Group(frame, "VERKÄUFE UND GOLD", W, 110)
  sales:SetPoint("TOPLEFT", me, "BOTTOMLEFT", 0, -10)
  local salesPairs = UI.Pairs(sales, 3, 130, W - 170)

  local tip = UI.Text(frame, "", "GameFontDisableSmall")
  tip:SetPoint("BOTTOMLEFT", 0, 0)
  tip:SetWidth(W)

  function content:Refresh()
    local rec = Chars.Current()
    local market = Chars.MarketKey()
    local recs = ns.Dashboard.Recommendations(3)
    local rows = {}
    for i, r in ipairs(recs) do
      rows[#rows + 1] = {
        text = i .. ". " .. r.text, color = r.color,
        right = r.value and ((r.value >= 0 and "≈ " or "Kosten ") .. money(math.abs(r.value))) or "",
        rightColor = r.value and (r.value >= 0 and { 0.6, 1, 0.6 } or { 1, 0.7, 0.5 }) or nil,
        onClick = r.action, tooltip = r.action and "Klick öffnet den passenden Bereich" or nil,
      }
    end
    if #rows == 0 then rows[1] = { text = "Alles erledigt. Sammeln, Berufefenster öffnen oder AH besuchen, dann gibt es neue Empfehlungen.", color = { 0.7, 0.7, 0.7 } } end
    stepRows:Set(rows)

    mePairs:Set({
      { "Name", Chars.FullName() },
      { "Rolle", rec and Chars.ROLE_LABELS[rec.role or "none"] or "unbekannt" },
      { "Markt", market },
      { "Gold", money(GetMoney and GetMoney() or 0) },
    })

    local trows = {}
    for _, c in ipairs(Chars.All(market)) do
      local n = 0
      for _ in pairs(c.professions or {}) do n = n + 1 end
      trows[#trows + 1] = { c.name, (Chars.ROLE_LABELS[c.role or "none"]:gsub(" %(.*%)", "")), tostring(n) }
    end
    if #trows == 0 then trows[1] = { "noch niemand", "", "" } end
    teamTable:Set(trows)

    local today, week = ns.Ledger.Totals(1), ns.Ledger.Totals(7)
    local delta = ns.Ledger.SessionDelta()
    salesPairs:Set({
      { "Diese Session", (delta >= 0 and "+" or "") .. money(delta) },
      { "Verkauft heute", ("%s (%d Auktionen, Einzahlung zurück %s)"):format(money(today.sales), today.count, money(today.deposits)) },
      { "Letzte 7 Tage", ("%s (%d Auktionen, AH-Cut %s)"):format(money(week.sales), week.count, money(week.cut)) },
    })
    tip:SetText("Verkäufe werden beim Abholen der Post erfasst. Zahlen tragen Quelle und Alter; ~ markiert unbestätigte Daten. /gw help listet alle Befehle.")
  end
  return content
end)

-- Berufe (Leitfaden) --------------------------------------------------------------------------
local selectedSkillLine

UI.RegisterTab("berufe", "Berufe", function(frame)
  local content = {}

  -- selector row
  local selector = CreateFrame("Frame", nil, frame)
  selector:SetSize(W, 24)
  selector:SetPoint("TOPLEFT", 0, 0)
  local selButtons = {}

  local status = UI.Group(frame, "STATUS", W, 92)
  status:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -6)
  local statusLines = UI.Lines(status, 3, W - 20, "GameFontHighlight")

  local nextStep = UI.Group(frame, "NÄCHSTER SKILL-UP", W, 176)
  nextStep:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
  local stepRow = UI.IconRows(nextStep, 1, W - 20, -28, 32)
  local reagentRows = UI.IconRows(nextStep, 3, W - 20 - 170, -64, 26)
  local craftButton = UI.Button(nextStep, "Herstellen", 160, nil)
  craftButton:SetPoint("TOPRIGHT", -10, -66)
  local searchButton = UI.Button(nextStep, "Fehlendes im AH suchen", 160, nil)
  searchButton:SetPoint("TOPRIGHT", -10, -92)
  local altLine = UI.Text(nextStep, "", "GameFontDisableSmall")
  altLine:SetPoint("BOTTOMLEFT", 10, 8); altLine:SetWidth(W - 20)

  local profit = UI.Group(frame, "LOHNT SICH (nach AH-Cut)", (W - 10) / 2, 150)
  profit:SetPoint("TOPLEFT", nextStep, "BOTTOMLEFT", 0, -8)
  local profitRows = UI.IconRows(profit, 4, (W - 10) / 2 - 20, -28, 28)

  local unlearned = UI.Group(frame, "NOCH NICHT GELERNT", (W - 10) / 2, 150)
  unlearned:SetPoint("TOPLEFT", profit, "TOPRIGHT", 10, 0)
  local unlearnedRows = UI.IconRows(unlearned, 4, (W - 10) / 2 - 20, -28, 28)

  -- comparison view (shown instead of the guide when "Vergleich" is selected)
  local compare = UI.Group(frame, "WELCHER BERUF LOHNT SICH ALS NÄCHSTES", W, 300)
  compare:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -6)
  local compareTable = UI.Table(compare, {
    { "Beruf", 0, 160 }, { "Kategorie", 164, 100 }, { "Kosten bis 300 (Startpfad)", 268, 170 },
    { "davon schon im Besitz", 442, 140 }, { "Status", 586, 80 },
  }, 12)
  local compareNote = UI.Text(compare, "Startpfade stammen aus Beta-Guides und werden durch Live-Rezepte ersetzt, sobald ein Charakter den Beruf öffnet. Kosten zu aktuellen Preisen; ohne Preis gilt 0.", "GameFontDisableSmall")
  compareNote:SetPoint("BOTTOMLEFT", 10, 8); compareNote:SetWidth(W - 20)
  compare:Hide()

  local guideFrames = { status, nextStep, profit, unlearned }
  local showCompare = false

  local function setGuideShown(shown)
    for _, f in ipairs(guideFrames) do if shown then f:Show() else f:Hide() end end
    if shown then compare:Hide() else compare:Show() end
  end

  local function professionsOfMe()
    local me = Chars.Current()
    local list = {}
    for skillLine, p in pairs(me and me.professions or {}) do list[#list + 1] = { skillLine = skillLine, name = p.name or tostring(skillLine) } end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
  end

  local function rebuildSelector()
    for _, b in ipairs(selButtons) do b:Hide() end
    local x = 0
    local list = professionsOfMe()
    for i, entry in ipairs(list) do
      local b = selButtons[i]
      if not b then
        b = UI.Button(selector, "", 120, nil)
        selButtons[i] = b
      end
      b:SetText(entry.name)
      b:SetWidth(math.max(90, b:GetFontString():GetStringWidth() + 24))
      b:ClearAllPoints(); b:SetPoint("LEFT", x, 0)
      b:SetScript("OnClick", function() selectedSkillLine = entry.skillLine; showCompare = false; content:Refresh() end)
      if not showCompare and selectedSkillLine == entry.skillLine then b:Disable() else b:Enable() end
      b:Show()
      x = x + b:GetWidth() + 4
    end
    local cmp = selButtons.compare
    if not cmp then
      cmp = UI.Button(selector, "Vergleich", 100, nil)
      selButtons.compare = cmp
    end
    cmp:ClearAllPoints(); cmp:SetPoint("RIGHT", 0, 0)
    cmp:SetScript("OnClick", function() showCompare = true; content:Refresh() end)
    if showCompare then cmp:Disable() else cmp:Enable() end
    cmp:Show()
    return list
  end

  local currentPlan

  local function refreshGuide(skillLine)
    local me = Chars.Current()
    local p = me and me.professions and me.professions[skillLine]
    local book = ns.Adapter.Book(skillLine)
    local profile = ns.Professions:BySkillLine(skillLine)
    local rank = ns.Planner.NextRank(skillLine, me)
    local lines = {}
    if p then
      local rankText = rank and rank.current and rank.current.name or "?"
      local nextText = ""
      if rank and rank.next then
        local hint = ""
        if rank.canTrain then hint = " (jetzt lernbar!)"
        elseif rank.needSkill > 0 then hint = ", noch " .. rank.needSkill .. " Punkte"
        elseif rank.needLevel > 0 then hint = ", noch " .. rank.needLevel .. " Level" end
        nextText = (" → %s ab Skill %d und Level %d%s"):format(rank.next.name, rank.next.reqSkill, rank.next.reqLevel, hint)
      end
      lines[1] = { ("%s %d / %d · %s%s"):format(p.name or "?", p.rank or 0, p.maxRank or 0, rankText, nextText), 1, 1, 1 }
      local trainer = rank and rank.next and rank.trainer
      if rank and rank.canTrain and trainer then lines[2] = { "Lernen bei: " .. trainer, 0.6, 1, 0.6 }
      elseif trainer then lines[2] = { "Nächster Rang bei: " .. trainer, 0.8, 0.8, 0.8 }
      elseif rank and rank.capped then lines[2] = { "Maximum dieses Rangs erreicht.", 1, 0.9, 0.5 }
      else lines[2] = { "", 1, 1, 1 } end
      if book then
        lines[3] = { ("Rezepte: %d von %d gelernt · Fenster zuletzt gelesen %s"):format(p.learnedCount or 0, p.recipeCount or #book.list, ago(p.when)), 0.7, 0.7, 0.7 }
      else
        lines[3] = { "Berufefenster einmal öffnen: dann liest Goldweaver Rezepte, Farben und Materialien.", 1, 0.6, 0.2 }
      end
    else
      lines[1] = { "Dieser Charakter hat diesen Beruf nicht.", 0.7, 0.7, 0.7 }
    end
    statusLines:Set(lines)

    currentPlan = book and ns.Planner.Plan(skillLine, me) or nil
    local best = currentPlan and currentPlan.best
    if best then
      local r = best.recipe
      local chance = math.floor(best.chance * 100 + 0.5)
      stepRow:Set({ {
        icon = r.icon or r.outputItemID, text = ("%s ×%d"):format(r.name, currentPlan.crafts or 1),
        right = ("≈ %s je Punkt"):format(money(best.costPerPoint)), rightColor = { 1, 0.9, 0.6 },
        sub = ("Skill-up-Chance %d %% · Materialkosten %s je Stück · Produkt %s"):format(chance, money(best.cost), best.productValue > 0 and ("≈ " .. money(best.productValue)) or "ohne AH-Preis"),
        itemID = r.outputItemID, tooltip = not r.outputItemID and r.name or nil,
      } })
      local rrows = {}
      for i, s in ipairs(currentPlan.shopping or {}) do
        if i > 3 then break end
        local have = s.have
        rrows[#rrows + 1] = {
          icon = s.item, text = UI.ItemName(s.item), itemID = s.item,
          right = s.buy > 0 and (("fehlen %d%s"):format(s.buy, s.cost and (" · " .. money(s.cost)) or "")) or "vorhanden",
          rightColor = s.buy > 0 and { 1, 0.6, 0.4 } or { 0.6, 1, 0.6 },
          sub = ("brauche %d · habe %d (Taschen %d, Bank %d%s)"):format(s.need, have, s.bags or 0, s.bank or 0, #(s.alts or {}) > 0 and (", Twinks " .. (have - (s.bags or 0) - (s.bank or 0))) or ""),
        }
      end
      reagentRows:Set(rrows)
      craftButton:SetText(("Herstellen ×%d"):format(currentPlan.crafts or 1))
      if ns.Adapter.IsOpen() and ns.Adapter.current == skillLine then craftButton:Enable() else craftButton:Disable() end
      craftButton:SetScript("OnClick", function()
        local ok, err = ns.Adapter.Craft(r.id, currentPlan.crafts or 1)
        if not ok then ns.Print("Herstellen: " .. tostring(err)) end
      end)
      local missingItem
      for _, s in ipairs(currentPlan.shopping or {}) do if s.buy > 0 then missingItem = s.item; break end end
      if missingItem and AuctionHouseFrame and AuctionHouseFrame:IsShown() then searchButton:Enable() else searchButton:Disable() end
      searchButton:SetScript("OnClick", function() if missingItem then ns.Auction.SearchFor(missingItem) end end)
      local alts = {}
      for i = 2, math.min(4, #currentPlan.candidates) do
        local c = currentPlan.candidates[i]
        alts[#alts + 1] = ("%s (%s/Pkt)"):format(c.recipe.name, money(c.costPerPoint))
      end
      altLine:SetText(#alts > 0 and ("Alternativen: " .. table.concat(alts, " · ")) or "")
    else
      stepRow:Set({ { text = book and "Kein gelerntes Rezept gibt noch Skill-ups. Nächstes Rezept lernen (siehe rechts unten) oder Rang trainieren." or "Noch keine Rezeptdaten.", color = { 0.8, 0.8, 0.8 } } })
      reagentRows:Set({})
      craftButton:Disable(); searchButton:Disable()
      altLine:SetText("")
    end

    local prows = {}
    for _, e in ipairs(book and ns.Planner.Profitable(skillLine, me, 4) or {}) do
      prows[#prows + 1] = {
        icon = e.recipe.icon or e.recipe.outputItemID, text = e.recipe.name, itemID = e.recipe.outputItemID,
        right = (e.margin >= 0 and "+" or "") .. money(e.margin), rightColor = e.margin >= 0 and { 0.6, 1, 0.6 } or { 1, 0.5, 0.5 },
        sub = ("Kosten %s → Erlös %s"):format(money(e.cost), money(e.value)),
      }
    end
    if #prows == 0 then prows[1] = { text = book and "Keine AH-Preise für Produkte bekannt. Im AH suchen oder Auctionator scannen lassen." or "Noch keine Rezeptdaten.", color = { 0.7, 0.7, 0.7 } } end
    profitRows:Set(prows)

    local urows = {}
    for i, r in ipairs(book and ns.Adapter.Unlearned(skillLine, me) or {}) do
      if i > 4 then break end
      local mats = {}
      for _, rg in ipairs(r.reagents or {}) do mats[#mats + 1] = ("%d× %s"):format(rg.qty, UI.ItemName(rg.item)) end
      urows[#urows + 1] = {
        icon = r.icon or r.outputItemID, text = r.name, itemID = r.outputItemID, tooltip = not r.outputItemID and r.name or nil,
        right = r.sourceType and ("Quelle " .. tostring(r.sourceType)) or "", sub = table.concat(mats, ", "),
      }
    end
    local total = book and #ns.Adapter.Unlearned(skillLine, me) or 0
    if #urows == 0 then urows[1] = { text = book and "Alle Rezepte dieses Buchs sind gelernt." or "Noch keine Rezeptdaten.", color = { 0.7, 0.7, 0.7 } }
    elseif total > 4 then urows[4].sub = ("… und %d weitere. Wo es sie gibt, zeigt der Trade-Contacts-Rekorder nach Besuch bei Lehrern und Händlern."):format(total - 4) end
    unlearnedRows:Set(urows)
    unlearned.title:SetText(("NOCH NICHT GELERNT (%d)"):format(total))
    if profile and profile.notes and profile.notes[1] then status.title:SetText("STATUS · " .. profile.notes[1]:sub(1, 90)) else status.title:SetText("STATUS") end
  end

  local function refreshCompare()
    local rows = {}
    local CATEGORY = { crafting = "Herstellung", gathering = "Sammeln", secondary = "Sekundär" }
    for _, r in ipairs(ns.Compare.Rows()) do
      rows[#rows + 1] = { r.profile.name, CATEGORY[r.profile.category] or r.profile.category, money(r.costTo300) .. (r.coverage < 1 and " ~" or ""), money(r.ownedValue), r.known and ("gelernt " .. tostring(r.known.rank)) or "–" }
    end
    compareTable:Set(rows)
  end

  function content:Refresh()
    local list = rebuildSelector()
    if not showCompare then
      local valid = false
      for _, e in ipairs(list) do if e.skillLine == selectedSkillLine then valid = true end end
      if not valid then selectedSkillLine = list[1] and list[1].skillLine or nil end
      if not selectedSkillLine then showCompare = true end
    end
    rebuildSelector()
    if showCompare then
      setGuideShown(false)
      refreshCompare()
    else
      setGuideShown(true)
      refreshGuide(selectedSkillLine)
    end
  end

  function UI.SelectProfession(skillLine)
    selectedSkillLine = skillLine
    showCompare = false
    content:Refresh()
  end
  return content
end)

-- Charaktere ---------------------------------------------------------------------------------
UI.RegisterTab("chars", "Charaktere", function(frame)
  local content = { rows = {} }

  local help = UI.Group(frame, "ROLLEN", W, 62)
  help:SetPoint("TOPLEFT", 0, 0)
  local helpLines = UI.Lines(help, 1, W - 20, "GameFontHighlightSmall")
  helpLines:Set({ { "Main sammelt unterwegs und schickt Material. Verarbeiter stellt her, entzaubert und verkauft. Bank lagert. "
    .. "Jeder Charakter wird beim ersten Login automatisch eingetragen; Berufe beim Öffnen des Berufefensters.", 0.85, 0.85, 0.85 } })

  local list = UI.Group(frame, "CHARAKTERE", W, 400)
  list:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  local colName = UI.Text(list, "Charakter", "GameFontDisableSmall"); colName:SetPoint("TOPLEFT", 10, -26)
  local colMarket = UI.Text(list, "Markt", "GameFontDisableSmall"); colMarket:SetPoint("TOPLEFT", 230, -26)
  local colProfs = UI.Text(list, "Berufe", "GameFontDisableSmall"); colProfs:SetPoint("TOPLEFT", 360, -26)

  local ROLE_ORDER = { "main", "processor", "bank", "none" }
  local ROLE_SHORT = { main = "Main", processor = "Verarbeiter", bank = "Bank", none = "–" }

  local function row(i)
    if content.rows[i] then return content.rows[i] end
    local r = CreateFrame("Frame", nil, list)
    r:SetSize(W - 20, 44)
    r:SetPoint("TOPLEFT", 10, -42 - (i - 1) * 50)
    local line = r:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.06)
    line:SetPoint("BOTTOMLEFT", 0, -3); line:SetPoint("BOTTOMRIGHT", 0, -3); line:SetHeight(1)
    r.name = UI.Text(r, "", "GameFontNormal"); r.name:SetPoint("TOPLEFT", 0, 0); r.name:SetWidth(215)
    r.market = UI.Text(r, ""); r.market:SetPoint("TOPLEFT", 220, 0); r.market:SetWidth(125)
    r.profs = UI.Text(r, "", "GameFontHighlightSmall"); r.profs:SetPoint("TOPLEFT", 350, 0); r.profs:SetWidth(W - 20 - 350); r.profs:SetWordWrap(true)
    r.buttons = {}
    local x = 0
    for _, role in ipairs(ROLE_ORDER) do
      local width = role == "processor" and 90 or 60
      local b = UI.Button(r, ROLE_SHORT[role], width, function() if r.rec then Chars.SetRole(r.rec.name, role) end end)
      b:SetPoint("TOPLEFT", x, -20)
      r.buttons[role] = b
      x = x + width + 4
    end
    content.rows[i] = r
    return r
  end

  function content:Refresh()
    local all = Chars.All()
    for i, rec in ipairs(all) do
      if i > 7 then break end
      local r = row(i)
      r.rec = rec
      r:Show()
      r.name:SetText(rec.name .. (rec.name == Chars.FullName() and " (du)" or ""))
      r.market:SetText(rec.market or "?")
      r.profs:SetText(professionSummary(rec))
      for role, b in pairs(r.buttons) do
        if (rec.role or "none") == role then b:Disable() else b:Enable() end
      end
    end
    for i = #all + 1, #content.rows do content.rows[i]:Hide() end
  end
  return content
end)

-- Einstellungen ------------------------------------------------------------------------------
UI.RegisterTab("settings", "Einstellungen", function(frame)
  local content = {}
  local s = ns.db.settings

  local display = UI.Group(frame, "ANZEIGE", W, 150)
  display:SetPoint("TOPLEFT", 0, 0)
  local checks = {}
  local defs = {
    { "Minimap-Button anzeigen", function() return not s.minimapHidden end, function(on) s.minimapHidden = not on; if ns.Minimap then ns.Minimap.SetShown(on) end end },
    { "HUD-Zeile anzeigen (automatisch: nur für Mains)", function() return ns.HUD.ShouldShow() end, function(on) if on then s.hudOn = true; s.hudOff = nil else s.hudOff = true; s.hudOn = nil end; ns.HUD.Refresh() end },
    { "Tooltip-Zeilen anzeigen", function() return not s.tooltipOff end, function(on) s.tooltipOff = not on end },
    { "AH-Preisvorschlag automatisch eintragen", function() return s.autofillPrice ~= false end, function(on) s.autofillPrice = on end },
    { "Materialien der eigenen Berufe behalten (nicht verschicken)", function() return s.keepOwnMaterials ~= false end, function(on) s.keepOwnMaterials = on end },
    { "Debug-Ausgaben im Chat", function() return s.debug end, function(on) s.debug = on end },
  }
  for i, d in ipairs(defs) do
    local c = UI.Check(display, d[1], d[2](), d[3])
    c:SetPoint("TOPLEFT", 10 + ((i - 1) % 2) * (W / 2), -26 - math.floor((i - 1) / 2) * 26)
    checks[i] = { check = c, get = d[2] }
  end

  local calc = UI.Group(frame, "RECHENGRUNDLAGEN", W, 130)
  calc:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -10)
  local calcPairs = UI.Pairs(calc, 4, 150, W - 190)

  local note = UI.Text(frame, "Höchstens zehn Einstellungen, alle mit funktionierendem Standard (docs/08-UX.md Regel 7). "
    .. "Ändern per Befehl: /gw favor <Kupfer>, /gw undercut <Kupfer>, /gw market <Key>|auto, /gw hud on|off|auto.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 0, 0)
  note:SetWidth(W)

  function content:Refresh()
    for _, c in ipairs(checks) do c.check:SetChecked(c.get() and true or false) end
    calcPairs:Set({
      { "Wert je Favor", ns.Util.Money(s.favorValueCopper or 500) .. "  (für die Kisten-Empfehlung, unbestätigte Favor-Sätze)" },
      { "AH-Cut", ("%d %%"):format(math.floor((s.ahCut or 0.05) * 100 + 0.5)) .. "  (Fraktions-AH; Goblin-AH 15 %)" },
      { "Unterbieten um", ns.Util.Money(s.undercutCopper or 1) },
      { "Markt-Key", Chars.MarketKey() .. (s.marketKey and "  (manuell)" or "  (automatisch aus Realmname)") },
    })
  end
  return content
end)

ns.Slash.Register("favor", function(arg)
  local n = tonumber(arg)
  if not n or n < 0 then return ns.Print("usage: /gw favor <Kupfer je Favor>, z. B. 500 für 5 Silber") end
  ns.db.settings.favorValueCopper = math.floor(n)
  ns.Print("ein Favor zählt jetzt " .. ns.Util.Money(n))
  UI.Refresh()
end, "gold value of one Merchant's Favor in copper")

ns.Slash.Register("undercut", function(arg)
  local n = tonumber(arg)
  if not n or n < 0 then return ns.Print("usage: /gw undercut <Kupfer>") end
  ns.db.settings.undercutCopper = math.floor(n)
  ns.Print("Unterbieten um " .. ns.Util.Money(n))
  UI.Refresh()
end, "undercut amount in copper for the AH price suggestion")

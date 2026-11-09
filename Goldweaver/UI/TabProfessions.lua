-- Goldweaver: tab "Berufe" (docs/09-LEITFADEN.md, docs/14-UI-FUEHRUNG.md). Left: the character's professions as a
-- navigation list with icon and skill bar (like the professions book); right: status, next skill-up with shopping
-- list and actions, profitable crafts, unlearned recipes. "Vergleich" shows which profession to add or switch to.
local ADDON, ns = ...

local UI = ns.UI
local Chars = ns.Chars
local W, NAV = 752, 196
local DW = W - NAV - 10 -- detail width
local HALF = (DW - 8) / 2

local selectedSkillLine, showCompare

local function money(c) return UI.Money(c) end

local function ago(t)
  if not t then return "nie" end
  local d = time() - t
  if d < 90 then return "gerade eben" end
  if d < 3600 then return ("vor %d min"):format(math.floor(d / 60)) end
  if d < 86400 then return ("vor %d h"):format(math.floor(d / 3600)) end
  return ("vor %d Tagen"):format(math.floor(d / 86400))
end

UI.RegisterTab("berufe", "Berufe", function(frame)
  local content = {}

  -- navigation -------------------------------------------------------------------------------------
  local nav = UI.Inset(frame, NAV, 10)
  nav:SetPoint("TOPLEFT", 0, 0)
  nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local navTitle = UI.Section(nav, "DEINE BERUFE", NAV - 20)
  navTitle:SetPoint("TOPLEFT", 10, -8)
  local navButtons = {}

  local function navButton(i)
    if navButtons[i] then return navButtons[i] end
    local b = CreateFrame("Button", nil, nav)
    b:SetSize(NAV - 16, 46)
    b:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 50)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(); b.sel:SetColorTexture(1, 0.82, 0, 0.12); b.sel:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.06)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(30, 30); b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.name = UI.Text(b, "", "GameFontNormal")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 2)
    b.bar = UI.SkillBar(b, NAV - 60, 12)
    b.bar:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, 0)
    navButtons[i] = b
    return b
  end

  local compareButton = UI.Button(nav, "Welcher Beruf lohnt sich?", NAV - 20, function() showCompare = true; content:Refresh() end)
  compareButton:SetPoint("BOTTOMLEFT", 10, 10)

  -- detail -----------------------------------------------------------------------------------------
  local status = UI.Inset(frame, DW, 92)
  status:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  local statusTitle = UI.Section(status, "STATUS", DW - 20)
  statusTitle:SetPoint("TOPLEFT", 10, -8)
  local statusLines = UI.Lines(status, 3, DW - 190, "GameFontHighlightSmall", -28)
  local loadButton = UI.Button(status, "Rezepte laden", 160, nil)
  loadButton:SetPoint("TOPRIGHT", -10, -26)

  local nextStep = UI.Inset(frame, DW, 196)
  nextStep:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
  local nextTitle = UI.Section(nextStep, "NÄCHSTER SKILL-UP", DW - 20)
  nextTitle:SetPoint("TOPLEFT", 10, -8)
  local stepRow = UI.IconRows(nextStep, 1, DW - 190, -28, 42)
  local craftButton = UI.Button(nextStep, "Herstellen", 160, nil)
  craftButton:SetPoint("TOPRIGHT", -10, -32)
  craftButton:SetHeight(26)
  local reagentRows = UI.IconRows(nextStep, 3, DW - 20, -74, 34)
  local altLine = UI.Text(nextStep, "", "GameFontDisableSmall")
  altLine:SetPoint("BOTTOMLEFT", 10, 6); altLine:SetWidth(DW - 20)

  local profit = UI.Inset(frame, HALF, 10)
  profit:SetPoint("TOPLEFT", nextStep, "BOTTOMLEFT", 0, -8)
  profit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  local profitTitle = UI.Section(profit, "LOHNT SICH", HALF - 20)
  profitTitle:SetPoint("TOPLEFT", 10, -8)
  local profitRows = UI.IconRows(profit, 4, HALF - 20, -28, 38)

  local unlearned = UI.Inset(frame, HALF, 10)
  unlearned:SetPoint("TOPLEFT", profit, "TOPRIGHT", 8, 0)
  unlearned:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  local unlearnedTitle = UI.Section(unlearned, "NOCH NICHT GELERNT", HALF - 20)
  unlearnedTitle:SetPoint("TOPLEFT", 10, -8)
  local unlearnedRows = UI.IconRows(unlearned, 4, HALF - 20, -28, 38)

  local compare = UI.Inset(frame, DW, 10)
  compare:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  compare:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local compareTitle = UI.Section(compare, "WELCHER BERUF LOHNT SICH ALS NÄCHSTES", DW - 20)
  compareTitle:SetPoint("TOPLEFT", 10, -8)
  local compareTable = UI.Table(compare, {
    { "Beruf", 0, 140 }, { "Art", 144, 90 }, { "Kosten bis 300", 238, 110 }, { "schon im Besitz", 352, 110 }, { "Status", 466, 70 },
  }, 14, -30)
  local compareNote = UI.Text(compare, "Kosten aus den Start-Lernpfaden zu aktuellen Preisen; Live-Rezepte ersetzen sie, sobald ein Charakter den Beruf liest. ~ = nicht alle Preise bekannt.", "GameFontDisableSmall")
  compareNote:SetPoint("BOTTOMLEFT", 10, 8); compareNote:SetWidth(DW - 20)

  local detailFrames = { status, nextStep, profit, unlearned }

  local function refreshNav()
    local me = Chars.Current()
    local list = {}
    for skillLine, p in pairs(me and me.professions or {}) do
      if not p.former then list[#list + 1] = { skillLine = skillLine, p = p } end
    end
    table.sort(list, function(a, b) return (a.p.name or "") < (b.p.name or "") end)
    for i, b in ipairs(navButtons) do if i > #list then b:Hide() end end
    for i, e in ipairs(list) do
      if i > 8 then break end
      local b = navButton(i)
      b.icon:SetTexture(e.p.icon or "Interface\\Icons\\INV_Misc_Book_09")
      b.name:SetText(e.p.name or "?")
      local book = ns.Adapter.Book(e.skillLine)
      if book then b.bar:SetSkill(e.p.rank, e.p.maxRank, 0.1, 0.55, 0.1) else b.bar:SetSkill(e.p.rank, e.p.maxRank, 0.5, 0.4, 0.1) end
      b.sel:SetShown(not showCompare and selectedSkillLine == e.skillLine)
      b:SetScript("OnClick", function() selectedSkillLine = e.skillLine; showCompare = false; content:Refresh() end)
      b:Show()
    end
    return list
  end

  local function refreshDetail(skillLine)
    local me = Chars.Current()
    local p = me and me.professions and me.professions[skillLine]
    local book = ns.Adapter.Book(skillLine)
    local profile = ns.Professions:BySkillLine(skillLine)
    local rank = ns.Planner.NextRank(skillLine, me)
    local lines = {}
    if p then
      local nextText = ""
      if rank and rank.next then
        local hint = ""
        if rank.canTrain then hint = " |cff80ff80· jetzt lernbar|r"
        elseif rank.needSkill > 0 then hint = (" · noch %d Punkte"):format(rank.needSkill)
        elseif rank.needLevel > 0 then hint = (" · noch %d Level"):format(rank.needLevel) end
        nextText = (" → %s ab Skill %d, Level %d%s"):format(rank.next.name, rank.next.reqSkill, rank.next.reqLevel, hint)
      end
      lines[1] = { ("%s · %s%s"):format(p.name or "?", rank and rank.current and rank.current.name or "?", nextText), 1, 1, 1 }
      local trainer = rank and rank.next and rank.trainer
      if trainer then
        local label = rank.canTrain and "Lernen bei" or "Nächster Rang bei"
        local text = ("%s: %s%s"):format(label, trainer, rank.trainerSeen and " (selbst gesehen)" or "")
        lines[2] = rank.canTrain and { text, 0.6, 1, 0.6 } or { text, 0.8, 0.8, 0.8 }
      else lines[2] = { profile and profile.notes and profile.notes[1] or "", 0.7, 0.7, 0.7 } end
      lines[3] = book and { ("Rezepte: %d von %d gelernt · gelesen %s"):format(p.learnedCount or 0, p.recipeCount or #book.list, ago(p.when)), 0.6, 0.6, 0.6 }
        or { "Noch nicht eingelesen: 'Rezepte laden' (geschieht sonst automatisch beim nächsten Login).", 1, 0.6, 0.2 }
    end
    statusLines:Set(lines)
    statusTitle:SetText(("STATUS · %s %d / %d"):format((p and p.name or ""):upper(), p and p.rank or 0, p and p.maxRank or 0))
    loadButton:SetText(book and "Rezepte aktualisieren" or "Rezepte laden")
    loadButton:SetEnabled(ns.Features.Available("openProfession") and p ~= nil)
    loadButton:SetScript("OnClick", function()
      local ok, err = ns.Adapter.Open(skillLine)
      if not ok then ns.Print("Beruf öffnen: " .. tostring(err)) end
    end)

    local plan = book and ns.Planner.Plan(skillLine, me) or nil
    local best = plan and plan.best
    if best then
      local r = best.recipe
      local greyText = best.pointsLeft and (" · grau in %d Punkten"):format(best.pointsLeft) or ""
      stepRow:Set({ {
        icon = r.icon, item = r.outputItemID, text = ("%s ×%d"):format(r.name, plan.crafts or 1),
        right = ("≈ %s je Punkt"):format(money(best.costPerPoint)), rightColor = { 1, 0.82, 0 },
        sub = ("Skill-up %d %%%s · Material %s je Stück · Produkt %s"):format(math.floor(best.chance * 100 + 0.5), greyText, money(best.cost), best.productValue > 0 and ("≈ " .. money(best.productValue)) or "ohne Preis"),
        tooltip = not r.outputItemID and r.name or nil,
      } })
      local rrows = {}
      for i, s in ipairs(plan.shopping or {}) do
        if i > 3 then break end
        local alts = s.have - (s.bags or 0) - (s.bank or 0)
        rrows[#rrows + 1] = {
          item = s.item, text = UI.ItemName(s.item), count = s.need,
          sub = ("brauche %d · Taschen %d · Bank %d%s"):format(s.need, s.bags or 0, s.bank or 0, alts > 0 and (" · Twinks " .. alts) or ""),
          right = s.buy > 0 and (("fehlen %d%s"):format(s.buy, s.cost and (" · " .. money(s.cost)) or "")) or "|cff80ff80vorhanden|r",
          rightColor = s.buy > 0 and { 1, 0.6, 0.4 } or nil,
          button = s.buy > 0 and { "Im AH suchen", function()
            if not ns.Auction.SearchFor(s.item) then ns.Print("Auktionshaus öffnen, dann erneut klicken.") end
          end } or nil,
        }
      end
      reagentRows:Set(rrows)
      craftButton:SetText(("Herstellen ×%d"):format(plan.crafts or 1))
      local open = ns.Adapter.IsOpen() and ns.Adapter.current == skillLine
      craftButton:SetScript("OnClick", function()
        if not (ns.Adapter.IsOpen() and ns.Adapter.current == skillLine) then ns.Adapter.Open(skillLine); return end
        local ok, err = ns.Adapter.Craft(r.id, plan.crafts or 1)
        if not ok then ns.Print("Herstellen: " .. tostring(err)) end
        if ns.Checks then ns.Checks.Pass("craft", "über den Leitfaden") end
      end)
      if not open then craftButton:SetText("Beruf öffnen") end
      craftButton:Enable()
      local alts = {}
      for i = 2, math.min(4, #plan.candidates) do
        local c = plan.candidates[i]
        alts[#alts + 1] = ("%s (%s/Pkt)"):format(c.recipe.name, money(c.costPerPoint))
      end
      altLine:SetText(#alts > 0 and ("Alternativen: " .. table.concat(alts, " · ")) or "")
    else
      stepRow:Set({ { icon = "Interface\\Icons\\INV_Misc_Book_09", text = book and "Kein gelerntes Rezept gibt noch Punkte" or "Noch keine Rezeptdaten",
        sub = book and "Neues Rezept lernen (rechts) oder nächsten Rang trainieren." or "Wird beim nächsten Login automatisch eingelesen.", color = { 0.8, 0.8, 0.8 } } })
      reagentRows:Set({})
      craftButton:Disable()
      altLine:SetText("")
    end

    local prows = {}
    for _, e in ipairs(book and ns.Planner.Profitable(skillLine, me, 4) or {}) do
      prows[#prows + 1] = {
        icon = e.recipe.icon, item = e.recipe.outputItemID, text = e.recipe.name,
        right = (e.margin >= 0 and "+" or "") .. money(e.margin), rightColor = e.margin >= 0 and { 0.4, 1, 0.4 } or { 1, 0.5, 0.5 },
        sub = ("%s → %s"):format(money(e.cost), money(e.value)),
      }
    end
    if #prows == 0 then prows[1] = { icon = "Interface\\Icons\\INV_Misc_Coin_02", text = "Keine Produktpreise bekannt", sub = "Im AH suchen oder Auctionator scannen.", color = { 0.7, 0.7, 0.7 } } end
    profitRows:Set(prows)

    local urows = {}
    local unl = book and ns.Adapter.Unlearned(skillLine, me) or {}
    for i, r in ipairs(unl) do
      if i > 4 then break end
      local source = ns.Learn and ns.Learn.RecipeSource(r) or nil
      urows[#urows + 1] = {
        icon = r.icon, item = r.outputItemID, text = r.name, tooltip = not r.outputItemID and r.name or nil,
        sub = source or "Quelle noch unbekannt (Lehrer/Händler besuchen)", color = source and { 0.8, 1, 0.8 } or nil,
      }
    end
    if #urows == 0 then urows[1] = { icon = "Interface\\Icons\\Achievement_General", text = book and "Alles gelernt" or "Noch keine Rezeptdaten", color = { 0.7, 0.7, 0.7 } } end
    unlearnedRows:Set(urows)
    unlearnedTitle:SetText(("NOCH NICHT GELERNT (%d)"):format(#unl))
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
    local list = refreshNav()
    if not showCompare then
      local valid = false
      for _, e in ipairs(list) do if e.skillLine == selectedSkillLine then valid = true end end
      if not valid then selectedSkillLine = list[1] and list[1].skillLine or nil end
      if not selectedSkillLine then showCompare = true end
      refreshNav()
    end
    for _, f in ipairs(detailFrames) do f:SetShown(not showCompare) end
    compare:SetShown(showCompare and true or false)
    if showCompare then refreshCompare() else refreshDetail(selectedSkillLine) end
  end

  function UI.SelectProfession(skillLine)
    selectedSkillLine = skillLine
    showCompare = false
    content:Refresh()
  end
  return content
end)

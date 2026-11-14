-- Goldweaver: tab "Professions" (docs/09-LEITFADEN.md, docs/14-UI-FUEHRUNG.md). Left: the character's professions as a
-- navigation list with icon and skill bar (like the professions book); right: status, next skill-up with shopping
-- list and actions, profitable crafts, unlearned recipes. "Compare" shows which profession to add or switch to.
local ADDON, ns = ...
local L = ns.L

local UI = ns.UI
local Chars = ns.Chars
local W, NAV = 752, 196
local DW = W - NAV - 10 -- detail width
local HALF = (DW - 8) / 2

local selectedSkillLine, showCompare

local function money(c) return UI.Money(c) end

local function ago(t)
  if not t then return L["never"] end
  local d = time() - t
  if d < 90 then return L["just now"] end
  if d < 3600 then return (L["%d min ago"]):format(math.floor(d / 60)) end
  if d < 86400 then return (L["%d h ago"]):format(math.floor(d / 3600)) end
  return (L["%d days ago"]):format(math.floor(d / 86400))
end

UI.RegisterTab("berufe", "Professions", function(frame)
  local content = {}

  -- navigation -------------------------------------------------------------------------------------
  local nav = UI.Inset(frame, NAV, 10)
  nav:SetPoint("TOPLEFT", 0, 0)
  nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local navTitle = UI.Section(nav, L["YOUR PROFESSIONS"], NAV - 20)
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

  local compareButton = UI.Button(nav, L["Compare professions"], NAV - 20, function() showCompare = true; content:Refresh() end)
  compareButton:SetPoint("BOTTOMLEFT", 10, 10)

  -- detail -----------------------------------------------------------------------------------------
  local status = UI.Inset(frame, DW, 98)
  status:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  local statusTitle = UI.Section(status, L["STATUS"], DW - 20)
  statusTitle:SetPoint("TOPLEFT", 10, -8)
  -- rank ladder: four segments (Apprentice .. Artisan), filled to the skill; under each the rank and what unlocks it
  local LADDER_W = DW - 190
  local ladder = {}
  for i = 1, 4 do
    local seg = CreateFrame("Frame", nil, status)
    seg:SetSize(LADDER_W / 4 - 4, 8); seg:SetPoint("TOPLEFT", 10 + (i - 1) * LADDER_W / 4, -30)
    seg.bg = seg:CreateTexture(nil, "BACKGROUND"); seg.bg:SetAllPoints()
    seg.fill = seg:CreateTexture(nil, "ARTWORK"); seg.fill:SetPoint("TOPLEFT"); seg.fill:SetHeight(8)
    seg.fill:SetColorTexture(1, 0.78, 0.35, 0.9)
    seg.label = status:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    seg.label:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 0, -3); seg.label:SetWidth(LADDER_W / 4 - 4)
    seg.label:SetJustifyH("LEFT"); seg.label:SetWordWrap(false)
    ladder[i] = seg
  end
  local ladderHover = CreateFrame("Frame", nil, status)
  ladderHover:SetPoint("TOPLEFT", 10, -26); ladderHover:SetSize(LADDER_W, 30); ladderHover:EnableMouse(true)
  ladderHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local statusLines = UI.Lines(status, 2, LADDER_W, "GameFontHighlightSmall", -58, true)
  local loadButton = UI.Button(status, L["Load recipes"], 160, nil)
  loadButton:SetPoint("TOPRIGHT", -10, -26)

  local nextStep = UI.Inset(frame, DW, 196)
  nextStep:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
  local nextTitle = UI.Section(nextStep, L["NEXT SKILL-UP"], DW - 20)
  nextTitle:SetPoint("TOPLEFT", 10, -8)
  local stepRow = UI.IconRows(nextStep, 1, DW - 190, -28, 42)
  local craftButton = UI.Button(nextStep, L["Craft"], 160, nil)
  craftButton:SetPoint("TOPRIGHT", -10, -32)
  craftButton:SetHeight(26)
  local reagentRows = UI.IconRows(nextStep, 3, DW - 20, -74, 34)
  local altLine = UI.Text(nextStep, "", "GameFontDisableSmall")
  altLine:SetPoint("BOTTOMLEFT", 10, 6); altLine:SetWidth(DW - 20)

  local profit = UI.Inset(frame, HALF, 10)
  profit:SetPoint("TOPLEFT", nextStep, "BOTTOMLEFT", 0, -8)
  profit:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  local profitTitle = UI.Section(profit, L["PROFITABLE"], HALF - 20)
  profitTitle:SetPoint("TOPLEFT", 10, -8)
  local profitRows = UI.IconRows(profit, 4, HALF - 20, -28, 38)

  local unlearned = UI.Inset(frame, HALF, 10)
  unlearned:SetPoint("TOPLEFT", profit, "TOPRIGHT", 8, 0)
  unlearned:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  local unlearnedTitle = UI.Section(unlearned, L["NOT LEARNED YET"], HALF - 20)
  unlearnedTitle:SetPoint("TOPLEFT", 10, -8)
  local unlearnedRows = UI.IconRows(unlearned, 4, HALF - 20, -28, 38)

  local compare = UI.Inset(frame, DW, 10)
  compare:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  compare:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local compareTitle = UI.Section(compare, L["WHICH PROFESSION PAYS OFF NEXT"], DW - 20)
  compareTitle:SetPoint("TOPLEFT", 10, -8)
  local compareTable = UI.Table(compare, {
    { L["Profession"], 0, 140 }, { L["Type"], 144, 90 }, { L["Cost to 300"], 238, 110 }, { L["already owned"], 352, 110 }, { L["Status"], 466, 70 },
  }, 14, -30)
  local compareNote = UI.Text(compare, L["Costs from the starter learning paths at current prices; live recipes replace them as soon as a character reads the profession. ~ = not all prices known."], "GameFontDisableSmall")
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
    local ranks = profile and profile.ranks or ns.Professions.DEFAULT_RANKS
    local level = me and me.level or 1
    local from = 0
    local nextShown = false
    for i, seg in ipairs(ladder) do
      local r = ranks[i]
      if p and r then
        local trained = r.max <= (p.maxRank or 0)
        seg.bg:SetColorTexture(trained and 0.24 or 0.07, trained and 0.19 or 0.06, trained and 0.12 or 0.05, 1)
        local share = math.max(0, math.min(1, ((p.rank or 0) - from) / math.max(1, r.max - from)))
        seg.fill:SetWidth(math.max(1, (LADDER_W / 4 - 4) * share)); seg.fill:SetShown(share > 0)
        local reqLevel = (ns.Learn.RankRequirement(skillLine, r.reqSkill)) or r.reqLevel or 0
        if trained then
          seg.label:SetText(L[r.name]); seg.label:SetTextColor(0.85, 0.80, 0.70)
        elseif not nextShown then
          nextShown = true
          if level < reqLevel then
            seg.label:SetText((L["%s · lvl %d"]):format(L[r.name], reqLevel)); seg.label:SetTextColor(1, 0.45, 0.35)
          elseif (p.rank or 0) < r.reqSkill then
            seg.label:SetText((L["%s · skill %d"]):format(L[r.name], r.reqSkill)); seg.label:SetTextColor(1, 0.82, 0.45)
          else
            seg.label:SetText((L["%s · learn now"]):format(L[r.name])); seg.label:SetTextColor(0.5, 1, 0.5)
          end
        else
          seg.label:SetText(("%s %d"):format(L[r.name], reqLevel)); seg.label:SetTextColor(0.5, 0.47, 0.42)
        end
        seg:Show(); seg.label:Show()
        from = r.max
      else
        seg:Hide(); seg.label:Hide()
      end
    end
    if p then
      -- the trainer of the next rank: the first one on the line, all of them in the tooltip
      local trainer = rank and rank.next and rank.trainer
      if trainer then
        local firstTrainer, more = trainer:match("^(.-%))%s*,%s*(.+)$")
        local label = rank.canTrain and L["Train at"] or L["Next rank at"]
        local text = ("%s: %s%s"):format(label, firstTrainer or trainer, more and (" " .. L["+ more"]) or "")
        lines[1] = rank.canTrain and { text, 0.6, 1, 0.6 } or { text, 0.8, 0.8, 0.8 }
      else lines[1] = { profile and profile.notes and profile.notes[1] and L[profile.notes[1]] or "", 0.7, 0.7, 0.7 } end
      ladderHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(("%s %d / %d"):format(p.name or "?", p.rank or 0, p.maxRank or 0), 1, 0.82, 0)
        for _, r in ipairs(ranks) do
          local reqLevel = (ns.Learn.RankRequirement(skillLine, r.reqSkill)) or r.reqLevel or 0
          GameTooltip:AddDoubleLine(L[r.name], (L["skill %d · level %d · cap %d"]):format(r.reqSkill, reqLevel, r.max), 1, 1, 1, 0.8, 0.8, 0.8)
        end
        if trainer then GameTooltip:AddLine(trainer, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
      end)
      -- gathering professions have no recipe book: the zone band for the current skill instead (profile.zones)
      local band = profile and ns.Professions.ZoneFor(profile, p.rank or 0)
      if band then
        lines[2] = { (L["Level in: %s (%s)"]):format(L[band.zone], L[band.note or ""]), 0.6, 0.85, 1 }
      else
        lines[2] = book and { (L["Recipes: %d of %d learned · read %s"]):format(p.learnedCount or 0, p.recipeCount or #book.list, ago(p.when)), 0.6, 0.6, 0.6 }
          or { L["Not read yet: 'Load recipes' (otherwise happens automatically at the next login)."], 1, 0.6, 0.2 }
      end
    end
    statusLines:Set(lines)
    statusTitle:SetText((L["STATUS · %s %d / %d"]):format((p and p.name or ""):upper(), p and p.rank or 0, p and p.maxRank or 0))
    loadButton:SetText(book and L["Refresh recipes"] or L["Load recipes"])
    loadButton:SetEnabled(ns.Features.Available("openProfession") and p ~= nil)
    loadButton:SetScript("OnClick", function()
      local ok, err = ns.Adapter.Open(skillLine)
      if not ok then ns.Print((L["Opening profession: %s"]):format(tostring(err))) end
    end)

    local plan = book and ns.Planner.Plan(skillLine, me) or nil
    local best = plan and plan.best
    if best then
      local r = best.recipe
      local greyText = best.pointsLeft and (" · " .. L["grey in %d points"]):format(best.pointsLeft) or ""
      stepRow:Set({ {
        icon = r.icon, item = r.outputItemID, text = ("%s ×%d"):format(r.name, plan.crafts or 1),
        right = (L["≈ %s per point"]):format(money(best.costPerPoint)), rightColor = { 1, 0.82, 0 },
        sub = (L["Skill-up %d %%%s · materials %s each · product %s"]):format(math.floor(best.chance * 100 + 0.5), greyText, money(best.cost), best.productValue > 0 and ("≈ " .. money(best.productValue)) or L["no price"]),
        tooltip = not r.outputItemID and r.name or nil,
      } })
      local rrows = {}
      for i, s in ipairs(plan.shopping or {}) do
        if i > 3 then break end
        local alts = s.have - (s.bags or 0) - (s.bank or 0)
        rrows[#rrows + 1] = {
          item = s.item, text = UI.ItemName(s.item), count = s.need,
          sub = (L["need %d · bags %d · bank %d%s"]):format(s.need, s.bags or 0, s.bank or 0, alts > 0 and (" · " .. L["alts"] .. " " .. alts) or ""),
          right = s.buy > 0 and ((L["missing %d%s"]):format(s.buy, s.cost and (" · " .. money(s.cost)) or "")) or ("|cff80ff80" .. L["owned"] .. "|r"),
          rightColor = s.buy > 0 and { 1, 0.6, 0.4 } or nil,
          button = s.buy > 0 and { L["Search AH"], function()
            if not ns.Auction.SearchFor(s.item) then ns.Print(L["Open the auction house, then click again."]) end
          end } or nil,
        }
      end
      reagentRows:Set(rrows)
      craftButton:SetText((L["Craft ×%d"]):format(plan.crafts or 1))
      local open = ns.Adapter.IsOpen() and ns.Adapter.current == skillLine
      craftButton:SetScript("OnClick", function()
        if not (ns.Adapter.IsOpen() and ns.Adapter.current == skillLine) then ns.Adapter.Open(skillLine, r.id); return end
        local ok, err = ns.Adapter.Craft(r.id, plan.crafts or 1)
        if not ok then ns.Print((L["Crafting: %s"]):format(tostring(err))) end
        if ns.Checks then ns.Checks.Pass("craft", "via the guide") end
      end)
      if not open then craftButton:SetText(L["Open profession"]) end
      craftButton:Enable()
      local alts = {}
      for i = 2, math.min(4, #plan.candidates) do
        local c = plan.candidates[i]
        alts[#alts + 1] = ("%s (%s/Pkt)"):format(c.recipe.name, money(c.costPerPoint))
      end
      altLine:SetText(#alts > 0 and (L["Alternatives: %s"]):format(table.concat(alts, " · ")) or "")
    else
      stepRow:Set({ { icon = "Interface\\Icons\\INV_Misc_Book_09", text = book and L["No learned recipe gives points anymore"] or L["No recipe data yet"],
        sub = book and L["Learn a new recipe (right) or train the next rank."] or L["Read automatically at the next login."], color = { 0.8, 0.8, 0.8 } } })
      reagentRows:Set({})
      craftButton:Disable()
      altLine:SetText("")
    end

    local prows = {}
    for _, e in ipairs(book and ns.Planner.Profitable(skillLine, me, 4) or {}) do
      prows[#prows + 1] = {
        icon = e.recipe.icon, item = e.recipe.outputItemID, text = e.recipe.name,
        right = (e.margin >= 0 and "+" or "") .. money(e.margin), rightColor = e.margin >= 0 and { 0.4, 1, 0.4 } or { 1, 0.5, 0.5 },
        sub = ("%s » %s"):format(money(e.cost), money(e.value)),
      }
    end
    if #prows == 0 then prows[1] = { icon = "Interface\\Icons\\INV_Misc_Coin_02", text = L["No product prices known"], sub = L["Search the AH or scan with Auctionator."], color = { 0.7, 0.7, 0.7 } } end
    profitRows:Set(prows)

    local urows = {}
    local unl = book and ns.Adapter.Unlearned(skillLine, me) or {}
    for i, r in ipairs(unl) do
      if i > 4 then break end
      local source = ns.Learn and ns.Learn.RecipeSource(r) or nil
      urows[#urows + 1] = {
        icon = r.icon, item = r.outputItemID, text = r.name, tooltip = not r.outputItemID and r.name or nil,
        sub = source or L["Source still unknown (visit trainer/vendor)"], color = source and { 0.8, 1, 0.8 } or nil,
      }
    end
    if #urows == 0 then urows[1] = { icon = "Interface\\Icons\\Achievement_General", text = book and L["All learned"] or L["No recipe data yet"], color = { 0.7, 0.7, 0.7 } } end
    unlearnedRows:Set(urows)
    unlearnedTitle:SetText((L["NOT LEARNED YET (%d)"]):format(#unl))
  end

  local function refreshCompare()
    local rows = {}
    local CATEGORY = { crafting = "Crafting", gathering = "Gathering", secondary = "Secondary" }
    for _, r in ipairs(ns.Compare.Rows()) do
      rows[#rows + 1] = { L[r.profile.name], L[CATEGORY[r.profile.category] or r.profile.category],
        money(r.costTo300) .. (r.coverage < 1 and " ~" or ""), money(r.ownedValue), r.known and (L["learned %s"]):format(tostring(r.known.rank)) or "–" }
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

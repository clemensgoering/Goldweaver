-- Goldweaver: tab "Guide" (docs/14-UI-FUEHRUNG.md, mockup docs/mockups/index.html). Main and twink as one team:
-- both characters side by side with the mail pipeline between them, the shared gather list (what the crafter needs
-- for the next skill points and where each piece is), and RestedXP-style guidance on the right: one current step
-- with one action, the next steps, the feature status. The own character is always on the left.
local ADDON, ns = ...
local L = ns.L

local UI = ns.UI
local DUO_H = 100
local CARD_W, FLOW_W = 296, 160
local LIST_W, RIGHT_W = 420, 322
local ROLE_ICON = { main = "Interface\\Icons\\INV_Misc_Bag_08", processor = "Interface\\Icons\\Trade_BlackSmithing", none = "Interface\\Icons\\INV_Misc_QuestionMark" }
local GOLD, GREEN, ORANGE, GREY = { 1, 0.82, 0.45 }, { 0.37, 0.83, 0.37 }, { 1, 0.6, 0.24 }, { 0.62, 0.57, 0.50 }

local function first(rec) return rec and (rec.firstName or rec.name) or "?" end

-- One character card: role icon, name (+ "YOU"), one info line, up to two profession skill bars.
local function charCard(parent, highlight)
  local c = UI.Inset(parent, CARD_W, DUO_H, highlight and "hl" or "card")
  c.icon = UI.ItemButton(c, 36)
  c.icon:SetPoint("TOPLEFT", 10, -10)
  c.name = UI.Text(c, "", "GameFontNormalLarge")
  c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 0)
  c.you = UI.Text(c, "", "GameFontNormalSmall")
  c.you:SetPoint("LEFT", c.name, "RIGHT", 6, 0)
  c.line = UI.Text(c, "", "GameFontDisableSmall")
  c.line:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
  c.line:SetWidth(CARD_W - 64); c.line:SetWordWrap(false)
  c.skills = {}
  for i = 1, 2 do
    local label = UI.Text(c, "", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 12, -52 - (i - 1) * 20)
    label:SetWidth(96); label:SetWordWrap(false)
    local bar = UI.SkillBar(c, CARD_W - 124, 12)
    bar:SetPoint("LEFT", label, "RIGHT", 4, 0)
    c.skills[i] = { label = label, bar = bar }
  end
  function c:SetChar(rec, isMe, line)
    if not rec then
      self.icon:SetContent("Interface\\Icons\\INV_Misc_QuestionMark")
      self.name:SetText(L["No partner yet"]); self.you:SetText("")
      self.line:SetText(line or "")
      for _, s in ipairs(self.skills) do s.label:SetText(""); s.bar:Hide() end
      return
    end
    self.icon:SetContent(ROLE_ICON[rec.role or "none"] or ROLE_ICON.none)
    self.name:SetText(first(rec))
    self.you:SetText(isMe and L["YOU"] or "")
    self.line:SetText(line or "")
    local list = {}
    for _, p in pairs(rec.professions or {}) do if not p.former and p.name then list[#list + 1] = p end end
    table.sort(list, function(a, b) return (a.rank or 0) > (b.rank or 0) end)
    for i, s in ipairs(self.skills) do
      local p = list[i]
      if p then
        s.label:SetText(p.name); s.bar:Show(); s.bar:SetSkill(p.rank or 0, p.maxRank or 1)
      else
        s.label:SetText(i == 1 and L["no professions"] or ""); s.bar:Hide()
      end
    end
  end
  return c
end

-- The pipe between the cards: two chips with a line under each and a gold arrow between them.
local function flow(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(FLOW_W, DUO_H)
  local function chip(y)
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(FLOW_W - 16, 20); box:SetPoint("TOP", 0, y)
    UI.Skin(box, "ghost")
    box.text = UI.Text(box, "", "GameFontHighlightSmall")
    box.text:SetPoint("CENTER"); box.text:SetJustifyH("CENTER")
    box.sub = UI.Text(f, "", "GameFontDisableSmall")
    box.sub:SetPoint("TOP", box, "BOTTOM", 0, -2); box.sub:SetWidth(FLOW_W - 8); box.sub:SetJustifyH("CENTER"); box.sub:SetWordWrap(false)
    return box
  end
  f.a = chip(-6)
  local arrow = f:CreateTexture(nil, "ARTWORK")
  arrow:SetPoint("TOPLEFT", 10, -49); arrow:SetPoint("TOPRIGHT", -18, -49); arrow:SetHeight(2)
  arrow:SetColorTexture(0.72, 0.50, 0.12, 0.9)
  local head = UI.Text(f, "»", "GameFontNormal")
  head:SetPoint("LEFT", arrow, "RIGHT", 0, 0)
  f.b = chip(-58)
  function f:Set(a, aSub, b, bSub)
    self.a.text:SetText(a or ""); self.a.sub:SetText(aSub or "")
    self.b.text:SetText(b or ""); self.b.sub:SetText(bSub or "")
  end
  return f
end

local function mailTotal(rec)
  local n = 0
  local inv = rec and rec.inventory or {}
  for _, c in pairs(inv.mail or {}) do n = n + c end
  for _, c in pairs(inv.incoming and inv.incoming.items or {}) do n = n + c end
  return n
end

UI.RegisterTab("guide", "Guide", function(frame)
  local content = {}

  -- team strip
  local meCard = charCard(frame, true)
  meCard:SetPoint("TOPLEFT", 0, 0)
  local pipe = flow(frame)
  pipe:SetPoint("TOPLEFT", meCard, "TOPRIGHT", 0, 0)
  local otherCard = charCard(frame, false)
  otherCard:SetPoint("TOPLEFT", pipe, "TOPRIGHT", 0, 0)

  -- shared gather list
  local list = UI.Inset(frame, LIST_W, 10)
  list:SetPoint("TOPLEFT", meCard, "BOTTOMLEFT", 0, -8)
  list:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  local listTitle = UI.Section(list, L["SHARED GATHER LIST"], LIST_W - 20)
  listTitle:SetPoint("TOPLEFT", 10, -8)
  local listSub = UI.Text(list, "", "GameFontDisableSmall")
  listSub:SetPoint("TOPLEFT", 10, -28); listSub:SetWidth(LIST_W - 20); listSub:SetWordWrap(false)
  local needRows = UI.ProgressRows(list, 7, LIST_W - 20, -46, 44)
  local empty = UI.Text(list, "", "GameFontHighlight")
  empty:SetPoint("TOPLEFT", 10, -52); empty:SetWidth(LIST_W - 20)
  local legend = UI.Text(list, "", "GameFontDisableSmall")
  legend:SetPoint("BOTTOMLEFT", 10, 10)
  local points = UI.Text(list, "", "GameFontNormal")
  points:SetPoint("BOTTOMRIGHT", -10, 10); points:SetJustifyH("RIGHT")
  points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

  -- guidance
  local card = UI.StepCard(frame, RIGHT_W, 136)
  card:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
  local health = UI.Inset(frame, RIGHT_W, 44)
  health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local after = UI.Inset(frame, RIGHT_W, 10)
  after:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -8)
  after:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 8)
  local afterTitle = UI.Section(after, L["NEXT"], RIGHT_W - 20)
  afterTitle:SetPoint("TOPLEFT", 10, -8)
  local steps = UI.StepList(after, 4, RIGHT_W - 20, -28)

  local healthIcon = health:CreateTexture(nil, "ARTWORK")
  healthIcon:SetSize(16, 16)
  healthIcon:SetPoint("TOPLEFT", 10, -8)
  local healthText = UI.Text(health, "", "GameFontHighlightSmall")
  healthText:SetPoint("LEFT", healthIcon, "RIGHT", 6, 0)
  healthText:SetWidth(RIGHT_W - 140); healthText:SetWordWrap(false)
  local healthSub = UI.Text(health, "", "GameFontDisableSmall")
  healthSub:SetPoint("TOPLEFT", healthIcon, "BOTTOMLEFT", 0, -4)
  healthSub:SetWidth(RIGHT_W - 130); healthSub:SetWordWrap(false)
  local reportButton = UI.Button(health, L["Report"], 100, function() ns.Debug.Run() end)
  reportButton:SetPoint("RIGHT", -8, 0)

  local function refreshTeam(me)
    local gatherer, crafter = ns.Coop.Team()
    local partner = ns.Coop.Partner(me)
    local view = ns.Coop.Needs()
    local count, value = ns.Mail.Pending()
    local roleLine = me and L[ns.Chars.ROLE_LABELS[me.role or "none"] or ""] or ""
    if me and me == gatherer and crafter then
      meCard:SetChar(me, true, (L["Level %d · %d item(s) for %s in your bags"]):format(me.level or 0, count, first(crafter)))
      otherCard:SetChar(crafter, false, (L["Level %d · last seen %s"]):format(crafter.level or 0, ns.Util.Ago(crafter.lastSeen)))
      pipe:Set((L["%d item(s) · %s"]):format(count, UI.Money(value)), (L["in your bags for %s"]):format(first(crafter)),
        (L["%d in the mail"]):format(mailTotal(crafter)), (L["waiting for %s"]):format(first(crafter)))
    elseif me and me == crafter and gatherer then
      local inMail = mailTotal(me)
      meCard:SetChar(me, true, (L["Level %d · %d item(s) in your mailbox"]):format(me.level or 0, inMail))
      otherCard:SetChar(gatherer, false, (L["Level %d · last seen %s"]):format(gatherer.level or 0, ns.Util.Ago(gatherer.lastSeen)))
      pipe:Set((L["%d in the mail"]):format(inMail), (L["from %s"]):format(first(gatherer)),
        (L["State of %s"]):format(first(gatherer)), ns.Util.Ago(gatherer.lastSeen))
    else
      meCard:SetChar(me, true, me and ("%s · " .. L["Level %d"]):format(roleLine, me.level or 0) or "")
      otherCard:SetChar(partner, false, L["Log in with your twink once: roles are set automatically (Team tab)."])
      pipe:Set("", "", "", "")
    end

    if not view then
      needRows:Set({})
      empty:SetText((gatherer or crafter) and L["Your partner's professions are not read yet. Open each profession once on the twink."]
        or L["As soon as a main and a processor are known, this shows what the twink needs and what the main can gather for it."])
      empty:Show()
      listSub:SetText(""); legend:SetText(""); points:SetText("")
      return
    end
    empty:Hide()
    local plans = {}
    for _, p in ipairs(view.plans) do plans[#plans + 1] = ("%s %d » %d"):format(p.name, p.from, p.to) end
    local amGatherer = me == view.gatherer
    listSub:SetText(amGatherer and (L["What %s needs: %s"]):format(first(view.crafter), table.concat(plans, " · "))
      or (L["What you need: %s"]):format(table.concat(plans, " · ")))
    local data = {}
    for _, r in ipairs(view.rows) do
      if #data >= #needRows then break end
      local note
      if r.source == "here" then note = { L["gather here"], GREEN[1], GREEN[2], GREEN[3] }
      elseif r.source == "gatherer" then
        note = amGatherer and { L["you can gather it"], GOLD[1], GOLD[2], GOLD[3] } or { (L["%s can gather it"]):format(first(view.gatherer)), GREEN[1], GREEN[2], GREEN[3] }
      elseif r.source == "vendor" then note = { L["vendor"], GREY[1], GREY[2], GREY[3] }
      else note = { L["elsewhere"], ORANGE[1], ORANGE[2], ORANGE[3] } end
      local parts = {}
      if r.via then parts[#parts + 1] = (L["for %s"]):format(UI.ItemName(r.via)) end
      if r.gatherer > 0 then parts[#parts + 1] = amGatherer and (L["%d in your bags"]):format(r.gatherer) or (L["%d at %s"]):format(r.gatherer, first(view.gatherer)) end
      if r.mail > 0 then parts[#parts + 1] = (L["%d in the mail"]):format(r.mail) end
      if r.crafter > 0 then parts[#parts + 1] = amGatherer and (L["%d at %s"]):format(r.crafter, first(view.crafter)) or (L["%d with you"]):format(r.crafter) end
      data[#data + 1] = { item = r.item, text = UI.ItemName(r.item), note = note, sub = table.concat(parts, " · "),
        have = r.have, need = r.need, mail = r.mail }
    end
    needRows:Set(data)
    legend:SetText(L["Bar: gold = there · blue = in the mail"])
    if amGatherer then
      points:SetText((L["You carry: +%d skill points for %s"]):format(view.fromGatherer, first(view.crafter)))
    else
      points:SetText((L["In the mail: +%d skill points"]):format(view.fromMail))
    end
  end

  function content:Refresh()
    local me = ns.Chars.Current()
    local ok, err = pcall(refreshTeam, me)
    if not ok then ns.Health.Record("Guide team view", err) end

    local list7 = ns.Steps.Build(5)
    card:SetStep(list7[1], 1, #list7)
    steps:SetSteps(list7, 1)
    afterTitle:SetText(#list7 > 1 and L["NEXT"] or L["NEXT · nothing more"])

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

    local today = ns.Ledger.Totals(1)
    local delta = ns.Ledger.SessionDelta()
    UI.SetHeaderInfo((L["Session %s · sold today %s"]):format((delta >= 0 and "+" or "-") .. UI.Money(math.abs(delta)), UI.Money(today.sales)))
  end
  return content
end)

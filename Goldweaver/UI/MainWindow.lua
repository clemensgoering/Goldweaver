-- Goldweaver: the four tabs of the /gw window (docs/08-UX.md section 4.7): Heute · Berufe · Charaktere · Einstellungen.
-- Layout: grouped boxes with real columns; text never overlaps (UI.Lines/UI.Pairs/UI.Table anchor each row below the last).
local ADDON, ns = ...

local UI = ns.UI
local Chars = ns.Chars

local W = 584 -- usable width inside the body (window 620 minus paddings)

local function money(copper) return ns.Util.Money(copper or 0) end

local function professionSummary(rec)
  local profs = {}
  for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank or 0) end
  table.sort(profs)
  return #profs > 0 and table.concat(profs, ", ") or "keine Berufe erfasst"
end

-- Heute --------------------------------------------------------------------------------------
UI.RegisterTab("heute", "Heute", function(frame)
  local content = {}

  local steps = UI.Group(frame, "NÄCHSTE SCHRITTE", W, 120)
  steps:SetPoint("TOPLEFT", 0, 0)
  local stepLines = UI.Lines(steps, 3, W - 20)

  local me = UI.Group(frame, "DIESER CHARAKTER", 280, 128)
  me:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -10)
  local mePairs = UI.Pairs(me, 4, 70, 190)

  local team = UI.Group(frame, "DEIN TEAM AUF DIESEM MARKT", W - 290, 128)
  team:SetPoint("TOPLEFT", me, "TOPRIGHT", 10, 0)
  local teamTable = UI.Table(team, { { "Charakter", 0, 130 }, { "Rolle", 134, 80 }, { "Berufe", 218, 60 } }, 4)

  local tip = UI.Text(frame, "", "GameFontDisableSmall")
  tip:SetPoint("BOTTOMLEFT", 0, 0)
  tip:SetWidth(W)

  function content:Refresh()
    local rec = Chars.Current()
    local unassigned = Chars.Unassigned()
    local market = Chars.MarketKey()
    local list = {}
    if unassigned > 0 then
      list[#list + 1] = { ("1. %d Charakter(e) ohne Rolle: im Tab Charaktere Main oder Verarbeiter wählen."):format(unassigned), 1, 0.6, 0.2 }
    else
      list[#list + 1] = { "1. Rollen sind gesetzt.", 0.6, 1, 0.6 }
    end
    list[#list + 1] = { "2. Empfehlungen (entzaubern, herstellen, Kiste füllen) erscheinen hier, sobald Tooltip, Post und Berufe-Seitenleiste fertig sind.", 0.8, 0.8, 0.8 }
    list[#list + 1] = { "3. Bis dahin: /gw probe liefert die Spiel-API-Antworten für die Entwicklung.", 0.8, 0.8, 0.8 }
    stepLines:Set(list)

    mePairs:Set({
      { "Name", Chars.FullName() },
      { "Rolle", rec and Chars.ROLE_LABELS[rec.role or "none"] or "unbekannt" },
      { "Markt", market },
      { "Gold", money(GetMoney and GetMoney() or 0) },
    })

    local rows = {}
    for _, c in ipairs(Chars.All(market)) do
      local n = 0
      for _ in pairs(c.professions or {}) do n = n + 1 end
      rows[#rows + 1] = { c.name, Chars.ROLE_LABELS[c.role or "none"]:gsub(" %(.*%)", ""), tostring(n) }
    end
    if #rows == 0 then rows[1] = { "noch niemand", "", "" } end
    teamTable:Set(rows)

    tip:SetText("Tipp: Zahlen tragen immer Quelle und Alter. /gw help listet alle Befehle.")
  end
  return content
end)

-- Berufe -------------------------------------------------------------------------------------
UI.RegisterTab("berufe", "Berufe", function(frame)
  local content = {}

  local mine = UI.Group(frame, "BERUFE DIESES CHARAKTERS", W, 150)
  mine:SetPoint("TOPLEFT", 0, 0)
  local mineTable = UI.Table(mine, { { "Beruf", 0, 180 }, { "Skill", 184, 70 }, { "Rang", 258, 100 }, { "Profil", 362, 90 }, { "Startpfad", 456, 100 } }, 6)

  local known = UI.Group(frame, "WEITERE PROFILE (für Berufswechsel oder Zweitberuf)", W, 150)
  known:SetPoint("TOPLEFT", mine, "BOTTOMLEFT", 0, -10)
  local knownTable = UI.Table(known, { { "Beruf", 0, 180 }, { "Kategorie", 184, 120 }, { "Startpfad", 308, 120 }, { "Kosten bis 300", 432, 140 } }, 6)

  local note = UI.Text(frame, "Kosten bis 300 zu aktuellen Preisen und beste Rezepte folgen mit dem Berufs-Vergleich (WP2.5). Skill-up-Planer und Seitenleiste am Berufefenster mit WP2.1/2.2.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 0, 0)
  note:SetWidth(W)

  local CATEGORY = { crafting = "Herstellung", gathering = "Sammeln", secondary = "Sekundär" }

  function content:Refresh()
    local rec = Chars.Current()
    local rows, seen = {}, {}
    for skillLine, p in pairs(rec and rec.professions or {}) do
      local profile = ns.Professions:BySkillLine(skillLine)
      seen[skillLine] = true
      local rank = profile and ns.Professions.RankFor(profile, p.rank or 0) or nil
      rows[#rows + 1] = { p.name or "?", ("%d / %d"):format(p.rank or 0, p.maxRank or 0), rank and rank.name or "–",
        profile and "vorhanden" or "folgt", profile and (#profile.seedPath .. " Schritte") or "–" }
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    if #rows == 0 then rows[1] = { "keine Berufe erfasst", "", "", "", "" } end
    mineTable:Set(rows)

    local others = {}
    for _, profile in ipairs(ns.Professions:All()) do
      if not seen[profile.skillLineID] then
        others[#others + 1] = { profile.name, CATEGORY[profile.category] or profile.category, #profile.seedPath .. " Schritte", "folgt (WP2.5)" }
      end
    end
    if #others == 0 then others[1] = { "alle bekannten Profile sind erlernt", "", "", "" } end
    knownTable:Set(others)
  end
  return content
end)

-- Charaktere ---------------------------------------------------------------------------------
UI.RegisterTab("chars", "Charaktere", function(frame)
  local content = { rows = {} }

  local help = UI.Group(frame, "ROLLEN", W, 62)
  help:SetPoint("TOPLEFT", 0, 0)
  local helpLines = UI.Lines(help, 1, W - 20, "GameFontHighlightSmall")
  helpLines:Set({ { "Main sammelt unterwegs und schickt Material. Verarbeiter stellt her, entzaubert und verkauft. Bank lagert. Jeder Charakter wird beim ersten Login automatisch eingetragen.", 0.85, 0.85, 0.85 } })

  local list = UI.Group(frame, "CHARAKTERE", W, 300)
  list:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  local colName = UI.Text(list, "Charakter", "GameFontDisableSmall"); colName:SetPoint("TOPLEFT", 10, -26)
  local colMarket = UI.Text(list, "Markt", "GameFontDisableSmall"); colMarket:SetPoint("TOPLEFT", 200, -26)
  local colProfs = UI.Text(list, "Berufe", "GameFontDisableSmall"); colProfs:SetPoint("TOPLEFT", 330, -26)

  local ROLE_ORDER = { "main", "processor", "bank", "none" }
  local ROLE_SHORT = { main = "Main", processor = "Verarbeiter", bank = "Bank", none = "–" }

  local function row(i)
    if content.rows[i] then return content.rows[i] end
    local r = CreateFrame("Frame", nil, list)
    r:SetSize(W - 20, 44)
    r:SetPoint("TOPLEFT", 10, -42 - (i - 1) * 48)
    local line = r:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.06)
    line:SetPoint("BOTTOMLEFT", 0, -2); line:SetPoint("BOTTOMRIGHT", 0, -2); line:SetHeight(1)
    r.name = UI.Text(r, "", "GameFontNormal"); r.name:SetPoint("TOPLEFT", 0, 0); r.name:SetWidth(185)
    r.market = UI.Text(r, ""); r.market:SetPoint("TOPLEFT", 190, 0); r.market:SetWidth(125)
    r.profs = UI.Text(r, "", "GameFontHighlightSmall"); r.profs:SetPoint("TOPLEFT", 320, 0); r.profs:SetWidth(W - 20 - 320); r.profs:SetWordWrap(true)
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
      if i > 5 then break end
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

  local display = UI.Group(frame, "ANZEIGE", W, 90)
  display:SetPoint("TOPLEFT", 0, 0)
  local minimap = UI.Check(display, "Minimap-Button anzeigen", not s.minimapHidden, function(on)
    s.minimapHidden = not on
    if ns.Minimap then ns.Minimap.SetShown(on) end
  end)
  minimap:SetPoint("TOPLEFT", 10, -26)
  local debug = UI.Check(display, "Debug-Ausgaben im Chat", s.debug, function(on) s.debug = on end)
  debug:SetPoint("TOPLEFT", 10, -52)

  local calc = UI.Group(frame, "RECHENGRUNDLAGEN", W, 110)
  calc:SetPoint("TOPLEFT", display, "BOTTOMLEFT", 0, -10)
  local calcPairs = UI.Pairs(calc, 3, 150, W - 190)

  local note = UI.Text(frame, "Höchstens zehn Einstellungen, alle mit funktionierendem Standard (docs/08-UX.md Regel 7). Ändern per Befehl: /gw favor <Kupfer>, /gw market <Key>|auto.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 0, 0)
  note:SetWidth(W)

  function content:Refresh()
    minimap:SetChecked(not s.minimapHidden)
    debug:SetChecked(s.debug and true or false)
    calcPairs:Set({
      { "Wert je Favor", ns.Util.Money(s.favorValueCopper or 500) .. "  (für die Kisten-Empfehlung)" },
      { "AH-Cut", ("%d %%"):format(math.floor((s.ahCut or 0.05) * 100 + 0.5)) .. "  (Fraktions-AH; Goblin-AH 15 %)" },
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

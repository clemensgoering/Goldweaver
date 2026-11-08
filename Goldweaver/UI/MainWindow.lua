-- Goldweaver: the four tabs of the /gw window (docs/08-UX.md section 4.7): Heute · Berufe · Charaktere · Einstellungen.
local ADDON, ns = ...

local UI = ns.UI
local Chars = ns.Chars

local function money(copper) return ns.Util.Money(copper or 0) end

-- Heute --------------------------------------------------------------------------------------
UI.RegisterTab("heute", "Heute", function(frame)
  local content = {}
  local header = UI.Header(frame, "HEUTE")
  header:SetPoint("TOPLEFT", 0, 0)
  local lines = {}
  for i = 1, 8 do
    local fs = UI.Text(frame, "")
    fs:SetPoint("TOPLEFT", 0, -22 - (i - 1) * 18)
    fs:SetWidth(560)
    lines[i] = fs
  end
  local footer = UI.Text(frame, "", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", 0, 0)
  footer:SetWidth(560)

  function content:Refresh()
    local me = Chars.Current()
    local role = me and Chars.ROLE_LABELS[me.role or "none"] or "unbekannt"
    local unassigned = Chars.Unassigned()
    local i = 0
    local function add(text, r, g, b)
      i = i + 1
      if lines[i] then lines[i]:SetText(text); lines[i]:SetTextColor(r or 1, g or 1, b or 1) end
    end
    if unassigned > 0 then
      add(("1. %d Charakter(e) haben noch keine Rolle. Tab 'Charaktere' öffnen und Main / Verarbeiter wählen."):format(unassigned), 1, 0.6, 0.2)
    else
      add("1. Rollen sind gesetzt. Empfehlungen erscheinen hier, sobald Tooltip, Post und Berufe-Seitenleiste fertig sind (WP1.3, WP1.5, WP2.x).")
    end
    add(("Dieser Charakter: %s · Rolle: %s · Markt: %s"):format(Chars.FullName(), role, Chars.MarketKey()), 0.8, 0.8, 0.8)
    add(("Gold: %s"):format(money(GetMoney and GetMoney() or 0)), 0.8, 0.8, 0.8)
    local processors = Chars.ByRole("processor", Chars.MarketKey())
    local names = {}
    for _, rec in ipairs(processors) do names[#names + 1] = rec.name end
    add(("Verarbeiter auf diesem Markt: %s"):format(#names > 0 and table.concat(names, ", ") or "keiner"), 0.8, 0.8, 0.8)
    for j = i + 1, #lines do lines[j]:SetText("") end
    footer:SetText("Tipp: /gw probe prüft die Spiel-APIs, /gw help listet alle Befehle. Zahlen tragen immer Quelle und Alter.")
  end
  return content
end)

-- Berufe -------------------------------------------------------------------------------------
UI.RegisterTab("berufe", "Berufe", function(frame)
  local content = {}
  local header = UI.Header(frame, "BERUFE DIESES CHARAKTERS UND BEKANNTE PROFILE")
  header:SetPoint("TOPLEFT", 0, 0)
  local cols = UI.Text(frame, "Beruf                          Skill         Profil            Startpfad", "GameFontDisableSmall")
  cols:SetPoint("TOPLEFT", 0, -20)
  local rows = {}
  for i = 1, 14 do
    local fs = UI.Text(frame, "")
    fs:SetPoint("TOPLEFT", 0, -38 - (i - 1) * 17)
    fs:SetWidth(560)
    rows[i] = fs
  end
  local note = UI.Text(frame, "Kosten bis 300 und beste Rezepte folgen mit WP2.5 (Berufs-Vergleich). Skill-up-Planer und Seitenleiste am Berufefenster mit WP2.1/2.2.", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 0, 0)
  note:SetWidth(560)

  function content:Refresh()
    local me = Chars.Current()
    local mine = me and me.professions or {}
    local i = 0
    local function add(text) i = i + 1 if rows[i] then rows[i]:SetText(text) end end
    -- professions the character has
    local seen = {}
    for skillLine, p in pairs(mine) do
      local profile = ns.Professions:BySkillLine(skillLine)
      seen[skillLine] = true
      add(("%-30s %3d/%-3d       %-16s %s"):format(p.name or "?", p.rank or 0, p.maxRank or 0,
        profile and "ja" or "noch nicht", profile and (#profile.seedPath .. " Schritte") or "–"))
    end
    -- profiles the character does not have
    for _, profile in ipairs(ns.Professions:All()) do
      if not seen[profile.skillLineID] then
        add(("%-30s %-13s %-16s %s"):format(profile.name, "–", "ja", #profile.seedPath .. " Schritte"))
      end
    end
    for j = i + 1, #rows do rows[j]:SetText("") end
  end
  return content
end)

-- Charaktere ---------------------------------------------------------------------------------
UI.RegisterTab("chars", "Charaktere", function(frame)
  local content = { rows = {} }
  local header = UI.Header(frame, "CHARAKTERE UND ROLLEN")
  header:SetPoint("TOPLEFT", 0, 0)
  local hint = UI.Text(frame, "Main sammelt unterwegs und schickt Material. Verarbeiter stellt her, entzaubert und verkauft. Bank lagert. Jeder Charakter wird beim ersten Login automatisch eingetragen.", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 0, -18)
  hint:SetWidth(580)
  local cols = UI.Text(frame, "Charakter                      Markt                 Berufe", "GameFontDisableSmall")
  cols:SetPoint("TOPLEFT", 0, -46)

  local ROLE_ORDER = { "main", "processor", "bank", "none" }
  local ROLE_SHORT = { main = "Main", processor = "Verarbeiter", bank = "Bank", none = "–" }

  local function row(i)
    if content.rows[i] then return content.rows[i] end
    local r = CreateFrame("Frame", nil, frame)
    r:SetSize(580, 40)
    r:SetPoint("TOPLEFT", 0, -62 - (i - 1) * 44)
    r.name = UI.Text(r, "", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", 0, 0)
    r.name:SetWidth(200)
    r.market = UI.Text(r, "")
    r.market:SetPoint("TOPLEFT", 200, 0)
    r.market:SetWidth(150)
    r.profs = UI.Text(r, "", "GameFontHighlightSmall")
    r.profs:SetPoint("TOPLEFT", 350, 0)
    r.profs:SetWidth(230)
    r.buttons = {}
    local x = 0
    for _, role in ipairs(ROLE_ORDER) do
      local b = UI.Button(r, ROLE_SHORT[role], role == "processor" and 90 or 60, function()
        if r.rec then Chars.SetRole(r.rec.name, role) end
      end)
      b:SetPoint("TOPLEFT", x, -18)
      r.buttons[role] = b
      x = x + (role == "processor" and 92 or 62)
    end
    content.rows[i] = r
    return r
  end

  function content:Refresh()
    local list = Chars.All()
    for i, rec in ipairs(list) do
      if i > 8 then break end
      local r = row(i)
      r.rec = rec
      r:Show()
      local me = rec.name == Chars.FullName() and " (du)" or ""
      r.name:SetText(rec.name .. me)
      r.market:SetText(rec.market or "?")
      local profs = {}
      for _, p in pairs(rec.professions or {}) do profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank or 0) end
      table.sort(profs)
      r.profs:SetText(#profs > 0 and table.concat(profs, ", ") or "keine Berufe erfasst")
      for role, b in pairs(r.buttons) do
        if (rec.role or "none") == role then b:Disable() else b:Enable() end
      end
    end
    for i = #list + 1, #content.rows do content.rows[i]:Hide() end
  end
  return content
end)

-- Einstellungen ------------------------------------------------------------------------------
UI.RegisterTab("settings", "Einstellungen", function(frame)
  local content = {}
  local header = UI.Header(frame, "EINSTELLUNGEN")
  header:SetPoint("TOPLEFT", 0, 0)
  local s = ns.db.settings

  local minimap = UI.Check(frame, "Minimap-Button anzeigen", not s.minimapHidden, function(on)
    s.minimapHidden = not on
    if ns.Minimap then ns.Minimap.SetShown(on) end
  end)
  minimap:SetPoint("TOPLEFT", 0, -22)

  local debug = UI.Check(frame, "Debug-Ausgaben im Chat", s.debug, function(on) s.debug = on end)
  debug:SetPoint("TOPLEFT", 0, -48)

  local favorLabel = UI.Text(frame, ("Wert eines Merchant's Favor für die Kisten-Empfehlung: %s (Standard 5s, ändern mit /gw favor <Kupfer>)"):format(ns.Util.Money(s.favorValueCopper or 500)), "GameFontHighlightSmall")
  favorLabel:SetPoint("TOPLEFT", 0, -82)
  favorLabel:SetWidth(580)

  local market = UI.Text(frame, "", "GameFontHighlightSmall")
  market:SetPoint("TOPLEFT", 0, -104)
  market:SetWidth(580)

  local note = UI.Text(frame, "Höchstens zehn Einstellungen, alle mit funktionierendem Standard (docs/08-UX.md Regel 7).", "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", 0, 0)

  function content:Refresh()
    minimap:SetChecked(not s.minimapHidden)
    debug:SetChecked(s.debug and true or false)
    favorLabel:SetText(("Wert eines Merchant's Favor für die Kisten-Empfehlung: %s (ändern mit /gw favor <Kupfer>)"):format(ns.Util.Money(s.favorValueCopper or 500)))
    market:SetText(("Markt-Key: %s%s (ändern mit /gw market <Region-Regelsatz-Fraktion>, zurücksetzen mit /gw market auto)"):format(Chars.MarketKey(), s.marketKey and " (manuell)" or " (automatisch)"))
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

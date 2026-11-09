-- Goldweaver: tab "Team" - characters with their roles (set automatically, changeable here), the self check status
-- and shortcuts to the settings (Blizzard options) and the debug report.
local ADDON, ns = ...

local UI = ns.UI
local Chars = ns.Chars
local W = 752
local ROLE_OPTIONS = { { "main", "Main (sammelt)" }, { "processor", "Verarbeiter & Bank" }, { "none", "Inaktiv" } }
local ROLE_ICON = {
  main = "Interface\\Icons\\INV_Misc_Bag_08", processor = "Interface\\Icons\\Trade_BlackSmithing",
  bank = "Interface\\Icons\\INV_Misc_Bag_10_Blue", none = "Interface\\Icons\\INV_Misc_QuestionMark",
}

UI.RegisterTab("team", "Team", function(frame)
  local content = { rows = {} }

  local list = UI.Inset(frame, W, 340)
  list:SetPoint("TOPLEFT", 0, 0)
  local listTitle = UI.Section(list, "DEIN TEAM", W - 20)
  listTitle:SetPoint("TOPLEFT", 10, -8)
  local hint = UI.Text(list, "Rollen werden automatisch vergeben (höchstes Level = Main, Handwerker = Verarbeiter & Bank). Eine Auswahl legt sie fest.", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 10, -26); hint:SetWidth(W - 20)

  local function row(i)
    if content.rows[i] then return content.rows[i] end
    local r = CreateFrame("Frame", nil, list)
    r:SetSize(W - 20, 48)
    r:SetPoint("TOPLEFT", 10, -44 - (i - 1) * 52)
    local line = r:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(1, 1, 1, 0.05)
    line:SetPoint("BOTTOMLEFT", 0, -2); line:SetPoint("BOTTOMRIGHT", 0, -2); line:SetHeight(1)
    r.icon = UI.ItemButton(r, 36)
    r.icon:SetPoint("LEFT", 0, 0)
    r.name = UI.Text(r, "", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -2)
    r.name:SetWidth(240)
    r.info = UI.Text(r, "", "GameFontDisableSmall")
    r.info:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.info:SetWidth(W - 20 - 44 - 200); r.info:SetWordWrap(false)
    r.role = UI.Dropdown(r, 180, ROLE_OPTIONS, function(role) if r.rec then Chars.SetRole(r.rec.name, role) end end)
    r.role:SetPoint("RIGHT", 0, 0)
    content.rows[i] = r
    return r
  end

  local status = UI.Inset(frame, W, 10)
  status:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)
  status:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  local statusTitle = UI.Section(status, "FUNKTIONSSTATUS", W - 20)
  statusTitle:SetPoint("TOPLEFT", 10, -8)
  local statusLines = UI.Lines(status, 4, W - 200, "GameFontHighlightSmall", -28, true)
  local settingsButton = UI.Button(status, "Einstellungen", 170, function() if ns.Settings then ns.Settings.Open() end end)
  settingsButton:SetPoint("TOPRIGHT", -10, -28)
  local reportButton = UI.Button(status, "Debug-Bericht", 170, function() ns.Debug.Run() end)
  reportButton:SetPoint("TOPRIGHT", settingsButton, "BOTTOMRIGHT", 0, -6)
  local backupButton = UI.Button(status, "Backup anlegen", 170, function() ns.DB.Backup("manuell"); ns.Print("Backup angelegt.") end)
  backupButton:SetPoint("TOPRIGHT", reportButton, "BOTTOMRIGHT", 0, -6)

  function content:Refresh()
    local all = Chars.All()
    for i, rec in ipairs(all) do
      if i > 6 then break end
      local r = row(i)
      r.rec = rec
      r:Show()
      r.icon:SetContent(ROLE_ICON[rec.role or "none"])
      local auto = rec.roleSource == "auto" and " |cff999999(automatisch)|r" or ""
      r.name:SetText(rec.name .. (rec.name == Chars.FullName() and " |cff80ff80(du)|r" or "") .. auto)
      local profs = {}
      for _, p in pairs(rec.professions or {}) do if not p.former then profs[#profs + 1] = (p.name or "?") .. " " .. tostring(p.rank or 0) end end
      table.sort(profs)
      r.info:SetText(("Level %s · %s · %s"):format(tostring(rec.level or "?"), rec.market or "?", #profs > 0 and table.concat(profs, ", ") or "keine Berufe"))
      r.role:SetValue(rec.role or "none")
    end
    for i = #all + 1, #content.rows do content.rows[i]:Hide() end

    local h = ns.Autopilot and ns.Autopilot.status.health
    local s = ns.Checks.Summary()
    local lines = {}
    if h then
      lines[#lines + 1] = h.red > 0 and { ("%d Funktion(en) eingeschränkt: %s"):format(h.red, h.rows[1] or "?"), 1, 0.5, 0.4 }
        or { "Selbstprüfung beim Login: alles in Ordnung.", 0.5, 1, 0.5 }
    else
      lines[#lines + 1] = { "Selbstprüfung läuft 15 Sekunden nach dem Login.", 0.8, 0.8, 0.8 }
    end
    lines[#lines + 1] = { ("Im Spiel bestätigt: %d von %d Funktionen (füllt sich beim normalen Spielen)."):format(s.pass, s.total), 0.85, 0.85, 0.85 }
    local ap = ns.Autopilot and ns.Autopilot.status or {}
    lines[#lines + 1] = { ("Berufe im Hintergrund gelesen: %d%s"):format(ap.books or 0, ap.blocked and " · vom Client blockiert" or ""), 0.7, 0.7, 0.7 }
    lines[#lines + 1] = { ("Backup: %s"):format(ns.DB.HasBackup() and (GoldweaverBackupDB.reason .. ", " .. date("%d.%m. %H:%M", GoldweaverBackupDB.when)) or "noch keins"), 0.7, 0.7, 0.7 }
    statusLines:Set(lines)
  end
  return content
end)

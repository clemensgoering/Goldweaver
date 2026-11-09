-- Goldweaver: automatic acceptance checks. Every roadmap/acceptance item is a check that passes by evidence from the
-- game (an event fired, a button worked, data arrived), never by hand. Pending checks carry a hint telling the player
-- what to do in game to trigger them. Status lives in GoldweaverDB.checks and shows in Heute and /gw debug run.
local ADDON, ns = ...

local Checks = { defs = {}, order = {} }
ns.Checks = Checks

function Checks.Define(id, def)
  if Checks.defs[id] then return end
  def.id = id
  Checks.defs[id] = def
  Checks.order[#Checks.order + 1] = id
end

local function store()
  ns.db.checks = ns.db.checks or {}
  return ns.db.checks
end

local function set(id, status, detail)
  if not Checks.defs[id] then return end
  local s = store()
  local prev = s[id]
  s[id] = { status = status, detail = detail, when = time() }
  if (not prev or prev.status ~= status) and status == "pass" then ns.Log("check passed", id, detail) end
  if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function Checks.Pass(id, detail) set(id, "pass", detail) end
function Checks.Fail(id, detail) set(id, "fail", detail) end
function Checks.Skip(id, detail) set(id, "skip", detail) end

function Checks.Get(id)
  local s = store()
  return s[id] or { status = "pending" }
end

-- Ordered status rows { id, title, status, detail, hint, when }
function Checks.Status()
  local rows = {}
  for _, id in ipairs(Checks.order) do
    local def = Checks.defs[id]
    local st = Checks.Get(id)
    rows[#rows + 1] = { id = id, title = def.title, status = st.status, detail = st.detail, hint = def.hint, when = st.when, group = def.group, action = def.action }
  end
  return rows
end

function Checks.Summary()
  local pass, fail, pending, skip = 0, 0, 0, 0
  for _, r in ipairs(Checks.Status()) do
    if r.status == "pass" then pass = pass + 1 elseif r.status == "fail" then fail = fail + 1 elseif r.status == "skip" then skip = skip + 1 else pending = pending + 1 end
  end
  return { pass = pass, fail = fail, pending = pending, skip = skip, total = #Checks.order }
end

-- Pending checks in order, for the Heute tab ("what to do next to complete the acceptance").
function Checks.NextPending(limit)
  local out = {}
  for _, r in ipairs(Checks.Status()) do
    if r.status == "pending" or r.status == "fail" then out[#out + 1] = r end
    if #out >= (limit or 2) then break end
  end
  return out
end

function Checks.Reset()
  ns.db.checks = {}
end

-- Definitions (group = Abnahme A / Fragen F / Roadmap B) ------------------------------------------
local D = Checks.Define
D("load", { group = "A", title = "Addon lädt ohne Fehler", hint = "Einloggen; Fehler erscheinen im Chat und im Bericht." })
D("interface", { group = "A", title = "Interface-Nummer passt zum Client", hint = "Automatisch beim Login." })
D("char", { group = "A", title = "Charakter registriert (Vorname Nachname, Markt-Key)", hint = "Automatisch beim Login." })
D("roles", { group = "A", title = "Rollen gesetzt: mindestens ein Main und ein Verarbeiter", hint = "Fenster → Charaktere, Rollen wählen." })
D("onboarding", { group = "A", title = "Erstlauf-Karte gezeigt oder übersprungen", hint = "Einen Charakter ohne Rolle einloggen." })
D("hud", { group = "A", title = "HUD-Zeile sichtbar auf dem Main", hint = "Mit dem Main einloggen (oder /gw hud on)." })
D("tooltip", { group = "A", title = "Tooltip-Zeile erscheint", hint = "Ein Item in der Tasche anschauen." })
D("stock", { group = "A", title = "Bestand über Bank/Twinks im Tooltip", hint = "Bank besuchen, dann ein Item ansehen, das auch dort liegt." })
D("mailButtons", { group = "A", title = "Briefkasten-Knöpfe erscheinen", hint = "Briefkasten öffnen." })
D("mailAttach", { group = "A", title = "Anhängen füllt Empfänger und Anhänge", hint = "Im Briefkasten 'Anhängen für …' klicken." })
D("mailSend", { group = "A", title = "Post an den Verarbeiter zugestellt (Empfängerformat bestätigt)", hint = "Nach dem Anhängen 'Senden an …' klicken." })
D("mailOpen", { group = "A", title = "Posteingang mit AH-Post geöffnet (Blizzard 'Alle öffnen'), Rechnungen erfasst", hint = "Nach einem Verkauf den Briefkasten öffnen und 'Alle öffnen' klicken." })
D("ledger", { group = "A", title = "Verkauf aus einer AH-Rechnung erfasst", hint = "Etwas im AH verkaufen, Post öffnen." })
D("book", { group = "A", title = "Rezeptbuch gelesen (C_TradeSkillUI)", hint = "Fenster → Berufe → 'Rezepte laden' (öffnet den Beruf per Knopf).",
  action = function() ns.UI.Open("berufe") end })
D("plan", { group = "A", title = "Skill-up-Plan mit Einkaufsliste berechnet", hint = "Beruf mit lernbaren Rezepten laden, dann Fenster → Berufe.",
  action = function() ns.UI.Open("berufe") end })
D("craft", { group = "A", title = "Herstellen über den Leitfaden-Knopf", hint = "Im Leitfaden 'Herstellen ×N' bei geladenem Beruf klicken.",
  action = function() ns.UI.Open("berufe") end })
D("disenchant", { group = "A", title = "Entzaubern über die Queue (Secure-Button)", hint = "/gw de auf dem Verzauberer, Knopf klicken.",
  action = function() if ns.Destroy then ns.Destroy.Show() end end })
D("ahObserve", { group = "A", title = "AH-Suchseite in die Preisdatenbank übernommen", hint = "Im AH nach einem Item suchen." })
D("ahSuggest", { group = "A", title = "Verkaufsvorschlag angezeigt und Preis vorbelegt", hint = "Ein Item in den Verkaufen-Tab legen." })
D("contacts", { group = "A", title = "Lehrer oder Händler aufgezeichnet", hint = "Einen Berufslehrer oder Händler ansprechen." })
D("selftest", { group = "A", title = "Debug-Bericht ohne rote Modulzeilen", hint = "/gw debug run.", action = function() if ns.Debug then ns.Debug.Run() end end })
-- open questions answered by observation
D("f6deposit", { group = "F", title = "F6 Einzahlungsformel aus echten Werten", hint = "Items in den Verkaufen-Tab legen (drei verschiedene genügen)." })
D("f7crate", { group = "F", title = "F7 Kisten-Bündel und Favor aus einem Kisten-Tooltip", hint = "Eine Waylaid Crate im Tooltip ansehen." })
D("f10mail", { group = "F", title = "F10 Post-Empfängerformat", hint = "Einmal über den Knopf an den Verarbeiter senden." })
D("f11skillup", { group = "F", title = "F11 Skill-up-Chancen aus eigenen Crafts (mind. 15)", hint = "Herstellen; das Addon zählt Crafts und Skill-ups je Farbe." })
D("recipeFields", { group = "F", title = "Rezeptfelder erkannt (Quelle, Anforderungen)", hint = "Ein Berufefenster öffnen." })
D("trainerRanks", { group = "F", title = "Rang-Anforderungen beim Lehrer gelesen", hint = "Einen Berufslehrer ansprechen." })
D("recipeSources", { group = "B", title = "Mindestens eine Rezeptquelle (Lehrer/Händler) zugeordnet", hint = "Lehrer oder Rezept-Händler besuchen." })
D("deObserved", { group = "B", title = "Entzauber-Ergebnis geloggt (Kalibrierung)", hint = "Einmal entzaubern." })

ns:RegisterModule("Checks", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function()
      C_Timer.After(6, function()
        if #ns.Health.errors == 0 then Checks.Pass("load", ns.version) else Checks.Fail("load", ns.Health.errors[1].where .. ": " .. ns.Health.errors[1].err) end
        local _, _, _, interface = GetBuildInfo()
        if interface == ns.INTERFACE then Checks.Pass("interface", tostring(interface)) else Checks.Fail("interface", ("Client %s, Addon %s"):format(tostring(interface), tostring(ns.INTERFACE))) end
      end)
    end, "Checks")
  end,
  SelfTest = function()
    local s = Checks.Summary()
    local rows = { { name = "Prüfungen", ok = s.fail == 0, warn = s.pending > 0, detail = ("%d bestanden, %d offen, %d fehlgeschlagen, %d übersprungen"):format(s.pass, s.pending, s.fail, s.skip) } }
    for _, r in ipairs(Checks.Status()) do
      if r.status == "fail" then rows[#rows + 1] = { name = r.title, ok = false, detail = r.detail } end
    end
    return rows
  end,
})

ns.Slash.Register("checks", function(arg)
  if arg == "reset" then Checks.Reset(); return ns.Print("Prüfungen zurückgesetzt") end
  for _, r in ipairs(Checks.Status()) do
    local mark = r.status == "pass" and "|cff7fd17f✓|r" or (r.status == "fail" and "|cffd9534f✗|r" or (r.status == "skip" and "|cff999999–|r" or "|cffffd27f…|r"))
    ns.Print(("%s %s%s"):format(mark, r.title, r.status == "pending" and (" → " .. (r.hint or "")) or (r.detail and (" (" .. tostring(r.detail) .. ")") or "")))
  end
  local s = Checks.Summary()
  ns.Print(("%d/%d bestanden"):format(s.pass, s.total))
end, "automatic acceptance checks (reset)")

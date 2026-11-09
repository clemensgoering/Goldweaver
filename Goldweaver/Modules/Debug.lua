-- Goldweaver: self test and debug report. /gw debug run executes every check that is possible right now
-- (client, APIs, features, data, each module's SelfTest, the probes whose window is open) and opens a window with
-- the full report in a text box: "Alles markieren" + Ctrl+C copies it for a bug report. The report is also stored in
-- GoldweaverDB.debug.report so it survives a /reload.
local ADDON, ns = ...
local L = ns.L

local Debug = {}
ns.Debug = Debug

local lines

local function add(fmt, ...)
  local text = select("#", ...) > 0 and fmt:format(...) or fmt
  lines[#lines + 1] = text
end

local function section(title)
  add("")
  add("== %s ==", title)
end

local function show(v)
  if ns.Secret.IsSecret(v) then return "<secret>" end
  if type(v) == "table" then return "<table>" end
  return tostring(v)
end

local function client()
  section(L["Client"])
  local version, build, dateStr, interface = GetBuildInfo()
  add(L["Version %s build %s (%s), Interface %s, addon for %s, WOW_PROJECT_ID %s"], show(version), show(build), show(dateStr), show(interface), ns.INTERFACE, show(WOW_PROJECT_ID))
  add(L["Addon version %s, schema %s, locale %s"], ns.version or "?", tostring(ns.db.schema), GetLocale and GetLocale() or "?")
  add(L["UI language %s (setting %s)"], tostring(ns.Locale and ns.Locale.active), tostring(ns.db.settings.language or "auto"))
  add(L["Character %s, market %s, role %s, level %s"], ns.Chars.FullName(), ns.Chars.MarketKey(), (ns.Chars.Current() or {}).role or "none", UnitLevel and tostring(UnitLevel("player")) or "?")
  add(L["Time %s"], date and date("%Y-%m-%d %H:%M:%S") or "?")
  if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
    local others = {}
    for i = 1, C_AddOns.GetNumAddOns() do
      local name, _, _, loadable = C_AddOns.GetAddOnInfo(i)
      if loadable and name ~= ADDON then others[#others + 1] = name end
    end
    add(L["Other loaded addons (%d): %s"], #others, table.concat(others, ", "))
  end
end

local function features()
  section(L["Features"])
  for _, row in ipairs(ns.Features.Status()) do
    add("[%s] %s (%s): %s", row.ok and "ok" or "--", L[row.label], row.name, row.detail)
  end
  local fails = {}
  for path, n in pairs(ns.API.failures) do fails[#fails + 1] = path .. " x" .. n end
  table.sort(fails)
  add(L["API failures: %s"], #fails > 0 and table.concat(fails, ", ") or L["none"])
end

local function modules()
  section(L["Modules"])
  local names = {}
  for name in pairs(ns.modules) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local m = ns.modules[name]
    if type(m.SelfTest) == "function" then
      local ok, results = pcall(m.SelfTest, m)
      if not ok then
        add(L["[!!] %s: SelfTest error: %s"], name, tostring(results))
      else
        for _, r in ipairs(results or {}) do
          add("[%s] %s: %s%s", r.ok and "ok" or (r.warn and "~~" or "--"), name, r.name, r.detail and (" - " .. tostring(r.detail)) or "")
        end
      end
    else
      add(L["[ok] %s: loaded"], name)
    end
  end
end

local function data()
  section(L["Data"])
  local s = ns.DB.Stats()
  add(L["Characters %d, recipe books %d, prices %d, contacts %d, vendor prices %d, stored errors %d"], s.chars, s.recipeBooks, s.prices, s.contacts, s.vendors, s.errors)
  for _, rec in ipairs(ns.Chars.All()) do
    local profs = {}
    for sl, p in pairs(rec.professions or {}) do
      profs[#profs + 1] = L["%s %s/%s (line %s, %s/%s recipes)"]:format(p.name or "?", tostring(p.rank), tostring(p.maxRank), tostring(sl), tostring(p.learnedCount or "?"), tostring(p.recipeCount or "?"))
    end
    add("  %s [%s] %s: %s", rec.name, rec.role or "none", rec.market or "?", #profs > 0 and table.concat(profs, "; ") or L["no professions"])
  end
  local settings = {}
  for k, v in pairs(ns.db.settings) do if type(v) ~= "table" then settings[#settings + 1] = k .. "=" .. tostring(v) end end
  table.sort(settings)
  add(L["Settings: %s"], table.concat(settings, ", "))
  add(L["Graph: %d conversions"], ns.Graph.Count())
  local sources = {}
  for _, src in ipairs(ns.Price.sources) do sources[#sources + 1] = src.name .. "@" .. src.priority end
  add(L["Price sources: %s"], table.concat(sources, ", "))
end

local function events()
  section(L["Events"])
  local rows = ns.Events:Summary()
  local parts = {}
  for _, r in ipairs(rows) do parts[#parts + 1] = r.event .. "(" .. r.handlers .. ")" end
  add(L["%d events registered: %s"], #rows, table.concat(parts, " "))
  add(L["Skipped by secret guard: %d"], ns.Events.skipped)
  add(L["Unknown events (rejected by the client): %s"], ns.Events.unknown and table.concat(ns.Events.unknown, ", ") or L["none"])
  add(L["Disabled handlers: %s"], #ns.Health.detached > 0 and table.concat(ns.Health.detached, ", ") or L["none"])
end

local function errors()
  section(L["Errors (last 30 of this session)"])
  if #ns.Health.errors == 0 then add(L["none"]) end
  for _, e in ipairs(ns.Health.errors) do add("%s %s: %s", date and date("%H:%M:%S", e.t) or "", e.where, e.err) end
end

local function probes()
  section(L["Probes (from GoldweaverDB.probe, executed only)"])
  local any = false
  for name, result in pairs(ns.db.probe or {}) do
    any = true
    local keys = {}
    for k, v in pairs(result) do
      if type(v) ~= "table" then keys[#keys + 1] = k .. "=" .. tostring(v) end
    end
    table.sort(keys)
    add("%s: %s", name, table.concat(keys, " "))
    if name == "general" and type(result.apis) == "table" then
      local missing = {}
      for path, ok in pairs(result.apis) do if not ok then missing[#missing + 1] = path end end
      table.sort(missing)
      add(L["  missing APIs: %s"], table.concat(missing, ", "))
    end
    if name == "profession" then
      for _, key in ipairs({ "learnedFields", "unlearnedFields", "schematicFields" }) do
        if type(result[key]) == "table" then
          local parts = {}
          for k, v in pairs(result[key]) do parts[#parts + 1] = k .. "=" .. tostring(v) end
          table.sort(parts)
          add("  %s: %s", key, table.concat(parts, " "))
        end
      end
    end
  end
  if not any then add(L["no probe run yet"]) end
end

local function context()
  section(L["Context-dependent checks"])
  local probe = ns.modules.Probe
  if probe then
    pcall(probe.General)
    add(L["General probe run."])
    if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() then
      pcall(probe.Profession); add(L["Profession window open: profession probe run."])
    else
      add(L["Profession window not open: profession probe skipped (open a profession and repeat /gw debug run)."])
    end
    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then pcall(probe.AuctionHouse); add(L["AH open: AH probe run (search sent)."]) else add(L["AH not open: AH probe skipped."]) end
    if MailFrame and MailFrame:IsShown() then pcall(probe.Mail); add(L["Mailbox open: mail probe run."]) else add(L["Mailbox not open: mail probe skipped."]) end
  end
end

local function diagnosis()
  section(L["Diagnosis (evaluated automatically)"])
  local findings = ns.Diagnose and ns.Diagnose.Run() or {}
  if #findings == 0 then add(L["no findings: all good"]) end
  for _, f in ipairs(findings) do
    add("[%s] %s%s – %s", f.severity, f.title, f.fixed and L[" (fixed automatically)"] or "", tostring(f.detail or ""))
  end
end

local function checks()
  section(L["Checks (automatic)"])
  local s = ns.Checks.Summary()
  add(L["%d passed, %d pending, %d failed, %d skipped (of %d)"], s.pass, s.pending, s.fail, s.skip, s.total)
  for _, r in ipairs(ns.Checks.Status()) do
    local mark = r.status == "pass" and "ok" or (r.status == "fail" and "!!" or (r.status == "skip" and "--" or ".."))
    add("[%s] %s %s%s", mark, r.group or "", L[r.title], r.status == "pending" and (" -> " .. L[r.hint or ""]) or (r.detail and (": " .. L[tostring(r.detail)]) or ""))
  end
end

local function learned()
  section(L["Learned from the game (open questions)"])
  for _, row in ipairs(ns.Learn.Status()) do add("%s: %s", row[1], row[2]) end
  local l = ns.db.learned or {}
  for itemID, crate in pairs(l.crates or {}) do
    add(L["Crate %s (%s): %s"], tostring(itemID), tostring(crate.name), table.concat(crate.lines or {}, " | "))
  end
  for npc, t in pairs(l.trainers or {}) do
    local parts = {}
    for _, r in ipairs(t.ranks or {}) do parts[#parts + 1] = L["%s (skill %s, level %s, %s)"]:format(r.name, tostring(r.skillReq), tostring(r.levelReq), ns.Util.Money(r.cost or 0)) end
    add(L["Trainer %s (line %s): %d services, ranks: %s"], npc, tostring(t.skillLine), #(t.services or {}), #parts > 0 and table.concat(parts, "; ") or "-")
  end
  if l.recipeFields then add(L["Schematic fields: %s"], table.concat(l.recipeFields.schematic or {}, ",")) end
  for name, tbl in pairs(l.enums or {}) do
    local parts = {}
    for k, v in pairs(tbl) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    add(L["Enum %s: %s"], name, table.concat(parts, " "))
  end
end

local function debugLog()
  section(L["Debug log (last 60 lines)"])
  local log = ns.db.debug and ns.db.debug.log or {}
  for i = math.max(1, #log - 59), #log do add("%s", log[i]) end
  if #log == 0 then add(L["empty"]) end
end

function Debug.Build()
  lines = {}
  add(L["Goldweaver debug report"])
  local steps = { client, diagnosis, checks, learned, features, modules, data, events, errors, context, probes, debugLog }
  for _, step in ipairs(steps) do
    local ok, err = pcall(step)
    if not ok then add(L["[!!] Report step failed: %s"], tostring(err)) end
  end
  -- the self test itself is a check: no red module lines
  local red = false
  for _, line in ipairs(lines) do if line:sub(1, 4) == "[--]" or line:sub(1, 4) == "[!!]" then red = true end end
  if ns.Checks then if red then ns.Checks.Fail("selftest", "red lines in the report") else ns.Checks.Pass("selftest", "no red lines") end end
  local report = table.concat(lines, "\n")
  ns.db.debug.report = report
  ns.db.debug.reportAt = time()
  return report
end

-- Report window -----------------------------------------------------------------------------
local win, box

local function createWindow()
  if win then return end
  win = CreateFrame("Frame", "GoldweaverDebugWindow", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(760, 520)
  win:SetPoint("CENTER")
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetFrameStrata("DIALOG")
  if win.TitleText then win.TitleText:SetText(L["Goldweaver debug report"]) end
  tinsert(UISpecialFrames, "GoldweaverDebugWindow")

  local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -60)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetFontObject("ChatFontSmall")
  box:SetWidth(700)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  scroll:SetScrollChild(box)

  local selectAll = ns.UI.Button(win, L["Select all (then Ctrl+C)"], 220, function()
    box:SetFocus()
    box:HighlightText()
  end)
  selectAll:SetPoint("TOPLEFT", 12, -30)
  local rerun = ns.UI.Button(win, L["Run again"], 140, function() Debug.Run() end)
  rerun:SetPoint("LEFT", selectAll, "RIGHT", 6, 0)
  local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", rerun, "RIGHT", 10, 0)
  hint:SetText(L["The report is also stored in SavedVariables (GoldweaverDB.debug.report)."])
end

function Debug.Show(text)
  createWindow()
  box:SetText(text or ns.db.debug.report or L["No report yet. /gw debug run"])
  win:Show()
end

function Debug.Run()
  local report = Debug.Build()
  Debug.Show(report)
  ns.Print((L["Debug report created: %d lines. In the window click 'Select all', then Ctrl+C."]):format(#lines))
end

ns:RegisterModule("Debug", {})

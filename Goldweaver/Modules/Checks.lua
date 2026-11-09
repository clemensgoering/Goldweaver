-- Goldweaver: automatic acceptance checks. Every roadmap/acceptance item is a check that passes by evidence from the
-- game (an event fired, a button worked, data arrived), never by hand. Pending checks carry a hint telling the player
-- what to do in game to trigger them. Status lives in GoldweaverDB.checks and shows in Heute and /gw debug run.
local ADDON, ns = ...
local L = ns.L

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
D("load", { group = "A", title = "Addon loads without errors", hint = "Log in; errors appear in chat and in the report." })
D("interface", { group = "A", title = "Interface number matches the client", hint = "Automatic at login." })
D("char", { group = "A", title = "Character registered (first name surname, market key)", hint = "Automatic at login." })
D("roles", { group = "A", title = "Roles set: at least one main and one processor", hint = "Window » Team, choose roles." })
D("onboarding", { group = "A", title = "First-run card shown or skipped", hint = "Log in a character without a role." })
D("hud", { group = "A", title = "HUD line visible on the main", hint = "Log in with the main (or /gw hud on)." })
D("tooltip", { group = "A", title = "Tooltip line appears", hint = "Look at an item in your bag." })
D("stock", { group = "A", title = "Stock across bank/alts in the tooltip", hint = "Visit the bank, then look at an item that is also stored there." })
D("mailButtons", { group = "A", title = "Mailbox buttons appear", hint = "Open the mailbox." })
D("mailAttach", { group = "A", title = "Attach fills recipient and attachments", hint = "In the mailbox click 'Attach for …'." })
D("coopGather", { group = "A", title = "Gathering for the twink is counted", hint = "As main, gather or loot something the twink needs; a short notice appears." })
D("mailSend", { group = "A", title = "Mail delivered to the processor (recipient format confirmed)", hint = "After attaching, click 'Send to …'." })
D("mailOpen", { group = "A", title = "Inbox with AH mail opened (Blizzard 'Open all'), invoices recorded", hint = "After a sale, open the mailbox and click 'Open all'." })
D("ledger", { group = "A", title = "Sale recorded from an AH invoice", hint = "Sell something at the AH, open the mail." })
D("book", { group = "A", title = "Recipe book read (C_TradeSkillUI)", hint = "Window » Professions » 'Load recipes' (opens the profession by button).",
  action = function() ns.UI.Open("berufe") end })
D("plan", { group = "A", title = "Skill-up plan with shopping list calculated", hint = "Load a profession with learnable recipes, then Window » Professions.",
  action = function() ns.UI.Open("berufe") end })
D("craft", { group = "A", title = "Crafting via the guide button", hint = "In the guide click 'Craft ×N' with a profession loaded.",
  action = function() ns.UI.Open("berufe") end })
D("disenchant", { group = "A", title = "Disenchanting via the queue (secure button)", hint = "/gw de on the enchanter, click the button.",
  action = function() if ns.Destroy then ns.Destroy.Show() end end })
D("ahObserve", { group = "A", title = "AH search page stored in the price database", hint = "Search for an item at the AH." })
D("ahSuggest", { group = "A", title = "Sell suggestion shown and price prefilled", hint = "Put an item into the Sell tab." })
D("contacts", { group = "A", title = "Trainer or vendor recorded", hint = "Talk to a profession trainer or vendor." })
D("selftest", { group = "A", title = "Debug report without red module lines", hint = "/gw debug run.", action = function() if ns.Debug then ns.Debug.Run() end end })
-- open questions answered by observation
D("f6deposit", { group = "F", title = "F6 Deposit formula from real values", hint = "Put items into the Sell tab (three different ones are enough)." })
D("f7crate", { group = "F", title = "F7 Crate bundles and favor from a crate tooltip", hint = "Look at a Waylaid Crate in the tooltip." })
D("f10mail", { group = "F", title = "F10 Mail recipient format", hint = "Send once to the processor via the button." })
D("f11skillup", { group = "F", title = "F11 Skill-up chances from own crafts (min. 15)", hint = "Craft; the addon counts crafts and skill-ups per colour." })
D("recipeFields", { group = "F", title = "Recipe fields detected (source, requirements)", hint = "Open a profession window." })
D("openRecipe", { group = "B", title = "Profession window opens on the recipe", hint = "In the guide click 'Open recipe' on a craft step." })
D("trainerRanks", { group = "F", title = "Rank requirements read from the trainer", hint = "Talk to a profession trainer." })
D("autoRead", { group = "B", title = "Professions read automatically in the background", hint = "Runs by itself at login (out of combat)." })
D("fieldZone", { group = "B", title = "Current zone detected (On the road)", hint = "Runs by itself." })
D("fieldObserve", { group = "B", title = "Gathering find assigned to a zone", hint = "Gather an herb, ore or leather." })
D("recipeSources", { group = "B", title = "At least one recipe source (trainer/vendor) assigned", hint = "Visit a trainer or recipe vendor." })
D("deObserved", { group = "B", title = "Disenchant result logged (calibration)", hint = "Disenchant once." })

ns:RegisterModule("Checks", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function()
      C_Timer.After(6, function()
        if #ns.Health.errors == 0 then Checks.Pass("load", ns.version) else Checks.Fail("load", ns.Health.errors[1].where .. ": " .. ns.Health.errors[1].err) end
        local _, _, _, interface = GetBuildInfo()
        if interface == ns.INTERFACE then Checks.Pass("interface", tostring(interface)) else Checks.Fail("interface", ("Client %s, addon %s"):format(tostring(interface), tostring(ns.INTERFACE))) end
      end)
    end, "Checks")
  end,
  SelfTest = function()
    local s = Checks.Summary()
    local rows = { { name = L["Checks"], ok = s.fail == 0, warn = s.pending > 0, detail = L["%d passed, %d pending, %d failed, %d skipped"]:format(s.pass, s.pending, s.fail, s.skip) } }
    for _, r in ipairs(Checks.Status()) do
      -- failed acceptance checks are hints (evidence from play), not runtime breakage: warn, never red
      if r.status == "fail" then rows[#rows + 1] = { name = L[r.title], ok = false, warn = true, detail = r.detail and L[r.detail] } end
    end
    return rows
  end,
})

ns.Slash.Register("checks", function(arg)
  if arg == "reset" then Checks.Reset(); return ns.Print(L["Checks reset"]) end
  for _, r in ipairs(Checks.Status()) do
    local mark = r.status == "pass" and "|cff7fd17f✓|r" or (r.status == "fail" and "|cffd9534f✗|r" or (r.status == "skip" and "|cff999999–|r" or "|cffffd27f…|r"))
    ns.Print(("%s %s%s"):format(mark, L[r.title], r.status == "pending" and (" » " .. L[r.hint or ""]) or (r.detail and (" (" .. L[tostring(r.detail)] .. ")") or "")))
  end
  local s = Checks.Summary()
  ns.Print((L["%d/%d passed"]):format(s.pass, s.total))
end, "automatic acceptance checks (reset)")

-- Goldweaver: mail pipeline. Rules decide which bag items travel to the processor; the mailbox gets ONE button
-- (docs/08-UX.md 4.3): "Anhängen" fills up to 12 attachments and the recipient, a second click "Senden" sends that
-- mail. Each click is one protected action (docs/04-COMPLIANCE.md). Forever's own inbox already has "Alle öffnen";
-- sales are recorded passively by Modules/Ledger.lua while the inbox is open.
--
-- Public API
--   ns.Mail.AddRule(name, fn, position?)   ★ routing rule, see below
--   ns.Mail.TargetFor(item) -> rec, reason  which processor gets an item and why (nil = stays)
--   ns.Mail.Plan() -> { [name] = { rec, items, value, count } }
--   ns.Mail.Pending() -> count, value, target
--   ns.Mail.Explain() -> { {item, target, reason} }   every bag item with its decision (for /gw mail)
local ADDON, ns = ...
local L = ns.L

local Mail = {}
ns.Mail = Mail

local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12

-- Item class / subclass constants (Mainline numbering, verified by GetItemInfoInstant on Forever items)
local CLASS_WEAPON, CLASS_ARMOR, CLASS_TRADEGOODS, CLASS_RECIPE = 2, 4, 7, 9
-- tradegoods subclass -> skill lines that use it
local TRADEGOOD_USERS = {
  [5] = { 197, 129 },        -- Cloth: Tailoring, First Aid
  [6] = { 165 },             -- Leather: Leatherworking
  [7] = { 164, 202, 186 },   -- Metal & Stone: Blacksmithing, Engineering, Mining
  [8] = { 185 },             -- Cooking
  [9] = { 171 },             -- Herb: Alchemy
  [12] = { 333 },            -- Enchanting
  [1] = { 202 },             -- Parts: Engineering
  [10] = { 164, 165, 197, 171, 202, 333 }, -- Elemental: any crafter
  [11] = { 164, 165, 197, 171, 202, 333, 185, 129 }, -- Other
}
-- Enum.ItemRecipeSubclass (verified on Forever): Leatherworking=1 Tailoring=2 Engineering=3 Blacksmithing=4 Cooking=5
-- Alchemy=6 FirstAid=7 Enchanting=8 Fishing=9
local RECIPE_USERS = { [1] = 165, [2] = 197, [3] = 202, [4] = 164, [5] = 185, [6] = 171, [7] = 129, [8] = 333, [9] = 356 }
local ENCHANTING = 333

local function hasAny(rec, skillLines)
  if not (rec and rec.professions) then return false end
  for _, sl in ipairs(skillLines) do if rec.professions[sl] and not rec.professions[sl].former then return true end end
  return false
end

local function processors()
  return ns.Chars.ByRole("processor", ns.Chars.MarketKey())
end

-- Routing rules ------------------------------------------------------------------------------------
-- Extension point: Mail.AddRule(name, fn) where fn(item, info, me, processors) returns
--   target rec, reason   -> send to that processor
--   false, reason        -> keep here (decided)
--   nil                  -> rule does not apply, try the next one
-- item = { itemID, quality, isBound }; info = { classID, subclassID } from GetItemInfoInstant.
Mail.rules = {}

function Mail.AddRule(name, fn, position)
  local rule = { name = name, fn = fn }
  if position then table.insert(Mail.rules, position, rule) else Mail.rules[#Mail.rules + 1] = rule end
end

Mail.AddRule("bound", function(item) if item.isBound then return false, L["bound"] end end)
Mail.AddRule("grey", function(item) if (item.quality or 1) == 0 then return false, L["vendor"] end end)

Mail.AddRule("tradegoods", function(_, info, me, list)
  if info.classID ~= CLASS_TRADEGOODS then return nil end
  local users = TRADEGOOD_USERS[info.subclassID] or {}
  if ns.db.settings.keepOwnMaterials ~= false and hasAny(me, users) then return false, L["own profession"] end
  for _, rec in ipairs(list) do if hasAny(rec, users) then return rec, (L["Material for %s"]):format(rec.name) end end
  return list[1], L["Material"]
end)

Mail.AddRule("recipes", function(_, info, me, list)
  if info.classID ~= CLASS_RECIPE then return nil end
  local sl = RECIPE_USERS[info.subclassID]
  if sl and me.professions and me.professions[sl] then return false, L["own profession"] end
  for _, rec in ipairs(list) do if sl and rec.professions and rec.professions[sl] then return rec, (L["Recipe for %s"]):format(rec.name) end end
  return list[1], L["Recipe"]
end)

Mail.AddRule("gear", function(item, info, me, list)
  if not ((info.classID == CLASS_WEAPON or info.classID == CLASS_ARMOR) and (item.quality or 1) >= 2) then return nil end
  if me.professions and me.professions[ENCHANTING] then return false, L["disenchant it yourself"] end
  for _, rec in ipairs(list) do if rec.professions and rec.professions[ENCHANTING] then return rec, (L["disenchant at %s"]):format(rec.name) end end
  return false, L["sell it yourself"]
end)

-- Which processor should receive an item and why. Returns rec, reason or nil, reason.
function Mail.TargetFor(item)
  local me = ns.Chars.Current()
  if not me or me.role == "processor" then return nil, L["process here"] end
  local instant = ns.API.ItemInfoInstant(item.itemID)
  if not instant then return nil, L["item data missing"] end
  local list = processors()
  if #list == 0 then return nil, L["no processor"] end
  for _, rule in ipairs(Mail.rules) do
    local ok, target, reason = pcall(rule.fn, item, instant, me, list)
    if not ok then
      ns.Health.Record("mail rule " .. rule.name, target)
    elseif target then
      return target, reason
    elseif target == false then
      return nil, reason
    end
  end
  return nil, L["no rule"]
end

-- Items in bags that should travel, grouped by target. Returns { [targetName] = { rec, items = {...}, value } }.
function Mail.Plan()
  local plan = {}
  for _, it in ipairs(ns.Inventory.BagItems()) do
    if not it.isLocked then
      local target, reason = Mail.TargetFor(it)
      if target then
        local p = plan[target.name] or { rec = target, items = {}, value = 0, count = 0 }
        it.reason = reason
        local price = ns.Price.Copper(it.itemID)
        it.value = price and price * it.count or 0
        p.value = p.value + it.value
        p.count = p.count + 1
        p.items[#p.items + 1] = it
        plan[target.name] = p
      end
    end
  end
  return plan
end

-- Every bag item with its decision, for /gw mail and the debug report.
function Mail.Explain()
  local out = {}
  for _, it in ipairs(ns.Inventory.BagItems()) do
    local target, reason = Mail.TargetFor(it)
    out[#out + 1] = { item = it, target = target, reason = reason }
  end
  return out
end

-- Flat list for the HUD: count and value of everything that should travel.
function Mail.Pending()
  local count, value, target = 0, 0, nil
  for _, p in pairs(Mail.Plan()) do
    count = count + p.count
    value = value + p.value
    target = target or p.rec
  end
  return count, value, target
end

-- Mailbox UI -----------------------------------------------------------------------------------
local sendButton, attached, pendingSend

local function countAttachments()
  local n = 0
  if GetSendMailItem then
    for i = 1, MAX_ATTACH do if GetSendMailItem(i) then n = n + 1 end end
  end
  return n
end

local function refreshSendButton()
  if not sendButton then return end
  local me = ns.Chars.Current()
  if not me or me.role == "processor" or me.role == "bank" then sendButton:Hide(); return end
  -- Attached items have left the bags, so the plan no longer contains them: while a mail is filled, the button
  -- keeps pointing at the target it was filled for (bug found by tools/tests/sim.lua, 09.11.2026).
  if attached and attached > 0 and sendButton.plan then
    local rec = sendButton.plan.rec
    sendButton:SetText((L["Send to %s (%d attachments)"]):format(rec.firstName or rec.name, attached))
    sendButton:Enable(); sendButton:Show()
    return
  end
  local plan = Mail.Plan()
  local first
  for _, p in pairs(plan) do if not first or p.value > first.value then first = p end end
  if not first then
    sendButton:SetText(L["Nothing to send (/gw mail shows why)"])
    sendButton:Disable(); sendButton:Show(); return
  end
  sendButton.plan = first
  sendButton:Enable(); sendButton:Show()
  if attached and attached > 0 then
    sendButton:SetText((L["Send to %s (%d attachments)"]):format(first.rec.firstName or first.rec.name, attached))
  else
    local n = math.min(MAX_ATTACH, #first.items)
    sendButton:SetText((L["Attach for %s: %d of %d (%s)"]):format(first.rec.firstName or first.rec.name, n, first.count, ns.Util.Money(first.value)))
  end
end

local function onSendClick()
  local p = sendButton.plan
  if not p then return end
  attached = countAttachments()
  if attached > 0 then
    -- second click: send this one mail
    local recipient = ns.Chars.MailName(p.rec)
    local variant = (ns.Learn and ns.Learn.MailVariant()) or "full"
    if SendMailNameEditBox then SendMailNameEditBox:SetText(recipient) end
    local subject = (L["Goldweaver: %d items"]):format(attached)
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(subject) end
    pendingSend = { variant = variant, recipient = recipient, t = GetTime() }
    local ok, err = pcall(SendMail, recipient, subject, "")
    if not ok then ns.Print((L["Sending failed: %s"]):format(tostring(err))); pendingSend = nil end
    return
  end
  -- first click: switch to the send tab, fill recipient and attach up to 12 items
  if MailFrameTab2 and MailFrameTab2.Click then MailFrameTab2:Click() end
  if SendMailNameEditBox then SendMailNameEditBox:SetText(ns.Chars.MailName(p.rec)) end
  local n = 0
  for _, it in ipairs(p.items) do
    if n >= MAX_ATTACH then break end
    if not it.isLocked and ns.API.UseContainerItem(it.bag, it.slot) then n = n + 1 end
  end
  C_Timer.After(0.2, function()
    attached = countAttachments()
    refreshSendButton()
    if attached > 0 and ns.Checks then ns.Checks.Pass("mailAttach", attached .. " attachments") end
  end)
end

local function createButton()
  if sendButton or not MailFrame then return end
  sendButton = ns.UI.Button(MailFrame, "", 300, onSendClick)
  sendButton:SetPoint("TOP", MailFrame, "BOTTOM", 0, -4)
  sendButton:SetFrameStrata("HIGH")
  local width = MailFrame:GetWidth()
  if width and width > 100 then sendButton:SetWidth(width - 40) end
end

ns:RegisterModule("Mail", {
  SelfTest = function()
    local plan = Mail.Plan()
    local targets, items = 0, 0
    for _, p in pairs(plan) do targets = targets + 1; items = items + p.count end
    local explained = Mail.Explain()
    local first = explained[1]
    return {
      { name = L["Send plan"], ok = true, detail = L["%d target(s), %d item(s) of %d in the bags"]:format(targets, items, #explained) },
      { name = L["Rule check first bag item"], ok = first ~= nil, warn = true,
        detail = first and ("%s -> %s (%s)"):format(tostring(first.item.itemID), first.target and first.target.name or L["stays"], tostring(first.reason)) or L["bags empty"] },
      { name = L["Mailbox button created"], ok = sendButton ~= nil, warn = true, detail = sendButton and L["yes"] or L["only after the first opening"] },
      { name = L["Rules"], ok = #Mail.rules >= 5, detail = (function() local t = {} for _, r in ipairs(Mail.rules) do t[#t + 1] = r.name end return table.concat(t, ", ") end)() },
    }
  end,
  Init = function()
    ns.Events:On("MAIL_SHOW", function()
      createButton()
      attached = 0
      refreshSendButton()
      if sendButton and ns.Checks then ns.Checks.Pass("mailButtons", "created") end
    end, "Mail")
    ns.Events:On("MAIL_CLOSED", function() attached = 0; pendingSend = nil end, "Mail")
    ns.Events:On("MAIL_SEND_SUCCESS", function()
      attached = 0
      if pendingSend and ns.Learn then ns.Learn.MailResult(pendingSend.variant, true) end
      pendingSend = nil
      C_Timer.After(0.5, refreshSendButton)
    end, "Mail")
    -- the server rejects unknown recipients with a UI error; learn the format and switch for the next try
    ns.Events:On("UI_ERROR_MESSAGE", function(_, _, message)
      if not pendingSend or type(message) ~= "string" then return end
      local notFound = ERR_MAIL_TARGET_NOT_FOUND and message == ERR_MAIL_TARGET_NOT_FOUND
      if notFound or message:find("not found") or message:find("nicht gefunden") then -- locale-ok: German client error text
        if ns.Learn then ns.Learn.MailResult(pendingSend.variant, false) end
        ns.Print((L["Recipient '%s' not found; the next attempt uses %s."]):format(pendingSend.recipient, pendingSend.variant == "full" and L["first name only"] or L["first name + surname"]))
        pendingSend = nil
      end
    end, "Mail")
    ns.Events:On("MAIL_SEND_INFO_UPDATE", function() attached = countAttachments(); refreshSendButton() end, "Mail")
    ns.Events:On("BAG_UPDATE_DELAYED", function() if MailFrame and MailFrame:IsShown() then C_Timer.After(0.5, refreshSendButton) end end, "Mail")
  end,
})

ns.Slash.Register("mail", function()
  local explained = Mail.Explain()
  if #explained == 0 then return ns.Print(L["Bags are empty."]) end
  local byReason = {}
  for _, e in ipairs(explained) do
    if e.target then
      ns.Print(("» %s: %s x%d (%s)"):format(e.target.firstName or e.target.name, e.item.link or tostring(e.item.itemID), e.item.count, e.reason or ""))
    else
      byReason[e.reason or "?"] = (byReason[e.reason or "?"] or 0) + 1
    end
  end
  for reason, n in pairs(byReason) do ns.Print((L["stays: %d item(s), reason: %s"]):format(n, reason)) end
end, "show what would be mailed and why the rest stays")

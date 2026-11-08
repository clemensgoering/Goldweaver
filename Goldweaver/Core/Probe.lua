-- Goldweaver: in-game API probe for Phase 0. Answers the open questions F1-F11 in docs/02-ROADMAP.md.
-- Usage: /gw probe            general client, identity and API availability
--        /gw probe items      resolve the item IDs used in Data/ to names (catches wrong IDs)
--        /gw probe prof       inside an open profession window: which tradeskill API answers and what a recipe looks like
--        /gw probe ah         at the auction house: throttle state, durations, one timed search
--        /gw probe replicate  at the auction house: ONE ReplicateItems attempt (explicit, never automatic)
--        /gw probe mail       at the mailbox: header and invoice fields of the first mail
--        /gw probe secure     outside combat: create a SecureActionButton with macrotext and report errors
-- Results are printed and stored in GoldweaverDB.probe[<section>] so they can be copied from SavedVariables.
local ADDON, ns = ...

local Probe = ns:RegisterModule("Probe", {})
local Secret = ns.Secret

local function store(section, tbl)
  ns.db.probe[section] = tbl
  tbl.when = date and date("%Y-%m-%d %H:%M") or "?"
end

local function show(v)
  if Secret.IsSecret(v) then return "<secret>" end
  if type(v) == "table" then return "<table>" end
  return tostring(v)
end

local function has(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    cur = type(cur) == "table" and cur[part] or nil
    if cur == nil then return false end
  end
  return true
end

local function report(section, lines)
  ns.Print("probe " .. section .. ":")
  for _, line in ipairs(lines) do ns.Print("  " .. line) end
end

local API_CHECKS = {
  -- items / bags / tooltip
  "C_Item.GetItemInfo", "C_Item.GetItemInfoInstant", "C_Item.RequestLoadItemDataByID", "C_Item.GetItemCount",
  "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Container.UseContainerItem",
  "C_TooltipInfo.GetBagItem", "C_TooltipInfo.GetItemByID", "TooltipDataProcessor.AddTooltipPostCall",
  -- professions
  "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetRecipeSchematic",
  "C_TradeSkillUI.GetProfessionInfoBySkillLineID", "C_TradeSkillUI.GetRecipeTools", "C_TradeSkillUI.CraftRecipe",
  "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.GetChildProfessionInfo", "C_TradeSkillUI.OpenTradeSkill",
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillReagentInfo", "DoTradeSkill",
  "GetNumCrafts", "GetCraftInfo", "GetCraftReagentInfo", "DoCraft",
  "GetProfessions", "GetProfessionInfo",
  -- auction house
  "C_AuctionHouse.SendBrowseQuery", "C_AuctionHouse.SendSearchQuery", "C_AuctionHouse.ReplicateItems",
  "C_AuctionHouse.GetNumReplicateItems", "C_AuctionHouse.GetReplicateItemInfo", "C_AuctionHouse.IsThrottledMessageSystemReady",
  "C_AuctionHouse.GetCommoditySearchResultInfo", "C_AuctionHouse.GetItemSearchResultInfo", "C_AuctionHouse.GetOwnedAuctions",
  "C_AuctionHouse.PostCommodity", "C_AuctionHouse.PostItem", "C_AuctionHouse.CalculateCommodityDeposit", "C_AuctionHouse.CalculateItemDeposit",
  -- mail
  "SendMail", "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxInvoiceInfo", "TakeInboxItem", "AutoLootMailItem", "C_Mail.IsCommandPending",
  -- identity / misc
  "UnitFullName", "GetNormalizedRealmName", "GetRealmName", "GetAutoCompleteRealms", "UnitFactionGroup", "issecretvalue",
  "C_RestrictedActions.IsRestricted", "C_ChatInfo.InChatMessagingLockdown",
  -- optional addons
  "Auctionator.API.v1.GetAuctionPriceByItemID", "Auctionator.API.v1.GetDisenchantPriceByItemID", "Auctionator.API.v1.RegisterForDBUpdate",
  "TSM_API.GetCustomPriceValue", "Syndicator.API.GetInventoryInfoByItemID", "GatherMate2.gmdbs",
}

function Probe.General()
  local version, build, dateStr, tocversion = GetBuildInfo()
  local lines = {}
  local result = { apis = {} }
  result.version, result.build, result.date, result.interface = version, build, dateStr, tocversion
  result.project = WOW_PROJECT_ID
  lines[#lines + 1] = ("client %s (%s, %s) interface %s project %s"):format(show(version), show(build), show(dateStr), show(tocversion), show(WOW_PROJECT_ID))

  local name, realm = UnitFullName("player")
  result.name, result.realm = show(name), show(realm)
  result.normalizedRealm = GetNormalizedRealmName and show(GetNormalizedRealmName()) or "n/a"
  result.realmName = GetRealmName and show(GetRealmName()) or "n/a"
  result.faction = show((UnitFactionGroup("player")))
  lines[#lines + 1] = ("name=%s realm=%s normalized=%s realmName=%s faction=%s"):format(result.name, result.realm, result.normalizedRealm, result.realmName, result.faction)
  if GetAutoCompleteRealms then
    local realms = GetAutoCompleteRealms()
    result.autoCompleteRealms = type(realms) == "table" and #realms or show(realms)
    lines[#lines + 1] = "autoCompleteRealms=" .. tostring(result.autoCompleteRealms)
  end

  local missing = {}
  for _, path in ipairs(API_CHECKS) do
    local ok = has(path)
    result.apis[path] = ok
    if not ok then missing[#missing + 1] = path end
  end
  lines[#lines + 1] = ("%d APIs checked, %d missing: %s"):format(#API_CHECKS, #missing, table.concat(missing, ", "))
  if GetProfessions then
    local p1, p2, arch, fish, cook, aid = GetProfessions()
    local profs = {}
    for _, idx in ipairs({ p1, p2, arch, fish, cook, aid }) do
      if idx and GetProfessionInfo then
        local pname, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
        profs[#profs + 1] = ("%s %s/%s (line %s)"):format(show(pname), show(rank), show(maxRank), show(skillLine))
      end
    end
    result.professions = profs
    lines[#lines + 1] = "professions: " .. table.concat(profs, "; ")
  end
  store("general", result)
  report("general", lines)
end

function Probe.Items()
  if not ns.Data or not ns.Data.AllItemIDs then return ns.Print("probe items: ns.Data not loaded") end
  local ids = ns.Data.AllItemIDs()
  local result, lines, pending = {}, {}, 0
  for _, id in ipairs(ids) do
    local itemName = C_Item.GetItemInfo(id)
    if itemName then
      result[id] = itemName
    else
      pending = pending + 1
      C_Item.RequestLoadItemDataByID(id)
    end
  end
  lines[#lines + 1] = ("%d ids, %d resolved now, %d requested from server (run again in a few seconds)"):format(#ids, #ids - pending, pending)
  -- Expected names are English; a name comparison is only meaningful on an enUS client. Elsewhere list the
  -- resolved names so they can be checked by eye (verified 08.11.2026 on deDE: all IDs correct).
  local english = GetLocale and GetLocale() == "enUS"
  local shown = 0
  for _, id in ipairs(ids) do
    local expected = ns.Data.ExpectedName and ns.Data.ExpectedName(id)
    local got = result[id]
    if got and expected then
      if english and got ~= expected then
        lines[#lines + 1] = ("MISMATCH %d: expected %s, got %s"):format(id, expected, got)
      elseif not english and shown < 12 then
        shown = shown + 1
        lines[#lines + 1] = ("%d: %s = %s"):format(id, expected, got)
      end
    end
  end
  if not english and shown == 12 then lines[#lines + 1] = "... (full list in GoldweaverDB.probe.items)" end
  store("items", result)
  report("items", lines)
end

local waitingForTradeSkill = false

function Probe.Profession()
  local lines, result = {}, {}
  if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
    local ids = C_TradeSkillUI.GetAllRecipeIDs()
    result.modernCount = type(ids) == "table" and #ids or 0
    lines[#lines + 1] = "C_TradeSkillUI.GetAllRecipeIDs: " .. tostring(result.modernCount)
    if result.modernCount == 0 and not waitingForTradeSkill then
      -- Verified 08.11.2026: the list is empty until ONE profession is opened (not just the professions book).
      waitingForTradeSkill = true
      local function onList()
        waitingForTradeSkill = false
        ns.Events:Off("TRADE_SKILL_LIST_UPDATE", onList)
        ns.Print("probe prof: profession window detected, dumping")
        Probe.Profession()
      end
      ns.Events:On("TRADE_SKILL_LIST_UPDATE", onList)
      ns.Print("probe prof: no recipes loaded. Open one profession (click it in the professions book); the dump runs automatically.")
      return
    end
    if C_TradeSkillUI.GetBaseProfessionInfo then
      local info = C_TradeSkillUI.GetBaseProfessionInfo()
      if type(info) == "table" then
        result.base = {}
        for k, v in pairs(info) do result.base[k] = show(v) end
        lines[#lines + 1] = ("base profession: %s skill %s/%s line %s"):format(show(info.professionName), show(info.skillLevel), show(info.maxSkillLevel), show(info.professionID))
      end
    end
    local first = type(ids) == "table" and ids[1]
    if first and C_TradeSkillUI.GetRecipeInfo then
      -- dump one learned and one unlearned recipe with ALL fields (to find source/skill requirement fields)
      local learnedID, unlearnedID
      for _, id in ipairs(ids) do
        local okI, inf = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if okI and type(inf) == "table" then
          if inf.learned and not learnedID then learnedID = id end
          if not inf.learned and not unlearnedID then unlearnedID = id end
        end
        if learnedID and unlearnedID then break end
      end
      for label, id in pairs({ learned = learnedID, unlearned = unlearnedID }) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if type(info) == "table" then
          result[label .. "Fields"] = {}
          local parts = {}
          for k, v in pairs(info) do result[label .. "Fields"][k] = show(v); parts[#parts + 1] = k .. "=" .. show(v) end
          table.sort(parts)
          lines[#lines + 1] = ("%s recipe %s: %s"):format(label, show(id), table.concat(parts, " "))
        end
        if C_TradeSkillUI.GetRecipeRequirements then
          local okR, req = pcall(C_TradeSkillUI.GetRecipeRequirements, id)
          if okR and type(req) == "table" then
            local parts = {}
            for _, r in ipairs(req) do parts[#parts + 1] = show(r.name) .. "(" .. show(r.type) .. "," .. show(r.met) .. ")" end
            lines[#lines + 1] = ("%s requirements: %s"):format(label, table.concat(parts, " "))
          end
        end
        if C_TradeSkillUI.GetRecipeDescription then
          local okD, desc = pcall(C_TradeSkillUI.GetRecipeDescription, id, {})
          if okD and desc then lines[#lines + 1] = ("%s description: %s"):format(label, show(desc)) end
        end
      end
      local info = C_TradeSkillUI.GetRecipeInfo(first)
      if type(info) == "table" then
        lines[#lines + 1] = ("recipe %s: %s difficulty=%s learned=%s"):format(show(first), show(info.name), show(info.difficulty or info.relativeDifficulty), show(info.learned))
      end
      if C_TradeSkillUI.GetRecipeSchematic then
        local ok, schem = pcall(C_TradeSkillUI.GetRecipeSchematic, first, false)
        if ok and type(schem) == "table" then
          result.schematicFields = {}
          for k, v in pairs(schem) do result.schematicFields[k] = show(v) end
          local slots = type(schem.reagentSlotSchematics) == "table" and #schem.reagentSlotSchematics or 0
          lines[#lines + 1] = ("schematic: %d reagent slots, quantityMin=%s quantityMax=%s"):format(slots, show(schem.quantityMin), show(schem.quantityMax))
        else
          lines[#lines + 1] = "GetRecipeSchematic failed: " .. tostring(schem)
        end
      end
    end
  else
    lines[#lines + 1] = "C_TradeSkillUI.GetAllRecipeIDs missing"
  end
  if GetNumTradeSkills then
    local n = GetNumTradeSkills()
    result.legacyTradeSkills = n
    lines[#lines + 1] = "GetNumTradeSkills: " .. tostring(n)
    if n and n > 0 and GetTradeSkillInfo then
      for i = 1, math.min(n, 3) do
        local sname, stype = GetTradeSkillInfo(i)
        lines[#lines + 1] = ("  legacy[%d] %s (%s)"):format(i, show(sname), show(stype))
      end
    end
  end
  if GetNumCrafts then
    local n = GetNumCrafts()
    result.legacyCrafts = n
    lines[#lines + 1] = "GetNumCrafts: " .. tostring(n)
    if n and n > 0 and GetCraftInfo then
      local cname, _, ctype = GetCraftInfo(1)
      lines[#lines + 1] = ("  craft[1] %s (%s)"):format(show(cname), show(ctype))
    end
  end
  store("profession", result)
  report("profession", lines)
end

function Probe.AuctionHouse()
  local lines, result = {}, {}
  if not C_AuctionHouse then return ns.Print("probe ah: C_AuctionHouse missing") end
  result.throttleReady = C_AuctionHouse.IsThrottledMessageSystemReady and C_AuctionHouse.IsThrottledMessageSystemReady()
  lines[#lines + 1] = "IsThrottledMessageSystemReady: " .. tostring(result.throttleReady)
  if Enum and Enum.AuctionHouseTimeLeftBand then
    result.timeLeftBands = {}
    for k, v in pairs(Enum.AuctionHouseTimeLeftBand) do result.timeLeftBands[k] = v end
    lines[#lines + 1] = "time left bands: " .. (function() local t = {} for k, v in pairs(result.timeLeftBands) do t[#t + 1] = k .. "=" .. tostring(v) end return table.concat(t, " ") end)()
  end
  result.durations = { AUCTION_DURATION_ONE = _G.AUCTION_DURATION_ONE, AUCTION_DURATION_TWO = _G.AUCTION_DURATION_TWO, AUCTION_DURATION_THREE = _G.AUCTION_DURATION_THREE }
  lines[#lines + 1] = ("duration labels: %s / %s / %s"):format(show(result.durations.AUCTION_DURATION_ONE), show(result.durations.AUCTION_DURATION_TWO), show(result.durations.AUCTION_DURATION_THREE))
  if C_AuctionHouse.CalculateCommodityDeposit then
    -- Linen Cloth, 1 unit, each duration index 1..3
    for d = 1, 3 do
      local ok, dep = pcall(C_AuctionHouse.CalculateCommodityDeposit, 2589, d, 1)
      result["depositLinen" .. d] = ok and dep or ("err " .. tostring(dep))
      lines[#lines + 1] = ("deposit 1x Linen Cloth, duration %d: %s"):format(d, show(result["depositLinen" .. d]))
    end
  end
  -- one timed search, Linen Cloth, only if the throttle is ready
  if result.throttleReady and C_AuctionHouse.SendSearchQuery then
    local t0 = GetTime()
    local function onResults(_, itemID)
      if itemID ~= 2589 then return end
      result.searchMs = math.floor((GetTime() - t0) * 1000)
      local n = C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(2589) or "?"
      result.searchResults = n
      ns.Print(("probe ah: search answered after %d ms with %s results"):format(result.searchMs, tostring(n)))
      ns.Events:Off("COMMODITY_SEARCH_RESULTS_UPDATED", onResults)
    end
    ns.Events:On("COMMODITY_SEARCH_RESULTS_UPDATED", onResults)
    local ok, err = pcall(C_AuctionHouse.SendSearchQuery, { itemID = 2589 }, {}, false)
    lines[#lines + 1] = "SendSearchQuery(Linen Cloth): " .. (ok and "sent" or ("error " .. tostring(err)))
  end
  store("ah", result)
  report("ah", lines)
end

function Probe.Replicate()
  if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems) then return ns.Print("probe replicate: ReplicateItems missing") end
  local result = { startedAt = time(), startedClock = date("%H:%M:%S") }
  local t0 = GetTime()
  local function onReplicate()
    result.answeredMs = math.floor((GetTime() - t0) * 1000)
    result.count = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or "?"
    if type(result.count) == "number" and result.count > 0 and C_AuctionHouse.GetReplicateItemInfo then
      local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID, hasAllInfo = C_AuctionHouse.GetReplicateItemInfo(0)
      -- privacy: never store other players' names, only whether the field is filled
      result.sample = { name = show(name), count = show(count), buyout = show(buyout), ownerPresent = (owner ~= nil), itemID = show(itemID), hasAllInfo = show(hasAllInfo) }
    end
    ns.Print(("probe replicate: %s items after %d ms"):format(tostring(result.count), result.answeredMs))
    store("replicate", result)
    ns.Events:Off("REPLICATE_ITEM_LIST_UPDATE", onReplicate)
  end
  ns.Events:On("REPLICATE_ITEM_LIST_UPDATE", onReplicate)
  result.throttleReady = C_AuctionHouse.IsThrottledMessageSystemReady and C_AuctionHouse.IsThrottledMessageSystemReady()
  local ok, err = pcall(C_AuctionHouse.ReplicateItems)
  result.callOk, result.callErr = ok, err and tostring(err) or nil
  store("replicate", result)
  ns.Print("probe replicate: call " .. (ok and "sent, waiting for REPLICATE_ITEM_LIST_UPDATE" or ("failed: " .. tostring(err))) .. " (throttle ready: " .. tostring(result.throttleReady) .. ")")
  -- Run 1: no event within the time the player waited. Check-ins only READ the local count; nothing is re-sent.
  for _, delay in ipairs({ 15, 45, 90 }) do
    C_Timer.After(delay, function()
      if result.answeredMs then return end
      local n = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or "?"
      local open = AuctionHouseFrame and AuctionHouseFrame:IsShown()
      result["checkAt" .. delay] = { count = n, ahOpen = open }
      store("replicate", result)
      ns.Print(("probe replicate: after %d s no event yet; GetNumReplicateItems=%s, AH open=%s"):format(delay, tostring(n), tostring(open)))
    end)
  end
end

function Probe.Mail()
  local lines, result = {}, {}
  if not GetInboxNumItems then return ns.Print("probe mail: inbox API missing") end
  local n, total = GetInboxNumItems()
  result.inbox, result.total = n, total
  lines[#lines + 1] = ("inbox %s shown / %s total"):format(show(n), show(total))
  if n and n > 0 then
    local h = { GetInboxHeaderInfo(1) }
    result.header = {}
    for i, v in ipairs(h) do result.header[i] = show(v) end
    lines[#lines + 1] = ("header[1]: sender=%s subject=%s money=%s cod=%s daysLeft=%s items=%s"):format(show(h[3]), show(h[4]), show(h[5]), show(h[6]), show(h[7]), show(h[8]))
    if GetInboxInvoiceInfo then
      local inv = { GetInboxInvoiceInfo(1) }
      result.invoice = {}
      for i, v in ipairs(inv) do result.invoice[i] = show(v) end
      lines[#lines + 1] = ("invoice[1]: type=%s item=%s buyer=%s bid=%s buyout=%s deposit=%s cut=%s count=%s"):format(show(inv[1]), show(inv[2]), show(inv[3]), show(inv[4]), show(inv[5]), show(inv[6]), show(inv[7]), show(inv[9]))
    end
  end
  store("mail", result)
  report("mail", lines)
end

function Probe.Secure()
  if InCombatLockdown() then return ns.Print("probe secure: leave combat first") end
  local result = {}
  local ok, err = pcall(function()
    local b = _G.GoldweaverProbeSecureButton
    if not b then
      -- UIPanelButtonTemplate gives the visible button art; SecureActionButtonTemplate the secure click handling.
      b = CreateFrame("Button", "GoldweaverProbeSecureButton", UIParent, "UIPanelButtonTemplate, SecureActionButtonTemplate")
      b:SetAttribute("type", "macro")
      -- Run 1 (08.11.2026): PreClick and PostClick fired, "/run print(...)" did not -> /run is blocked in macro text
      -- or the attribute did not fire. Run 2 uses a harmless emote: if the character dances, secure macro
      -- attributes work (F4) and only /run is blocked (F12). Nothing is cast or sent to other players' chat.
      b:SetAttribute("macrotext", "/dance")
      b:SetScript("PreClick", function() ns.Print("probe secure: click received (PreClick)") end)
      b:SetScript("PostClick", function() ns.Print("probe secure: PostClick. Did the character dance? yes = secure macro works (F4 ok), no = attribute did not fire") end)
      b:RegisterForClicks("AnyUp", "AnyDown")
      b:SetSize(260, 32)
      b:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
      b:SetFrameStrata("FULLSCREEN_DIALOG")
      b:SetText("Goldweaver Probe: hier klicken")
    end
    b:Show()
    result.shown = b:IsShown()
    result.strata = b:GetFrameStrata()
    C_Timer.After(30, function() if not InCombatLockdown() then b:Hide() end end)
  end)
  result.created, result.error = ok, err and tostring(err) or nil
  store("secure", result)
  ns.Print("probe secure: " .. (ok and ("button shown=" .. tostring(result.shown) .. " above the screen center, click it within 30 s and watch the chat") or ("failed: " .. tostring(err))))
end

local SUB = {
  [""] = Probe.General, general = Probe.General, items = Probe.Items, prof = Probe.Profession,
  ah = Probe.AuctionHouse, replicate = Probe.Replicate, mail = Probe.Mail, secure = Probe.Secure,
}

ns.Slash.Register("probe", function(arg)
  local fn = SUB[(arg or ""):lower():match("^%S*")]
  if not fn then return ns.Print("probe: general | items | prof | ah | replicate | mail | secure") end
  local ok, err = pcall(fn)
  if not ok then ns.Print("probe failed: " .. tostring(err)) end
end, "API verification: /gw probe [items|prof|ah|replicate|mail|secure]")

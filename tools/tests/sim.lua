-- Goldweaver session simulator (Lua 5.1 / LuaJIT). Usage: lua tools/tests/sim.lua <repo root>
--
-- Loads EVERY file of Goldweaver.toc into a simulated WoW client (frames, events, timers, professions, bags,
-- mailbox, auction house, merchant, trainer, tooltips, RestedXP) and plays whole sessions:
--   login -> autopilot -> background profession reading -> tooltips -> every window tab -> panel -> mailbox
--   (attach, send, inbox invoices) -> auction house (observe, sell suggestion) -> merchant/trainer -> gathering ->
--   disenchant queue -> every slash command -> settings -> debug report -> diagnosis.
-- Each scenario runs twice: "modern" (all Blizzard templates exist) and "minimal" (modern templates missing, so
-- every fallback path runs). The run fails on any Lua error, any error recorded by the addon, any unknown frame
-- method the addon calls, or a red self test. No game, no manual log reading.
local root = arg[1] or "."
local FAILURES, NOTES = {}, {}
local function fail(msg) FAILURES[#FAILURES + 1] = msg end
local function note(msg) NOTES[#NOTES + 1] = msg end

---------------------------------------------------------------------------------------------------
-- Simulated client
---------------------------------------------------------------------------------------------------
local function newClient(opts)
  local env = setmetatable({}, { __index = _G })
  env._G = env -- in WoW _G is the addon environment itself
  local clock, timers, frames, unknown = 1000, {}, {}, {}
  env._frames, env._unknown = frames, unknown
  local chat = {}
  env._chat = chat

  -- timers
  env.C_Timer = { After = function(d, fn) timers[#timers + 1] = { at = clock + (d or 0), fn = fn } end }
  local function advance(seconds)
    local target = clock + seconds
    while true do
      local idx, best
      for i, t in ipairs(timers) do if t.at <= target and (not best or t.at < best.at) then idx, best = i, t end end
      if not idx then break end
      table.remove(timers, idx)
      clock = math.max(clock, best.at)
      local ok, err = pcall(best.fn)
      if not ok then fail("uncaught error in timer: " .. tostring(err)) end
    end
    clock = target
  end
  env.GetTime = function() return clock end
  env.time = function(t) if t then return os.time(t) end return 1794200000 + math.floor(clock) end
  env.date = os.date

  -- frames
  local TEMPLATES_MODERN = { UIPanelButtonTemplate = true, UICheckButtonTemplate = true, BackdropTemplate = true, InsetFrameTemplate = true,
    PortraitFrameTemplate = true, ButtonFrameTemplate = true, PanelTabButtonTemplate = true, BasicFrameTemplateWithInset = true,
    SecureActionButtonTemplate = true, UIPanelScrollFrameTemplate = true, UIPanelCloseButton = true }
  local TEMPLATES_MINIMAL = { UIPanelButtonTemplate = true, UICheckButtonTemplate = true, BackdropTemplate = true,
    BasicFrameTemplateWithInset = true, SecureActionButtonTemplate = true, UIPanelScrollFrameTemplate = true, UIPanelCloseButton = true }
  local templates = opts.minimal and TEMPLATES_MINIMAL or TEMPLATES_MODERN

  local Methods = {}
  local function noop() end
  local mt = {}
  -- unknown keys are nil like on a real frame; capitalised ones are logged so missing simulator methods show up
  mt.__index = function(_, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^[A-Z]") then unknown[k] = (unknown[k] or 0) + 1 end
    return nil
  end

  local function newObject(kind, parent, name)
    local o = setmetatable({ _kind = kind, _shown = true, _scripts = {}, _events = {}, _attrs = {}, _text = "", _w = 100, _h = 20, _alpha = 1, _parent = parent, _name = name, _enabled = true }, mt)
    frames[#frames + 1] = o
    return o
  end
  env._newObject = newObject

  local function m(name, fn) Methods[name] = fn end
  for _, n in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetMovable", "EnableMouse", "RegisterForDrag", "RegisterForClicks",
    "StartMoving", "StopMovingOrSizing", "SetClampedToScreen", "SetFrameLevel", "SetToplevel", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "SetTexCoord", "SetVertexColor", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetMinMaxValues",
    "SetStatusBarTexture", "SetStatusBarColor", "SetFontObject", "SetHighlightTexture", "SetNormalFontObject", "SetMultiLine",
    "SetAutoFocus", "SetFocus", "ClearFocus", "HighlightText", "SetScrollChild", "SetDrawLayer", "SetOwner", "SetColorTexture",
    "SetTextColor", "SetParent", "SetID" }) do m(n, noop) end
  m("SetSize", function(self, w, h) self._w, self._h = w, h end)
  m("SetWidth", function(self, w) self._w = w end)
  m("SetHeight", function(self, h) self._h = h end)
  m("GetWidth", function(self) return self._w end)
  m("GetHeight", function(self) return self._h end)
  m("GetPoint", function() return "CENTER", nil, "CENTER", 0, 0 end)
  m("GetLeft", function() return 500 end)
  m("GetTop", function() return 500 end)
  m("GetCenter", function() return 500, 500 end)
  m("GetEffectiveScale", function() return 1 end)
  m("Show", function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end)
  m("Hide", function(self) self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end)
  m("IsShown", function(self) return self._shown end)
  m("IsVisible", function(self) return self._shown end)
  m("SetShown", function(self, s) if s then self:Show() else self:Hide() end end)
  m("SetScript", function(self, k, fn) self._scripts[k] = fn end)
  m("GetScript", function(self, k) return self._scripts[k] end)
  m("HookScript", function(self, k, fn) local old = self._scripts[k]; self._scripts[k] = function(...) if old then old(...) end fn(...) end end)
  m("RegisterEvent", function(self, e)
    if opts.unknownEvents and opts.unknownEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    self._events[e] = true
  end)
  m("UnregisterEvent", function(self, e) self._events[e] = nil end)
  m("CreateTexture", function(self) return newObject("Texture", self) end)
  m("CreateFontString", function(self) return newObject("FontString", self) end)
  m("SetText", function(self, t) self._text = t and tostring(t) or "" end)
  m("GetText", function(self) return self._text end)
  m("GetStringWidth", function(self) return #(self._text or "") * 6 end)
  m("GetFontString", function(self) self._fs = self._fs or newObject("FontString", self); return self._fs end)
  m("SetTexture", function(self, t) self._texture = t end)
  m("SetAlpha", function(self, a) self._alpha = a end)
  m("GetAlpha", function(self) return self._alpha end)
  m("SetAttribute", function(self, k, v) self._attrs[k] = v end)
  m("GetAttribute", function(self, k) return self._attrs[k] end)
  m("SetFrameStrata", function(self, s) self._strata = s end)
  m("GetFrameStrata", function(self) return self._strata or "MEDIUM" end)
  m("SetValue", function(self, v) self._value = v end)
  m("SetChecked", function(self, v) self._checked = v end)
  m("GetChecked", function(self) return self._checked end)
  m("Enable", function(self) self._enabled = true end)
  m("Disable", function(self) self._enabled = false end)
  m("SetEnabled", function(self, v) self._enabled = v and true or false end)
  m("IsEnabled", function(self) return self._enabled end)
  m("Click", function(self, button) if self._enabled and self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end
    if self._scripts.PostClick then self._scripts.PostClick(self) end end)
  m("GetID", function() return 1 end)
  m("GetName", function(self) return self._name end)
  m("GetParent", function(self) return self._parent end)
  m("GetOwner", function(self) return self._owner end)
  m("AddLine", function(self, text) self._lines = self._lines or {}; self._lines[#self._lines + 1] = text end)
  m("SetItemByID", noop)

  env.CreateFrame = function(ftype, name, parent, template)
    if template then
      for t in tostring(template):gmatch("[^,%s]+") do
        if not templates[t] then error("unknown template " .. t) end
      end
    end
    local f = newObject(ftype or "Frame", parent, name)
    f._template = template
    if name then env[name] = f end
    if template and template:find("PortraitFrameTemplate") then
      f.SetTitle = function(self, t) self._title = t end
      f.SetPortraitToAsset = noop
      f.CloseButton = newObject("Button", f)
    end
    if template and template:find("UICheckButtonTemplate") then f.Text = newObject("FontString", f) end
    if template and template:find("BasicFrameTemplate") then f.TitleText = newObject("FontString", f); f.CloseButton = newObject("Button", f) end
    return f
  end

  env.UIParent = newObject("Frame", nil, "UIParent")
  env.UIParent._w, env.UIParent._h = 1920, 1080
  env.Minimap = newObject("Frame", env.UIParent, "Minimap")
  env.Minimap._w = 140
  env.GameTooltip = newObject("GameTooltip", env.UIParent, "GameTooltip")
  env.ItemRefTooltip = newObject("GameTooltip", env.UIParent, "ItemRefTooltip")
  env.UISpecialFrames = {}
  env.tinsert = table.insert
  env.unpack = unpack
  env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) chat[#chat + 1] = msg end }
  env.SlashCmdList = {}
  env.issecretvalue = function() return false end
  env.InCombatLockdown = function() return false end
  env.IsShiftKeyDown = function() return false end
  env.GetCursorPosition = function() return 0, 0 end
  env.GetLocale = function() return "deDE" end
  env.GetBuildInfo = function() return "1.60.1", "70862", "Nov 6 2026", opts.interface or 16001 end
  env.WOW_PROJECT_ID = 18
  env.PlaySound = noop
  env.SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 }
  env.HideUIPanel = function(f) if f then f:Hide() end end
  env.ReloadUI = noop
  env.hooksecurefunc = function(obj, name, fn)
    local old = obj[name]
    obj[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
  end
  if not opts.minimal then
    env.PanelTemplates_SetNumTabs = noop
    env.PanelTemplates_SetTab = function(f, id) f._selectedTab = id end
    env.PanelTemplates_TabResize = noop
    env.Settings = {
      RegisterCanvasLayoutCategory = function(frame, name) return { GetID = function() return 7 end, frame = frame, name = name } end,
      RegisterAddOnCategory = noop,
      OpenToCategory = function() env._settingsOpened = true end,
    }
  end
  env.Enum = { TooltipDataType = { Item = 0 }, CraftingReagentType = { Basic = 1 },
    AuctionHouseTimeLeftBand = { Short = 0, Medium = 1, Long = 2, VeryLong = 3 } }
  env.C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end, GetNumAddOns = function() return 1 end,
    GetAddOnInfo = function() return "Goldweaver", nil, nil, true end }

  -- character
  local char = opts.char
  env.UnitFullName = function() return char.first, char.surname end
  env.UnitName = function(unit) if unit == "npc" then return env._npc end return char.first end
  env.UnitFactionGroup = function() return "Horde", "Horde" end
  env.UnitLevel = function() return char.level end
  env.UnitClassBase = function() return "WARRIOR" end
  env.GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
  env.GetNormalizedRealmName = function() return "CAMWOWEU4Realm5PvE" end
  env.GetAutoCompleteRealms = function() return {} end
  env.GetMoney = function() return char.money end
  env.GetProfessions = function() local t = {} for i = 1, #char.profs do t[i] = i end return unpack(t) end
  env.GetProfessionInfo = function(i)
    local p = char.profs[i]
    if not p then return nil end
    return p.name, 136240 + p.line, p.rank, p.max, 0, 0, p.line
  end

  -- items
  local ITEMS = {
    [2589] = { "Leinenstoff", 1, 1, 7, 5, 13, "" }, [2996] = { "Bolzen aus Leinenstoff", 1, 1, 7, 5, 40, "" },
    [2320] = { "Grobes Garn", 1, 1, 7, 11, 2, "" }, [7026] = { "Leinengürtel", 1, 3, 4, 1, 25, "INVTYPE_WAIST" },
    [5555] = { "Grüne Robe", 2, 12, 4, 1, 40, "INVTYPE_CHEST" }, [2450] = { "Wilddornrose", 1, 1, 7, 9, 5, "" },
    [10940] = { "Seltsamer Staub", 1, 1, 7, 12, 0, "" }, [2318] = { "Leichtes Leder", 1, 1, 7, 6, 10, "" },
    [247786] = { "Magiepartikel", 1, 1, 7, 12, 0, "" },
  }
  env.C_Item = {
    GetItemInfo = function(id)
      local it = ITEMS[id]
      if not it then return nil end
      return it[1], "|Hitem:" .. id .. "|h[" .. it[1] .. "]|h", it[2], 10, it[3], "t", "s", 20, it[7], 134000 + id % 1000, it[6], it[4], it[5], it[2] >= 2 and 2 or 0
    end,
    GetItemInfoInstant = function(id) local it = ITEMS[id] if not it then return nil end return id, "t", "s", it[7], 134000, it[4], it[5] end,
    GetItemCount = function(id) local n = 0 for _, s in pairs(env._bags[0]) do if s.itemID == id then n = n + s.stackCount end end return n end,
    GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][1] end,
    GetItemIconByID = function(id) return ITEMS[id] and (134000 + id % 1000) end,
    RequestLoadItemDataByID = noop,
    GetItemQualityColor = function() return 0.1, 1, 0.1 end,
    GetItemSpell = function() return nil end,
    DoesItemExist = function(loc) return loc ~= nil end,
    GetItemID = function(loc) return loc.itemID end,
  }
  env._bags = { [0] = {
    [1] = { itemID = 2589, stackCount = 20, quality = 1, isBound = false, isLocked = false, hyperlink = "[Leinenstoff]" },
    [2] = { itemID = 5555, stackCount = 1, quality = 2, isBound = false, isLocked = false, hyperlink = "[Grüne Robe]" },
    [3] = { itemID = 2450, stackCount = 5, quality = 1, isBound = false, isLocked = false, hyperlink = "[Wilddornrose]" },
  } }
  env._sendItems = {}
  env.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
    GetContainerNumFreeSlots = function(bag) return bag == 0 and 13 or 0 end,
    GetContainerItemInfo = function(bag, slot) local b = env._bags[bag] return b and b[slot] end,
    UseContainerItem = function(bag, slot)
      local it = env._bags[bag] and env._bags[bag][slot]
      if it and env.MailFrame._shown then env._sendItems[#env._sendItems + 1] = it; env._bags[bag][slot] = nil end
    end,
  }

  -- professions
  local open
  env.ProfessionsFrame = newObject("Frame", env.UIParent, "ProfessionsFrame")
  env.ProfessionsFrame._shown = false
  local function recipesFor(line)
    return char.recipes[line] or {}
  end
  env.C_TradeSkillUI = {
    OpenTradeSkill = function(line)
      open = line
      env.ProfessionsFrame._shown = true
      env.C_Timer.After(0.1, function() env._fire("TRADE_SKILL_SHOW"); env._fire("TRADE_SKILL_LIST_UPDATE") end)
      return true
    end,
    CloseTradeSkill = function() open = nil; env.ProfessionsFrame._shown = false end,
    IsTradeSkillReady = function() return open ~= nil end,
    GetBaseProfessionInfo = function()
      if not open then return { professionID = 0 } end
      for _, p in ipairs(char.profs) do if p.line == open then return { professionID = open, professionName = p.name, skillLevel = p.rank, maxSkillLevel = p.max } end end
      return { professionID = 0 }
    end,
    GetAllRecipeIDs = function() local ids = {} for id in pairs(recipesFor(open)) do ids[#ids + 1] = id end table.sort(ids) return ids end,
    GetRecipeInfo = function(id)
      local r = recipesFor(open)[id]
      if not r then return nil end
      return { recipeID = id, name = r.name, learned = r.learned, relativeDifficulty = r.diff, icon = 136000 + id % 100, maxTrivialLevel = r.grey, canSkillUp = r.diff < 3, numSkillUps = 1 }
    end,
    GetRecipeSchematic = function(id)
      local r = recipesFor(open)[id]
      if not r then return nil end
      local slots = {}
      for _, rg in ipairs(r.reagents) do slots[#slots + 1] = { reagents = { { itemID = rg[1] } }, quantityRequired = rg[2], reagentType = 1 } end
      return { outputItemID = r.out, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = slots, icon = 136000, name = r.name, recipeType = 1 }
    end,
    CraftRecipe = function(id) env._crafted = id end,
    GetProfessionInfoBySkillLineID = function() return nil end,
  }
  env.C_Spell = { GetSpellName = function(id) return id == 13262 and "Entzaubern" or "Zauber" end }

  -- map
  local MAPS = { [1413] = { name = "Brachland", parentMapID = 1414 }, [1414] = { name = "Kalimdor", parentMapID = 947 }, [1454] = { name = "Orgrimmar", parentMapID = 1414 } }
  env._mapID = opts.mapID or 1413
  env.C_Map = {
    GetBestMapForUnit = function() return env._mapID end,
    GetMapInfo = function(id) return MAPS[id] or { name = "Zone " .. tostring(id) } end,
    GetPlayerMapPosition = function() return { x = 0.5, y = 0.4 } end,
    SetUserWaypoint = function(p) env._waypoint = p end,
  }
  env.UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { id = id, x = x, y = y } end }
  env.C_SuperTrack = { SetSuperTrackedUserWaypoint = noop }
  env.OpenWorldMap = noop

  -- mailbox
  env.MailFrame = newObject("Frame", env.UIParent, "MailFrame")
  env.MailFrame._shown, env.MailFrame._w = false, 384
  env.MailFrameTab2 = newObject("Button", env.MailFrame, "MailFrameTab2")
  env.SendMailNameEditBox = newObject("EditBox", env.MailFrame, "SendMailNameEditBox")
  env.SendMailSubjectEditBox = newObject("EditBox", env.MailFrame, "SendMailSubjectEditBox")
  env.ATTACHMENTS_MAX_SEND = 12
  env.GetSendMailItem = function(i) return env._sendItems[i] and env._sendItems[i].itemID or nil end
  env.SendMail = function(to)
    env._sentTo = to
    env._sendItems = {}
    env.C_Timer.After(0.2, function() env._fire("MAIL_SEND_SUCCESS") end)
  end
  local inbox = { { invoice = { "seller", "Leinenstoff", nil, 0, 500, 100, 25, nil, nil, nil, 20 } } }
  env.GetInboxNumItems = function() return #inbox, #inbox end
  env.GetInboxHeaderInfo = function(i) if inbox[i] then return nil, nil, "Auktionshaus", "Verkauf", 500, 0, 29.5, nil end end
  env.GetInboxInvoiceInfo = function(i) if inbox[i] then return unpack(inbox[i].invoice) end end
  env.TakeInboxItem = noop
  env.AutoLootMailItem = function(i) table.remove(inbox, i); env._fire("MAIL_INBOX_UPDATE") end
  env.ERR_MAIL_TARGET_NOT_FOUND = "Empfänger nicht gefunden"

  -- auction house
  env.AuctionHouseFrame = newObject("Frame", env.UIParent, "AuctionHouseFrame")
  env.AuctionHouseFrame._shown = false
  local sell = newObject("Frame", env.AuctionHouseFrame)
  sell.SetItem = function() end
  sell.GetQuantity = function() return 20 end
  sell.PriceInput = { SetAmount = function(_, v) env._prefilled = v end }
  env.AuctionHouseFrame.CommoditiesSellFrame = sell
  env.AuctionHouseFrame.SearchBar = { SearchBox = newObject("EditBox", env.AuctionHouseFrame) }
  env.C_AuctionHouse = {
    IsThrottledMessageSystemReady = function() return true end,
    GetNumCommoditySearchResults = function() return 2 end,
    GetCommoditySearchResultInfo = function(_, i) return { unitPrice = 40 + i, quantity = 10, auctionID = i } end,
    GetNumItemSearchResults = function() return 0 end,
    GetItemSearchResultInfo = function() return nil end,
    GetBrowseResults = function() return { { itemKey = { itemID = 2589 }, minPrice = 45, totalQuantity = 50 } } end,
    CalculateCommodityDeposit = function() return 100 end,
    CalculateItemDeposit = function() return 100 end,
    SendSearchQuery = noop, ReplicateItems = noop, GetNumReplicateItems = function() return 0 end,
  }

  -- merchant / trainer / loot
  env.MerchantFrame = newObject("Frame", env.UIParent, "MerchantFrame"); env.MerchantFrame._shown = false
  env.ClassTrainerFrame = newObject("Frame", env.UIParent, "ClassTrainerFrame"); env.ClassTrainerFrame._shown = false
  env.BankFrame = newObject("Frame", env.UIParent, "BankFrame"); env.BankFrame._shown = false
  env.GetMerchantNumItems = function() return 2 end
  env.GetMerchantItemLink = function(i) return i == 1 and "|Hitem:2320|h[Grobes Garn]|h" or "|Hitem:2996|h[Bolzen]|h" end
  env.C_MerchantFrame = { GetItemInfo = function(i) return { price = i == 1 and 10 or 80, numAvailable = -1 } end }
  env.GetNumTrainerServices = function() return 2 end
  env.GetTrainerServiceInfo = function(i) if i == 1 then return "Geselle", "", "available" end return char.trainerRecipe or "Leinengürtel", "", "available" end
  env.GetTrainerServiceSkillReq = function(i) return i == 1 and 50 or 20 end
  env.GetTrainerServiceLevelReq = function(i) return i == 1 and 10 or 0 end
  env.GetTrainerServiceCost = function() return 500 end
  env._loot = {}
  env.GetNumLootItems = function() return #env._loot end
  env.GetLootSlotLink = function(i) return "|Hitem:" .. env._loot[i] .. "|h[x]|h" end
  env.GetLootSlotInfo = function() return nil, nil, 2 end

  -- tooltips
  env._tooltipCalls = {}
  env.TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) env._tooltipCalls[#env._tooltipCalls + 1] = fn end }

  -- RestedXP (optional)
  if opts.rxp then
    env.RXP = { currentGuide = { name = "23-25 Brachland", steps = { { elements = { { zone = 1413 } } }, { elements = { { zone = 1442 } } } } } }
    env.RXPCData = { currentStep = 1 }
  end

  -- event dispatch
  env._fire = function(event, ...)
    for _, f in ipairs(frames) do
      if f._events[event] and f._scripts.OnEvent then
        local ok, err = pcall(f._scripts.OnEvent, f, event, ...)
        if not ok then fail(("uncaught error in %s: %s"):format(event, tostring(err))) end
      end
    end
  end
  env._advance = advance
  return env
end

---------------------------------------------------------------------------------------------------
-- Load the addon
---------------------------------------------------------------------------------------------------
local function tocFiles()
  local files = {}
  local f = assert(io.open(root .. "/Goldweaver/Goldweaver.toc", "r"))
  for line in f:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  f:close()
  return files
end

local function loadAddon(env)
  local ns = {}
  for _, rel in ipairs(tocFiles()) do
    local chunk, err = loadfile(root .. "/Goldweaver/" .. rel)
    if not chunk then fail("load " .. rel .. ": " .. tostring(err)) else
      setfenv(chunk, env)
      local ok, runErr = pcall(chunk, "Goldweaver", ns)
      if not ok then fail("run " .. rel .. ": " .. tostring(runErr)) end
    end
  end
  return ns
end

---------------------------------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------------------------------
local function step(name, fn)
  local ok, err = pcall(fn)
  if not ok then fail(name .. ": " .. tostring(err)) end
end

local function findButton(env, pattern)
  for i = #env._frames, 1, -1 do
    local f = env._frames[i]
    if f._kind == "Button" and f._shown and type(f._text) == "string" and f._text:find(pattern) then return f end
  end
  return nil
end

local MAIN = { first = "Cupedos", surname = "Grel", level = 23, money = 142231,
  profs = { { name = "Lederverarbeitung", line = 165, rank = 81, max = 150 }, { name = "Kürschnerei", line = 393, rank = 142, max = 225 } },
  recipes = { [165] = {
    [2149] = { name = "Leichte Lederhose", learned = true, diff = 0, grey = 95, out = 7026, reagents = { { 2318, 4 }, { 2320, 1 } } },
    [2152] = { name = "Lederumhang", learned = false, diff = 1, grey = 120, out = 7026, reagents = { { 2318, 6 } } },
  } } }
local BANK = { first = "Cupedos", surname = "Bank", level = 6, money = 1831,
  profs = { { name = "Schneiderei", line = 197, rank = 53, max = 75 }, { name = "Verzauberkunst", line = 333, rank = 25, max = 75 } },
  trainerRecipe = "Leinentasche",
  recipes = {
    [197] = {
      [2963] = { name = "Bolzen aus Leinenstoff", learned = true, diff = 2, grey = 50, out = 2996, reagents = { { 2589, 2 } } },
      [3755] = { name = "Leinentasche", learned = true, diff = 0, grey = 70, out = 7026, reagents = { { 2996, 3 }, { 2320, 3 } } },
      [3914] = { name = "Leinenbeutel", learned = false, diff = 0, grey = 80, out = 7026, reagents = { { 2996, 4 } } },
    },
    [333] = { [7418] = { name = "Rute", learned = true, diff = 0, grey = 40, out = 2996, reagents = { { 247786, 1 } } } },
  } }

local function session(label, opts, savedDB)
  local env = newClient(opts)
  env.GoldweaverDB, env.GoldweaverCharDB, env.GoldweaverBackupDB = savedDB, nil, nil
  local ns = loadAddon(env)
  if not ns.Events then fail(label .. ": addon did not load"); return end
  local count = 0
  local function s(name, fn) count = count + 1; step(label .. " / " .. name, fn) end

  s("ADDON_LOADED", function() env._fire("ADDON_LOADED", "Goldweaver") end)
  s("PLAYER_LOGIN + 40 s autopilot", function() env._fire("PLAYER_LOGIN"); env._advance(40) end)
  s("bags and zone", function() env._fire("BAG_UPDATE_DELAYED"); env._fire("ZONE_CHANGED_NEW_AREA"); env._advance(3) end)
  s("tooltips", function()
    for _, fn in ipairs(env._tooltipCalls) do
      fn(env.GameTooltip, { id = 2589, lines = { { leftText = "Leinenstoff" } } })
      fn(env.GameTooltip, { id = 5555, lines = { { leftText = "Grüne Robe" } } })
      fn(env.GameTooltip, { id = 999999, lines = {} })
    end
    if #env._tooltipCalls == 0 and not opts.minimal then fail(label .. ": tooltip hook not registered") end
  end)
  s("every window tab", function()
    for _, key in ipairs(ns.UI.order) do ns.UI.Open(key); env._advance(0.1) end
    ns.UI.Open("heute"); ns.UI.Open("chars"); ns.UI.Toggle(); ns.UI.Toggle("berufe")
    for skillLine in pairs(ns.Chars.Current().professions) do ns.UI.SelectProfession(skillLine) end
  end)
  s("step card actions", function()
    for _, st in ipairs(ns.Steps.Build(8)) do if st.action then st.action() end end
    env._advance(2)
  end)
  s("side panel", function() ns.Panel.Refresh(); ns.Panel.Toggle(); ns.Panel.Toggle() end)
  s("mailbox send", function()
    env.MailFrame._shown = true
    env._fire("MAIL_SHOW"); env._advance(1)
    local b = findButton(env, "^Anhängen")
    local hasProcessor = #ns.Chars.ByRole("processor", ns.Chars.MarketKey()) > 0
    if ns.Chars.Current().role == "main" and hasProcessor then
      if not b then fail(label .. ": no attach button for the main") return end
      b:Click(); env._advance(0.5)
      local send = findButton(env, "^Senden")
      if not send then fail(label .. ": attach did not switch to send") return end
      send:Click(); env._advance(1)
      if not env._sentTo then fail(label .. ": mail not sent") end
    end
    env._fire("MAIL_INBOX_UPDATE"); env.AutoLootMailItem(1); env._advance(1)
    env.MailFrame._shown = false; env._fire("MAIL_CLOSED")
  end)
  s("auction house", function()
    env.AuctionHouseFrame._shown = true
    env._fire("AUCTION_HOUSE_SHOW"); env._advance(1)
    env._fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
    env._fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    env.AuctionHouseFrame.CommoditiesSellFrame:SetItem({ itemID = 2589 })
    ns.Auction.SearchFor(2589)
    env.AuctionHouseFrame._shown = false
  end)
  s("merchant and trainer", function()
    env._npc = "Händler Hans"; env.MerchantFrame._shown = true
    env._fire("MERCHANT_SHOW"); env._advance(1); env.MerchantFrame._shown = false
    env._npc = "Magar"; env._fire("TRAINER_SHOW"); env._advance(1); env._fire("TRAINER_UPDATE")
  end)
  s("gathering loot", function()
    env._fire("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 2366)
    env._loot = { 2450 }
    env._fire("LOOT_OPENED")
  end)
  s("craft via guide", function()
    local line = ns.Chars.Current().professions[197] and 197 or 165
    ns.Adapter.Open(line); env._advance(2)
    ns.UI.Open("berufe"); ns.UI.SelectProfession(line)
    local b = findButton(env, "^Herstellen")
    if b then b:Click() end
    env._fire("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 3755); env._advance(1)
  end)
  s("slash commands", function()
    local role = ns.Chars.Current().role
    for _, cmd in ipairs({ "", "help", "show field", "role processor", "role main", "role " .. role, "chars", "market", "favor 600", "undercut 2",
      "hud on", "hud auto", "minimap hide", "minimap show", "tooltip off", "tooltip on", "de", "de", "mail", "contacts",
      "checks", "feature", "feature tooltip off", "feature tooltip on", "panel", "panel", "probe", "probe items",
      "debug on", "debug off", "backup", "restore", "unknowncmd" }) do
      env.SlashCmdList.GOLDWEAVER(cmd)
    end
    env._advance(5)
  end)
  s("settings", function() ns.Settings.Open() end)
  s("debug report", function()
    ns.Debug.Run()
    if not (ns.db.debug.report and #ns.db.debug.report > 500) then fail(label .. ": debug report too short") end
  end)
  s("diagnosis and health", function()
    local findings = ns.Diagnose.Run()
    for _, f in ipairs(findings) do if f.severity == "error" then fail(label .. ": diagnosis error: " .. f.title .. " – " .. tostring(f.detail)) end end
    local h = ns.Autopilot.QuickHealth()
    if h.red > 0 then fail(label .. ": self test red: " .. table.concat(h.rows, "; ")) end
  end)
  s("logout/login keeps data", function()
    local before = 0
    for _ in pairs(ns.db.chars) do before = before + 1 end
    if before == 0 then fail(label .. ": no characters stored") end
  end)

  for _, e in ipairs(ns.Health.errors) do
    local expected = opts.unknownEvents and e.where:find("^RegisterEvent")
    if not expected then fail(("%s: addon recorded error at %s: %s"):format(label, e.where, e.err)) end
  end
  local EXPECTED_PROBES = { Inset = true, ItemSellFrame = true, SetTitle = true, SetPortraitToAsset = true, PortraitContainer = true, TitleText = true, TitleContainer = true, Text = true, CloseButton = true }
  for k, n in pairs(env._unknown) do if not EXPECTED_PROBES[k] then note(("%s: addon called frame method %s (%d×) not in the simulator"):format(label, k, n)) end end
  local s1 = ns.Checks.Summary()
  print(("%-34s %2d steps · checks %2d/%d passed · %d chat lines · role %s"):format(label, count, s1.pass, s1.total, #env._chat, tostring(ns.Chars.Current() and ns.Chars.Current().role)))
  return env.GoldweaverDB
end

---------------------------------------------------------------------------------------------------
local function deepCopy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deepCopy(v) end return o end

for _, mode in ipairs({ { name = "modern", minimal = false }, { name = "minimal", minimal = true } }) do
  -- main logs in first (fresh install), then the twink with RestedXP, then the main again on a new patch
  local db = session(mode.name .. " · Main, Neuinstallation", { minimal = mode.minimal, char = MAIN }, nil)
  db = session(mode.name .. " · Bank, RestedXP aktiv", { minimal = mode.minimal, char = BANK, rxp = true, mapID = 1454 }, deepCopy(db))
  session(mode.name .. " · Main, neuer Patch", { minimal = mode.minimal, char = MAIN, interface = 16002,
    unknownEvents = { AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = true } }, deepCopy(db))
end

for _, n in ipairs(NOTES) do print("note: " .. n) end
if #FAILURES > 0 then
  for _, f in ipairs(FAILURES) do print("FAIL " .. f) end
  print(("simulation: %d failure(s)"):format(#FAILURES))
  os.exit(1)
end
print("simulation: OK")
os.exit(0)

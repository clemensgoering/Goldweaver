-- Goldweaver: disenchant queue. Lists bag items where disenchanting beats selling, and offers ONE secure button
-- that disenchants the top item per click (/cast <Disenchant>, /use bag slot). Verified 08.11.2026: secure macro
-- attributes run on Forever (F4); /run is blocked (F12) and not used. Results are logged for calibration (F11).
local ADDON, ns = ...

local Destroy = {}
ns.Destroy = Destroy

local DISENCHANT_SPELL = 13262
local ENCHANTING = 333
local frame, button, title, line, listLines

local function spellName()
  if C_Spell and C_Spell.GetSpellName then
    local n = C_Spell.GetSpellName(DISENCHANT_SPELL)
    if n and not ns.Secret.IsSecret(n) then return n end
  end
  return "Disenchant"
end

function Destroy.CanDisenchant()
  local me = ns.Chars.Current()
  return me and me.professions and me.professions[ENCHANTING] ~= nil
end

-- Queue entries: { bag, slot, itemID, link, deValue, auctionNet, gain }
function Destroy.Queue()
  local out = {}
  if not Destroy.CanDisenchant() then return out end
  local ctx = ns.Advisor.LiveContext({ canDisenchant = true, needsMail = false })
  for _, it in ipairs(ns.Inventory.BagItems()) do
    if (it.quality or 0) >= 2 and not it.isLocked and C_Item and C_Item.GetItemInfo then
      local _, _, quality, _, reqLevel, _, _, _, equipLoc, _, sellPrice, classID = C_Item.GetItemInfo(it.itemID)
      if quality and (classID == 2 or classID == 4) and equipLoc ~= "" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BODY" then
        local item = { id = it.itemID, quantity = 1, reqLevel = reqLevel or 1, quality = quality, isWeapon = classID == 2, vendorSell = sellPrice or 0, soulbound = it.isBound }
        local options = ns.Advisor.Evaluate(item, ctx)
        local de, best
        for _, o in ipairs(options) do
          if o.action == "convert" and o.conversion and o.conversion.kind == "disenchant" then de = o end
          if not best and o.action ~= "keep" then best = o end
        end
        if de and best and de.value >= best.value then
          local alt = 0
          for _, o in ipairs(options) do if o ~= de and o.action ~= "keep" and o.value > alt then alt = o.value end end
          out[#out + 1] = { bag = it.bag, slot = it.slot, itemID = it.itemID, link = it.link, deValue = de.value, altValue = alt, gain = de.value - alt }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.gain > b.gain end)
  return out
end

local function createFrame()
  if frame then return end
  frame = CreateFrame("Frame", "GoldweaverDestroyFrame", UIParent, "BackdropTemplate")
  frame:SetSize(300, 150)
  frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    frame:SetBackdropBorderColor(0.5, 0.42, 0.25, 0.9)
  end
  title = ns.UI.Header(frame, "ENTZAUBERN")
  title:SetPoint("TOPLEFT", 10, -8)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() frame:Hide() end)

  -- the secure button: one item per click
  button = CreateFrame("Button", "GoldweaverDisenchantButton", frame, "UIPanelButtonTemplate, SecureActionButtonTemplate")
  button:SetSize(280, 26)
  button:SetPoint("TOPLEFT", 10, -28)
  button:SetAttribute("type", "macro")
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetScript("PostClick", function() Destroy.lastClickAt = GetTime(); C_Timer.After(1.5, Destroy.Refresh) end)

  line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  line:SetPoint("TOPLEFT", 10, -58); line:SetWidth(280); line:SetJustifyH("LEFT")
  listLines = ns.UI.Lines(frame, 4, 280, "GameFontDisableSmall", -76)
end

function Destroy.Refresh()
  if not frame or not frame:IsShown() then return end
  local queue = Destroy.Queue()
  Destroy.lastQueue = queue
  local top = queue[1]
  if InCombatLockdown() then
    button:SetText("Im Kampf nicht möglich")
    button:Disable()
    return
  end
  if not top then
    button:SetText("Nichts zu entzaubern")
    button:Disable()
    button:SetAttribute("macrotext", "")
    line:SetText(Destroy.CanDisenchant() and "Keine grünen oder besseren Items, bei denen Entzaubern mehr bringt als Verkaufen." or "Dieser Charakter hat keine Verzauberkunst.")
    listLines:Set({})
    return
  end
  button:Enable()
  button:SetAttribute("macrotext", ("/cast %s\n/use %d %d"):format(spellName(), top.bag, top.slot))
  local name = top.link and top.link:match("%[(.-)%]") or tostring(top.itemID)
  button:SetText(("Entzaubern: %s (≈%s)"):format(name, ns.Util.Money(top.deValue)))
  line:SetText(("Statt verkaufen für %s · noch %d Item(s) in der Liste"):format(ns.Util.Money(top.altValue), #queue))
  local rows = {}
  for i = 2, math.min(5, #queue) do
    local q = queue[i]
    rows[#rows + 1] = ("%s  ≈%s (+%s)"):format(q.link and q.link:match("%[(.-)%]") or q.itemID, ns.Util.Money(q.deValue), ns.Util.Money(q.gain))
  end
  listLines:Set(rows)
end

function Destroy.Show()
  createFrame()
  frame:Show()
  Destroy.Refresh()
end

function Destroy.Toggle()
  createFrame()
  if frame:IsShown() then frame:Hide() else Destroy.Show() end
end

-- Calibration log: what a disenchant produced (LOOT_OPENED right after our cast).
local lastCastAt
ns:RegisterModule("Destroy", {
  SelfTest = function()
    local can = Destroy.CanDisenchant()
    local queue = can and Destroy.Queue() or {}
    local obs = ns.db.observations.disenchant or {}
    return {
      { name = "Verzauberkunst auf diesem Charakter", ok = can, warn = true, detail = can and "ja" or "nein" },
      { name = "Zauber-Name", ok = spellName() ~= "Disenchant" or GetLocale() == "enUS", warn = true, detail = spellName() },
      { name = "Queue", ok = true, detail = #queue .. " Item(s)" },
      { name = "Entzauber-Beobachtungen", ok = true, detail = #obs .. " geloggt" },
    }
  end,
  Init = function()
    ns.Events:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
      if unit == "player" and spellID == DISENCHANT_SPELL then lastCastAt = GetTime() end
    end)
    ns.Events:On("LOOT_OPENED", function()
      if not lastCastAt or GetTime() - lastCastAt > 3 then return end
      if not (GetNumLootItems and GetLootSlotInfo) then return end
      local obs = { t = time(), kind = "disenchant", items = {} }
      for i = 1, GetNumLootItems() do
        local _, _, qty = GetLootSlotInfo(i)
        local link = GetLootSlotLink and GetLootSlotLink(i)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id and not ns.Secret.Any(id, qty) then obs.items[#obs.items + 1] = { item = id, qty = qty or 1 } end
      end
      ns.db.observations.disenchant = ns.db.observations.disenchant or {}
      table.insert(ns.db.observations.disenchant, obs)
      while #ns.db.observations.disenchant > 500 do table.remove(ns.db.observations.disenchant, 1) end
      lastCastAt = nil
      if ns.Checks then
        ns.Checks.Pass("deObserved", #obs.items .. " Ergebnis(se)")
        if Destroy.lastClickAt and GetTime() - Destroy.lastClickAt < 10 then ns.Checks.Pass("disenchant", "über die Queue") end
      end
    end, "Destroy")
    ns.Events:On("PLAYER_REGEN_ENABLED", function() Destroy.Refresh() end)
    ns.Events:On("BAG_UPDATE_DELAYED", function() if frame and frame:IsShown() then C_Timer.After(0.8, Destroy.Refresh) end end)
  end,
})

ns.Slash.Register("de", function() Destroy.Toggle() end, "toggle the disenchant queue")

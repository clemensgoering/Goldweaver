-- Goldweaver: auction house. (1) Observe: every search result page the player sees is recorded into the price
-- engine; no extra requests are sent (ReplicateItems is dead on Forever, F13). (2) Sell helper: when an item is
-- placed in the sell frame, a suggestion line shows undercut price, deposit and net, and prefills the price input.
local ADDON, ns = ...

local Auction = {}
ns.Auction = Auction

-- Observe -------------------------------------------------------------------------------------
local function observeCommodity(itemID)
  if not (C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetCommoditySearchResultInfo) then return end
  local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
  local now = time()
  for i = 1, math.min(n, 50) do
    local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if r and r.unitPrice and not ns.Secret.Any(r.unitPrice, r.quantity) then
      ns.Price.Observe(itemID, r.unitPrice, r.quantity or 1, now)
    end
  end
end

local function observeItem(itemKey)
  if not (itemKey and itemKey.itemID and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo) then return end
  local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
  local now = time()
  for i = 1, math.min(n, 50) do
    local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
    if r and r.buyoutAmount and r.buyoutAmount > 0 and not ns.Secret.Any(r.buyoutAmount) then
      ns.Price.Observe(itemKey.itemID, r.buyoutAmount, 1, now)
    end
  end
end

local function observeBrowse()
  if not C_AuctionHouse.GetBrowseResults then return end
  local results = C_AuctionHouse.GetBrowseResults() or {}
  local now = time()
  for _, r in ipairs(results) do
    if r.itemKey and r.itemKey.itemID and r.minPrice and r.minPrice > 0 and not ns.Secret.Any(r.itemKey.itemID, r.minPrice) then
      ns.Price.Observe(r.itemKey.itemID, r.minPrice, r.totalQuantity or 1, now)
    end
  end
end

-- Sell helper ---------------------------------------------------------------------------------
local helper, helperText

function Auction.Suggest(itemID, quantity, durationIndex)
  local p = ns.Price.Get(itemID)
  if not p then return nil end
  local undercut = ns.db.settings.undercutCopper or 1
  local unit = math.max(1, p.copper - undercut)
  local deposit
  if C_AuctionHouse.CalculateCommodityDeposit then
    local ok, d = pcall(C_AuctionHouse.CalculateCommodityDeposit, itemID, durationIndex or 2, quantity or 1)
    if ok and type(d) == "number" then deposit = d end
  end
  local gross = unit * (quantity or 1)
  local net = math.floor(gross * (1 - (ns.db.settings.ahCut or 0.05)))
  return { unitPrice = unit, market = p.copper, source = p.source, age = p.age, deposit = deposit, net = net }
end

local function ageText(age)
  if not age then return "?" end
  if age >= 86400 then return math.floor(age / 86400) .. " Tage" end
  if age >= 3600 then return math.floor(age / 3600) .. " h" end
  return math.floor(age / 60) .. " min"
end

local function showSuggestion(sellFrame, itemLocation)
  if not helper then return end
  if not itemLocation or not (C_Item and C_Item.DoesItemExist and C_Item.DoesItemExist(itemLocation)) then helper:Hide(); return end
  local itemID = C_Item.GetItemID and C_Item.GetItemID(itemLocation)
  if not itemID or ns.Secret.IsSecret(itemID) then helper:Hide(); return end
  local quantity = 1
  if sellFrame.GetQuantity then local ok, q = pcall(sellFrame.GetQuantity, sellFrame) if ok and type(q) == "number" then quantity = q end end
  local s = Auction.Suggest(itemID, quantity)
  if not s then
    helperText:SetText("Goldweaver: kein Preis bekannt für dieses Item. Erst suchen, dann posten.")
    helper:Show()
    return
  end
  helperText:SetText(("Goldweaver: Vorschlag %s je Stück · unterbietet %s (%s, %s) · Einzahlung %s · Erlös nach Cut %s"):format(
    ns.Util.Money(s.unitPrice), ns.Util.Money(s.market), s.source, ageText(s.age), s.deposit and ns.Util.Money(s.deposit) or "?", ns.Util.Money(s.net)))
  helper:Show()
  if ns.db.settings.autofillPrice ~= false and sellFrame.PriceInput and sellFrame.PriceInput.SetAmount then
    pcall(sellFrame.PriceInput.SetAmount, sellFrame.PriceInput, s.unitPrice)
  end
end

local function hookSellFrames()
  if not AuctionHouseFrame then return end
  if not helper then
    helper = CreateFrame("Frame", "GoldweaverAHHelper", AuctionHouseFrame)
    helper:SetSize(700, 20)
    helper:SetPoint("TOP", AuctionHouseFrame, "BOTTOM", 0, -2)
    helperText = helper:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helperText:SetPoint("CENTER")
    helperText:SetTextColor(0.83, 0.66, 0.31)
    helper:Hide()
  end
  Auction.hooked = Auction.hooked or {}
  for _, key in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
    local f = AuctionHouseFrame[key]
    if f and f.SetItem and not Auction.hooked[key] then
      Auction.hooked[key] = true
      hooksecurefunc(f, "SetItem", function(self, itemLocation) pcall(showSuggestion, self, itemLocation) end)
      f:HookScript("OnHide", function() if helper then helper:Hide() end end)
    end
  end
end

ns:RegisterModule("Auction", {
  SelfTest = function()
    local hooked = Auction.hooked and (Auction.hooked.CommoditiesSellFrame or Auction.hooked.ItemSellFrame)
    local s = Auction.Suggest(2589, 20, 2)
    return {
      { name = "C_AuctionHouse", ok = C_AuctionHouse ~= nil, detail = C_AuctionHouse and "vorhanden" or "fehlt" },
      { name = "Verkaufsfenster gehookt", ok = hooked and true or false, warn = true, detail = hooked and "ja" or "erst nach dem ersten AH-Besuch" },
      { name = "Vorschlag Leinenstoff x20", ok = s ~= nil, warn = true, detail = s and ("%s je Stück, Einzahlung %s"):format(ns.Util.Money(s.unitPrice), s.deposit and ns.Util.Money(s.deposit) or "?") or "kein Preis" },
    }
  end,
  Init = function()
    if not C_AuctionHouse then return end
    ns.Events:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) if itemID then pcall(observeCommodity, itemID) end end)
    ns.Events:On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) pcall(observeItem, itemKey) end)
    ns.Events:On("BROWSE_SEARCH_RESULTS_UPDATED", function() pcall(observeBrowse) end)
    ns.Events:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.5, function() pcall(hookSellFrames) end) end)
    ns.Events:On("ADDON_LOADED", function(_, name) if name == "Blizzard_AuctionHouseUI" then C_Timer.After(0.5, function() pcall(hookSellFrames) end) end end)
  end,
})

-- Fills the AH search box with an item name (no query is sent; the player presses search). Used by the guide.
function Auction.SearchFor(itemID)
  if not (AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return false end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
  if not name then return false end
  local box = AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SearchBox
  if box and box.SetText then box:SetText(name); return true end
  return false
end

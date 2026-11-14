-- Goldweaver: auction house. (1) Observe: every search result page the player sees is recorded into the price
-- engine; no extra requests are sent (ReplicateItems is dead on Forever, F13). (2) Sell helper: when an item is
-- placed in the sell frame, a suggestion line shows undercut price, deposit and net, and prefills the price input.
local ADDON, ns = ...
local L = ns.L

local Auction = {}
ns.Auction = Auction

-- Observe -------------------------------------------------------------------------------------
local function observed(itemID, n)
  if n > 0 and ns.Checks then ns.Checks.Pass("ahObserve", ("Item %d: %d offers"):format(itemID, n)) end
end

local function observeCommodity(itemID)
  if not (C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetCommoditySearchResultInfo) then return end
  local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
  local now = time()
  local seen = 0
  for i = 1, math.min(n, 50) do
    local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if r and r.unitPrice and not ns.Secret.Any(r.unitPrice, r.quantity) then
      ns.Price.Observe(itemID, r.unitPrice, r.quantity or 1, now)
      seen = seen + 1
    end
  end
  observed(itemID, seen)
end

local function observeItem(itemKey)
  if not (itemKey and itemKey.itemID and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo) then return end
  local n = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
  local now = time()
  local seen = 0
  for i = 1, math.min(n, 50) do
    local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
    if r and r.buyoutAmount and r.buyoutAmount > 0 and not ns.Secret.Any(r.buyoutAmount) then
      ns.Price.Observe(itemKey.itemID, r.buyoutAmount, 1, now)
      seen = seen + 1
    end
  end
  observed(itemKey.itemID, seen)
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
  if age >= 86400 then return (L["%d days"]):format(math.floor(age / 86400)) end
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
  -- F6: sample the deposit for all three durations against the vendor price
  if ns.Learn and C_AuctionHouse.CalculateCommodityDeposit then
    local vendorSell = ns.Price.VendorSell(itemID)
    local deposits = {}
    for d = 1, 3 do
      local ok, dep = pcall(C_AuctionHouse.CalculateCommodityDeposit, itemID, d, quantity)
      if not (ok and type(dep) == "number") and C_AuctionHouse.CalculateItemDeposit then
        ok, dep = pcall(C_AuctionHouse.CalculateItemDeposit, itemLocation, d, quantity)
      end
      deposits[d] = ok and type(dep) == "number" and dep or nil
    end
    if vendorSell and deposits[1] and deposits[2] and deposits[3] then pcall(ns.Learn.DepositSample, itemID, quantity, vendorSell, deposits) end
  end
  local s = Auction.Suggest(itemID, quantity)
  if not s then
    helperText:SetText(L["Goldweaver: no price known for this item. Search first, then post."])
    helper:Show()
    return
  end
  local text = (L["Goldweaver: suggestion %s each · undercuts %s (%s, %s) · deposit %s · proceeds after cut %s"]):format(
    ns.Util.Money(s.unitPrice), ns.Util.Money(s.market), s.source, ageText(s.age), s.deposit and ns.Util.Money(s.deposit) or "?", ns.Util.Money(s.net))
  -- B23: break-even from the own purchase or craft cost
  local breakEven = ns.Ledger.BreakEven(itemID, quantity, s.deposit)
  helperText:SetTextColor(0.83, 0.66, 0.31)
  if breakEven then
    if s.unitPrice < breakEven then
      text = text .. " · " .. (L["|cffff6040below break-even %s|r"]):format(ns.Util.Money(breakEven))
    else
      text = text .. " · " .. (L["break-even %s"]):format(ns.Util.Money(breakEven))
    end
  end
  helperText:SetText(text)
  helper:Show()
  local filled = false
  if ns.db.settings.autofillPrice ~= false and sellFrame.PriceInput and sellFrame.PriceInput.SetAmount then
    filled = pcall(sellFrame.PriceInput.SetAmount, sellFrame.PriceInput, s.unitPrice)
  end
  if ns.Checks then ns.Checks.Pass("ahSuggest", ("%s%s"):format(ns.Util.Money(s.unitPrice), filled and ", prefilled" or "")) end
end

local function hookSellFrames()
  if not AuctionHouseFrame then return end
  if not helper then
    helper = CreateFrame("Frame", "GoldweaverAHHelper", AuctionHouseFrame)
    helper:SetSize(700, 20)
    helper:SetPoint("TOP", AuctionHouseFrame, "BOTTOM", 0, -32) -- below the tabs (Blizzard left, ours right)
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

-- Shopping list (B19) ------------------------------------------------------------------------
-- Two tabs under the auction house: the action tab walks one material at a time through three clicks
-- (search -> buy -> confirm) and the skip tab moves to the next material. A price rise of more than 15 % between
-- search and purchase stops the purchase. Only commodities (stackable materials) are bought.
local shop = { index = 1, state = "idle" }
local shopTabs
local PRICE_JUMP = 1.15

local function shopList()
  local list = {}
  for _, row in ipairs(ns.Coop.Shopping()) do
    if row.source ~= "vendor" and row.missing > 0 then list[#list + 1] = row end
  end
  -- what cannot be gathered by the team first
  table.sort(list, function(a, b)
    local ae, be = a.source == "elsewhere" and 0 or 1, b.source == "elsewhere" and 0 or 1
    if ae ~= be then return ae < be end
    return a.missing > b.missing
  end)
  return list
end

-- Cheapest cost for qty units from the current commodity results (nil when not enough is offered).
local function quote(itemID, qty)
  if not (C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetCommoditySearchResultInfo) then return nil end
  local total, left = 0, qty
  for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
    local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
    if r and r.unitPrice and r.quantity and not ns.Secret.Any(r.unitPrice, r.quantity) then
      local take = math.min(left, r.quantity)
      total, left = total + take * r.unitPrice, left - take
      if left <= 0 then return total end
    end
  end
  return nil
end

local refreshShop
local function ready()
  return C_AuctionHouse.IsThrottledMessageSystemReady == nil or C_AuctionHouse.IsThrottledMessageSystemReady()
end

refreshShop = function()
  if not (shopTabs and AuctionHouseFrame and AuctionHouseFrame:IsShown()) then return end
  local list = shopList()
  if #list == 0 then shopTabs[1]:Clear(); shopTabs[2]:Clear(); return end
  if shop.index > #list then shop.index = 1 end
  local row = list[shop.index]
  local name = ns.UI.ItemName(row.item)
  if shop.item ~= row.item then shop.item, shop.state, shop.qty = row.item, "idle", row.missing end
  local qty = shop.qty
  local tip = (L["Shopping list %d/%d: %d × %s for %s's plan."]):format(shop.index, #list, qty, name, row.forRec and (ns.Chars.ShortName(row.forRec)) or "?")
  if shop.state == "idle" then
    shopTabs[1]:Set((L["Search %s"]):format(name), tip, function()
      if not ready() then return ns.Print(L["Auction house is busy, try again in a moment."]) end
      local key = C_AuctionHouse.MakeItemKey and C_AuctionHouse.MakeItemKey(row.item)
      local sorts = (Enum and Enum.AuctionHouseSortOrder) and { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } } or {}
      if key and C_AuctionHouse.SendSearchQuery then C_AuctionHouse.SendSearchQuery(key, sorts, true) end
      shop.state = "searched"
      C_Timer.After(1, refreshShop)
    end)
  elseif shop.state == "searched" then
    local total = quote(row.item, qty)
    if not total then
      shopTabs[1]:Set((L["%s: not enough offered"]):format(name), tip, function() shop.state = "idle"; refreshShop() end, true)
    else
      shopTabs[1]:Set((L["Buy %d × %s ≈ %s"]):format(qty, name, ns.Util.Money(total)), tip, function()
        if not ready() then return ns.Print(L["Auction house is busy, try again in a moment."]) end
        shop.expectTotal = total
        if C_AuctionHouse.StartCommoditiesPurchase then C_AuctionHouse.StartCommoditiesPurchase(row.item, qty) end
        shop.state = "starting"
        refreshShop()
      end, (GetMoney and GetMoney() or 0) >= total)
    end
  elseif shop.state == "starting" then
    shopTabs[1]:Set(L["Waiting for the price…"], tip, nil, false)
  elseif shop.state == "confirm" then
    shopTabs[1]:Set((L["Confirm %d × %s for %s"]):format(qty, name, ns.Util.Money(shop.total)), tip, function()
      if C_AuctionHouse.ConfirmCommoditiesPurchase then C_AuctionHouse.ConfirmCommoditiesPurchase(row.item, qty) end
      shop.state = "buying"
      refreshShop()
    end)
  elseif shop.state == "jump" then
    shopTabs[1]:Set((L["Price rose to %s, cancel"]):format(ns.Util.Money(shop.total)), tip, function()
      if C_AuctionHouse.CancelCommoditiesPurchase then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
      shop.state = "idle"
      refreshShop()
    end)
  elseif shop.state == "buying" then
    shopTabs[1]:Set(L["Buying…"], tip, nil, false)
  end
  if #list > 1 then
    shopTabs[2]:Set((L["Next (%d/%d)"]):format(shop.index, #list), L["Skip to the next material on the list."], function()
      if shop.state == "confirm" or shop.state == "jump" then
        if C_AuctionHouse.CancelCommoditiesPurchase then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
      end
      shop.index, shop.item = shop.index % #list + 1, nil
      refreshShop()
    end)
  else
    shopTabs[2]:Clear()
  end
end
Auction.RefreshShopping = refreshShop

local function onPriceUpdated(_, unitPrice, totalPrice)
  if shop.state ~= "starting" or ns.Secret.Any(unitPrice, totalPrice) then return end
  shop.total = totalPrice
  if shop.expectTotal and totalPrice and totalPrice > shop.expectTotal * PRICE_JUMP then shop.state = "jump" else shop.state = "confirm" end
  refreshShop()
end

local function onPurchaseDone(ok)
  if shop.state ~= "buying" then return end
  if ok then
    if ns.Ledger then ns.Ledger.RecordPurchase(shop.item, shop.qty, shop.total or 0) end
    if ns.Checks then ns.Checks.Pass("ahBuy", ("%d × %s"):format(shop.qty or 0, tostring(shop.item))) end
    shop.item = nil
  else
    shop.state = "idle"
  end
  C_Timer.After(0.5, refreshShop)
end

ns:RegisterModule("Auction", {
  SelfTest = function()
    local hooked = Auction.hooked and (Auction.hooked.CommoditiesSellFrame or Auction.hooked.ItemSellFrame)
    local s = Auction.Suggest(2589, 20, 2)
    return {
      { name = "C_AuctionHouse", ok = C_AuctionHouse ~= nil, detail = C_AuctionHouse and "present" or "missing" },
      { name = "Sell frame hooked", ok = hooked and true or false, warn = true, detail = hooked and "yes" or "only after the first AH visit" },
      { name = "Suggestion linen cloth x20", ok = s ~= nil, warn = true, detail = s and ("%s each, deposit %s"):format(ns.Util.Money(s.unitPrice), s.deposit and ns.Util.Money(s.deposit) or "?") or "no price" },
    }
  end,
  Init = function()
    if not C_AuctionHouse then return end
    ns.Events:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID)
      if itemID then pcall(observeCommodity, itemID) end
      if shop.state == "searched" and itemID == shop.item then pcall(refreshShop) end
    end)
    ns.Events:On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) pcall(observeItem, itemKey) end)
    -- Mainline name (verified: "BROWSE_SEARCH_RESULTS_UPDATED" does not exist on Forever 1.60.1)
    ns.Events:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() pcall(observeBrowse) end)
    ns.Events:On("AUCTION_HOUSE_SHOW", function()
      C_Timer.After(0.5, function()
        pcall(hookSellFrames)
        if not shopTabs and AuctionHouseFrame then shopTabs = ns.UI.FrameTabs(AuctionHouseFrame, 2) end
        shop.index, shop.item = 1, nil
        pcall(refreshShop)
      end)
    end)
    ns.Events:On("COMMODITY_PRICE_UPDATED", onPriceUpdated, "Auction")
    -- the server may answer the purchase start with "no price": back to search instead of waiting forever
    ns.Events:On("COMMODITY_PRICE_UNAVAILABLE", function()
      if shop.state == "starting" then shop.state = "idle"; pcall(refreshShop) end
    end, "Auction")
    ns.Events:On("COMMODITY_PURCHASE_SUCCEEDED", function() onPurchaseDone(true) end, "Auction")
    ns.Events:On("COMMODITY_PURCHASE_FAILED", function() onPurchaseDone(false) end, "Auction")
    ns.Events:On("AUCTION_HOUSE_CLOSED", function() shop.state, shop.item = "idle", nil end, "Auction")
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

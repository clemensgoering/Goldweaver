-- Goldweaver: tooltip lines (docs/08-UX.md 4.1). One gold line with the best use and its value; Shift shows the
-- other options; a grey stock line when the item exists in bank or on alts. Uses TooltipDataProcessor (verified on Forever).
local ADDON, ns = ...
local L = ns.L

local Tooltip = {}
ns.Tooltip = Tooltip

local GOLD = { 0.83, 0.66, 0.31 }
local ACTION_LABEL = { vendor = "Vendor", auction = "AH", convert = nil, crate = "Crate~", keep = "Keep" } -- English keys, translated at display

local function optionLabel(o)
  if o.action == "convert" then return o.conversion and L[o.conversion.name or o.conversion.kind] or L["Convert"] end
  return L[ACTION_LABEL[o.action] or o.action]
end

local function whoCan(conv)
  if not conv then return nil end
  local skillLine = conv.skillLine
  if not skillLine and conv.profession then
    local profile = ns.Professions:Get(conv.profession)
    skillLine = profile and profile.skillLineID
  end
  if not skillLine then return nil end
  local names = {}
  for _, rec in ipairs(ns.Chars.WithProfession(skillLine, ns.Chars.MarketKey())) do names[#names + 1] = rec.firstName or rec.name end
  if #names == 0 then return nil end
  return table.concat(names, ", ")
end

local function buildItem(itemID, quantity, isBound)
  if not (C_Item and C_Item.GetItemInfo) then return nil end
  local _, _, quality, _, reqLevel, _, _, _, equipLoc, _, sellPrice, classID, _, bindType = C_Item.GetItemInfo(itemID)
  if quality == nil then return nil end -- not cached yet
  if ns.Secret.Any(quality, reqLevel, sellPrice, classID, bindType) then return nil end
  local bound = isBound
  if bound == nil then bound = (bindType == 1) end -- BoP items in bags are bound
  return {
    id = itemID, quantity = quantity or 1, reqLevel = reqLevel or 1, quality = quality, isWeapon = classID == 2,
    vendorSell = sellPrice or 0, soulbound = bound, equipLoc = equipLoc, classID = classID,
  }
end

function Tooltip.Lines(itemID, quantity, isBound)
  local item = buildItem(itemID, quantity, isBound)
  if not item then return nil end
  local ctx = ns.Advisor.LiveContext()
  local options = ns.Advisor.Evaluate(item, ctx)
  if #options == 0 then
    return { { text = L["Goldweaver: no price known · search the AH or let Auctionator scan"], color = { 0.6, 0.6, 0.6 } } }
  end
  local best = options[1]
  local lines = {}

  -- mail hint for the gatherer
  local target, reason = nil, nil
  if ns.Mail and ns.Mail.TargetFor then target, reason = ns.Mail.TargetFor({ itemID = itemID, quality = item.quality, isBound = item.soulbound }) end

  local main
  if best.value <= 0 and best.action == "vendor" and item.vendorSell == 0 then
    main = L["Goldweaver: no price known · open the AH or install Auctionator"]
  else
    local label = optionLabel(best)
    local who = best.action == "convert" and whoCan(best.conversion) or nil
    main = (L["Goldweaver: %s ≈ %s"]):format(label, ns.Util.Money(best.value))
    if who then main = main .. " (" .. who .. ")" end
    if target then main = (L["Goldweaver: send to %s » %s ≈ %s"]):format(target.firstName or target.name, label, ns.Util.Money(best.value)) end
  end
  lines[#lines + 1] = { text = main, color = GOLD }

  if IsShiftKeyDown and IsShiftKeyDown() then
    local parts = {}
    for i = 2, math.min(#options, 5) do
      local o = options[i]
      local v = ns.Util.Money(o.value)
      if o.action == "crate" and o.detail and o.detail.partial then v = v .. " (" .. (L["%d needed"]):format(o.detail.bundleQty) .. ")" end
      parts[#parts + 1] = optionLabel(o) .. " " .. v
    end
    if reason and not target then parts[#parts + 1] = (L["Rule: %s"]):format(reason) end
    if #parts > 0 then lines[#lines + 1] = { text = "  " .. table.concat(parts, " · "), color = { 0.7, 0.7, 0.7 } } end
    local p = ns.Price.Get(itemID)
    if p then
      local age = p.age and p.age >= 3600 and (math.floor(p.age / 3600) .. " h") or (p.age and (math.floor((p.age or 0) / 60) .. " min") or "?")
      lines[#lines + 1] = { text = (L["  Price %s · %s, %s"]):format(ns.Util.Money(p.copper), p.source, age), color = { 0.7, 0.7, 0.7 } }
    end
  else
    lines[#lines + 1] = { text = L["  Shift: all options"], color = { 0.45, 0.45, 0.45 } }
  end

  -- team demand: the processor needs this for its next skill-ups
  local need = ns.Demand and ns.Demand.For(itemID)
  if need then
    local who, why = next(need.by)
    lines[#lines + 1] = { text = (L["  Wanted: %s needs %d (%s)"]):format((who or L["Team"]):match("^(%S+)") or L["Team"], need.qty, tostring(why or "")), color = { 1, 0.82, 0 } }
  end

  -- stock line (Baganator-style alt counts), only when something is beyond the bags
  local total, br = ns.Inventory.Count(itemID, { bank = true, alts = true })
  if total > (br.bags or 0) then
    local parts = { (L["Bags %d"]):format(br.bags or 0) }
    if (br.bank or 0) > 0 then parts[#parts + 1] = (L["Bank %d"]):format(br.bank) end
    if (br.mail or 0) > 0 then parts[#parts + 1] = (L["Mail %d"]):format(br.mail) end
    -- other characters with where it is (B18): "Grel 12 (bank 4, mail 6)"
    for _, a in ipairs(br.alts or {}) do
      local where = {}
      if (a.bank or 0) > 0 then where[#where + 1] = (L["bank %d"]):format(a.bank) end
      if (a.mail or 0) > 0 then where[#where + 1] = (L["mail %d"]):format(a.mail) end
      parts[#parts + 1] = ("%s %d%s"):format(a.name:match("^(%S+)") or a.name, a.count, #where > 0 and (" (" .. table.concat(where, ", ") .. ")") or "")
    end
    lines[#lines + 1] = { text = (L["  Stock: %s"]):format(table.concat(parts, " · ")), color = { 0.6, 0.6, 0.6 }, stock = true }
  end
  return lines
end

local function onItemTooltip(tooltip, data)
  if not (tooltip == GameTooltip or tooltip == ItemRefTooltip) then return end
  if ns.db.settings.tooltipOff then return end
  local itemID = data and data.id
  if not itemID or ns.Secret.IsSecret(itemID) then return end
  local quantity, isBound
  -- bag item: count and bound state are known from the owning container button
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  if owner and owner.GetBagID then
    local okBag, bag = pcall(owner.GetBagID, owner)
    local slot = owner.GetID and owner:GetID()
    if okBag and bag and slot and C_Container and C_Container.GetContainerItemInfo then
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID == itemID then quantity = info.stackCount; isBound = info.isBound end
    end
  end
  -- F7: capture crate tooltips (any item whose lines mention favor) for automatic bundle/favor learning
  if ns.Learn and data.lines then
    local name = data.lines[1] and data.lines[1].leftText
    pcall(ns.Learn.CrateTooltip, itemID, name, data.lines)
  end
  local ok, lines = pcall(Tooltip.Lines, itemID, quantity, isBound)
  if not ok then ns.Log("tooltip error", lines); return end
  if not lines then return end
  tooltip:AddLine(" ")
  for _, l in ipairs(lines) do
    tooltip:AddLine(l.text, l.color[1], l.color[2], l.color[3], true)
    if ns.Checks and l.stock then ns.Checks.Pass("stock", l.text) end
  end
  if ns.Checks then ns.Checks.Pass("tooltip", lines[1].text) end
end

local registered = false
ns:RegisterModule("Tooltip", {
  Init = function()
    local ok, why = ns.Features.Available("tooltip")
    if ok and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
      registered = true
    else
      ns.Print((L["Tooltip lines off: %s"]):format(tostring(why or "Enum.TooltipDataType missing")))
    end
  end,
  SelfTest = function()
    local ok, lines = pcall(Tooltip.Lines, 2589, 20, false)
    return {
      { name = "Tooltip hook registered", ok = registered, detail = registered and "TooltipDataProcessor" or "no" },
      { name = "Lines for linen cloth", ok = ok and lines ~= nil, warn = true, detail = ok and (lines and lines[1].text or "none (item not cached?)") or tostring(lines) },
    }
  end,
})

ns.Slash.Register("tooltip", function(arg)
  ns.db.settings.tooltipOff = (arg == "off")
  ns.Print(ns.db.settings.tooltipOff and L["Tooltip lines off"] or L["Tooltip lines on"])
end, "tooltip lines on|off")

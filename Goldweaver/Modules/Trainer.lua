-- Goldweaver: trainer helper (B20). A card beside the trainer window lists what is worth learning here: the next
-- rank first, then recipes with their profit per craft and after how many crafts the training cost is paid back.
-- Each row has its own "Learn" button (one purchase per click, BuyTrainerService).
--
-- Public API (ns.Trainer)
--   Rows() -> { { index, name, cost, kind = "rank"|"recipe", profit?, payback?, available } }
local ADDON, ns = ...
local L = ns.L

local Trainer = {}
ns.Trainer = Trainer

local RANK_SKILLS = { [50] = true, [125] = true, [200] = true }
local ROWS = 6
local card, rows, title

local function serviceInfo(i)
  local name, rank, category = GetTrainerServiceInfo(i)
  if not name or ns.Secret.Any(name, category) or category == "header" then return nil end
  local cost, skillReq, levelReq
  if GetTrainerServiceCost then local ok, c = pcall(GetTrainerServiceCost, i) if ok then cost = tonumber(c) end end
  if GetTrainerServiceSkillReq then local ok, s = pcall(GetTrainerServiceSkillReq, i) if ok then skillReq = tonumber(s) end end
  if GetTrainerServiceLevelReq then local ok, lv = pcall(GetTrainerServiceLevelReq, i) if ok then levelReq = tonumber(lv) end end
  return { index = i, name = name, rank = rank, available = category == "available", cost = cost or 0, skillReq = skillReq, levelReq = levelReq }
end

-- Unlearned recipes of this character by name, with the skill line they belong to.
local function unlearnedByName()
  local map = {}
  local me = ns.Chars.Current()
  for skillLine in pairs(me and me.professions or {}) do
    for _, r in ipairs(ns.Adapter.Unlearned(skillLine) or {}) do map[r.name] = r end
  end
  return map
end

function Trainer.Rows()
  local out = {}
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return out end
  local recipes = unlearnedByName()
  for i = 1, GetNumTrainerServices() or 0 do
    local s = serviceInfo(i)
    if s and s.available then
      if s.skillReq and RANK_SKILLS[s.skillReq] and (s.levelReq or 0) > 0 and not recipes[s.name] then
        s.kind = "rank"
        out[#out + 1] = s
      elseif recipes[s.name] then
        s.kind = "recipe"
        s.profit = ns.CraftProfit.Of(recipes[s.name])
        s.item = recipes[s.name].outputItemID
        if s.profit and s.profit > 0 and s.cost > 0 then s.payback = math.ceil(s.cost / s.profit) end
        out[#out + 1] = s
      end
    end
  end
  table.sort(out, function(a, b)
    if a.kind ~= b.kind then return a.kind == "rank" end
    return (a.profit or -math.huge) > (b.profit or -math.huge)
  end)
  return out
end

local function refresh()
  if not (card and ClassTrainerFrame and ClassTrainerFrame:IsShown()) then return end
  local list = Trainer.Rows()
  local data = {}
  for _, s in ipairs(list) do
    if #data >= ROWS then break end
    local sub
    if s.kind == "rank" then sub = L["next rank"]
    elseif s.profit and s.profit > 0 then
      sub = s.payback and (L["+%s per craft · pays off after %d crafts"]):format(ns.Util.Money(s.profit), s.payback)
        or (L["+%s per craft"]):format(ns.Util.Money(s.profit))
    elseif s.profit then sub = (L["loses %s per craft (skill only)"]):format(ns.Util.Money(-s.profit))
    else sub = L["no price known yet"] end
    local index = s.index
    data[#data + 1] = {
      icon = s.kind == "rank" and "Interface\\Icons\\INV_Misc_Book_09" or nil, item = s.item, text = s.name, sub = sub,
      color = s.kind == "rank" and { 1, 0.82, 0.45 } or nil, right = s.cost > 0 and ns.Util.Money(s.cost) or "",
      button = { L["Learn"], function()
        if BuyTrainerService then BuyTrainerService(index) end
        if ns.Checks then ns.Checks.Pass("trainerHelp", s.name) end
        C_Timer.After(0.5, refresh)
      end },
    }
  end
  if #data == 0 then
    data[1] = { icon = "Interface\\Icons\\INV_Misc_Note_01", text = L["Nothing worth learning here right now"], color = { 0.7, 0.7, 0.7 } }
  end
  rows:Set(data)
  card:SetHeight(36 + #data * 40)
  card:Show()
end
Trainer.Refresh = refresh

local function build()
  if card or not ClassTrainerFrame then return end
  card = ns.UI.Inset(ClassTrainerFrame, 330, 100, "hl")
  card:SetPoint("TOPLEFT", ClassTrainerFrame, "TOPRIGHT", 6, -24)
  title = ns.UI.Section(card, L["GOLDWEAVER · WORTH LEARNING"], 310)
  title:SetPoint("TOPLEFT", 10, -8)
  rows = ns.UI.IconRows(card, ROWS, 310, -30, 40)
end

ns:RegisterModule("Trainer", {
  Init = function()
    ns.Events:On("TRAINER_SHOW", function() C_Timer.After(0.4, function() pcall(build); pcall(refresh) end) end, "Trainer")
    ns.Events:On("TRAINER_UPDATE", function() C_Timer.After(0.2, function() pcall(refresh) end) end, "Trainer")
    ns.Events:On("TRAINER_CLOSED", function() if card then card:Hide() end end, "Trainer")
  end,
  SelfTest = function()
    return { { name = L["Trainer card"], ok = true, warn = card == nil, detail = card and L["built"] or L["only after the first trainer visit"] } }
  end,
})

-- Goldweaver: first-run card (docs/08-UX.md 4.8). One question per character: what does this character do?
local ADDON, ns = ...
local L = ns.L

local Onboarding = {}
ns.Onboarding = Onboarding

local card

local function create()
  if card then return end
  card = CreateFrame("Frame", "GoldweaverOnboarding", UIParent, "BackdropTemplate")
  card:SetSize(440, 120)
  card:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  card:SetFrameStrata("DIALOG")
  ns.UI.Skin(card, "hl")
  local title = ns.UI.Header(card, L["Goldweaver: What does this character do?"])
  title:SetPoint("TOPLEFT", 14, -12)
  local hint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -34); hint:SetWidth(410); hint:SetJustifyH("LEFT")
  hint:SetText(L["Main gathers on the road and sends materials. Processor crafts, disenchants and sells. Changeable later in the window (Team tab)."])
  local x = 14
  for _, def in ipairs({ { "main", L["Gathers on the road"], 140 }, { "processor", L[ns.Chars.ROLE_LABELS.processor], 150 }, { "none", L["Later"], 70 } }) do
    local b = ns.UI.Button(card, def[2], def[3], function()
      ns.Chars.SetRole(ns.Chars.FullName(), def[1])
      local me = ns.Chars.Current()
      if me then me.onboarded = true end
      card:Hide()
      if def[1] ~= "none" then ns.Print((L["Role set: %s. Tooltip, mailbox and profession guide are active. /gw opens the window."]):format(L[ns.Chars.ROLE_LABELS[def[1]]])) end
      if ns.HUD then ns.HUD.Refresh() end
    end)
    b:SetPoint("BOTTOMLEFT", x, 14)
    x = x + def[3] + 6
  end
end

function Onboarding.Check()
  local me = ns.Chars.Current()
  if not me or me.onboarded then return end
  if (me.role or "none") ~= "none" then
    me.onboarded = true
    if ns.Checks then ns.Checks.Pass("onboarding", "skipped, role was already set") end
    return
  end
  create()
  card:Show()
  if ns.Checks then ns.Checks.Pass("onboarding", "card shown") end
end

ns:RegisterModule("Onboarding", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(5, Onboarding.Check) end)
  end,
})

-- Goldweaver: first-run card (docs/08-UX.md 4.8). One question per character: what does this character do?
local ADDON, ns = ...

local Onboarding = {}
ns.Onboarding = Onboarding

local card

local function create()
  if card then return end
  card = CreateFrame("Frame", "GoldweaverOnboarding", UIParent, "BackdropTemplate")
  card:SetSize(440, 120)
  card:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
  card:SetFrameStrata("DIALOG")
  if card.SetBackdrop then
    card:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    card:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
    card:SetBackdropBorderColor(0.83, 0.66, 0.31, 1)
  end
  local title = ns.UI.Header(card, "Goldweaver: Was macht dieser Charakter?")
  title:SetPoint("TOPLEFT", 14, -12)
  local hint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -34); hint:SetWidth(410); hint:SetJustifyH("LEFT")
  hint:SetText("Main sammelt unterwegs und schickt Material. Verarbeiter stellt her, entzaubert und verkauft. Später änderbar im Fenster (Tab Charaktere).")
  local x = 14
  for _, def in ipairs({ { "main", "Sammelt unterwegs", 140 }, { "processor", "Verarbeitet & verkauft", 150 }, { "bank", "Bank", 60 }, { "none", "Später", 60 } }) do
    local b = ns.UI.Button(card, def[2], def[3], function()
      ns.Chars.SetRole(ns.Chars.FullName(), def[1])
      local me = ns.Chars.Current()
      if me then me.onboarded = true end
      card:Hide()
      if def[1] ~= "none" then ns.Print(("Rolle gesetzt: %s. Tooltip, Briefkasten und Berufe-Leitfaden sind aktiv. /gw öffnet das Fenster."):format(ns.Chars.ROLE_LABELS[def[1]])) end
      if ns.HUD then ns.HUD.Refresh() end
    end)
    b:SetPoint("BOTTOMLEFT", x, 14)
    x = x + def[3] + 6
  end
end

function Onboarding.Check()
  local me = ns.Chars.Current()
  if not me or me.onboarded then return end
  if (me.role or "none") ~= "none" then me.onboarded = true; return end
  create()
  card:Show()
end

ns:RegisterModule("Onboarding", {
  Init = function()
    ns.Events:On("PLAYER_LOGIN", function() C_Timer.After(5, Onboarding.Check) end)
  end,
})

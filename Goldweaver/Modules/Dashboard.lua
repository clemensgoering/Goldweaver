-- Goldweaver: recommendations for the Heute tab (docs/08-UX.md 4.7): at most three, each with a value and an action.
local ADDON, ns = ...

local Dashboard = {}
ns.Dashboard = Dashboard

-- Returns up to `limit` entries { text, value (copper or nil), action = fn|nil, color = {r,g,b} }
function Dashboard.Recommendations(limit)
  limit = limit or 3
  local out = {}
  local me = ns.Chars.Current()
  local unassigned = ns.Chars.Unassigned()
  if unassigned > 0 then
    out[#out + 1] = { text = ("%d Charakter(e) ohne Rolle: im Tab Charaktere Main oder Verarbeiter wählen"):format(unassigned), color = { 1, 0.6, 0.2 }, action = function() ns.UI.Open("chars") end }
  end

  -- mail
  if me and me.role == "main" then
    local count, value, target = ns.Mail.Pending()
    if count > 0 and target then
      out[#out + 1] = { text = ("%d Item(s) an %s schicken (Briefkasten: Anhängen, dann Senden)"):format(count, target.firstName or target.name), value = value, color = { 1, 1, 1 } }
    end
  end

  -- disenchant
  if ns.Destroy and ns.Destroy.CanDisenchant() then
    local queue = ns.Destroy.Queue()
    if #queue > 0 then
      local gain = 0
      for _, q in ipairs(queue) do gain = gain + q.gain end
      out[#out + 1] = { text = ("%d Item(s) entzaubern statt verkaufen"):format(#queue), value = gain, color = { 0.7, 0.5, 1 }, action = function() ns.Destroy.Show() end }
    end
  end

  -- skill-up and profit per profession
  if me and me.professions then
    for skillLine, p in pairs(me.professions) do
      if ns.Adapter.Book(skillLine) then
        local plan = ns.Planner.Plan(skillLine, me)
        if plan.best and not (plan.rank and plan.rank.capped) then
          local missing = 0
          for _, s in ipairs(plan.shopping or {}) do missing = missing + s.buy end
          out[#out + 1] = {
            text = ("%s: %s ×%d herstellen für den nächsten Skill-up%s"):format(p.name or "?", plan.best.recipe.name, plan.crafts or 1, missing > 0 and (", " .. missing .. " Materialien fehlen") or ""),
            value = plan.shoppingCost and -plan.shoppingCost or nil, color = { 0.6, 0.9, 1 },
            action = function() ns.UI.Open("berufe"); if ns.UI.SelectProfession then ns.UI.SelectProfession(skillLine) end end,
          }
        elseif plan.rank and plan.rank.capped and plan.rank.next then
          out[#out + 1] = { text = ("%s ist am Limit (%d): nächster Rang %s"):format(p.name or "?", plan.rank.skill, plan.rank.next.name), color = { 1, 0.9, 0.5 },
            action = function() ns.UI.Open("berufe"); if ns.UI.SelectProfession then ns.UI.SelectProfession(skillLine) end end }
        end
      end
    end
    local top = ns.CraftProfit.Top(1)[1]
    if top and top.margin > 0 then
      out[#out + 1] = { text = ("Lohnt sich: %s (%s) +%s je Stück"):format(top.recipe.name, top.professionName or "", ns.Util.Money(top.margin)), value = top.margin, color = { 0.6, 1, 0.6 } }
    end
  end

  while #out > limit do table.remove(out) end
  return out
end

ns:RegisterModule("Dashboard", {})

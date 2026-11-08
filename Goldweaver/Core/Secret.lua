-- Goldweaver: secret-value helpers (Midnight/Forever restrictions).
-- A secret value can be displayed but not compared, used as a table key, converted or saved.
local ADDON, ns = ...

ns.Secret = {}

local issecretvalue = issecretvalue

function ns.Secret.IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Returns true if any argument is secret.
function ns.Secret.Any(...)
  if not issecretvalue then return false end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return true end
  end
  return false
end

-- Returns v if it is safe to use, otherwise `fallback`.
function ns.Secret.Safe(v, fallback)
  if ns.Secret.IsSecret(v) then return fallback end
  return v
end

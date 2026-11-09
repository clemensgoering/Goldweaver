-- Locale coverage (no game needed):
--   1. every L["..."] key used in the addon has a German translation in Locales/deDE*.lua
--   2. each translation keeps the format placeholders of its key (same ones, same order)
--   3. no German text is left in code outside the locale files (umlauts or common German words in string literals);
--      a line that must keep game-client text is marked with the comment "locale-ok"
local ns, eq, T = ...

local here = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
local root = here:gsub("/tools/tests/[^/]*$", "")
local addon = root .. "/Goldweaver/"

local function tocFiles()
  local files = {}
  local f = assert(io.open(addon .. "Goldweaver.toc", "r"))
  for line in f:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
  end
  f:close()
  return files
end

local de = ns.Locale and ns.Locale.tables.deDE or {}
local function placeholders(s)
  local out = {}
  for p in s:gmatch("%%[%-%d%.]*[%a%%]") do out[#out + 1] = p end
  return table.concat(out, " ")
end

local GERMAN_WORDS = { "und", "nicht", "oder", "noch", "kein", "keine", "mit", "bei", "ist", "sind", "wird", "werden", "nach",
  "auf", "zum", "zur", "dem", "der", "das", "ein", "eine", "einen", "vom", "jetzt", "alle", "Fenster", "Beruf", "Berufe" }
local function looksGerman(s)
  if s:find("[\195][\132\150\156\164\182\188\159]") then return true end -- Ä Ö Ü ä ö ü ß
  local padded = " " .. s:gsub("[%p]", " ") .. " "
  for _, w in ipairs(GERMAN_WORDS) do if padded:find(" " .. w .. " ", 1, true) then return true end end
  return false
end

local missing, badFormat, leftovers, used = {}, {}, {}, 0
for _, rel in ipairs(tocFiles()) do
  if not rel:match("^Locales/") then
    local f = io.open(addon .. rel, "r")
    if f then
      local n = 0
      for line in f:lines() do
        n = n + 1
        local code = line:match("^%s*%-%-") and "" or line
        for key in code:gmatch("L%[\"(.-[^\\])\"%]") do
          used = used + 1
          if not de[key] then missing[#missing + 1] = rel .. ":" .. n .. "  " .. key
          elseif placeholders(de[key]) ~= placeholders(key) then badFormat[#badFormat + 1] = rel .. ":" .. n .. "  " .. key end
        end
        if not code:find("locale-ok", 1, true) then
          local stripped = code:gsub("L%[\".-[^\\]\"%]", "")
          for lit in stripped:gmatch("\"([^\"\\]*)\"") do
            if looksGerman(lit) then leftovers[#leftovers + 1] = rel .. ":" .. n .. "  \"" .. lit .. "\"" end
          end
        end
      end
      f:close()
    end
  end
end

local function report(title, list)
  if #list == 0 then return end
  print(("%s (%d):"):format(title, #list))
  for i = 1, math.min(#list, 40) do print("  " .. list[i]) end
  if #list > 40 then print(("  ... %d more"):format(#list - 40)) end
end
report("locale: keys without German translation", missing)
report("locale: translation changes the format placeholders", badFormat)
report("locale: German text left in code (translate via L or mark the line locale-ok)", leftovers)
eq(#missing, 0, "locale: every key translated")
eq(#badFormat, 0, "locale: placeholders kept")
eq(#leftovers, 0, "locale: no German text in code")
eq(used > 0, true, "locale: keys found")

-- switching works and falls back to the key
local before = ns.Locale.active
ns.Locale.Set("deDE")
eq(ns.L["Apprentice"], "Lehrling", "locale: German active")
eq(ns.L["__no such key__"], "__no such key__", "locale: fallback to key")
ns.Locale.Set("enUS")
eq(ns.L["Apprentice"], "Apprentice", "locale: English active")
eq(ns.Locale.Resolve("xxXX"), ns.Locale.Client(), "locale: unknown code resolves to game language")
ns.Locale.Set(before)
local _ = T

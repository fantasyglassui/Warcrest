--[[
  Warcrest
  Translations. The interface is written in English; the files in Locales/
  give German, French and Spanish for each piece of English text. Widgets pass
  their text through ns.T, so a label shows the translation when there is one
  and the English when there isn't.

  The language follows the game's (GetLocale) unless someone picks another in
  Settings (WarcrestDB.locale: "auto", "enUS", "deDE", "frFR" or "esES").
  Changing it takes effect after /reload, since windows are built once.
]]

local _, ns = ...

ns.LOCALES = ns.LOCALES or {}   -- filled by Locales/*.lua: [code] = { [english] = translation }
ns.LANGUAGES = {
  { "auto", "Game language" },
  { "enUS", "English" },
  { "deDE", "Deutsch" },
  { "frFR", "Français" },
  { "esES", "Español" },
}

-- Game locales that share a translation.
local SAME = { enGB = "enUS", esMX = "esES" }

local active -- the table in use, or nil for English

-- Capitals, including the accented letters the translations use
-- (string.upper only knows A to Z).
local ACCENTS = {
  ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ä"] = "Ä", ["ç"] = "Ç", ["é"] = "É", ["è"] = "È", ["ê"] = "Ê",
  ["ë"] = "Ë", ["í"] = "Í", ["î"] = "Î", ["ï"] = "Ï", ["ñ"] = "Ñ", ["ó"] = "Ó", ["ô"] = "Ô", ["ö"] = "Ö",
  ["ú"] = "Ú", ["û"] = "Û", ["ü"] = "Ü", ["œ"] = "Œ",
}
function ns.Upper(s)
  return (s:upper():gsub("\195[\128-\191]", ACCENTS):gsub("\197\147", ACCENTS))
end

function ns.LocaleCode()
  local pick = ns.db and ns.db.locale
  if not pick or pick == "auto" then
    pick = GetLocale and GetLocale() or "enUS"
  end
  return SAME[pick] or pick
end

function ns.ApplyLocale()
  local base = ns.LOCALES[ns.LocaleCode()]
  active = nil
  if not base then return end
  -- Column headings and small labels are shown in capitals: "AMOUNT" finds "Amount" too.
  active = {}
  -- "This month" wins over "this month" for THIS MONTH.
  for pass = 1, 2 do
    for en, tr in pairs(base) do
      local up = en:upper()
      local capital = en:sub(1, 1) ~= en:sub(1, 1):lower()
      if up ~= en and base[up] == nil and (pass == 1) ~= capital then active[up] = ns.Upper(tr) end
    end
  end
  for en, tr in pairs(base) do active[en] = tr end
end

-- The translation of a piece of English text (or the text itself).
function ns.T(s)
  if type(s) ~= "string" or s == "" then return s end
  if ns.localeSeen then -- tests collect what's shown
    ns.localeSeen[s] = true
    local inner = s:match("^|c%x%x%x%x%x%x%x%x(.-)|r$")
    if inner then ns.localeSeen[inner] = true end
  end
  if not active then return s end
  local t = active[s]
  if t then return t end
  -- Coloured text: translate what's inside the colour.
  local open, inner, close = s:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
  if inner and active[inner] then return open .. active[inner] .. close end
  return s
end

-- A translated format string: ns.TF("%d moved.", n).
function ns.TF(fmt, ...)
  return ns.T(fmt):format(...)
end

-- The same, picking the sentence for one or for several by n:
-- ns.TP(n, "%d item handed out.", "%d items handed out.", n).
function ns.TP(n, one, many, ...)
  return ns.TF(n == 1 and one or many, ...)
end

-- date() with the day and month names in your language (the game's date()
-- only knows English ones): ns.Date("%a %b %d", t) -> "Fr 15. Jan" style names.
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local DAYS_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }
local MONTHS_SHORT = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function ns.Date(fmt, t)
  if not active or not fmt:find("%%[aAbB]") then return date(fmt, t) end
  local d = date("*t", t)
  local names = { a = DAYS_SHORT[d.wday], A = DAYS[d.wday], b = MONTHS_SHORT[d.month], B = MONTHS[d.month] }
  fmt = fmt:gsub("%%([aAbB])", function(c) return (ns.T(names[c]):gsub("%%", "%%%%")) end)
  return date(fmt, t)
end

ns.OnLoad(ns.ApplyLocale)

-- A whole number with thousands separators in the player's language: 1,500 / 1.500 / 1 500.
local THOUSANDS = { deDE = ".", esES = ".", esMX = ".", frFR = " " }
function ns.Number(n)
  n = math.floor(tonumber(n) or 0)
  local s = tostring(math.abs(n))
  local sep = THOUSANDS[ns.LocaleCode and ns.LocaleCode() or GetLocale()] or ","
  s = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse():gsub("^%" .. sep, "")
  return (n < 0 and "-" or "") .. s
end


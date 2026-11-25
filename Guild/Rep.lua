--[[
  Warcrest
  Guild rep: standing with the guild, earned only by playing together.

    10 minutes grouped with a guildmate   +10  (both of you must report it)
    A raid night attended                 +100
    A guild boss kill                     +25
    A guild event attended                +50
    Helping a guildmate with a kill       +5
    A revenge kill                        +15
    A crafting order done for a guildmate +25  (to the crafter)

  At most 1,000 a day. Ranks: Neutral, Friendly 3,000, Honored 9,000,
  Revered 21,000, Exalted 42,000.

  Everything but grouped time is counted from records the guild already
  shares, so every addon works out the same numbers. Grouped time is one new
  shared record, GR { from, mins, names }: while you're grouped with
  guildmates, every 30 minutes (and when the group ends) your addon notes how
  long and with whom. Minutes count only where a guildmate's own GR names you
  for the same time.

  Rep only goes up: nobody can award or remove it, and each addon keeps the
  highest it has seen, so it doesn't drop when old records age out.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local VALUES = { raids = 100, bosses = 25, events = 50, assists = 5, revenge = 15 }
local CRAFT = 25
local GROUP_STEP, GROUP_REP = 600, 10 -- seconds, rep
local DAILY_CAP = 1000
local FLUSH = 1800    -- note grouped time at least this often
local MAX_SPAN = 1860 -- the longest one GR can count for (seconds)
local TICK = 60

ns.REP_DAILY_CAP = DAILY_CAP
ns.REP_RANKS = {
  { at = 0,     name = "Neutral" },
  { at = 3000,  name = "Friendly" },
  { at = 9000,  name = "Honored" },
  { at = 21000, name = "Revered" },
  { at = 42000, name = "Exalted" },
}

ns.OnLoad(function()
  ns.db.repPeak = ns.db.repPeak or {} -- member key -> the highest total seen
end)

------------------------------------------------------------------------
-- Ranks
------------------------------------------------------------------------
-- The rank for a total: index, name, its floor, the next rank's floor (nil at Exalted).
function ns.RepRank(total)
  local i = 1
  for j, r in ipairs(ns.REP_RANKS) do if total >= r.at then i = j end end
  local nxt = ns.REP_RANKS[i + 1]
  return i, ns.REP_RANKS[i].name, ns.REP_RANKS[i].at, nxt and nxt.at
end

------------------------------------------------------------------------
-- Grouped time: overlapping GR records
------------------------------------------------------------------------
local function namesSet(text)
  local set = {}
  for n in (text or ""):gmatch("[^,]+") do set[ns.Key(n)] = true end
  return set
end

-- author key -> list of { from, to, mates (key set), t }, sorted by from.
local function groupIndex()
  local by = {}
  for _, e in ipairs(ns.LedgerEntries("GR")) do
    local from = tonumber(e.from) or 0
    local span = math.min((tonumber(e.mins) or 0) * 60, MAX_SPAN, e.t - from + 60)
    if from > 0 and span >= 60 then
      local k = ns.Key(e.a)
      by[k] = by[k] or {}
      table.insert(by[k], { from = from, to = from + span, mates = namesSet(e.names), t = e.t })
    end
  end
  for _, list in pairs(by) do table.sort(list, function(a, b) return a.from < b.from end) end
  return by
end

-- The first index in a list sorted by from whose from is >= t.
local function firstFrom(list, t)
  local lo, hi = 1, #list + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if list[mid].from < t then lo = mid + 1 else hi = mid end
  end
  return lo
end

-- Seconds of one record that a guildmate's own records confirm (overlaps merged).
local function confirmed(by, me, g)
  local spans = {}
  for mate in pairs(g.mates) do
    local theirs = by[mate]
    if theirs and mate ~= me then
      for i = firstFrom(theirs, g.from - MAX_SPAN), #theirs do
        local o = theirs[i]
        if o.from >= g.to then break end
        if o.mates[me] then
          local a, b = math.max(g.from, o.from), math.min(g.to, o.to)
          if b > a then spans[#spans + 1] = { a, b } end
        end
      end
    end
  end
  table.sort(spans, function(x, y) return x[1] < y[1] end)
  local total, upTo = 0, -math.huge
  for _, s in ipairs(spans) do
    local a = math.max(s[1], upTo)
    if s[2] > a then total = total + (s[2] - a) end
    upTo = math.max(upTo, s[2])
  end
  return total
end

------------------------------------------------------------------------
-- Counting
------------------------------------------------------------------------
local stamp, groups, crafts
local memo = {} -- key -> { total, today }

local function fresh()
  local s = ns.LedgerVersion() .. "/" .. (ns.HistoryVersion and ns.HistoryVersion() or 0)
  if s ~= stamp then stamp, groups, crafts, memo = s, nil, nil, {} end
end

local function count(name)
  local k = ns.Key(name)
  local gains = {} -- { t, rep }
  local function add(times, rep)
    for _, t in ipairs(times or {}) do gains[#gains + 1] = { t, rep } end
  end
  add(ns.RaidNightsAttended and ns.RaidNightsAttended(name), VALUES.raids)
  add(ns.BossKillTimes and ns.BossKillTimes(name), VALUES.bosses)
  for _, stat in ipairs({ "events", "assists", "revenge" }) do
    add(ns.StatTimes and ns.StatTimes(name, stat), VALUES[stat])
  end
  crafts = crafts or (ns.CraftOrdersDone and ns.CraftOrdersDone() or {})
  add(crafts[k], CRAFT)
  -- Grouped time: whole 10 minutes, the leftover carried to the next record.
  groups = groups or groupIndex()
  local carry = 0
  for _, g in ipairs(groups[k] or {}) do
    carry = carry + confirmed(groups, k, g)
    while carry >= GROUP_STEP do
      gains[#gains + 1] = { g.from, GROUP_REP }
      carry = carry - GROUP_STEP
    end
  end
  -- At most DAILY_CAP a day, by the day each thing happened.
  table.sort(gains, function(a, b) return a[1] < b[1] end)
  local total, perDay = 0, {}
  for _, x in ipairs(gains) do
    local day = date("%Y-%m-%d", x[1])
    local got = math.min(x[2], DAILY_CAP - (perDay[day] or 0))
    if got > 0 then
      perDay[day] = (perDay[day] or 0) + got
      total = total + got
    end
  end
  return total, perDay[date("%Y-%m-%d", GetServerTime())] or 0
end

-- A member's guild rep: total, earned today, rank index, rank name, rank floor, next rank's floor.
function ns.Rep(name)
  if not name or name == "" then return 0, 0, ns.RepRank(0) end
  fresh()
  local k = ns.Key(Ambiguate(name, "short"))
  local m = memo[k]
  if not m then
    local total, today = count(Ambiguate(name, "short"))
    local peak = tonumber(ns.db.repPeak[k]) or 0
    if peak > total then total = peak elseif total > 0 then ns.db.repPeak[k] = total end
    m = { total, today }
    memo[k] = m
  end
  return m[1], m[2], ns.RepRank(m[1])
end

------------------------------------------------------------------------
-- Noting grouped time
------------------------------------------------------------------------
local session -- { from, last, names = { key = name } }

local function guildmatesInGroup()
  local out = {}
  local n = GetNumGroupMembers() or 0
  if n == 0 or not IsInGuild() then return out end
  local raid = IsInRaid()
  for i = 1, raid and n or (n - 1) do
    local name
    if raid then name = GetRaidRosterInfo(i) else name = UnitName("party" .. i) end
    name = ns.Usable(name)
    if type(name) == "string" and name ~= "" and not ns.IsMe(name) and ns.Member(name) then
      out[#out + 1] = Ambiguate(name, "short")
    end
  end
  return out
end

local function flush(s)
  s = s or session
  if not s then return end
  if s == session then session = nil end
  ns.db.repSession = nil
  local span = (s.last or s.from) - s.from
  if span < 60 then return end
  local names = {}
  for _, n in pairs(s.names) do names[#names + 1] = n end
  table.sort(names)
  if #names == 0 then return end
  local list = table.concat(names, ",")
  if #list > 180 then list = list:sub(1, 180):gsub(",[^,]*$", "") end
  ns.LedgerAdd("GR", { from = s.from, mins = math.floor(span / 60), names = list })
end
ns.FlushGroupedTime = function() flush() end

local function tick()
  local mates = guildmatesInGroup()
  local now = GetServerTime()
  if #mates == 0 then
    if session then flush() end
    return
  end
  if not session then session = { from = now, last = now, names = {} } end
  session.last = now
  for _, n in ipairs(mates) do session.names[ns.Key(n)] = n end
  ns.db.repSession = session -- saved, so a logout doesn't lose it
  if now - session.from >= FLUSH then
    local names = session.names
    flush()
    session = { from = now, last = now, names = {} }
    for key, n in pairs(names) do session.names[key] = n end
  end
end

table.insert(ns.OnGuildReady, function()
  -- Time from before a logout or reload.
  local saved = ns.db.repSession
  if saved and saved ~= session and saved.from then flush(saved) end
  if not ns.repTicker then ns.repTicker = C_Timer.NewTicker(TICK, tick) end
end)

------------------------------------------------------------------------
-- Ranking up
------------------------------------------------------------------------
local checking = false
local function checkRank()
  checking = false
  local me = UnitName("player")
  local total, _, rank, rankName = ns.Rep(me)
  local seen = ns.db.repRank
  ns.db.repRank = math.max(seen or 1, rank)
  if not seen or rank <= seen then return end
  local text = ns.TF("You're now %s with the guild (%s rep).", ns.T(rankName), ns.Number(total))
  ns.Notify(ns.COLOR .. text .. "|r", ns.COLOR .. text .. "|r", nil, nil, "rep")
  local c, show = ns.cfg, ns.db.show
  if IsInGuild() and c and c.enabled and c.types and c.types.achievement_chat and show and show.achievement_chat then
    ns.SendChat(ns.TF("[%s] %s is now %s with the guild!", ns.BRAND or "Warcrest", Ambiguate(me, "short"),
      ns.T(rankName)), "GUILD")
  end
end
local function later()
  if checking then return end
  checking = true
  C_Timer.After(3, checkRank)
end
ns.OnLedgerChanged(later)
local previousHook = ns.OnHistoryChanged
function ns.OnHistoryChanged()
  later()
  if previousHook then previousHook() end
end
table.insert(ns.OnGuildReady, later)
ns.OnEvent("PLAYER_ENTERING_WORLD", later) -- the first look is the baseline: no banner for rep from before

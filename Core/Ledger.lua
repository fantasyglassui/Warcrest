--[[
  Warcrest
  Ledger: the guild's shared record of raids, sign-ups and DKP.

  Every change is an entry that is never edited or deleted (a mistake is
  fixed with a new entry). Entries are sent to the guild when they're made,
  and guildmates fill in each other's gaps when they log in, day by day.

  Who may write what:
    - Raids, raid cancellations, DKP changes, raid sessions and bounties: officers only.
    - Sign-ups, wishlists, titles, boss kills and achievements earned: any guild
      member, in their own name.
  Officer entries are only accepted straight from the officer who made them,
  or passed along by another officer, so nobody can slip in fake DKP. For the
  same reason only officers answer catch-up requests; members ask again every
  15 minutes so they catch up whenever an officer is online.
]]

local _, ns = ...

local OFFICER_KINDS = { EV = true, EX = true, DK = true, RS = true, RE = true, KD = true,
  AT = true, SB = true, DS = true, UN = true, SN = true, SS = true, BO = true, BX = true, BC = true,
  RG = true, AG = true, RC = true, RM = true, WR = true,
  GG = true, GQ = true, RA = true }
-- Member entries that must come straight from the player who made them (or
-- be passed along by an officer), so nobody can make one in someone else's name.
local DIRECT_ONLY = { AL = true, WL = true, TI = true, BK = true, AE = true, AW = true, AB = true,
  GE = true, GX = true, GS = true, GT = true, PF = true, AN = true,
  PO = true, PV = true, PC = true, CO = true, CU = true, BP = true }
-- Fields of each kind, in message order.
local FIELDS = {
  EV = { "title", "start", "notes" },          -- a scheduled raid
  EX = { "ref" },                              -- a raid cancelled
  SU = { "ref", "status", "role" },            -- a sign-up
  DK = { "amount", "names", "reason" },        -- DKP added (or removed, if negative)
  RS = { "ref", "onTime", "hourly", "title", "boss" }, -- a raid session started
  RE = { "ref" },                              -- a raid session ended
  KD = { "ref" },                              -- a kill removed by an officer
  AT = { "ref", "names", "how" },              -- who attended a raid session ("raid" or "standby")
  SB = { "ref", "names", "state" },            -- standby added to ("on") or removed from ("off") a session
  DS = { "decay", "auto", "hidden" },          -- DKP rules: decay %, weekly decay, hidden bids
  UN = { "ref", "reason" },                    -- a DKP change undone by an officer
  AL = { "alt", "main", "state" },             -- alt link: "req" (from the alt), "ok" (from the main),
                                               -- "set" (officer) or "off" (unlink)
  SN = { "name", "parts" },                    -- a new DKP season starts; history before it is archived
  SS = { "ref", "amount", "names" },           -- a season's starting balances (parts of the snapshot)
  BK = { "boss", "name", "raid", "size", "names" }, -- a raid boss killed: encounter ID, boss, raid, guild members there
  AE = { "ach", "when" },                       -- an achievement a member earned, and when (kept with the guild,
                                               -- so it isn't lost with one player's saved data)
  AB = { "list" },                             -- achievements a member earned, several at once ("id.when,id.when")
  AN = { "list" },
  PO = { "q", "opts", "lasts" },                -- a guild poll: the question, answers ("a;b;c"), days it stays open
  PV = { "ref", "choice" },                    -- a vote in a poll (the latest counts)
  PC = { "ref" },
  CO = { "crafter", "recipe", "mats", "note" }, -- a crafting order: who should make it, the recipe, bringing materials
  CU = { "ref", "status" },
  BP = { "raid", "enc", "ok", "secs" },        -- a boss pull: the raid, the boss, killed ("1") or wiped, how long                    -- a crafting order changed: accepted, declined, done or cancelled                              -- a poll closed (by whoever asked, or an officer)                             -- a member's attunements and keys ("mc,ony,ubrs")
  AG = { "who", "list" },                      -- officer: achievements a member had earned, put back after
                                               -- they lost them ("id.when,id.when")
  AW = { "who", "list" },                      -- a guildmate vouching for achievements a member had earned;
                                               -- counts once two different guildmates agree
  GE = { "title", "start", "etype", "notes", "mins" }, -- a guild event (not a raid): any member can make one
  GX = { "ref" },                              -- a guild event cancelled (by whoever made it, or an officer)
  GS = { "ref", "status" },                    -- going to a guild event: "going", "maybe" or "no"
  GT = { "ref", "names" },                     -- who came to a guild event (taken by whoever made it, or an officer)
  PF = { "spec", "role", "days", "hours", "bday", "ilvl", "note" }, -- a member's profile (the latest one counts)
  RC = { "name", "class", "level", "note", "status" }, -- officer: a recruit and where they're up to
  RM = { "text" },                             -- officer: the guild's recruiting message
  WR = { "guild", "on" },
  RA = { "raid", "enc", "v", "part", "parts", "text" }, -- officer: a part of the raid assignments for a boss ("enc")
  GG = { "kind", "amount", "period" },         -- officer: a guild goal: what to count ("kills", ...), how many, "week" or "month"
  GQ = { "ref" },                              -- officer: a guild goal removed                      -- officer: an enemy guild marked as a rival ("1") or not ("0")
  TI = { "title" },                            -- the title a member shows: an achievement's id, or "" for none
  RG = { "ref", "name", "group" },             -- a raid plan: someone put in group 1-8, the bench (0), or out (-1)
  BO = { "target", "amount", "note" },         -- a bounty on an enemy player (DKP reward)
  BX = { "ref" },                              -- a bounty withdrawn
  BC = { "ref", "killer", "when" },            -- a bounty claimed: who killed the target, and when
  WL = { "item", "name", "prio" },             -- a wishlist item: item ID, name, "need", "want" or "off" (removed)
}
local NUMERIC = { start = true, amount = true, onTime = true, hourly = true, decay = true, boss = true,
  parts = true, size = true, when = true, group = true, mins = true, ilvl = true, level = true, part = true,
  choice = true, lasts = true, secs = true }
local CLAIM_WINDOW = 30

local counter = 0
local version = 0 -- goes up with every change, so caches can tell they're stale
local kindVersion = {} -- kind -> its own count of changes
local epoch = 0        -- goes up when everything may have changed (archiving)

-- Bumped whenever the record changes. Caches keep the version they were built at.
function ns.LedgerVersion() return version end

-- A stamp for some kinds of entry: the same until one of them changes, so a
-- cache of boss kills isn't rebuilt because someone was given DKP.
function ns.LedgerStamp(...)
  local s = tostring(epoch)
  for i = 1, select("#", ...) do s = s .. ":" .. (kindVersion[(select(i, ...))] or 0) end
  return s
end
local listeners = {}
local changePending = false



function ns.OnLedgerChanged(fn) listeners[#listeners + 1] = fn end

local function changed()
  if changePending then return end
  changePending = true
  C_Timer.After(0.5, function()
    changePending = false
    for _, fn in ipairs(listeners) do pcall(fn) end
    if ns.RefreshPanel then ns.RefreshPanel() end
  end)
end

------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------
local function encode(e)
  local parts = { "X", e.id, e.t, e.a, e.k }
  for _, f in ipairs(FIELDS[e.k]) do parts[#parts + 1] = e[f] ~= nil and tostring(e[f]) or "" end
  return parts
end

local function decode(p)
  local kind = p[5]
  local fields = FIELDS[kind]
  if not fields then return end
  local e = { id = p[2], t = tonumber(p[3]), a = p[4], k = kind }
  if not e.id or e.id == "" or not e.t or not e.a or e.a == "" then return end
  for i, f in ipairs(fields) do
    local v = p[5 + i] or ""
    if NUMERIC[f] then v = tonumber(v) or 0 end
    e[f] = v
  end
  return e
end

function ns.IsOfficerName(name)
  return ns.IsOfficerRank(ns.RankOf(name))
end

local function authorAllowed(e)
  if OFFICER_KINDS[e.k] then return ns.IsOfficerName(e.a) end
  return ns.RankOf(e.a) ~= nil
end

------------------------------------------------------------------------
-- Seasons: archiving old history so the record stays small and fast
------------------------------------------------------------------------
-- When a season starts, everyone's DKP is saved as the season's starting
-- balances. Once all of those have arrived, older history is removed:
-- DKP changes from before the season, and raids, sign-ups and attendance
-- more than 30 days before it. Alt links, DKP rules and kill removals are kept.
local KEEP_RAIDS = 30 * 86400
local BEFORE_SEASON = { DK = true, UN = true }                  -- folded into the starting balances
local RAID_HISTORY = { RS = true, RE = true, AT = true, SB = true, EV = true, EX = true, SU = true, RG = true,
  GE = true, GX = true, GS = true, GT = true }
local byKind     -- kind -> sorted list of entries, rebuilt after any change
local season     -- the current season, once all its starting balances are here

local function before(a, b)
  if a.t ~= b.t then return a.t < b.t end
  return a.id < b.id
end

local function findSeason()
  -- The newest season whose starting balances have all arrived.
  season = nil
  local seasons = byKind.SN or {}
  for i = #seasons, 1, -1 do
    local sn, parts = seasons[i], 0
    for _, ss in ipairs(byKind.SS or {}) do
      if ss.ref == sn.id then parts = parts + 1 end
    end
    if parts >= sn.parts then season = sn break end
  end
end

-- Put a new entry into its kind's sorted list. New entries are nearly always
-- the newest, so this walks back only a step or two; it saves sorting the
-- whole record again for every entry that arrives during a catch-up.
local function indexOne(e)
  local list = byKind[e.k]
  if not list then list = {}; byKind[e.k] = list end
  local i = #list
  while i > 0 and before(e, list[i]) do i = i - 1 end
  table.insert(list, i + 1, e)
end

local function index()
  byKind = {}
  for _, e in pairs(ns.db.ledger) do
    byKind[e.k] = byKind[e.k] or {}
    table.insert(byKind[e.k], e)
  end
  for _, list in pairs(byKind) do table.sort(list, before) end
  findSeason()
end

-- The current DKP season (complete), if any.
function ns.CurrentSeason()
  if not byKind then index() end
  return season
end

-- Would this entry be archived under the current season?
local function archived(e)
  local s = ns.CurrentSeason()
  if not s or e.k == "SN" then return false end
  if BEFORE_SEASON[e.k] then return e.t < s.t end
  if RAID_HISTORY[e.k] then return e.t < s.t - KEEP_RAIDS end
  if e.k == "SS" then return e.ref ~= s.id end -- an older season's starting balances
  return false
end

local function prune()
  local removed = 0
  for id, e in pairs(ns.db.ledger) do
    if archived(e) then ns.db.ledger[id] = nil; removed = removed + 1 end
  end
  if removed > 0 then byKind = nil; version = version + 1; epoch = epoch + 1 end
  return removed
end

local function store(e)
  if ns.db.ledger[e.id] then return false end
  if archived(e) then return false end -- history from before the season stays archived
  ns.db.ledger[e.id] = e
  version = version + 1
  kindVersion[e.k] = (kindVersion[e.k] or 0) + 1
  if byKind then indexOne(e) end
  if e.k == "SN" or e.k == "SS" then
    index()
    if season and prune() > 0 then index() end
  end
  return true
end

-- Make a new entry as yourself, keep it and send it to the guild.
function ns.LedgerAdd(kind, fields)
  if OFFICER_KINDS[kind] and not ns.IsAddonOfficer() then
    ns.Say("Only officers can do that.")
    return
  end
  counter = counter + 1
  local me = UnitName("player")
  local t = GetServerTime()
  local e = { id = me .. ":" .. t .. ":" .. counter, t = t, a = me, k = kind }
  for k, v in pairs(fields) do e[k] = v end
  for _, f in ipairs(FIELDS[kind]) do
    if NUMERIC[f] then e[f] = tonumber(e[f]) or 0 else e[f] = ns.Clean(e[f] or "") end
  end
  store(e)
  ns.Send(unpack(encode(e)))
  changed()
  return e
end

ns.OnLoad(function()
  ns.db.ledger = ns.db.ledger or {}
  index()
  if season and prune() > 0 then index() end
end)

-- Sort everything again (tests that rewrite entries' times use it).
function ns.ReindexLedger() byKind = nil; version = version + 1; epoch = epoch + 1 end

-- All entries of one kind, oldest first. The list is shared: read it, don't change it.
local EMPTY = {}
function ns.LedgerEntries(kind)
  if not byKind then index() end
  return byKind[kind] or EMPTY
end

local function receive(p, sender, retried)
  local e = decode(p)
  if not e or ns.BeforeRelease(e.t) then return end
  -- The roster isn't loaded yet: try again shortly.
  if (GetNumGuildMembers() or 0) == 0 and not retried then
    C_Timer.After(5, function() receive(p, sender, true) end)
    return
  end
  if ns.Key(sender) ~= ns.Key(e.a) then
    -- Passed along by someone other than its author: officer entries only from officers.
    if (OFFICER_KINDS[e.k] or DIRECT_ONLY[e.k]) and not ns.IsOfficerName(sender) then return end
  end
  if not authorAllowed(e) then return end
  if store(e) then changed() end
end

ns.OnMessage("X", function(p, sender) receive(p, sender) end)

------------------------------------------------------------------------
-- Filling gaps from guildmates, day by day
------------------------------------------------------------------------
local function dayOf(t) return math.floor(t / 86400) end

local shareMineWith

-- A number for an entry's id, so two records with the same number of entries
-- on a day can still be told apart.
local function idHash(id)
  local h = 0
  for i = 1, #id do h = (h * 31 + id:byte(i)) % 2147483647 end
  return h
end

-- day -> count, and day -> the sum of the day's id numbers.
local function digest()
  local d, sums = {}, {}
  for _, e in pairs(ns.db.ledger) do
    local day = dayOf(e.t)
    d[day] = (d[day] or 0) + 1
    sums[day] = ((sums[day] or 0) + idHash(e.id)) % 2147483647
  end
  return d, sums
end

local function stats()
  local n, newest = 0, 0
  for _, e in pairs(ns.db.ledger) do
    n = n + 1
    if e.t > newest then newest = e.t end
  end
  return n, newest
end

function ns.RequestLedger()
  local n, newest = stats()
  ns.Send("LQ", n, newest)
end

table.insert(ns.OnGuildReady, function()
  C_Timer.After(20, ns.RequestLedger)
  C_Timer.NewTicker(15 * 60, ns.RequestLedger)
end)

local claimed = {}

-- Your own profile and title: only you (or an officer) can pass them on, so
-- without an officer online a guildmate who logged in after you saved them
-- would never get them. Each guildmate who asks for a catch-up gets your
-- latest ones straight from you, once per session.
local OWN_KINDS = { "PF", "TI" }
local sharedWith = {}
shareMineWith = function(sender)
  local who = ns.fullName(sender)
  if sharedWith[who] then return end
  sharedWith[who] = true
  local me = ns.Key(UnitName("player"))
  local mine = {}
  for _, kind in ipairs(OWN_KINDS) do
    local list = ns.LedgerEntries(kind)
    for i = #list, 1, -1 do
      if ns.Key(list[i].a) == me then mine[#mine + 1] = list[i] break end
    end
  end
  if #mine == 0 then return end
  C_Timer.After(2 + math.random() * 20, function()
    for _, e in ipairs(mine) do ns.QueueTo(sender, unpack(encode(e))) end
  end)
end

-- Someone asked: if we have more, send them a summary of entries per day.
-- Only officers answer (see the note at the top).
ns.OnMessage("LQ", function(p, sender)
  if ns.IsMe(sender) then return end
  local theirCount, theirNewest = tonumber(p[2]) or 0, tonumber(p[3]) or 0
  local n, newest = stats()
  -- Someone far behind may have lost their saved data: put back any achievements they're missing.
  if theirCount < n / 2 and ns.RestoreAchievementsLater then ns.RestoreAchievementsLater() end
  shareMineWith(sender)
  if not ns.IsAddonOfficer() then return end
  -- Answer whenever the records differ: a member with more entries than us
  -- (their own achievements, say) can still be missing some of ours.
  if n == theirCount and newest == theirNewest then return end
  local who = ns.fullName(sender)
  local delay = 0.5 + math.random() * 2
  C_Timer.After(delay, function()
    local c = claimed[who]
    if c and GetTime() - c < CLAIM_WINDOW then return end
    ns.Send("LS", who)
    local chunk, len = {}, 0
    local counts, sums = digest()
    for day, count in pairs(counts) do
      local item = day .. ":" .. count .. ":" .. sums[day]
      if len + #item > 200 then
        ns.QueueTo(sender, "LG", table.concat(chunk, ","))
        chunk, len = {}, 0
      end
      chunk[#chunk + 1] = item
      len = len + #item + 1
    end
    if #chunk > 0 then ns.QueueTo(sender, "LG", table.concat(chunk, ",")) end
    ns.QueueTo(sender, "LGE")
  end)
end)

ns.OnMessage("LS", function(p)
  if p[2] then claimed[ns.fullName(p[2])] = GetTime() end
end)

local incoming = {}
local askedFor = {} -- "day:count:sum" -> true: days already asked for this session

ns.OnMessage("LG", function(p, sender)
  local d = incoming[sender] or {}
  incoming[sender] = d
  -- "day:count:sum" (or "day:count" from versions before 4.3.0)
  for item in (p[2] or ""):gmatch("[^,]+") do
    local day, count, sum = item:match("^(%d+):(%d+):?(%d*)$")
    if day then d[tonumber(day)] = { tonumber(count), tonumber(sum) } end
  end
end)

-- Summary complete: ask for the days where they have more than us.
ns.OnMessage("LGE", function(_, sender)
  local theirs = incoming[sender]
  incoming[sender] = nil
  if not theirs then return end
  local mine, sums = digest()
  local want = {}
  for day, v in pairs(theirs) do
    local count, sum = v[1], v[2]
    -- They have more that day, or not the same entries (they may have one we
    -- lack even with fewer in all).
    -- (Once per session for the same day and contents: records that can't
    -- match, like entries from people who've left, aren't asked for again.)
    local seen = day .. ":" .. count .. ":" .. tostring(sum)
    if (count > (mine[day] or 0) or (sum and sum ~= sums[day])) and not askedFor[seen] then
      askedFor[seen] = true
      want[#want + 1] = day
    end
  end
  for i = 1, #want, 25 do
    ns.QueueTo(sender, "LR", table.concat(want, ",", i, math.min(i + 24, #want)))
  end
end)

-- Send every entry from the days asked for.
ns.OnMessage("LR", function(p, sender)
  local days = {}
  for d in (p[2] or ""):gmatch("%d+") do days[tonumber(d)] = true end
  for _, e in pairs(ns.db.ledger) do
    if days[dayOf(e.t)] then ns.QueueTo(sender, unpack(encode(e))) end
  end
end)

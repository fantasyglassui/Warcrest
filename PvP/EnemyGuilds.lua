--[[
  Warcrest
  Enemy guilds: the war board.

  Which guild an enemy player is in comes from what guildmates see: their
  nameplates, targets and mouseovers. Each kill and death report carries the
  enemy's guild too, so every guildmate's addon learns it (a small directory,
  name -> guild, kept for 90 days).

  With that, kills and deaths are tallied by enemy guild: how many of theirs
  we've killed and how many of ours they have, over any period. Officers mark
  the guilds the guild is at war with as rivals. When three or more players of
  a rival guild are seen together, everyone is alerted where. The weekly recap
  says how each war went.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local KEEP_DAYS = 90
local MAX_NAMES = 6000
local SIGHTING_GROUP = 3        -- rival players seen together for an alert
local SIGHTING_WINDOW = 90      -- seconds they count as "together"
local SIGHTING_QUIET = 10 * 60  -- seconds before the same guild alerts again
local NAME_MAX = 40

local names = 0 -- how many are in the directory

-- Drop names not seen for 90 days, and keep only the most recently seen MAX_NAMES.
local function trim()
  local cutoff, n = time() - KEEP_DAYS * 86400, 0
  for k, e in pairs(ns.db.enemyGuilds) do
    if type(e) ~= "table" or (e.t or 0) < cutoff then ns.db.enemyGuilds[k] = nil else n = n + 1 end
  end
  if n > MAX_NAMES then
    local list = {}
    for k, e in pairs(ns.db.enemyGuilds) do list[#list + 1] = { k, e.t } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = MAX_NAMES + 1, #list do ns.db.enemyGuilds[list[i][1]] = nil end
    n = MAX_NAMES
  end
  names = n
end

ns.OnLoad(function()
  ns.db.enemyGuilds = ns.db.enemyGuilds or {} -- key -> { g = guild, t = when seen }
  trim()
end)

------------------------------------------------------------------------
-- The directory
------------------------------------------------------------------------
local version = 0
function ns.EnemyGuildsVersion() return version end

-- Note that an enemy player is in a guild (the newest sighting wins).
function ns.NoteEnemyGuild(name, guild, t)
  if not ns.db or type(name) ~= "string" or name == "" or type(guild) ~= "string" or guild == "" then return end
  if issecretvalue and (issecretvalue(name) or issecretvalue(guild)) then return end
  guild = guild:sub(1, NAME_MAX)
  t = tonumber(t) or time()
  local k = ns.Key(name)
  local e = ns.db.enemyGuilds[k]
  if e and e.t >= t and e.g == guild then return end
  if e and e.t > t then return end
  if e and e.g == guild then
    -- Seen again in the same guild: just move the time (at most once a minute),
    -- rather than make a new entry every second they're in sight.
    if t - e.t >= 60 then e.t = t end
    return
  end
  if e then
    e.g, e.t = guild, t
  else
    ns.db.enemyGuilds[k] = { g = guild, t = t }
    names = names + 1
    if names > MAX_NAMES * 1.25 then trim() end
  end
  version = version + 1
end

-- The guild an enemy player is in, or nil if nobody has seen one.
function ns.EnemyGuild(name)
  local e = ns.db and ns.db.enemyGuilds and name and ns.db.enemyGuilds[ns.Key(name)]
  return e and e.g or nil
end

------------------------------------------------------------------------
-- Rivals (officers): ledger kind WR { guild, on }
------------------------------------------------------------------------
local rivals, rivalsStamp
function ns.Rivals()
  local stamp = ns.LedgerStamp("WR")
  if rivals and rivalsStamp == stamp then return rivals end
  rivals, rivalsStamp = {}, stamp
  for _, e in ipairs(ns.LedgerEntries("WR")) do -- oldest first: the latest counts
    rivals[e.guild] = (e.on == "1") or nil
  end
  return rivals
end

function ns.IsRival(guild) return guild ~= nil and ns.Rivals()[guild] == true end

function ns.SetRival(guild, on)
  if not ns.IsAddonOfficer() then ns.Say("Only officers can mark rival guilds.") return end
  guild = strtrim(guild or ""):sub(1, NAME_MAX)
  if guild == "" then return end
  if ns.IsRival(guild) == (on and true or false) then return end
  return ns.LedgerAdd("WR", { guild = guild, on = on and "1" or "0" })
end

------------------------------------------------------------------------
-- The war: kills and deaths by enemy guild
------------------------------------------------------------------------
-- { { guild, kills = ours on them, deaths = theirs on us, last = time, rival }, ... }
-- for kills and deaths in [fromT, toT) (nil for no limit), rivals first, then busiest.
function ns.GuildWar(fromT, toT)
  fromT, toT = fromT or 0, toT or math.huge
  local by = {}
  local function row(guild)
    local r = by[guild]
    if not r then
      r = { guild = guild, kills = 0, deaths = 0, last = 0, rival = ns.IsRival(guild) }
      by[guild] = r
    end
    return r
  end
  for _, k in ipairs(ns.db.killLog or {}) do
    if k.t >= fromT and k.t < toT and not ns.KillHidden(k) then
      local g = k.vg or ns.EnemyGuild(k.victim)
      if g then
        local r = row(g)
        r.kills = r.kills + 1
        r.last = math.max(r.last, k.t)
      end
    end
  end
  for _, d in ipairs(ns.db.deathLog or {}) do
    if d.kind == "pvp" and d.killer and d.killer ~= "" and d.t >= fromT and d.t < toT then
      local g = d.kg or ns.EnemyGuild(d.killer)
      if g then
        local r = row(g)
        r.deaths = r.deaths + 1
        r.last = math.max(r.last, d.t)
      end
    end
  end
  local out = {}
  for _, r in pairs(by) do out[#out + 1] = r end
  -- Rivals with nothing in the period are listed too, so you can see them.
  for g in pairs(ns.Rivals()) do if not by[g] then out[#out + 1] = row(g) end end
  table.sort(out, function(a, b)
    if a.rival ~= b.rival then return a.rival end
    local ta, tb = a.kills + a.deaths, b.kills + b.deaths
    if ta ~= tb then return ta > tb end
    return a.guild < b.guild
  end)
  return out
end

-- How many members of an enemy guild we know, and who killed most of them.
function ns.EnemyGuildMembers(guild)
  local n = 0
  for _, e in pairs(ns.db.enemyGuilds or {}) do if e.g == guild then n = n + 1 end end
  return n
end

------------------------------------------------------------------------
-- Seeing enemy players, and rival sightings
------------------------------------------------------------------------
local seen = {}       -- guild -> { key -> GetTime() }
local alerted = {}    -- guild -> GetTime() of the last alert

local function scan()
  local now = GetTime()
  for _, unit in ipairs(ns.NearbyUnits(true)) do
    local name, isPlayer = ns.UnitInfo(unit)
    if name and isPlayer then
      local ok, guild = pcall(GetGuildInfo, unit)
      guild = ok and ns.Usable(guild) or nil
      if type(guild) == "string" and guild ~= "" then
        ns.NoteEnemyGuild(name, guild)
        if ns.IsRival(guild) then
          seen[guild] = seen[guild] or {}
          seen[guild][ns.Key(name)] = now
        end
      end
    end
  end
  -- Several of a rival guild together: tell the guild where.
  for guild, members in pairs(seen) do
    local count = 0
    for k, t in pairs(members) do
      if now - t <= SIGHTING_WINDOW then count = count + 1 else members[k] = nil end
    end
    if count >= SIGHTING_GROUP and (not alerted[guild] or now - alerted[guild] > SIGHTING_QUIET) then
      alerted[guild] = now
      local zone = GetRealZoneText() or GetZoneText() or ""
      ns.Send("WS", guild, count, zone)
    end
  end
end

ns.OnLoad(function() C_Timer.NewTicker(1, scan) end)

-- A guildmate saw a group of a rival guild.
local heard = {} -- guild -> GetTime()
ns.OnMessage("WS", function(p, sender)
  local guild, count, zone = p[2], tonumber(p[3]) or 0, p[4] or ""
  if not guild or guild == "" or not ns.IsRival(guild) then return end
  if heard[guild] and GetTime() - heard[guild] < SIGHTING_QUIET then return end
  heard[guild] = GetTime()
  alerted[guild] = GetTime()
  local show = ns.cfg and ns.cfg.enabled and ns.cfg.types.wanted and ns.db.show.wanted
  if not show then return end
  local text = ns.TF("Rival guild <%s> spotted: %d players in %s, seen by %s.", guild, count,
    zone ~= "" and zone or ns.T("an unknown zone"), Ambiguate(sender, "short"))
  ns.Notify("|cffff8c3a" .. text .. "|r", nil, nil, nil, "rival", "Rival guild")
end)

------------------------------------------------------------------------
-- The weekly recap: how each war went
------------------------------------------------------------------------
function ns.WarRecapLines(fromT, toT)
  local lines = {}
  for _, r in ipairs(ns.GuildWar(fromT, toT)) do
    if r.rival and (r.kills + r.deaths) > 0 then
      local verdict = r.kills > r.deaths and ns.T("won") or (r.kills < r.deaths and ns.T("lost") or ns.T("even"))
      lines[#lines + 1] = ns.TF("War with <%s>: we killed %d, they killed %d (%s).", r.guild, r.kills, r.deaths, verdict)
    end
  end
  return lines
end

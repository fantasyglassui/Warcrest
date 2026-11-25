--[[
  Warcrest
  Wanted: enemy players who keep killing guild members.

  Anyone who has killed guild members in world PvP at least a set number of
  times in the last 30 days is "wanted". When a guildmate's addon sees a
  wanted player (targeted, focused or on nameplates), the guild is alerted
  and the sighting is marked on the world map.

  With "remove when killed" on (the default), a guild member killing a wanted
  player claims the bounty: only guild deaths after that kill count toward
  them, so they drop off the list until they gank enough again.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local WINDOW = 30 * 24 * 60 * 60  -- kills counted from the last 30 days
local REPORT_EVERY = 10 * 60      -- seconds before the same player is reported again
local MAX_SIGHTINGS = 50
local SPOT_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t"
local SPOT_COLOR = "|cffff66ff"

local cache
local lastReported = {}  -- player key -> time a sighting was reported (by anyone)

ns.OnLoad(function()
  ns.db.spotted = ns.db.spotted or {}
  ns.db.wantedHidden = ns.db.wantedHidden or {}
  ns.db.bounties = ns.db.bounties or {} -- player key -> time a guild member last killed them
  if ns.db.wantedRemoveOnKill == nil then ns.db.wantedRemoveOnKill = true end
end)

-- When a guild member last killed this player (from the kill log, which is
-- shared between guildmates, and from kills seen live).
local function lastKilledTimes()
  local times = {}
  for k, t in pairs(ns.db.bounties) do times[k] = t end
  for _, kill in ipairs(ns.db.killLog or {}) do
    local k = ns.Key(kill.victim)
    if not times[k] or kill.t > times[k] then times[k] = kill.t end
  end
  return times
end

-- A guild member killed this player.
function ns.ClaimBounty(victim, t)
  local k = ns.Key(victim)
  t = t or time()
  if not ns.db.bounties[k] or t > ns.db.bounties[k] then ns.db.bounties[k] = t end
  cache = nil
end

function ns.SetWantedRemoveOnKill(on)
  ns.db.wantedRemoveOnKill = on and true or false
  cache = nil
  if ns.RefreshPanel then ns.RefreshPanel() end
end

-- The log changed: work the list out again next time it's needed.
local previousHook = ns.OnHistoryChanged
function ns.OnHistoryChanged()
  cache = nil
  if previousHook then previousHook() end
end

------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------
local function build()
  local threshold = ns.db.wantedThreshold or 3
  local cutoff = time() - WINDOW
  local killed = ns.db.wantedRemoveOnKill and lastKilledTimes() or {}
  local byKey = {}
  for _, e in ipairs(ns.db.deathLog) do
    if e.t < cutoff then break end -- newest first
    local k = e.killer and ns.Key(e.killer)
    -- Deaths before a guild member killed them don't count any more.
    local claimed = k and killed[k] and e.t <= killed[k]
    if ns.PVP_TYPES[e.kind] and e.killer and e.killer ~= "" and not claimed then
      local w = byKey[k]
      if not w then
        w = { key = k, name = Ambiguate(e.killer, "short"), count = 0, victims = {}, last = e.t,
          lastVictim = e.who, lastZone = e.zone }
        byKey[k] = w
      end
      w.count = w.count + 1
      w.victims[e.who] = true
    end
  end
  local list = {}
  for k, w in pairs(byKey) do
    if w.count >= threshold and not ns.db.wantedHidden[k] then
      local n = 0
      for _ in pairs(w.victims) do n = n + 1 end
      w.victimCount = n
      list[#list + 1] = w
    end
  end
  table.sort(list, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.last > b.last
  end)
  -- latest sighting of each
  for _, w in ipairs(list) do
    for _, s in ipairs(ns.db.spotted) do
      if ns.Key(s.name) == w.key then w.seen = s break end
    end
  end
  cache = { list = list, byKey = {} }
  for _, w in ipairs(list) do cache.byKey[w.key] = w end
  return cache
end

function ns.WantedList()
  return (cache or build()).list
end

function ns.WantedInfo(name)
  return (cache or build()).byKey[ns.Key(name)]
end

function ns.HideWanted(name)
  ns.db.wantedHidden[ns.Key(name)] = true
  cache = nil
  if ns.RefreshPanel then ns.RefreshPanel() end
end

function ns.UnhideAllWanted()
  wipe(ns.db.wantedHidden)
  cache = nil
  if ns.RefreshPanel then ns.RefreshPanel() end
end

function ns.SetWantedThreshold(n)
  ns.db.wantedThreshold = n
  cache = nil
  if ns.RefreshPanel then ns.RefreshPanel() end
end

function ns.HiddenWantedCount()
  local n = 0
  for _ in pairs(ns.db.wantedHidden) do n = n + 1 end
  return n
end

------------------------------------------------------------------------
-- Spotting wanted players
------------------------------------------------------------------------
local function report(name)
  local k = ns.Key(name)
  if lastReported[k] and GetTime() - lastReported[k] < REPORT_EVERY then return end
  lastReported[k] = GetTime()
  local c = ns.cfg
  if not (c.enabled and c.types.wanted) then return end
  local w = ns.WantedInfo(name)
  local zone = GetRealZoneText() or GetZoneText() or "Unknown"
  local mapID, x, y = ns.PlayerPosition()
  ns.Send("S", name, zone, w and w.count or 0, mapID or "", x and ("%.4f"):format(x) or "",
    y and ("%.4f"):format(y) or "", GetServerTime())
end

local function scan()
  if not (ns.db and ns.UnitInfo) then return end
  if #ns.WantedList() == 0 then return end
  for _, unit in ipairs(ns.NearbyUnits(true)) do
    local name, isPlayer = ns.UnitInfo(unit)
    if name and isPlayer and ns.WantedInfo(name) then report(name) end
  end
end

ns.OnLoad(function() C_Timer.NewTicker(1, scan) end)

------------------------------------------------------------------------
-- Sightings from guildmates
------------------------------------------------------------------------
function ns.DescribeSighting(s)
  local times = (s.count and s.count > 0) and (" " .. ns.TF("(killed guild members %d times)", s.count)) or ""
  return ns.TF("Wanted: %s%s spotted in %s by %s", s.name, times, s.zone, s.by)
end

function ns.ShowSighting(s, force)
  if not force then
    local c, show = ns.cfg, ns.db.show
    if not (c.enabled and c.types.wanted and show.wanted) then return end
  end
  local text = SPOT_COLOR .. ns.DescribeSighting(s) .. "|r"
  ns.Notify(SPOT_ICON .. " " .. text, SPOT_ICON .. " " .. text .. " " .. SPOT_ICON, nil, force, "wanted")
end

local SAME_SIGHTING = 60 -- seconds in which another report of the same enemy isn't shown again
local shownAt = {}      -- enemy key -> GetTime() of the last sighting shown
ns.OnMessage("S", function(p, sender)
  local name = p[2]
  if not name or name == "" then return end
  local k = ns.Key(name)
  lastReported[k] = GetTime() -- someone reported it; don't repeat it ourselves
  local mapID, x, y = tonumber(p[5]), tonumber(p[6]), tonumber(p[7])
  local valid = mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
  if p[8] and ns.BeforeRelease(p[8]) then return end
  local s = { t = tonumber(p[8]) or time(), name = Ambiguate(name, "short"), zone = p[3] or "Unknown",
    count = tonumber(p[4]) or 0, by = Ambiguate(sender, "short"),
    mapID = valid and mapID or nil, x = valid and x or nil, y = valid and y or nil }
  table.insert(ns.db.spotted, 1, s)
  while #ns.db.spotted > MAX_SIGHTINGS do table.remove(ns.db.spotted) end
  cache = nil
  -- Two guildmates can spot the same enemy at the same moment: say it once.
  if not shownAt[k] or GetTime() - shownAt[k] > SAME_SIGHTING then ns.ShowSighting(s) end
  shownAt[k] = GetTime()
  if ns.RefreshPanel then ns.RefreshPanel() end
  if ns.RefreshMapPins then ns.RefreshMapPins() end
end)

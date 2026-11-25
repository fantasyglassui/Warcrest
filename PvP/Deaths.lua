--[[
  Warcrest
  Deaths: works out how you died, tells the guild and shows guildmates' deaths.
  There is no death log tab or leaderboard; deaths are kept only for the map
  marks and the Wanted list. Only world PvP deaths and
  falling, drowning or fatigue are announced; deaths to monsters are not.

  WoW Forever doesn't let addons read the combat log, so the cause of death
  is worked out from where you were and what was around you. Each member's
  addon reports their own death.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local RECENT_WINDOW = 15  -- seconds an enemy you saw still counts
local LANDING_WINDOW = 0.6 -- a fall death happens the moment you land
local MIN_FALL = 1.0       -- seconds in the air: jumps and knockbacks are shorter
local MAX_LOG = 500

local lastHostile = { name = nil, time = 0 } -- enemy player
-- The current or most recent fall: when it started and ended, and whether
-- you were in combat at any point during it.
local fall = { start = 0, landed = 0, combat = false, active = false }
local inCombat = false
local mirrorTimers = {}
local lastDeathSent = 0

local personalDefaults = { sound = true, warning = true, mapPins = true, pinHours = 24,
  quietInstances = true, quietCombat = false, wantedThreshold = 3 }
local showDefaults = { pvp = true, environment = true, kill_world = true, kill_bg = false, kill_honor = true,
  wanted = true, level_ten = true, level_all = false, kill_streak = true, kill_revenge = true,
  achievement = true, boss_first = true, bounty = true, raid_recap = true, achievement_chat = true }

ns.OnLoad(function()
  local db = ns.db
  for k, v in pairs(personalDefaults) do
    if db[k] == nil then db[k] = v end
  end
  db.show = db.show or {}
  db.battlegrounds = nil
  db.show.battleground = nil
  for k, v in pairs(showDefaults) do
    if db.show[k] == nil then db.show[k] = v end
  end
  db.deathLog = db.deathLog or {}
  -- Only world PvP and falling/drowning/fatigue deaths are tracked: drop others
  -- (battleground, arena and monster deaths) recorded by older versions.
  local keep = {}
  for _, t in ipairs(ns.TYPES) do
    if t.group == "death" then keep[t.key] = true end
  end
  for i = #db.deathLog, 1, -1 do
    if not keep[db.deathLog[i].kind] then table.remove(db.deathLog, i) end
  end
  for _, k in ipairs({ "dungeon", "raid", "world", "battleground", "duel" }) do db.show[k] = nil end
  db.duelLog = nil -- duels were removed in 2.0.0

  -- Track falls, to spot deaths from falling.
  C_Timer.NewTicker(0.1, function()
    if not IsFalling then return end
    local ok, falling = pcall(IsFalling)
    falling = ok and ns.Usable(falling)
    if falling then
      if not fall.active then
        fall.active, fall.start, fall.combat = true, GetTime(), inCombat
      elseif inCombat then
        fall.combat = true
      end
    elseif fall.active then
      fall.active, fall.landed = false, GetTime()
    end
  end)
end)

------------------------------------------------------------------------
-- Watching what's around you
------------------------------------------------------------------------
local ATTACKER_WINDOW = 8 -- seconds a unit attacking you still counts as the killer
local attacker = { name = nil, isPlayer = false, time = 0 }

-- Name and player-ness of a hostile unit. Uses reaction rather than
-- "can I attack it", because nothing is attackable once you're dead.
-- (These run several times a second for every unit around you, so they're
-- plain functions called through pcall: no new closures or tables each time.)
local function hostileInfo(unit)
  if not UnitExists(unit) then return end
  local hostile = UnitCanAttack("player", unit)
  if not hostile then
    local reaction = UnitReaction("player", unit)
    hostile = reaction ~= nil and reaction <= 4
  end
  if hostile then return GetUnitName(unit, true), UnitIsPlayer(unit) end
end

local function unitInfo(unit)
  local ok, name, isPlayer = pcall(hostileInfo, unit)
  if ok then return ns.Usable(name), ns.Usable(isPlayer) end
end

local TARGET_OF = {} -- unit -> unit .. "target", made once
local function targetsMe(unit)
  local tot = TARGET_OF[unit]
  if not tot then tot = unit .. "target"; TARGET_OF[unit] = tot end
  return UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitIsUnit(tot, "player")
end

local function isTargetingMe(unit)
  local ok, res = pcall(targetsMe, unit)
  return ok and ns.Usable(res) and true or false
end

local function note(unit)
  local name, isPlayer = unitInfo(unit)
  if name and isPlayer then lastHostile.name, lastHostile.time = name, GetTime() end
end

-- The units around you: target, focus, (mouseover,) and every nameplate.
-- One shared list, refreshed at most every 0.2 seconds; read it straight away
-- and don't keep or change it.
local plates, platesAt = {}, -1
local function nameplateUnits()
  local now = GetTime()
  if now - platesAt < 0.2 then return plates end
  platesAt = now
  wipe(plates)
  if C_NamePlate and C_NamePlate.GetNamePlates then
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
      local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
      if unit then plates[#plates + 1] = unit end
    end
  end
  return plates
end

local nearby, nearbyMouse = {}, {}
function ns.NearbyUnits(withMouseover)
  local list = withMouseover and nearbyMouse or nearby
  wipe(list)
  list[1], list[2] = "target", "focus"
  if withMouseover then list[3] = "mouseover" end
  for _, u in ipairs(nameplateUnits()) do list[#list + 1] = u end
  return list
end

-- While you're in combat, remember which enemy is attacking you.
-- Enemy players win over creatures when both are on you.
local function scanAttackers()
  local ok, fighting = pcall(UnitAffectingCombat, "player")
  if not (ok and ns.Usable(fighting)) then return end
  local found, foundPlayer
  for _, unit in ipairs(ns.NearbyUnits()) do
    if isTargetingMe(unit) then
      local name, isPlayer = unitInfo(unit)
      if name and (not found or (isPlayer and not foundPlayer)) then
        found, foundPlayer = name, isPlayer and true or false
      end
    end
  end
  if found then
    attacker.name, attacker.isPlayer, attacker.time = found, foundPlayer, GetTime()
  end
end

ns.OnLoad(function() C_Timer.NewTicker(0.5, scanAttackers) end)

-- Shared with Kills.lua
ns.UnitInfo = unitInfo
ns.IsTargetingMe = isTargetingMe
ns.NameplateUnits = nameplateUnits

ns.OnEvent("PLAYER_TARGET_CHANGED", function() note("target") end)
ns.OnEvent("PLAYER_FOCUS_CHANGED", function() note("focus") end)
ns.OnEvent("NAME_PLATE_UNIT_ADDED", function(unit)
  local name, isPlayer = unitInfo(unit)
  if name and isPlayer then lastHostile.name, lastHostile.time = name, GetTime() end
end)

ns.OnEvent("PLAYER_REGEN_DISABLED", function()
  inCombat = true
  if fall.active then fall.combat = true end
end)
ns.OnEvent("PLAYER_REGEN_ENABLED", function() inCombat = false end)

ns.OnEvent("MIRROR_TIMER_START", function(timer, value, _, scale)
  if timer then
    mirrorTimers[timer] = { value = tonumber(value) or 0, scale = tonumber(scale) or -1, start = GetTime() }
  end
end)
ns.OnEvent("MIRROR_TIMER_STOP", function(timer)
  if timer then mirrorTimers[timer] = nil end
end)

local function timerRanOut(name)
  local t = mirrorTimers[name]
  if not t then return false end
  local remaining = t.value + t.scale * (GetTime() - t.start) * 1000
  return remaining <= 500
end

local function recent(slot)
  if slot.name and GetTime() - slot.time <= RECENT_WINDOW then return slot.name end
end

local function recentAttacker()
  if attacker.name and GetTime() - attacker.time <= ATTACKER_WINDOW then
    return attacker.name, attacker.isPlayer
  end
end

local function nearbyEnemyPlayer()
  for _, unit in ipairs({ "target", "focus" }) do
    local name, isPlayer = unitInfo(unit)
    if name and isPlayer then return name end
  end
  for _, unit in ipairs(nameplateUnits()) do
    local name, isPlayer = unitInfo(unit)
    if name and isPlayer then return name end
  end
  return recent(lastHostile)
end

------------------------------------------------------------------------
-- Working out how you died
------------------------------------------------------------------------
-- Returns kind, sub-type, killer, or nothing for deaths that aren't announced.
-- Only world PvP deaths and falls, drowning and fatigue are announced:
-- deaths to monsters, and in battlegrounds and arenas, are not.
-- A fall death: a real drop (not a jump or knockback), dying as you land,
-- with no combat during the fall, so damage over time and attacks don't count.
local function diedFromFall()
  local now = GetTime()
  local landedAt = fall.active and now or fall.landed
  local duration = landedAt - fall.start
  if fall.start == 0 or duration < MIN_FALL then return false end
  if now - landedAt > LANDING_WINDOW then return false end
  if fall.combat or inCombat then return false end
  if recentAttacker() then return false end
  return true
end

local function classify()
  local _, instanceType = IsInInstance()
  if instanceType == "pvp" or instanceType == "arena" then return end

  if timerRanOut("BREATH") then return "environment", "drowning" end
  if timerRanOut("EXHAUSTION") then return "environment", "fatigue" end
  if diedFromFall() then return "environment", "falling" end

  if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then return end

  local who, whoIsPlayer = recentAttacker()
  if who then
    -- We saw what was attacking you: a player means PvP, a monster means skip.
    if whoIsPlayer then return "pvp", "world", who end
    return
  end
  -- Nothing seen attacking you: count it as PvP if you were flagged with an enemy player nearby.
  local enemy = nearbyEnemyPlayer()
  if enemy and ns.Usable(UnitIsPVP("player")) then return "pvp", "world", enemy end
end

ns.OnEvent("PLAYER_DEAD", function()
  if GetTime() - lastDeathSent < 5 then return end
  lastDeathSent = GetTime()
  local kind, sub, killer = classify()
  if not kind then return end
  -- (Recorded even with the alert turned off: deaths count for nemesis and
  -- revenge. The alert settings only decide what's shown.)
  local zone = GetRealZoneText() or GetZoneText() or "Unknown"
  local mapID, x, y = ns.PlayerPosition()
  C_Timer.After(0.5, function()
    ns.Send("D2", kind, sub or "", zone, killer or "", UnitLevel("player") or 0,
      mapID or "", x and ("%.4f"):format(x) or "", y and ("%.4f"):format(y) or "", GetServerTime(),
      killer and ns.EnemyGuild and ns.EnemyGuild(killer) or "")
  end)
end)

------------------------------------------------------------------------
-- Showing and logging deaths
------------------------------------------------------------------------
local KIND_COLOR = {
  pvp = "|cffff4040",
  environment = "|cff66bbff",
}
local ENVIRONMENT = { falling = "fell to their death", drowning = "drowned", fatigue = "died of fatigue" }

function ns.DescribeDeath(e)
  local line
  if e.kind == "environment" then
    line = ns.TF("%s %s in %s", e.who, ns.T(ENVIRONMENT[e.sub] or "died"), e.zone)
  elseif e.killer and e.killer ~= "" then
    line = ns.TF("%s was killed by %s in %s", e.who, e.killer, e.zone)
  elseif ns.PVP_TYPES[e.kind] then
    line = ns.TF("%s died in PvP in %s", e.who, e.zone)
  else
    line = ns.TF("%s died in %s", e.who, e.zone)
  end
  return line
end

function ns.DeathColor(e)
  if e.kind == "pvp" and ns.AccessChatColor("death") then return ns.AccessChatColor("death") end
  return KIND_COLOR[e.kind] or "|cffffffff"
end

ns.SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t"

-- A skull in front of PvP deaths.
function ns.DeathIcon(e)
  return ns.PVP_TYPES[e.kind] and (ns.SKULL .. " ") or ""
end

function ns.ShowAlert(e, force)
  if not force then
    local c, show = ns.cfg, ns.db.show
    if not (c.enabled and c.types[e.kind] and show[e.kind]) then return end
  end
  local text = ns.DeathColor(e) .. ns.DescribeDeath(e) .. "|r"
  local warning = text
  if ns.PVP_TYPES[e.kind] then warning = ns.SKULL .. " " .. text .. " " .. ns.SKULL end
  ns.Notify(ns.DeathIcon(e) .. text, warning, nil, force, "death")
end

-- Insert into a newest-first log, keeping it in time order.
function ns.InsertSorted(log, entry, max)
  local i = 1
  while log[i] and log[i].t > entry.t do i = i + 1 end
  table.insert(log, i, entry)
  while #log > max do table.remove(log) end
end

local SAME_EVENT = 90 -- seconds: two reports of one death closer than this are the same death

-- Adds a death to the log unless it's already there. Returns true if added.
function ns.MergeDeath(e)
  if ns.BeforeRelease(e.t) then return false end
  local who = ns.Key(e.who)
  for _, old in ipairs(ns.db.deathLog) do
    if ns.Key(old.who) == who and old.kind == e.kind and math.abs(old.t - e.t) <= SAME_EVENT then
      if not old.mapID and e.mapID then old.mapID, old.x, old.y = e.mapID, e.x, e.y end
      if e.kg and not old.kg then old.kg = e.kg end
      return false
    end
  end
  ns.InsertSorted(ns.db.deathLog, e, MAX_LOG)
  if ns.OnHistoryChanged then ns.OnHistoryChanged() end
  return true
end

local function record(e)
  if not ns.MergeDeath(e) then return end
  ns.ShowAlert(e)
  if ns.OnLiveDeath then ns.OnLiveDeath(e) end -- a streak ended?
  if ns.RefreshPanel then ns.RefreshPanel() end
  if ns.RefreshMapPins then ns.RefreshMapPins() end
end

local VALID = {}
for _, t in ipairs(ns.TYPES) do
  if t.group == "death" then VALID[t.key] = true end
end

ns.OnMessage("D2", function(parts, sender)
  local kind = parts[2]
  if not VALID[kind] then return end
  local mapID, x, y = tonumber(parts[7]), tonumber(parts[8]), tonumber(parts[9])
  local valid = mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
  local kg = parts[11] ~= "" and parts[11] or nil -- the killer's guild, from 3.7
  local t = tonumber(parts[10]) or time()
  if kg and parts[5] and parts[5] ~= "" and ns.NoteEnemyGuild then ns.NoteEnemyGuild(parts[5], kg, t) end
  record({
    t = t, who = Ambiguate(sender, "short"), kind = kind, sub = parts[3] or "",
    zone = parts[4] or "Unknown", killer = parts[5] or "", level = tonumber(parts[6]) or 0,
    mapID = valid and mapID or nil, x = valid and x or nil, y = valid and y or nil, kg = kg,
  })
end)

-- Alerts from version 1.2 (PvP only). Battleground and arena deaths are ignored.
ns.OnMessage("D", function(parts, sender)
  if parts[2] ~= "world" then return end
  record({
    t = time(), who = Ambiguate(sender, "short"), kind = "pvp", sub = "world",
    zone = parts[3] or "Unknown", killer = parts[4] or "", level = 0,
  })
end)

local testIndex = 0
local SAMPLES = {
  { kind = "pvp", sub = "world", killer = "Testenemy" },
  { kind = "environment", sub = "falling", killer = "" },
  { kill = true },
  { spot = true },
  { level = true },
}

-- Shows one sample alert of each death type in turn. Not logged.
function ns.TestAlert()
  testIndex = testIndex % #SAMPLES + 1
  local s = SAMPLES[testIndex]
  if s.spot then
    if ns.ShowSighting then
      ns.ShowSighting({ name = "Testganker", zone = GetRealZoneText() or "Somewhere", count = 4,
        by = UnitName("player") }, true)
    end
    return
  end
  if s.level then
    if ns.ShowLevel then ns.ShowLevel(UnitName("player"), ns.MaxLevel and ns.MaxLevel() or 60, true) end
    return
  end
  if s.kill then
    if ns.ShowKill then
      ns.ShowKill({ killers = { UnitName("player"), "Guildmate" }, victim = "Testenemy",
        kind = "kill_world", zone = GetRealZoneText() or "Somewhere" }, true)
    end
    return
  end
  ns.ShowAlert({ t = time(), who = UnitName("player"), kind = s.kind, sub = s.sub,
    zone = GetRealZoneText() or "Somewhere", killer = s.killer, level = UnitLevel("player") }, true)
end

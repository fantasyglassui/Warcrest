--[[
  Warcrest
  World buffs and world bosses (Events > World buffs).

  World buffs: when a guildmate with Warcrest gets one of the buffs an NPC
  hands out to everyone around (the Onyxia or Nefarian head, Rend's head, the
  Heart of Hakkar) with nearly its full time left, it has just been dropped.
  Their addon tells the guild where and when. This goes by the buff itself, so
  it works in every language.

  World bosses: when a guildmate sees Azuregos, Lord Kazzak or one of the
  Emerald Dragons (target, focus, mouseover or nameplate), the guild hears
  where, and whether it was alive.

  Both are plain messages (WB, WX), kept for a day. At login, Warcrest asks
  (WBQ) and guildmates who know of recent ones send them.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local KEEP = 24 * 3600          -- forget drops and sightings after a day
local SAME_DROP = 10 * 60       -- reports of one buff this close together are one drop
local SAME_SIGHTING = 10 * 60   -- one sighting of a boss per 10 minutes (unless it died)
local FRESH = 60                -- a buff with at most this much time gone has just dropped
local ALERT_WITHIN = 5 * 60     -- only alert for drops and sightings from the last 5 minutes

ns.WORLD_BUFFS = {
  { key = "dragonslayer", spell = 22888, duration = 7200, name = "Rallying Cry of the Dragonslayer",
    from = "Onyxia or Nefarian's head" },
  { key = "warchief", spell = 16609, duration = 3600, name = "Warchief's Blessing", from = "Rend's head" },
  { key = "zandalar", spell = 24425, duration = 7200, name = "Spirit of Zandalar", from = "the Heart of Hakkar" },
}
local BUFF = {}
for _, b in ipairs(ns.WORLD_BUFFS) do BUFF[b.key] = b end

ns.WORLD_BOSSES = {
  { key = "azuregos", npc = 6109, name = "Azuregos" },
  { key = "kazzak", npc = 12397, name = "Lord Kazzak" },
  { key = "ysondre", npc = 14887, name = "Ysondre" },
  { key = "lethon", npc = 14888, name = "Lethon" },
  { key = "emeriss", npc = 14889, name = "Emeriss" },
  { key = "taerar", npc = 14890, name = "Taerar" },
}
local BOSS, BOSS_BY_NPC = {}, {}
for _, b in ipairs(ns.WORLD_BOSSES) do BOSS[b.key] = b; BOSS_BY_NPC[b.npc] = b end

local function store()
  local s = ns.db.worldBuffs
  if type(s) ~= "table" then s = {}; ns.db.worldBuffs = s end
  s.drops = s.drops or {}       -- { key, t, zone, by }, newest first
  s.bosses = s.bosses or {}     -- { key, t, zone, by, dead }, newest first
  return s
end

local function prune(list)
  local cutoff = time() - KEEP
  for i = #list, 1, -1 do
    if (tonumber(list[i].t) or 0) < cutoff then table.remove(list, i) end
  end
end

-- Alerts for world buffs and bosses: on unless the player turns them off (on the view).
function ns.WorldBuffAlertsOn() return ns.db.worldBuffAlerts ~= false end

local function alert(text, title)
  if not ns.WorldBuffAlertsOn() then return end
  ns.Notify(ns.COLOR .. text .. "|r", nil, nil, nil, "worldbuff", title)
end

------------------------------------------------------------------------
-- Drops
------------------------------------------------------------------------
-- Note a drop. Returns true if it's new (not a repeat of one already known).
function ns.NoteWorldBuff(key, t, zone, by)
  local b = BUFF[key]
  t = tonumber(t)
  if not b or not t or t > time() + 300 or t < time() - KEEP then return false end
  local s = store()
  for _, d in ipairs(s.drops) do
    if d.key == key and math.abs(d.t - t) <= SAME_DROP then return false end
  end
  zone = type(zone) == "string" and zone:sub(1, 60) or ""
  by = type(by) == "string" and Ambiguate(by, "short"):sub(1, 30) or ""
  table.insert(s.drops, 1, { key = key, t = t, zone = zone, by = by })
  table.sort(s.drops, function(a, c) return a.t > c.t end)
  prune(s.drops)
  if time() - t <= ALERT_WITHIN and not ns.IsMe(by) then
    alert(ns.TF("%s dropped in %s (seen by %s).", ns.T(b.name), zone ~= "" and zone or ns.T("an unknown zone"), by),
      "World buff")
  end
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

-- The last drop of each buff: { [key] = { t, zone, by } }.
function ns.LastWorldBuffs()
  local out = {}
  for _, d in ipairs(store().drops) do
    if not out[d.key] then out[d.key] = d end
  end
  return out
end

local function auraOf(spell)
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    return C_UnitAuras.GetPlayerAuraBySpellID(spell)
  end
end

-- Look at your own buffs: one of them just dropped?
local lastSeen = {} -- key -> time we last noticed it on us (so a buff seen once isn't sent again)
local function checkMine()
  for _, b in ipairs(ns.WORLD_BUFFS) do
    local ok, aura = pcall(auraOf, b.spell)
    local ends = ok and type(aura) == "table" and ns.Usable(aura.expirationTime)
    if type(ends) == "number" and ends > 0 then
      local left = ends - GetTime()
      if left >= b.duration - FRESH and (not lastSeen[b.key] or time() - lastSeen[b.key] > SAME_DROP) then
        lastSeen[b.key] = time()
        local t = time() - math.max(0, math.floor(b.duration - left))
        local zone = GetRealZoneText() or ""
        if ns.NoteWorldBuff(b.key, t, zone, UnitName("player")) then
          ns.Send("WB", b.key, t, zone)
        end
      end
    end
  end
end

local auraQueued = false
ns.OnEvent("UNIT_AURA", function(unit)
  if unit ~= "player" or auraQueued then return end
  auraQueued = true
  C_Timer.After(0.5, function() auraQueued = false; checkMine() end)
end)

ns.OnMessage("WB", function(p, sender)
  if ns.IsMe(sender) then return end
  -- p[5]: who saw it, when a guildmate passes on a drop they heard about.
  ns.NoteWorldBuff(p[2], p[3], p[4], (p[5] and p[5] ~= "") and p[5] or sender)
end)

------------------------------------------------------------------------
-- World bosses
------------------------------------------------------------------------
function ns.NoteBossSighting(key, t, zone, by, dead)
  local b = BOSS[key]
  t = tonumber(t)
  if not b or not t or t > time() + 300 or t < time() - KEEP then return false end
  dead = dead == true or dead == "1"
  local s = store()
  for _, d in ipairs(s.bosses) do
    if d.key == key and math.abs(d.t - t) <= SAME_SIGHTING and (d.dead or not dead) then return false end
  end
  zone = type(zone) == "string" and zone:sub(1, 60) or ""
  by = type(by) == "string" and Ambiguate(by, "short"):sub(1, 30) or ""
  table.insert(s.bosses, 1, { key = key, t = t, zone = zone, by = by, dead = dead })
  table.sort(s.bosses, function(a, c) return a.t > c.t end)
  prune(s.bosses)
  if time() - t <= ALERT_WITHIN and not ns.IsMe(by) then
    local text = dead and ns.TF("%s is dead in %s (seen by %s).", ns.T(b.name), zone, by)
      or ns.TF("%s is up in %s (seen by %s).", ns.T(b.name), zone, by)
    alert(text, "World boss")
  end
  if ns.RefreshPanel then ns.RefreshPanel() end
  return true
end

function ns.BossSightings() return store().bosses end

local function npcOf(unit)
  local guid = UnitGUID(unit)
  if type(guid) ~= "string" then return end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" then return tonumber(id) end
end

local seenAt = {} -- key -> { t, dead }: what this client last reported
local function scan()
  if not ns.NearbyUnits then return end
  for _, unit in ipairs(ns.NearbyUnits(true)) do
    local ok, npc = pcall(npcOf, unit)
    local b = ok and ns.Usable(npc) and BOSS_BY_NPC[npc]
    if b then
      local okDead, dead = pcall(UnitIsDead, unit)
      dead = okDead and ns.Usable(dead) and true or false
      local last = seenAt[b.key]
      if not last or time() - last.t > SAME_SIGHTING or (dead and not last.dead) then
        seenAt[b.key] = { t = time(), dead = dead }
        local zone = GetRealZoneText() or ""
        if ns.NoteBossSighting(b.key, time(), zone, UnitName("player"), dead) then
          ns.Send("WX", b.key, time(), zone, dead and "1" or "0")
        end
      end
    end
  end
end

ns.OnMessage("WX", function(p, sender)
  if ns.IsMe(sender) then return end
  ns.NoteBossSighting(p[2], p[3], p[4], (p[6] and p[6] ~= "") and p[6] or sender, p[5])
end)

------------------------------------------------------------------------
-- Catching up at login
------------------------------------------------------------------------
ns.OnMessage("WBQ", function(_, sender)
  if ns.IsMe(sender) then return end
  local s = store()
  prune(s.drops); prune(s.bosses)
  if #s.drops == 0 and #s.bosses == 0 then return end
  -- A little later, and only the newest of each, so a guild doesn't all answer at once.
  C_Timer.After(2 + math.random() * 10, function()
    for key, d in pairs(ns.LastWorldBuffs()) do ns.QueueTo(sender, "WB", key, d.t, d.zone, d.by) end
    local sent = {}
    for _, d in ipairs(s.bosses) do
      if not sent[d.key] then
        sent[d.key] = true
        ns.QueueTo(sender, "WX", d.key, d.t, d.zone, d.dead and "1" or "0", d.by)
      end
    end
  end)
end)

ns.OnLoad(function()
  local s = store()
  prune(s.drops); prune(s.bosses)
  C_Timer.NewTicker(2, scan)
  C_Timer.After(20, function() ns.Send("WBQ") end)
end)

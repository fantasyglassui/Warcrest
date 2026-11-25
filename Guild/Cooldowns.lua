--[[
  Warcrest
  Profession cooldowns (Guild > Crafters > Cooldowns): who can do a
  transmute, make Mooncloth or Cured Rugged Hide, or use a Salt Shaker, and
  when each is ready.

  Each member's addon reads their own cooldowns from the game (only the ones
  they know or carry) and sends them to the guild (CD) when they change.
  At login Warcrest asks (CDQ) and guildmates send theirs.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

ns.TRACKED_COOLDOWNS = {
  { key = "transmute", label = "Transmute", spells = { 17187, 11479, 11480, 17559, 17560, 17561, 17562, 17563, 17564,
    17565, 17566, 25146 } },
  { key = "mooncloth", label = "Mooncloth", spells = { 18560 } },
  { key = "hide", label = "Cured Rugged Hide", spells = { 19047 } },
  { key = "salt", label = "Salt Shaker", item = 15846 },
}
local TRACKED = {}
for _, c in ipairs(ns.TRACKED_COOLDOWNS) do TRACKED[c.key] = c end

local function store()
  local s = ns.db.cooldowns
  if type(s) ~= "table" then s = {}; ns.db.cooldowns = s end
  return s -- member key -> { name, list = { key -> ready at (0: ready) } }
end

local function spellCooldown(id)
  if C_Spell and C_Spell.GetSpellCooldown then
    local c = C_Spell.GetSpellCooldown(id)
    if type(c) == "table" then return c.startTime, c.duration end
  end
  if GetSpellCooldown then return GetSpellCooldown(id) end
end

local function itemCooldown(id)
  if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(id) end
  if GetItemCooldown then return GetItemCooldown(id) end
end

-- When a running cooldown ends, as a time() (0: ready now).
local function readyAt(start, duration)
  start, duration = ns.Usable(start), ns.Usable(duration)
  if type(start) ~= "number" or type(duration) ~= "number" or start <= 0 or duration <= 2 then return 0 end
  local left = start + duration - GetTime()
  if left <= 0 then return 0 end
  return time() + math.floor(left + 0.5)
end

-- Your own: { key -> ready at } for the cooldowns you have.
function ns.MyCooldowns()
  local out = {}
  for _, c in ipairs(ns.TRACKED_COOLDOWNS) do
    if c.spells then
      for _, id in ipairs(c.spells) do
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and ns.Usable(known) then
          local ok2, s, d = pcall(spellCooldown, id)
          local at = ok2 and readyAt(s, d) or 0
          if out[c.key] == nil or at > out[c.key] then out[c.key] = at end
        end
      end
    elseif c.item then
      local ok, n = pcall(GetItemCount, c.item)
      if ok and (ns.Usable(n) or 0) > 0 then
        local ok2, s, d = pcall(itemCooldown, c.item)
        out[c.key] = ok2 and readyAt(s, d) or 0
      end
    end
  end
  return out
end

local function note(name, key, at)
  if not TRACKED[key] then return end
  at = tonumber(at)
  if not at or at < 0 or at > time() + 8 * 86400 then return end
  local s = store()
  local k = ns.Key(name)
  local e = s[k] or { name = Ambiguate(name, "short"), list = {} }
  s[k] = e
  e.list[key] = at
  if ns.RefreshCrafters then ns.RefreshCrafters() end
end

-- Everyone's: { { name, key, label, readyAt }, ... }, ready first, then soonest.
function ns.GuildCooldowns()
  local out = {}
  local me = ns.Key(UnitName("player"))
  local mine = ns.MyCooldowns()
  for key, at in pairs(mine) do
    out[#out + 1] = { name = UnitName("player"), key = key, label = TRACKED[key].label, readyAt = at }
  end
  for k, e in pairs(store()) do
    if k ~= me and (not ns.Member or ns.Member(e.name) ~= nil or not IsInGuild()) then
      for key, at in pairs(e.list) do
        if TRACKED[key] then out[#out + 1] = { name = e.name, key = key, label = TRACKED[key].label, readyAt = at } end
      end
    end
  end
  local now = time()
  table.sort(out, function(a, b)
    local ra, rb = a.readyAt <= now, b.readyAt <= now
    if ra ~= rb then return ra end
    if a.readyAt ~= b.readyAt and not ra then return a.readyAt < b.readyAt end
    if a.label ~= b.label then return a.label < b.label end
    return a.name < b.name
  end)
  return out
end

------------------------------------------------------------------------
-- Sharing
------------------------------------------------------------------------
local lastSent = {} -- key -> ready at we last sent
local function sendMine(force, to)
  for key, at in pairs(ns.MyCooldowns()) do
    if force or lastSent[key] == nil or math.abs(lastSent[key] - at) > 60 then
      lastSent[key] = at
      if to then ns.QueueTo(to, "CD", key, at) else ns.Send("CD", key, at) end
    end
  end
end

local queued = false
local function changed()
  if queued then return end
  queued = true
  C_Timer.After(3, function() queued = false; sendMine(false) end)
end
ns.OnEvent("SPELL_UPDATE_COOLDOWN", changed)
ns.OnEvent("BAG_UPDATE_COOLDOWN", changed)

ns.OnMessage("CD", function(p, sender)
  if ns.IsMe(sender) then return end
  note(sender, p[2], p[3])
end)

ns.OnMessage("CDQ", function(_, sender)
  if ns.IsMe(sender) or next(ns.MyCooldowns()) == nil then return end
  C_Timer.After(1 + math.random() * 8, function() sendMine(true, sender) end)
end)

ns.OnLoad(function()
  store()
  C_Timer.After(12, function()
    sendMine(true)
    ns.Send("CDQ")
  end)
end)

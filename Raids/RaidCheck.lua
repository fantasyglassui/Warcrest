--[[
  Warcrest
  Raid check (Raids > Raid check): before the first pull, what each raid
  member has on: a flask, elixirs, food and world buffs.

  Read straight from the game's buffs on the raid's units, so members
  without Warcrest show too and nothing is sent. The game hides buffs
  during combat, so it only works outside it.
]]

local _, ns = ...
local Ambiguate = ns.Ambiguate

local function set(list) local s = {} for _, id in ipairs(list) do s[id] = true end return s end

ns.RAID_CHECK = {
  flask = set({ 17626, 17627, 17628, 17629 }), -- Titans, Distilled Wisdom, Supreme Power, Chromatic Resistance
  elixir = set({
    11405, 17538, 17539, 11474, 26276, 11390, 24363, 3593, 11371, 11348, 17537, 11334, 11328, 17535, -- elixirs
    24382, 10667, 10669, 10668, 10692, 10693, 17038, 16323, 16329, 16321, 16325, -- Zanza, Scorpok, R.O.I.D.S., Juju...
  }),
  food = set({ 19705, 19706, 19708, 19709, 19710, 19711, 24799, 18192, 18193, 18194, 18222, 22730, 25661, 18141,
    18125, 18191, 24870 }),
  world = set({ 22888, 16609, 24425, 15366, 22817, 22818, 22820, 23768, 23736, 23737, 23738, 23766, 23767, 23735 }),
}

local function auraAt(unit, i)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then return C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL") end
end

local function readUnit(unit)
  local r = { flask = false, elixirs = 0, food = false, world = 0 }
  for i = 1, 60 do
    local ok, a = pcall(auraAt, unit, i)
    if not ok or type(a) ~= "table" then break end
    local id = ns.Usable(a.spellId)
    if id then
      if ns.RAID_CHECK.flask[id] then r.flask = true
      elseif ns.RAID_CHECK.food[id] then r.food = true
      elseif ns.RAID_CHECK.world[id] then r.world = r.world + 1
      elseif ns.RAID_CHECK.elixir[id] then r.elixirs = r.elixirs + 1 end
    end
  end
  return r
end

-- The raid's buffs: rows { name, classFile, flask, elixirs, food, world, here }, or nil and why
-- ("combat": the game hides them; "group": not in a raid or party).
function ns.RaidCheck()
  if InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) then return nil, "combat" end
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  local units = {}
  if IsInRaid() then
    for i = 1, n do units[#units + 1] = "raid" .. i end
  elseif n > 0 then
    units[1] = "player"
    for i = 1, n - 1 do units[#units + 1] = "party" .. i end
  else
    return nil, "group"
  end
  local rows = {}
  for i, unit in ipairs(units) do
    local name
    if IsInRaid() then name = GetRaidRosterInfo(i) else name = UnitName(unit) end
    if name then
      local exists = unit == "player" or UnitExists(unit)
      local r = exists and readUnit(unit) or { flask = false, elixirs = 0, food = false, world = 0 }
      r.name, r.here = Ambiguate(name, "short"), exists
      local m = ns.Member(name)
      r.classFile = m and m.classFile
      rows[#rows + 1] = r
    end
  end
  -- The least prepared first.
  local function score(r) return (r.flask and 4 or 0) + math.min(r.elixirs, 3) + (r.food and 2 or 0) + math.min(r.world, 3) end
  table.sort(rows, function(a, b)
    local sa, sb = score(a), score(b)
    if sa ~= sb then return sa < sb end
    return a.name < b.name
  end)
  return rows
end

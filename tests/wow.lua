-- A small stand-in for the parts of the WoW API the addon uses, so its
-- logic can run outside the game. Each simulated player gets their own copy.
-- harness.py sets: now_py() (the clock), send_py(...) (outgoing messages),
-- and PLAYER (this character's name) before loading this file.

unpack = unpack or table.unpack

------------------------------------------------------------------------
-- Time and timers
------------------------------------------------------------------------
function GetTime() return now_py() end
function GetServerTime() return math.floor(now_py()) end
function time(t) if t then return os.time(t) end return math.floor(now_py()) end
date = function(fmt, t) return os.date(fmt, t or math.floor(now_py())) end

realmOffset = 0 -- seconds the realm's clock is ahead of UTC
C_DateAndTime = { GetCurrentCalendarTime = function()
  local d = os.date("!*t", math.floor(now_py()) + realmOffset)
  return { year = d.year, month = d.month, monthDay = d.day, hour = d.hour, minute = d.min }
end }

local timers, tickers = {}, {}
C_Timer = {
  After = function(delay, fn) timers[#timers + 1] = { due = GetTime() + (delay or 0), fn = fn } end,
  NewTicker = function(interval, fn)
    local t = { iv = interval, fn = fn, due = GetTime() + interval }
    tickers[#tickers + 1] = t
    return { Cancel = function() t.cancelled = true end }
  end,
}

-- Run every timer and ticker that's due. Called by the harness each step.
function RunDue()
  local now = GetTime()
  local ready, waiting = {}, {}
  for _, t in ipairs(timers) do
    if t.due <= now then ready[#ready + 1] = t else waiting[#waiting + 1] = t end
  end
  timers = waiting
  for _, t in ipairs(ready) do t.fn() end
  for _, t in ipairs(tickers) do
    if not t.cancelled and t.due <= now then
      t.due = now + t.iv
      t.fn(t)
    end
  end
end

------------------------------------------------------------------------
-- Lua helpers WoW adds
------------------------------------------------------------------------
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function strsplit(sep, s)
  local out = {}
  for piece in (s .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = piece end
  return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert = table.insert
function issecretvalue() return false end
function hooksecurefunc(owner, name, fn)
  if type(owner) == "string" then owner, name, fn = _G, owner, name end
  local orig = owner[name]
  owner[name] = function(...) local r = { orig and orig(...) }; fn(...); return unpack(r) end
end

printed = {}
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  printed[#printed + 1] = table.concat(parts, " ")
end

------------------------------------------------------------------------
-- Frames and widgets: any method not listed returns another widget, so
-- interface code can be built and refreshed without a real screen.
-- (Methods start with a capital letter; other fields are the addon's own.)
------------------------------------------------------------------------
frames = {}
local VALUES = {
  GetWidth = 140, GetHeight = 140, GetEffectiveScale = 1, GetStringHeight = 12, GetStringWidth = 60, GetText = "",
  GetChecked = false, IsShown = false, HasFocus = false, IsEnabled = true, IsProtected = false,
  GetObjectType = "Frame", GetValue = 0, GetNumPoints = 0, GetID = 1, GetMapID = 0, GetFrameLevel = 1,
  GetVerticalScroll = 0,
}
-- Where things are placed, so tests/render.py can draw the interface.
local function layout(w)
  local l = rawget(w, "_layout")
  if not l then l = { points = {} }; rawset(w, "_layout", l) end
  return l
end
local function adopt(parent, child)
  if type(parent) ~= "table" then return end
  rawset(child, "_parent", parent)
  local kids = rawget(parent, "_kids")
  if not kids then kids = {}; rawset(parent, "_kids", kids) end
  kids[#kids + 1] = child
end
local function frameOf(rel) if type(rel) == "string" then return _G[rel] end return rel end
local METHODS = {
  SetPoint = function(w, point, a, b, c, d)
    local rel, relPoint, x, y
    if type(a) == "number" then x, y = a, b
    elseif a ~= nil then
      rel = frameOf(a)
      if type(b) == "string" then relPoint, x, y = b, c, d else x, y = b, c end
    end
    table.insert(layout(w).points, { point = point, rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 })
  end,
  SetAllPoints = function(w, rel)
    rel = frameOf(rel)
    layout(w).points = {
      { point = "TOPLEFT", rel = rel, relPoint = "TOPLEFT", x = 0, y = 0 },
      { point = "BOTTOMRIGHT", rel = rel, relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    }
  end,
  ClearAllPoints = function(w) layout(w).points = {} end,
  GetNumPoints = function(w) return #layout(w).points end,
  GetPoint = function(w, i)
    local p = layout(w).points[i or 1]
    if p then return p.point, p.rel or rawget(w, "_parent"), p.relPoint, p.x, p.y end
  end,
  SetSize = function(w, width, height)
    layout(w).w, layout(w).h = width, height
    rawset(w, "_GetWidth", width); rawset(w, "_GetHeight", height)
  end,
  SetWidth = function(w, width) layout(w).w = width; rawset(w, "_GetWidth", width) end,
  SetHeight = function(w, height) layout(w).h = height; rawset(w, "_GetHeight", height) end,
  SetColorTexture = function(w, r, g, b, a) layout(w).color = { r, g, b, a or 1 } end,
  SetTexture = function(w, path) layout(w).tex = path end,
  SetVertexColor = function(w, r, g, b, a) layout(w).tint = { r, g, b, a or 1 } end,
  SetAlpha = function(w, a) layout(w).alpha = a end,
  SetJustifyH = function(w, j) layout(w).justify = j end,
  SetWordWrap = function(w, on) layout(w).nowrap = not on end,
  SetFontObject = function(w, f) layout(w).font = f end,
  SetFont = function(w, path, size) layout(w).path, layout(w).size = path, size; return true end,
  GetFont = function(w) return layout(w).path, layout(w).size end,
  GetAlpha = function(w) local a = layout(w).alpha; if a == nil then return 1 end return a end,
  SetTextColor = function(w, r, g, b) layout(w).textColor = { r, g, b } end,
  SetFontString = function(w, fs) rawset(w, "_fs", fs) end,
  GetFontString = function(w) return rawget(w, "_fs") or NewWidget() end,
  SetNormalFontObject = function(w, f)
    rawset(w, "_normalFont", f)
    local fs = rawget(w, "_fs")
    if fs then layout(fs).font = f end
  end,
  SetText = function(w, v)
    rawset(w, "_GetText", v)
    local fs = rawget(w, "_fs")
    if fs then rawset(fs, "_GetText", v) end
  end,
  SetScrollChild = function(w, child) layout(w).scrollChild = child; adopt(w, child) end,
  CreateTexture = function(w, _, layer)
    local t = NewWidget("Texture"); adopt(w, t); layout(t).layer = layer or "ARTWORK"; return t
  end,
  CreateFontString = function(w, _, layer)
    local t = NewWidget("FontString"); adopt(w, t); layout(t).layer = layer or "ARTWORK"; return t
  end,
  GetParent = function(w) return rawget(w, "_parent") end,
  -- Roughly how wide text is (no fonts here): about 6.5 pixels a letter, minus color codes.
  GetStringWidth = function(w)
    local t = tostring(rawget(w, "_GetText") or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * 6.5
  end,
  SetCheckedTexture = function(w, t) if type(t) == "table" then rawset(t, "_checkedOf", w) end end,
  SetDisabledCheckedTexture = function(w, t) if type(t) == "table" then rawset(t, "_disabledCheckOf", w) end end,
}

-- Parts that frame templates create (BasicFrameTemplate's title, and so on).
local CHILDREN = { TitleText = true, CloseButton = true, Icon = true, Text = true }
local widgetMeta
widgetMeta = { __index = function(self, key)
  if type(key) ~= "string" or not key:find("^%u") then return nil end
  if CHILDREN[key] then local c = NewWidget(); rawset(self, key, c); return c end
  if METHODS[key] then return METHODS[key] end
  if VALUES[key] ~= nil then
    local v = VALUES[key]
    return function(w) local own = rawget(w, "_" .. key); if own ~= nil then return own end return v end
  end
  if key == "GetCenter" then return function() return 0, 0 end end
  if key == "GetMinMaxValues" then return function() return 0, 100 end end
  if key == "SetChecked" then return function(w, v) rawset(w, "_GetChecked", v and true or false) end end
  if key == "SetVerticalScroll" then return function(w, v) rawset(w, "_GetVerticalScroll", v) end end
  if key == "Show" then return function(w) rawset(w, "_IsShown", true) end end
  if key == "Hide" then return function(w) rawset(w, "_IsShown", false) end end
  if key == "SetShown" then return function(w, v) rawset(w, "_IsShown", v and true or false) end end
  if key == "SetScript" then return function(w, name, fn) rawset(w, "script_" .. name, fn) end end
  -- HookScript runs after the script that's there, as in the game.
  if key == "HookScript" then return function(w, name, fn)
    local old = rawget(w, "script_" .. name)
    rawset(w, "script_" .. name, old and function(...) old(...); fn(...) end or fn)
  end end
  if key == "GetScript" then return function(w, name) return rawget(w, "script_" .. name) end end
  if key == "RegisterEvent" then return function(w, ev)
    if FOREVER_EVENTS and not FOREVER_EVENTS[ev] and not ev:find("^WARCREST_TEST") then error("Attempt to register unknown event \"" .. ev .. "\"", 2) end
    w.events[ev] = true
  end end
  return function() return NewWidget() end
end }
local widgetCount = 0
function NewWidget(kind)
  widgetCount = widgetCount + 1
  local w = setmetatable({ events = {}, kind = kind, _uid = widgetCount }, widgetMeta)
  if kind == "EditBox" then rawset(w, "_GetObjectType", "EditBox") end
  if kind == "Slider" then rawset(w, "_GetObjectType", "Slider") end
  return w
end
function CreateFrame(kind, name, parent, template)
  local f = NewWidget(kind)
  frames[#frames + 1] = f
  adopt(frameOf(parent), f)
  rawset(f, "_template", template)
  if name then _G[name] = f end
  return f
end

-- Deliver a game event to every frame listening for it.
function fire(event, ...)
  for _, f in ipairs(frames) do
    local handler = rawget(f, "script_OnEvent")
    if handler and (f.events[event] or event == "ADDON_LOADED") then handler(f, event, ...) end
  end
end

function CreateFont(name) local f = NewWidget(); if name then _G[name] = f end return f end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UIParent, Minimap, GameTooltip = NewWidget(), NewWidget(), NewWidget()
UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
ChatTypeInfo = { RAID_WARNING = {} }
SOUNDKIT = { RAID_WARNING = 8959, READY_CHECK = 8960, ALARM_CLOCK_WARNING_3 = 12889 }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
YES, NO, OKAY, CANCEL = "Yes", "No", "Okay", "Cancel"
staticPopups = {}
function StaticPopup_Show(which, a, b, data) staticPopups[#staticPopups + 1] = { which = which, data = data } end
-- Sounds played: { "kit", id, channel } or { "file", path, channel }. Files in
-- MISSING_SOUNDS don't exist (the game won't play them).
soundsPlayed = {}
MISSING_SOUNDS = {}
function PlaySound(kit, channel)
  soundsPlayed[#soundsPlayed + 1] = { "kit", kit, channel }
  return true
end
function PlaySoundFile(path, channel)
  if MISSING_SOUNDS[path] then return false end
  soundsPlayed[#soundsPlayed + 1] = { "file", path, channel }
  return true, 1
end
function RaidNotice_AddMessage() end
RaidWarningFrame = NewWidget()
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 0, 0 end

------------------------------------------------------------------------
-- Addon messages
------------------------------------------------------------------------
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 9, GeneralError = 1 } }
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, text, channel, target) return send_py(prefix, text, channel, target) end,
}
C_AddOns = {
  GetAddOnMetadata = function(addon, field) if field == "Version" then return ADDON_VERSION end end,
  GetNumAddOns = function() return 2 end,
  GetAddOnInfo = function(i) return ({ "Warcrest", "TomTom" })[i] end,
  IsAddOnLoaded = function() return true end,
}

------------------------------------------------------------------------
-- The player, the guild and the group (the harness fills these in)
------------------------------------------------------------------------
guildRoster = {}   -- { name, rankIndex, online, classFile }
raidMembers = {}   -- names in the player's raid
playerClass = "WARRIOR"
playerLevel = 60
inInstance, instanceType = false, "none"
inCombat = false
falling = false
pvpFlagged = false

function IsInGuild() return true end
function GetNormalizedRealmName() return "Realm" end
function Ambiguate(name) return (tostring(name):gsub("%-.*", "")) end
function UnitName(unit)
  if unit == nil or unit == "player" then return PLAYER end
  return units[unit] and units[unit].name
end
function GetGuildInfo(unit)
  if unit and unit ~= "player" then return units[unit] and units[unit].guild end
  for _, r in ipairs(guildRoster) do
    if r[1] == PLAYER then return GUILD_NAME or "The Imperium", "Rank", r[2] end
  end
end
-- The guild window's "Show offline members". With it off, the game only lists
-- online members (the total still counts everyone), as Classic clients do.
guildShowOffline = true
function GetGuildRosterShowOffline() return guildShowOffline end
function SetGuildRosterShowOffline(on) guildShowOffline = on and true or false end
function GetNumGuildMembers()
  local online = 0
  for _, r in ipairs(guildRoster) do if r[3] ~= false then online = online + 1 end end
  return #guildRoster, online
end
local function listed()
  if guildShowOffline then return guildRoster end
  local out = {}
  for _, r in ipairs(guildRoster) do if r[3] ~= false then out[#out + 1] = r end end
  return out
end
function GetGuildRosterInfo(i)
  local r = listed()[i]
  if not r then return end
  local classFile = r[4] or "WARRIOR"
  local className = classFile:sub(1, 1) .. classFile:sub(2):lower() -- "PRIEST" -> "Priest"
  return r[1] .. "-Realm", "Rank " .. r[2], r[2], r[5] or 60, className, "Zone", "", "", r[3] ~= false, 0, classFile,
    0, 0, false, false, 0, "Player-" .. i
end
-- Offline members: r[6] = days since they were last online.
function GetGuildRosterLastOnline(i)
  local r = listed()[i]
  if not r or r[3] ~= false then return nil end
  local d = r[6] or 0
  return math.floor(d / 365), math.floor((d % 365) / 30), d % 30, 0
end
function GuildControlGetNumRanks() return 10 end
function GuildControlGetRankName(i) return "Rank " .. (i - 1) end
function GetGuildRosterMOTD() return "" end
C_GuildInfo = {}

partyOnly = false -- true while the group is a party rather than a raid
function IsInRaid() return #raidMembers > 0 and not partyOnly end
function IsInGroup() return #raidMembers > 0 end
function GetNumGroupMembers() return #raidMembers end
raidSubgroups = {} -- name -> group, once moved (otherwise five to a group in order)
local function subgroupOf(i)
  return raidSubgroups[raidMembers[i]] or math.floor((i - 1) / 5) + 1
end
function GetRaidRosterInfo(i)
  local n = raidMembers[i]
  if n then return n, 0, subgroupOf(i), 60, "Class", "WARRIOR", "Zone", true, false, nil, false, "DAMAGER" end
end
function SetRaidSubgroup(i, g) raidSubgroups[raidMembers[i]] = g end
function SwapRaidSubgroup(i, j)
  local a, b = subgroupOf(i), subgroupOf(j)
  raidSubgroups[raidMembers[i]], raidSubgroups[raidMembers[j]] = b, a
end
function UnitIsGroupLeader() return true end
function UnitIsGroupAssistant() return false end

function UnitClass() return "Class", playerClass end
function UnitLevel(unit)
  if unit == nil or unit == "player" then return playerLevel end
  return units[unit] and units[unit].level or 60
end
function GetMaxPlayerLevel() return 60 end
function IsInInstance() return inInstance, instanceType end
function UnitAffectingCombat(unit)
  if unit == "player" then return inCombat end
  return units[unit] and units[unit].combat or false
end
function UnitIsPVP() return pvpFlagged end
function IsFalling() return falling end
function GetRealZoneText() return "Stranglethorn Vale" end
function GetZoneText() return "Stranglethorn Vale" end
function GetPVPLifetimeStats() return 0 end

-- Other units the player can see: units[unitToken] = { name, player, hostile, dead, level, targetingMe }
units = {}
function UnitExists(u)
  if units[u] then return true end
  local base = u:match("^(.-)target$")
  return base ~= nil and units[base] ~= nil and units[base].targetingMe == true
end
function UnitIsPlayer(u) return units[u] and units[u].player or false end
function UnitCanAttack(_, u) return units[u] and units[u].hostile and not units[u].dead or false end
function UnitReaction(_, u) return units[u] and units[u].hostile and 2 or 5 end
function GetUnitName(u) return units[u] and units[u].name end
function UnitIsDeadOrGhost(u)
  if u == "player" then return playerDead or false end
  return units[u] and units[u].dead or false
end
function UnitIsFeignDeath() return false end
function UnitIsUnit(a, b)
  if b == "player" then
    local base = a:match("^(.-)target$")
    return base ~= nil and units[base] ~= nil and units[base].targetingMe == true
  end
  return a == b
end
function UnitClassification(u) return units[u] and units[u].classification or "normal" end
C_NamePlate = { GetNamePlates = function()
  local out = {}
  for token in pairs(units) do
    if token:find("^nameplate") then out[#out + 1] = { namePlateUnitToken = token } end
  end
  return out
end }
C_Spell = { IsSpellHarmful = function(id) return harmfulSpells[id] == true end }
harmfulSpells = { [133] = true } -- Fireball

-- Items: link text containing a word picks its type.
C_Item = { GetItemInfoInstant = function(link)
  if link:find("Plate") then return 1, "Armor", "Plate", "INVTYPE_CHEST", 0, 4, 4 end
  if link:find("Wand") then return 2, "Weapon", "Wand", "INVTYPE_RANGED", 0, 2, 19 end
  return 3, "Armor", "Miscellaneous", "INVTYPE_FINGER", 0, 4, 0
end }

invited = {}
C_PartyInfo = {
  InviteUnit = function(name) invited[#invited + 1] = name end,
  ConvertToRaid = function() convertedToRaid = true; partyOnly = false end,
}
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (%d Honor Points)"
ERR_GUILD_PROMOTE_SSS = "%s has promoted %s to %s."
ERR_GUILD_DEMOTE_SSS = "%s has demoted %s to %s."
ERR_GUILD_REMOVE_SS = "%s has been kicked out of the guild by %s."
ERR_GUILD_JOIN_S = "%s has joined the guild."
ERR_GUILD_LEAVE_S = "%s has left the guild."

-- The instance you're in: set INSTANCE = { "Hyjal Summit", "raid" } to be in a raid instance.
function GetInstanceInfo()
  if INSTANCE then return INSTANCE[1], INSTANCE[2], 9, "", 20, 0, false, INSTANCE[3] or 2000 end
  return "Eastern Kingdoms", "none", 0, "", 0, 0, false, 0
end

-- The game's language (tests can change it).
gameLocale = "enUS"
function GetLocale() return gameLocale end

-- Gear, chat channels and chat (member profiles and recruiting)
equipped = {}      -- slot -> item link
itemLevels = {}    -- item link -> { level, equipLoc }
function GetInventoryItemLink(unit, slot) if unit == "player" then return equipped[slot] end end
itemNames = {}     -- item ID -> name, for items looked up by ID
function GetItemInfo(link)
  if type(link) == "number" then
    local name = itemNames[link]
    if name then return name, "|cff1eff00|Hitem:" .. link .. "|h[" .. name .. "]|h|r" end
    return nil
  end
  local i = itemLevels[link]
  if not i then return nil end
  return link, link, 3, i[1], i[1], "Armor", "Misc", 1, i[2] or "INVTYPE_CHEST"
end
chatChannels = { 1, "General", false, 2, "Trade", false }
function GetChannelList() return unpack(chatChannels) end
chatSent = {}
function SendChatMessage(text, chatType, lang, target) table.insert(chatSent, { text, chatType, target }) end
function UnitIsConnected() return true end
guildInvites = {}
function GuildInvite(name) table.insert(guildInvites, name) end
chatFilters = {}   -- event -> { filter functions }
function ChatFrame_AddMessageEventFilter(event, fn)
  chatFilters[event] = chatFilters[event] or {}
  table.insert(chatFilters[event], fn)
end
-- What the chat window would show for a message: each filter in turn.
function ShowChat(event, msg, author)
  for _, fn in ipairs(chatFilters[event] or {}) do
    local hide, m, a = fn(nil, event, msg, author)
    if hide then return nil end
    msg, author = m or msg, a or author
  end
  return msg
end

-- Professions (the crafters directory)
tradeSkill = nil   -- { name, rank, max, recipes = { { name, kind, link } } }
craftSkill = nil   -- the same, for the enchanting window
function GetTradeSkillLine()
  if not tradeSkill then return "UNKNOWN", 0, 0 end
  return tradeSkill.name, tradeSkill.rank, tradeSkill.max
end
function GetNumTradeSkills() return tradeSkill and #tradeSkill.recipes or 0 end
function GetTradeSkillInfo(i) local r = tradeSkill.recipes[i]; return r[1], r[2] end
function GetTradeSkillItemLink(i) return tradeSkill.recipes[i][3] end
function GetCraftDisplaySkillLine()
  if not craftSkill then return nil end
  return craftSkill.name, craftSkill.rank, craftSkill.max
end
function GetNumCrafts() return craftSkill and #craftSkill.recipes or 0 end
function GetCraftInfo(i) local r = craftSkill.recipes[i]; return r[1], "", r[2] end
function GetCraftItemLink(i) return craftSkill.recipes[i][3] end
spellNames = {}
function GetSpellInfo(id) return spellNames[id] end
openedChat = {}
function ChatFrame_OpenChat(text) table.insert(openedChat, text) end

-- Quests finished (attunements)
questsDone = {}
C_QuestLog = C_QuestLog or {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return questsDone[id] == true end

-- Units' GUIDs (units[u].npc makes a creature) and buffs.
function UnitGUID(u)
  if u == "player" then return "Player-1-" .. tostring(PLAYER) end
  local d = units[u]
  if not d then return nil end
  if d.npc then return "Creature-0-1-1-1-" .. d.npc .. "-0000ABCD" end
  return "Player-1-" .. tostring(d.name)
end
function UnitIsDead(u) return units[u] and units[u].dead or false end
-- auras[unit] = { { spellId = 123, name = "...", expirationTime = GetTime() + 100, duration = 3600 }, ... }
auras = {}
C_UnitAuras = {
  GetPlayerAuraBySpellID = function(id)
    for _, a in ipairs(auras.player or {}) do if a.spellId == id then return a end end
  end,
  GetAuraDataByIndex = function(unit, i) return (auras[unit] or {})[i] end,
}
-- Spells you know (knownSpells[id] = true) and their cooldowns (spellCooldowns[id] = { start, duration }).
knownSpells, spellCooldowns, itemCounts, itemCooldowns = {}, {}, {}, {}
function IsPlayerSpell(id) return knownSpells[id] == true end
C_Spell.GetSpellCooldown = function(id)
  local c = spellCooldowns[id] or { 0, 0 }
  return { startTime = c[1], duration = c[2], isEnabled = true }
end
function GetItemCount(id) return itemCounts[id] or 0 end
C_Container = { GetItemCooldown = function(id)
  local c = itemCooldowns[id] or { 0, 0 }
  return c[1], c[2], 1
end }

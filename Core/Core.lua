--[[
  Warcrest
  Guild tools for World of Warcraft: Forever. Formerly The Imperium, the
  guild addon of <The Imperium>.

  Core: shared helpers, saved data, event and message routing, slash commands.
]]

local ADDON_NAME, ns = ...

-- Names without the realm. The game's Ambiguate(name, "short") keeps the realm
-- on some clients when it can't tell which realm is yours, so guildmates would
-- show as "Name-Realm". Player names never contain "-", so cutting there is safe.
local gameAmbiguate = Ambiguate
-- A character's name without its realm. Usually "Name-Realm", but some game
-- clients write "Name Realm" or "Name (Realm)". Names never have spaces.
local REALM = "[%-%s%(].*$"
ns.REALM_PATTERN = REALM

function ns.Ambiguate(name, context)
  if context == "short" and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
    return (name:gsub(REALM, ""))
  end
  return gameAmbiguate(name, context)
end

-- Hidden addon channel used to talk to guildmates. It keeps the addon's old
-- name so Warcrest and The Imperium (2.x) understand each other while a
-- guild updates. Players never see it.
ns.PREFIX = "TheImperium"
ns.SEP = "^"
ns.COLOR = "|cffd4af37"   -- Warcrest gold
ns.NAME = "Warcrest"

-- Artwork (Media folder). Paths are given without the .tga extension.
ns.MEDIA = "Interface\\AddOns\\Warcrest\\Media\\"

-- The look: Warcrest's crest for every guild, except <The Imperium>, the
-- guild it was made for, which keeps its own emblem and name.
--   Icon     64x64 emblem: chat, addon list, minimap menu
--   Portrait 128x128 emblem on navy: window portraits
--   Artwork  512x512 artwork: Options page
ns.IMPERIUM_GUILD = "The Imperium"
local LOOKS = {
  warcrest = { folder = ns.MEDIA, brand = "Warcrest" },
  imperium = { folder = ns.MEDIA .. "Imperium\\", brand = "The Imperium" },
}
local lookHooks = {}

local function setLook(name)
  local look = LOOKS[name]
  ns.look = name
  ns.BRAND = look.brand
  ns.ICON = look.folder .. "Icon"
  ns.PORTRAIT = look.folder .. "Portrait"
  ns.ARTWORK = look.folder .. "Artwork"
  ns.ICON_TEXT = "|T" .. ns.ICON .. ":14:14|t"
end
setLook("warcrest")

-- Whether the guild uses DKP for loot (officers can turn it off in Settings).
function ns.UsesDKP()
  return not ns.cfg or ns.cfg.dkp ~= false
end

-- Your guild's name, or nil.
function ns.GuildName()
  if not (IsInGuild and IsInGuild()) then return end
  local name = GetGuildInfo("player")
  if type(name) == "string" and name ~= "" then return name end
end

-- fn() runs now and whenever the look changes (to update a texture or label).
function ns.OnLook(fn)
  lookHooks[#lookHooks + 1] = fn
  fn()
end

-- A texture showing the emblem: kind is "ICON", "PORTRAIT" or "ARTWORK".
function ns.Emblem(texture, kind)
  ns.OnLook(function() texture:SetTexture(ns[kind]) end)
end

-- Picks the look for the guild you're in; called when the guild is known.
function ns.ApplyGuildLook()
  local name = ns.GuildName() == ns.IMPERIUM_GUILD and "imperium" or "warcrest"
  if name == ns.look then return end
  setLook(name)
  for _, fn in ipairs(lookHooks) do pcall(fn) end
end

-- Alert types members can announce and filter. Order is the display order.
ns.TYPES = {
  { key = "pvp",          group = "death", label = "World PvP" },
  { key = "environment",  group = "death", label = "Falling, drowning & fatigue" },
  { key = "kill_world",   group = "kill",  label = "World PvP kills" },
  -- Battleground and arena kills don't count since 4.3.0. Kept hidden for older versions.
  { key = "kill_bg",      group = "kill",  label = "Battleground & arena kills", hidden = true },
  -- Always on since 2.11.1 (grey kills are never logged). Kept so older versions still get it from officers.
  { key = "kill_honor",   group = "kill",  label = "Honor kills only (no grey kills)", filter = true, hidden = true },
  { key = "kill_streak",  group = "streak", label = "Kill streaks" },
  { key = "kill_revenge", group = "streak", label = "Revenge kills" },
  { key = "wanted",       group = "wanted", label = "Wanted gankers spotted" },
  { key = "bounty",       group = "wanted", label = "Bounties placed and claimed" },
  { key = "achievement",  group = "achievement", label = "Achievements earned" },
  -- (A guild feature since 3.6.2: older versions' settings messages leave it alone.)
  { key = "achievement_chat", group = "achievement", label = "Posted in guild chat", feature = true,
    youTip = "Just for you: untick and your own achievements aren't posted in guild chat." },
  { key = "boss_first",   group = "raid", label = "Guild first boss kills" },
  { key = "raid_recap",   group = "raid", label = "Raid night recaps" },
  { key = "level_ten",    group = "celebrate", label = "Every 10 levels and max level" },
  { key = "level_all",    group = "celebrate", label = "Every level up" },
}
ns.GROUP_LABELS = { death = "Deaths", kill = "PvP kills by guild members", streak = "Streaks and revenge",
  wanted = "Wanted list", achievement = "Achievements", raid = "Raids", celebrate = "Celebrations" }
ns.PVP_TYPES = { pvp = true }

local frame = CreateFrame("Frame")
local events, inits, handlers = {}, {}, {}
ns.loadErrors = {}
ns.recentErrors = {} -- { text, n, t }: the last errors, for bug reports

-- Run a piece of the addon; if it breaks, note the error instead of
-- stopping everything else.
local lastErrorShown = 0
local function safely(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if ok then return end
  if #ns.loadErrors < 20 then ns.loadErrors[#ns.loadErrors + 1] = where .. ": " .. tostring(err) end
  -- The last few, for /warcrest report (the same error again counts up instead).
  local text = (where .. ": " .. tostring(err)):sub(1, 300)
  local last = ns.recentErrors[#ns.recentErrors]
  if last and last.text == text then
    last.n, last.t = last.n + 1, time()
  else
    ns.recentErrors[#ns.recentErrors + 1] = { text = text, n = 1, t = time() }
    if #ns.recentErrors > 12 then table.remove(ns.recentErrors, 1) end
  end
  if ns.db and ns.db.debug and GetTime() - lastErrorShown > 2 then
    lastErrorShown = GetTime()
    print("|cffff6060[" .. ns.BRAND .. "] error in " .. where .. ": " .. tostring(err) .. "|r")
  end
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns.Say(msg)
  print(ns.ICON_TEXT .. " " .. ns.COLOR .. "[" .. ns.BRAND .. "]|r " .. (ns.T and ns.T(msg) or msg))
end

-- Midnight-era clients can hand back "secret" values; never use those.
function ns.Usable(v)
  if v == nil then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

-- Item and spell lookups (nothing, rather than an error, for an unknown one).
function ns.GetItemInfo(item)
  if item == nil then return end
  return C_Item.GetItemInfo(item)
end

function ns.SpellName(id)
  local info = C_Spell.GetSpellInfo(id)
  return info and info.name
end

-- Boss fights, keystone runs and PvP matches lock addon chat: the game sends
-- nothing an addon says (chat lines or addon messages) until they end.
-- Warcrest holds what it has to say and sends it then.
local lockedAt -- when the game last refused an addon message as locked
function ns.ChatLocked()
  if C_ChatInfo.InChatMessagingLockdown() == true then return true end
  return lockedAt ~= nil and GetTime() - lockedAt < 5
end

-- A countdown (an auction, a roll, a vote) can't end while nobody can answer:
-- while addon chat is locked, keep at least a few seconds on it. True while locked.
function ns.HoldCountdown(t, secs)
  if not (t and t.ends and ns.ChatLocked()) then return false end
  t.ends = math.max(t.ends, GetTime() + (secs or 5))
  return true
end

local heldChat = {} -- chat lines waiting for the lockdown to end
local MAX_HELD_CHAT = 20
local toldLocked -- told the player we're holding messages, this lockdown
local function noteHeld()
  if toldLocked then return end
  toldLocked = true
  ns.Say("The game blocks addon messages during boss fights and PvP matches. Warcrest will send its messages when this one ends.")
end

-- Say something in chat.
function ns.SendChat(text, chatType, language, target)
  if ns.ChatLocked() then
    if #heldChat < MAX_HELD_CHAT then heldChat[#heldChat + 1] = { text, chatType, language, target } end
    noteHeld()
    return true, "held"
  end
  return pcall(C_ChatInfo.SendChatMessage, text, chatType, language, target)
end

local function sendHeldChat()
  local lines = heldChat
  heldChat = {}
  for i, l in ipairs(lines) do
    C_Timer.After((i - 1) * 0.4, function() ns.SendChat(l[1], l[2], l[3], l[4]) end)
  end
end

-- Open the chat box with this text in it.
function ns.OpenChat(text)
  ChatFrameUtil.OpenChat(text)
  return true
end

function ns.First(...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if type(f) == "function" then return f end
  end
end

function ns.Clean(s)
  return ((tostring(s or "")):gsub("%" .. ns.SEP, ""))
end

-- Lowercase name without realm, for matching the same player across messages.
-- Called constantly on the same few hundred names, so the answers are kept.
local keys, keyCount = {}, 0
function ns.Key(name)
  local k = keys[name or ""]
  if k then return k end
  k = (tostring(name or ""):gsub(REALM, "")):lower()
  if keyCount > 20000 then keys, keyCount = {}, 0 end
  keys[name or ""] = k
  keyCount = keyCount + 1
  return k
end

------------------------------------------------------------------------
-- Sending, within the game's limits
------------------------------------------------------------------------
-- WoW silently drops addon messages sent too fast: each prefix gets a small
-- burst allowance that refills about once a second. Every message goes
-- through this queue, which stays under that limit and sends the most
-- important messages first. Bulk catch-up data uses a second prefix, so it
-- has its own allowance and never holds up live alerts or loot bids.
ns.PREFIX_BULK = "TheImperiumB"
local BURST, REFILL = 8, 0.9            -- messages, and messages per second, per prefix
local MAX_BULK = 600                    -- bulk messages waiting before new ones are dropped
local URGENT = { B1 = true, B2 = true, B3 = true, B4 = true, B5 = true, K = true, D2 = true,
  S = true, L = true, W = true, L1 = true, L2 = true, L3 = true, L4 = true }
local queues = { {}, {}, {} }           -- 1 urgent, 2 normal, 3 bulk
local tokens = {}
local lastRefill
local bulkReady = {}                    -- name key -> true once they're known to read the bulk prefix

local function encode(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = ns.Clean((select(i, ...))) end
  return table.concat(parts, ns.SEP)
end

local function enqueue(level, prefix, channel, target, text)
  if level == 3 and #queues[3] >= MAX_BULK then return end
  table.insert(queues[level], { prefix = prefix, channel = channel, target = target, text = text, tries = 0 })
end

local THROTTLED, LOCKDOWN = {}, 11
local function throttleResults()
  local r = Enum and Enum.SendAddonMessageResult
  if r then
    for _, name in ipairs({ "AddonMessageThrottle", "ChannelThrottle", "GeneralError" }) do
      if r[name] then THROTTLED[r[name]] = true end
    end
    LOCKDOWN = r.AddOnMessageLockdown or LOCKDOWN
  end
end

-- An addon message from a guildmate (or from you): run its handler.
function ns.HandleAddonMessage(prefix, text, channel, sender)
  -- Private messages are only accepted from guild members.
  local member = sender and ns.RankOf and ns.RankOf(sender) ~= nil
  local trusted = channel == "GUILD" or ((channel == "WHISPER" or channel == "RAID") and member)
  if (prefix == ns.PREFIX or prefix == ns.PREFIX_BULK) and trusted and sender and text then
    local parts = { strsplit(ns.SEP, text) }
    local handler = handlers[parts[1]]
    if handler then
      ns.busy = (ns.busy or 0) + 1 -- (see ns.RefreshPanel)
      safely("message " .. tostring(parts[1]), handler, parts, sender, channel)
      ns.busy = ns.busy - 1
    end
    if ns.NoteAddonUser and channel ~= "RAID" then ns.NoteAddonUser(sender) end
  end
end

-- Send one message now. Returns false if the game said to slow down.
-- The name to whisper a guildmate by. Some game clients report a sender as
-- "Name Realm", which the server can't whisper ("No player named ... is
-- currently playing"): use the roster's name for them, or "Name-Realm".
-- Returns nil for a guildmate the roster shows offline (don't whisper them).
function ns.WhisperName(target)
  if type(target) ~= "string" or target == "" then return nil end
  local m = ns.Member and ns.Member(target)
  if m then
    if m.online == false then return nil end
    target = m.name or target
  end
  if target:find(" ", 1, true) then
    local name, realm = target:match("^(%S+)%s+%(?(.-)%)?$")
    if name then target = (realm ~= "" and (name .. "-" .. realm:gsub("%s+", ""))) or name end
  end
  return target
end

local function deliver(m)
  if m.channel == "GUILD" and not IsInGuild() then return true end
  if m.channel == "RAID" and not IsInRaid() then return true end
  if m.channel == "WHISPER" then
    m.target = ns.WhisperName(m.target)
    if not m.target then return true end -- offline: drop it
  end
  if ns.ChatLocked() then return "held" end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, m.prefix, m.text, m.channel, m.target)
  if not ok then return true end           -- a bad message: drop it
  if result == LOCKDOWN then lockedAt = GetTime() return "held" end
  if result == false or THROTTLED[result] then return false end
  -- Everyone in the guild (or raid) gets it, you included: handle your own
  -- copy here rather than waiting for the game to send it back, which not
  -- every game client does.
  if m.channel == "GUILD" or m.channel == "RAID" then
    local me = ns.fullName(UnitName("player"))
    C_Timer.After(0, function() ns.HandleAddonMessage(m.prefix, m.text, m.channel, me) end)
  end
  return true
end

local locked    -- addon chat was locked last tick
local unlocking -- it just ended: once a message goes out, send the rest
local function unlocked()
  unlocking, toldLocked = nil, nil
  sendHeldChat()
  if ns.OnChatUnlocked then ns.OnChatUnlocked() end
end

local function pump()
  if ns.ChatLocked() then
    if not locked then
      locked = true
      if ns.QueueSize() > 0 or #heldChat > 0 then noteHeld() end
    end
    return
  end
  if locked then
    locked, unlocking = nil, true
    if ns.QueueSize() == 0 then unlocked() end
  end
  local now = GetTime()
  local elapsed = lastRefill and (now - lastRefill) or 0
  lastRefill = now
  tokens[ns.PREFIX] = math.min(BURST, (tokens[ns.PREFIX] or BURST) + elapsed * REFILL)
  tokens[ns.PREFIX_BULK] = math.min(BURST, (tokens[ns.PREFIX_BULK] or BURST) + elapsed * REFILL)
  -- (Nothing waiting, the usual case: done. This runs ten times a second.)
  if not (queues[1][1] or queues[2][1] or queues[3][1]) then return end
  for level = 1, 3 do
    local q = queues[level]
    local i = 1
    while q[i] do
      -- Nothing more can go out this tick: stop, rather than look through a long queue.
      -- (Only bulk data, level 3, ever uses the second prefix.)
      if tokens[ns.PREFIX] < 1 and (level < 3 or tokens[ns.PREFIX_BULK] < 1) then break end
      local m = q[i]
      -- Bulk data on the main prefix always leaves room for alerts and bids.
      local need = (level == 3 and m.prefix == ns.PREFIX) and 4 or 1
      if tokens[m.prefix] >= need then
        tokens[m.prefix] = tokens[m.prefix] - 1
        local sent = deliver(m)
        if sent == "held" then
          -- Addon chat is locked (a boss fight, say): keep it all for later.
          tokens[m.prefix] = tokens[m.prefix] + 1
          locked = true
          noteHeld()
          return
        elseif sent then
          table.remove(q, i)
          if unlocking then unlocked() end
        else
          -- The game held it back: wait a moment, then try again (a few times).
          tokens[m.prefix] = 0
          m.tries = m.tries + 1
          if m.tries > 5 then table.remove(q, i) else i = i + 1 end
        end
      else
        i = i + 1
      end
    end
  end
end

-- Started once the addon has loaded (see the end of this file).
ns.StartSendQueue = function()
  throttleResults()
  C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX_BULK)
  C_Timer.NewTicker(0.1, pump)
end

-- Can this guildmate read the bulk prefix? (Version 2.6.0 and later.)
local function readsBulk(target)
  local k = ns.Key(target)
  if bulkReady[k] then return true end
  local v = (ns.versions and ns.versions[ns.fullName(target)])
    or (ns.db and ns.db.addonUsers and ns.db.addonUsers[k] and ns.db.addonUsers[k].version)
  if v and ns.CompareVersions(v, "2.6.0") >= 0 then bulkReady[k] = true return true end
  return false
end

-- Send a message to one guildmate's addon only.
function ns.SendTo(target, ...)
  local text = encode(...)
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "WHISPER", target, text)
end

-- Send a message to everyone in your raid running the addon.
function ns.SendRaid(...)
  if not IsInRaid() then return end
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "RAID", nil, encode(...))
end

-- Bulk data for one guildmate (catch-up history), sent after everything else.
function ns.QueueTo(target, ...)
  enqueue(3, readsBulk(target) and ns.PREFIX_BULK or ns.PREFIX, "WHISPER", target, encode(...))
end

-- Send a message to every guildmate running the addon.
function ns.Send(...)
  if not IsInGuild() then return end
  enqueue(URGENT[(...)] and 1 or 2, ns.PREFIX, "GUILD", nil, encode(...))
end

-- How many messages are waiting (for troubleshooting).
function ns.QueueSize()
  return #queues[1] + #queues[2] + #queues[3]
end

function ns.fullName(name)
  if not name then return nil end
  -- "Name Realm" or "Name (Realm Name)", as some game clients write it: "Name-RealmName".
  if name:find("[%s%(]") then
    local short, realm = name:match("^([^%s%(]+)%s*%(?(.-)%)?%s*$")
    if short then
      realm = (realm or ""):gsub("[%s%-]", "")
      name = realm ~= "" and (short .. "-" .. realm) or short
    end
  end
  if name:find("-", 1, true) then return name end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  return realm and (name .. "-" .. realm) or name
end

-- Is this you? By name, without the realm: the game may add a realm to your
-- own messages that doesn't match the one it reports for you, and a guild (and
-- everyone in it) is on one realm.
function ns.IsMe(name)
  if type(name) ~= "string" or name == "" then return false end
  local me = UnitName("player")
  if not me then return false end
  return (name:gsub(REALM, "")):lower() == me:lower()
end

-- Turn a Blizzard format string like "%s has promoted %s to %s." into a pattern.
-- Also returns which argument each capture is, for formats like
-- "%2$s has promoted %1$s" where the order is swapped.
local function escape(str)
  return (str:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"))
end

function ns.FormatToPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local out, order, seq, i = {}, {}, 0, 1
  while i <= #fmt do
    local s, e, pos, conv = fmt:find("%%(%d*)%$?([sd])", i)
    if not s then
      out[#out + 1] = escape(fmt:sub(i))
      break
    end
    out[#out + 1] = escape(fmt:sub(i, s - 1))
    seq = seq + 1
    order[#order + 1] = tonumber(pos) or seq
    out[#out + 1] = (conv == "d") and "(%d+)" or "(.+)"
    i = e + 1
  end
  return "^" .. table.concat(out) .. "$", order
end

local function parseVersion(v)
  local a, b, c = tostring(v or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- 1 if a is newer than b, -1 if older, 0 if the same.
function ns.CompareVersions(a, b)
  local a1, a2, a3 = parseVersion(a)
  local b1, b2, b3 = parseVersion(b)
  if a1 ~= b1 then return a1 > b1 and 1 or -1 end
  if a2 ~= b2 then return a2 > b2 and 1 or -1 end
  if a3 ~= b3 then return a3 > b3 and 1 or -1 end
  return 0
end

------------------------------------------------------------------------
-- Module registration
------------------------------------------------------------------------
function ns.OnLoad(fn) inits[#inits + 1] = fn end

function ns.OnEvent(event, fn)
  if not events[event] then
    events[event] = {}
    -- A game client without this event (each version has its own set) says so
    -- with an error: skip it rather than stop loading.
    pcall(frame.RegisterEvent, frame, event)
  end
  table.insert(events[event], fn)
end

function ns.OnMessage(kind, fn) handlers[kind] = fn end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then
      local list = ns.db and events.ADDON_LOADED
      if list then for _, fn in ipairs(list) do safely("ADDON_LOADED", fn, ...) end end
      return
    end
    ns.isNewInstall = WarcrestDB == nil
    WarcrestDB = WarcrestDB or {}
    ns.db = WarcrestDB
    ns.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0"
    C_ChatInfo.RegisterAddonMessagePrefix(ns.PREFIX)
    for _, fn in ipairs(inits) do safely("startup", fn) end
    return
  end
  if not ns.db then return end

  if event == "CHAT_MSG_ADDON" then
    local prefix, text, channel, sender = ...
    -- During a lockdown the game can hand these over as secret values: skip them.
    if not (ns.Usable(prefix) and ns.Usable(text) and ns.Usable(channel) and ns.Usable(sender)) then return end
    -- Your own guild and raid messages are handled as they're sent (see deliver),
    -- since some game clients send them back to you and some don't.
    if (channel == "GUILD" or channel == "RAID") and sender and ns.IsMe(sender) then return end
    ns.HandleAddonMessage(prefix, text, channel, sender)
    return
  end

  local list = events[event]
  if list then
    -- While game events and guildmates' messages are handled, window redraws
    -- are bunched together (see ns.RefreshPanel).
    ns.busy = (ns.busy or 0) + 1
    for _, fn in ipairs(list) do safely(event, fn, ...) end
    ns.busy = ns.busy - 1
  end
end)

------------------------------------------------------------------------
-- Alerts and quiet mode
------------------------------------------------------------------------
-- Every alert goes through ns.Notify. In quiet mode, alerts are held and
-- shown together once you're out of the dungeon, raid or combat.
local held = {}
local MAX_HELD = 50

function ns.IsQuiet()
  local db = ns.db
  if db.quietInstances then
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
      return true
    end
  end
  if db.quietCombat then
    local ok, inCombat = pcall(UnitAffectingCombat, "player")
    if InCombatLockdown() or (ok and ns.Usable(inCombat)) then return true end
  end
  return false
end


-- How alerts show on screen: "banner" (Warcrest's own), "warning" (the game's
-- raid warning text) or "off" (chat only).
function ns.AlertStyle()
  local s = ns.db.alertStyle
  if s then return s end
  return ns.db.warning == false and "off" or "banner"
end

-- chat: the chat line. warning: the on-screen text (defaults to chat).
-- sound: a SOUNDKIT id to play instead of the kind's sound (rarely needed: each
-- kind has a sound you can choose in Settings > Sounds, Core/Sounds.lua).
-- kind: what it is, for the banner's colour, icon and heading (UI/Banner.lua)
-- and the sound; title overrides the heading.
function ns.Notify(chat, warning, sound, force, kind, title)
  if not force and ns.IsQuiet() then
    if #held < MAX_HELD then held[#held + 1] = chat end
    return
  end
  ns.Say(chat)
  local style = ns.AlertStyle()
  if style == "banner" and ns.ShowBanner then
    -- The banner has its own icon: drop the little ones around the text.
    local text = (warning or chat):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", "")
    -- One colour around everything: the banner's own white reads better under its coloured heading.
    local inner = text:match("^|c%x%x%x%x%x%x%x%x(.*)|r$")
    if inner and not inner:find("|c", 1, true) then text = inner end
    ns.ShowBanner(kind, text, title)
  elseif style ~= "off" then
    pcall(RaidWarningUtil.AddMessage, warning or chat, ChatTypeInfo["RAID_WARNING"])
  end
  if sound then
    if ns.db.sound then pcall(PlaySound, sound, ns.db.soundChannel or "Master") end
  elseif ns.PlayAlertSound then
    ns.PlayAlertSound(kind)
  end
end

local function flushHeld()
  if #held == 0 or ns.IsQuiet() then return end
  ns.Say(ns.TP(#held, "While you were busy, %d alert came in:", "While you were busy, %d alerts came in:", #held))
  for _, line in ipairs(held) do print("   " .. line) end
  wipe(held)
  if ns.db.sound and ns.PlaySoundID then ns.PlaySoundID("wc:NotifyDing") end
end

-- Where the player is on the map: mapID, x, y (x and y from 0 to 1).
-- Returns nothing where the game hides your position, such as in instances.
function ns.PlayerPosition()
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = ok and ns.Usable(mapID)
  if not mapID then return end
  local ok2, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not (ok2 and pos) then return end
  local ok3, x, y = pcall(pos.GetXY, pos)
  x, y = ok3 and ns.Usable(x), ok3 and ns.Usable(y)
  if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return end
  return mapID, x, y
end

-- Login greeting, then let modules sync once the guild roster is ready.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(isLogin, isReload)
  if isLogin then
    ns.Say("v" .. ns.version .. " loaded. Type |cffffffff/warcrest|r (or |cffffffff/wc|r) to open it, or |cffffffff/warcrest help|r for help.")
  end
  if isLogin or isReload then
    C_Timer.After(8, function()
      if not IsInGuild() then return end
      if ns.RequestRoster then ns.RequestRoster() end
      if ns.OnGuildReady then
        for _, fn in ipairs(ns.OnGuildReady) do fn() end
      end
    end)
  end
end)
ns.OnGuildReady = {}

-- The Warcrest website: guides, every achievement, and a contact form.
ns.WEBSITE = "https://warcrest-addon.com/"
ns.DISCORD = "https://discord.gg/qeSMwQWyPR"

ns.OnEvent("PLAYER_REGEN_ENABLED", function() C_Timer.After(1, flushHeld) end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, flushHeld) end)
ns.OnEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, flushHeld) end)

-- The game stopped something Warcrest tried (an "interface action failed").
-- Say what, and keep it for /warcrest report, with where it came from.
local function blocked(kind, who, func)
  if who ~= ADDON_NAME then return end
  ns.Say(ns.TF("The game blocked %s for addons. Use the regular Guild window for that action.", tostring(func)))
  local where = debugstack and debugstack(3, 4, 0) or ""
  local text = (kind .. ": " .. tostring(func) .. " " .. where:gsub("\n", " | ")):sub(1, 300)
  local last = ns.recentErrors[#ns.recentErrors]
  if last and last.text == text then
    last.n, last.t = last.n + 1, time()
  else
    ns.recentErrors[#ns.recentErrors + 1] = { text = text, n = 1, t = time() }
    if #ns.recentErrors > 10 then table.remove(ns.recentErrors, 1) end
  end
end
ns.OnEvent("ADDON_ACTION_BLOCKED", function(who, func) blocked("blocked", who, func) end)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", function(who, func) blocked("forbidden", who, func) end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_WARCREST1 = "/warcrest"
SLASH_WARCREST2 = "/wc"
SLASH_WARCREST3 = "/imperium" -- the addon's old name, so old habits still work
SLASH_WARCREST4 = "/imp"
SlashCmdList.WARCREST = function(input)
  input = input or ""
  local msg = input:lower():match("^%s*(.-)%s*$")
  local function toggle(key, label)
    ns.db[key] = not ns.db[key]
    ns.Say(label .. ": " .. (ns.db[key] and "on" or "off"))
    if ns.RefreshPanel then ns.RefreshPanel() end
  end
  if msg == "" then
    if ns.TogglePanel then ns.TogglePanel() end
  elseif msg == "raids" or msg == "raid" then
    if ns.OpenPanel then ns.OpenPanel("raids") end
  elseif msg == "calendar" or msg == "cal" then
    if ns.OpenPanel then ns.OpenPanel("calendar") end
  elseif msg == "dkp" then
    if ns.OpenPanel then ns.OpenPanel("dkp") end
  elseif msg:find("^auction") then
    -- /warcrest auction [item link] [minimum bid]
    local raw = input:gsub("^%s*[Aa][Uu][Cc][Tt][Ii][Oo][Nn]%s*", "")
    local link = raw:match("(|c.-|r)") or raw:match("(|H.-|h.-|h)")
    local min = tonumber(raw:match("(%d+)%s*$"))
    if ns.StartAuction then ns.StartAuction(link or "", min or 10, 30) end
  elseif msg == "kills" then
    if ns.OpenPanel then ns.OpenPanel("kills") end
  elseif msg == "wanted" then
    if ns.OpenPanel then ns.OpenPanel("wanted") end
  elseif msg == "quiet" then
    ns.db.quietCombat = not ns.db.quietCombat
    ns.Say("Hold alerts during combat: " .. (ns.db.quietCombat and "on" or "off"))
    if ns.RefreshPanel then ns.RefreshPanel() end
  elseif msg == "sync" then
    if ns.RequestHistory then ns.RequestHistory(true) end
    if ns.SyncKills then ns.SyncKills() end
  elseif msg == "test" then
    if ns.TestAlert then ns.TestAlert() end
  elseif msg == "sound" then toggle("sound", "Sound")
  elseif msg == "warn" then
    -- On-screen alerts on (as a banner) or off (chat only).
    local on = ns.AlertStyle() == "off"
    ns.db.alertStyle = on and "banner" or "off"
    ns.db.warning = on
    ns.Say(on and "On-screen alerts on." or "On-screen alerts off: chat only.")
  elseif msg == "minimap" then
    if ns.SetMinimapButtonShown then
      local show = not ns.IsMinimapButtonShown()
      ns.SetMinimapButtonShown(show)
      ns.Say("Minimap button " .. (show and "shown." or "hidden. Type /warcrest minimap to bring it back."))
    end
  elseif msg == "share" then
    ns.ShowShare()
  elseif msg == "invite" then
    ns.ShowInvite()
  elseif msg == "council" or msg == "lc" then
    ns.OpenCouncil()
  elseif msg == "raidrecap" or msg == "night" then
    if ns.ShowLastRaidNight then ns.ShowLastRaidNight() end
  elseif msg == "bosses" or msg == "boss" then
    ns.ShowBossChecks()
  elseif msg == "profile" or msg == "me" then
    if ns.ShowProfileEditor then ns.ShowProfileEditor() end
  elseif msg == "profiles" then
    if ns.ShowProfiles then ns.ShowProfiles() end
  elseif msg:find("^craft") then
    -- /warcrest craft [search]: who in the guild can make something.
    if ns.ShowCrafters then ns.ShowCrafters(input:match("^%s*%S+%s+(.-)%s*$")) end
  elseif msg == "events" or msg == "event" then
    if ns.OpenPanel then ns.OpenPanel("events") end
  elseif msg == "recruit" or msg == "recruits" then
    if ns.OpenPanel then ns.OpenPanel("recruit") end
  elseif msg:find("^check") then
    -- /warcrest check [name]: why achievements have or haven't counted.
    if ns.AchievementCheck then ns.AchievementCheck(input:match("^%s*%S+%s+(%S+)")) end
  elseif msg == "debug" then
    ns.db.debug = not ns.db.debug
    ns.Say("Debug messages " .. (ns.db.debug and "on. Error details will show in chat." or "off."))
  elseif msg == "addon" or msg == "who" then
    if ns.OpenPanel then ns.OpenPanel("addon") end
  elseif msg == "versions" then
    if ns.CheckVersions then ns.CheckVersions() end
  elseif msg == "help" or msg == "?" then
    if ns.ShowHelp then ns.ShowHelp() end
  elseif msg == "website" or msg == "site" or msg == "feedback" or msg == "contact" then
    ns.Say(ns.TF("Guides, every achievement and a contact form for bugs and ideas: %s", "|cffffffff" .. ns.WEBSITE .. "|r"))
    if ns.ShowHelp then ns.ShowHelp(nil, true) end
  elseif msg == "attune" or msg == "attunements" or msg == "attunement" then
    if ns.ShowAttunements then ns.ShowAttunements() end
  elseif msg == "assign" or msg == "assignments" or msg:find("^assign ") then
    if ns.ShowAssignments then ns.ShowAssignments() end
  elseif msg == "polls" or msg == "poll" then
    if ns.OpenPanel then ns.OpenPanel("events", "polls") end
  elseif msg == "orders" then
    if ns.ShowCrafters then ns.ShowCrafters(nil, "orders") end
  elseif msg == "inactive" then
    if ns.OpenPanel then ns.OpenPanel("officers", "inactive") end
  elseif msg == "discord" then
    ns.Say(ns.TF("Join the Warcrest Discord for help, news and other guilds using it: %s", "|cffffffff" .. ns.DISCORD .. "|r"))
    if ns.ShowHelp then ns.ShowHelp(nil, "discord") end
  elseif msg == "report" or msg == "bugreport" or msg == "bug" or msg == "bug report" then
    if ns.ShowBugReport then ns.ShowBugReport() end
  elseif msg == "access" or msg == "accessibility" then
    if ns.OpenPanel then ns.OpenPanel("settings", "access") end
  elseif msg == "start" or msg == "welcome" or msg == "started" then
    if ns.ShowGettingStarted then ns.ShowGettingStarted() end
  elseif msg == "setup" then
    if ns.ShowWelcome then ns.ShowWelcome(2) end
  elseif msg == "updates" or msg == "news" or msg == "changes" then
    if ns.ShowUpdates then ns.ShowUpdates(nil) end
  elseif msg == "recap" or msg == "recap now" or msg == "recap week" then
    if ns.ShowRecap then ns.ShowRecap(msg == "recap" and -1 or 0) end
  elseif msg == "achievements" or msg == "ach" then
    ns.ShowAchievements()
  elseif msg == "wishlist" or msg == "wish" then
    ns.OpenPanel("wishlist")
  elseif msg:find("^card") then
    -- /warcrest card [name]: a guild member's player card (yours if no name).
    local who = input:match("^%s*%S+%s+(%S+)") or UnitName("player")
    if ns.ShowPlayerCard then ns.ShowPlayerCard(who) end
  elseif msg == "version" then
    ns.Say("Version " .. ns.version .. (ns.QueueSize() > 0 and (" (" .. ns.QueueSize() .. " messages waiting to send)") or ""))
    if #ns.loadErrors > 0 then
      ns.Say(("|cffff6060%d problem%s so far. The first was:|r"):format(#ns.loadErrors, #ns.loadErrors == 1 and "" or "s"))
      print("  " .. ns.loadErrors[1])
    else
      print("  No problems so far.")
    end
  else
    ns.Say("Commands:")
    print("  /warcrest - open Warcrest (or /wc)")
    print("  /warcrest raids | dkp | kills | wanted | wishlist | achievements - open that page")
    print("  /warcrest card [name] - a guild member's player card")
    print("  /warcrest share | invite - spread the word about Warcrest")
    print("  /warcrest help - the help window, with every command")
  end
end

------------------------------------------------------------------------
-- Addon compartment (the addons button by the minimap)
------------------------------------------------------------------------
-- Key Bindings > AddOns > Warcrest (Bindings.xml): a key to open or close the window.
BINDING_HEADER_WARCREST = "Warcrest"
BINDING_NAME_WARCREST_TOGGLE = "Open or close Warcrest"
ns.OnLoad(function() BINDING_NAME_WARCREST_TOGGLE = ns.T("Open or close Warcrest") end)

function Warcrest_OnAddonCompartmentClick()
  if ns.TogglePanel then ns.TogglePanel() end
end

function Warcrest_OnAddonCompartmentEnter(_, button)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText("|T" .. ns.ICON .. ":20:20|t " .. ns.COLOR .. ns.BRAND .. "|r")
  GameTooltip:AddLine("Click to open guild tools.", 1, 1, 1)
  GameTooltip:AddLine("Version " .. (ns.version or "?"), 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function Warcrest_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

ns.OnLoad(ns.StartSendQueue)
